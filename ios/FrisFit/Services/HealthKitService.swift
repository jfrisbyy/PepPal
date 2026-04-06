import Foundation
import HealthKit

@Observable
final class HealthKitService {
    static let shared = HealthKitService()

    private let healthStore = HKHealthStore()

    var isAuthorized: Bool = false
    var isAvailable: Bool = HKHealthStore.isHealthDataAvailable()

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
    var workoutsToday: [HKWorkout] = []
    var vo2Max: Double? = nil

    var liveHeartRate: Int = 0
    var liveCadence: Int = 0
    var liveActiveCalories: Double = 0
    var liveDistanceWalkingRunning: Double = 0
    var liveDistanceCycling: Double = 0
    var liveDistanceSwimming: Double = 0

    private var heartRateQuery: HKAnchoredObjectQuery?
    private var cadenceQuery: HKAnchoredObjectQuery?
    private var caloriesQuery: HKAnchoredObjectQuery?
    private var distanceRunQuery: HKAnchoredObjectQuery?
    private var distanceCycleQuery: HKAnchoredObjectQuery?
    private var heartRateAnchor: HKQueryAnchor?
    private var cadenceAnchor: HKQueryAnchor?
    private var caloriesAnchor: HKQueryAnchor?
    private var distanceRunAnchor: HKQueryAnchor?
    private var distanceCycleAnchor: HKQueryAnchor?

    private var heartRateSamplesCollected: [(bpm: Int, date: Date)] = []
    private var workoutStartDate: Date?

    var isHealthKitEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "healthkit_enabled") }
        set {
            UserDefaults.standard.set(newValue, forKey: "healthkit_enabled")
            if newValue {
                Task { await requestAuthorization() }
            }
        }
    }

    private let readTypes: Set<HKObjectType> = {
        var types: Set<HKObjectType> = []
        let quantityTypes: [HKQuantityTypeIdentifier] = [
            .stepCount,
            .activeEnergyBurned,
            .basalEnergyBurned,
            .heartRate,
            .distanceWalkingRunning,
            .distanceCycling,
            .distanceSwimming,
            .flightsClimbed,
            .appleExerciseTime,
            .appleStandTime,
            .bodyMass,
            .vo2Max,
            .runningStrideLength,
            .swimmingStrokeCount,
        ]
        for id in quantityTypes {
            if let t = HKObjectType.quantityType(forIdentifier: id) {
                types.insert(t)
            }
        }
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepType)
        }
        types.insert(HKObjectType.workoutType())
        return types
    }()

    private let writeTypes: Set<HKSampleType> = {
        var types: Set<HKSampleType> = []
        let quantityIds: [HKQuantityTypeIdentifier] = [
            .activeEnergyBurned,
            .distanceWalkingRunning,
            .distanceCycling,
            .distanceSwimming,
            .heartRate,
        ]
        for id in quantityIds {
            if let t = HKObjectType.quantityType(forIdentifier: id) {
                types.insert(t)
            }
        }
        types.insert(HKObjectType.workoutType())
        return types
    }()

    private init() {}

    func requestAuthorization() async {
        print("[HealthKit] requestAuthorization called")
        guard HKHealthStore.isHealthDataAvailable() else {
            print("[HealthKit] guard failed: isHealthDataAvailable is false")
            isAvailable = false
            return
        }
        isAvailable = true
        print("[HealthKit] readTypes count: \(readTypes.count), writeTypes count: \(writeTypes.count)")
        print("[HealthKit] calling healthStore.requestAuthorization (native async)")

        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
            print("[HealthKit] authorization succeeded")
            isAuthorized = true
            isHealthKitEnabled = true
            await fetchAllData()
        } catch {
            print("[HealthKit] Authorization failed: \(error.localizedDescription)")
            isAuthorized = false
        }
    }

    func fetchAllData() async {
        guard isAvailable, isAuthorized else { return }
        async let s = fetchSteps()
        async let ac = fetchActiveCalories()
        async let rc = fetchRestingCalories()
        async let hr = fetchLatestHeartRate()
        async let d = fetchDistance()
        async let fc = fetchFlightsClimbed()
        async let em = fetchExerciseMinutes()
        async let sl = fetchSleepHours()
        async let bw = fetchBodyWeight()
        async let wo = fetchTodayWorkouts()
        async let v2 = fetchVO2Max()

        let (stepsVal, activeVal, restingVal, hrVal, distVal, flightsVal, exVal, sleepVal, weightVal, workoutsVal, vo2Val) = await (s, ac, rc, hr, d, fc, em, sl, bw, wo, v2)

        steps = stepsVal
        activeCalories = activeVal
        restingCalories = restingVal
        heartRate = hrVal
        distanceWalking = distVal
        flightsClimbed = flightsVal
        exerciseMinutes = exVal
        sleepHours = sleepVal
        bodyWeight = weightVal
        workoutsToday = workoutsVal
        vo2Max = vo2Val
    }

    var totalCalories: Double {
        activeCalories + restingCalories
    }

    var distanceMiles: Double {
        distanceWalking / 1609.344
    }

    var distanceKm: Double {
        distanceWalking / 1000.0
    }

    // MARK: - Live Workout Streaming

    func startLiveHeartRateStreaming() {
        guard isAvailable, isAuthorized else { return }
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }

        stopLiveHeartRateStreaming()

        let startDate = Date()
        workoutStartDate = startDate
        heartRateSamplesCollected = []
        liveHeartRate = 0

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil, options: .strictStartDate)

        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: predicate,
            anchor: heartRateAnchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, newAnchor, _ in
            Task { @MainActor in
                self?.heartRateAnchor = newAnchor
                self?.processHeartRateSamples(samples)
            }
        }

        query.updateHandler = { [weak self] _, samples, _, newAnchor, _ in
            Task { @MainActor in
                self?.heartRateAnchor = newAnchor
                self?.processHeartRateSamples(samples)
            }
        }

        heartRateQuery = query
        healthStore.execute(query)
    }

    func stopLiveHeartRateStreaming() {
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
        heartRateAnchor = nil
    }

    func startLiveCaloriesStreaming() {
        guard isAvailable, isAuthorized else { return }
        guard let caloriesType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return }

        stopLiveCaloriesStreaming()
        liveActiveCalories = 0

        let startDate = Date()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil, options: .strictStartDate)

        let query = HKAnchoredObjectQuery(
            type: caloriesType,
            predicate: predicate,
            anchor: caloriesAnchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, newAnchor, _ in
            Task { @MainActor in
                self?.caloriesAnchor = newAnchor
                self?.processCaloriesSamples(samples)
            }
        }

        query.updateHandler = { [weak self] _, samples, _, newAnchor, _ in
            Task { @MainActor in
                self?.caloriesAnchor = newAnchor
                self?.processCaloriesSamples(samples)
            }
        }

        caloriesQuery = query
        healthStore.execute(query)
    }

    func stopLiveCaloriesStreaming() {
        if let query = caloriesQuery {
            healthStore.stop(query)
            caloriesQuery = nil
        }
        caloriesAnchor = nil
    }

    func startAllLiveStreaming() {
        startLiveHeartRateStreaming()
        startLiveCaloriesStreaming()
    }

    func stopAllLiveStreaming() {
        stopLiveHeartRateStreaming()
        stopLiveCaloriesStreaming()
    }

    var collectedHeartRateSamples: [(bpm: Int, date: Date)] {
        heartRateSamplesCollected
    }

    var averageHeartRateDuringWorkout: Int {
        guard !heartRateSamplesCollected.isEmpty else { return 0 }
        let total = heartRateSamplesCollected.reduce(0) { $0 + $1.bpm }
        return total / heartRateSamplesCollected.count
    }

    var maxHeartRateDuringWorkout: Int {
        heartRateSamplesCollected.map(\.bpm).max() ?? 0
    }

    func heartRateZoneDistribution(totalDuration: TimeInterval) -> [HeartRateZoneDistribution] {
        guard !heartRateSamplesCollected.isEmpty, totalDuration > 0 else {
            return generateEstimatedZones(duration: totalDuration)
        }

        var zoneTimes: [HeartRateZone: TimeInterval] = [:]
        for zone in HeartRateZone.allCases {
            zoneTimes[zone] = 0
        }

        let sorted = heartRateSamplesCollected.sorted { $0.date < $1.date }
        for i in 0..<sorted.count {
            let zone = HeartRateZone.zone(for: sorted[i].bpm)
            let duration: TimeInterval
            if i + 1 < sorted.count {
                duration = sorted[i + 1].date.timeIntervalSince(sorted[i].date)
            } else if let start = workoutStartDate {
                duration = totalDuration - sorted[i].date.timeIntervalSince(start)
            } else {
                duration = 5
            }
            let clampedDuration = min(max(duration, 0), 300)
            zoneTimes[zone, default: 0] += clampedDuration
        }

        let totalTracked = zoneTimes.values.reduce(0, +)
        guard totalTracked > 0 else {
            return generateEstimatedZones(duration: totalDuration)
        }

        return HeartRateZone.allCases.map { zone in
            let time = zoneTimes[zone] ?? 0
            return HeartRateZoneDistribution(
                zone: zone,
                timeInZone: time,
                percentage: time / totalTracked
            )
        }
    }

    private func generateEstimatedZones(duration: TimeInterval) -> [HeartRateZoneDistribution] {
        guard duration > 0 else { return [] }
        let z1 = Double.random(in: 0.05...0.15)
        let z2 = Double.random(in: 0.2...0.35)
        let z3 = Double.random(in: 0.25...0.35)
        let z4 = Double.random(in: 0.1...0.2)
        let z5 = max(1.0 - z1 - z2 - z3 - z4, 0)
        return [
            HeartRateZoneDistribution(zone: .zone1, timeInZone: duration * z1, percentage: z1),
            HeartRateZoneDistribution(zone: .zone2, timeInZone: duration * z2, percentage: z2),
            HeartRateZoneDistribution(zone: .zone3, timeInZone: duration * z3, percentage: z3),
            HeartRateZoneDistribution(zone: .zone4, timeInZone: duration * z4, percentage: z4),
            HeartRateZoneDistribution(zone: .zone5, timeInZone: duration * max(z5, 0), percentage: max(z5, 0)),
        ]
    }

    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else { return }
        let unit = HKUnit.count().unitDivided(by: .minute())
        for sample in samples {
            let bpm = Int(sample.quantity.doubleValue(for: unit))
            if bpm > 30 && bpm < 250 {
                liveHeartRate = bpm
                heartRateSamplesCollected.append((bpm: bpm, date: sample.endDate))
            }
        }
    }

    private func processCaloriesSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else { return }
        for sample in samples {
            let kcal = sample.quantity.doubleValue(for: .kilocalorie())
            liveActiveCalories += kcal
        }
    }

    // MARK: - Fetch Swim Workouts from HealthKit

    func fetchSwimWorkouts(limit: Int = 50) async -> [HKWorkout] {
        guard isAvailable, isAuthorized else { return [] }

        let swimPredicate = HKQuery.predicateForWorkouts(with: .swimming)

        return await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: swimPredicate,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                let workouts = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: workouts)
            }
            healthStore.execute(query)
        }
    }

    func fetchWorkoutHeartRateSamples(for workout: HKWorkout) async -> [HKQuantitySample] {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return [] }

        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                let hrSamples = (samples as? [HKQuantitySample]) ?? []
                continuation.resume(returning: hrSamples)
            }
            healthStore.execute(query)
        }
    }

    func fetchWorkoutDistance(for workout: HKWorkout, type: HKQuantityTypeIdentifier) async -> Double {
        guard let distanceType = HKObjectType.quantityType(forIdentifier: type) else { return 0 }

        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: distanceType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let meters = result?.sumQuantity()?.doubleValue(for: .meter()) ?? 0
                continuation.resume(returning: meters)
            }
            healthStore.execute(query)
        }
    }

    func fetchWorkoutCalories(for workout: HKWorkout) async -> Double {
        guard let caloriesType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }

        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: caloriesType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let kcal = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: kcal)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Fetchers

    private func fetchSteps() async -> Int {
        let value = await fetchTodayCumulativeSum(for: .stepCount, unit: .count())
        return Int(value)
    }

    private func fetchActiveCalories() async -> Double {
        await fetchTodayCumulativeSum(for: .activeEnergyBurned, unit: .kilocalorie())
    }

    private func fetchRestingCalories() async -> Double {
        await fetchTodayCumulativeSum(for: .basalEnergyBurned, unit: .kilocalorie())
    }

    private func fetchDistance() async -> Double {
        await fetchTodayCumulativeSum(for: .distanceWalkingRunning, unit: .meter())
    }

    private func fetchFlightsClimbed() async -> Int {
        let value = await fetchTodayCumulativeSum(for: .flightsClimbed, unit: .count())
        return Int(value)
    }

    private func fetchExerciseMinutes() async -> Double {
        await fetchTodayCumulativeSum(for: .appleExerciseTime, unit: .minute())
    }

    private func fetchLatestHeartRate() async -> Double {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return 0 }

        return await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: 0)
                    return
                }
                let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                continuation.resume(returning: bpm)
            }
            healthStore.execute(query)
        }
    }

    private func fetchSleepHours() async -> Double {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let yesterday = Calendar.current.date(byAdding: .hour, value: -12, to: startOfDay) ?? startOfDay
        let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: now, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: 0)
                    return
                }
                let asleepSamples = samples.filter {
                    $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                }
                let totalSeconds = asleepSamples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: totalSeconds / 3600.0)
            }
            healthStore.execute(query)
        }
    }

    private func fetchBodyWeight() async -> Double? {
        guard let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return nil }

        return await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: weightType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let lbs = sample.quantity.doubleValue(for: .pound())
                continuation.resume(returning: lbs)
            }
            healthStore.execute(query)
        }
    }

    private func fetchVO2Max() async -> Double? {
        guard let vo2Type = HKObjectType.quantityType(forIdentifier: .vo2Max) else { return nil }

        return await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: vo2Type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let value = sample.quantity.doubleValue(for: HKUnit(from: "ml/kg*min"))
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    private func fetchTodayWorkouts() async -> [HKWorkout] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                let workouts = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: workouts)
            }
            healthStore.execute(query)
        }
    }

    func fetchSteps(for date: Date) async -> Int {
        let start = Calendar.current.startOfDay(for: date)
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return 0 }
        let value = await fetchCumulativeSum(for: .stepCount, unit: .count(), start: start, end: end)
        return Int(value)
    }

    func fetchActiveCalories(for date: Date) async -> Double {
        let start = Calendar.current.startOfDay(for: date)
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return 0 }
        return await fetchCumulativeSum(for: .activeEnergyBurned, unit: .kilocalorie(), start: start, end: end)
    }

    // MARK: - Step Data Queries

    func fetchHourlySteps(for date: Date) async -> [(hour: Int, steps: Int)] {
        guard isAvailable, isAuthorized else { return [] }
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return [] }

        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        guard let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }

        var interval = DateComponents()
        interval.hour = 1

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate),
                options: .cumulativeSum,
                anchorDate: startOfDay,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, results, _ in
                var hourlyData: [(hour: Int, steps: Int)] = []
                results?.enumerateStatistics(from: startOfDay, to: endOfDay) { stat, _ in
                    let hour = cal.component(.hour, from: stat.startDate)
                    let count = Int(stat.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                    hourlyData.append((hour: hour, steps: count))
                }
                continuation.resume(returning: hourlyData)
            }
            healthStore.execute(query)
        }
    }

    func fetchDailySteps(days: Int) async -> [(date: Date, steps: Int)] {
        guard isAvailable, isAuthorized else { return [] }
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return [] }

        let cal = Calendar.current
        let endDate = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: Date()) ?? Date())
        guard let startDate = cal.date(byAdding: .day, value: -days, to: cal.startOfDay(for: Date())) else { return [] }

        var interval = DateComponents()
        interval.day = 1

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate),
                options: .cumulativeSum,
                anchorDate: startDate,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, results, _ in
                var dailyData: [(date: Date, steps: Int)] = []
                results?.enumerateStatistics(from: startDate, to: endDate) { stat, _ in
                    let count = Int(stat.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                    dailyData.append((date: stat.startDate, steps: count))
                }
                continuation.resume(returning: dailyData)
            }
            healthStore.execute(query)
        }
    }

    func fetchWeeklySteps(weeks: Int) async -> [(weekStart: Date, steps: Int)] {
        guard isAvailable, isAuthorized else { return [] }
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return [] }

        let cal = Calendar.current
        let now = Date()
        let currentWeekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        guard let endDate = cal.date(byAdding: .day, value: 7, to: currentWeekStart),
              let startDate = cal.date(byAdding: .weekOfYear, value: -weeks, to: currentWeekStart) else { return [] }

        var interval = DateComponents()
        interval.weekOfYear = 1

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate),
                options: .cumulativeSum,
                anchorDate: startDate,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, results, _ in
                var weeklyData: [(weekStart: Date, steps: Int)] = []
                results?.enumerateStatistics(from: startDate, to: endDate) { stat, _ in
                    let count = Int(stat.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                    weeklyData.append((weekStart: stat.startDate, steps: count))
                }
                continuation.resume(returning: weeklyData)
            }
            healthStore.execute(query)
        }
    }

    func fetchMonthlySteps(months: Int) async -> [(monthStart: Date, steps: Int)] {
        guard isAvailable, isAuthorized else { return [] }
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return [] }

        let cal = Calendar.current
        let now = Date()
        let currentMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        guard let endDate = cal.date(byAdding: .month, value: 1, to: currentMonthStart),
              let startDate = cal.date(byAdding: .month, value: -months, to: currentMonthStart) else { return [] }

        var interval = DateComponents()
        interval.month = 1

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate),
                options: .cumulativeSum,
                anchorDate: startDate,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, results, _ in
                var monthlyData: [(monthStart: Date, steps: Int)] = []
                results?.enumerateStatistics(from: startDate, to: endDate) { stat, _ in
                    let count = Int(stat.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                    monthlyData.append((monthStart: stat.startDate, steps: count))
                }
                continuation.resume(returning: monthlyData)
            }
            healthStore.execute(query)
        }
    }

    func fetchDistanceWalking(for date: Date) async -> Double {
        let start = Calendar.current.startOfDay(for: date)
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return 0 }
        return await fetchCumulativeSum(for: .distanceWalkingRunning, unit: .meter(), start: start, end: end)
    }

    func fetchFlightsClimbed(for date: Date) async -> Int {
        let start = Calendar.current.startOfDay(for: date)
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return 0 }
        return Int(await fetchCumulativeSum(for: .flightsClimbed, unit: .count(), start: start, end: end))
    }

    // MARK: - Live Step Streaming

    private var stepQuery: HKObserverQuery?
    private var stepStatQuery: HKStatisticsQuery?

    func startLiveStepStreaming() {
        guard isAvailable, isAuthorized else { return }
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return }

        stopLiveStepStreaming()

        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, _, _ in
            Task { @MainActor in
                await self?.refreshTodaySteps()
            }
        }
        stepQuery = query
        healthStore.execute(query)
    }

    func stopLiveStepStreaming() {
        if let query = stepQuery {
            healthStore.stop(query)
            stepQuery = nil
        }
    }

    private func refreshTodaySteps() async {
        let value = await fetchTodayCumulativeSum(for: .stepCount, unit: .count())
        steps = Int(value)
        let dist = await fetchTodayCumulativeSum(for: .distanceWalkingRunning, unit: .meter())
        distanceWalking = dist
    }

    // MARK: - Save Workout

    func saveWorkout(
        type: HKWorkoutActivityType,
        start: Date,
        end: Date,
        calories: Double,
        distanceMeters: Double = 0,
        distanceType: HKQuantityTypeIdentifier? = nil,
        heartRateSamples: [(bpm: Int, date: Date)] = []
    ) async {
        guard isAvailable, isAuthorized else { return }

        let config = HKWorkoutConfiguration()
        config.activityType = type

        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: config, device: .local())

        do {
            try await builder.beginCollection(at: start)

            var samples: [HKQuantitySample] = []

            if calories > 0, let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
                let energySample = HKQuantitySample(
                    type: energyType,
                    quantity: HKQuantity(unit: .kilocalorie(), doubleValue: calories),
                    start: start,
                    end: end
                )
                samples.append(energySample)
            }

            if distanceMeters > 0, let distId = distanceType, let distType = HKObjectType.quantityType(forIdentifier: distId) {
                let distanceSample = HKQuantitySample(
                    type: distType,
                    quantity: HKQuantity(unit: .meter(), doubleValue: distanceMeters),
                    start: start,
                    end: end
                )
                samples.append(distanceSample)
            }

            if !heartRateSamples.isEmpty, let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) {
                let unit = HKUnit.count().unitDivided(by: .minute())
                let hrSamplesToSave = heartRateSamples.prefix(500).map { sample in
                    HKQuantitySample(
                        type: hrType,
                        quantity: HKQuantity(unit: unit, doubleValue: Double(sample.bpm)),
                        start: sample.date,
                        end: sample.date
                    )
                }
                samples.append(contentsOf: hrSamplesToSave)
            }

            if !samples.isEmpty {
                try await builder.addSamples(samples)
            }

            try await builder.endCollection(at: end)
            try await builder.finishWorkout()
        } catch {
            // Silently fail
        }
    }

    // MARK: - Helpers

    private func fetchTodayCumulativeSum(for identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return await fetchCumulativeSum(for: identifier, unit: unit, start: startOfDay, end: Date())
    }

    private func fetchCumulativeSum(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async -> Double {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                guard let result = result, let sum = result.sumQuantity() else {
                    continuation.resume(returning: 0)
                    return
                }
                continuation.resume(returning: sum.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }
}
