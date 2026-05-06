import Foundation
import SwiftUI

nonisolated enum TrainModeType: String, CaseIterable, Identifiable, Sendable, Codable {
    case main = "Main"
    case running = "Running"
    case basketball = "Basketball"
    case cycling = "Cycling"
    case swimming = "Swimming"
    case soccer = "Soccer"
    case tennis = "Tennis"
    case volleyball = "Volleyball"
    case football = "Football"
    case custom = "Custom"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .main: "figure.strengthtraining.traditional"
        case .running: "figure.run"
        case .basketball: "basketball.fill"
        case .cycling: "figure.outdoor.cycle"
        case .swimming: "figure.pool.swim"
        case .soccer: "soccerball"
        case .tennis: "tennis.racket"
        case .volleyball: "figure.volleyball"
        case .football: "football.fill"
        case .custom: "star.fill"
        }
    }

    var color: Color {
        switch self {
        case .main: Color(red: 0, green: 229/255, blue: 255/255)
        case .running: Color(red: 0.0, green: 0.9, blue: 1.0)
        case .basketball: Color(red: 1.0, green: 0.55, blue: 0.1)
        case .cycling: Color(red: 0.95, green: 0.45, blue: 0.0)
        case .swimming: Color(red: 0.2, green: 0.6, blue: 1.0)
        case .soccer: Color(red: 0.2, green: 0.78, blue: 0.35)
        case .tennis: Color(red: 0.85, green: 0.9, blue: 0.15)
        case .volleyball: Color(red: 0.95, green: 0.30, blue: 0.20)
        case .football: Color(red: 0.55, green: 0.35, blue: 0.17)
        case .custom: Color(red: 0.55, green: 0.36, blue: 0.96)
        }
    }

    var sport: Sport? {
        switch self {
        case .running: .running
        case .basketball: .basketball
        case .cycling: .cycling
        case .swimming: .swimming
        case .soccer: .soccer
        case .tennis: .tennis
        case .volleyball: .volleyball
        case .football: .football
        default: nil
        }
    }

    var defaultCards: [TrainCardType] {
        switch self {
        case .main:
            return TrainCardType.allCases
        case .running:
            return [.sportSessions, .sportStats, .weeklyDistance, .paceChart, .sportHistory, .goals]
        case .basketball:
            return [.sportSessions, .sportStats, .gameLog, .shootingStats, .sportHistory, .goals]
        case .cycling:
            return [.sportSessions, .sportStats, .weeklyDistance, .sportHistory, .goals]
        case .swimming:
            return [.sportSessions, .sportStats, .lapTracker, .sportHistory, .goals]
        case .soccer:
            return [.sportSessions, .sportStats, .gameLog, .sportHistory, .goals]
        case .tennis:
            return [.sportSessions, .sportStats, .gameLog, .sportHistory, .goals]
        case .volleyball:
            return [.sportSessions, .sportStats, .gameLog, .sportHistory, .goals]
        case .football:
            return [.sportSessions, .sportStats, .gameLog, .sportHistory, .goals]
        case .custom:
            return [.sportSessions, .sportStats, .sportHistory, .goals]
        }
    }
}

nonisolated enum TrainCardType: String, CaseIterable, Identifiable, Sendable, Codable {
    case todayWorkout = "Today's Workout"
    case consistencyRing = "Consistency"
    case weeklyInsights = "Weekly Insights"
    case personalRecords = "Personal Records"
    case weeklyVolume = "Weekly Volume"
    case muscleRecovery = "Recovery Status"
    case warmup = "Warm-up"
    case templates = "Templates"
    case history = "Activity History"
    case sportSessions = "Sessions"
    case sportStats = "Sport Stats"
    case weeklyDistance = "Weekly Distance"
    case paceChart = "Pace Tracking"
    case gameLog = "Game Log"
    case shootingStats = "Shooting Stats"
    case lapTracker = "Lap Tracker"
    case goals = "Goals"
    case sportHistory = "Recent Sessions"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .todayWorkout: "calendar.badge.clock"
        case .consistencyRing: "target"
        case .weeklyInsights: "chart.bar.fill"
        case .personalRecords: "trophy.fill"
        case .weeklyVolume: "scalemass.fill"
        case .muscleRecovery: "heart.text.clipboard"
        case .warmup: "figure.flexibility"
        case .templates: "doc.on.doc"
        case .history: "clock.arrow.circlepath"
        case .sportSessions: "list.bullet.clipboard"
        case .sportStats: "chart.xyaxis.line"
        case .weeklyDistance: "map.fill"
        case .paceChart: "speedometer"
        case .gameLog: "sportscourt.fill"
        case .shootingStats: "scope"
        case .lapTracker: "stopwatch.fill"
        case .goals: "flag.checkered"
        case .sportHistory: "clock.arrow.circlepath"
        }
    }
}

nonisolated struct TrainMode: Identifiable, Sendable, Codable {
    let id: UUID
    var name: String
    var type: TrainModeType
    var cards: [TrainCardType]
    var customSportName: String?

    init(type: TrainModeType, customSportName: String? = nil) {
        self.id = UUID()
        self.name = customSportName ?? type.rawValue
        self.type = type
        self.cards = type.defaultCards
        self.customSportName = customSportName
    }
}
