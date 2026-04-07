import SwiftUI
import CoreLocation
import AVFoundation
import MapKit
import HealthKit

@Observable
final class RunningViewModel {
    static let shared = RunningViewModel()

    var completedRuns: [CompletedRun] = []
    var shoes: [RunningShoe] = []
    var settings: RunningSettings = RunningSettings()
    var courseRecords: [PersonalCourseRecord] = []

    var isRunning: Bool = false
    var isPaused: Bool = false
    var isTreadmillMode: Bool = false
    var selectedRunType: RunType = .easyRun
    var selectedShoeId: UUID? = nil

    var elapsedSeconds: TimeInterval = 0
    var currentDistanceMiles: Double = 0
    var currentPace: Double = 0
    var currentHeartRate: Int = 0
    var currentCadence: Int = 0
    var currentElevation: Double = 0
    var currentCalories: Int = 0
    var currentSplits: [RunSplit] = []
    var routePoints: [RouteCoordinate] = []

    var gpsSignal: GPSSignalQuality = .none

    var showRunDetail: Bool = false
    var selectedRun: CompletedRun? = nil
    var showShoeManager: Bool = false
    var showRunSettings: Bool = false
    var showAddShoe: Bool = false
    var showWorkoutBuilder: Bool = false
    var savedRunWorkouts: [CustomRunWorkout] = []

    private var timer: Timer? = nil
    private var lastSplitDistance: Double = 0
    private let locationService = LocationTrackingService.shared

    private var lastLocation: CLLocation?
    private var totalElevationGain: Double = 0
    private var totalElevationLoss: Double = 0
    private var lastAltitude: Double?
    private var elevationSamples: [Double] = []
    private let elevationSmoothingWindow: Int = 5
    private var autoPausedAt: Date?
    private let autoPauseSpeedThreshold: Double = 0.3
    private let healthKit = HealthKitService.shared
    private var workoutStartDate: Date?

    private init() {
        loadSampleData()
    }

    var currentHeartRateZone: HeartRateZone {
        HeartRateZone.zone(for: currentHeartRate)
    }

    var elapsedFormatted: String {
        let hours = Int(elapsedSeconds) / 3600
        let minutes = (Int(elapsedSeconds) % 3600) / 60
        let secs = Int(elapsedSeconds) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    var currentPaceFormatted: String {
        guard currentPace > 0, currentPace < 30 else { return "--:--" }
        let minutes = Int(currentPace)
        let seconds = Int((currentPace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }

    var currentDistanceFormatted: String {
        if settings.distanceUnit == .kilometers {
            return String(format: "%.2f", currentDistanceMiles * 1.60934)
        }
        return String(format: "%.2f", currentDistanceMiles)
    }

    // MARK: - Dashboard Stats

    var totalMilesAllTime: Double {
        completedRuns.reduce(0) { $0 + $1.distanceMiles }
    }

    var totalRunsAllTime: Int { completedRuns.count }

    var averagePaceAllTime: Double {
        let paces = completedRuns.filter { $0.averagePace > 0 }.map(\.averagePace)
        guard !paces.isEmpty else { return 0 }
        return paces.reduce(0, +) / Double(paces.count)
    }

    var thisWeekRuns: [CompletedRun] {
        let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return completedRuns.filter { $0.date >= weekStart }
    }

    var thisWeekMiles: Double {
        thisWeekRuns.reduce(0) { $0 + $1.distanceMiles }
    }

    var thisMonthMiles: Double {
        let monthStart = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        return completedRuns.filter { $0.date >= monthStart }.reduce(0) { $0 + $1.distanceMiles }
    }

    var longestRunEver: Double {
        completedRuns.map(\.distanceMiles).max() ?? 0
    }

    var bestPaceEver: Double {
        completedRuns.filter { $0.bestPace > 0 }.map(\.bestPace).min() ?? 0
    }

    var weeklyMileageHistory: [WeeklyMileage] {
        let cal = Calendar.current
        let now = Date()
        return (0..<12).reversed().compactMap { weekOffset -> WeeklyMileage? in
            guard let weekStart = cal.date(byAdding: .weekOfYear, value: -weekOffset, to: now) else { return nil }
            let weekEnd = cal.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? now
            let weekRuns = completedRuns.filter { $0.date >= weekStart && $0.date < weekEnd }
            let totalMiles = weekRuns.reduce(0) { $0 + $1.distanceMiles }
            let avgPace = weekRuns.isEmpty ? 0 : weekRuns.reduce(0) { $0 + $1.averagePace } / Double(weekRuns.count)
            return WeeklyMileage(weekStart: weekStart, totalMiles: totalMiles, runCount: weekRuns.count, avgPace: avgPace)
        }
    }

    var racePredictions: [RacePrediction] {
        let recentRuns = completedRuns.filter { $0.distanceMiles >= 2 && $0.averagePace > 0 }.prefix(10)
        guard !recentRuns.isEmpty else { return [] }
        let avgPace = recentRuns.reduce(0.0) { $0 + $1.averagePace } / Double(recentRuns.count)

        return [
            RacePrediction(raceName: "5K", distance: 3.107, predictedTime: avgPace * 3.107 * 60 * 0.95, confidence: 0.85),
            RacePrediction(raceName: "10K", distance: 6.214, predictedTime: avgPace * 6.214 * 60 * 0.98, confidence: 0.78),
            RacePrediction(raceName: "Half Marathon", distance: 13.109, predictedTime: avgPace * 13.109 * 60 * 1.05, confidence: 0.65),
            RacePrediction(raceName: "Marathon", distance: 26.219, predictedTime: avgPace * 26.219 * 60 * 1.12, confidence: 0.50),
        ]
    }

    var todayDailyDistance: [(day: Date, distance: Double)] {
        let cal = Calendar.current
        let now = Date()
        return (0..<7).reversed().map { dayOffset in
            let day = cal.date(byAdding: .day, value: -dayOffset, to: now)!
            let dayStart = cal.startOfDay(for: day)
            let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
            let dist = completedRuns.filter { $0.date >= dayStart && $0.date < dayEnd }.reduce(0) { $0 + $1.distanceMiles }
            return (day: day, distance: dist)
        }
    }

    var paceOverTimeData: [(date: Date, pace: Double)] {
        completedRuns
            .filter { $0.averagePace > 0 }
            .sorted { $0.date < $1.date }
            .suffix(20)
            .map { (date: $0.date, pace: $0.averagePace) }
    }

    // MARK: - Run Control

    func startRun() {
        isRunning = true
        isPaused = false
        elapsedSeconds = 0
        currentDistanceMiles = 0
        currentPace = 0
        currentHeartRate = 0
        currentCadence = 0
        currentElevation = 0
        currentCalories = 0
        currentSplits = []
        routePoints = []
        lastSplitDistance = 0
        lastLocation = nil
        totalElevationGain = 0
        totalElevationLoss = 0
        lastAltitude = nil
        elevationSamples = []
        autoPausedAt = nil
        gpsSignal = .none

        workoutStartDate = Date()

        if healthKit.isHealthKitEnabled && healthKit.isAuthorized {
            healthKit.startAllLiveStreaming()
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }

        if !isTreadmillMode {
            if !locationService.hasLocationPermission {
                locationService.requestPermission()
            }
            locationService.startTracking(activityType: .fitness) { [weak self] location in
                Task { @MainActor in
                    self?.handleLocationUpdate(location)
                }
            }
        }
    }

    func pauseRun() {
        isPaused = true
        timer?.invalidate()
    }

    func resumeRun() {
        isPaused = false
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    func stopRun() -> CompletedRun {
        timer?.invalidate()
        isRunning = false
        isPaused = false

        if !isTreadmillMode {
            locationService.stopTracking()
        }

        let hasRealHR = !healthKit.collectedHeartRateSamples.isEmpty
        let avgHR = hasRealHR ? healthKit.averageHeartRateDuringWorkout : currentHeartRate
        let maxHR = hasRealHR ? healthKit.maxHeartRateDuringWorkout : currentHeartRate
        let zones = hasRealHR ? healthKit.heartRateZoneDistribution(totalDuration: elapsedSeconds) : []
        let finalCalories = healthKit.liveActiveCalories > 0 ? Int(healthKit.liveActiveCalories) : estimateCalories()

        healthKit.stopAllLiveStreaming()

        let run = CompletedRun(
            date: Date(),
            runType: selectedRunType,
            distanceMiles: currentDistanceMiles,
            durationSeconds: elapsedSeconds,
            averagePace: currentDistanceMiles > 0 ? (elapsedSeconds / 60) / currentDistanceMiles : 0,
            bestPace: currentSplits.map(\.pace).filter { $0 > 0 }.min() ?? 0,
            totalElevationGain: totalElevationGain,
            totalElevationLoss: totalElevationLoss,
            averageHeartRate: avgHR,
            maxHeartRate: maxHR,
            cadence: currentCadence,
            caloriesBurned: finalCalories,
            splits: currentSplits,
            routeCoordinates: routePoints,
            heartRateZones: zones,
            shoeId: selectedShoeId,
            isTreadmill: isTreadmillMode
        )

        Task {
            await healthKit.saveWorkout(
                type: .running,
                start: workoutStartDate ?? run.date.addingTimeInterval(-elapsedSeconds),
                end: Date(),
                calories: Double(finalCalories),
                distanceMeters: currentDistanceMiles * 1609.344,
                distanceType: .distanceWalkingRunning,
                heartRateSamples: healthKit.collectedHeartRateSamples
            )
        }

        completedRuns.insert(run, at: 0)

        if let shoeId = selectedShoeId, let idx = shoes.firstIndex(where: { $0.id == shoeId }) {
            shoes[idx].totalMiles += run.distanceMiles
        }

        gpsSignal = .none
        return run
    }

    // MARK: - GPS Location Handling

    private func handleLocationUpdate(_ location: CLLocation) {
        guard isRunning, !isPaused else { return }

        gpsSignal = GPSSignalQuality.from(accuracy: location.horizontalAccuracy)

        let speedMph = LocationTrackingService.speedInMph(metersPerSecond: location.speed)

        if settings.autoPause {
            if speedMph < autoPauseSpeedThreshold && lastLocation != nil {
                return
            }
        }

        if let last = lastLocation {
            let distMiles = LocationTrackingService.distanceInMiles(from: last, to: location)

            let maxReasonableDistPerUpdate = 0.05
            guard distMiles < maxReasonableDistPerUpdate else {
                lastLocation = location
                return
            }

            let minDistThreshold = 0.001
            if distMiles >= minDistThreshold {
                currentDistanceMiles += distMiles
            }
        }

        processElevation(location.altitude)

        currentElevation = LocationTrackingService.elevationInFeet(meters: location.altitude)

        if currentDistanceMiles > 0 {
            currentPace = (elapsedSeconds / 60) / currentDistanceMiles
        }

        routePoints.append(RouteCoordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            elevation: location.altitude,
            pace: currentPace,
            timestamp: Date()
        ))

        checkForSplit()

        lastLocation = location
    }

    private func processElevation(_ altitude: Double) {
        elevationSamples.append(altitude)
        if elevationSamples.count > elevationSmoothingWindow {
            elevationSamples.removeFirst()
        }

        let smoothedAltitude = elevationSamples.reduce(0, +) / Double(elevationSamples.count)

        if let lastAlt = lastAltitude {
            let diff = smoothedAltitude - lastAlt
            let minElevationChange: Double = 0.5
            if diff > minElevationChange {
                totalElevationGain += LocationTrackingService.elevationInFeet(meters: diff)
            } else if diff < -minElevationChange {
                totalElevationLoss += LocationTrackingService.elevationInFeet(meters: abs(diff))
            }
        }
        lastAltitude = smoothedAltitude
    }

    private func checkForSplit() {
        let splitDistance: Double = settings.distanceUnit == .kilometers ? 0.621371 : 1.0
        if currentDistanceMiles - lastSplitDistance >= splitDistance {
            let splitDuration = elapsedSeconds - currentSplits.reduce(0) { $0 + $1.duration }
            let splitPace = splitDuration / 60.0 / splitDistance
            let split = RunSplit(
                splitNumber: currentSplits.count + 1,
                distance: splitDistance,
                duration: splitDuration,
                pace: splitPace,
                elevationChange: 0,
                avgHeartRate: currentHeartRate
            )
            currentSplits.append(split)
            lastSplitDistance = currentDistanceMiles
        }
    }

    private func estimateCalories() -> Int {
        let weightKg: Double = 70
        let distanceKm = currentDistanceMiles * 1.60934
        let durationHours = elapsedSeconds / 3600
        guard durationHours > 0 else { return 0 }
        let speedKmh = distanceKm / durationHours
        let met: Double
        switch speedKmh {
        case ..<8: met = 8.0
        case 8..<10: met = 9.8
        case 10..<12: met = 11.0
        case 12..<14: met = 12.8
        default: met = 14.5
        }
        return Int(met * weightKg * durationHours)
    }

    private func tick() {
        guard !isPaused else { return }
        elapsedSeconds += 1

        if isTreadmillMode {
            tickTreadmill()
        } else {
            if healthKit.liveActiveCalories > 0 {
                currentCalories = Int(healthKit.liveActiveCalories)
            } else {
                currentCalories = estimateCalories()
            }

            if healthKit.liveHeartRate > 0 {
                currentHeartRate = healthKit.liveHeartRate
            }
        }
    }

    private func tickTreadmill() {
        if healthKit.liveHeartRate > 0 {
            currentHeartRate = healthKit.liveHeartRate
        }

        if healthKit.liveActiveCalories > 0 {
            currentCalories = Int(healthKit.liveActiveCalories)
        } else {
            currentCalories = estimateCalories()
        }

        if healthKit.liveDistanceWalkingRunning > 0 {
            let hkDistanceMiles = healthKit.liveDistanceWalkingRunning / 1609.344
            currentDistanceMiles = hkDistanceMiles
        }

        if currentDistanceMiles > 0 {
            currentPace = (elapsedSeconds / 60) / currentDistanceMiles
        }

        checkForSplit()
    }



    // MARK: - Shoe Management

    func addShoe(_ shoe: RunningShoe) {
        shoes.append(shoe)
    }

    func retireShoe(_ id: UUID) {
        if let idx = shoes.firstIndex(where: { $0.id == id }) {
            shoes[idx].isRetired = true
        }
    }

    func deleteShoe(_ id: UUID) {
        shoes.removeAll { $0.id == id }
    }

    func shoeForRun(_ run: CompletedRun) -> RunningShoe? {
        guard let shoeId = run.shoeId else { return nil }
        return shoes.first { $0.id == shoeId }
    }

    // MARK: - Sample Data

    private func loadSampleData() {
        let shoe1 = RunningShoe(name: "Pegasus 41", brand: "Nike", totalMiles: 187, retirementMiles: 400, colorHex: "00E5FF")
        let shoe2 = RunningShoe(name: "Ghost 16", brand: "Brooks", totalMiles: 312, retirementMiles: 400, colorHex: "FF8C00")
        let shoe3 = RunningShoe(name: "Vaporfly 3", brand: "Nike", totalMiles: 48, retirementMiles: 200, colorHex: "00FF88")
        shoes = [shoe1, shoe2, shoe3]

        let cal = Calendar.current
        let now = Date()

        completedRuns = [
            CompletedRun(
                date: cal.date(byAdding: .hour, value: -6, to: now)!,
                runType: .easyRun,
                distanceMiles: 4.2,
                durationSeconds: 2100,
                averagePace: 8.33,
                bestPace: 7.45,
                totalElevationGain: 85,
                totalElevationLoss: 78,
                averageHeartRate: 148,
                maxHeartRate: 172,
                cadence: 172,
                caloriesBurned: 420,
                splits: generateSampleSplits(count: 4, basePace: 8.33),
                routeCoordinates: generateSampleRoute(count: 50),
                heartRateZones: generateSampleZones(duration: 2100),
                shoeId: shoe1.id
            ),
            CompletedRun(
                date: cal.date(byAdding: .day, value: -1, to: now)!,
                runType: .tempoRun,
                distanceMiles: 5.5,
                durationSeconds: 2475,
                averagePace: 7.5,
                bestPace: 6.8,
                totalElevationGain: 110,
                totalElevationLoss: 105,
                averageHeartRate: 162,
                maxHeartRate: 184,
                cadence: 178,
                caloriesBurned: 580,
                splits: generateSampleSplits(count: 5, basePace: 7.5),
                routeCoordinates: generateSampleRoute(count: 60),
                heartRateZones: generateSampleZones(duration: 2475),
                shoeId: shoe1.id
            ),
            CompletedRun(
                date: cal.date(byAdding: .day, value: -3, to: now)!,
                runType: .longRun,
                distanceMiles: 10.2,
                durationSeconds: 5508,
                averagePace: 9.0,
                bestPace: 8.1,
                totalElevationGain: 210,
                totalElevationLoss: 195,
                averageHeartRate: 152,
                maxHeartRate: 175,
                cadence: 168,
                caloriesBurned: 1050,
                splits: generateSampleSplits(count: 10, basePace: 9.0),
                routeCoordinates: generateSampleRoute(count: 120),
                heartRateZones: generateSampleZones(duration: 5508),
                shoeId: shoe2.id
            ),
            CompletedRun(
                date: cal.date(byAdding: .day, value: -5, to: now)!,
                runType: .intervalSession,
                distanceMiles: 3.8,
                durationSeconds: 1596,
                averagePace: 7.0,
                bestPace: 5.8,
                totalElevationGain: 45,
                totalElevationLoss: 42,
                averageHeartRate: 168,
                maxHeartRate: 192,
                cadence: 182,
                caloriesBurned: 410,
                splits: generateSampleSplits(count: 4, basePace: 7.0),
                routeCoordinates: generateSampleRoute(count: 40),
                heartRateZones: generateSampleZones(duration: 1596),
                shoeId: shoe3.id
            ),
            CompletedRun(
                date: cal.date(byAdding: .day, value: -7, to: now)!,
                runType: .recoveryRun,
                distanceMiles: 3.0,
                durationSeconds: 1800,
                averagePace: 10.0,
                bestPace: 9.2,
                totalElevationGain: 30,
                totalElevationLoss: 28,
                averageHeartRate: 132,
                maxHeartRate: 148,
                cadence: 164,
                caloriesBurned: 290,
                splits: generateSampleSplits(count: 3, basePace: 10.0),
                routeCoordinates: generateSampleRoute(count: 35),
                heartRateZones: generateSampleZones(duration: 1800),
                shoeId: shoe2.id
            ),
            CompletedRun(
                date: cal.date(byAdding: .day, value: -9, to: now)!,
                runType: .tempoRun,
                distanceMiles: 6.0,
                durationSeconds: 2700,
                averagePace: 7.5,
                bestPace: 6.9,
                totalElevationGain: 125,
                totalElevationLoss: 118,
                averageHeartRate: 160,
                maxHeartRate: 182,
                cadence: 176,
                caloriesBurned: 620,
                splits: generateSampleSplits(count: 6, basePace: 7.5),
                routeCoordinates: generateSampleRoute(count: 65),
                heartRateZones: generateSampleZones(duration: 2700),
                shoeId: shoe1.id
            ),
            CompletedRun(
                date: cal.date(byAdding: .day, value: -12, to: now)!,
                runType: .easyRun,
                distanceMiles: 4.5,
                durationSeconds: 2340,
                averagePace: 8.67,
                bestPace: 7.9,
                totalElevationGain: 68,
                totalElevationLoss: 62,
                averageHeartRate: 145,
                maxHeartRate: 165,
                cadence: 170,
                caloriesBurned: 440,
                splits: generateSampleSplits(count: 4, basePace: 8.67),
                routeCoordinates: generateSampleRoute(count: 55),
                heartRateZones: generateSampleZones(duration: 2340),
                shoeId: shoe1.id
            ),
            CompletedRun(
                date: cal.date(byAdding: .day, value: -14, to: now)!,
                runType: .treadmill,
                distanceMiles: 3.5,
                durationSeconds: 1680,
                averagePace: 8.0,
                bestPace: 7.3,
                averageHeartRate: 155,
                maxHeartRate: 170,
                cadence: 174,
                caloriesBurned: 350,
                splits: generateSampleSplits(count: 3, basePace: 8.0),
                isTreadmill: true
            ),
        ]
    }

    private func generateSampleSplits(count: Int, basePace: Double) -> [RunSplit] {
        (1...count).map { i in
            let variance = Double.random(in: -0.5...0.5)
            let pace = basePace + variance
            return RunSplit(
                splitNumber: i,
                distance: 1.0,
                duration: pace * 60,
                pace: pace,
                elevationChange: Double.random(in: -15...20),
                avgHeartRate: Int.random(in: 140...175)
            )
        }
    }

    private func generateSampleRoute(count: Int) -> [RouteCoordinate] {
        let baseLat: Double = 37.7749
        let baseLng: Double = -122.4194
        var result: [RouteCoordinate] = []
        let now = Date()
        for i in 0..<count {
            let lat: Double = baseLat + Double(i) * 0.0003 + Double.random(in: -0.001...0.001)
            let lng: Double = baseLng + Double(i) * 0.0002 + Double.random(in: -0.001...0.001)
            let elev: Double = 50 + Double(i) * 0.3 + Double.random(in: -2...2)
            let p: Double = Double.random(in: 7...10)
            let ts: Date = now.addingTimeInterval(-Double(count - i) * 30)
            result.append(RouteCoordinate(latitude: lat, longitude: lng, elevation: elev, pace: p, timestamp: ts))
        }
        return result
    }

    private func generateSampleZones(duration: TimeInterval) -> [HeartRateZoneDistribution] {
        let z1 = Double.random(in: 0.05...0.12)
        let z2 = Double.random(in: 0.22...0.32)
        let z3 = Double.random(in: 0.28...0.38)
        let z4 = Double.random(in: 0.12...0.2)
        let z5 = max(1.0 - z1 - z2 - z3 - z4, 0)
        return [
            HeartRateZoneDistribution(zone: .zone1, timeInZone: duration * z1, percentage: z1),
            HeartRateZoneDistribution(zone: .zone2, timeInZone: duration * z2, percentage: z2),
            HeartRateZoneDistribution(zone: .zone3, timeInZone: duration * z3, percentage: z3),
            HeartRateZoneDistribution(zone: .zone4, timeInZone: duration * z4, percentage: z4),
            HeartRateZoneDistribution(zone: .zone5, timeInZone: duration * z5, percentage: z5),
        ]
    }
}
