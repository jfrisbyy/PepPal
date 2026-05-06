import SwiftUI
import HealthKit

@Observable
final class SwimmingViewModel {
    static let shared = SwimmingViewModel()

    var completedSwims: [CompletedSwim] = []
    var settings: SwimmingSettings = SwimmingSettings()
    var savedWorkouts: [StructuredSwimWorkout] = []
    var cssHistory: [CSSResult] = []

    var isSwimming: Bool = false
    var selectedSessionType: SwimSessionType = .poolLaps

    var showSwimDetail: Bool = false
    var selectedSwim: CompletedSwim? = nil
    var showSwimSettings: Bool = false
    var showDrillLibrary: Bool = false
    var showWorkoutBuilder: Bool = false
    var showCSSTest: Bool = false
    var isImportingFromHealthKit: Bool = false
    var healthKitImportCount: Int = 0

    private let healthKit = HealthKitService.shared

    private init() {
        loadSampleData()
    }

    func importSwimDataFromHealthKit() async {
        guard healthKit.isHealthKitEnabled, healthKit.isAuthorized else { return }
        isImportingFromHealthKit = true
        defer { isImportingFromHealthKit = false }

        let swimWorkouts = await healthKit.fetchSwimWorkouts(limit: 30)
        var importedCount = 0

        for workout in swimWorkouts {
            let alreadyExists = completedSwims.contains { swim in
                abs(swim.date.timeIntervalSince(workout.startDate)) < 60 &&
                abs(swim.durationSeconds - workout.duration) < 30
            }
            guard !alreadyExists else { continue }

            let calories = await healthKit.fetchWorkoutCalories(for: workout)
            let distanceMeters = await healthKit.fetchWorkoutDistance(for: workout, type: .distanceSwimming)
            let hrSamples = await healthKit.fetchWorkoutHeartRateSamples(for: workout)

            let hrUnit = HKUnit.count().unitDivided(by: .minute())
            let bpms = hrSamples.map { Int($0.quantity.doubleValue(for: hrUnit)) }
            let avgHR = bpms.isEmpty ? 0 : bpms.reduce(0, +) / bpms.count
            let maxHR = bpms.max() ?? 0

            let duration = workout.duration
            let finalDistance = distanceMeters > 0 ? distanceMeters : (workout.totalDistance?.doubleValue(for: .meter()) ?? 0)
            let poolM = settings.poolLength.lengthInMeters
            let laps = poolM > 0 ? Int(finalDistance / poolM) : 0
            let avgPace = finalDistance > 0 ? (duration / finalDistance) * 100 : 0

            let zones = computeZonesFromHR(bpms: bpms, hrSamples: hrSamples, totalDuration: duration)

            let swim = CompletedSwim(
                date: workout.startDate,
                sessionType: .poolLaps,
                poolLength: settings.poolLength,
                totalLaps: laps,
                totalDistanceMeters: finalDistance,
                durationSeconds: duration,
                averagePacePer100: avgPace,
                bestPacePer100: avgPace * 0.9,
                averageSwolf: 0,
                bestSwolf: 0,
                averageStrokeCount: 0,
                totalStrokeCount: 0,
                averageHeartRate: avgHR,
                maxHeartRate: maxHR,
                caloriesBurned: Int(calories),
                heartRateZones: zones
            )

            completedSwims.append(swim)
            importedCount += 1
        }

        if importedCount > 0 {
            completedSwims.sort { $0.date > $1.date }
        }
        healthKitImportCount = importedCount
    }

    private func computeZonesFromHR(bpms: [Int], hrSamples: [HKQuantitySample], totalDuration: TimeInterval) -> [HeartRateZoneDistribution] {
        guard !bpms.isEmpty, totalDuration > 0 else {
            return generateSampleZones(duration: totalDuration)
        }

        var zoneTimes: [HeartRateZone: TimeInterval] = [:]
        for zone in HeartRateZone.allCases { zoneTimes[zone] = 0 }

        for i in 0..<hrSamples.count {
            let bpm = bpms[i]
            let zone = HeartRateZone.zone(for: bpm)
            let dur: TimeInterval
            if i + 1 < hrSamples.count {
                dur = hrSamples[i + 1].startDate.timeIntervalSince(hrSamples[i].startDate)
            } else {
                dur = 5
            }
            zoneTimes[zone, default: 0] += min(max(dur, 0), 300)
        }

        let totalTracked = zoneTimes.values.reduce(0, +)
        guard totalTracked > 0 else { return generateSampleZones(duration: totalDuration) }

        return HeartRateZone.allCases.map { zone in
            let time = zoneTimes[zone] ?? 0
            return HeartRateZoneDistribution(zone: zone, timeInZone: time, percentage: time / totalTracked)
        }
    }

    func saveSwimToHealthKit(_ swim: CompletedSwim) {
        Task {
            await healthKit.saveWorkout(
                type: .swimming,
                start: swim.date.addingTimeInterval(-swim.durationSeconds),
                end: swim.date,
                calories: Double(swim.caloriesBurned),
                distanceMeters: swim.totalDistanceMeters,
                distanceType: .distanceSwimming
            )
        }
    }

    var totalMetersAllTime: Double {
        completedSwims.reduce(0) { $0 + $1.totalDistanceMeters }
    }

    var totalLapsAllTime: Int {
        completedSwims.reduce(0) { $0 + $1.totalLaps }
    }

    var totalSwimsAllTime: Int { completedSwims.count }

    var averagePaceAllTime: Double {
        let paces = completedSwims.filter { $0.averagePacePer100 > 0 }.map(\.averagePacePer100)
        guard !paces.isEmpty else { return 0 }
        return paces.reduce(0, +) / Double(paces.count)
    }

    var averageSwolfAllTime: Double {
        let swolfs = completedSwims.filter { $0.averageSwolf > 0 }.map(\.averageSwolf)
        guard !swolfs.isEmpty else { return 0 }
        return swolfs.reduce(0, +) / Double(swolfs.count)
    }

    var thisWeekSwims: [CompletedSwim] {
        let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return completedSwims.filter { $0.date >= weekStart }
    }

    var thisWeekMeters: Double {
        thisWeekSwims.reduce(0) { $0 + $1.totalDistanceMeters }
    }

    var thisWeekLaps: Int {
        thisWeekSwims.reduce(0) { $0 + $1.totalLaps }
    }

    var thisMonthMeters: Double {
        let monthStart = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        return completedSwims.filter { $0.date >= monthStart }.reduce(0) { $0 + $1.totalDistanceMeters }
    }

    var bestPaceEver: Double {
        completedSwims.filter { $0.bestPacePer100 > 0 }.map(\.bestPacePer100).min() ?? 0
    }

    var bestSwolfEver: Int {
        completedSwims.filter { $0.bestSwolf > 0 }.map(\.bestSwolf).min() ?? 0
    }

    var longestSwimMeters: Double {
        completedSwims.map(\.totalDistanceMeters).max() ?? 0
    }

    var currentCSS: CSSResult? {
        cssHistory.sorted(by: { $0.date > $1.date }).first
    }

    var paceZones: [SwimPaceZone] {
        guard let css = currentCSS else { return [] }
        let base = css.cssPacePer100m
        return [
            SwimPaceZone(name: "Recovery", paceRange: ">\(SwimFormatters.formatPace(base * 1.3))", color: .blue, cssPercentage: 1.3...2.0),
            SwimPaceZone(name: "Aerobic", paceRange: "\(SwimFormatters.formatPace(base * 1.1))-\(SwimFormatters.formatPace(base * 1.3))", color: .green, cssPercentage: 1.1...1.3),
            SwimPaceZone(name: "Threshold", paceRange: "\(SwimFormatters.formatPace(base * 0.95))-\(SwimFormatters.formatPace(base * 1.1))", color: .yellow, cssPercentage: 0.95...1.1),
            SwimPaceZone(name: "VO2 Max", paceRange: "\(SwimFormatters.formatPace(base * 0.85))-\(SwimFormatters.formatPace(base * 0.95))", color: .orange, cssPercentage: 0.85...0.95),
            SwimPaceZone(name: "Sprint", paceRange: "<\(SwimFormatters.formatPace(base * 0.85))", color: .red, cssPercentage: 0.0...0.85),
        ]
    }

    var weeklyVolumeHistory: [WeeklySwimVolume] {
        let cal = Calendar.current
        let now = Date()
        return (0..<12).reversed().compactMap { weekOffset -> WeeklySwimVolume? in
            guard let weekStart = cal.date(byAdding: .weekOfYear, value: -weekOffset, to: now) else { return nil }
            let weekEnd = cal.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? now
            let weekSwims = completedSwims.filter { $0.date >= weekStart && $0.date < weekEnd }
            let totalMeters = weekSwims.reduce(0) { $0 + $1.totalDistanceMeters }
            let avgPace = weekSwims.isEmpty ? 0 : weekSwims.reduce(0) { $0 + $1.averagePacePer100 } / Double(weekSwims.count)
            let avgSwolf = weekSwims.isEmpty ? 0 : weekSwims.reduce(0) { $0 + $1.averageSwolf } / Double(weekSwims.count)
            return WeeklySwimVolume(weekStart: weekStart, totalMeters: totalMeters, swimCount: weekSwims.count, avgPace: avgPace, avgSwolf: avgSwolf)
        }
    }

    var paceOverTimeData: [(date: Date, pace: Double)] {
        completedSwims
            .filter { $0.averagePacePer100 > 0 }
            .sorted { $0.date < $1.date }
            .suffix(20)
            .map { (date: $0.date, pace: $0.averagePacePer100) }
    }

    var swolfOverTimeData: [(date: Date, swolf: Double)] {
        completedSwims
            .filter { $0.averageSwolf > 0 }
            .sorted { $0.date < $1.date }
            .suffix(20)
            .map { (date: $0.date, swolf: $0.averageSwolf) }
    }

    var personalBests: [SwimPersonalBest] {
        var bests: [SwimPersonalBest] = []
        let distances: [(String, ClosedRange<Double>)] = [
            ("100m", 80...120),
            ("200m", 180...220),
            ("400m", 380...420),
            ("800m", 780...820),
            ("1500m", 1480...1520),
        ]
        for (label, range) in distances {
            let matching = completedSwims.filter { range.contains($0.totalDistanceMeters) }
            if let best = matching.min(by: { $0.durationSeconds < $1.durationSeconds }) {
                bests.append(SwimPersonalBest(distance: label, time: best.durationSeconds, pace: best.averagePacePer100, date: best.date))
            }
        }
        return bests
    }

    var strokeDistribution: [StrokeBreakdown] {
        var strokeLaps: [SwimStrokeType: (laps: Int, pace: Double, swolf: Double)] = [:]
        var totalLaps = 0
        for swim in completedSwims {
            for breakdown in swim.strokeBreakdown {
                let existing = strokeLaps[breakdown.strokeType] ?? (0, 0, 0)
                strokeLaps[breakdown.strokeType] = (
                    existing.laps + breakdown.laps,
                    existing.pace + breakdown.averagePace * Double(breakdown.laps),
                    existing.swolf + breakdown.averageSwolf * Double(breakdown.laps)
                )
                totalLaps += breakdown.laps
            }
        }
        guard totalLaps > 0 else { return [] }
        return strokeLaps.map { stroke, data in
            StrokeBreakdown(
                strokeType: stroke,
                laps: data.laps,
                distanceMeters: Double(data.laps) * settings.poolLength.lengthInMeters,
                averagePace: data.laps > 0 ? data.pace / Double(data.laps) : 0,
                averageSwolf: data.laps > 0 ? data.swolf / Double(data.laps) : 0,
                percentage: Double(data.laps) / Double(totalLaps)
            )
        }.sorted { $0.laps > $1.laps }
    }

    var insights: [SwimInsight] {
        var result: [SwimInsight] = []
        let recent = completedSwims.prefix(8)
        guard !recent.isEmpty else {
            result.append(SwimInsight(
                kind: .suggestion,
                title: "Log your first swim",
                message: "Sync from Apple Watch or tap a session type to start your story in the lane."
            ))
            return result
        }

        // Volume trend
        let volume = weeklyVolumeHistory
        if volume.count >= 2 {
            let last = volume.last?.totalMeters ?? 0
            let prev = volume[volume.count - 2].totalMeters
            if prev > 0 {
                let delta = (last - prev) / prev
                if delta > 0.15 {
                    result.append(SwimInsight(
                        kind: .progress,
                        title: "Volume trending up",
                        message: "You’re up \(Int(delta * 100))% over last week. Keep one swim genuinely easy to hold the trend."
                    ))
                } else if delta < -0.25 {
                    result.append(SwimInsight(
                        kind: .warning,
                        title: "Volume dropped this week",
                        message: "\(SwimFormatters.formatDistance(last)) so far. A quick technique swim is enough to keep the rhythm."
                    ))
                }
            }
        }

        // SWOLF improvement
        let swolfData = swolfOverTimeData
        if swolfData.count >= 4 {
            let earlyAvg = swolfData.prefix(2).map(\.swolf).reduce(0, +) / 2
            let recentAvg = swolfData.suffix(2).map(\.swolf).reduce(0, +) / 2
            if earlyAvg - recentAvg >= 1.0 {
                result.append(SwimInsight(
                    kind: .progress,
                    title: "SWOLF dropping",
                    message: "Average down \(String(format: "%.1f", earlyAvg - recentAvg)). Your stroke is buying you more distance."
                ))
            }
        }

        // Stroke balance
        let dist = strokeDistribution
        if let free = dist.first(where: { $0.strokeType == .freestyle }), free.percentage > 0.85, completedSwims.count >= 4 {
            result.append(SwimInsight(
                kind: .suggestion,
                title: "Mostly freestyle",
                message: "\(Int(free.percentage * 100))% of your laps are free. Sprinkle 4×50 IM kick or backstroke to stay balanced."
            ))
        }

        // CSS suggestion
        if currentCSS == nil {
            result.append(SwimInsight(
                kind: .suggestion,
                title: "Set your CSS",
                message: "A 400 + 200 time trial unlocks pace zones and threshold sets. Takes ~12 minutes."
            ))
        } else if let css = currentCSS, Date().timeIntervalSince(css.date) > 60 * 60 * 24 * 60 {
            result.append(SwimInsight(
                kind: .suggestion,
                title: "Time to retest CSS",
                message: "Your last test was \(Int(Date().timeIntervalSince(css.date) / 86400)) days ago. Pace zones drift — retest to recalibrate."
            ))
        }

        // Recovery
        let last24h = completedSwims.filter { Date().timeIntervalSince($0.date) < 24 * 3600 }
        let totalToday = last24h.reduce(0) { $0 + $1.totalDistanceMeters }
        if totalToday >= 2500 {
            result.append(SwimInsight(
                kind: .recovery,
                title: "Big day in the water",
                message: "\(SwimFormatters.formatDistance(totalToday)) today. Hydrate, stretch shoulders, and consider an easy 1000m tomorrow."
            ))
        }

        if result.isEmpty {
            result.append(SwimInsight(
                kind: .suggestion,
                title: "Pick a focus",
                message: "Try a drill set this week — small technique gains compound into big SWOLF drops."
            ))
        }

        return Array(result.prefix(4))
    }

    var weeklyFocus: SwimWeeklyFocus {
        let dist = strokeDistribution
        let weakStroke: SwimStrokeType?
        if let underused = dist.min(by: { $0.percentage < $1.percentage }), underused.percentage < 0.15 {
            weakStroke = underused.strokeType
        } else {
            weakStroke = nil
        }

        if let stroke = weakStroke {
            let drill = SwimDrillLibraryData.all.first { $0.targetStroke == stroke } ?? SwimDrillLibraryData.all.first
            return SwimWeeklyFocus(
                kicker: "This Week",
                title: "Round out your \(stroke.rawValue.lowercased())",
                rationale: "Only \(Int((dist.first { $0.strokeType == stroke }?.percentage ?? 0) * 100))% of recent laps. A balanced swimmer is a faster swimmer.",
                drillName: drill?.name,
                targetStroke: stroke
            )
        }

        if currentCSS == nil {
            return SwimWeeklyFocus(
                kicker: "This Week",
                title: "Find your threshold",
                rationale: "Run a CSS test — it sets every pace zone in this app. 12 minutes well spent.",
                drillName: "400m Threshold Set",
                targetStroke: .freestyle
            )
        }

        if averageSwolfAllTime > 38 {
            return SwimWeeklyFocus(
                kicker: "This Week",
                title: "Drop your SWOLF",
                rationale: "Average is \(Int(averageSwolfAllTime)). Three drill swims this week can shave 2–3 points.",
                drillName: "Catch-Up Drill",
                targetStroke: .freestyle
            )
        }

        return SwimWeeklyFocus(
            kicker: "This Week",
            title: "Build the aerobic base",
            rationale: "You're swimming clean. A long, steady swim this week pays off in race fitness.",
            drillName: "200m Steady Swim",
            targetStroke: .freestyle
        )
    }

    func addCSSResult(time400m: TimeInterval, time200m: TimeInterval) {
        let pace = CSSResult.calculate(time400m: time400m, time200m: time200m)
        let result = CSSResult(date: Date(), time400m: time400m, time200m: time200m, cssPacePer100m: pace)
        cssHistory.append(result)
    }

    func addSavedWorkout(_ workout: StructuredSwimWorkout) {
        savedWorkouts.append(workout)
    }

    func deleteSavedWorkout(_ id: UUID) {
        savedWorkouts.removeAll { $0.id == id }
    }

    func logSwim(_ swim: CompletedSwim) {
        completedSwims.insert(swim, at: 0)
    }

    private func loadSampleData() {
        let cal = Calendar.current
        let now = Date()

        let cssResult = CSSResult(
            date: cal.date(byAdding: .day, value: -14, to: now)!,
            time400m: 360,
            time200m: 165,
            cssPacePer100m: CSSResult.calculate(time400m: 360, time200m: 165)
        )
        cssHistory = [cssResult]

        savedWorkouts = [
            StructuredSwimWorkout(name: "Endurance Builder", intervals: [
                SwimInterval(distanceMeters: 200, targetPace: 130, strokeType: .freestyle, restSeconds: 20, repetitions: 1),
                SwimInterval(distanceMeters: 100, targetPace: 110, strokeType: .freestyle, restSeconds: 15, repetitions: 6),
                SwimInterval(distanceMeters: 50, targetPace: 95, strokeType: .freestyle, restSeconds: 30, repetitions: 4),
                SwimInterval(distanceMeters: 200, targetPace: 140, strokeType: .freestyle, restSeconds: 0, repetitions: 1),
            ]),
            StructuredSwimWorkout(name: "Mixed Stroke Session", intervals: [
                SwimInterval(distanceMeters: 100, targetPace: 130, strokeType: .freestyle, restSeconds: 15, repetitions: 2),
                SwimInterval(distanceMeters: 100, targetPace: 140, strokeType: .backstroke, restSeconds: 15, repetitions: 2),
                SwimInterval(distanceMeters: 100, targetPace: 150, strokeType: .breaststroke, restSeconds: 20, repetitions: 2),
                SwimInterval(distanceMeters: 50, targetPace: 100, strokeType: .butterfly, restSeconds: 30, repetitions: 2),
                SwimInterval(distanceMeters: 200, targetPace: 140, strokeType: .freestyle, restSeconds: 0, repetitions: 1),
            ]),
            StructuredSwimWorkout(name: "Sprint Day", intervals: [
                SwimInterval(distanceMeters: 200, targetPace: 130, strokeType: .freestyle, restSeconds: 20, repetitions: 1),
                SwimInterval(distanceMeters: 25, targetPace: 70, strokeType: .freestyle, restSeconds: 30, repetitions: 8),
                SwimInterval(distanceMeters: 50, targetPace: 80, strokeType: .freestyle, restSeconds: 30, repetitions: 4),
                SwimInterval(distanceMeters: 100, targetPace: 140, strokeType: .freestyle, restSeconds: 0, repetitions: 2),
            ]),
        ]

        completedSwims = [
            generateSampleSwim(daysAgo: 0, hours: 5, type: .poolLaps, laps: 40, distanceM: 1000, duration: 1800, avgPace: 108, bestPace: 95, avgSwolf: 38, bestSwolf: 33, avgHR: 148, maxHR: 172, cal: 420),
            generateSampleSwim(daysAgo: 1, hours: 0, type: .structuredWorkout, laps: 52, distanceM: 1300, duration: 2400, avgPace: 112, bestPace: 88, avgSwolf: 36, bestSwolf: 31, avgHR: 158, maxHR: 182, cal: 560),
            generateSampleSwim(daysAgo: 3, hours: 0, type: .poolLaps, laps: 60, distanceM: 1500, duration: 2700, avgPace: 105, bestPace: 92, avgSwolf: 37, bestSwolf: 32, avgHR: 152, maxHR: 178, cal: 650),
            generateSampleSwim(daysAgo: 5, hours: 0, type: .openWater, laps: 0, distanceM: 2000, duration: 3000, avgPace: 115, bestPace: 100, avgSwolf: 0, bestSwolf: 0, avgHR: 155, maxHR: 180, cal: 720),
            generateSampleSwim(daysAgo: 7, hours: 0, type: .drillSession, laps: 30, distanceM: 750, duration: 1500, avgPace: 120, bestPace: 105, avgSwolf: 42, bestSwolf: 36, avgHR: 138, maxHR: 158, cal: 340),
            generateSampleSwim(daysAgo: 9, hours: 0, type: .poolLaps, laps: 44, distanceM: 1100, duration: 2100, avgPace: 110, bestPace: 96, avgSwolf: 39, bestSwolf: 34, avgHR: 150, maxHR: 175, cal: 480),
            generateSampleSwim(daysAgo: 12, hours: 0, type: .structuredWorkout, laps: 56, distanceM: 1400, duration: 2520, avgPace: 108, bestPace: 90, avgSwolf: 35, bestSwolf: 30, avgHR: 160, maxHR: 185, cal: 600),
            generateSampleSwim(daysAgo: 14, hours: 0, type: .poolLaps, laps: 48, distanceM: 1200, duration: 2160, avgPace: 106, bestPace: 94, avgSwolf: 37, bestSwolf: 32, avgHR: 148, maxHR: 170, cal: 500),
        ]
    }

    private func generateSampleSwim(daysAgo: Int, hours: Int, type: SwimSessionType, laps: Int, distanceM: Double, duration: TimeInterval, avgPace: Double, bestPace: Double, avgSwolf: Double, bestSwolf: Int, avgHR: Int, maxHR: Int, cal: Int) -> CompletedSwim {
        let date: Date
        if hours > 0 {
            date = Calendar.current.date(byAdding: .hour, value: -hours, to: Date())!
        } else {
            date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        }

        let sampleLaps = generateSampleLaps(count: laps, avgPace: avgPace, poolMeters: settings.poolLength.lengthInMeters)
        let breakdown = generateStrokeBreakdown(totalLaps: laps)
        let zones = generateSampleZones(duration: duration)

        var openWaterCoords: [OpenWaterCoordinate] = []
        if type == .openWater {
            openWaterCoords = generateOpenWaterRoute(count: 40)
        }

        return CompletedSwim(
            date: date,
            sessionType: type,
            poolLength: type == .openWater ? .meters25 : settings.poolLength,
            totalLaps: laps,
            totalDistanceMeters: distanceM,
            durationSeconds: duration,
            averagePacePer100: avgPace,
            bestPacePer100: bestPace,
            averageSwolf: avgSwolf,
            bestSwolf: bestSwolf,
            averageStrokeCount: Double(Int.random(in: 14...22)),
            totalStrokeCount: laps * Int.random(in: 14...22),
            averageHeartRate: avgHR,
            maxHeartRate: maxHR,
            caloriesBurned: cal,
            laps: sampleLaps,
            strokeBreakdown: breakdown,
            heartRateZones: zones,
            openWaterCoordinates: openWaterCoords
        )
    }

    private func generateSampleLaps(count: Int, avgPace: Double, poolMeters: Double) -> [SwimLap] {
        guard count > 0 else { return [] }
        let strokes: [SwimStrokeType] = [.freestyle, .freestyle, .freestyle, .backstroke, .breaststroke]
        return (1...count).map { i in
            let stroke = strokes[i % strokes.count]
            let variance = Double.random(in: -8...8)
            let lapDuration = (avgPace + variance) * poolMeters / 100.0
            let strokeCount = Int.random(in: 14...22)
            return SwimLap(lapNumber: i, strokeType: stroke, duration: lapDuration, strokeCount: strokeCount, poolLengthMeters: poolMeters)
        }
    }

    private func generateStrokeBreakdown(totalLaps: Int) -> [StrokeBreakdown] {
        guard totalLaps > 0 else { return [] }
        let freePct = Double.random(in: 0.55...0.7)
        let backPct = Double.random(in: 0.1...0.2)
        let breastPct = Double.random(in: 0.1...0.15)
        let flyPct = max(1.0 - freePct - backPct - breastPct, 0)

        let poolM = settings.poolLength.lengthInMeters
        return [
            StrokeBreakdown(strokeType: .freestyle, laps: Int(Double(totalLaps) * freePct), distanceMeters: Double(Int(Double(totalLaps) * freePct)) * poolM, averagePace: Double.random(in: 95...110), averageSwolf: Double.random(in: 32...38), percentage: freePct),
            StrokeBreakdown(strokeType: .backstroke, laps: Int(Double(totalLaps) * backPct), distanceMeters: Double(Int(Double(totalLaps) * backPct)) * poolM, averagePace: Double.random(in: 110...130), averageSwolf: Double.random(in: 38...45), percentage: backPct),
            StrokeBreakdown(strokeType: .breaststroke, laps: Int(Double(totalLaps) * breastPct), distanceMeters: Double(Int(Double(totalLaps) * breastPct)) * poolM, averagePace: Double.random(in: 120...145), averageSwolf: Double.random(in: 40...48), percentage: breastPct),
            StrokeBreakdown(strokeType: .butterfly, laps: Int(Double(totalLaps) * flyPct), distanceMeters: Double(Int(Double(totalLaps) * flyPct)) * poolM, averagePace: Double.random(in: 105...125), averageSwolf: Double.random(in: 36...44), percentage: flyPct),
        ].filter { $0.laps > 0 }
    }

    private func generateSampleZones(duration: TimeInterval) -> [HeartRateZoneDistribution] {
        let z1 = Double.random(in: 0.06...0.14)
        let z2 = Double.random(in: 0.24...0.34)
        let z3 = Double.random(in: 0.26...0.36)
        let z4 = Double.random(in: 0.1...0.18)
        let z5 = max(1.0 - z1 - z2 - z3 - z4, 0)
        return [
            HeartRateZoneDistribution(zone: .zone1, timeInZone: duration * z1, percentage: z1),
            HeartRateZoneDistribution(zone: .zone2, timeInZone: duration * z2, percentage: z2),
            HeartRateZoneDistribution(zone: .zone3, timeInZone: duration * z3, percentage: z3),
            HeartRateZoneDistribution(zone: .zone4, timeInZone: duration * z4, percentage: z4),
            HeartRateZoneDistribution(zone: .zone5, timeInZone: duration * z5, percentage: z5),
        ]
    }

    private func generateOpenWaterRoute(count: Int) -> [OpenWaterCoordinate] {
        let baseLat: Double = 37.8085
        let baseLng: Double = -122.4098
        let now = Date()
        return (0..<count).map { i in
            let angle = Double(i) * (2 * .pi / Double(count))
            let lat = baseLat + 0.003 * sin(angle) + Double.random(in: -0.0003...0.0003)
            let lng = baseLng + 0.004 * cos(angle) + Double.random(in: -0.0003...0.0003)
            return OpenWaterCoordinate(latitude: lat, longitude: lng, timestamp: now.addingTimeInterval(-Double(count - i) * 45))
        }
    }
}
