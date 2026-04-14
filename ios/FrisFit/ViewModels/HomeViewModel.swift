import SwiftUI
import Auth

@Observable
final class HomeViewModel {
    var dailyTasks: [DailyTask] = DailyTaskLibrary.defaultTasks()
    var protocolDeckFocus: String = ""
    var hasProtocolDeck: Bool = false
    private var lastProtocolDeckId: UUID?
    var customCategories: [CustomTaskCategory] = []
    var isLoading: Bool = true
    var taskSupabaseIds: [UUID: String] = [:]
    private var tasksLoaded: Bool = false
    var selectedDate: Date = Date()
    var selectedTimePeriod: HomeTimePeriod = .daily
    var isDateSelectorExpanded: Bool = false
    var isFullCalendarExpanded: Bool = false
    var selectedWeekStart: Date = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
    var selectedMonthDate: Date = Date()

    var userFirstName: String {
        if AuthService.shared.authState == .signedIn,
           let name = ProfileService.shared.cachedDisplayName, !name.isEmpty {
            return name.components(separatedBy: " ").first ?? name
        }
        return "there"
    }

    let streakManager = StreakManager.shared
    let notificationService = NotificationService.shared
    let healthKit = HealthKitService.shared

    var activeProgram: TrainingProgram? = nil
    private static let programKey = "savedActiveProgram"
    private static let programStartDayKey = "programStartDayOffset"

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

    var weekStripDays: [CalendarDay] {
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)) else { return [] }
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
            let isToday = calendar.isDateInToday(date)
            let hasActivity = streakManager.activityLog.contains { calendar.isDate($0.date, inSameDayAs: date) }
            return CalendarDay(date: date, isSelected: isSelected, isToday: isToday, hasActivity: hasActivity)
        }
    }

    func navigateWeekStrip(by offset: Int) {
        guard let newDate = calendar.date(byAdding: .weekOfYear, value: offset, to: selectedDate) else { return }
        selectedDate = newDate
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

    var todaysTasks: [DailyTask] {
        dailyTasks.filter { $0.isScheduledForToday() }
    }

    func todaysTasks(for category: TaskCategory) -> [DailyTask] {
        todaysTasks.filter { $0.category == category && $0.customCategoryId == nil }
    }

    func todaysTasks(forCustom categoryId: UUID) -> [DailyTask] {
        todaysTasks.filter { $0.customCategoryId == categoryId }
    }

    var completedCount: Int {
        todaysTasks.filter(\.isCompleted).count
    }

    func toggleTask(_ task: DailyTask) {
        guard let index = dailyTasks.firstIndex(where: { $0.id == task.id }) else { return }
        dailyTasks[index].isCompleted.toggle()
        let newState = dailyTasks[index].isCompleted
        if let supabaseId = taskSupabaseIds[task.id] {
            Task { try? await DailyTaskService.shared.toggleCompletion(taskId: supabaseId, isCompleted: newState) }
        }
    }

    func tasks(for category: TaskCategory) -> [DailyTask] {
        dailyTasks.filter { $0.category == category && $0.customCategoryId == nil }
    }

    func addCustomCategory(_ category: CustomTaskCategory) {
        customCategories.append(category)
    }

    func updateCustomCategory(_ category: CustomTaskCategory) {
        guard let index = customCategories.firstIndex(where: { $0.id == category.id }) else { return }
        customCategories[index] = category
    }

    func deleteCustomCategory(_ category: CustomTaskCategory) {
        dailyTasks.removeAll { $0.customCategoryId == category.id }
        customCategories.removeAll { $0.id == category.id }
    }

    func goalDisplayString(for link: TaskActionLink, target: Int) -> String? {
        guard link.hasCustomTarget else { return nil }
        let value = target > 0 ? target : defaultTarget(for: link)
        return "\(value.formatted()) \(link.targetUnit)"
    }

    func defaultTarget(for link: TaskActionLink) -> Int {
        switch link {
        case .stepCounter: return 10000
        case .proteinGoal: return nutrition.proteinTarget
        case .calorieGoal: return nutrition.caloriesTarget
        case .carbGoal: return 250
        case .fatGoal: return 70
        case .fiberGoal: return 30
        case .sugarGoal: return 50
        case .waterIntake: return 128
        default: return 0
        }
    }

    func addTask(_ task: DailyTask) {
        dailyTasks.append(task)
        persistTaskToSupabase(task)
    }

    private func persistTaskToSupabase(_ task: DailyTask) {
        guard AuthService.shared.authState == .signedIn else { return }
        Task {
            do {
                let userId = try AuthService.shared.currentUserId()
                let created = try await DailyTaskService.shared.createTask(userId: userId, task: task, date: Date())
                if let sid = created.id {
                    taskSupabaseIds[task.id] = sid
                }
            } catch {}
        }
    }

    func updateTask(_ task: DailyTask) {
        guard let index = dailyTasks.firstIndex(where: { $0.id == task.id }) else { return }
        let wasCompleted = dailyTasks[index].isCompleted
        dailyTasks[index] = task
        dailyTasks[index].isCompleted = wasCompleted
    }

    func deleteTask(_ task: DailyTask) {
        dailyTasks.removeAll { $0.id == task.id }
        if let supabaseId = taskSupabaseIds[task.id] {
            Task { try? await DailyTaskService.shared.deleteTask(taskId: supabaseId) }
            taskSupabaseIds.removeValue(forKey: task.id)
        }
    }

    func checkActionLinkedTasks() {
        let todayActivities = streakManager.activityLog.filter { Calendar.current.isDateInToday($0.date) }

        for index in dailyTasks.indices {
            let task = dailyTasks[index]
            guard !task.isCompleted, task.isScheduledForToday() else { continue }

            switch task.actionLink {
            case .none:
                break
            case .stepCounter:
                let goal = task.actionTarget > 0 ? task.actionTarget : 10000
                if healthKit.steps >= goal {
                    dailyTasks[index].isCompleted = true
                }
            case .proteinGoal:
                let target = task.actionTarget > 0 ? task.actionTarget : nutrition.proteinTarget
                if nutrition.proteinConsumed >= target {
                    dailyTasks[index].isCompleted = true
                }
            case .calorieGoal:
                let target = task.actionTarget > 0 ? task.actionTarget : nutrition.caloriesTarget
                if nutrition.caloriesConsumed >= target {
                    dailyTasks[index].isCompleted = true
                }
            case .carbGoal, .fatGoal, .fiberGoal, .sugarGoal:
                break
            case .workoutCompleted:
                if !healthKit.workoutsToday.isEmpty || todayActivities.contains(where: { $0.type == .workout }) {
                    dailyTasks[index].isCompleted = true
                }
            case .waterIntake:
                break
            case .runningSession:
                if todayActivities.contains(where: { $0.type == .sportSession && $0.sport == .running }) {
                    dailyTasks[index].isCompleted = true
                }
            case .cyclingSession:
                if todayActivities.contains(where: { $0.type == .sportSession && $0.sport == .cycling }) {
                    dailyTasks[index].isCompleted = true
                }
            case .swimmingSession:
                if todayActivities.contains(where: { $0.type == .sportSession && $0.sport == .swimming }) {
                    dailyTasks[index].isCompleted = true
                }
            case .basketballSession:
                if todayActivities.contains(where: { $0.type == .sportSession && $0.sport == .basketball }) {
                    dailyTasks[index].isCompleted = true
                }
            case .soccerSession:
                if todayActivities.contains(where: { $0.type == .sportSession && $0.sport == .soccer }) {
                    dailyTasks[index].isCompleted = true
                }
            case .tennisSession:
                if todayActivities.contains(where: { $0.type == .sportSession && $0.sport == .tennis }) {
                    dailyTasks[index].isCompleted = true
                }
            case .footballSession:
                if todayActivities.contains(where: { $0.type == .sportSession && $0.sport == .football }) {
                    dailyTasks[index].isCompleted = true
                }
            case .yogaSession:
                break
            }
        }
    }

    var isPlanExpanded: Bool = false
    var showEditSplit: Bool = false

    var todaysPlan: WorkoutPlan {
        buildWorkoutPlan(for: selectedDate)
    }

    var nutrition: NutritionSnapshot = NutritionSnapshot(
        caloriesConsumed: 1420,
        caloriesTarget: 2200,
        proteinConsumed: 98,
        proteinTarget: 150
    )

    var activeProtocol: PeptideProtocol? = nil
    var allProtocols: [PeptideProtocol] = []
    private var protocolsLoaded: Bool = false
    var protocolSaveError: String?

    var pepInsight: String = "Your BPC-157 protocol is on day 14 — maintenance phase looking solid. Remember to rotate injection sites and stay hydrated for optimal absorption."

    var finnInsight: String { pepInsight }

    var activityFeed: [FriendActivity] = [
        FriendActivity(friendName: "Marcus", workoutName: "Leg Day Destroyer", fpEarned: 340, timeAgo: "25m ago", liked: false),
        FriendActivity(friendName: "Sophia", workoutName: "Morning HIIT", fpEarned: 280, timeAgo: "1h ago", liked: true),
        FriendActivity(friendName: "Jake", workoutName: "Upper Body Strength", fpEarned: 310, timeAgo: "2h ago", liked: false),
        FriendActivity(friendName: "Aisha", workoutName: "Yoga Flow", fpEarned: 150, timeAgo: "3h ago", liked: false),
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
        loadActiveProgram()
        refreshUserName()
        streakManager.checkAndHandleMissedDay()
        streakManager.loadFromSupabase()
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
        checkActionLinkedTasks()
        if !protocolsLoaded {
            loadProtocolsFromSupabase()
        }
        if !tasksLoaded {
            loadTasksFromSupabase()
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

    func reloadActiveProgram() {
        loadActiveProgram()
    }

    private func loadActiveProgram() {
        guard let data = UserDefaults.standard.data(forKey: Self.programKey),
              let program = try? JSONDecoder().decode(TrainingProgram.self, from: data) else {
            activeProgram = nil
            return
        }
        activeProgram = program
    }

    private func programDayForDate(_ date: Date) -> ProgramDay? {
        guard let program = activeProgram else { return nil }
        let startOffset = UserDefaults.standard.integer(forKey: Self.programStartDayKey)
        let dayOfWeek = calendar.component(.weekday, from: date)
        let mondayBased = (dayOfWeek + 5) % 7
        let adjusted = (mondayBased - startOffset + 7) % 7
        guard adjusted < program.days.count else { return nil }
        return program.days[adjusted]
    }

    private func buildWorkoutPlan(for date: Date) -> WorkoutPlan {
        guard let program = activeProgram else {
            return WorkoutPlan(
                name: "No Active Program",
                exercises: 0,
                estimatedMinutes: 0,
                isRestDay: true,
                recoveryTip: "Set up a training program to see your daily plan here.",
                planExercises: [],
                splitDays: []
            )
        }

        let startOffset = UserDefaults.standard.integer(forKey: Self.programStartDayKey)
        let dayOfWeek = calendar.component(.weekday, from: date)
        let mondayBased = (dayOfWeek + 5) % 7
        let adjusted = (mondayBased - startOffset + 7) % 7

        let isRestDay = adjusted >= program.days.count
        let currentDay = isRestDay ? nil : program.days[adjusted]

        let planExercises: [PlanExercise] = (currentDay?.exercises ?? []).map { pe in
            PlanExercise(
                name: pe.exerciseName,
                muscle: pe.primaryMuscle.rawValue,
                sets: pe.targetSets,
                repsMin: pe.targetRepsMin,
                repsMax: pe.targetRepsMax,
                equipment: pe.equipment.rawValue,
                equipmentIcon: pe.equipment.icon
            )
        }

        let estimatedMinutes: Int
        if let day = currentDay {
            let totalSets = day.exercises.reduce(0) { $0 + $1.targetSets }
            estimatedMinutes = max(totalSets * 2 + day.exercises.count * 1, 15)
        } else {
            estimatedMinutes = 0
        }

        let splitDays: [SplitDay] = (0..<max(program.days.count + (7 - program.days.count), program.days.count)).prefix(7).enumerated().map { index, _ in
            let isTrainingDay = index < program.days.count
            let dayName = isTrainingDay ? program.days[index].name : "Rest"
            return SplitDay(
                dayIndex: index,
                name: dayName,
                isToday: index == adjusted,
                isRest: !isTrainingDay
            )
        }

        return WorkoutPlan(
            name: currentDay?.name ?? "Rest Day",
            exercises: currentDay?.exercises.count ?? 0,
            estimatedMinutes: estimatedMinutes,
            isRestDay: isRestDay,
            recoveryTip: isRestDay ? "Recovery is when your muscles grow. Stay hydrated and get quality sleep tonight." : nil,
            planExercises: planExercises,
            splitDays: splitDays
        )
    }

    func programDayForWeekday(_ weekdayIndex: Int) -> ProgramDay? {
        guard let program = activeProgram else { return nil }
        let startOffset = UserDefaults.standard.integer(forKey: Self.programStartDayKey)
        let adjusted = (weekdayIndex - startOffset + 7) % 7
        guard adjusted < program.days.count else { return nil }
        return program.days[adjusted]
    }

    func weekSchedule() -> [(dayLabel: String, programDay: ProgramDay?, isToday: Bool)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"

        guard let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedWeekStart)) else { return [] }

        return (0..<7).map { offset in
            let date = cal.date(byAdding: .day, value: offset, to: weekStart) ?? weekStart
            let dayOfWeek = cal.component(.weekday, from: date)
            let mondayBased = (dayOfWeek + 5) % 7
            let day = programDayForWeekday(mondayBased)
            let label = dayFormatter.string(from: date)
            let isTodayFlag = cal.isDate(date, inSameDayAs: today)
            return (dayLabel: label, programDay: day, isToday: isTodayFlag)
        }
    }

    func monthProgramSummary() -> (programName: String, daysPerWeek: Int, totalDays: Int, dayNames: [String])? {
        guard let program = activeProgram else { return nil }
        let names = program.days.map(\.name)
        let cal = Calendar.current
        let range = cal.range(of: .weekOfMonth, in: .month, for: selectedMonthDate) ?? (0..<4)
        let totalDays = range.count * program.daysPerWeek
        return (programName: program.name, daysPerWeek: program.daysPerWeek, totalDays: totalDays, dayNames: names)
    }

    func loadTasksFromSupabase() {
        guard AuthService.shared.authState == .signedIn else { return }
        tasksLoaded = true
        Task {
            do {
                let userId = try AuthService.shared.currentUserId()
                let tasks = try await DailyTaskService.shared.fetchTasks(userId: userId, date: Date())
                guard !tasks.isEmpty else { return }
                var idMap: [UUID: String] = [:]
                let converted = tasks.map { t -> DailyTask in
                    let dt = DailyTaskService.shared.toDailyTask(t)
                    if let sid = t.id {
                        idMap[dt.id] = sid
                    }
                    return dt
                }
                dailyTasks = converted
                taskSupabaseIds = idMap
            } catch {}
        }
    }

    func applyProtocolDeck() {
        guard let proto = activeProtocol else {
            if hasProtocolDeck {
                dailyTasks.removeAll { $0.isProtocolRecommended }
                hasProtocolDeck = false
                protocolDeckFocus = ""
                lastProtocolDeckId = nil
            }
            return
        }

        if lastProtocolDeckId == proto.id { return }
        lastProtocolDeckId = proto.id

        dailyTasks.removeAll { $0.isProtocolRecommended }

        let ctx = ProtocolDeckEngine.context(from: proto)
        let protocolTasks = ProtocolDeckEngine.generateTasks(for: ctx)
        protocolDeckFocus = ProtocolDeckEngine.deckFocusNote(for: ctx)
        hasProtocolDeck = true

        let existingNames = Set(dailyTasks.map { $0.name.lowercased() })
        let uniqueTasks = protocolTasks.filter { !existingNames.contains($0.name.lowercased()) }

        dailyTasks.insert(contentsOf: uniqueTasks, at: 0)
    }

    func loadProtocolsFromSupabase() {
        guard AuthService.shared.authState == .signedIn else {
            Task {
                try? await Task.sleep(for: .seconds(1))
                if AuthService.shared.authState == .signedIn, !protocolsLoaded {
                    loadProtocolsFromSupabase()
                }
            }
            return
        }
        protocolsLoaded = true
        Task {
            do {
                let protocols = try await ProtocolService.shared.fetchProtocols()
                allProtocols = protocols
                activeProtocol = protocols.first { $0.isActive }
                applyProtocolDeck()
            } catch {
                print("[HomeVM] Failed to load protocols: \(error)")
            }
        }
    }

    func saveProtocolToSupabase(_ proto: PeptideProtocol) {
        if proto.supabaseId != nil {
            activeProtocol = proto
            allProtocols.insert(proto, at: 0)
            applyProtocolDeck()
            return
        }
        guard AuthService.shared.authState == .signedIn else {
            activeProtocol = proto
            allProtocols.insert(proto, at: 0)
            applyProtocolDeck()
            return
        }
        Task {
            do {
                let saved = try await ProtocolService.shared.createProtocol(proto)
                activeProtocol = saved
                allProtocols.insert(saved, at: 0)
            } catch {
                print("[HomeVM] Failed to save protocol: \(error)")
                var localProto = proto
                localProto.supabaseId = nil
                activeProtocol = localProto
                allProtocols.insert(localProto, at: 0)
                protocolSaveError = error.localizedDescription
            }
        }
    }

    func refreshUserName() {
        guard AuthService.shared.authState == .signedIn,
              let session = AuthService.shared.session else { return }
        let userId = session.user.id.uuidString
        Task {
            let profile = try? await ProfileService.shared.fetchProfile(userId: userId)
            _ = profile
        }
    }

    func refresh() async {
        if healthKit.isAuthorized {
            await healthKit.fetchAllData()
        }
        refreshUserName()
        checkActionLinkedTasks()
        protocolsLoaded = false
        loadProtocolsFromSupabase()
        try? await Task.sleep(for: .seconds(1))
    }

    func useStreakFreeze() {
        _ = streakManager.useStreakFreeze()
    }

    func toggleLike(for activity: FriendActivity) {
        guard let index = activityFeed.firstIndex(where: { $0.id == activity.id }) else { return }
        let current = activityFeed[index]
        activityFeed[index] = FriendActivity(
            friendName: current.friendName,
            workoutName: current.workoutName,
            fpEarned: current.fpEarned,
            timeAgo: current.timeAgo,
            liked: !current.liked
        )
    }
}
