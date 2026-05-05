import SwiftUI

nonisolated enum VialStorageLocation: String, Codable, CaseIterable, Sendable, Identifiable {
    case freezer = "Freezer"
    case fridge = "Fridge"
    case room = "Room Temp"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .freezer: return "snowflake"
        case .fridge: return "thermometer.snowflake"
        case .room: return "house.fill"
        }
    }
}

nonisolated struct Vial: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    var compoundName: String
    var vialSizeMg: Double
    var diluentMl: Double?
    var reconstitutedOn: Date?
    var storage: VialStorageLocation
    var lotNumber: String
    var vialNumber: String
    var expirationDate: Date?
    var typicalDoseMcg: Double
    var mcgUsed: Double
    var budDays: Int
    var createdAt: Date
    var labelImageFilename: String?

    init(
        id: UUID = UUID(),
        compoundName: String,
        vialSizeMg: Double,
        diluentMl: Double? = nil,
        reconstitutedOn: Date? = nil,
        storage: VialStorageLocation = .fridge,
        lotNumber: String = "",
        vialNumber: String = "",
        expirationDate: Date? = nil,
        typicalDoseMcg: Double,
        mcgUsed: Double = 0,
        budDays: Int = 30,
        createdAt: Date = Date(),
        labelImageFilename: String? = nil
    ) {
        self.id = id
        self.compoundName = compoundName
        self.vialSizeMg = vialSizeMg
        self.diluentMl = diluentMl
        self.reconstitutedOn = reconstitutedOn
        self.storage = storage
        self.lotNumber = lotNumber
        self.vialNumber = vialNumber
        self.expirationDate = expirationDate
        self.typicalDoseMcg = typicalDoseMcg
        self.mcgUsed = mcgUsed
        self.budDays = budDays
        self.createdAt = createdAt
        self.labelImageFilename = labelImageFilename
    }

    var totalMcg: Double { vialSizeMg * 1000 }
    var mcgRemaining: Double { max(0, totalMcg - mcgUsed) }
    var fillFraction: Double { totalMcg > 0 ? mcgRemaining / totalMcg : 0 }
    var dosesRemaining: Int {
        guard typicalDoseMcg > 0 else { return 0 }
        return Int(mcgRemaining / typicalDoseMcg)
    }
    var totalDoses: Int {
        guard typicalDoseMcg > 0 else { return 0 }
        return Int(totalMcg / typicalDoseMcg)
    }

    var budDate: Date? {
        guard let recon = reconstitutedOn else { return nil }
        return Calendar.current.date(byAdding: .day, value: budDays, to: recon)
    }

    var daysUntilBUD: Int? {
        guard let bud = budDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: bud).day
    }

    var isReconstituted: Bool { reconstitutedOn != nil }
    var isExpired: Bool {
        if let days = daysUntilBUD, days < 0 { return true }
        if let exp = expirationDate, exp < Date() { return true }
        return false
    }
    var isLowStock: Bool { dosesRemaining > 0 && dosesRemaining <= 3 }
    var isEmpty: Bool { dosesRemaining == 0 && mcgUsed > 0 }

    var statusColor: Color {
        if isExpired { return .red }
        if isEmpty { return PepTheme.textSecondary }
        if isLowStock { return PepTheme.amber }
        if let days = daysUntilBUD, days <= 3 { return .red }
        if let days = daysUntilBUD, days <= 7 { return PepTheme.amber }
        return PepTheme.teal
    }

    var statusLabel: String {
        if isExpired { return "Expired" }
        if isEmpty { return "Empty" }
        if isLowStock { return "Low stock" }
        if let days = daysUntilBUD {
            if days <= 0 { return "BUD today" }
            return "\(days)d until BUD"
        }
        if !isReconstituted { return "Unmixed" }
        return "Good"
    }
}

@Observable
@MainActor
final class VialInventoryStore {
    static let shared = VialInventoryStore()

    private let storageKey = "peppal.vialInventory.v1"

    var vials: [Vial] = [] {
        didSet { save() }
    }

    private(set) var hasHydratedFromCloud: Bool = false

    private init() {
        load()
        Task { await self.hydrateFromCloud() }
    }

    func hydrateFromCloud() async {
        let remote = await VialSyncService.shared.fetchAll()
        await MainActor.run {
            if !remote.isEmpty {
                // Merge: prefer remote rows, but keep any local-only vials (queued for upload below).
                let remoteIds = Set(remote.map(\.id))
                let localOnly = self.vials.filter { !remoteIds.contains($0.id) }
                self.vials = remote + localOnly
                for v in localOnly { Task { await VialSyncService.shared.upsert(v) } }
            } else if !self.vials.isEmpty {
                // First-ever sync from local-only state: push everything up.
                for v in self.vials { Task { await VialSyncService.shared.upsert(v) } }
            }
            self.hasHydratedFromCloud = true
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Vial].self, from: data) else { return }
        vials = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(vials) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    func add(_ vial: Vial) {
        vials.insert(vial, at: 0)
        Task { await VialSyncService.shared.upsert(vial) }
    }

    func update(_ vial: Vial) {
        guard let idx = vials.firstIndex(where: { $0.id == vial.id }) else { return }
        vials[idx] = vial
        Task { await VialSyncService.shared.upsert(vial) }
    }

    func remove(_ vial: Vial) {
        vials.removeAll { $0.id == vial.id }
        let id = vial.id
        Task { await VialSyncService.shared.delete(clientId: id) }
    }

    func recordDose(vialId: UUID, mcg: Double) {
        guard let idx = vials.firstIndex(where: { $0.id == vialId }) else { return }
        vials[idx].mcgUsed += mcg
        let updated = vials[idx]
        Task { await VialSyncService.shared.upsert(updated) }
    }

    func activeVials(for compoundName: String) -> [Vial] {
        vials.filter { $0.compoundName == compoundName && !$0.isExpired && !$0.isEmpty }
    }

    var hasAnyVials: Bool { !vials.isEmpty }
    var lowStockCount: Int { vials.filter { $0.isLowStock || $0.isEmpty || $0.isExpired }.count }
}

nonisolated enum ReconHelper: Sendable {
    static func defaultBUDDays(for compoundName: String) -> Int {
        let lower = compoundName.lowercased()
        if lower.contains("tesamorelin") { return 7 }
        if lower.contains("tb-500") || lower.contains("tb500") { return 14 }
        if lower.contains("semaglutide") { return 56 }
        if lower.contains("tirzepatide") { return 30 }
        if lower.contains("retatrutide") { return 30 }
        if lower.contains("kpv") { return 45 }
        return 30
    }

    static func parseFirstNumber(_ s: String) -> Double? {
        let pattern = #"(\d+(?:\.\d+)?)"#
        guard let range = s.range(of: pattern, options: .regularExpression) else { return nil }
        return Double(s[range])
    }
}
