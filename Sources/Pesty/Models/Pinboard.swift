import SwiftUI

struct Pinboard: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var colorHex: String
    var items: [ClipItem]
    var pinnedItemIDs: [UUID]
    var itemOrderIDs: [UUID]

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case colorHex
        case items
        case pinnedItemIDs
        case itemOrderIDs
    }

    private static func uniqueIDs(_ ids: [UUID], allowed: Set<UUID>? = nil) -> [UUID] {
        var seen = Set<UUID>()
        return ids.filter { id in
            (allowed == nil || allowed?.contains(id) == true) && seen.insert(id).inserted
        }
    }

    init(id: UUID = UUID(), name: String, colorHex: String = "#5B8DEF",
         items: [ClipItem] = [], pinnedItemIDs: [UUID] = [], itemOrderIDs: [UUID]? = nil) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.items = items
        self.pinnedItemIDs = Self.uniqueIDs(pinnedItemIDs)
        self.itemOrderIDs = Self.uniqueIDs(itemOrderIDs ?? items.map(\.id))
    }

    var color: Color { Color(hex: colorHex) ?? .accentColor }

    var orderedItems: [ClipItem] {
        let itemsByID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let existingIDs = Set(itemsByID.keys)
        let pinnedIDs = Self.uniqueIDs(pinnedItemIDs, allowed: existingIDs)
        let pinned = Set(pinnedIDs)
        var emitted = pinned
        var ordered = pinnedIDs.compactMap { itemsByID[$0] }
        for id in Self.uniqueIDs(itemOrderIDs, allowed: existingIDs)
            where !pinned.contains(id) && emitted.insert(id).inserted {
            if let item = itemsByID[id] { ordered.append(item) }
        }
        ordered += items.filter { emitted.insert($0.id).inserted }
        return ordered
    }

    func isPinned(_ itemID: UUID) -> Bool {
        pinnedItemIDs.contains(itemID)
    }

    mutating func reconcileItemReferences(preservingMissing: Bool = false) {
        let itemIDs = Set(items.map(\.id))
        let allowed = preservingMissing ? nil : itemIDs
        pinnedItemIDs = Self.uniqueIDs(pinnedItemIDs, allowed: allowed)
        itemOrderIDs = Self.uniqueIDs(itemOrderIDs, allowed: allowed)
        var orderedIDs = Set(itemOrderIDs)
        for item in items where orderedIDs.insert(item.id).inserted {
            itemOrderIDs.append(item.id)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        items = try container.decode([ClipItem].self, forKey: .items)
        pinnedItemIDs = try container.decodeIfPresent([UUID].self, forKey: .pinnedItemIDs) ?? []
        itemOrderIDs = try container.decodeIfPresent([UUID].self, forKey: .itemOrderIDs)
            ?? items.map(\.id)
        reconcileItemReferences()
    }
}

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard let v = UInt64(s, radix: 16) else { return nil }
        let r, g, b, a: Double
        switch s.count {
        case 6:
            r = Double((v >> 16) & 0xFF) / 255
            g = Double((v >> 8) & 0xFF) / 255
            b = Double(v & 0xFF) / 255
            a = 1
        case 8:
            r = Double((v >> 24) & 0xFF) / 255
            g = Double((v >> 16) & 0xFF) / 255
            b = Double((v >> 8) & 0xFF) / 255
            a = Double(v & 0xFF) / 255
        default:
            return nil
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    var hexString: String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .white
        let r = Int(round(ns.redComponent * 255))
        let g = Int(round(ns.greenComponent * 255))
        let b = Int(round(ns.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
