import AppKit

@MainActor
enum TextPrompt {
    static func run(title: String, message: String, defaultValue: String = "") -> String? {
        AppController.shared.suppressAutoHide = true
        defer { AppController.shared.suppressAutoHide = false }
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = defaultValue
        alert.accessoryView = field
        alert.layout()
        alert.window.initialFirstResponder = field
        alert.window.makeFirstResponder(field)
        field.selectText(nil)
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }
        let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

@MainActor
enum ColorPrompt {
    static func run(title: String, currentHex: String) -> String? {
        AppController.shared.suppressAutoHide = true
        defer { AppController.shared.suppressAutoHide = false }
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = "Choose a color for this pinboard"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let colorWell = NSColorWell(frame: NSRect(x: 0, y: 0, width: 260, height: 32))
        colorWell.color = NSColor(hex: currentHex) ?? .systemBlue
        alert.accessoryView = colorWell
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }
        return colorWell.color.usingColorSpace(.sRGB)?.hexString
    }
}
