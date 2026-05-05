import Foundation
import HealthKit

nonisolated struct SleepNight: Identifiable, Sendable {
    let id: UUID = UUID()
    let date: Date
    let totalHours: Double
    let deepHours: Double
    let remHours: Double
    let coreHours: Double
    let awakeHours: Double
}

nonisolated struct RecoveryReading: Identifiable, Sendable {
    let id: UUID = UUID()
    let date: Date
    let hrv: Double?
    let restingHR: Double?
}

nonisolated struct TrainingSleepCorrelation: Sendable {
    let weeklyVolume: Int
    let weeklySessions: Int
    let averageSleepHours: Double
    let averageHRV: Double?
    let insight: String
    let severity: Severity

    enum Severity: Sendable { case good, watch, warn }
}

@Observable
final class SleepRecoveryService {
    static let shared = SleepRecoveryService()

    var recentNights: [SleepNight] = []
    var recoveryReadings: [RecoveryReading] = []
    var isLoading: Bool = false
    var correlation: TrainingSleepCorrelation?

    private let healthStore = HKHealthStore()

    private init() {}

    func authorize() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        var read: Set<HKObjectType> = []
        if let s = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { read.insert(s) }
        if let h = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { read.insert(h) }
        if let r = HKObjectType.quantityType(forIdentifier: .restingHeartRate) { read.insert(r) }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: read)
            return true
        } catch {
            return false
        }
    }

    func loadRecent(days: Int = 14) async {
        isLoading = true
        defer { isLoading = false }
        async let nights = fetchNights(days: days)
        async let recovery = fetchRecovery(days: days)
        let (n, r) = await (nights, recovery)
        recentNights = n
        recoveryReadings = r
        correlation = await computeCorrelation()
    }

    private func computeCorrelation() async -> TrainingSleepCorrelation? {
        let sleep7 = averageSleep7d
        guard sleep7 > 0 else { return nil }

        var weeklyVolume = 0
        var weeklySessions = 0
        if let userId = try? AuthService.shared.currentUserId() {
            if let workouts = try? await WorkoutService.shared.fetchWorkouts(userId: userId, limit: 50) {
                let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                let recent = workouts.compactMap { WorkoutService.shared.toWorkoutHistoryDetail($0) }
                    .filter { $0.date >= weekStart }
                weeklySessions = recent.count
                weeklyVolume = recent.reduce(0) { $0 + $1.totalVolume }
            }
        }

        let hrv = averageHRV7d
        let highVolume = weeklyVolume >= 40_000 || weeklySessions >= 5
        let lowSleep = sleep7 < 7.0

        let severity: TrainingSleepCorrelation.Severity
        let insight: String
        if highVolume && lowSleep {
            severity = .warn
            insight = "High training volume (\(weeklySessions) sessions) combined with \(String(format: "%.1f", sleep7))h average sleep. Recovery is likely impaired — prioritize sleep or reduce load this week."
        } else if highVolume {
            severity = .watch
            insight = "Volume is up (\(weeklySessions) sessions). Keep sleep above 7.5h to support recovery."
        } else if lowSleep {
            severity = .watch
            insight = "Sleep is averaging \(String(format: "%.1f", sleep7))h — below the 7h baseline most lifters need for optimal recovery."
        } else if let hrv, hrv < 30 {
            severity = .watch
            insight = "HRV trending low (\(Int(hrv))ms avg). Consider a lighter session if fatigue is compounding."
        } else {
            severity = .good
            insight = "Sleep and training load are in a healthy balance. Keep it consistent."
        }

        return TrainingSleepCorrelation(
            weeklyVolume: weeklyVolume,
            weeklySessions: weeklySessions,
            averageSleepHours: sleep7,
            averageHRV: hrv,
            insight: insight,
            severity: severity
        )
    }

    private func fetchNights(days: Int) async -> [SleepNight] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -days, to: cal.startOfDay(for: Date())) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else {
                    cont.resume(returning: [])
                    return
                }
                var buckets: [Date: (total: Double, deep: Double, rem: Double, core: Double, awake: Double)] = [:]
                for s in samples {
                    let duration = s.endDate.timeIntervalSince(s.startDate) / 3600.0
                    let dayKey: Date
                    if cal.component(.hour, from: s.startDate) < 12 {
                        dayKey = cal.startOfDay(for: s.startDate)
                    } else if let next = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: s.startDate)) {
                        dayKey = next
                    } else {
                        dayKey = cal.startOfDay(for: s.startDate)
                    }
                    var bucket = buckets[dayKey] ?? (0, 0, 0, 0, 0)
                    switch s.value {
                    case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                        bucket.deep += duration; bucket.total += duration
                    case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                        bucket.rem += duration; bucket.total += duration
                    case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                        bucket.core += duration; bucket.total += duration
                    case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                        bucket.core += duration; bucket.total += duration
                    case HKCategoryValueSleepAnalysis.awake.rawValue:
                        bucket.awake += duration
                    default: break
                    }
                    buckets[dayKey] = bucket
                }
                let nights = buckets
                    .filter { $0.value.total > 0 }
                    .sorted { $0.key > $1.key }
                    .map { SleepNight(date: $0.key, totalHours: $0.value.total, deepHours: $0.value.deep, remHours: $0.value.rem, coreHours: $0.value.core, awakeHours: $0.value.awake) }
                cont.resume(returning: nights)
            }
            healthStore.execute(q)
        }
    }

    private func fetchRecovery(days: Int) async -> [RecoveryReading] {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -days, to: cal.startOfDay(for: Date())) else { return [] }

        async let hrv = fetchDaily(identifier: .heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli), start: start)
        async let rhr = fetchDaily(identifier: .restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), start: start)
        let (hrvMap, rhrMap) = await (hrv, rhr)

        var keys = Set(hrvMap.keys)
        keys.formUnion(rhrMap.keys)
        return keys.sorted(by: >).map { date in
            RecoveryReading(date: date, hrv: hrvMap[date], restingHR: rhrMap[date])
        }
    }

    private func fetchDaily(identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date) async -> [Date: Double] {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return [:] }
        let cal = Calendar.current
        var comps = DateComponents()
        comps.day = 1

        return await withCheckedContinuation { cont in
            let q = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate),
                options: .discreteAverage,
                anchorDate: start,
                intervalComponents: comps
            )
            q.initialResultsHandler = { _, results, _ in
                var out: [Date: Double] = [:]
                results?.enumerateStatistics(from: start, to: Date()) { stat, _ in
                    if let avg = stat.averageQuantity() {
                        out[cal.startOfDay(for: stat.startDate)] = avg.doubleValue(for: unit)
                    }
                }
                cont.resume(returning: out)
            }
            self.healthStore.execute(q)
        }
    }

    var averageSleep7d: Double {
        let recent = recentNights.prefix(7)
        guard !recent.isEmpty else { return 0 }
        return recent.reduce(0) { $0 + $1.totalHours } / Double(recent.count)
    }

    var averageHRV7d: Double? {
        let vals = recoveryReadings.prefix(7).compactMap(\.hrv)
        guard !vals.isEmpty else { return nil }
        return vals.reduce(0, +) / Double(vals.count)
    }
}
