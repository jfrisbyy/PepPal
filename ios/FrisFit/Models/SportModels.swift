import Foundation
import SwiftUI

nonisolated enum Sport: String, CaseIterable, Identifiable, Sendable {
    case basketball = "Basketball"
    case football = "Football"
    case soccer = "Soccer"
    case baseball = "Baseball"
    case tennis = "Tennis"
    case swimming = "Swimming"
    case running = "Running"
    case cycling = "Cycling"
    case custom = "Custom"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .basketball: "basketball.fill"
        case .football: "football.fill"
        case .soccer: "soccerball"
        case .baseball: "baseball.fill"
        case .tennis: "tennis.racket"
        case .swimming: "figure.pool.swim"
        case .running: "figure.run"
        case .cycling: "figure.outdoor.cycle"
        case .custom: "star.fill"
        }
    }

    var color: Color {
        switch self {
        case .basketball: Color(red: 1.0, green: 0.55, blue: 0.1)
        case .football: Color(red: 0.55, green: 0.35, blue: 0.17)
        case .soccer: Color(red: 0.2, green: 0.78, blue: 0.35)
        case .baseball: Color(red: 0.85, green: 0.25, blue: 0.25)
        case .tennis: Color(red: 0.85, green: 0.9, blue: 0.15)
        case .swimming: Color(red: 0.2, green: 0.6, blue: 1.0)
        case .running: Color(red: 0.0, green: 0.9, blue: 1.0)
        case .cycling: Color(red: 0.95, green: 0.45, blue: 0.0)
        case .custom: Color(red: 0.55, green: 0.36, blue: 0.96)
        }
    }

    var hasSpecificStats: Bool {
        switch self {
        case .basketball, .running, .swimming, .cycling, .soccer, .tennis: true
        default: false
        }
    }
}

nonisolated enum SportSessionType: String, CaseIterable, Identifiable, Sendable {
    case practice = "Practice"
    case game = "Game"
    case training = "Training"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .practice: "figure.strengthtraining.traditional"
        case .game: "trophy"
        case .training: "bolt.fill"
        }
    }
}

nonisolated struct BasketballStats: Sendable {
    var points: Int = 0
    var assists: Int = 0
    var rebounds: Int = 0
}

nonisolated struct RunningStats: Sendable {
    var distanceMiles: Double = 0.0
    var paceMinutesPerMile: Double = 0.0
}

nonisolated enum SwimmingStroke: String, CaseIterable, Identifiable, Sendable {
    case freestyle = "Freestyle"
    case backstroke = "Backstroke"
    case breaststroke = "Breaststroke"
    case butterfly = "Butterfly"
    case mixed = "Mixed"

    var id: String { rawValue }
}

nonisolated struct SwimmingStats: Sendable {
    var laps: Int = 0
    var stroke: SwimmingStroke = .freestyle
}

nonisolated struct CyclingStats: Sendable {
    var distanceMiles: Double = 0.0
    var averageSpeed: Double = 0.0
    var elevationGain: Double = 0.0
}

nonisolated struct SoccerSessionStats: Sendable {
    var goals: Int = 0
    var assists: Int = 0
    var distanceKm: Double = 0
}

nonisolated struct TennisSessionStats: Sendable {
    var aces: Int = 0
    var doubleFaults: Int = 0
    var winners: Int = 0
    var unforcedErrors: Int = 0
    var firstServePercentage: Double = 0
}

nonisolated enum SportSpecificStats: Sendable {
    case basketball(BasketballStats)
    case running(RunningStats)
    case swimming(SwimmingStats)
    case cycling(CyclingStats)
    case soccer(SoccerSessionStats)
    case tennis(TennisSessionStats)
    case none
}

nonisolated struct SportSession: Identifiable, Sendable {
    let id: UUID
    let sport: Sport
    let sessionType: SportSessionType
    let durationMinutes: Int
    let intensity: Int
    let date: Date
    let specificStats: SportSpecificStats
    let customSportName: String?

    init(sport: Sport, sessionType: SportSessionType, durationMinutes: Int, intensity: Int, date: Date = Date(), specificStats: SportSpecificStats = .none, customSportName: String? = nil) {
        self.id = UUID()
        self.sport = sport
        self.sessionType = sessionType
        self.durationMinutes = durationMinutes
        self.intensity = intensity
        self.date = date
        self.specificStats = specificStats
        self.customSportName = customSportName
    }

    var displayName: String {
        if sport == .custom, let name = customSportName, !name.isEmpty {
            return name
        }
        return sport.rawValue
    }
}

nonisolated struct SportAnalyticsData: Sendable {
    let sport: Sport
    let sessionCount: Int
    let totalMinutes: Int
    let averageIntensity: Double
}
