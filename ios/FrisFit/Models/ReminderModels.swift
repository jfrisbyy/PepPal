import Foundation

nonisolated enum ReminderCategory: String, CaseIterable, Sendable {
    case dose = "dose"
    case bloodwork = "bloodwork"
    case weighIn = "weigh_in"
    case workout = "workout"
    case mealLogging = "meal_logging"
    case hydration = "hydration"
    case restDay = "rest_day"
    case weeklyCheckIn = "weekly_check_in"

    var title: String {
        switch self {
        case .dose: return "Dose Reminders"
        case .bloodwork: return "Bloodwork Reminder"
        case .weighIn: return "Weigh-In Reminder"
        case .workout: return "Workout Reminder"
        case .mealLogging: return "Meal Logging Nudge"
        case .hydration: return "Hydration Nudges"
        case .restDay: return "Rest Day Reminders"
        case .weeklyCheckIn: return "Weekly Check-In"
        }
    }

    var subtitle: String {
        switch self {
        case .dose: return "Get reminded when it's time for your scheduled doses"
        case .bloodwork: return "Periodic reminder to schedule bloodwork panels"
        case .weighIn: return "Weekly reminder to log your weight"
        case .workout: return "Daily nudge to hit the gym"
        case .mealLogging: return "Reminders to log meals throughout the day"
        case .hydration: return "Stay hydrated with nudges at your chosen times"
        case .restDay: return "Nudge if you miss a planned workout"
        case .weeklyCheckIn: return "Weekly weigh-in + progress photo reminder"
        }
    }

    var icon: String {
        switch self {
        case .dose: return "syringe.fill"
        case .bloodwork: return "drop.fill"
        case .weighIn: return "scalemass.fill"
        case .workout: return "figure.run"
        case .mealLogging: return "fork.knife"
        case .hydration: return "drop.halffull"
        case .restDay: return "bed.double.fill"
        case .weeklyCheckIn: return "calendar.badge.checkmark"
        }
    }

    var iconColor: ReminderIconColor {
        switch self {
        case .dose: return .teal
        case .bloodwork: return .red
        case .weighIn: return .blue
        case .workout: return .amber
        case .mealLogging: return .violet
        case .hydration: return .blue
        case .restDay: return .violet
        case .weeklyCheckIn: return .teal
        }
    }

    var isHealthReminder: Bool {
        switch self {
        case .dose, .bloodwork, .weighIn, .weeklyCheckIn: return true
        case .workout, .mealLogging, .hydration, .restDay: return false
        }
    }

    var defaultEnabled: Bool {
        switch self {
        case .dose: return true
        default: return false
        }
    }
}

nonisolated enum ReminderIconColor: Sendable {
    case teal, red, blue, amber, violet
}

nonisolated enum WeighInDay: Int, CaseIterable, Sendable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var name: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
}

nonisolated enum BloodworkInterval: Int, CaseIterable, Sendable {
    case days30 = 30
    case days60 = 60
    case days90 = 90

    var label: String {
        switch self {
        case .days30: return "Every 30 days"
        case .days60: return "Every 60 days"
        case .days90: return "Every 90 days"
        }
    }
}
