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

nonisolated enum HealthKitCache {
    private static let scalarKey = "healthkit.cache.scalars.v1"
    private static func seriesKey(for period: String) -> String {
        "healthkit.cache.series.v1.\(period)"
    }

    static func loadScalars() -> HealthKitScalarSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: scalarKey) else { return nil }
        return try? JSONDecoder().decode(HealthKitScalarSnapshot.self, from: data)
    }

    static func saveScalars(_ snapshot: HealthKitScalarSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: scalarKey)
    }

    static func loadDetail(period: String) -> HealthDetailCacheSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: seriesKey(for: period)) else { return nil }
        return try? JSONDecoder().decode(HealthDetailCacheSnapshot.self, from: data)
    }

    static func saveDetail(_ snapshot: HealthDetailCacheSnapshot, period: String) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: seriesKey(for: period))
    }
}
