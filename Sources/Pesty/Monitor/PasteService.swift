import AppKit
import Carbon.HIToolbox

@MainActor
enum PasteService {
    private static let sourceType = NSPasteboard.PasteboardType("org.nspasteboard.source")
    private static let packagedBundleID = "com.greycorelabs.pesty"

    private static func markSource(of item: ClipItem, on pasteboard: NSPasteboard) {
        let source = item.sourceBundleID ?? Bundle.main.bundleIdentifier ?? packagedBundleID
        pasteboard.setString(source, forType: sourceType)
    }

    @discardableResult
    static func copy(_ item: ClipItem,
                     asPlainText: Bool = false,
                     to pasteboard: NSPasteboard = .general) -> Int {
        if asPlainText, let text = item.plainText {
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            markSource(of: item, on: pasteboard)
            return pasteboard.changeCount
        }
        if item.type == .image {
            guard let img = ClipboardStore.shared.loadImage(for: item) else {
                return pasteboard.changeCount
            }
            pasteboard.clearContents()
            pasteboard.writeObjects([img])
            markSource(of: item, on: pasteboard)
            return pasteboard.changeCount
        }
        pasteboard.clearContents()
        switch item.type {
        case .image:
            break
        case .file:
            let urls = item.fileURLs.compactMap { URL(string: $0) }
            if !urls.isEmpty { pasteboard.writeObjects(urls as [NSURL]) }
            if let t = item.text { pasteboard.setString(t, forType: .string) }
        case .color:
            if let hex = item.colorHex, let c = NSColor(hex: hex) {
                pasteboard.writeObjects([c])
                pasteboard.setString(hex, forType: .string)
            }
        case .richText:
            if let rtf = item.rtfData { pasteboard.setData(rtf, forType: .rtf) }
            if let t = item.text { pasteboard.setString(t, forType: .string) }
        case .text, .link:
            if let t = item.text { pasteboard.setString(t, forType: .string) }
        }
        markSource(of: item, on: pasteboard)
        return pasteboard.changeCount
    }

    #if !MAS
    private static func sendCommandV() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let v = CGKeyCode(kVK_ANSI_V)
        guard let down = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: true),
              let up = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: false) else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private static func waitForFrontmost(_ app: NSRunningApplication, attempts: Int) {
        guard attempts > 0, !app.isTerminated else { return }
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { sendCommandV() }
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            waitForFrontmost(app, attempts: attempts - 1)
        }
    }

    @discardableResult
    static func ensureAccessibility(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let opts = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    private static func requestAccessibility() -> Bool {
        guard !ensureAccessibility(prompt: true) else { return true }
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return false }
        NSWorkspace.shared.open(url)
        return false
    }
    #endif

    static func paste(_ item: ClipItem,
                      into targetApp: NSRunningApplication?,
                      monitor: ClipboardMonitor,
                      asPlainText: Bool = false) {
        let change = copy(item, asPlainText: asPlainText)
        monitor.suppressUntilChangeCount = change
        if Settings.shared.playSound { NSSound(named: "Pop")?.play() }

        guard let target = targetApp, !target.isTerminated else { return }

        #if MAS
        // Mac App Store (sandboxed) build: copy the clip and return focus to the
        // app the user came from so they can paste with ⌘V. No Accessibility
        // APIs and no synthetic keystrokes are used.
        target.activate()
        #else
        // Direct-download build: optionally paste straight into the active app by
        // synthesizing ⌘V. This requires the user's Accessibility grant. Prompt
        // when a rebuilt app no longer matches the identity macOS previously trusted.
        guard Settings.shared.pasteDirectly else {
            target.activate()
            return
        }
        guard requestAccessibility() else { return }
        target.activate()
        waitForFrontmost(target, attempts: 20)
        #endif
    }
}
