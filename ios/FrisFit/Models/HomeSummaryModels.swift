import SwiftUI

nonisolated enum HomeTimePeriod: String, CaseIterable, Identifiable, Sendable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"

    var id: String { rawValue }
}

nonisolated struct DailyDataPoint: Identifiable, Sendable {
    let id = UUID()
    let label: String
    let value: Double
}

nonisolated struct WeeklySummaryData: Sendable {
    let totalWorkouts: Int
    let totalCaloriesBurned: Int
    let totalExerciseMinutes: Int
    let avgSteps: Int
    let totalSteps: Int
    let avgCaloriesConsumed: Int
    let avgProtein: Int
    let avgSleepHours: Double
    let weightStart: Double
    let weightEnd: Double
    let dailyWorkouts: [DailyDataPoint]
    let dailyCalories: [DailyDataPoint]
    let dailySteps: [DailyDataPoint]
    let dailyProtein: [DailyDataPoint]

    var weightChange: Double { weightEnd - weightStart }
}

nonisolated struct MonthlySummaryData: Sendable {
    let totalWorkouts: Int
    let totalCaloriesBurned: Int
    let totalExerciseMinutes: Int
    let avgStepsPerDay: Int
    let avgCaloriesConsumed: Int
    let avgProtein: Int
    let avgSleepHours: Double
    let weightStart: Double
    let weightEnd: Double
    let weeklyWorkouts: [DailyDataPoint]
    let weeklyCalories: [DailyDataPoint]
    let weeklySteps: [DailyDataPoint]
    let weeklyWeight: [DailyDataPoint]

    var weightChange: Double { weightEnd - weightStart }
}
