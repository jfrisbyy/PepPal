import Foundation
import HealthKit

nonisolated struct JourneyMapDay: Codable, Sendable {
    let date: Date
    var steps: Int?
    var activeCalories: Double?
    var sleepHours: Double?
    var hrv: Double?
    var restingHeartRate: Double?
    var weightLbs: Double?
    var workoutCount: Int?
    var workoutMinutes: Double?
}

nonisolated struct JourneyMapStagingSnapshot: Codable, Sendable {
    let stagedAt: Date
    let days: [JourneyMapDay]
}

/// Stages the last 90 days of HealthKit signals into a local JSON cache so the
/// Journey Map chapter and morning brief can render with real history on day one.
/// Pure on-device storage — nothing transmitted unless the user enables cloud sync.
@MainActor
enum JourneyMapStagingStore {
    private static let filename = "journey_map_staging.json"

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent(filename)
    }

    static func load() -> JourneyMapStagingSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try? dec.decode(JourneyMapStagingSnapshot.self, from: data)
    }

    static func save(_ snapshot: JourneyMapStagingSnapshot) {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        guard let data = try? enc.encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
        HealthKitConnectFlags.didStage90Days = false
    }

    /// True when the staging snapshot is missing or older than 24h.
    /// Used by home-screen first render to re-stage if the user granted
    /// HealthKit permission outside of the Connect chapter (e.g. revoked
    /// during onboarding then re-granted from Settings later).
    static var isStale: Bool {
        guard let snapshot = load() else { return true }
        return Date().timeIntervalSince(snapshot.stagedAt) > 60 * 60 * 24
    }

    /// Re-stages the last 90 days when (a) HealthKit is authorized and (b)
    /// the cache is missing or stale. Cheap to call on every home first-render
    /// because it short-circuits when the snapshot is fresh.
    static func stageIfStale() async {
        let hk = HealthKitService.shared
        guard hk.isAvailable, hk.isAuthorized else { return }
        guard isStale else { return }
        await stageLast90Days()
        HealthKitConnectFlags.didStage90Days = true
    }

    /// Pulls the last 90 days of weight, workouts, sleep, HRV, and resting heart rate
    /// from HealthKit and writes them to local storage. Idempotent and safe to call
    /// after a successful authorization grant.
    static func stageLast90Days() async {
        let hk = HealthKitService.shared
        guard hk.isAvailable, hk.isAuthorized else { return }

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var days: [JourneyMapDay] = []

        for offset in (0..<90).reversed() {
            guard let date = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            async let steps = hk.fetchSteps(for: date)
            async let active = hk.fetchActiveCalories(for: date)
            async let sleep = hk.fetchSleepHours(for: date)
            async let workouts = hk.fetchWorkouts(for: date)
            async let hrv = dayAverage(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), date: date)
            async let rhr = dayAverage(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), date: date)
            async let weight = dayAverage(.bodyMass, unit: .pound(), date: date)

            let (s, a, sl, wos, h, r, w) = await (steps, active, sleep, workouts, hrv, rhr, weight)
            let totalMinutes = wos.reduce(0.0) { $0 + $1.duration / 60.0 }
            days.append(JourneyMapDay(
                date: date,
                steps: s > 0 ? s : nil,
                activeCalories: a > 0 ? a : nil,
                sleepHours: sl > 0 ? sl : nil,
                hrv: h,
                restingHeartRate: r,
                weightLbs: w,
                workoutCount: wos.isEmpty ? nil : wos.count,
                workoutMinutes: totalMinutes > 0 ? totalMinutes : nil
            ))
        }

        save(JourneyMapStagingSnapshot(stagedAt: Date(), days: days))
    }

    private static func dayAverage(_ id: HKQuantityTypeIdentifier, unit: HKUnit, date: Date) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else { return nil }
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { cont in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, result, _ in
                let v = result?.averageQuantity()?.doubleValue(for: unit)
                cont.resume(returning: v)
            }
            HKHealthStore().execute(query)
        }
    }
}

/// Small UserDefaults-backed flags so we never re-prompt automatically and can
/// surface a soft "Connect Apple Health" nudge on home empty states.
nonisolated enum HealthKitConnectFlags {
    private static let promptedKey = "peppal.healthkit.connect.prompted.v1"
    private static let deniedKey = "peppal.healthkit.connect.denied.v1"
    private static let stagedKey = "peppal.healthkit.connect.staged.v1"

    static var hasBeenPrompted: Bool {
        get { UserDefaults.standard.bool(forKey: promptedKey) }
        set { UserDefaults.standard.set(newValue, forKey: promptedKey) }
    }

    static var wasDenied: Bool {
        get { UserDefaults.standard.bool(forKey: deniedKey) }
        set { UserDefaults.standard.set(newValue, forKey: deniedKey) }
    }

    static var didStage90Days: Bool {
        get { UserDefaults.standard.bool(forKey: stagedKey) }
        set { UserDefaults.standard.set(newValue, forKey: stagedKey) }
    }
}
