import Foundation
import SwiftUI
import CoreLocation
import MapKit

nonisolated enum RunType: String, CaseIterable, Identifiable, Sendable, Codable {
    case easyRun = "Easy Run"
    case tempoRun = "Tempo Run"
    case intervalSession = "Intervals"
    case longRun = "Long Run"
    case recoveryRun = "Recovery"
    case fartlek = "Fartlek"
    case raceRun = "Race"
    case treadmill = "Treadmill"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .easyRun: "figure.run"
        case .tempoRun: "bolt.heart.fill"
        case .intervalSession: "repeat"
        case .longRun: "road.lanes"
        case .recoveryRun: "leaf.fill"
        case .fartlek: "waveform.path.ecg"
        case .raceRun: "flag.checkered"
        case .treadmill: "figure.run.treadmill"
        }
    }

    var color: Color {
        switch self {
        case .easyRun: Color(red: 0.0, green: 0.9, blue: 1.0)
        case .tempoRun: Color(red: 1.0, green: 0.55, blue: 0.1)
        case .intervalSession: Color(red: 0.85, green: 0.25, blue: 0.25)
        case .longRun: Color(red: 0.2, green: 0.78, blue: 0.35)
        case .recoveryRun: Color(red: 0.55, green: 0.8, blue: 0.55)
        case .fartlek: Color(red: 0.85, green: 0.9, blue: 0.15)
        case .raceRun: Color(red: 1.0, green: 0.84, blue: 0.0)
        case .treadmill: Color(red: 0.55, green: 0.36, blue: 0.96)
        }
    }
}

nonisolated enum HeartRateZone: Int, CaseIterable, Identifiable, Sendable {
    case zone1 = 1
    case zone2 = 2
    case zone3 = 3
    case zone4 = 4
    case zone5 = 5

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .zone1: "Recovery"
        case .zone2: "Aerobic"
        case .zone3: "Tempo"
        case .zone4: "Threshold"
        case .zone5: "Max"
        }
    }

    var color: Color {
        switch self {
        case .zone1: .blue
        case .zone2: .green
        case .zone3: .yellow
        case .zone4: .orange
        case .zone5: .red
        }
    }

    var bpmRange: (min: Int, max: Int) {
        switch self {
        case .zone1: (0, 120)
        case .zone2: (120, 140)
        case .zone3: (140, 160)
        case .zone4: (160, 180)
        case .zone5: (180, 220)
        }
    }

    static func zone(for bpm: Int) -> HeartRateZone {
        switch bpm {
        case ..<120: .zone1
        case 120..<140: .zone2
        case 140..<160: .zone3
        case 160..<180: .zone4
        default: .zone5
        }
    }
}

nonisolated enum AudioCueInterval: String, CaseIterable, Identifiable, Sendable, Codable {
    case everyHalfMile = "Every 0.5 mi"
    case everyMile = "Every Mile"
    case everyKilometer = "Every Kilometer"
    case every5Minutes = "Every 5 Min"
    case every10Minutes = "Every 10 Min"
    case off = "Off"

    var id: String { rawValue }
}

nonisolated enum DistanceUnit: String, CaseIterable, Identifiable, Sendable, Codable {
    case miles = "Miles"
    case kilometers = "Kilometers"

    var id: String { rawValue }

    var abbreviation: String {
        switch self {
        case .miles: "mi"
        case .kilometers: "km"
        }
    }

    var splitLabel: String {
        switch self {
        case .miles: "mile"
        case .kilometers: "km"
        }
    }
}

nonisolated struct RunSplit: Identifiable, Sendable {
    let id: UUID
    let splitNumber: Int
    let distance: Double
    let duration: TimeInterval
    let pace: Double
    let elevationChange: Double
    let avgHeartRate: Int

    var paceFormatted: String {
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }

    init(splitNumber: Int, distance: Double, duration: TimeInterval, pace: Double, elevationChange: Double = 0, avgHeartRate: Int = 0) {
        self.id = UUID()
        self.splitNumber = splitNumber
        self.distance = distance
        self.duration = duration
        self.pace = pace
        self.elevationChange = elevationChange
        self.avgHeartRate = avgHeartRate
    }
}

nonisolated struct RouteCoordinate: Sendable {
    let latitude: Double
    let longitude: Double
    let elevation: Double
    let pace: Double
    let timestamp: Date
}

nonisolated struct HeartRateZoneDistribution: Sendable {
    let zone: HeartRateZone
    let timeInZone: TimeInterval
    let percentage: Double
}

nonisolated struct CompletedRun: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let runType: RunType
    let distanceMiles: Double
    let durationSeconds: TimeInterval
    let averagePace: Double
    let bestPace: Double
    let totalElevationGain: Double
    let totalElevationLoss: Double
    let averageHeartRate: Int
    let maxHeartRate: Int
    let cadence: Int
    let caloriesBurned: Int
    let splits: [RunSplit]
    let routeCoordinates: [RouteCoordinate]
    let heartRateZones: [HeartRateZoneDistribution]
    let shoeId: UUID?
    let temperature: Double?
    let notes: String
    let isTreadmill: Bool

    var distanceKm: Double { distanceMiles * 1.60934 }
    var durationFormatted: String { formatDuration(durationSeconds) }
    var averagePaceFormatted: String { formatPace(averagePace) }
    var bestPaceFormatted: String { formatPace(bestPace) }

    var strideLength: Double {
        guard cadence > 0, durationSeconds > 0 else { return 0 }
        let totalSteps = Double(cadence) * (durationSeconds / 60.0)
        guard totalSteps > 0 else { return 0 }
        return (distanceMiles * 5280) / totalSteps
    }

    init(
        date: Date = Date(),
        runType: RunType = .easyRun,
        distanceMiles: Double = 0,
        durationSeconds: TimeInterval = 0,
        averagePace: Double = 0,
        bestPace: Double = 0,
        totalElevationGain: Double = 0,
        totalElevationLoss: Double = 0,
        averageHeartRate: Int = 0,
        maxHeartRate: Int = 0,
        cadence: Int = 0,
        caloriesBurned: Int = 0,
        splits: [RunSplit] = [],
        routeCoordinates: [RouteCoordinate] = [],
        heartRateZones: [HeartRateZoneDistribution] = [],
        shoeId: UUID? = nil,
        temperature: Double? = nil,
        notes: String = "",
        isTreadmill: Bool = false
    ) {
        self.id = UUID()
        self.date = date
        self.runType = runType
        self.distanceMiles = distanceMiles
        self.durationSeconds = durationSeconds
        self.averagePace = averagePace
        self.bestPace = bestPace
        self.totalElevationGain = totalElevationGain
        self.totalElevationLoss = totalElevationLoss
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.cadence = cadence
        self.caloriesBurned = caloriesBurned
        self.splits = splits
        self.routeCoordinates = routeCoordinates
        self.heartRateZones = heartRateZones
        self.shoeId = shoeId
        self.temperature = temperature
        self.notes = notes
        self.isTreadmill = isTreadmill
    }
}

nonisolated struct RunningShoe: Identifiable, Sendable, Codable {
    let id: UUID
    var name: String
    var brand: String
    var totalMiles: Double
    var retirementMiles: Double
    var dateAdded: Date
    var isRetired: Bool
    var colorHex: String

    var milesRemaining: Double { max(retirementMiles - totalMiles, 0) }
    var usagePercentage: Double { min(totalMiles / retirementMiles, 1.0) }

    var statusColor: Color {
        switch usagePercentage {
        case ..<0.6: .green
        case 0.6..<0.8: .yellow
        case 0.8..<1.0: .orange
        default: .red
        }
    }

    init(name: String, brand: String, totalMiles: Double = 0, retirementMiles: Double = 400, colorHex: String = "00E5FF") {
        self.id = UUID()
        self.name = name
        self.brand = brand
        self.totalMiles = totalMiles
        self.retirementMiles = retirementMiles
        self.dateAdded = Date()
        self.isRetired = false
        self.colorHex = colorHex
    }
}

nonisolated struct RacePrediction: Identifiable, Sendable {
    let id: UUID
    let raceName: String
    let distance: Double
    let predictedTime: TimeInterval
    let confidence: Double

    var predictedTimeFormatted: String {
        formatDuration(predictedTime)
    }

    init(raceName: String, distance: Double, predictedTime: TimeInterval, confidence: Double) {
        self.id = UUID()
        self.raceName = raceName
        self.distance = distance
        self.predictedTime = predictedTime
        self.confidence = confidence
    }
}

nonisolated struct PersonalCourseRecord: Identifiable, Sendable {
    let id: UUID
    let routeHash: String
    let routeName: String
    let bestTime: TimeInterval
    let bestPace: Double
    let bestDate: Date
    let attempts: Int
    let recentTimes: [TimeInterval]

    init(routeHash: String, routeName: String, bestTime: TimeInterval, bestPace: Double, bestDate: Date, attempts: Int, recentTimes: [TimeInterval]) {
        self.id = UUID()
        self.routeHash = routeHash
        self.routeName = routeName
        self.bestTime = bestTime
        self.bestPace = bestPace
        self.bestDate = bestDate
        self.attempts = attempts
        self.recentTimes = recentTimes
    }
}

nonisolated struct WeeklyMileage: Identifiable, Sendable {
    let id: UUID
    let weekStart: Date
    let totalMiles: Double
    let runCount: Int
    let avgPace: Double

    init(weekStart: Date, totalMiles: Double, runCount: Int, avgPace: Double) {
        self.id = UUID()
        self.weekStart = weekStart
        self.totalMiles = totalMiles
        self.runCount = runCount
        self.avgPace = avgPace
    }
}

nonisolated enum GPSAccuracy: String, CaseIterable, Identifiable, Sendable, Codable {
    case best = "Best"
    case balanced = "Balanced"
    case batterySaver = "Battery Saver"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .best: "Highest precision, more battery"
        case .balanced: "10m accuracy, normal battery"
        case .batterySaver: "100m accuracy, longest battery"
        }
    }

    var icon: String {
        switch self {
        case .best: "location.fill"
        case .balanced: "location"
        case .batterySaver: "battery.100"
        }
    }
}

nonisolated struct RunningSettings: Sendable, Codable {
    var distanceUnit: DistanceUnit = .miles
    var audioCueInterval: AudioCueInterval = .everyMile
    var announceHeartRate: Bool = true
    var announcePace: Bool = true
    var announceDistance: Bool = true
    var autoPause: Bool = true
    var countdownSeconds: Int = 3
    var gpsAccuracy: GPSAccuracy = .best
}

nonisolated private func formatDuration(_ seconds: TimeInterval) -> String {
    let hours = Int(seconds) / 3600
    let minutes = (Int(seconds) % 3600) / 60
    let secs = Int(seconds) % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, secs)
    }
    return String(format: "%d:%02d", minutes, secs)
}

nonisolated private func formatPace(_ pace: Double) -> String {
    let minutes = Int(pace)
    let seconds = Int((pace - Double(minutes)) * 60)
    return String(format: "%d:%02d", minutes, seconds)
}
