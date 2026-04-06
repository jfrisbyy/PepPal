import Foundation

nonisolated enum NotificationType: String, CaseIterable, Sendable {
    case workoutReminder = "workout_reminder"
    case friendWorkout = "friend_workout"
    case friendHighFive = "friend_high_five"
    case streakMilestone = "streak_milestone"
    case weeklyProgress = "weekly_progress"
    case restDayRecovery = "rest_day_recovery"
    case streakWarning = "streak_warning"

    var title: String {
        switch self {
        case .workoutReminder: "Workout Reminders"
        case .friendWorkout: "Friend Workouts"
        case .friendHighFive: "High-Fives"
        case .streakMilestone: "Streak Milestones"
        case .weeklyProgress: "Weekly Progress"
        case .restDayRecovery: "Recovery Tips"
        case .streakWarning: "Streak Alerts"
        }
    }

    var subtitle: String {
        switch self {
        case .workoutReminder: "Daily reminders at your preferred time"
        case .friendWorkout: "When friends complete a workout"
        case .friendHighFive: "When someone high-fives your post"
        case .streakMilestone: "Celebrate streak achievements"
        case .weeklyProgress: "Weekly FP progress summary"
        case .restDayRecovery: "Recovery tips from Finn on rest days"
        case .streakWarning: "Reminder before your streak breaks"
        }
    }

    var icon: String {
        switch self {
        case .workoutReminder: "alarm.fill"
        case .friendWorkout: "person.fill.checkmark"
        case .friendHighFive: "hand.raised.fill"
        case .streakMilestone: "flame.fill"
        case .weeklyProgress: "chart.bar.fill"
        case .restDayRecovery: "bed.double.fill"
        case .streakWarning: "exclamationmark.triangle.fill"
        }
    }
}

nonisolated struct NotificationPreferences: Sendable {
    var enabled: Bool
    var workoutReminderTime: Date
    var enabledTypes: Set<NotificationType>
}
