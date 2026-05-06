import SwiftUI
import HealthKit

@Observable
@MainActor
final class SleepLogViewModel {
    static let shared = SleepLogViewModel()

    /// Manual entries keyed by night (yyyy-MM-dd).
    var manualByNight: [String: ManualSleepLog] = [:]
    var isLoading: Bool = false
    var hasLoadedRemote: Bool = false

    private let localKey = "com.frisfit.manualSleepLogs.v1"

    private init() {
        loadLocal()
    }

    // MARK: - Lookups

    static func nightKey(for date: Date) -> String {
        ManualSleepLogService.nightString(for: date)
    }

    func manualLog(for date: Date) -> ManualSleepLog? {
        manualByNight[Self.nightKey(for: date)]
    }

    var recentManualLogs: [ManualSleepLog] {
        manualByNight.values.sorted { $0.night > $1.night }
    }

    /// Last night = today's night key (sleep logged when you wake up today).
    func lastNightLog() -> ManualSleepLog? {
        manualLog(for: Date()) ?? manualLog(for: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
    }

    // MARK: - Mutations

    @discardableResult
    func save(_ log: ManualSleepLog) -> ManualSleepLog {
        var stored = log
        let key = Self.nightKey(for: log.night)
        if let existing = manualByNight[key], stored.supabaseId == nil {
            stored.supabaseId = existing.supabaseId
        }
        manualByNight[key] = stored
        saveLocal()
        NotificationCenter.default.post(name: .sleepLogChanged, object: nil)

        guard AuthService.shared.authState == .signedIn,
              let userId = try? AuthService.shared.currentUserId() else { return stored }

        Task { @MainActor in
            do {
                let row = try await ManualSleepLogService.shared.upsert(userId: userId, log: stored)
                if var current = manualByNight[key] {
                    current.supabaseId = row.id
                    manualByNight[key] = current
                    saveLocal()
                }
            } catch {
                print("[SleepLogVM] upsert error: \(error)")
            }
        }
        return stored
    }

    func remove(_ log: ManualSleepLog) {
        let key = Self.nightKey(for: log.night)
        manualByNight.removeValue(forKey: key)
        saveLocal()
        NotificationCenter.default.post(name: .sleepLogChanged, object: nil)

        guard let sid = log.supabaseId else { return }
        Task {
            do {
                try await ManualSleepLogService.shared.delete(id: sid)
            } catch {
                print("[SleepLogVM] delete error: \(error)")
            }
        }
    }

    // MARK: - Loading

    func loadIfNeeded() async {
        guard !hasLoadedRemote else { return }
        await load()
    }

    func load() async {
        guard AuthService.shared.authState == .signedIn,
              let userId = try? AuthService.shared.currentUserId() else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let rows = try await ManualSleepLogService.shared.fetch(userId: userId, days: 60)
            var merged = manualByNight
            for r in rows {
                guard let nightDate = ManualSleepLogService.parseNight(r.night) else { continue }
                let log = ManualSleepLog(
                    id: UUID(uuidString: r.id ?? "") ?? UUID(),
                    night: nightDate,
                    bedtime: ManualSleepLogService.parseDateTime(r.bedtime),
                    wakeTime: ManualSleepLogService.parseDateTime(r.wake_time),
                    hours: r.hours,
                    quality: r.quality,
                    notes: r.notes,
                    supabaseId: r.id
                )
                merged[ManualSleepLogService.nightString(for: nightDate)] = log
            }
            manualByNight = merged
            hasLoadedRemote = true
            saveLocal()
            NotificationCenter.default.post(name: .sleepLogChanged, object: nil)
        } catch {
            print("[SleepLogVM] load error: \(error)")
        }
    }

    // MARK: - Persistence

    private func saveLocal() {
        guard let data = try? JSONEncoder().encode(manualByNight) else { return }
        UserDefaults.standard.set(data, forKey: localKey)
    }

    private func loadLocal() {
        guard let data = UserDefaults.standard.data(forKey: localKey),
              let decoded = try? JSONDecoder().decode([String: ManualSleepLog].self, from: data) else { return }
        manualByNight = decoded
    }

    // MARK: - Display helpers

    /// Best available "last night" reading combining HealthKit + manual.
    /// Returns hours, quality (optional), and a source label.
    struct LastNightReading: Sendable {
        let hours: Double
        let quality: Int?
        let source: Source
        let manualLog: ManualSleepLog?

        enum Source: Sendable { case appleHealth, manual, none }
    }

    func lastNightReading(healthHours: Double) -> LastNightReading {
        let manual = lastNightLog()
        if healthHours > 0 {
            return LastNightReading(hours: healthHours, quality: manual?.quality, source: .appleHealth, manualLog: manual)
        }
        if let manual {
            return LastNightReading(hours: manual.hours, quality: manual.quality, source: .manual, manualLog: manual)
        }
        return LastNightReading(hours: 0, quality: nil, source: .none, manualLog: nil)
    }

    /// Build a 7-night history for the mini chart.
    /// Prefers HealthKit hours; falls back to manual hours when HealthKit is empty.
    struct NightPoint: Identifiable, Sendable {
        let id: String
        let date: Date
        let hours: Double
        let isManual: Bool
    }

    func recent7Nights(healthByDate: [Date: Double]) -> [NightPoint] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var out: [NightPoint] = []
        for offset in (0..<7).reversed() {
            guard let d = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let key = Self.nightKey(for: d)
            let hkHours = healthByDate[d] ?? 0
            let manualHours = manualByNight[key]?.hours ?? 0
            let hours = hkHours > 0 ? hkHours : manualHours
            out.append(NightPoint(id: key, date: d, hours: hours, isManual: hkHours == 0 && manualHours > 0))
        }
        return out
    }
}

extension Notification.Name {
    static let sleepLogChanged = Notification.Name("com.frisfit.sleepLogChanged")
}
