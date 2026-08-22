import SwiftUI

struct PinboardTabs: View {
    @Bindable private var store = ClipboardStore.shared
    @State private var dropTargetPinboardID: UUID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                pill(title: "Clipboard",
                     dot: nil,
                     icon: "clock",
                     selected: store.source == .history) {
                    store.source = .history; store.selectFirst()
                }

                ForEach(store.pinboards) { board in
                    pill(title: board.name,
                         dot: board.color,
                         dropTarget: dropTargetPinboardID == board.id,
                         selected: store.source == .pinboard(board.id)) {
                        store.source = .pinboard(board.id); store.selectFirst()
                    }
                    .contextMenu {
                        Button("Rename…") { rename(board) }
                        colorMenu(for: board)
                        Divider()
                        Button("Delete Pinboard", role: .destructive) {
                            store.deletePinboard(board.id)
                        }
                    }
                    .onDrop(of: [ClipDragProvider.internalItemTypeIdentifier],
                            delegate: PinboardMoveDropDelegate(
                                boardID: board.id,
                                store: store,
                                dropTargetPinboardID: $dropTargetPinboardID))
                }

                Button(action: addPinboard) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.chromeTextSecondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("New Pinboard")
            }
        }
        .background(HorizontalScrollWheelSupport())
    }

    private func pill(title: String, dot: Color?, icon: String? = nil, dropTarget: Bool = false,
                      selected: Bool, action: @escaping () -> Void) -> some View {
        let background = dropTarget
            ? (dot ?? Theme.selection).opacity(0.20)
            : (selected ? Theme.pillSelected : Theme.pillBG)
        return Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                }
                if let dot {
                    Circle().fill(dot).frame(width: 8, height: 8)
                }
                Text(title)
                    .font(.system(size: 12.5, weight: selected ? .semibold : .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(selected ? Theme.chromeTextPrimary : Theme.chromeTextSecondary)
            .padding(.horizontal, 12)
            .frame(height: 29)
            .background(background, in: Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .animation(.easeOut(duration: 0.15), value: selected)
    }

    private func addPinboard() {
        guard let name = TextPrompt.run(title: "Create Pinboard", message: "Name") else { return }
        let board = store.addPinboard(name: name)
        store.source = .pinboard(board.id)
    }

    private func rename(_ board: Pinboard) {
        if let name = TextPrompt.run(title: "Rename Pinboard",
                                     message: "Enter a new name",
                                     defaultValue: board.name) {
            store.renamePinboard(board.id, to: name)
        }
    }

    private func colorSwatch(_ hex: String) -> NSImage {
        let color = NSColor(hex: hex) ?? .systemBlue
        let size = NSSize(width: 12, height: 12)
        let image = NSImage(size: size, flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
            return true
        }
        image.isTemplate = false
        return image
    }

    private func colorMenu(for board: Pinboard) -> some View {
        Menu {
            ForEach(PinboardColorOption.defaults) { option in
                Button {
                    store.setPinboardColor(board.id, to: option.hex)
                } label: {
                    Label {
                        Text(option.name)
                    } icon: {
                        Image(nsImage: colorSwatch(option.hex))
                            .renderingMode(.original)
                    }
                }
            }
            Divider()
            Button("Custom Color…") {
                if let color = ColorPrompt.run(title: "Pinboard Color", currentHex: board.colorHex) {
                    store.setPinboardColor(board.id, to: color)
                }
            }
        } label: {
            Label("Change Color", systemImage: "paintpalette")
        }
    }
}

private struct PinboardMoveDropDelegate: DropDelegate {
    let boardID: UUID
    let store: ClipboardStore
    @Binding var dropTargetPinboardID: UUID?

    func validateDrop(info: DropInfo) -> Bool {
        store.draggedSource != nil
            && store.draggedSource != .pinboard(boardID)
            && info.hasItemsConforming(to: [ClipDragProvider.internalItemTypeIdentifier])
    }

    func dropEntered(info: DropInfo) {
        guard validateDrop(info: info) else { return }
        dropTargetPinboardID = boardID
    }

    func dropExited(info: DropInfo) {
        if dropTargetPinboardID == boardID { dropTargetPinboardID = nil }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        validateDrop(info: info) ? DropProposal(operation: .move) : DropProposal(operation: .forbidden)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard validateDrop(info: info) else { return false }
        store.moveDraggedItem(toPinboard: boardID)
        dropTargetPinboardID = nil
        return true
    }
}

private struct PinboardColorOption: Identifiable {
    let name: String
    let hex: String

    var id: String { hex }

    static let defaults = [
        PinboardColorOption(name: "Blue", hex: "#5B8DEF"),
        PinboardColorOption(name: "Indigo", hex: "#6C63D9"),
        PinboardColorOption(name: "Purple", hex: "#A45DCE"),
        PinboardColorOption(name: "Pink", hex: "#D95F9C"),
        PinboardColorOption(name: "Red", hex: "#D95D5D"),
        PinboardColorOption(name: "Orange", hex: "#D98245"),
        PinboardColorOption(name: "Yellow", hex: "#C9A227"),
        PinboardColorOption(name: "Green", hex: "#4E9F6D"),
        PinboardColorOption(name: "Teal", hex: "#3A9D9A")
    ]
}
