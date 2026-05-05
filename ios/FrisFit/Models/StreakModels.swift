import Foundation

nonisolated enum StreakState: String, Sendable {
    case active        // logged today
    case grace         // haven't logged today yet, but yesterday is intact (or covered by freeze) — still in flame state
    case paused        // missed yesterday, freeze unavailable, 24h window to save it
    case broken        // streak rolled to 0
    case dormant       // never started a streak
}

nonisolated struct StreakData: Sendable {
    let currentStreak: Int
    let longestStreak: Int
    let lastActivityDate: Date?
    /// True when the most recent freeze is still inside the rolling 7-day window
    let streakFreezeAvailable: Bool
    /// When the active freeze (if any) expires and a new one becomes available
    let freezeAvailableAgainAt: Date?
    /// When the most recent freeze was auto-applied (for "covered yesterday" UI)
    let freezeUsedAt: Date?
    /// True when we've entered a paused state — user has 24h from this Date to log
    let pausedUntil: Date?
    let missedYesterday: Bool

    var streakFreezeUsedThisWeek: Bool { freezeAvailableAgainAt != nil && (freezeAvailableAgainAt ?? .distantPast) > Date() }

    static let empty = StreakData(
        currentStreak: 0,
        longestStreak: 0,
        lastActivityDate: nil,
        streakFreezeAvailable: true,
        freezeAvailableAgainAt: nil,
        freezeUsedAt: nil,
        pausedUntil: nil,
        missedYesterday: false
    )
}

nonisolated struct ActivityLog: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let type: ActivityType
    let sport: Sport?

    init(id: UUID, date: Date, type: ActivityType, sport: Sport? = nil) {
        self.id = id
        self.date = date
        self.type = type
        self.sport = sport
    }
}

nonisolated enum ActivityType: String, Sendable, CaseIterable {
    case workout
    case sportSession
    case pin            // peptide dose / injection
    case weight         // weigh-in
    case food           // meal log
    case mood           // mood / side-effects / daily check-in
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
