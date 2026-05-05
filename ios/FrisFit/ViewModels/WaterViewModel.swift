import SwiftUI

@Observable
final class WaterViewModel {
    @MainActor static let shared = WaterViewModel()

    enum Unit: String, CaseIterable, Identifiable {
        case oz, ml
        var id: String { rawValue }
        var label: String { self == .oz ? "oz" : "ml" }
    }

    var entriesByDay: [String: [WaterEntry]] = [:]
    var dailyGoalMl: Int = 2500
    var isLoading: Bool = false
    var unit: Unit = .oz

    private let goalKey = "com.frisfit.waterGoalMl"
    private let localKey = "com.frisfit.waterEntries.local"
    private let unitKey = "com.frisfit.waterUnit"
    private var loadedDays: Set<String> = []

    private init() {
        if let saved = UserDefaults.standard.object(forKey: goalKey) as? Int, saved > 0 {
            dailyGoalMl = saved
        }
        if let savedUnit = UserDefaults.standard.string(forKey: unitKey), let u = Unit(rawValue: savedUnit) {
            unit = u
        }
        loadLocal()
    }

    static func dayKey(for date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    func entries(for date: Date) -> [WaterEntry] {
        entriesByDay[Self.dayKey(for: date)] ?? []
    }

    func totalMl(for date: Date) -> Int {
        entries(for: date).reduce(0) { $0 + $1.amountMl }
    }

    func progress(for date: Date) -> Double {
        guard dailyGoalMl > 0 else { return 0 }
        return min(Double(totalMl(for: date)) / Double(dailyGoalMl), 1.0)
    }

    func setGoal(_ ml: Int) {
        dailyGoalMl = max(500, ml)
        UserDefaults.standard.set(dailyGoalMl, forKey: goalKey)
    }

    func setUnit(_ u: Unit) {
        unit = u
        UserDefaults.standard.set(u.rawValue, forKey: unitKey)
    }

    /// Re-reads goal + unit from UserDefaults. Called after remote
    /// preferences hydrate on launch so this observable reflects the cloud
    /// values without requiring a full relaunch.
    func reloadPreferencesFromDefaults() {
        if let saved = UserDefaults.standard.object(forKey: goalKey) as? Int, saved > 0 {
            dailyGoalMl = saved
        }
        if let savedUnit = UserDefaults.standard.string(forKey: unitKey), let u = Unit(rawValue: savedUnit) {
            unit = u
        }
    }

    func add(amountMl: Int, date: Date = Date()) {
        let entry = WaterEntry(amountMl: amountMl, loggedAt: date)
        let key = Self.dayKey(for: date)
        var arr = entriesByDay[key] ?? []
        arr.append(entry)
        entriesByDay[key] = arr
        saveLocal()
        NotificationCenter.default.post(name: .waterIntakeChanged, object: nil)

        guard AuthService.shared.authState == .signedIn,
              let userId = try? AuthService.shared.currentUserId() else { return }

        let mutationId = entry.id.uuidString
        if !NetworkMonitor.shared.isOnline {
            let payload = WaterService.shared.insertPayload(userId: userId, amountMl: amountMl, loggedAt: date, clientMutationId: mutationId)
            OfflineQueue.shared.enqueueInsert(table: "water_entries", payload: payload, kind: "Water — \(amountMl) ml", clientMutationId: mutationId)
            return
        }

        Task { @MainActor in
            do {
                let created = try await WaterService.shared.insert(userId: userId, amountMl: amountMl, loggedAt: date)
                if var arr = entriesByDay[key], let idx = arr.firstIndex(where: { $0.id == entry.id }) {
                    arr[idx].supabaseId = created.id
                    entriesByDay[key] = arr
                    saveLocal()
                }
            } catch {
                let payload = WaterService.shared.insertPayload(userId: userId, amountMl: amountMl, loggedAt: date, clientMutationId: mutationId)
                OfflineQueue.shared.enqueueInsert(table: "water_entries", payload: payload, kind: "Water — \(amountMl) ml", clientMutationId: mutationId)
            }
        }
    }

    func update(_ entry: WaterEntry, amountMl: Int, loggedAt: Date) {
        let oldKey = Self.dayKey(for: entry.loggedAt)
        let newKey = Self.dayKey(for: loggedAt)
        let updated = WaterEntry(id: entry.id, amountMl: amountMl, loggedAt: loggedAt, supabaseId: entry.supabaseId)

        if oldKey == newKey {
            if var arr = entriesByDay[oldKey], let idx = arr.firstIndex(where: { $0.id == entry.id }) {
                arr[idx] = updated
                entriesByDay[oldKey] = arr
            }
        } else {
            entriesByDay[oldKey]?.removeAll { $0.id == entry.id }
            var arr = entriesByDay[newKey] ?? []
            arr.append(updated)
            entriesByDay[newKey] = arr
        }
        saveLocal()
        NotificationCenter.default.post(name: .waterIntakeChanged, object: nil)

        if let sid = entry.supabaseId {
            Task {
                do {
                    try await WaterService.shared.update(id: sid, amountMl: amountMl, loggedAt: loggedAt)
                } catch {
                    print("[WaterVM] update error: \(error)")
                }
            }
        }
    }

    func remove(_ entry: WaterEntry) {
        let key = Self.dayKey(for: entry.loggedAt)
        entriesByDay[key]?.removeAll { $0.id == entry.id }
        saveLocal()
        NotificationCenter.default.post(name: .waterIntakeChanged, object: nil)

        if let sid = entry.supabaseId {
            if !NetworkMonitor.shared.isOnline {
                OfflineQueue.shared.enqueueDelete(table: "water_entries", column: "id", value: sid, kind: "Remove water entry")
                return
            }
            Task {
                do {
                    try await WaterService.shared.delete(id: sid)
                } catch {
                    OfflineQueue.shared.enqueueDelete(table: "water_entries", column: "id", value: sid, kind: "Remove water entry")
                }
            }
        }
    }

    func load(date: Date) async {
        guard AuthService.shared.authState == .signedIn else { return }
        let key = Self.dayKey(for: date)
        guard !loadedDays.contains(key) else { return }
        guard let userId = try? AuthService.shared.currentUserId() else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let remote = try await WaterService.shared.fetch(userId: userId, date: date)
            let mapped: [WaterEntry] = remote.compactMap { r in
                guard let s = r.logged_at, let d = ISO8601DateFormatter.shared.date(from: s) else { return nil }
                return WaterEntry(
                    id: UUID(uuidString: r.id ?? "") ?? UUID(),
                    amountMl: r.amount_ml,
                    loggedAt: d,
                    supabaseId: r.id
                )
            }
            let existingUnsynced = (entriesByDay[key] ?? []).filter { $0.supabaseId == nil }
            entriesByDay[key] = mapped + existingUnsynced
            loadedDays.insert(key)
            saveLocal()
        } catch {
            print("[WaterVM] load error: \(error)")
        }
    }

    private func saveLocal() {
        guard let data = try? JSONEncoder().encode(entriesByDay) else { return }
        UserDefaults.standard.set(data, forKey: localKey)
    }

    private func loadLocal() {
        guard let data = UserDefaults.standard.data(forKey: localKey),
              let decoded = try? JSONDecoder().decode([String: [WaterEntry]].self, from: data) else { return }
        entriesByDay = decoded
    }
}

nonisolated extension ISO8601DateFormatter {
    static let shared: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
