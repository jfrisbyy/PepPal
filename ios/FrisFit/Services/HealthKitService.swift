import Foundation
import HealthKit

@Observable
final class HealthKitService {
    static let shared = HealthKitService()

    private let healthStore = HKHealthStore()

    var isAuthorized: Bool = false
    var isAvailable: Bool = HKHealthStore.isHealthDataAvailable()

    /// True while a fresh fetch is in-flight. Views can show a subtle
    /// refreshing indicator without hiding the cached values that are
    /// already being displayed.
    var isRefreshing: Bool = false
    /// Timestamp of the last successfully completed fetch (today's data).
    var lastRefreshedAt: Date? = nil
    /// True when the observable fields were populated from the local cache
    /// rather than a live HealthKit query. Flipped off after the first
    /// successful live fetch completes.
    var isShowingCachedData: Bool = false

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

    /// Date currently being viewed on the dashboard. Live observers only write
    /// to the observable fields when this is today; otherwise they'd overwrite
    /// the historical values the user is looking at.
    var currentViewDate: Date = Date()

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

    var isHealthKitEnabled: Bool = UserDefaults.standard.bool(forKey: "healthkit_enabled") {
        didSet {
            UserDefaults.standard.set(isHealthKitEnabled, forKey: "healthkit_enabled")
            if isHealthKitEnabled && !oldValue {
                print("[HealthKit] Toggle turned ON, requesting authorization")
                Task { await requestAuthorization() }
            } else if !isHealthKitEnabled && oldValue {
                print("[HealthKit] Toggle turned OFF, disconnecting")
                isAuthorized = false
                stopAllLiveStreaming()
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
            .heartRateVariabilitySDNN,
            .restingHeartRate,
            .respiratoryRate,
            .oxygenSaturation,
            .walkingHeartRateAverage,
            .bodyMassIndex,
            .bodyFatPercentage,
            .leanBodyMass,
            .waistCircumference,
            .dietaryEnergyConsumed,
            .dietaryProtein,
            .dietaryCarbohydrates,
            .dietaryFatTotal,
            .dietaryWater,
            .bloodGlucose,
            .bloodPressureSystolic,
            .bloodPressureDiastolic,
            .bodyTemperature,
            .basalBodyTemperature,
        ]
        for id in quantityTypes {
            if let t = HKObjectType.quantityType(forIdentifier: id) {
                types.insert(t)
            }
        }
        let categoryTypes: [HKCategoryTypeIdentifier] = [
            .sleepAnalysis,
            .mindfulSession,
            .menstrualFlow,
            .ovulationTestResult,
            .headache,
            .nausea,
            .fatigue,
            .bloating,
            .moodChanges,
            .appetiteChanges,
            .dizziness,
            .abdominalCramps,
            .hotFlashes,
            .sleepChanges,
            .acne,
        ]
        for id in categoryTypes {
            if let t = HKObjectType.categoryType(forIdentifier: id) {
                types.insert(t)
            }
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
            .bodyMass,
            .bodyFatPercentage,
            .leanBodyMass,
            .waistCircumference,
            .dietaryWater,
            .dietaryEnergyConsumed,
            .dietaryProtein,
            .dietaryCarbohydrates,
            .dietaryFatTotal,
        ]
        for id in quantityIds {
            if let t = HKObjectType.quantityType(forIdentifier: id) {
                types.insert(t)
            }
        }
        let categoryIds: [HKCategoryTypeIdentifier] = [
            .mindfulSession,
            .headache,
            .nausea,
            .fatigue,
            .bloating,
            .moodChanges,
            .appetiteChanges,
            .dizziness,
            .abdominalCramps,
            .hotFlashes,
            .sleepChanges,
            .acne,
        ]
        for id in categoryIds {
            if let t = HKObjectType.categoryType(forIdentifier: id) {
                types.insert(t)
            }
        }
        types.insert(HKObjectType.workoutType())
        return types
    }()

    private init() {
        hydrateFromCache()
        if UserDefaults.standard.bool(forKey: "healthkit_enabled"), HKHealthStore.isHealthDataAvailable() {
            isAuthorized = true
            Task { await resumeIfAuthorized() }
        }
    }

    /// Re-reads the enabled flag from UserDefaults and silently re-attaches
    /// to HealthKit if the user previously connected on another device /
    /// before a rebuild. Called after cloud preferences are hydrated.
    func reloadEnabledFlagFromDefaults() {
        let remoteEnabled = UserDefaults.standard.bool(forKey: "healthkit_enabled")
        guard remoteEnabled, HKHealthStore.isHealthDataAvailable() else { return }
        guard !isAuthorized else { return }
        Task { await resumeIfAuthorized() }
    }

    /// Restores the most recently persisted HealthKit scalar values so the UI
    /// never renders a blank state on cold launch. Overwritten as soon as a
    /// live fetch completes.
    private func hydrateFromCache() {
        guard let snap = HealthKitCache.loadScalars() else { return }
        steps = snap.steps
        activeCalories = snap.activeCalories
        restingCalories = snap.restingCalories
        heartRate = snap.heartRate
        distanceWalking = snap.distanceWalking
        flightsClimbed = snap.flightsClimbed
        exerciseMinutes = snap.exerciseMinutes
        standHours = snap.standHours
        sleepHours = snap.sleepHours
        bodyWeight = snap.bodyWeight
        vo2Max = snap.vo2Max
        hrv = snap.hrv
        restingHeartRate = snap.restingHeartRate
        respiratoryRate = snap.respiratoryRate
        oxygenSaturation = snap.oxygenSaturation
        walkingHeartRateAverage = snap.walkingHeartRateAverage
        bodyFatPercentage = snap.bodyFatPercentage
        leanBodyMass = snap.leanBodyMass
        waistCircumference = snap.waistCircumference
        bmi = snap.bmi
        mindfulMinutesToday = snap.mindfulMinutesToday
        dietaryEnergyConsumed = snap.dietaryEnergyConsumed
        dietaryProtein = snap.dietaryProtein
        dietaryCarbs = snap.dietaryCarbs
        dietaryFat = snap.dietaryFat
        dietaryWater = snap.dietaryWater
        bloodGlucose = snap.bloodGlucose
        bloodPressureSystolic = snap.bloodPressureSystolic
        bloodPressureDiastolic = snap.bloodPressureDiastolic
        bodyTemperature = snap.bodyTemperature
        lastRefreshedAt = snap.savedAt
        isShowingCachedData = true
    }

    /// Captures the current observable scalar values and writes them to disk
    /// so that the next cold launch renders immediately from cache.
    private func persistScalarCache() {
        var snap = HealthKitScalarSnapshot()
        snap.steps = steps
        snap.activeCalories = activeCalories
        snap.restingCalories = restingCalories
        snap.heartRate = heartRate
        snap.distanceWalking = distanceWalking
        snap.flightsClimbed = flightsClimbed
        snap.exerciseMinutes = exerciseMinutes
        snap.standHours = standHours
        snap.sleepHours = sleepHours
        snap.bodyWeight = bodyWeight
        snap.vo2Max = vo2Max
        snap.hrv = hrv
        snap.restingHeartRate = restingHeartRate
        snap.respiratoryRate = respiratoryRate
        snap.oxygenSaturation = oxygenSaturation
        snap.walkingHeartRateAverage = walkingHeartRateAverage
        snap.bodyFatPercentage = bodyFatPercentage
        snap.leanBodyMass = leanBodyMass
        snap.waistCircumference = waistCircumference
        snap.bmi = bmi
        snap.mindfulMinutesToday = mindfulMinutesToday
        snap.dietaryEnergyConsumed = dietaryEnergyConsumed
        snap.dietaryProtein = dietaryProtein
        snap.dietaryCarbs = dietaryCarbs
        snap.dietaryFat = dietaryFat
        snap.dietaryWater = dietaryWater
        snap.bloodGlucose = bloodGlucose
        snap.bloodPressureSystolic = bloodPressureSystolic
        snap.bloodPressureDiastolic = bloodPressureDiastolic
        snap.bodyTemperature = bodyTemperature
        snap.savedAt = Date()
        HealthKitCache.saveScalars(snap)
    }

    /// Called on app launch / foreground when the user has previously connected.
    /// Avoids re-prompting: uses iOS's remembered decision, refreshes data, and
    /// re-enables background delivery + live streams.
    func resumeIfAuthorized() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            isAvailable = false
            return
        }
        isAvailable = true
        guard UserDefaults.standard.bool(forKey: "healthkit_enabled") else { return }

        do {
            let status = try await healthStore.statusForAuthorizationRequest(toShare: writeTypes, read: readTypes)
            if status == .unnecessary {
                isAuthorized = true
                enableBackgroundDelivery()
                await fetchAllData()
                startLiveStepStreaming()
                return
            }
        } catch {
            print("[HealthKit] statusForAuthorizationRequest failed: \(error.localizedDescription)")
        }

        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
            isAuthorized = true
            enableBackgroundDelivery()
            await fetchAllData()
            startLiveStepStreaming()
        } catch {
            print("[HealthKit] resume auth failed: \(error.localizedDescription)")
        }
    }

    /// Returns true if iOS actually presented the authorization sheet for at
    /// least one type. Returns false when status is `.unnecessary` (already
    /// responded) or the platform refuses to prompt — caller should then
    /// direct the user to Settings.app.
    @discardableResult
    func requestAuthorizationInteractively() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            isAvailable = false
            return false
        }
        isAvailable = true

        var willPrompt = true
        do {
            let status = try await healthStore.statusForAuthorizationRequest(toShare: writeTypes, read: readTypes)
            willPrompt = (status != .unnecessary)
        } catch {
            print("[HealthKit] statusForAuthorizationRequest failed: \(error.localizedDescription)")
        }

        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
        } catch {
            print("[HealthKit] Authorization request failed: \(error.localizedDescription)")
            isAuthorized = false
            return willPrompt
        }

        let writeStatus = writeTypes.contains { healthStore.authorizationStatus(for: $0) == .sharingAuthorized }
        let granted = writeStatus || willPrompt
        isAuthorized = granted
        UserDefaults.standard.set(granted, forKey: "healthkit_enabled")
        if granted {
            enableBackgroundDelivery()
            await fetchAllData()
            startLiveStepStreaming()
        }
        return willPrompt
    }

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
            UserDefaults.standard.set(true, forKey: "healthkit_enabled")
            enableBackgroundDelivery()
            await fetchAllData()
            startLiveStepStreaming()
        } catch {
            print("[HealthKit] Authorization failed: \(error.localizedDescription)")
            isAuthorized = false
        }
    }

    func fetchAllData() async {
        guard isAvailable, isAuthorized else { return }
        isRefreshing = true
        defer {
            isRefreshing = false
            isShowingCachedData = false
            lastRefreshedAt = Date()
            persistScalarCache()
        }
        currentViewDate = Date()
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

        await fetchExtendedMetrics()
    }

    func fetchExtendedMetrics() async {
        guard isAvailable, isAuthorized else { return }
        async let hrvV = fetchLatestDiscrete(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli))
        async let rhrV = fetchLatestDiscrete(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()))
        async let rrV = fetchLatestDiscrete(.respiratoryRate, unit: HKUnit.count().unitDivided(by: .minute()))
        async let o2V = fetchLatestDiscrete(.oxygenSaturation, unit: .percent())
        async let whrV = fetchLatestDiscrete(.walkingHeartRateAverage, unit: HKUnit.count().unitDivided(by: .minute()))
        async let bfV = fetchLatestDiscrete(.bodyFatPercentage, unit: .percent())
        async let lbmV = fetchLatestDiscrete(.leanBodyMass, unit: .pound())
        async let waistV = fetchLatestDiscrete(.waistCircumference, unit: .inch())
        async let bmiV = fetchLatestDiscrete(.bodyMassIndex, unit: .count())
        async let glucV = fetchLatestDiscrete(.bloodGlucose, unit: HKUnit(from: "mg/dL"))
        async let bpsV = fetchLatestDiscrete(.bloodPressureSystolic, unit: .millimeterOfMercury())
        async let bpdV = fetchLatestDiscrete(.bloodPressureDiastolic, unit: .millimeterOfMercury())
        async let tempV = fetchLatestDiscrete(.bodyTemperature, unit: .degreeFahrenheit())
        async let dECV = fetchTodayCumulativeSum(for: .dietaryEnergyConsumed, unit: .kilocalorie())
        async let dPV = fetchTodayCumulativeSum(for: .dietaryProtein, unit: .gram())
        async let dCV = fetchTodayCumulativeSum(for: .dietaryCarbohydrates, unit: .gram())
        async let dFV = fetchTodayCumulativeSum(for: .dietaryFatTotal, unit: .gram())
        async let dWV = fetchTodayCumulativeSum(for: .dietaryWater, unit: .literUnit(with: .milli))
        async let mindV = fetchTodayMindfulMinutes()

        let results = await (hrvV, rhrV, rrV, o2V, whrV, bfV, lbmV, waistV, bmiV, glucV, bpsV, bpdV, tempV, dECV, dPV, dCV, dFV, dWV, mindV)
        hrv = results.0
        restingHeartRate = results.1
        respiratoryRate = results.2
        oxygenSaturation = results.3.map { $0 * 100 }
        walkingHeartRateAverage = results.4
        bodyFatPercentage = results.5.map { $0 * 100 }
        leanBodyMass = results.6
        waistCircumference = results.7
        bmi = results.8
        bloodGlucose = results.9
        bloodPressureSystolic = results.10
        bloodPressureDiastolic = results.11
        bodyTemperature = results.12
        dietaryEnergyConsumed = results.13
        dietaryProtein = results.14
        dietaryCarbs = results.15
        dietaryFat = results.16
        dietaryWater = results.17
        mindfulMinutesToday = results.18
    }

    /// Composite 0–100 score from HRV, RHR, sleep, respiratory rate. Higher is better.
    var recoveryScore: Int? {
        var components: [Double] = []

        if let hrv, hrv > 0 {
            let normalized = min(max((hrv - 20) / 80.0, 0), 1)
            components.append(normalized * 100)
        }
        if let rhr = restingHeartRate, rhr > 0 {
            let normalized = min(max(1 - (rhr - 50) / 40.0, 0), 1)
            components.append(normalized * 100)
        }
        if sleepHours > 0 {
            let normalized = min(max(sleepHours / 8.0, 0), 1)
            components.append(normalized * 100)
        }
        if let rr = respiratoryRate, rr > 0 {
            let normalized = min(max(1 - abs(rr - 14) / 10.0, 0), 1)
            components.append(normalized * 100)
        }
        guard !components.isEmpty else { return nil }
        return Int(components.reduce(0, +) / Double(components.count))
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
            let service = self
            Task { @MainActor in
                service?.heartRateAnchor = newAnchor
                service?.processHeartRateSamples(samples)
            }
        }

        query.updateHandler = { [weak self] _, samples, _, newAnchor, _ in
            let service = self
            Task { @MainActor in
                service?.heartRateAnchor = newAnchor
                service?.processHeartRateSamples(samples)
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
            let service = self
            Task { @MainActor in
                service?.caloriesAnchor = newAnchor
                service?.processCaloriesSamples(samples)
            }
        }

        query.updateHandler = { [weak self] _, samples, _, newAnchor, _ in
            let service = self
            Task { @MainActor in
                service?.caloriesAnchor = newAnchor
                service?.processCaloriesSamples(samples)
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

    private func fetchLatestDiscrete(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        return await withCheckedContinuation { cont in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                guard let s = samples?.first as? HKQuantitySample else {
                    cont.resume(returning: nil)
                    return
                }
                cont.resume(returning: s.quantity.doubleValue(for: unit))
            }
            self.healthStore.execute(query)
        }
    }

    private func fetchTodayMindfulMinutes() async -> Double {
        guard let type = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return 0 }
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        return await withCheckedContinuation { cont in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else {
                    cont.resume(returning: 0)
                    return
                }
                let total = samples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 60.0 }
                cont.resume(returning: total)
            }
            self.healthStore.execute(query)
        }
    }

    // MARK: - Write Helpers

    func saveBodyMass(pounds: Double, date: Date = Date()) async {
        guard isAvailable, isAuthorized, let type = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return }
        let sample = HKQuantitySample(
            type: type,
            quantity: HKQuantity(unit: .pound(), doubleValue: pounds),
            start: date,
            end: date
        )
        try? await healthStore.save(sample)
    }

    func saveWaterIntake(milliliters: Double, date: Date = Date()) async {
        guard isAvailable, isAuthorized, let type = HKObjectType.quantityType(forIdentifier: .dietaryWater) else { return }
        let sample = HKQuantitySample(
            type: type,
            quantity: HKQuantity(unit: .literUnit(with: .milli), doubleValue: milliliters),
            start: date,
            end: date
        )
        try? await healthStore.save(sample)
    }

    func saveMindfulSession(minutes: Double, end: Date = Date()) async {
        guard isAvailable, isAuthorized, let type = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return }
        let start = end.addingTimeInterval(-minutes * 60)
        let sample = HKCategorySample(type: type, value: 0, start: start, end: end)
        try? await healthStore.save(sample)
    }

    /// Maps a protocol side-effect name to a HealthKit symptom category and writes it.
    func saveSymptom(name: String, severity: Int, date: Date = Date()) async {
        guard isAvailable, isAuthorized else { return }
        let lowered = name.lowercased()
        let identifier: HKCategoryTypeIdentifier?
        switch lowered {
        case let s where s.contains("headache"): identifier = .headache
        case let s where s.contains("nausea"): identifier = .nausea
        case let s where s.contains("fatigue") || s.contains("lethargy") || s.contains("tired"): identifier = .fatigue
        case let s where s.contains("bloat") || s.contains("water retention"): identifier = .bloating
        case let s where s.contains("mood"): identifier = .moodChanges
        case let s where s.contains("appetite") || s.contains("hunger"): identifier = .appetiteChanges
        case let s where s.contains("dizz") || s.contains("light"): identifier = .dizziness
        case let s where s.contains("cramp") || s.contains("abdom"): identifier = .abdominalCramps
        case let s where s.contains("hot flash") || s.contains("flush"): identifier = .hotFlashes
        case let s where s.contains("insomn") || s.contains("sleep"): identifier = .sleepChanges
        case let s where s.contains("acne") || s.contains("breakout"): identifier = .acne
        default: identifier = nil
        }
        guard let id = identifier, let type = HKObjectType.categoryType(forIdentifier: id) else { return }

        let value: Int
        switch severity {
        case 1: value = HKCategoryValueSeverity.mild.rawValue
        case 2: value = HKCategoryValueSeverity.moderate.rawValue
        case 3: value = HKCategoryValueSeverity.severe.rawValue
        default: value = HKCategoryValueSeverity.severe.rawValue
        }

        let sample = HKCategorySample(type: type, value: value, start: date, end: date)
        try? await healthStore.save(sample)
    }

    // MARK: - Background Delivery

    func enableBackgroundDelivery() {
        guard isAvailable, isAuthorized else { return }
        let observed: [(HKQuantityTypeIdentifier, HKUpdateFrequency)] = [
            (.stepCount, .hourly),
            (.heartRateVariabilitySDNN, .hourly),
            (.restingHeartRate, .hourly),
            (.activeEnergyBurned, .hourly),
        ]
        for (id, freq) in observed {
            guard let type = HKObjectType.quantityType(forIdentifier: id) else { continue }
            healthStore.enableBackgroundDelivery(for: type, frequency: freq) { _, _ in }
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

    func fetchRestingCalories(for date: Date) async -> Double {
        let start = Calendar.current.startOfDay(for: date)
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return 0 }
        return await fetchCumulativeSum(for: .basalEnergyBurned, unit: .kilocalorie(), start: start, end: end)
    }

    func fetchExerciseMinutes(for date: Date) async -> Double {
        let start = Calendar.current.startOfDay(for: date)
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return 0 }
        return await fetchCumulativeSum(for: .appleExerciseTime, unit: .minute(), start: start, end: end)
    }

    func fetchAverageHeartRate(for date: Date) async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRate) else { return 0 }
        let start = Calendar.current.startOfDay(for: date)
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { cont in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, _ in
                let bpm = result?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) ?? 0
                cont.resume(returning: bpm)
            }
            self.healthStore.execute(query)
        }
    }

    func fetchWorkouts(for date: Date) async -> [HKWorkout] {
        let start = Calendar.current.startOfDay(for: date)
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            healthStore.execute(query)
        }
    }

    func fetchSleepHours(for date: Date) async -> Double {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        // Sleep window = previous noon -> target day's noon (captures the night attributed to this day)
        guard let windowStart = cal.date(byAdding: .hour, value: -12, to: startOfDay),
              let windowEnd = cal.date(byAdding: .hour, value: 12, to: startOfDay) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: 0); return
                }
                let asleep = samples.filter {
                    $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                }
                let total = asleep.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: total / 3600.0)
            }
            self.healthStore.execute(query)
        }
    }

    /// Loads the primary day-scoped metrics for an arbitrary date and overwrites
    /// the observable fields used by the dashboard. Passing today's date is
    /// equivalent to a fresh `fetchAllData()` for the visible cards.
    func fetchAllData(for date: Date) async {
        guard isAvailable, isAuthorized else { return }
        currentViewDate = date
        if Calendar.current.isDateInToday(date) {
            await fetchAllData()
            return
        }
        async let s = fetchSteps(for: date)
        async let ac = fetchActiveCalories(for: date)
        async let rc = fetchRestingCalories(for: date)
        async let hr = fetchAverageHeartRate(for: date)
        async let d = fetchDistanceWalking(for: date)
        async let fc = fetchFlightsClimbed(for: date)
        async let em = fetchExerciseMinutes(for: date)
        async let sl = fetchSleepHours(for: date)
        async let wo = fetchWorkouts(for: date)

        let (stepsVal, activeVal, restingVal, hrVal, distVal, flightsVal, exVal, sleepVal, workoutsVal) = await (s, ac, rc, hr, d, fc, em, sl, wo)

        steps = stepsVal
        activeCalories = activeVal
        restingCalories = restingVal
        heartRate = hrVal
        distanceWalking = distVal
        flightsClimbed = flightsVal
        exerciseMinutes = exVal
        sleepHours = sleepVal
        workoutsToday = workoutsVal

        await fetchExtendedMetrics(for: date)
    }

    /// Fetches the extended recovery/body/nutrition metrics scoped to a specific day
    /// and writes them to the observable fields so the card reflects the viewed date.
    func fetchExtendedMetrics(for date: Date) async {
        guard isAvailable, isAuthorized else { return }
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return }
        let bpm = HKUnit.count().unitDivided(by: .minute())

        async let hrvV = dayAverage(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), start: start, end: end)
        async let rhrV = dayAverage(.restingHeartRate, unit: bpm, start: start, end: end)
        async let rrV = dayAverage(.respiratoryRate, unit: bpm, start: start, end: end)
        async let o2V = dayAverage(.oxygenSaturation, unit: .percent(), start: start, end: end)
        async let whrV = dayAverage(.walkingHeartRateAverage, unit: bpm, start: start, end: end)
        async let bfV = dayAverage(.bodyFatPercentage, unit: .percent(), start: start, end: end)
        async let lbmV = dayAverage(.leanBodyMass, unit: .pound(), start: start, end: end)
        async let waistV = dayAverage(.waistCircumference, unit: .inch(), start: start, end: end)
        async let bmiV = dayAverage(.bodyMassIndex, unit: .count(), start: start, end: end)
        async let glucV = dayAverage(.bloodGlucose, unit: HKUnit(from: "mg/dL"), start: start, end: end)
        async let bpsV = dayAverage(.bloodPressureSystolic, unit: .millimeterOfMercury(), start: start, end: end)
        async let bpdV = dayAverage(.bloodPressureDiastolic, unit: .millimeterOfMercury(), start: start, end: end)
        async let tempV = dayAverage(.bodyTemperature, unit: .degreeFahrenheit(), start: start, end: end)
        async let weightV = dayAverage(.bodyMass, unit: .pound(), start: start, end: end)
        async let dECV = fetchCumulativeSum(for: .dietaryEnergyConsumed, unit: .kilocalorie(), start: start, end: end)
        async let dPV = fetchCumulativeSum(for: .dietaryProtein, unit: .gram(), start: start, end: end)
        async let dCV = fetchCumulativeSum(for: .dietaryCarbohydrates, unit: .gram(), start: start, end: end)
        async let dFV = fetchCumulativeSum(for: .dietaryFatTotal, unit: .gram(), start: start, end: end)
        async let dWV = fetchCumulativeSum(for: .dietaryWater, unit: .literUnit(with: .milli), start: start, end: end)
        async let mindV = dayMindfulMinutes(start: start, end: end)

        let r = await (hrvV, rhrV, rrV, o2V, whrV, bfV, lbmV, waistV, bmiV, glucV, bpsV, bpdV, tempV, weightV, dECV, dPV, dCV, dFV, dWV, mindV)

        hrv = r.0
        restingHeartRate = r.1
        respiratoryRate = r.2
        oxygenSaturation = r.3.map { $0 * 100 }
        walkingHeartRateAverage = r.4
        bodyFatPercentage = r.5.map { $0 * 100 }
        leanBodyMass = r.6
        waistCircumference = r.7
        bmi = r.8
        bloodGlucose = r.9
        bloodPressureSystolic = r.10
        bloodPressureDiastolic = r.11
        bodyTemperature = r.12
        bodyWeight = r.13
        dietaryEnergyConsumed = r.14
        dietaryProtein = r.15
        dietaryCarbs = r.16
        dietaryFat = r.17
        dietaryWater = r.18
        mindfulMinutesToday = r.19
    }

    func fetchDayAverage(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, date: Date) async -> Double? {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return nil }
        return await dayAverage(identifier, unit: unit, start: start, end: end)
    }

    private func dayAverage(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { cont in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, _ in
                guard let avg = result?.averageQuantity()?.doubleValue(for: unit), avg > 0 else {
                    cont.resume(returning: nil)
                    return
                }
                cont.resume(returning: avg)
            }
            self.healthStore.execute(query)
        }
    }

    private func dayMindfulMinutes(start: Date, end: Date) async -> Double {
        guard let type = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { cont in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else { cont.resume(returning: 0); return }
                let total = samples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 60.0 }
                cont.resume(returning: total)
            }
            self.healthStore.execute(query)
        }
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
        guard Calendar.current.isDateInToday(currentViewDate) else { return }
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

    // MARK: - Generic History Fetchers

    /// Fetches daily cumulative sums (e.g. steps, calories, distance) over the last N days.
    func fetchDailySumSeries(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, days: Int) async -> [(date: Date, value: Double)] {
        guard isAvailable, isAuthorized else { return [] }
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return [] }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let endDate = cal.date(byAdding: .day, value: 1, to: today),
              let startDate = cal.date(byAdding: .day, value: -(days - 1), to: today) else { return [] }
        var interval = DateComponents(); interval.day = 1
        return await withCheckedContinuation { cont in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate),
                options: .cumulativeSum,
                anchorDate: startDate,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, results, _ in
                var out: [(date: Date, value: Double)] = []
                results?.enumerateStatistics(from: startDate, to: endDate) { stat, _ in
                    let v = stat.sumQuantity()?.doubleValue(for: unit) ?? 0
                    out.append((date: stat.startDate, value: v))
                }
                cont.resume(returning: out)
            }
            self.healthStore.execute(query)
        }
    }

    /// Fetches daily cumulative sums for an arbitrary date range.
    func fetchDailySumSeries(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async -> [(date: Date, value: Double)] {
        guard isAvailable, isAuthorized else { return [] }
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return [] }
        let cal = Calendar.current
        let startDate = cal.startOfDay(for: start)
        let endDate = cal.startOfDay(for: end)
        guard endDate > startDate else { return [] }
        var interval = DateComponents(); interval.day = 1
        return await withCheckedContinuation { cont in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate),
                options: .cumulativeSum,
                anchorDate: startDate,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, results, _ in
                var out: [(date: Date, value: Double)] = []
                results?.enumerateStatistics(from: startDate, to: endDate) { stat, _ in
                    let v = stat.sumQuantity()?.doubleValue(for: unit) ?? 0
                    out.append((date: stat.startDate, value: v))
                }
                cont.resume(returning: out)
            }
            self.healthStore.execute(query)
        }
    }

    /// Fetches sleep hours per night over an arbitrary date range.
    func fetchSleepHistory(start: Date, end: Date) async -> [(date: Date, asleepHours: Double)] {
        guard isAvailable, isAuthorized else { return [] }
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        let cal = Calendar.current
        let startDate = cal.startOfDay(for: start)
        let endDate = cal.startOfDay(for: end)
        guard endDate > startDate else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        return await withCheckedContinuation { cont in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else { cont.resume(returning: []); return }
                var buckets: [Date: TimeInterval] = [:]
                for s in samples {
                    let bucketStart = cal.startOfDay(for: s.endDate.addingTimeInterval(-6 * 3600))
                    let dur = s.endDate.timeIntervalSince(s.startDate)
                    let isAsleep = s.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                        || s.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                        || s.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
                        || s.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                    if isAsleep {
                        buckets[bucketStart, default: 0] += dur
                    }
                }
                let out = buckets.keys.sorted().map { (date: $0, asleepHours: (buckets[$0] ?? 0) / 3600) }
                cont.resume(returning: out)
            }
            self.healthStore.execute(query)
        }
    }

    /// Fetches daily average values (e.g. heart rate, HRV, resting HR) over the last N days.
    func fetchDailyAverageSeries(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, days: Int) async -> [(date: Date, value: Double)] {
        guard isAvailable, isAuthorized else { return [] }
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return [] }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let endDate = cal.date(byAdding: .day, value: 1, to: today),
              let startDate = cal.date(byAdding: .day, value: -(days - 1), to: today) else { return [] }
        var interval = DateComponents(); interval.day = 1
        return await withCheckedContinuation { cont in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate),
                options: .discreteAverage,
                anchorDate: startDate,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, results, _ in
                var out: [(date: Date, value: Double)] = []
                results?.enumerateStatistics(from: startDate, to: endDate) { stat, _ in
                    if let avg = stat.averageQuantity()?.doubleValue(for: unit) {
                        out.append((date: stat.startDate, value: avg))
                    }
                }
                cont.resume(returning: out)
            }
            self.healthStore.execute(query)
        }
    }

    /// Fetches min/max/avg range for discrete metrics like heart rate, bp.
    func fetchDailyRangeSeries(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, days: Int) async -> [(date: Date, min: Double, max: Double, avg: Double)] {
        guard isAvailable, isAuthorized else { return [] }
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return [] }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let endDate = cal.date(byAdding: .day, value: 1, to: today),
              let startDate = cal.date(byAdding: .day, value: -(days - 1), to: today) else { return [] }
        var interval = DateComponents(); interval.day = 1
        return await withCheckedContinuation { cont in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate),
                options: [.discreteAverage, .discreteMin, .discreteMax],
                anchorDate: startDate,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, results, _ in
                var out: [(date: Date, min: Double, max: Double, avg: Double)] = []
                results?.enumerateStatistics(from: startDate, to: endDate) { stat, _ in
                    let avg = stat.averageQuantity()?.doubleValue(for: unit) ?? 0
                    let mn = stat.minimumQuantity()?.doubleValue(for: unit) ?? 0
                    let mx = stat.maximumQuantity()?.doubleValue(for: unit) ?? 0
                    if avg > 0 || mn > 0 || mx > 0 {
                        out.append((date: stat.startDate, min: mn, max: mx, avg: avg))
                    }
                }
                cont.resume(returning: out)
            }
            self.healthStore.execute(query)
        }
    }

    /// Fetches the most recent N discrete samples (e.g. weight, body fat).
    func fetchRecentSamples(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, limit: Int = 50) async -> [(date: Date, value: Double)] {
        guard isAvailable, isAuthorized else { return [] }
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return [] }
        return await withCheckedContinuation { cont in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: limit, sortDescriptors: [sort]) { _, samples, _ in
                let items = (samples as? [HKQuantitySample])?.map { s in
                    (date: s.endDate, value: s.quantity.doubleValue(for: unit))
                } ?? []
                cont.resume(returning: items.reversed())
            }
            self.healthStore.execute(query)
        }
    }

    /// Fetches daily mindful minutes over the last N days.
    func fetchMindfulDailySeries(days: Int) async -> [(date: Date, value: Double)] {
        guard isAvailable, isAuthorized else { return [] }
        guard let type = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return [] }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let endDate = cal.date(byAdding: .day, value: 1, to: today),
              let startDate = cal.date(byAdding: .day, value: -(days - 1), to: today) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        return await withCheckedContinuation { cont in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else { cont.resume(returning: []); return }
                var map: [Date: Double] = [:]
                for s in samples {
                    let day = cal.startOfDay(for: s.startDate)
                    let minutes = s.endDate.timeIntervalSince(s.startDate) / 60.0
                    map[day, default: 0] += minutes
                }
                let out = map.keys.sorted().map { (date: $0, value: map[$0] ?? 0) }
                cont.resume(returning: out)
            }
            self.healthStore.execute(query)
        }
    }

    /// Fetches sleep hours per night over the last N days.
    func fetchSleepHistory(days: Int) async -> [(date: Date, asleepHours: Double, deepHours: Double, remHours: Double, coreHours: Double)] {
        guard isAvailable, isAuthorized else { return [] }
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let endDate = cal.date(byAdding: .day, value: 1, to: today),
              let startDate = cal.date(byAdding: .day, value: -days, to: today) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return await withCheckedContinuation { cont in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else { cont.resume(returning: []); return }
                var buckets: [Date: (asleep: TimeInterval, deep: TimeInterval, rem: TimeInterval, core: TimeInterval)] = [:]
                for s in samples {
                    let bucketStart = cal.startOfDay(for: s.endDate.addingTimeInterval(-6 * 3600))
                    let dur = s.endDate.timeIntervalSince(s.startDate)
                    var e = buckets[bucketStart] ?? (0, 0, 0, 0)
                    switch s.value {
                    case HKCategoryValueSleepAnalysis.asleepDeep.rawValue: e.deep += dur; e.asleep += dur
                    case HKCategoryValueSleepAnalysis.asleepREM.rawValue: e.rem += dur; e.asleep += dur
                    case HKCategoryValueSleepAnalysis.asleepCore.rawValue: e.core += dur; e.asleep += dur
                    case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue: e.asleep += dur
                    default: break
                    }
                    buckets[bucketStart] = e
                }
                let out = buckets.keys.sorted().map { day in
                    let e = buckets[day] ?? (0, 0, 0, 0)
                    return (date: day,
                            asleepHours: e.asleep / 3600,
                            deepHours: e.deep / 3600,
                            remHours: e.rem / 3600,
                            coreHours: e.core / 3600)
                }
                cont.resume(returning: out)
            }
            self.healthStore.execute(query)
        }
    }
}
