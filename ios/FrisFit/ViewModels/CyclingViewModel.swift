import SwiftUI
import CoreLocation
import MapKit
import HealthKit

@Observable
final class CyclingViewModel {
    static let shared = CyclingViewModel()

    var completedRides: [CompletedRide] = []
    var bikes: [Bike] = []
    var settings: CyclingSettings = CyclingSettings()
    var routeRecords: [PersonalRouteRecord] = []

    var isRiding: Bool = false
    var isPaused: Bool = false
    var isIndoorMode: Bool = false
    var selectedRideType: RideType = .casualRide
    var selectedBikeId: UUID? = nil

    var elapsedSeconds: TimeInterval = 0
    var movingSeconds: TimeInterval = 0
    var currentDistanceMiles: Double = 0
    var currentSpeed: Double = 0
    var maxSpeedThisRide: Double = 0
    var currentHeartRate: Int = 0
    var currentCadence: Int = 0
    var currentPower: Int = 0
    var currentElevation: Double = 0
    var currentElevationGain: Double = 0
    var currentCalories: Int = 0
    var currentSegments: [RideSegment] = []
    var routePoints: [CyclingRouteCoordinate] = []

    var gpsSignal: GPSSignalQuality = .none

    var showRideDetail: Bool = false
    var selectedRide: CompletedRide? = nil
    var showCyclingSettings: Bool = false
    var showBikeManager: Bool = false
    var showAddBike: Bool = false
    var showWorkoutBuilder: Bool = false
    var savedCyclingWorkouts: [CustomCyclingWorkout] = []

    private var timer: Timer? = nil
    private var lastSegmentDistance: Double = 0
    private let locationService = LocationTrackingService.shared

    private var lastLocation: CLLocation?
    private var totalElevationLoss: Double = 0
    private var lastAltitude: Double?
    private var elevationSamples: [Double] = []
    private let elevationSmoothingWindow: Int = 5
    private let movingSpeedThresholdMph: Double = 1.5
    private let autoPauseSpeedThresholdMps: Double = 0.5
    private let autoResumeSpeedThresholdMps: Double = 1.5
    private let autoPauseDwellSeconds: TimeInterval = 10
    private var slowSpeedStartedAt: Date?
    var isAutoPaused: Bool = false
    private var isCurrentlyMoving: Bool = true
    private var segmentMaxSpeed: Double = 0
    private var segmentHeartRateSum: Int = 0
    private var segmentCadenceSum: Int = 0
    private var segmentTickCount: Int = 0
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

    var currentSpeedFormatted: String {
        if settings.speedUnit == .kph {
            return String(format: "%.1f", currentSpeed * 1.60934)
        }
        return String(format: "%.1f", currentSpeed)
    }

    var currentDistanceFormatted: String {
        if settings.distanceUnit == .kilometers {
            return String(format: "%.2f", currentDistanceMiles * 1.60934)
        }
        return String(format: "%.2f", currentDistanceMiles)
    }

    // MARK: - Dashboard Stats

    var totalMilesAllTime: Double {
        completedRides.reduce(0) { $0 + $1.distanceMiles }
    }

    var totalRidesAllTime: Int { completedRides.count }

    var averageSpeedAllTime: Double {
        let speeds = completedRides.filter { $0.averageSpeed > 0 }.map(\.averageSpeed)
        guard !speeds.isEmpty else { return 0 }
        return speeds.reduce(0, +) / Double(speeds.count)
    }

    var totalElevationAllTime: Double {
        completedRides.reduce(0) { $0 + $1.totalElevationGain }
    }

    var thisWeekRides: [CompletedRide] {
        let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return completedRides.filter { $0.date >= weekStart }
    }

    var thisWeekMiles: Double {
        thisWeekRides.reduce(0) { $0 + $1.distanceMiles }
    }

    var thisWeekElevation: Double {
        thisWeekRides.reduce(0) { $0 + $1.totalElevationGain }
    }

    var longestRideEver: Double {
        completedRides.map(\.distanceMiles).max() ?? 0
    }

    var topSpeedEver: Double {
        completedRides.map(\.maxSpeed).max() ?? 0
    }

    var weeklyDistanceHistory: [WeeklyRideDistance] {
        let cal = Calendar.current
        let now = Date()
        return (0..<12).reversed().compactMap { weekOffset -> WeeklyRideDistance? in
            guard let weekStart = cal.date(byAdding: .weekOfYear, value: -weekOffset, to: now) else { return nil }
            let weekEnd = cal.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? now
            let weekRides = completedRides.filter { $0.date >= weekStart && $0.date < weekEnd }
            let totalMiles = weekRides.reduce(0) { $0 + $1.distanceMiles }
            let totalElev = weekRides.reduce(0) { $0 + $1.totalElevationGain }
            let avgSpd = weekRides.isEmpty ? 0 : weekRides.reduce(0) { $0 + $1.averageSpeed } / Double(weekRides.count)
            return WeeklyRideDistance(weekStart: weekStart, totalMiles: totalMiles, totalElevation: totalElev, rideCount: weekRides.count, avgSpeed: avgSpd)
        }
    }

    var speedOverTimeData: [(date: Date, speed: Double)] {
        completedRides
            .filter { $0.averageSpeed > 0 }
            .sorted { $0.date < $1.date }
            .suffix(20)
            .map { (date: $0.date, speed: $0.averageSpeed) }
    }

    var elevationOverTimeData: [(date: Date, elevation: Double)] {
        completedRides
            .sorted { $0.date < $1.date }
            .suffix(20)
            .map { (date: $0.date, elevation: $0.totalElevationGain) }
    }

    // MARK: - Ride Control

    func startRide() {
        isRiding = true
        isPaused = false
        isAutoPaused = false
        slowSpeedStartedAt = nil
        elapsedSeconds = 0
        movingSeconds = 0
        currentDistanceMiles = 0
        currentSpeed = 0
        maxSpeedThisRide = 0
        currentHeartRate = 0
        currentCadence = 0
        currentPower = 0
        currentElevation = 0
        currentElevationGain = 0
        currentCalories = 0
        currentSegments = []
        routePoints = []
        lastSegmentDistance = 0
        lastLocation = nil
        totalElevationLoss = 0
        lastAltitude = nil
        elevationSamples = []
        isCurrentlyMoving = true
        segmentMaxSpeed = 0
        segmentHeartRateSum = 0
        segmentCadenceSum = 0
        segmentTickCount = 0
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

        if !isIndoorMode {
            if !locationService.hasLocationPermission {
                locationService.requestPermission()
            }
            locationService.startTracking(activityType: .otherNavigation) { [weak self] location in
                Task { @MainActor in
                    self?.handleLocationUpdate(location)
                }
            }
        }
    }

    func pauseRide() {
        isPaused = true
        timer?.invalidate()
    }

    func resumeRide() {
        isPaused = false
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    func stopRide() -> CompletedRide {
        timer?.invalidate()
        isRiding = false
        isPaused = false

        if !isIndoorMode {
            locationService.stopTracking()
        }

        let hasRealHR = !healthKit.collectedHeartRateSamples.isEmpty
        let avgHR = hasRealHR ? healthKit.averageHeartRateDuringWorkout : currentHeartRate
        let maxHR = hasRealHR ? healthKit.maxHeartRateDuringWorkout : currentHeartRate
        let zones = hasRealHR ? healthKit.heartRateZoneDistribution(totalDuration: elapsedSeconds) : []
        let finalCalories = healthKit.liveActiveCalories > 0 ? Int(healthKit.liveActiveCalories) : estimateCalories()

        healthKit.stopAllLiveStreaming()

        let ride = CompletedRide(
            date: Date(),
            rideType: selectedRideType,
            distanceMiles: currentDistanceMiles,
            durationSeconds: elapsedSeconds,
            movingTimeSeconds: movingSeconds,
            averageSpeed: movingSeconds > 0 ? currentDistanceMiles / (movingSeconds / 3600) : 0,
            maxSpeed: maxSpeedThisRide,
            totalElevationGain: currentElevationGain,
            totalElevationLoss: totalElevationLoss,
            averageHeartRate: avgHR,
            maxHeartRate: maxHR,
            averageCadence: currentCadence,
            maxCadence: currentCadence,
            averagePower: currentPower,
            maxPower: currentPower,
            caloriesBurned: finalCalories,
            segments: currentSegments,
            routeCoordinates: routePoints,
            heartRateZones: zones,
            bikeId: selectedBikeId,
            isIndoor: isIndoorMode
        )

        Task {
            await healthKit.saveWorkout(
                type: .cycling,
                start: workoutStartDate ?? ride.date.addingTimeInterval(-elapsedSeconds),
                end: Date(),
                calories: Double(finalCalories),
                distanceMeters: currentDistanceMiles * 1609.344,
                distanceType: .distanceCycling,
                heartRateSamples: healthKit.collectedHeartRateSamples
            )
        }

        completedRides.insert(ride, at: 0)

        if let bikeId = selectedBikeId, let idx = bikes.firstIndex(where: { $0.id == bikeId }) {
            bikes[idx].totalMiles += ride.distanceMiles
        }

        Task { await CardioSessionService.shared.saveRide(ride) }

        gpsSignal = .none
        return ride
    }

    // MARK: - GPS Location Handling

    private func handleLocationUpdate(_ location: CLLocation) {
        guard isRiding, !isPaused else { return }

        gpsSignal = GPSSignalQuality.from(accuracy: location.horizontalAccuracy)

        let speedMph = LocationTrackingService.speedInMph(metersPerSecond: location.speed)
        currentSpeed = speedMph

        isCurrentlyMoving = speedMph >= movingSpeedThresholdMph

        if speedMph > maxSpeedThisRide {
            maxSpeedThisRide = speedMph
        }
        if speedMph > segmentMaxSpeed {
            segmentMaxSpeed = speedMph
        }

        if let last = lastLocation {
            let distMiles = LocationTrackingService.distanceInMiles(from: last, to: location)

            let maxReasonableDistPerUpdate = 0.1
            guard distMiles < maxReasonableDistPerUpdate else {
                lastLocation = location
                return
            }

            let minDistThreshold = 0.0005
            if distMiles >= minDistThreshold {
                currentDistanceMiles += distMiles
            }
        }

        processElevation(location.altitude)

        currentElevation = LocationTrackingService.elevationInFeet(meters: location.altitude)

        routePoints.append(CyclingRouteCoordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            elevation: location.altitude,
            speed: speedMph,
            timestamp: Date()
        ))

        checkForSegment()

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
                currentElevationGain += LocationTrackingService.elevationInFeet(meters: diff)
            } else if diff < -minElevationChange {
                totalElevationLoss += LocationTrackingService.elevationInFeet(meters: abs(diff))
            }
        }
        lastAltitude = smoothedAltitude
    }

    private func checkForSegment() {
        let segmentDistance: Double = settings.distanceUnit == .kilometers ? 0.621371 : 1.0
        if currentDistanceMiles - lastSegmentDistance >= segmentDistance {
            let segDuration = elapsedSeconds - currentSegments.reduce(0) { $0 + $1.duration }
            let segSpeed = segDuration > 0 ? segmentDistance / (segDuration / 3600) : 0
            let avgHR = segmentTickCount > 0 ? segmentHeartRateSum / segmentTickCount : currentHeartRate
            let avgCad = segmentTickCount > 0 ? segmentCadenceSum / segmentTickCount : currentCadence
            let seg = RideSegment(
                segmentNumber: currentSegments.count + 1,
                distanceMiles: segmentDistance,
                duration: segDuration,
                avgSpeed: segSpeed,
                maxSpeed: segmentMaxSpeed,
                elevationChange: 0,
                avgHeartRate: avgHR,
                avgCadence: avgCad
            )
            currentSegments.append(seg)
            lastSegmentDistance = currentDistanceMiles
            segmentMaxSpeed = 0
            segmentHeartRateSum = 0
            segmentCadenceSum = 0
            segmentTickCount = 0
        }
    }

    private func estimateCalories() -> Int {
        let weightKg: Double = 75
        let distanceKm = currentDistanceMiles * 1.60934
        let durationHours = movingSeconds > 0 ? movingSeconds / 3600 : elapsedSeconds / 3600
        guard durationHours > 0 else { return 0 }
        let speedKmh = distanceKm / durationHours
        let met: Double
        switch speedKmh {
        case ..<16: met = 4.0
        case 16..<19: met = 6.8
        case 19..<22: met = 8.0
        case 22..<26: met = 10.0
        case 26..<32: met = 12.0
        default: met = 15.8
        }
        return Int(met * weightKg * durationHours)
    }

    private func tick() {
        guard !isPaused else { return }
        elapsedSeconds += 1

        if isIndoorMode {
            tickIndoor()
        } else {
            if isCurrentlyMoving {
                movingSeconds += 1
            }

            if healthKit.liveActiveCalories > 0 {
                currentCalories = Int(healthKit.liveActiveCalories)
            } else {
                currentCalories = estimateCalories()
            }

            if healthKit.liveHeartRate > 0 {
                currentHeartRate = healthKit.liveHeartRate
            }

            segmentHeartRateSum += currentHeartRate
            segmentCadenceSum += currentCadence
            segmentTickCount += 1
        }
    }

    private func tickIndoor() {
        movingSeconds += 1

        if healthKit.liveHeartRate > 0 {
            currentHeartRate = healthKit.liveHeartRate
        }

        if healthKit.liveActiveCalories > 0 {
            currentCalories = Int(healthKit.liveActiveCalories)
        } else {
            currentCalories = estimateCalories()
        }

        if healthKit.liveDistanceCycling > 0 {
            let hkDistanceMiles = healthKit.liveDistanceCycling / 1609.344
            currentDistanceMiles = hkDistanceMiles
            if movingSeconds > 0 {
                currentSpeed = currentDistanceMiles / (movingSeconds / 3600)
            }
            maxSpeedThisRide = max(maxSpeedThisRide, currentSpeed)
        }

        segmentHeartRateSum += currentHeartRate
        segmentCadenceSum += currentCadence
        segmentTickCount += 1

        checkForSegment()
    }



    // MARK: - Bike Management

    func addBike(_ bike: Bike) {
        bikes.append(bike)
    }

    func retireBike(_ id: UUID) {
        if let idx = bikes.firstIndex(where: { $0.id == id }) {
            bikes[idx].isRetired = true
        }
    }

    func deleteBike(_ id: UUID) {
        bikes.removeAll { $0.id == id }
    }

    func markMaintenance(_ id: UUID) {
        if let idx = bikes.firstIndex(where: { $0.id == id }) {
            bikes[idx].lastMaintenanceMiles = bikes[idx].totalMiles
        }
    }

    func bikeForRide(_ ride: CompletedRide) -> Bike? {
        guard let bikeId = ride.bikeId else { return nil }
        return bikes.first { $0.id == bikeId }
    }

    // MARK: - Sample Data

    private func loadSampleData() {
        let bike1 = Bike(name: "Tarmac SL7", type: "Road", totalMiles: 1240, maintenanceIntervalMiles: 500, colorHex: "F27300")
        let bike2 = Bike(name: "Diverge", type: "Gravel", totalMiles: 680, maintenanceIntervalMiles: 400, colorHex: "8B5CF6")
        let bike3 = Bike(name: "Allez Sprint", type: "Road", totalMiles: 320, maintenanceIntervalMiles: 500, colorHex: "00E5FF")
        bikes = [bike1, bike2, bike3]

        let cal = Calendar.current
        let now = Date()

        completedRides = [
            CompletedRide(
                date: cal.date(byAdding: .hour, value: -4, to: now)!,
                rideType: .endurance,
                distanceMiles: 32.5,
                durationSeconds: 5850,
                movingTimeSeconds: 5600,
                averageSpeed: 17.8,
                maxSpeed: 28.4,
                totalElevationGain: 1450,
                totalElevationLoss: 1380,
                averageHeartRate: 148,
                maxHeartRate: 176,
                averageCadence: 85,
                maxCadence: 112,
                averagePower: 195,
                maxPower: 380,
                caloriesBurned: 980,
                segments: generateSampleSegments(count: 32, baseSpeed: 17.8),
                routeCoordinates: generateSampleRoute(count: 80),
                heartRateZones: generateSampleZones(duration: 5850),
                bikeId: bike1.id
            ),
            CompletedRide(
                date: cal.date(byAdding: .day, value: -1, to: now)!,
                rideType: .tempo,
                distanceMiles: 22.3,
                durationSeconds: 3960,
                movingTimeSeconds: 3840,
                averageSpeed: 19.2,
                maxSpeed: 31.5,
                totalElevationGain: 820,
                totalElevationLoss: 790,
                averageHeartRate: 158,
                maxHeartRate: 184,
                averageCadence: 90,
                maxCadence: 115,
                averagePower: 225,
                maxPower: 420,
                caloriesBurned: 720,
                segments: generateSampleSegments(count: 22, baseSpeed: 19.2),
                routeCoordinates: generateSampleRoute(count: 55),
                heartRateZones: generateSampleZones(duration: 3960),
                bikeId: bike1.id
            ),
            CompletedRide(
                date: cal.date(byAdding: .day, value: -3, to: now)!,
                rideType: .hillClimb,
                distanceMiles: 18.7,
                durationSeconds: 4320,
                movingTimeSeconds: 4200,
                averageSpeed: 14.8,
                maxSpeed: 38.2,
                totalElevationGain: 2800,
                totalElevationLoss: 2750,
                averageHeartRate: 162,
                maxHeartRate: 188,
                averageCadence: 78,
                maxCadence: 105,
                averagePower: 240,
                maxPower: 480,
                caloriesBurned: 850,
                segments: generateSampleSegments(count: 18, baseSpeed: 14.8),
                routeCoordinates: generateSampleRoute(count: 60),
                heartRateZones: generateSampleZones(duration: 4320),
                bikeId: bike1.id
            ),
            CompletedRide(
                date: cal.date(byAdding: .day, value: -5, to: now)!,
                rideType: .gravel,
                distanceMiles: 28.1,
                durationSeconds: 5400,
                movingTimeSeconds: 5200,
                averageSpeed: 16.2,
                maxSpeed: 25.8,
                totalElevationGain: 1650,
                totalElevationLoss: 1600,
                averageHeartRate: 152,
                maxHeartRate: 178,
                averageCadence: 82,
                maxCadence: 108,
                averagePower: 210,
                maxPower: 395,
                caloriesBurned: 920,
                segments: generateSampleSegments(count: 28, baseSpeed: 16.2),
                routeCoordinates: generateSampleRoute(count: 70),
                heartRateZones: generateSampleZones(duration: 5400),
                bikeId: bike2.id
            ),
            CompletedRide(
                date: cal.date(byAdding: .day, value: -7, to: now)!,
                rideType: .casualRide,
                distanceMiles: 15.2,
                durationSeconds: 3240,
                movingTimeSeconds: 3000,
                averageSpeed: 15.8,
                maxSpeed: 22.4,
                totalElevationGain: 420,
                totalElevationLoss: 400,
                averageHeartRate: 138,
                maxHeartRate: 158,
                averageCadence: 80,
                maxCadence: 98,
                averagePower: 165,
                maxPower: 310,
                caloriesBurned: 520,
                segments: generateSampleSegments(count: 15, baseSpeed: 15.8),
                routeCoordinates: generateSampleRoute(count: 45),
                heartRateZones: generateSampleZones(duration: 3240),
                bikeId: bike3.id
            ),
            CompletedRide(
                date: cal.date(byAdding: .day, value: -10, to: now)!,
                rideType: .interval,
                distanceMiles: 20.5,
                durationSeconds: 3600,
                movingTimeSeconds: 3500,
                averageSpeed: 20.5,
                maxSpeed: 34.2,
                totalElevationGain: 560,
                totalElevationLoss: 540,
                averageHeartRate: 165,
                maxHeartRate: 192,
                averageCadence: 92,
                maxCadence: 118,
                averagePower: 255,
                maxPower: 510,
                caloriesBurned: 780,
                segments: generateSampleSegments(count: 20, baseSpeed: 20.5),
                routeCoordinates: generateSampleRoute(count: 50),
                heartRateZones: generateSampleZones(duration: 3600),
                bikeId: bike1.id
            ),
            CompletedRide(
                date: cal.date(byAdding: .day, value: -12, to: now)!,
                rideType: .indoor,
                distanceMiles: 12.0,
                durationSeconds: 2700,
                movingTimeSeconds: 2700,
                averageSpeed: 16.0,
                maxSpeed: 22.0,
                averageHeartRate: 155,
                maxHeartRate: 178,
                averageCadence: 88,
                maxCadence: 110,
                averagePower: 200,
                maxPower: 360,
                caloriesBurned: 480,
                segments: generateSampleSegments(count: 12, baseSpeed: 16.0),
                heartRateZones: generateSampleZones(duration: 2700),
                isIndoor: true
            ),
        ]
    }

    private func generateSampleSegments(count: Int, baseSpeed: Double) -> [RideSegment] {
        (1...count).map { i in
            let variance = Double.random(in: -2...3)
            let speed = baseSpeed + variance
            return RideSegment(
                segmentNumber: i,
                distanceMiles: 1.0,
                duration: 3600 / speed,
                avgSpeed: speed,
                maxSpeed: speed + Double.random(in: 2...8),
                elevationChange: Double.random(in: -20...30),
                avgHeartRate: Int.random(in: 135...170),
                avgCadence: Int.random(in: 75...100)
            )
        }
    }

    private func generateSampleRoute(count: Int) -> [CyclingRouteCoordinate] {
        let baseLat: Double = 37.7749
        let baseLng: Double = -122.4194
        var result: [CyclingRouteCoordinate] = []
        let now = Date()
        for i in 0..<count {
            let lat = baseLat + Double(i) * 0.0005 + Double.random(in: -0.002...0.002)
            let lng = baseLng + Double(i) * 0.0004 + Double.random(in: -0.002...0.002)
            let elev = 50 + Double(i) * 0.5 + Double.random(in: -3...3)
            let spd = Double.random(in: 12...25)
            let ts = now.addingTimeInterval(-Double(count - i) * 45)
            result.append(CyclingRouteCoordinate(latitude: lat, longitude: lng, elevation: elev, speed: spd, timestamp: ts))
        }
        return result
    }

    private func generateSampleZones(duration: TimeInterval) -> [HeartRateZoneDistribution] {
        let z1 = Double.random(in: 0.08...0.15)
        let z2 = Double.random(in: 0.25...0.35)
        let z3 = Double.random(in: 0.22...0.32)
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
}
