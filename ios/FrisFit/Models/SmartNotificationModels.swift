import Foundation
import SwiftUI

// MARK: - Categories

nonisolated enum SmartNotificationCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    case training
    case sleep
    case nutrition
    case supplements
    case tasks
    case social
    case streaks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .training:    return "Training"
        case .sleep:       return "Sleep"
        case .nutrition:   return "Nutrition"
        case .supplements: return "Supplements"
        case .tasks:       return "Daily Tasks"
        case .social:      return "Social"
        case .streaks:     return "Streaks"
        }
    }

    var blurb: String {
        switch self {
        case .training:    return "Pre-session reminders and missed-workout nudges"
        case .sleep:       return "Wind-down ping and morning sleep log"
        case .nutrition:   return "Meal logging, hydration, macro check-ins"
        case .supplements: return "Time-of-day dose reminders from your protocol"
        case .tasks:       return "Morning brief and unfinished tasks"
        case .social:      return "DMs, mentions, friend activity"
        case .streaks:     return "Milestones and save-your-streak alerts"
        }
    }

    var icon: String {
        switch self {
        case .training:    return "figure.run"
        case .sleep:       return "moon.stars.fill"
        case .nutrition:   return "fork.knife"
        case .supplements: return "pills.fill"
        case .tasks:       return "checklist"
        case .social:      return "bubble.left.and.bubble.right.fill"
        case .streaks:     return "flame.fill"
        }
    }

    /// Visual accent — left edge color, icon tint.
    var accent: Color {
        switch self {
        case .training:    return .orange
        case .sleep:       return Color(red: 0.42, green: 0.45, blue: 0.95) // indigo
        case .nutrition:   return PepTheme.success
        case .supplements: return PepTheme.violet
        case .tasks:       return PepTheme.teal
        case .social:      return PepTheme.blue
        case .streaks:     return PepTheme.amber
        }
    }

    /// Lower number = higher priority for frequency-cap dropping.
    var priority: Int {
        switch self {
        case .social:      return 0
        case .supplements: return 1
        case .training:    return 2
        case .sleep:       return 3
        case .nutrition:   return 4
        case .tasks:       return 5
        case .streaks:     return 6
        }
    }
}

// MARK: - Settings

nonisolated struct SmartNotificationSettings: Codable, Sendable, Equatable {
    var masterEnabled: Bool = true
    var enabledCategories: Set<SmartNotificationCategory> = Set(SmartNotificationCategory.allCases)
    /// Quiet hours expressed as hour-of-day (0-23) inclusive start, exclusive end.
    /// Defaults to 22:00 → 07:00.
    var quietStartHour: Int = 22
    var quietEndHour: Int = 7
    /// Max notifications per day across all categories. `nil` = unlimited.
    var dailyCap: Int? = 5

    static let `default` = SmartNotificationSettings()

    func isCategoryEnabled(_ c: SmartNotificationCategory) -> Bool {
        masterEnabled && enabledCategories.contains(c)
    }

    /// Returns true if the date falls inside quiet hours.
    func isQuiet(at date: Date, calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: date)
        if quietStartHour == quietEndHour { return false }
        if quietStartHour < quietEndHour {
            return hour >= quietStartHour && hour < quietEndHour
        }
        // Wraps midnight (e.g. 22 → 7)
        return hour >= quietStartHour || hour < quietEndHour
    }

    /// Snap a date out of quiet hours by pushing it to `quietEndHour` of the same/next day.
    func nudgeOutOfQuietHours(_ date: Date, calendar: Calendar = .current) -> Date {
        guard isQuiet(at: date, calendar: calendar) else { return date }
        var comps = calendar.dateComponents([.year, .month, .day], from: date)
        comps.hour = quietEndHour
        comps.minute = 0
        var target = calendar.date(from: comps) ?? date
        if target <= date {
            target = calendar.date(byAdding: .day, value: 1, to: target) ?? target
        }
        return target
    }
}

// MARK: - Log entry (in-app history)

nonisolated struct SmartNotificationLogEntry: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let category: SmartNotificationCategory
    let title: String
    let body: String
    let firedAt: Date
    var isRead: Bool
    /// Optional deep-link key (matches DeepLinkRouter user-info keys).
    let deepLink: [String: String]?

    init(
        id: String = UUID().uuidString,
        category: SmartNotificationCategory,
        title: String,
        body: String,
        firedAt: Date = Date(),
        isRead: Bool = false,
        deepLink: [String: String]? = nil
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.body = body
        self.firedAt = firedAt
        self.isRead = isRead
        self.deepLink = deepLink
    }
}
