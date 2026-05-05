import SwiftUI
import HealthKit

nonisolated enum HealthDetailPeriod: String, CaseIterable, Identifiable, Sendable {
    case week = "W"
    case month = "M"
    case sixMonths = "6M"
    case year = "Y"

    nonisolated var id: String { rawValue }

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .sixMonths: return 180
        case .year: return 365
        }
    }

    var label: String {
        switch self {
        case .week: return "Last 7 Days"
        case .month: return "Last 30 Days"
        case .sixMonths: return "Last 6 Months"
        case .year: return "Last Year"
        }
    }
}

nonisolated struct HealthSeriesPoint: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let value: Double
    let min: Double
    let max: Double
}

nonisolated struct HealthTrendSummary: Sendable {
    let current: Double
    let previous: Double
    let deltaPct: Double?
    let isPersonalBest: Bool
    let streakDays: Int
}

nonisolated extension Array where Element == HealthSeriesPoint {
    var nonZeroAverage: Double {
        let nz = self.filter { $0.value > 0 }
        guard !nz.isEmpty else { return 0 }
        return nz.reduce(0) { $0 + $1.value } / Double(nz.count)
    }
    var nonZeroSum: Double {
        self.reduce(0) { $0 + $1.value }
    }
}

@Observable
final class HealthDetailViewModel {
    let healthKit = HealthKitService.shared

    var period: HealthDetailPeriod = .week
    var isLoading: Bool = false
    /// True while a live fetch is running but cached data is already visible.
    var isRefreshing: Bool = false
    /// True when the currently-displayed series came from the local cache,
    /// not a live HealthKit query. Flips off after the first successful load.
    var isShowingCachedData: Bool = false
    /// Timestamp of the last successful live load.
    var lastLoadedAt: Date? = nil

    // Activity
    var stepsSeries: [HealthSeriesPoint] = []
    var activeCalSeries: [HealthSeriesPoint] = []
    var restingCalSeries: [HealthSeriesPoint] = []
    var distanceSeries: [HealthSeriesPoint] = []
    var flightsSeries: [HealthSeriesPoint] = []
    var exerciseSeries: [HealthSeriesPoint] = []

    // Heart
    var heartRateSeries: [HealthSeriesPoint] = []
    var restingHRSeries: [HealthSeriesPoint] = []
    var hrvSeries: [HealthSeriesPoint] = []
    var walkingHRSeries: [HealthSeriesPoint] = []

    // Body
    var weightSeries: [HealthSeriesPoint] = []
    var bodyFatSeries: [HealthSeriesPoint] = []
    var leanMassSeries: [HealthSeriesPoint] = []
    var bmiSeries: [HealthSeriesPoint] = []
    var waistSeries: [HealthSeriesPoint] = []

    // Respiratory & Vitals
    var respiratoryRateSeries: [HealthSeriesPoint] = []
    var oxygenSaturationSeries: [HealthSeriesPoint] = []
    var bodyTempSeries: [HealthSeriesPoint] = []
    var bloodGlucoseSeries: [HealthSeriesPoint] = []
    var systolicSeries: [HealthSeriesPoint] = []
    var diastolicSeries: [HealthSeriesPoint] = []
    var vo2MaxSeries: [HealthSeriesPoint] = []

    // Nutrition (today data, but show daily series)
    var hydrationSeries: [HealthSeriesPoint] = []
    var dietaryEnergySeries: [HealthSeriesPoint] = []
    var mindfulSeries: [HealthSeriesPoint] = []

    // Sleep
    var sleepNights: [(date: Date, asleep: Double, deep: Double, rem: Double, core: Double)] = []

    // Prior period (for delta comparisons)
    var priorStepsSeries: [HealthSeriesPoint] = []
    var priorActiveCalSeries: [HealthSeriesPoint] = []
    var priorSleepTotals: [HealthSeriesPoint] = []
    var priorRestingHRSeries: [HealthSeriesPoint] = []
    var priorHRVSeries: [HealthSeriesPoint] = []
    var priorDistanceSeries: [HealthSeriesPoint] = []
    var priorExerciseSeries: [HealthSeriesPoint] = []

    // Personal best windows (wider than period) for PB detection
    var pbStepsMax: Double = 0
    var pbActiveCalMax: Double = 0
    var pbSleepMax: Double = 0
    var pbHRVMax: Double = 0
    var pbDistanceMax: Double = 0
    var pbExerciseMax: Double = 0

    // Goals
    var stepGoal: Int = 10_000
    var activeEnergyGoal: Int = 500
    var exerciseGoal: Int = 30
    var standGoal: Int = 12
    var sleepGoalHours: Double = 8

    func trend(for series: [HealthSeriesPoint], prior: [HealthSeriesPoint], pbMax: Double, higherIsBetter: Bool = true, mode: TrendMode = .sum) -> HealthTrendSummary {
        let current = mode == .sum ? series.nonZeroSum : series.nonZeroAverage
        let previous = mode == .sum ? prior.nonZeroSum : prior.nonZeroAverage
        let deltaPct: Double?
        if previous > 0 {
            deltaPct = (current - previous) / previous * 100
        } else {
            deltaPct = nil
        }
        let curMax = series.map(\.value).max() ?? 0
        let isPB = curMax > 0 && curMax >= pbMax && pbMax > 0
        let streak = computeStreak(series: series, higherIsBetter: higherIsBetter)
        _ = higherIsBetter
        return HealthTrendSummary(current: current, previous: previous, deltaPct: deltaPct, isPersonalBest: isPB, streakDays: streak)
    }

    nonisolated enum TrendMode: Sendable { case sum, avg }

    private func computeStreak(series: [HealthSeriesPoint], higherIsBetter: Bool) -> Int {
        let sorted = series.sorted { $0.date > $1.date }
        let avg = series.nonZeroAverage
        guard avg > 0 else { return 0 }
        var streak = 0
        for p in sorted {
            if p.value > 0 && ((higherIsBetter && p.value >= avg * 0.9) || (!higherIsBetter && p.value <= avg * 1.1)) {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    var stepsTrend: HealthTrendSummary { trend(for: stepsSeries, prior: priorStepsSeries, pbMax: pbStepsMax, mode: .avg) }
    var activeCalTrend: HealthTrendSummary { trend(for: activeCalSeries, prior: priorActiveCalSeries, pbMax: pbActiveCalMax, mode: .avg) }
    var sleepTrend: HealthTrendSummary { trend(for: priorSleepTotals, prior: [], pbMax: pbSleepMax, mode: .avg) }
    var rhrTrend: HealthTrendSummary { trend(for: restingHRSeries, prior: priorRestingHRSeries, pbMax: 0, higherIsBetter: false, mode: .avg) }
    var hrvTrend: HealthTrendSummary { trend(for: hrvSeries, prior: priorHRVSeries, pbMax: pbHRVMax, mode: .avg) }
    var distanceTrend: HealthTrendSummary { trend(for: distanceSeries, prior: priorDistanceSeries, pbMax: pbDistanceMax, mode: .sum) }
    var exerciseTrend: HealthTrendSummary { trend(for: exerciseSeries, prior: priorExerciseSeries, pbMax: pbExerciseMax, mode: .sum) }

    var sleepSeries: [HealthSeriesPoint] {
        sleepNights.map { HealthSeriesPoint(date: $0.date, value: $0.asleep, min: 0, max: 0) }
    }

    init() {
        hydrateFromCache(period: period)
    }

    /// Loads persisted series for the given period so charts never render
    /// empty on cold launch. Called on init and when the period changes.
    func hydrateFromCache(period: HealthDetailPeriod) {
        guard let snap = HealthKitCache.loadDetail(period: period.rawValue) else { return }
        func map(_ arr: [HealthSeriesCachePoint]) -> [HealthSeriesPoint] {
            arr.map { HealthSeriesPoint(date: $0.date, value: $0.value, min: $0.min, max: $0.max) }
        }
        stepsSeries = map(snap.stepsSeries)
        activeCalSeries = map(snap.activeCalSeries)
        restingCalSeries = map(snap.restingCalSeries)
        distanceSeries = map(snap.distanceSeries)
        flightsSeries = map(snap.flightsSeries)
        exerciseSeries = map(snap.exerciseSeries)
        heartRateSeries = map(snap.heartRateSeries)
        restingHRSeries = map(snap.restingHRSeries)
        hrvSeries = map(snap.hrvSeries)
        walkingHRSeries = map(snap.walkingHRSeries)
        weightSeries = map(snap.weightSeries)
        bodyFatSeries = map(snap.bodyFatSeries)
        leanMassSeries = map(snap.leanMassSeries)
        bmiSeries = map(snap.bmiSeries)
        waistSeries = map(snap.waistSeries)
        respiratoryRateSeries = map(snap.respiratoryRateSeries)
        oxygenSaturationSeries = map(snap.oxygenSaturationSeries)
        bodyTempSeries = map(snap.bodyTempSeries)
        bloodGlucoseSeries = map(snap.bloodGlucoseSeries)
        systolicSeries = map(snap.systolicSeries)
        diastolicSeries = map(snap.diastolicSeries)
        vo2MaxSeries = map(snap.vo2MaxSeries)
        hydrationSeries = map(snap.hydrationSeries)
        dietaryEnergySeries = map(snap.dietaryEnergySeries)
        mindfulSeries = map(snap.mindfulSeries)
        sleepNights = snap.sleepNights.map { (date: $0.date, asleep: $0.asleep, deep: $0.deep, rem: $0.rem, core: $0.core) }
        priorSleepTotals = sleepNights.map { HealthSeriesPoint(date: $0.date, value: $0.asleep, min: 0, max: 0) }
        lastLoadedAt = snap.savedAt
        isShowingCachedData = true
    }

    private func persistCache() {
        func map(_ arr: [HealthSeriesPoint]) -> [HealthSeriesCachePoint] {
            arr.map { HealthSeriesCachePoint(date: $0.date, value: $0.value, min: $0.min, max: $0.max) }
        }
        var snap = HealthDetailCacheSnapshot()
        snap.period = period.rawValue
        snap.stepsSeries = map(stepsSeries)
        snap.activeCalSeries = map(activeCalSeries)
        snap.restingCalSeries = map(restingCalSeries)
        snap.distanceSeries = map(distanceSeries)
        snap.flightsSeries = map(flightsSeries)
        snap.exerciseSeries = map(exerciseSeries)
        snap.heartRateSeries = map(heartRateSeries)
        snap.restingHRSeries = map(restingHRSeries)
        snap.hrvSeries = map(hrvSeries)
        snap.walkingHRSeries = map(walkingHRSeries)
        snap.weightSeries = map(weightSeries)
        snap.bodyFatSeries = map(bodyFatSeries)
        snap.leanMassSeries = map(leanMassSeries)
        snap.bmiSeries = map(bmiSeries)
        snap.waistSeries = map(waistSeries)
        snap.respiratoryRateSeries = map(respiratoryRateSeries)
        snap.oxygenSaturationSeries = map(oxygenSaturationSeries)
        snap.bodyTempSeries = map(bodyTempSeries)
        snap.bloodGlucoseSeries = map(bloodGlucoseSeries)
        snap.systolicSeries = map(systolicSeries)
        snap.diastolicSeries = map(diastolicSeries)
        snap.vo2MaxSeries = map(vo2MaxSeries)
        snap.hydrationSeries = map(hydrationSeries)
        snap.dietaryEnergySeries = map(dietaryEnergySeries)
        snap.mindfulSeries = map(mindfulSeries)
        snap.sleepNights = sleepNights.map { HealthSleepCachePoint(date: $0.date, asleep: $0.asleep, deep: $0.deep, rem: $0.rem, core: $0.core) }
        snap.savedAt = Date()
        HealthKitCache.saveDetail(snap, period: period.rawValue)
    }

    func load() async {
        let hasCached = !stepsSeries.isEmpty || !sleepNights.isEmpty
        if hasCached {
            isRefreshing = true
        } else {
            isLoading = true
        }
        defer {
            isLoading = false
            isRefreshing = false
        }
        let days = period.days

        async let steps = healthKit.fetchDailySumSeries(for: .stepCount, unit: .count(), days: days)
        async let activeCal = healthKit.fetchDailySumSeries(for: .activeEnergyBurned, unit: .kilocalorie(), days: days)
        async let restingCal = healthKit.fetchDailySumSeries(for: .basalEnergyBurned, unit: .kilocalorie(), days: days)
        async let distance = healthKit.fetchDailySumSeries(for: .distanceWalkingRunning, unit: .meter(), days: days)
        async let flights = healthKit.fetchDailySumSeries(for: .flightsClimbed, unit: .count(), days: days)
        async let exercise = healthKit.fetchDailySumSeries(for: .appleExerciseTime, unit: .minute(), days: days)

        let bpm = HKUnit.count().unitDivided(by: .minute())
        async let hr = healthKit.fetchDailyRangeSeries(for: .heartRate, unit: bpm, days: days)
        async let restingHR = healthKit.fetchDailyAverageSeries(for: .restingHeartRate, unit: bpm, days: days)
        async let hrv = healthKit.fetchDailyAverageSeries(for: .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), days: days)
        async let walkingHR = healthKit.fetchDailyAverageSeries(for: .walkingHeartRateAverage, unit: bpm, days: days)

        async let weight = healthKit.fetchRecentSamples(for: .bodyMass, unit: .pound(), limit: 100)
        async let bodyFat = healthKit.fetchRecentSamples(for: .bodyFatPercentage, unit: .percent(), limit: 100)
        async let leanMass = healthKit.fetchRecentSamples(for: .leanBodyMass, unit: .pound(), limit: 100)
        async let bmi = healthKit.fetchRecentSamples(for: .bodyMassIndex, unit: .count(), limit: 100)
        async let waist = healthKit.fetchRecentSamples(for: .waistCircumference, unit: .inch(), limit: 100)

        async let rr = healthKit.fetchDailyAverageSeries(for: .respiratoryRate, unit: HKUnit.count().unitDivided(by: .minute()), days: days)
        async let o2 = healthKit.fetchDailyAverageSeries(for: .oxygenSaturation, unit: .percent(), days: days)
        async let temp = healthKit.fetchDailyAverageSeries(for: .bodyTemperature, unit: .degreeFahrenheit(), days: days)
        async let gluc = healthKit.fetchDailyAverageSeries(for: .bloodGlucose, unit: HKUnit(from: "mg/dL"), days: days)
        async let bps = healthKit.fetchDailyAverageSeries(for: .bloodPressureSystolic, unit: .millimeterOfMercury(), days: days)
        async let bpd = healthKit.fetchDailyAverageSeries(for: .bloodPressureDiastolic, unit: .millimeterOfMercury(), days: days)
        async let vo2 = healthKit.fetchRecentSamples(for: .vo2Max, unit: HKUnit(from: "ml/kg*min"), limit: 60)

        async let water = healthKit.fetchDailySumSeries(for: .dietaryWater, unit: .literUnit(with: .milli), days: days)
        async let dietEnergy = healthKit.fetchDailySumSeries(for: .dietaryEnergyConsumed, unit: .kilocalorie(), days: days)

        async let sleep = healthKit.fetchSleepHistory(days: days)

        async let mindful = healthKit.fetchMindfulDailySeries(days: days)
        let mindfulRes = await mindful

        let (stepsRes, activeCalRes, restingCalRes, distanceRes, flightsRes, exerciseRes) = await (steps, activeCal, restingCal, distance, flights, exercise)
        let (hrRes, restingHRRes, hrvRes, walkingHRRes) = await (hr, restingHR, hrv, walkingHR)
        let (weightRes, bodyFatRes, leanMassRes, bmiRes, waistRes) = await (weight, bodyFat, leanMass, bmi, waist)
        let (rrRes, o2Res, tempRes, glucRes, bpsRes, bpdRes, vo2Res) = await (rr, o2, temp, gluc, bps, bpd, vo2)
        let (waterRes, dietEnergyRes, sleepRes) = await (water, dietEnergy, sleep)

        stepsSeries = stepsRes.map { HealthSeriesPoint(date: $0.date, value: $0.value, min: 0, max: 0) }
        activeCalSeries = activeCalRes.map { HealthSeriesPoint(date: $0.date, value: $0.value, min: 0, max: 0) }
        restingCalSeries = restingCalRes.map { HealthSeriesPoint(date: $0.date, value: $0.value, min: 0, max: 0) }
        distanceSeries = distanceRes.map { HealthSeriesPoint(date: $0.date, value: $0.value / 1609.344, min: 0, max: 0) }
        flightsSeries = flightsRes.map { HealthSeriesPoint(date: $0.date, value: $0.value, min: 0, max: 0) }
        exerciseSeries = exerciseRes.map { HealthSeriesPoint(date: $0.date, value: $0.value, min: 0, max: 0) }

        heartRateSeries = hrRes.map { HealthSeriesPoint(date: $0.date, value: $0.avg, min: $0.min, max: $0.max) }
        restingHRSeries = restingHRRes.map { HealthSeriesPoint(date: $0.date, value: $0.value, min: 0, max: 0) }
        hrvSeries = hrvRes.map { HealthSeriesPoint(date: $0.date, value: $0.value, min: 0, max: 0) }
        walkingHRSeries = walkingHRRes.map { HealthSeriesPoint(date: $0.date, value: $0.value, min: 0, max: 0) }

        weightSeries = weightRes.map { HealthSeriesPoint(date: $0.date, value: $0.value, min: 0, max: 0) }
        bodyFatSeries = bodyFatRes.map { HealthSeriesPoint(date: $0.date, value: $0.value * 100, min: 0, max: 0) }
        leanMassSeries = leanMassRes.map { HealthSeriesPoint(date: $0.date, value: $0.value, min: 0, max: 0) }
        bmiSeries = bmiRes.map { HealthSeriesPoint(date: $0.date, value: $0.value, min: 0, max: 0) }
        waistSeries = waistRes.map { HealthSeriesPoint(date: $0.date, value: $0.value, min: 0, max: 0) }

        respiratoryRateSeries = rrRes.map { HealthSeriesPoint(date: $0.date, value: $0.value, min: 0, max: 0) }
        oxygenSaturationSeries = o2Res.map { HealthSeriesPoint(date: $0.date, value: $0.value * 100, min: 0, max: 0) }
        bodyTempSeries = tempRes.map { HealthSeriesPoint(date: $0.date, value: $0.value, min: 0, max: 0) }
        bloodGlucoseSeries = glucRes.map { HealthSeriesPoint(date: $0.date, value: $0.value, min: 0, max: 0) }
        systolicSeries = bpsRes.map { HealthSeriesPoint(date: $0.date, value: $0.value, min: 0, max: 0) }
        diastolicSeries = bpdRes.map { HealthSeriesPoint(date: $0.date, value: $0.value, min: 0, max: 0) }
        vo2MaxSeries = vo2Res.map { HealthSeriesPoint(date: $0.date, value: $0.value, min: 0, max: 0) }

        hydrationSeries = waterRes.map { HealthSeriesPoint(date: $0.date, value: $0.value, min: 0, max: 0) }
        dietaryEnergySeries = dietEnergyRes.map { HealthSeriesPoint(date: $0.date, value: $0.value, min: 0, max: 0) }
        mindfulSeries = mindfulRes.map { HealthSeriesPoint(date: $0.date, value: $0.value, min: 0, max: 0) }

        sleepNights = sleepRes.map { (date: $0.date, asleep: $0.asleepHours, deep: $0.deepHours, rem: $0.remHours, core: $0.coreHours) }
        priorSleepTotals = sleepNights.map { HealthSeriesPoint(date: $0.date, value: $0.asleep, min: 0, max: 0) }

        await loadPriorAndPBs(days: days)
    }

    private func loadPriorAndPBs(days: Int) async {
        let priorRange = days * 2
        let bpm = HKUnit.count().unitDivided(by: .minute())
        async let stepsFull = healthKit.fetchDailySumSeries(for: .stepCount, unit: .count(), days: max(priorRange, 90))
        async let activeFull = healthKit.fetchDailySumSeries(for: .activeEnergyBurned, unit: .kilocalorie(), days: max(priorRange, 90))
        async let distFull = healthKit.fetchDailySumSeries(for: .distanceWalkingRunning, unit: .meter(), days: max(priorRange, 90))
        async let exFull = healthKit.fetchDailySumSeries(for: .appleExerciseTime, unit: .minute(), days: max(priorRange, 90))
        async let rhrFull = healthKit.fetchDailyAverageSeries(for: .restingHeartRate, unit: bpm, days: max(priorRange, 90))
        async let hrvFull = healthKit.fetchDailyAverageSeries(for: .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), days: max(priorRange, 90))

        let (sF, aF, dF, eF, rF, hF) = await (stepsFull, activeFull, distFull, exFull, rhrFull, hrvFull)

        let cutoff = Calendar.current.startOfDay(for: Date()).addingTimeInterval(-Double(days) * 86400)
        let cal = Calendar.current

        func split<T>(_ arr: [T], dateKey: (T) -> Date) -> (current: [T], prior: [T]) {
            var cur: [T] = []
            var pri: [T] = []
            for el in arr {
                let d = cal.startOfDay(for: dateKey(el))
                if d >= cutoff { cur.append(el) } else { pri.append(el) }
            }
            return (cur, pri)
        }

        let stepsSplit = split(sF) { $0.date }
        let activeSplit = split(aF) { $0.date }
        let distSplit = split(dF) { $0.date }
        let exSplit = split(eF) { $0.date }
        let rhrSplit = split(rF) { $0.date }
        let hrvSplit = split(hF) { $0.date }

        priorStepsSeries = stepsSplit.prior.map { HealthSeriesPoint(date: $0.date, value: $0.value, min: 0, max: 0) }
        priorActiveCalSeries = activeSplit.prior.map { HealthSeriesPoint(date: $0.date, value: $0.value, min: 0, max: 0) }
        priorDistanceSeries = distSplit.prior.map { HealthSeriesPoint(date: $0.date, value: $0.value / 1609.344, min: 0, max: 0) }
        priorExerciseSeries = exSplit.prior.map { HealthSeriesPoint(date: $0.date, value: $0.value, min: 0, max: 0) }
        priorRestingHRSeries = rhrSplit.prior.map { HealthSeriesPoint(date: $0.date, value: $0.value, min: 0, max: 0) }
        priorHRVSeries = hrvSplit.prior.map { HealthSeriesPoint(date: $0.date, value: $0.value, min: 0, max: 0) }

        pbStepsMax = sF.map(\.value).max() ?? 0
        pbActiveCalMax = aF.map(\.value).max() ?? 0
        pbDistanceMax = (dF.map(\.value).max() ?? 0) / 1609.344
        pbExerciseMax = eF.map(\.value).max() ?? 0
        pbHRVMax = hF.map(\.value).max() ?? 0

        lastLoadedAt = Date()
        isShowingCachedData = false
        persistCache()
    }
}
