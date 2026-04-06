import SwiftUI

nonisolated struct CalendarDay: Identifiable, Sendable {
    var id: Date { date }
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasActivity: Bool

    var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

nonisolated struct PlanExercise: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let muscle: String
    let sets: Int
    let repsMin: Int
    let repsMax: Int
    let equipment: String
    let equipmentIcon: String
}

nonisolated struct WorkoutPlan: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let exercises: Int
    let estimatedMinutes: Int
    let isRestDay: Bool
    let recoveryTip: String?
    let planExercises: [PlanExercise]
    let splitDays: [SplitDay]
}

nonisolated struct SplitDay: Identifiable, Sendable {
    let id = UUID()
    let dayIndex: Int
    let name: String
    let isToday: Bool
    let isRest: Bool
}

nonisolated struct NutritionSnapshot: Sendable {
    let caloriesConsumed: Int
    let caloriesTarget: Int
    let proteinConsumed: Int
    let proteinTarget: Int
}

nonisolated struct FriendActivity: Identifiable, Sendable {
    let id = UUID()
    let friendName: String
    let workoutName: String
    let fpEarned: Int
    let timeAgo: String
    let highFived: Bool
}

nonisolated struct QuickStats: Sendable {
    let streakDays: Int
    let workoutsThisWeek: Int
    let leaderboardRank: Int
}

nonisolated struct WeekItem: Identifiable, Sendable {
    var id: Date { weekStart }
    let weekStart: Date
    let weekEnd: Date
    let isSelected: Bool
    let isCurrent: Bool

    var shortLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: weekStart)
    }

    var weekNumber: String {
        let cal = Calendar.current
        let weekOfYear = cal.component(.weekOfYear, from: weekStart)
        return "W\(weekOfYear)"
    }
}

nonisolated struct MonthItem: Identifiable, Sendable {
    var id: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
    let date: Date
    let isSelected: Bool
    let isCurrent: Bool

    var shortLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    var yearLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: date)
    }
}
