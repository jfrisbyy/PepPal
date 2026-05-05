import Foundation
import SwiftUI

nonisolated struct VialScanHistoryEntry: Identifiable, Codable, Sendable {
    let id: UUID
    let scan: ScannedVialLabel
    let labelImageFilename: String?
    let extraImageFilenames: [String]
    let scannedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, scan, labelImageFilename, extraImageFilenames, scannedAt
    }

    init(id: UUID = UUID(), scan: ScannedVialLabel, labelImageFilename: String?, extraImageFilenames: [String] = [], scannedAt: Date = Date()) {
        self.id = id
        self.scan = scan
        self.labelImageFilename = labelImageFilename
        self.extraImageFilenames = extraImageFilenames
        self.scannedAt = scannedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        scan = try c.decode(ScannedVialLabel.self, forKey: .scan)
        labelImageFilename = try c.decodeIfPresent(String.self, forKey: .labelImageFilename)
        extraImageFilenames = try c.decodeIfPresent([String].self, forKey: .extraImageFilenames) ?? []
        scannedAt = try c.decode(Date.self, forKey: .scannedAt)
    }

    var allImageFilenames: [String] {
        var arr: [String] = []
        if let primary = labelImageFilename { arr.append(primary) }
        arr.append(contentsOf: extraImageFilenames)
        return arr
    }
}

@Observable
@MainActor
final class VialScanHistoryStore {
    static let shared = VialScanHistoryStore()

    private let storageKey = "peppal.vialScanHistory.v1"
    private let maxEntries = 25

    var entries: [VialScanHistoryEntry] = [] {
        didSet { save() }
    }

    private init() { load() }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([VialScanHistoryEntry].self, from: data) else { return }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    func add(scan: ScannedVialLabel, imageFilename: String?) {
        add(scan: scan, imageFilenames: imageFilename.map { [$0] } ?? [])
    }

    func add(scan: ScannedVialLabel, imageFilenames: [String]) {
        var updated = scan
        updated.labelImageFilename = imageFilenames.first
        let extras = imageFilenames.count > 1 ? Array(imageFilenames.dropFirst()) : []
        let entry = VialScanHistoryEntry(scan: updated, labelImageFilename: imageFilenames.first, extraImageFilenames: extras)
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            let overflow = entries[maxEntries...]
            for e in overflow {
                for name in e.allImageFilenames {
                    VialLabelImageStore.shared.delete(name)
                }
            }
            entries = Array(entries.prefix(maxEntries))
        }
    }

    func remove(_ entry: VialScanHistoryEntry) {
        for name in entry.allImageFilenames {
            VialLabelImageStore.shared.delete(name)
        }
        entries.removeAll { $0.id == entry.id }
    }

    func clear() {
        for e in entries {
            for name in e.allImageFilenames { VialLabelImageStore.shared.delete(name) }
        }
        entries.removeAll()
    }
}
