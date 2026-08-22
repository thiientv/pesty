import AppKit
import SwiftUI

struct ClipCardView: View {
    let item: ClipItem
    let index: Int
    let selected: Bool

    @State private var hovering = false
    @State private var dropPosition: ItemDropPosition?
    private var store: ClipboardStore { ClipboardStore.shared }
    private var settings: Settings { Settings.shared }
    private var headerColor: Color {
        guard let boardID = store.currentPinboardID,
              let board = store.pinboards.first(where: { $0.id == boardID }) else {
            return SourceColor.color(for: item.sourceBundleID)
        }
        return board.color
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            body_
        }
        .frame(width: Theme.cardWidth)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
        .background {
            if selected {
                RoundedRectangle(
                    cornerRadius: Theme.cardCorner + Theme.selectedCardRing,
                    style: .continuous
                )
                .fill(Theme.selection)
                .padding(-Theme.selectedCardRing)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                .strokeBorder(selected ? Theme.selection : Theme.cardBorder,
                              lineWidth: Theme.cardBorderWidth)
        )
        .shadow(color: selected ? Theme.selectedCardShadow : Theme.cardShadow,
                radius: selected ? 5 : 4, y: 2)
        .scaleEffect(hovering && !selected ? 1.015 : 1.0)
        .zIndex(selected ? 1 : 0)
        .animation(.spring(response: 0.32, dampingFraction: 0.72), value: selected)
        .animation(.easeOut(duration: 0.14), value: hovering)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { AppController.shared.pasteItem(item) }
        .onTapGesture { store.select(item.id) }
        .highPriorityGesture(TapGesture().modifiers(.shift).onEnded { store.extendSelection(to: item.id) })
        .highPriorityGesture(TapGesture().modifiers(.command).onEnded { store.toggleSelection(item.id) })
        .onDrag {
            store.beginDragging(item.id)
            return ClipDragProvider.make(for: item)
        }
        .onDrop(of: [ClipDragProvider.internalItemTypeIdentifier],
                delegate: ClipReorderDropDelegate(targetItemID: item.id,
                                                  source: store.source,
                                                  store: store,
                                                  dropPosition: $dropPosition))
        .overlay { dropIndicator }
        .contextMenu { menu }
    }

    @ViewBuilder
    private var dropIndicator: some View {
        if let dropPosition {
            HStack(spacing: 0) {
                if dropPosition == .after { Spacer(minLength: 0) }
                Capsule()
                    .fill(Theme.selection)
                    .frame(width: 4)
                    .padding(.vertical, 8)
                    .shadow(color: Theme.selection.opacity(0.5), radius: 4)
                if dropPosition == .before { Spacer(minLength: 0) }
            }
            .padding(.horizontal, -8)
            .allowsHitTesting(false)
        }
    }

    private var header: some View {
        ZStack {
            headerColor
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.type.label)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.headerText)
                    Text(item.createdAt.clipRelativeLong)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.headerSubText)
                }
                .lineLimit(1)
                Spacer(minLength: 4)
                if isPinnedInCurrentPinboard { pinBadge }
                appIconTile
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
        }
        .frame(height: Theme.headerHeight)
    }

    private var pinBadge: some View {
        Image(systemName: "pin.fill")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Theme.headerText)
            .frame(width: 26, height: 26)
            .background(Color.white.opacity(0.16), in: Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.18)))
            .accessibilityLabel("Pinned to top")
    }

    private var appIconTile: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(Color.white.opacity(0.14))
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14))
            )
            .frame(width: 56, height: 56)
            .overlay(
                Image(nsImage: AppIconProvider.icon(forBundleID: item.sourceBundleID))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 48, height: 48)
            )
    }

    private var body_: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            footer
        }
        .padding(.horizontal, 13)
        .padding(.top, 11)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.cardBody)
    }

    @ViewBuilder
    private var content: some View {
        switch item.type {
        case .image:
            if let img = store.loadImage(for: item) {
                Image(nsImage: img)
                    .resizable().interpolation(.medium).scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else { placeholder("photo") }
        case .color:
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color(hex: item.colorHex ?? "#000") ?? .black)
                Text(item.colorHex ?? "")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white).shadow(radius: 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .file:
            VStack(spacing: 9) {
                Image(systemName: "doc.fill").font(.system(size: 32))
                    .foregroundStyle(headerColor)
                Text(item.displayTitle).font(.system(size: 12))
                    .foregroundStyle(Theme.cardTextSecondary).lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .link:
            VStack(spacing: 10) {
                Spacer(minLength: 0)
                Image(systemName: "safari").font(.system(size: 34, weight: .light))
                    .foregroundStyle(Theme.cardTextTertiary)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        default:
            Text(item.text ?? "")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.cardTextPrimary.opacity(0.9))
                .lineLimit(10)
                .multilineTextAlignment(.leading)
        }
    }

    private func placeholder(_ symbol: String) -> some View {
        Image(systemName: symbol).font(.system(size: 30))
            .foregroundStyle(Theme.cardTextTertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 3) {
            if item.type == .link {
                Text(item.displayTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.cardTextPrimary).lineLimit(1)
            }
            HStack(spacing: 6) {
                Text(metaLeft)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.cardTextSecondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if index < 9 {
                    HStack(spacing: 3) {
                        Text(settings.quickPasteModifierDisplay)
                            .font(.system(size: 11, weight: .semibold))
                        Text("\(index + 1)")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Theme.cardTextTertiary)
                }
            }
        }
        .padding(.top, 8)
    }

    private var metaLeft: String {
        switch item.type {
        case .text, .richText:
            return "\(item.charCount) characters"
        case .link:
            return (item.text ?? "").replacingOccurrences(of: "https://", with: "")
                                    .replacingOccurrences(of: "http://", with: "")
        case .file:
            return "\(item.fileURLs.count) file\(item.fileURLs.count == 1 ? "" : "s")"
        case .image:
            return "Image"
        case .color:
            return item.colorHex ?? "Color"
        }
    }

    @ViewBuilder
    private var menu: some View {
        Button { AppController.shared.pasteItem(item) } label: {
            Label(AppController.shared.pasteMenuTitle, systemImage: "doc.on.clipboard")
        }

        Button { AppController.shared.pasteItem(item, asPlainText: true) } label: {
            Label("Paste as Plain Text", systemImage: "text.alignleft")
        }
        .disabled(item.plainText == nil)

        Button { AppController.shared.copyItem(item) } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }

        if let boardID = store.currentPinboardID {
            Divider()
            Button { store.togglePinned(item.id, inPinboard: boardID) } label: {
                Label(isPinnedInCurrentPinboard ? "Unpin from Top" : "Pin to Top",
                      systemImage: isPinnedInCurrentPinboard ? "pin.slash" : "pin.fill")
            }
        }

        Divider()

        Button { AppController.shared.editItem(item) } label: {
            Label("Edit", systemImage: "pencil")
        }
        .disabled(!isEditable)

        if writingToolsAvailable {
            Button { AppController.shared.editItem(item, launchWritingTools: true) } label: {
                Label("Writing Tools", systemImage: "pencil.and.scribble")
            }
        }

        Button { renameItem() } label: {
            Label("Rename…", systemImage: "pencil.line")
        }

        Divider()

        Menu {
            if destinationPinboards.isEmpty {
                Button("No Other Pinboards") {}.disabled(true)
            } else {
                ForEach(destinationPinboards) { b in
                    Button { store.saveToPinboard(item, boardID: b.id) } label: {
                        Label {
                            Text(b.name)
                        } icon: {
                            Image(nsImage: Self.pinboardMenuIcon(color: NSColor(b.color)))
                                .renderingMode(.original)
                        }
                    }
                }
            }
            Divider()
            Button { copyToNewBoard() } label: {
                Label("Create Pinboard…", systemImage: "plus")
            }
        } label: {
            Label("Copy to Pinboard", systemImage: "doc.on.doc")
        }

        Menu {
            if destinationPinboards.isEmpty {
                Button("No Other Pinboards") {}.disabled(true)
            } else {
                ForEach(destinationPinboards) { board in
                    Button {
                        store.moveItem(item.id, from: store.source, toPinboard: board.id)
                    } label: {
                        Label {
                            Text(board.name)
                        } icon: {
                            Image(nsImage: Self.pinboardMenuIcon(color: NSColor(board.color)))
                                .renderingMode(.original)
                        }
                    }
                }
            }
            Divider()
            Button { moveToNewBoard() } label: {
                Label("Create Pinboard and Move…", systemImage: "plus")
            }
        } label: {
            Label("Move to Pinboard", systemImage: "folder")
        }

        Divider()

        Button { AppController.shared.showPreview(for: item) } label: {
            Label("Preview", systemImage: "eye")
        }

        Button { AppController.shared.showSharePicker(for: item) } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }

        Divider()

        Button(role: .destructive) {
            AppController.shared.deleteSelection(containing: item)
        } label: {
            Label(deleteMenuTitle, systemImage: "trash")
        }
    }

    private var deleteMenuTitle: String {
        let count = store.multiSelectedIDs.contains(item.id) ? store.multiSelectedIDs.count : 1
        return count > 1 ? "Delete \(count) Clips" : "Delete"
    }

    private var isEditable: Bool {
        [.text, .richText, .link, .color].contains(item.type)
    }

    private var destinationPinboards: [Pinboard] {
        let currentID = store.currentPinboardID
        return store.pinboards.filter { $0.id != currentID }
    }

    private var isPinnedInCurrentPinboard: Bool {
        guard let boardID = store.currentPinboardID else { return false }
        return store.isPinned(item.id, inPinboard: boardID)
    }

    private var writingToolsAvailable: Bool {
        guard [.text, .richText, .link].contains(item.type) else { return false }
        guard #available(macOS 15.2, *) else { return false }
        return NSWritingToolsCoordinator.isWritingToolsAvailable
    }

    private func renameItem() {
        if let title = TextPrompt.run(title: "Rename", message: "Card title",
                                      defaultValue: item.customTitle ?? "") {
            store.setTitle(title, for: item)
        }
    }

    private func copyToNewBoard() {
        if let name = TextPrompt.run(title: "Create Pinboard", message: "Name") {
            let board = store.addPinboard(name: name)
            store.saveToPinboard(item, boardID: board.id)
        }
    }

    private func moveToNewBoard() {
        if let name = TextPrompt.run(title: "Create Pinboard", message: "Name") {
            let board = store.addPinboard(name: name)
            store.moveItem(item.id, from: store.source, toPinboard: board.id)
        }
    }

    private static func pinboardMenuIcon(color: NSColor) -> NSImage {
        let size = NSSize(width: 12, height: 12)
        let image = NSImage(size: size, flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}

private struct ClipReorderDropDelegate: DropDelegate {
    let targetItemID: UUID
    let source: BarSource
    let store: ClipboardStore
    @Binding var dropPosition: ItemDropPosition?

    func validateDrop(info: DropInfo) -> Bool {
        guard let draggedItemID = store.draggedItemID else { return false }
        return store.draggedSource == source
            && store.canReorderItem(draggedItemID, relativeTo: targetItemID, in: source)
            && info.hasItemsConforming(to: [ClipDragProvider.internalItemTypeIdentifier])
    }

    func dropEntered(info: DropInfo) {
        updateDropPosition(info: info)
    }

    func dropExited(info: DropInfo) {
        dropPosition = nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard validateDrop(info: info) else {
            dropPosition = nil
            return DropProposal(operation: .forbidden)
        }
        updateDropPosition(info: info)
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard validateDrop(info: info), let draggedItemID = store.draggedItemID else {
            dropPosition = nil
            return false
        }
        let position = position(for: info)
        store.reorderItem(draggedItemID, relativeTo: targetItemID,
                          position: position, in: source)
        store.finishDragging()
        dropPosition = nil
        return true
    }

    private func position(for info: DropInfo) -> ItemDropPosition {
        info.location.x < Theme.cardWidth / 2 ? .before : .after
    }

    private func updateDropPosition(info: DropInfo) {
        guard validateDrop(info: info) else {
            dropPosition = nil
            return
        }
        dropPosition = position(for: info)
    }
}
