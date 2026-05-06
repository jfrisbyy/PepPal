import Foundation

nonisolated struct HealthKitScalarSnapshot: Codable, Sendable {
    var steps: Int = 0
    var activeCalories: Double = 0
    var restingCalories: Double = 0
    var heartRate: Double = 0
    var distanceWalking: Double = 0
    var flightsClimbed: Int = 0
    var exerciseMinutes: Double = 0
    var standHours: Int = 0
    var sleepHours: Double = 0
    var bodyWeight: Double? = nil
    var vo2Max: Double? = nil

    var hrv: Double? = nil
    var restingHeartRate: Double? = nil
    var respiratoryRate: Double? = nil
    var oxygenSaturation: Double? = nil
    var walkingHeartRateAverage: Double? = nil
    var bodyFatPercentage: Double? = nil
    var leanBodyMass: Double? = nil
    var waistCircumference: Double? = nil
    var bmi: Double? = nil
    var mindfulMinutesToday: Double = 0

    var dietaryEnergyConsumed: Double = 0
    var dietaryProtein: Double = 0
    var dietaryCarbs: Double = 0
    var dietaryFat: Double = 0
    var dietaryWater: Double = 0

    var bloodGlucose: Double? = nil
    var bloodPressureSystolic: Double? = nil
    var bloodPressureDiastolic: Double? = nil
    var bodyTemperature: Double? = nil

    var savedAt: Date = Date()
}

nonisolated struct HealthSeriesCachePoint: Codable, Sendable {
    let date: Date
    let value: Double
    let min: Double
    let max: Double
}

nonisolated struct HealthSleepCachePoint: Codable, Sendable {
    let date: Date
    let asleep: Double
    let deep: Double
    let rem: Double
    let core: Double
}

nonisolated struct HealthDetailCacheSnapshot: Codable, Sendable {
    var period: String = "W"

    var stepsSeries: [HealthSeriesCachePoint] = []
    var activeCalSeries: [HealthSeriesCachePoint] = []
    var restingCalSeries: [HealthSeriesCachePoint] = []
    var distanceSeries: [HealthSeriesCachePoint] = []
    var flightsSeries: [HealthSeriesCachePoint] = []
    var exerciseSeries: [HealthSeriesCachePoint] = []

    var heartRateSeries: [HealthSeriesCachePoint] = []
    var restingHRSeries: [HealthSeriesCachePoint] = []
    var hrvSeries: [HealthSeriesCachePoint] = []
    var walkingHRSeries: [HealthSeriesCachePoint] = []

    var weightSeries: [HealthSeriesCachePoint] = []
    var bodyFatSeries: [HealthSeriesCachePoint] = []
    var leanMassSeries: [HealthSeriesCachePoint] = []
    var bmiSeries: [HealthSeriesCachePoint] = []
    var waistSeries: [HealthSeriesCachePoint] = []

    var respiratoryRateSeries: [HealthSeriesCachePoint] = []
    var oxygenSaturationSeries: [HealthSeriesCachePoint] = []
    var bodyTempSeries: [HealthSeriesCachePoint] = []
    var bloodGlucoseSeries: [HealthSeriesCachePoint] = []
    var systolicSeries: [HealthSeriesCachePoint] = []
    var diastolicSeries: [HealthSeriesCachePoint] = []
    var vo2MaxSeries: [HealthSeriesCachePoint] = []

    var hydrationSeries: [HealthSeriesCachePoint] = []
    var dietaryEnergySeries: [HealthSeriesCachePoint] = []
    var mindfulSeries: [HealthSeriesCachePoint] = []

    var sleepNights: [HealthSleepCachePoint] = []

    var savedAt: Date = Date()
}

/// Per-user, disk-backed cache for HealthKit scalars and detail series.
///
/// Series payloads can be large (~hundreds of KB across all metrics × periods),
/// which makes them poor citizens of `UserDefaults` — every read pages the
/// entire prefs plist into memory. Storing them on disk under the per-user
/// folder also gives us a clean atomic purge on sign-out.
///
/// Calls without a signed-in user fall back to a sentinel folder so no-op
/// pre-auth reads still work; the sentinel is purged alongside everything
/// else by `LocalStateResetCoordinator.purgeUserScopedState`.
nonisolated enum HealthKitCache {
    private static let scalarsFile = "healthkit.scalars.v1"
    private static func seriesFile(for period: String) -> String {
        "healthkit.series.v1.\(period)"
    }

    private static func currentUserId() -> String {
        ((try? AuthService.shared.currentUserId()) ?? "").lowercased()
    }

    static func loadScalars() -> HealthKitScalarSnapshot? {
        let uid = currentUserId()
        guard !uid.isEmpty else { return nil }
        return PerUserDiskStore.load(HealthKitScalarSnapshot.self, userId: uid, name: scalarsFile)
    }

    static func saveScalars(_ snapshot: HealthKitScalarSnapshot) {
        let uid = currentUserId()
        guard !uid.isEmpty else { return }
        PerUserDiskStore.save(snapshot, userId: uid, name: scalarsFile)
    }

    static func loadDetail(period: String) -> HealthDetailCacheSnapshot? {
        let uid = currentUserId()
        guard !uid.isEmpty else { return nil }
        return PerUserDiskStore.load(HealthDetailCacheSnapshot.self, userId: uid, name: seriesFile(for: period))
    }

    static func saveDetail(_ snapshot: HealthDetailCacheSnapshot, period: String) {
        let uid = currentUserId()
        guard !uid.isEmpty else { return }
        PerUserDiskStore.save(snapshot, userId: uid, name: seriesFile(for: period))
    }

    /// One-time migration: pull legacy UserDefaults blobs forward to disk and
    /// drop the originals. Idempotent — safe to call on every launch.
    static func migrateFromUserDefaultsIfNeeded() {
        let defaults = UserDefaults.standard
        let uid = currentUserId()
        guard !uid.isEmpty else { return }
        let scalarKey = "healthkit.cache.scalars.v1"
        if let data = defaults.data(forKey: scalarKey),
           let snap = try? JSONDecoder().decode(HealthKitScalarSnapshot.self, from: data) {
            PerUserDiskStore.save(snap, userId: uid, name: scalarsFile)
            defaults.removeObject(forKey: scalarKey)
        }
        for period in ["D", "W", "M", "6M", "Y"] {
            let key = "healthkit.cache.series.v1.\(period)"
            if let data = defaults.data(forKey: key),
               let snap = try? JSONDecoder().decode(HealthDetailCacheSnapshot.self, from: data) {
                PerUserDiskStore.save(snap, userId: uid, name: seriesFile(for: period))
                defaults.removeObject(forKey: key)
            }
        }
    }
}
