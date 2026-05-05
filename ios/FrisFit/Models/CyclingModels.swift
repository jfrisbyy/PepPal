import Foundation
import SwiftUI
import CoreLocation
import MapKit

nonisolated enum RideType: String, CaseIterable, Identifiable, Sendable, Codable {
    case casualRide = "Casual Ride"
    case endurance = "Endurance"
    case tempo = "Tempo"
    case hillClimb = "Hill Climb"
    case interval = "Intervals"
    case commute = "Commute"
    case gravel = "Gravel"
    case indoor = "Indoor"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .casualRide: "figure.outdoor.cycle"
        case .endurance: "road.lanes"
        case .tempo: "bolt.heart.fill"
        case .hillClimb: "mountain.2.fill"
        case .interval: "repeat"
        case .commute: "building.2.fill"
        case .gravel: "leaf.fill"
        case .indoor: "figure.indoor.cycle"
        }
    }

    var color: Color {
        switch self {
        case .casualRide: Color(red: 0.95, green: 0.45, blue: 0.0)
        case .endurance: Color(red: 0.2, green: 0.78, blue: 0.35)
        case .tempo: Color(red: 1.0, green: 0.55, blue: 0.1)
        case .hillClimb: Color(red: 0.85, green: 0.25, blue: 0.25)
        case .interval: Color(red: 0.85, green: 0.9, blue: 0.15)
        case .commute: Color(red: 0.2, green: 0.6, blue: 1.0)
        case .gravel: Color(red: 0.55, green: 0.35, blue: 0.17)
        case .indoor: Color(red: 0.55, green: 0.36, blue: 0.96)
        }
    }
}

nonisolated enum ClimbCategory: String, Sendable {
    case cat4 = "Cat 4"
    case cat3 = "Cat 3"
    case cat2 = "Cat 2"
    case cat1 = "Cat 1"
    case hc = "HC"

    var color: Color {
        switch self {
        case .cat4: .green
        case .cat3: .yellow
        case .cat2: .orange
        case .cat1: .red
        case .hc: Color(red: 0.55, green: 0.36, blue: 0.96)
        }
    }

    static func categorize(elevationGain: Double, distanceMiles: Double) -> ClimbCategory? {
        let gradient = distanceMiles > 0 ? (elevationGain / (distanceMiles * 5280)) * 100 : 0
        let score = elevationGain * gradient
        switch score {
        case 8000...: return .hc
        case 3200..<8000: return .cat1
        case 1600..<3200: return .cat2
        case 640..<1600: return .cat3
        case 160..<640: return .cat4
        default: return nil
        }
    }
}

nonisolated enum SpeedUnit: String, CaseIterable, Identifiable, Sendable, Codable {
    case mph = "mph"
    case kph = "km/h"

    var id: String { rawValue }
}

nonisolated struct RideSegment: Identifiable, Sendable {
    let id: UUID
    let segmentNumber: Int
    let distanceMiles: Double
    let duration: TimeInterval
    let avgSpeed: Double
    let maxSpeed: Double
    let elevationChange: Double
    let avgHeartRate: Int
    let avgCadence: Int

    var avgSpeedFormatted: String {
        String(format: "%.1f", avgSpeed)
    }

    init(segmentNumber: Int, distanceMiles: Double, duration: TimeInterval, avgSpeed: Double, maxSpeed: Double, elevationChange: Double = 0, avgHeartRate: Int = 0, avgCadence: Int = 0) {
        self.id = UUID()
        self.segmentNumber = segmentNumber
        self.distanceMiles = distanceMiles
        self.duration = duration
        self.avgSpeed = avgSpeed
        self.maxSpeed = maxSpeed
        self.elevationChange = elevationChange
        self.avgHeartRate = avgHeartRate
        self.avgCadence = avgCadence
    }
}

nonisolated struct CyclingRouteCoordinate: Sendable {
    let latitude: Double
    let longitude: Double
    let elevation: Double
    let speed: Double
    let timestamp: Date
}

nonisolated struct CompletedRide: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let rideType: RideType
    let distanceMiles: Double
    let durationSeconds: TimeInterval
    let movingTimeSeconds: TimeInterval
    let averageSpeed: Double
    let maxSpeed: Double
    let totalElevationGain: Double
    let totalElevationLoss: Double
    let averageHeartRate: Int
    let maxHeartRate: Int
    let averageCadence: Int
    let maxCadence: Int
    let averagePower: Int
    let maxPower: Int
    let caloriesBurned: Int
    let segments: [RideSegment]
    let routeCoordinates: [CyclingRouteCoordinate]
    let heartRateZones: [HeartRateZoneDistribution]
    let bikeId: UUID?
    let temperature: Double?
    let notes: String
    let isIndoor: Bool

    var distanceKm: Double { distanceMiles * 1.60934 }
    var durationFormatted: String { CyclingFormatters.formatDuration(durationSeconds) }
    var movingTimeFormatted: String { CyclingFormatters.formatDuration(movingTimeSeconds) }
    var averageSpeedFormatted: String { String(format: "%.1f", averageSpeed) }
    var maxSpeedFormatted: String { String(format: "%.1f", maxSpeed) }

    var climbCategory: ClimbCategory? {
        ClimbCategory.categorize(elevationGain: totalElevationGain, distanceMiles: distanceMiles)
    }

    init(
        date: Date = Date(),
        rideType: RideType = .casualRide,
        distanceMiles: Double = 0,
        durationSeconds: TimeInterval = 0,
        movingTimeSeconds: TimeInterval = 0,
        averageSpeed: Double = 0,
        maxSpeed: Double = 0,
        totalElevationGain: Double = 0,
        totalElevationLoss: Double = 0,
        averageHeartRate: Int = 0,
        maxHeartRate: Int = 0,
        averageCadence: Int = 0,
        maxCadence: Int = 0,
        averagePower: Int = 0,
        maxPower: Int = 0,
        caloriesBurned: Int = 0,
        segments: [RideSegment] = [],
        routeCoordinates: [CyclingRouteCoordinate] = [],
        heartRateZones: [HeartRateZoneDistribution] = [],
        bikeId: UUID? = nil,
        temperature: Double? = nil,
        notes: String = "",
        isIndoor: Bool = false
    ) {
        self.id = UUID()
        self.date = date
        self.rideType = rideType
        self.distanceMiles = distanceMiles
        self.durationSeconds = durationSeconds
        self.movingTimeSeconds = movingTimeSeconds > 0 ? movingTimeSeconds : durationSeconds
        self.averageSpeed = averageSpeed
        self.maxSpeed = maxSpeed
        self.totalElevationGain = totalElevationGain
        self.totalElevationLoss = totalElevationLoss
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.averageCadence = averageCadence
        self.maxCadence = maxCadence
        self.averagePower = averagePower
        self.maxPower = maxPower
        self.caloriesBurned = caloriesBurned
        self.segments = segments
        self.routeCoordinates = routeCoordinates
        self.heartRateZones = heartRateZones
        self.bikeId = bikeId
        self.temperature = temperature
        self.notes = notes
        self.isIndoor = isIndoor
    }
}

nonisolated struct Bike: Identifiable, Sendable, Codable {
    let id: UUID
    var name: String
    var type: String
    var totalMiles: Double
    var maintenanceIntervalMiles: Double
    var lastMaintenanceMiles: Double
    var dateAdded: Date
    var isRetired: Bool
    var colorHex: String

    var milesSinceLastMaintenance: Double { totalMiles - lastMaintenanceMiles }
    var maintenanceProgress: Double { min(milesSinceLastMaintenance / maintenanceIntervalMiles, 1.0) }

    var maintenanceStatusColor: Color {
        switch maintenanceProgress {
        case ..<0.6: .green
        case 0.6..<0.8: .yellow
        case 0.8..<1.0: .orange
        default: .red
        }
    }

    init(name: String, type: String = "Road", totalMiles: Double = 0, maintenanceIntervalMiles: Double = 500, colorHex: String = "F27300") {
        self.id = UUID()
        self.name = name
        self.type = type
        self.totalMiles = totalMiles
        self.maintenanceIntervalMiles = maintenanceIntervalMiles
        self.lastMaintenanceMiles = 0
        self.dateAdded = Date()
        self.isRetired = false
        self.colorHex = colorHex
    }
}

nonisolated struct WeeklyRideDistance: Identifiable, Sendable {
    let id: UUID
    let weekStart: Date
    let totalMiles: Double
    let totalElevation: Double
    let rideCount: Int
    let avgSpeed: Double

    init(weekStart: Date, totalMiles: Double, totalElevation: Double, rideCount: Int, avgSpeed: Double) {
        self.id = UUID()
        self.weekStart = weekStart
        self.totalMiles = totalMiles
        self.totalElevation = totalElevation
        self.rideCount = rideCount
        self.avgSpeed = avgSpeed
    }
}

nonisolated struct PersonalRouteRecord: Identifiable, Sendable {
    let id: UUID
    let routeHash: String
    let routeName: String
    let bestTime: TimeInterval
    let bestSpeed: Double
    let bestDate: Date
    let attempts: Int

    init(routeHash: String, routeName: String, bestTime: TimeInterval, bestSpeed: Double, bestDate: Date, attempts: Int) {
        self.id = UUID()
        self.routeHash = routeHash
        self.routeName = routeName
        self.bestTime = bestTime
        self.bestSpeed = bestSpeed
        self.bestDate = bestDate
        self.attempts = attempts
    }
}

nonisolated struct CyclingSettings: Sendable, Codable {
    var speedUnit: SpeedUnit = .mph
    var distanceUnit: DistanceUnit = .miles
    var autoPause: Bool = true
    var countdownSeconds: Int = 3
    var showPowerData: Bool = false
    var audioAnnounceInterval: AudioCueInterval = .everyMile
    var announceSpeed: Bool = true
    var announceDistance: Bool = true
    var announceHeartRate: Bool = true
}

nonisolated enum CyclingFormatters {
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    static func formatSpeed(_ speed: Double) -> String {
        String(format: "%.1f", speed)
    }
}
