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
    let dailyCalories: [DailyDataPoint]   // calories consumed
    let dailySteps: [DailyDataPoint]
    let dailyProtein: [DailyDataPoint]
    let dailyCaloriesBurned: [DailyDataPoint]
    let dailyExerciseMinutes: [DailyDataPoint]
    let dailySleep: [DailyDataPoint]
    let dailyWeight: [DailyDataPoint]
    let stepGoal: Int
    let proteinGoal: Int
    let calorieGoal: Int
    let workoutGoal: Int
    let daysWithFood: Int
    let daysWithSleep: Int

    var weightChange: Double { weightEnd - weightStart }
    var goalDaysHit: Int {
        zip(dailySteps, [Int](repeating: stepGoal, count: dailySteps.count))
            .filter { Int($0.0.value) >= $0.1 }
            .count
    }
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
    let weeklyCalories: [DailyDataPoint]   // calories consumed avg/day per week
    let weeklySteps: [DailyDataPoint]      // avg steps/day per week
    let weeklyWeight: [DailyDataPoint]
    let weeklyExerciseMinutes: [DailyDataPoint]
    let weeklyCaloriesBurned: [DailyDataPoint]
    let weeklySleep: [DailyDataPoint]
    let totalDays: Int
    let activeDays: Int
    let bestStepDay: (date: Date, steps: Int)?
    let bestStepStreak: Int
    let stepGoal: Int

    var weightChange: Double { weightEnd - weightStart }
}

private extension MonthlySummaryData {
    nonisolated init(_unused: Void = (),
        totalWorkouts: Int,
        totalCaloriesBurned: Int,
        totalExerciseMinutes: Int,
        avgStepsPerDay: Int,
        avgCaloriesConsumed: Int,
        avgProtein: Int,
        avgSleepHours: Double,
        weightStart: Double,
        weightEnd: Double,
        weeklyWorkouts: [DailyDataPoint],
        weeklyCalories: [DailyDataPoint],
        weeklySteps: [DailyDataPoint],
        weeklyWeight: [DailyDataPoint],
        weeklyExerciseMinutes: [DailyDataPoint],
        weeklyCaloriesBurned: [DailyDataPoint],
        weeklySleep: [DailyDataPoint],
        totalDays: Int,
        activeDays: Int,
        bestStepDay: (date: Date, steps: Int)?,
        bestStepStreak: Int,
        stepGoal: Int
    ) {
        self.totalWorkouts = totalWorkouts
        self.totalCaloriesBurned = totalCaloriesBurned
        self.totalExerciseMinutes = totalExerciseMinutes
        self.avgStepsPerDay = avgStepsPerDay
        self.avgCaloriesConsumed = avgCaloriesConsumed
        self.avgProtein = avgProtein
        self.avgSleepHours = avgSleepHours
        self.weightStart = weightStart
        self.weightEnd = weightEnd
        self.weeklyWorkouts = weeklyWorkouts
        self.weeklyCalories = weeklyCalories
        self.weeklySteps = weeklySteps
        self.weeklyWeight = weeklyWeight
        self.weeklyExerciseMinutes = weeklyExerciseMinutes
        self.weeklyCaloriesBurned = weeklyCaloriesBurned
        self.weeklySleep = weeklySleep
        self.totalDays = totalDays
        self.activeDays = activeDays
        self.bestStepDay = bestStepDay
        self.bestStepStreak = bestStepStreak
        self.stepGoal = stepGoal
    }
}
