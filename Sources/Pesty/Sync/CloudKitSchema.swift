import Foundation
import CloudKit

/// Clip/Pinboard <-> CKRecord mapping. This file is the wire contract —
/// the iOS app ships a byte-identical copy (PestyKit/Sync/CloudKitSchema.swift).
/// Any change here must land on both platforms simultaneously.
enum CKSchema {
    static let containerID = "iCloud.com.greycorelabs.pesty"
    static let zoneName = "PestyZone"

    static let clipType = "Clip"
    static let pinboardType = "Pinboard"
    static let historyContainerValue = "history"
    /// Above this many UTF-8 bytes, text/rtf move into CKAssets.
    static let inlineLimit = 200_000

    static var zoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
    }

    // MARK: Clip -> CKRecord

    /// `imageFileURL`: full path of the PNG for this clip if any (becomes a CKAsset).
    /// `container`: "history" or pinboard UUID string.
    static func populate(_ record: CKRecord, from item: ClipItem,
                         container: String, imageFileURL: URL?) {
        record["type"] = item.type.rawValue
        if let text = item.text {
            if text.utf8.count > inlineLimit {
                record["text"] = nil
                record["textAsset"] = writeTempAsset(Data(text.utf8), ext: "txt")
            } else {
                record["text"] = text
                record["textAsset"] = nil
            }
        } else {
            record["text"] = nil
            record["textAsset"] = nil
        }
        if let rtf = item.rtfData {
            if rtf.count > inlineLimit {
                record["rtf"] = nil
                record["rtfAsset"] = writeTempAsset(rtf, ext: "rtf")
            } else {
                record["rtf"] = rtf
                record["rtfAsset"] = nil
            }
        } else {
            record["rtf"] = nil
            record["rtfAsset"] = nil
        }
        if let url = imageFileURL, FileManager.default.fileExists(atPath: url.path) {
            record["image"] = CKAsset(fileURL: url)
        }
        record["imageHash"] = item.imageHash
        record["fileURLs"] = item.fileURLs.isEmpty ? nil : item.fileURLs
        record["colorHex"] = item.colorHex
        record["sourceBundleID"] = item.sourceBundleID
        record["sourceAppName"] = item.sourceAppName
        record["customTitle"] = item.customTitle
        record["createdAt"] = item.createdAt
        record["container"] = container
    }

    /// Staging dir for large text/rtf CKAssets; purged on engine start and
    /// after successful sends (Amendment 11). Mac base: Application Support/Pesty.
    static var tempAssetDir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pesty/ck-tmp", isDirectory: true)
    }

    static func purgeTempAssets() {
        try? FileManager.default.removeItem(at: tempAssetDir)
    }

    private static func writeTempAsset(_ data: Data, ext: String) -> CKAsset? {
        let dir = tempAssetDir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        let url = dir.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        do { try data.write(to: url, options: .atomic) } catch { return nil }
        return CKAsset(fileURL: url)
    }

    // MARK: CKRecord -> Clip

    struct DecodedClip {
        let item: ClipItem
        let container: String
        /// Local file URL of the downloaded image asset (CloudKit temp file); copy it before the op ends.
        let imageAssetURL: URL?
    }

    static func decodeClip(_ record: CKRecord) -> DecodedClip? {
        guard record.recordType == clipType,
              let id = UUID(uuidString: record.recordID.recordName),
              let rawType = record["type"] as? String,
              let type = ClipType(rawValue: rawType) else { return nil }

        var text = record["text"] as? String
        if let asset = record["textAsset"] as? CKAsset, let url = asset.fileURL,
           let data = try? Data(contentsOf: url) {
            text = String(data: data, encoding: .utf8) ?? text
        }
        var rtf = record["rtf"] as? Data
        if let asset = record["rtfAsset"] as? CKAsset, let url = asset.fileURL,
           let data = try? Data(contentsOf: url) {
            rtf = data
        }
        let imageAssetURL = (record["image"] as? CKAsset)?.fileURL
        let item = ClipItem(
            id: id,
            type: type,
            text: text,
            rtfData: rtf,
            imageFileName: imageAssetURL != nil ? "\(id.uuidString).png" : nil,
            imageHash: record["imageHash"] as? String,
            fileURLs: (record["fileURLs"] as? [String]) ?? [],
            colorHex: record["colorHex"] as? String,
            sourceBundleID: record["sourceBundleID"] as? String,
            sourceAppName: record["sourceAppName"] as? String,
            customTitle: record["customTitle"] as? String,
            createdAt: (record["createdAt"] as? Date) ?? record.creationDate ?? Date())
        return DecodedClip(item: item,
                           container: (record["container"] as? String) ?? historyContainerValue,
                           imageAssetURL: imageAssetURL)
    }

    // MARK: Pinboard

    static func populate(_ record: CKRecord, from board: Pinboard) {
        record["name"] = board.name
        record["colorHex"] = board.colorHex
        record["pinnedItemIDs"] = board.pinnedItemIDs.map(\.uuidString)
        record["itemOrderIDs"] = board.itemOrderIDs.map(\.uuidString)
    }

    static func decodePinboard(_ record: CKRecord) -> Pinboard? {
        guard record.recordType == pinboardType,
              let id = UUID(uuidString: record.recordID.recordName),
              let name = record["name"] as? String else { return nil }
        return Pinboard(id: id, name: name,
                        colorHex: (record["colorHex"] as? String) ?? "#5B8DEF",
                        items: [],
                        pinnedItemIDs: ((record["pinnedItemIDs"] as? [String]) ?? [])
                            .compactMap(UUID.init(uuidString:)),
                        itemOrderIDs: ((record["itemOrderIDs"] as? [String]) ?? [])
                            .compactMap(UUID.init(uuidString:)))
    }
}
