import Foundation

nonisolated struct StreakData: Sendable {
    let currentStreak: Int
    let longestStreak: Int
    let lastActivityDate: Date?
    let streakFreezeAvailable: Bool
    let streakFreezeUsedThisWeek: Bool
    let missedYesterday: Bool
}

nonisolated struct ActivityLog: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let type: ActivityType
}

nonisolated enum ActivityType: String, Sendable {
    case workout
    case sportSession
    case streakFreeze
}

nonisolated enum StreakMilestone: Int, CaseIterable, Sendable {
    case week = 7
    case month = 30
    case twoMonths = 60
    case quarter = 90
    case year = 365

    var badgeName: String {
        switch self {
        case .week: "Week Warrior"
        case .month: "Iron Will"
        case .twoMonths: "Relentless"
        case .quarter: "Unbreakable"
        case .year: "Legendary"
        }
    }

    var badgeIcon: String {
        switch self {
        case .week: "flame.fill"
        case .month: "flame.circle.fill"
        case .twoMonths: "bolt.heart.fill"
        case .quarter: "shield.checkered"
        case .year: "crown.fill"
        }
    }

    var badgeDescription: String {
        switch self {
        case .week: "Maintain a 7-day streak"
        case .month: "Maintain a 30-day streak"
        case .twoMonths: "Maintain a 60-day streak"
        case .quarter: "Maintain a 90-day streak"
        case .year: "Maintain a 365-day streak"
        }
    }
}
