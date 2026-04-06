import SwiftUI

@Observable
final class HomeViewModel {
    var dailyTasks: [DailyTask] = DailyTaskLibrary.defaultTasks()
    var isLoading: Bool = true
    var selectedDate: Date = Date()
    var selectedTimePeriod: HomeTimePeriod = .daily
    var isDateSelectorExpanded: Bool = false
    var selectedWeekStart: Date = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
    var selectedMonthDate: Date = Date()

    let streakManager = StreakManager.shared
    let notificationService = NotificationService.shared
    let healthKit = HealthKitService.shared

    private let calendar = Calendar.current

    var calendarWeekDays: [CalendarDay] {
        let today = calendar.startOfDay(for: Date())
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else { return [] }
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
            let isToday = calendar.isDateInToday(date)
            let hasActivity = streakManager.activityLog.contains { calendar.isDate($0.date, inSameDayAs: date) }
            return CalendarDay(date: date, isSelected: isSelected, isToday: isToday, hasActivity: hasActivity)
        }
    }

    var selectedDateLabel: String {
        if calendar.isDateInToday(selectedDate) {
            return "Today"
        } else if calendar.isDateInYesterday(selectedDate) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: selectedDate)
        }
    }

    var toolbarDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }

    var isSelectedDateToday: Bool {
        calendar.isDateInToday(selectedDate)
    }

    // MARK: - Week Navigation

    var isSelectedWeekCurrent: Bool {
        let currentWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        return calendar.isDate(selectedWeekStart, inSameDayAs: currentWeekStart)
    }

    var weekNavigationWeeks: [WeekItem] {
        (-2...2).compactMap { offset in
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: offset, to: selectedWeekStart) else { return nil }
            guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else { return nil }
            let isSelected = calendar.isDate(weekStart, inSameDayAs: selectedWeekStart)
            let currentWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
            let isCurrent = calendar.isDate(weekStart, inSameDayAs: currentWeekStart)
            return WeekItem(weekStart: weekStart, weekEnd: weekEnd, isSelected: isSelected, isCurrent: isCurrent)
        }
    }

    var selectedWeekLabel: String {
        if isSelectedWeekCurrent { return "This Week" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let endDate = calendar.date(byAdding: .day, value: 6, to: selectedWeekStart) ?? selectedWeekStart
        return "\(formatter.string(from: selectedWeekStart)) – \(formatter.string(from: endDate))"
    }

    func navigateWeek(by offset: Int) {
        guard let newStart = calendar.date(byAdding: .weekOfYear, value: offset, to: selectedWeekStart) else { return }
        selectedWeekStart = newStart
    }

    // MARK: - Month Navigation

    var isSelectedMonthCurrent: Bool {
        calendar.isDate(selectedMonthDate, equalTo: Date(), toGranularity: .month)
    }

    var monthNavigationMonths: [MonthItem] {
        (-2...2).compactMap { offset in
            guard let monthDate = calendar.date(byAdding: .month, value: offset, to: selectedMonthDate) else { return nil }
            let isSelected = calendar.isDate(monthDate, equalTo: selectedMonthDate, toGranularity: .month)
            let isCurrent = calendar.isDate(monthDate, equalTo: Date(), toGranularity: .month)
            return MonthItem(date: monthDate, isSelected: isSelected, isCurrent: isCurrent)
        }
    }

    var selectedMonthLabel: String {
        if isSelectedMonthCurrent { return "This Month" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonthDate)
    }

    func navigateMonth(by offset: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: offset, to: selectedMonthDate) else { return }
        selectedMonthDate = newMonth
    }

    var selectedDateActivities: [ActivityLog] {
        streakManager.activityLog.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    var selectedDateWorkoutCount: Int {
        selectedDateActivities.filter { $0.type == .workout }.count
    }

    var selectedDateSportCount: Int {
        selectedDateActivities.filter { $0.type == .sportSession }.count
    }

    var selectedDateNutrition: NutritionSnapshot {
        if calendar.isDateInToday(selectedDate) {
            return nutrition
        }
        return NutritionSnapshot(caloriesConsumed: 0, caloriesTarget: nutrition.caloriesTarget, proteinConsumed: 0, proteinTarget: nutrition.proteinTarget)
    }

    var earnedPoints: Int {
        dailyTasks.filter(\.isCompleted).reduce(0) { $0 + $1.points }
    }

    var totalPoints: Int {
        dailyTasks.reduce(0) { $0 + $1.points }
    }

    var pointsProgress: Double {
        guard totalPoints > 0 else { return 0 }
        return Double(earnedPoints) / Double(totalPoints)
    }

    var recentlyCompleted: [DailyTask] {
        Array(dailyTasks.filter(\.isCompleted).prefix(3))
    }

    var completedCount: Int {
        dailyTasks.filter(\.isCompleted).count
    }

    func toggleTask(_ task: DailyTask) {
        guard let index = dailyTasks.firstIndex(where: { $0.id == task.id }) else { return }
        dailyTasks[index].isCompleted.toggle()
    }

    func tasks(for category: TaskCategory) -> [DailyTask] {
        dailyTasks.filter { $0.category == category }
    }

    var isPlanExpanded: Bool = false
    var showEditSplit: Bool = false

    var todaysPlan: WorkoutPlan = WorkoutPlan(
        name: "Push Day — Chest, Shoulders, Triceps",
        exercises: 6,
        estimatedMinutes: 52,
        isRestDay: false,
        recoveryTip: nil,
        planExercises: [
            PlanExercise(name: "Barbell Bench Press", muscle: "Chest", sets: 4, repsMin: 6, repsMax: 10, equipment: "Barbell", equipmentIcon: "dumbbell.fill"),
            PlanExercise(name: "Incline Dumbbell Press", muscle: "Upper Chest", sets: 3, repsMin: 8, repsMax: 12, equipment: "Dumbbell", equipmentIcon: "dumbbell"),
            PlanExercise(name: "Overhead Press", muscle: "Shoulders", sets: 4, repsMin: 6, repsMax: 10, equipment: "Barbell", equipmentIcon: "dumbbell.fill"),
            PlanExercise(name: "Cable Lateral Raise", muscle: "Side Delts", sets: 3, repsMin: 12, repsMax: 15, equipment: "Cable", equipmentIcon: "cable.connector"),
            PlanExercise(name: "Tricep Pushdown", muscle: "Triceps", sets: 3, repsMin: 10, repsMax: 15, equipment: "Cable", equipmentIcon: "cable.connector"),
            PlanExercise(name: "Overhead Tricep Extension", muscle: "Triceps", sets: 3, repsMin: 10, repsMax: 12, equipment: "Cable", equipmentIcon: "cable.connector"),
        ],
        splitDays: [
            SplitDay(dayIndex: 0, name: "Push", isToday: true, isRest: false),
            SplitDay(dayIndex: 1, name: "Pull", isToday: false, isRest: false),
            SplitDay(dayIndex: 2, name: "Legs", isToday: false, isRest: false),
            SplitDay(dayIndex: 3, name: "Rest", isToday: false, isRest: true),
            SplitDay(dayIndex: 4, name: "Upper", isToday: false, isRest: false),
            SplitDay(dayIndex: 5, name: "Lower", isToday: false, isRest: false),
            SplitDay(dayIndex: 6, name: "Rest", isToday: false, isRest: true),
        ]
    )

    var nutrition: NutritionSnapshot = NutritionSnapshot(
        caloriesConsumed: 1420,
        caloriesTarget: 2200,
        proteinConsumed: 98,
        proteinTarget: 150
    )

    var activeProtocol: PeptideProtocol? = nil

    var pepInsight: String = "Your BPC-157 protocol is on day 14 — maintenance phase looking solid. Remember to rotate injection sites and stay hydrated for optimal absorption."

    var finnInsight: String { pepInsight }

    var activityFeed: [FriendActivity] = [
        FriendActivity(friendName: "Marcus", workoutName: "Leg Day Destroyer", fpEarned: 340, timeAgo: "25m ago", highFived: false),
        FriendActivity(friendName: "Sophia", workoutName: "Morning HIIT", fpEarned: 280, timeAgo: "1h ago", highFived: true),
        FriendActivity(friendName: "Jake", workoutName: "Upper Body Strength", fpEarned: 310, timeAgo: "2h ago", highFived: false),
        FriendActivity(friendName: "Aisha", workoutName: "Yoga Flow", fpEarned: 150, timeAgo: "3h ago", highFived: false),
    ]

    var quickStats: QuickStats {
        QuickStats(
            streakDays: streakManager.streakData.currentStreak,
            workoutsThisWeek: 4,
            leaderboardRank: 7
        )
    }

    // MARK: - Weekly Summary

    var weeklySummary: WeeklySummaryData {
        let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let workoutValues: [Double] = [1, 1, 0, 1, 1, 0, 1]
        let calorieValues: [Double] = [2150, 2080, 1950, 2200, 2100, 1800, 2050]
        let stepValues: [Double] = [8200, 10500, 6800, 9300, 11200, 5400, 7800]
        let proteinValues: [Double] = [135, 142, 118, 148, 140, 105, 130]

        return WeeklySummaryData(
            totalWorkouts: 5,
            totalCaloriesBurned: 2840,
            totalExerciseMinutes: 285,
            avgSteps: 8457,
            totalSteps: 59200,
            avgCaloriesConsumed: 2047,
            avgProtein: 131,
            avgSleepHours: 7.2,
            weightStart: 185.5,
            weightEnd: 184.3,
            dailyWorkouts: zip(dayLabels, workoutValues).map { DailyDataPoint(label: $0.0, value: $0.1) },
            dailyCalories: zip(dayLabels, calorieValues).map { DailyDataPoint(label: $0.0, value: $0.1) },
            dailySteps: zip(dayLabels, stepValues).map { DailyDataPoint(label: $0.0, value: $0.1) },
            dailyProtein: zip(dayLabels, proteinValues).map { DailyDataPoint(label: $0.0, value: $0.1) }
        )
    }

    // MARK: - Monthly Summary

    var monthlySummary: MonthlySummaryData {
        let weekLabels = ["Wk 1", "Wk 2", "Wk 3", "Wk 4"]
        let workoutValues: [Double] = [5, 4, 6, 5]
        let calorieValues: [Double] = [14200, 13800, 15100, 14500]
        let stepValues: [Double] = [62000, 58000, 71000, 59200]
        let weightValues: [Double] = [192.0, 189.2, 186.8, 184.3]

        return MonthlySummaryData(
            totalWorkouts: 20,
            totalCaloriesBurned: 11400,
            totalExerciseMinutes: 1140,
            avgStepsPerDay: 8340,
            avgCaloriesConsumed: 2050,
            avgProtein: 128,
            avgSleepHours: 7.0,
            weightStart: 192.0,
            weightEnd: 184.3,
            weeklyWorkouts: zip(weekLabels, workoutValues).map { DailyDataPoint(label: $0.0, value: $0.1) },
            weeklyCalories: zip(weekLabels, calorieValues).map { DailyDataPoint(label: $0.0, value: $0.1) },
            weeklySteps: zip(weekLabels, stepValues).map { DailyDataPoint(label: $0.0, value: $0.1) },
            weeklyWeight: zip(weekLabels, weightValues).map { DailyDataPoint(label: $0.0, value: $0.1) }
        )
    }

    var showStreakFreezeOffer: Bool {
        streakManager.streakData.missedYesterday && streakManager.streakData.streakFreezeAvailable && !streakManager.streakData.streakFreezeUsedThisWeek
    }

    var streakEncouragement: String? {
        streakManager.finnEncouragementMessage
    }

    func onAppear() {
        streakManager.checkAndHandleMissedDay()
        Task {
            _ = await notificationService.requestAuthorization()
        }
        if healthKit.isAvailable {
            Task {
                await healthKit.requestAuthorization()
                if healthKit.isAuthorized {
                    healthKit.startLiveStepStreaming()
                }
            }
        }
        if isLoading {
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    isLoading = false
                }
            }
        }
    }

    func refresh() async {
        if healthKit.isAuthorized {
            await healthKit.fetchAllData()
        }
        try? await Task.sleep(for: .seconds(1))
    }

    func useStreakFreeze() {
        _ = streakManager.useStreakFreeze()
    }

    func toggleHighFive(for activity: FriendActivity) {
        guard let index = activityFeed.firstIndex(where: { $0.id == activity.id }) else { return }
        let current = activityFeed[index]
        activityFeed[index] = FriendActivity(
            friendName: current.friendName,
            workoutName: current.workoutName,
            fpEarned: current.fpEarned,
            timeAgo: current.timeAgo,
            highFived: !current.highFived
        )
    }
}
