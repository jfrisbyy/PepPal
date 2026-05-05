import SwiftUI
import HealthKit
import Auth

@Observable
final class HomeViewModel {
    var dailyTasks: [DailyTask] = DailyTaskLibrary.defaultTasks()
    var aiActionItems: [PlanActionItem] = []
    var aiDeckSuggestions: [AIDeckSuggestion] = []
    var aiDeckPeriod: DeckRefreshPeriod = .morning
    var aiDeckGeneratedAt: Date?
    var aiDeckIsGenerating: Bool = false
    private var aiDeckLastRun: [DeckRefreshPeriod: Date] = [:]
    var completedSyntheticIds: Set<UUID> = []
    var protocolDeckFocus: String = ""
    var hasProtocolDeck: Bool = false
    private var lastProtocolDeckId: UUID?
    var customCategories: [CustomTaskCategory] = []
    var isLoading: Bool = true
    var taskSupabaseIds: [UUID: String] = [:]
    private var tasksLoaded: Bool = false
    var selectedDate: Date = Date() {
        didSet {
            NutritionViewModel.shared.selectedDate = selectedDate
            Task { await NutritionViewModel.shared.loadFromSupabaseAsync(date: selectedDate) }
            Task { await healthKit.fetchAllData(for: selectedDate) }
        }
    }
    var selectedTimePeriod: HomeTimePeriod = .daily {
        didSet {
            if selectedTimePeriod == .weekly { Task { await loadWeeklyHistory() } }
            if selectedTimePeriod == .monthly { Task { await loadMonthlyHistory() } }
        }
    }
    var isDateSelectorExpanded: Bool = false
    var isFullCalendarExpanded: Bool = false
    var selectedWeekStart: Date = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date() {
        didSet { Task { await loadWeeklyHistory() } }
    }
    var selectedMonthDate: Date = Date() {
        didSet { Task { await loadMonthlyHistory() } }
    }

    // MARK: - Historical data caches (keyed by startOfDay)
    var stepsByDay: [Date: Int] = [:]
    var caloriesBurnedByDay: [Date: Double] = [:]
    var exerciseMinutesByDay: [Date: Double] = [:]
    var sleepHoursByDay: [Date: Double] = [:]
    private var loadedRanges: Set<String> = []

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
    var allActivePrograms: [TrainingProgram] = []
    private static let programKey = "savedActiveProgram"
    private static let programStartDayKey = "programStartDayOffset"
    private static let allProgramsKey = "savedAllPrograms"
    private static let displayedProgramIdKey = "displayedActiveProgramId"
    private static let multiActiveKey = "multiActiveProgramsEnabled"
    private static let showAllActiveKey = "showAllActiveProgramsOnToday"

    var multiActiveEnabled: Bool = UserDefaults.standard.bool(forKey: "multiActiveProgramsEnabled")

    var showAllActiveOnToday: Bool = UserDefaults.standard.bool(forKey: "showAllActiveProgramsOnToday") {
        didSet { UserDefaults.standard.set(showAllActiveOnToday, forKey: Self.showAllActiveKey) }
    }

    var hasMultipleActivePrograms: Bool {
        allActivePrograms.count > 1
    }

    var todaysPlans: [(program: TrainingProgram, plan: WorkoutPlan)] {
        let programs: [TrainingProgram]
        if multiActiveEnabled && showAllActiveOnToday && allActivePrograms.count > 1 {
            programs = allActivePrograms
        } else if let p = activeProgram {
            programs = [p]
        } else {
            programs = []
        }
        return programs.map { ($0, buildWorkoutPlan(for: selectedDate, program: $0)) }
    }

    func selectDisplayedProgram(_ id: UUID) {
        guard let program = allActivePrograms.first(where: { $0.id == id }) else { return }
        activeProgram = program
        UserDefaults.standard.set(id.uuidString, forKey: Self.displayedProgramIdKey)
        if let data = try? JSONEncoder().encode(program) {
            UserDefaults.standard.set(data, forKey: Self.programKey)
        }
    }

    func toggleShowAllActive() {
        showAllActiveOnToday.toggle()
    }

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
        let nvm = NutritionViewModel.shared
        return NutritionSnapshot(
            caloriesConsumed: nvm.totalCalories(for: selectedDate),
            caloriesTarget: nutrition.caloriesTarget,
            proteinConsumed: Int(nvm.totalProtein(for: selectedDate)),
            proteinTarget: nutrition.proteinTarget
        )
    }

    var todaysTasks: [DailyTask] {
        let userTasks = dailyTasks.filter { $0.isScheduledForToday() }
        let activeProtos = allProtocols.filter { $0.isActive }
        let workoutDone = healthKit.workoutsToday.isEmpty == false ||
            streakManager.activityLog.contains { Calendar.current.isDateInToday($0.date) && $0.type == .workout }
        let inputs = SmartDailyTasksAssembler.Inputs(
            userTasks: userTasks,
            activeProtocols: activeProtos,
            activeProgram: activeProgram,
            todaysWorkoutPlan: todaysPlan,
            workoutCompletedToday: workoutDone,
            proteinTarget: NutritionViewModel.shared.dailyTarget.protein,
            calorieTarget: NutritionViewModel.shared.dailyTarget.calories,
            proteinConsumed: Int(NutritionViewModel.shared.totalProtein),
            caloriesConsumed: NutritionViewModel.shared.totalCalories,
            stepGoal: 10000,
            stepsToday: healthKit.steps,
            waterTarget: 0,
            aiActionItems: aiActionItems,
            aiDeckSuggestions: aiDeckSuggestions,
            completedSyntheticIds: completedSyntheticIds
        )
        return SmartDailyTasksAssembler.assemble(inputs)
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
        if task.source.isSynthetic {
            let wasCompleted = completedSyntheticIds.contains(task.id)
            if wasCompleted {
                completedSyntheticIds.remove(task.id)
            } else {
                completedSyntheticIds.insert(task.id)
                if task.source == .aiSuggested {
                    AILearningStore.shared.recordCompletion(task: task)
                }
            }
            return
        }
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

    var hasProtocolButNoProgram: Bool {
        activeProtocol != nil && activeProgram == nil
    }

    var trainingRecommendation: (title: String, message: String, icon: String)? {
        guard let proto = activeProtocol, activeProgram == nil else { return nil }
        let compoundName = proto.compounds.first?.compoundName ?? proto.name
        switch proto.goal {
        case .weightLoss:
            return (
                title: "Resistance Training Recommended",
                message: "On \(compoundName), resistance training is critical to preserve muscle while losing fat. Even 3 days a week makes a significant difference.",
                icon: "figure.strengthtraining.traditional"
            )
        case .muscleGrowth:
            return (
                title: "Training Program Needed",
                message: "\(compoundName) works best paired with a structured hypertrophy program. You're leaving gains on the table without one.",
                icon: "dumbbell.fill"
            )
        case .healing:
            return (
                title: "Light Movement Helps Recovery",
                message: "Gentle mobility work and light resistance training can complement your \(compoundName) protocol and accelerate healing.",
                icon: "figure.walk"
            )
        default:
            return (
                title: "Add a Training Program",
                message: "Pairing \(compoundName) with a structured training program will help you get the most out of your protocol.",
                icon: "figure.strengthtraining.traditional"
            )
        }
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

    var pepInsight: String {
        if let proto = activeProtocol {
            let day = proto.currentDay
            let phase = proto.currentPhase.rawValue
            let compound = proto.compounds.first?.compoundName ?? proto.name
            let store = InsightsDataStore.shared
            if let low = store.lowStockForecasts.first {
                return "\(compound) day \(day), \(phase.lowercased()) phase. Heads up: \(low.compoundName) — \(low.chipLabel.lowercased())."
            }
            if let corr = store.sleepCorrelation, corr.severity == .warn {
                return "\(compound) day \(day), \(phase.lowercased()) phase. \(corr.insight)"
            }
            return "\(compound) protocol is on day \(day) — \(phase.lowercased()) phase looking solid. Rotate injection sites and stay hydrated."
        }
        return "Set up a protocol to unlock personalized peptide insights."
    }

    var finnInsight: String { pepInsight }

    var activityFeed: [FriendActivity] = [
        FriendActivity(friendName: "Marcus", workoutName: "Leg Day Destroyer", timeAgo: "25m ago", liked: false),
        FriendActivity(friendName: "Sophia", workoutName: "Morning HIIT", timeAgo: "1h ago", liked: true),
        FriendActivity(friendName: "Jake", workoutName: "Upper Body Strength", timeAgo: "2h ago", liked: false),
        FriendActivity(friendName: "Aisha", workoutName: "Yoga Flow", timeAgo: "3h ago", liked: false),
    ]

    var quickStats: QuickStats {
        let calendar = Calendar.current
        let thisWeek = streakManager.activityLog.filter {
            $0.type == .workout && calendar.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear)
        }.count
        return QuickStats(
            streakDays: streakManager.streakData.currentStreak,
            workoutsThisWeek: thisWeek,
            leaderboardRank: 0
        )
    }

    // MARK: - Weekly Summary

    var weeklySummary: WeeklySummaryData {
        let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let cal = Calendar.current
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedWeekStart)) ?? selectedWeekStart
        let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }

        let store = InsightsDataStore.shared
        let activities = streakManager.activityLog
        let nvm = NutritionViewModel.shared

        var workoutValues: [Double] = []
        var calorieValues: [Double] = []
        var stepValues: [Double] = []
        var proteinValues: [Double] = []
        var burnValues: [Double] = []
        var minutesValues: [Double] = []
        var sleepValues: [Double] = []
        var weightValues: [Double] = []

        let today = cal.startOfDay(for: Date())
        for day in days {
            let dayKey = cal.startOfDay(for: day)
            let wCount = activities.filter { $0.type == .workout && cal.isDate($0.date, inSameDayAs: day) }.count
            workoutValues.append(Double(wCount))

            let cachedMeals = store.recentMealsByDay[dayKey] ?? []
            let nvmMeals = nvm.meals(for: day)
            let mealsForDay = nvmMeals.isEmpty ? cachedMeals : nvmMeals
            let cals = mealsForDay.reduce(0) { $0 + $1.totalCalories }
            let protein = mealsForDay.reduce(0.0) { $0 + $1.totalProtein }
            calorieValues.append(Double(cals))
            proteinValues.append(protein)

            // Use cached HK history; fall back to today's live values when day == today.
            if let s = stepsByDay[dayKey] {
                stepValues.append(Double(s))
            } else if dayKey == today {
                stepValues.append(Double(healthKit.steps))
            } else {
                stepValues.append(0)
            }
            if let b = caloriesBurnedByDay[dayKey] {
                burnValues.append(b)
            } else if dayKey == today {
                burnValues.append(healthKit.activeCalories)
            } else {
                burnValues.append(0)
            }
            if let m = exerciseMinutesByDay[dayKey] {
                minutesValues.append(m)
            } else if dayKey == today {
                minutesValues.append(healthKit.exerciseMinutes)
            } else {
                minutesValues.append(0)
            }
            if let s = sleepHoursByDay[dayKey] {
                sleepValues.append(s)
            } else if dayKey == today {
                sleepValues.append(healthKit.sleepHours)
            } else {
                sleepValues.append(0)
            }

            // Latest weight on or before this day.
            let entriesUpToDay = store.weightEntries.filter { $0.date <= cal.date(byAdding: .day, value: 1, to: day) ?? day }
            weightValues.append(entriesUpToDay.last?.weight ?? store.startingWeight)
        }

        let totalWorkouts = Int(workoutValues.reduce(0, +))
        let nonZeroCal = calorieValues.filter { $0 > 0 }
        let avgCal = nonZeroCal.isEmpty ? 0 : Int(nonZeroCal.reduce(0, +) / Double(nonZeroCal.count))
        let nonZeroProt = proteinValues.filter { $0 > 0 }
        let avgProtein = nonZeroProt.isEmpty ? 0 : Int(nonZeroProt.reduce(0, +) / Double(nonZeroProt.count))
        let nonZeroSleep = sleepValues.filter { $0 > 0 }
        let avgSleep = nonZeroSleep.isEmpty ? 0 : nonZeroSleep.reduce(0, +) / Double(nonZeroSleep.count)
        let nonZeroSteps = stepValues.filter { $0 > 0 }
        let avgSteps = nonZeroSteps.isEmpty ? 0 : Int(nonZeroSteps.reduce(0, +) / Double(nonZeroSteps.count))
        let totalSteps = Int(stepValues.reduce(0, +))
        let totalBurn = Int(burnValues.reduce(0, +))
        let totalMinutes = Int(minutesValues.reduce(0, +))
        let daysWithFood = nonZeroCal.count
        let daysWithSleep = nonZeroSleep.count

        let weekWeights = store.weightEntries.filter { entry in
            days.contains { cal.isDate(entry.date, inSameDayAs: $0) }
        }
        let weightStart = weekWeights.first?.weight
            ?? weightValues.first(where: { $0 > 0 })
            ?? store.weightEntries.last?.weight
            ?? 0
        let weightEnd = weekWeights.last?.weight
            ?? weightValues.last(where: { $0 > 0 })
            ?? weightStart

        let stepGoal = 10000
        let proteinGoal = NutritionViewModel.shared.dailyTarget.protein
        let calorieGoal = NutritionViewModel.shared.dailyTarget.calories
        let workoutGoal = activeProgram?.daysPerWeek ?? 4

        return WeeklySummaryData(
            totalWorkouts: totalWorkouts,
            totalCaloriesBurned: totalBurn,
            totalExerciseMinutes: totalMinutes,
            avgSteps: avgSteps,
            totalSteps: totalSteps,
            avgCaloriesConsumed: avgCal,
            avgProtein: avgProtein,
            avgSleepHours: avgSleep,
            weightStart: weightStart,
            weightEnd: weightEnd,
            dailyWorkouts: zip(dayLabels, workoutValues).map { DailyDataPoint(label: $0.0, value: $0.1) },
            dailyCalories: zip(dayLabels, calorieValues).map { DailyDataPoint(label: $0.0, value: $0.1) },
            dailySteps: zip(dayLabels, stepValues).map { DailyDataPoint(label: $0.0, value: $0.1) },
            dailyProtein: zip(dayLabels, proteinValues).map { DailyDataPoint(label: $0.0, value: $0.1) },
            dailyCaloriesBurned: zip(dayLabels, burnValues).map { DailyDataPoint(label: $0.0, value: $0.1) },
            dailyExerciseMinutes: zip(dayLabels, minutesValues).map { DailyDataPoint(label: $0.0, value: $0.1) },
            dailySleep: zip(dayLabels, sleepValues).map { DailyDataPoint(label: $0.0, value: $0.1) },
            dailyWeight: zip(dayLabels, weightValues).map { DailyDataPoint(label: $0.0, value: $0.1) },
            stepGoal: stepGoal,
            proteinGoal: proteinGoal,
            calorieGoal: calorieGoal,
            workoutGoal: workoutGoal,
            daysWithFood: daysWithFood,
            daysWithSleep: daysWithSleep
        )
    }

    // MARK: - Historical loaders

    func loadWeeklyHistory(force: Bool = false) async {
        let cal = Calendar.current
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedWeekStart)) ?? selectedWeekStart
        let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        let key = "week-\(Int(weekStart.timeIntervalSince1970))"
        if !force && loadedRanges.contains(key) { return }
        await loadHistoryRange(start: weekStart, end: weekEnd)
        loadedRanges.insert(key)
        await loadMealsForRange(start: weekStart, end: weekEnd)
    }

    func loadMonthlyHistory(force: Bool = false) async {
        let cal = Calendar.current
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: selectedMonthDate)) ?? selectedMonthDate
        let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        let key = "month-\(Int(monthStart.timeIntervalSince1970))"
        if !force && loadedRanges.contains(key) { return }
        await loadHistoryRange(start: monthStart, end: monthEnd)
        loadedRanges.insert(key)
        await loadMealsForRange(start: monthStart, end: monthEnd)
    }

    private func loadHistoryRange(start: Date, end: Date) async {
        guard healthKit.isAvailable, healthKit.isAuthorized else { return }
        async let stepsTask = healthKit.fetchDailySumSeries(for: .stepCount, unit: .count(), start: start, end: end)
        async let burnTask = healthKit.fetchDailySumSeries(for: .activeEnergyBurned, unit: .kilocalorie(), start: start, end: end)
        async let minutesTask = healthKit.fetchDailySumSeries(for: .appleExerciseTime, unit: .minute(), start: start, end: end)
        async let sleepTask = healthKit.fetchSleepHistory(start: start, end: end)
        let (steps, burn, minutes, sleep) = await (stepsTask, burnTask, minutesTask, sleepTask)
        let cal = Calendar.current
        for entry in steps {
            stepsByDay[cal.startOfDay(for: entry.date)] = Int(entry.value)
        }
        for entry in burn {
            caloriesBurnedByDay[cal.startOfDay(for: entry.date)] = entry.value
        }
        for entry in minutes {
            exerciseMinutesByDay[cal.startOfDay(for: entry.date)] = entry.value
        }
        for entry in sleep {
            sleepHoursByDay[cal.startOfDay(for: entry.date)] = entry.asleepHours
        }
    }

    private func loadMealsForRange(start: Date, end: Date) async {
        guard AuthService.shared.authState == .signedIn else { return }
        let cal = Calendar.current
        var date = cal.startOfDay(for: start)
        let stop = cal.startOfDay(for: end)
        while date < stop {
            await NutritionViewModel.shared.loadFromSupabaseAsync(date: date)
            guard let next = cal.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
    }

    // MARK: - Monthly Summary

    var monthlySummary: MonthlySummaryData {
        let cal = Calendar.current
        let store = InsightsDataStore.shared
        let activities = streakManager.activityLog
        let nvm = NutritionViewModel.shared

        // Anchor to the start of the selected month.
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: selectedMonthDate)) ?? selectedMonthDate
        let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        let totalDaysInMonth = cal.range(of: .day, in: .month, for: monthStart)?.count ?? 30

        // Determine week buckets that span the month (5 buckets covers any month).
        let weekCount = 5
        var weekLabels: [String] = []
        var workoutValues: [Double] = []
        var calorieValues: [Double] = []
        var stepValues: [Double] = []
        var burnValues: [Double] = []
        var minutesValues: [Double] = []
        var sleepValues: [Double] = []
        var weightValues: [Double] = []

        let today = cal.startOfDay(for: Date())
        var allDailySteps: [(date: Date, steps: Int)] = []

        for weekIdx in 0..<weekCount {
            guard let weekStart = cal.date(byAdding: .weekOfYear, value: weekIdx, to: monthStart) else { continue }
            guard let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart) else { continue }
            if weekStart >= monthEnd { break }
            weekLabels.append("Wk \(weekIdx + 1)")

            let wCount = activities.filter {
                $0.type == .workout && $0.date >= weekStart && $0.date < weekEnd
            }.count
            workoutValues.append(Double(wCount))

            let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }.filter { $0 < monthEnd }

            // Calories consumed: avg/day across days with food.
            var cals: [Double] = []
            for d in days {
                let cached = store.recentMealsByDay[cal.startOfDay(for: d)] ?? []
                let live = nvm.meals(for: d)
                let m = live.isEmpty ? cached : live
                let total = m.reduce(0) { $0 + $1.totalCalories }
                if total > 0 { cals.append(Double(total)) }
            }
            calorieValues.append(cals.isEmpty ? 0 : cals.reduce(0, +) / Double(cals.count))

            // Steps: total across week (chart shows weekly total)
            var weekSteps: Double = 0
            for d in days {
                let key = cal.startOfDay(for: d)
                let s = stepsByDay[key] ?? (key == today ? healthKit.steps : 0)
                weekSteps += Double(s)
                allDailySteps.append((date: key, steps: s))
            }
            stepValues.append(weekSteps)

            // Calories burned & exercise minutes (totals)
            var weekBurn: Double = 0
            var weekMinutes: Double = 0
            for d in days {
                let key = cal.startOfDay(for: d)
                weekBurn += caloriesBurnedByDay[key] ?? (key == today ? healthKit.activeCalories : 0)
                weekMinutes += exerciseMinutesByDay[key] ?? (key == today ? healthKit.exerciseMinutes : 0)
            }
            burnValues.append(weekBurn)
            minutesValues.append(weekMinutes)

            // Sleep avg per night that week
            var sleepNights: [Double] = []
            for d in days {
                let key = cal.startOfDay(for: d)
                if let s = sleepHoursByDay[key], s > 0 { sleepNights.append(s) }
                else if key == today, healthKit.sleepHours > 0 { sleepNights.append(healthKit.sleepHours) }
            }
            sleepValues.append(sleepNights.isEmpty ? 0 : sleepNights.reduce(0, +) / Double(sleepNights.count))

            let weekWeights = store.weightEntries.filter { $0.date >= weekStart && $0.date < weekEnd }
            weightValues.append(weekWeights.last?.weight ?? store.weightEntries.last(where: { $0.date < weekEnd })?.weight ?? 0)
        }

        let totalWorkouts = Int(workoutValues.reduce(0, +))
        let nonZeroCal = calorieValues.filter { $0 > 0 }
        let avgCal = nonZeroCal.isEmpty ? 0 : Int(nonZeroCal.reduce(0, +) / Double(nonZeroCal.count))
        let totalSteps = stepValues.reduce(0, +)
        let daysObserved = max(allDailySteps.filter { $0.steps > 0 }.count, 1)
        let avgStepsPerDay = Int(totalSteps / Double(daysObserved))
        let totalBurn = Int(burnValues.reduce(0, +))
        let totalMinutes = Int(minutesValues.reduce(0, +))
        let nonZeroSleep = sleepValues.filter { $0 > 0 }
        let avgSleep = nonZeroSleep.isEmpty ? 0 : nonZeroSleep.reduce(0, +) / Double(nonZeroSleep.count)

        // Protein avg/day across the month
        var proteinDays: [Double] = []
        var date = monthStart
        while date < monthEnd {
            let cached = store.recentMealsByDay[cal.startOfDay(for: date)] ?? []
            let live = nvm.meals(for: date)
            let m = live.isEmpty ? cached : live
            let p = m.reduce(0.0) { $0 + $1.totalProtein }
            if p > 0 { proteinDays.append(p) }
            guard let next = cal.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        let avgProtein = proteinDays.isEmpty ? 0 : Int(proteinDays.reduce(0, +) / Double(proteinDays.count))

        let weightStart = weightValues.first(where: { $0 > 0 }) ?? store.startingWeight
        let weightEnd = weightValues.last(where: { $0 > 0 }) ?? store.weightEntries.last?.weight ?? 0

        // Best step day & streak
        let bestDay = allDailySteps.max(by: { $0.steps < $1.steps })
        let stepGoal = 10000
        var streak = 0
        var maxStreak = 0
        for entry in allDailySteps.sorted(by: { $0.date < $1.date }) {
            if entry.steps >= stepGoal {
                streak += 1
                maxStreak = max(maxStreak, streak)
            } else {
                streak = 0
            }
        }

        let activeDays = Set(activities.filter { $0.date >= monthStart && $0.date < monthEnd }.map { cal.startOfDay(for: $0.date) }).count

        return MonthlySummaryData(
            totalWorkouts: totalWorkouts,
            totalCaloriesBurned: totalBurn,
            totalExerciseMinutes: totalMinutes,
            avgStepsPerDay: avgStepsPerDay,
            avgCaloriesConsumed: avgCal,
            avgProtein: avgProtein,
            avgSleepHours: avgSleep,
            weightStart: weightStart,
            weightEnd: weightEnd,
            weeklyWorkouts: zip(weekLabels, workoutValues).map { DailyDataPoint(label: $0.0, value: $0.1) },
            weeklyCalories: zip(weekLabels, calorieValues).map { DailyDataPoint(label: $0.0, value: $0.1) },
            weeklySteps: zip(weekLabels, stepValues).map { DailyDataPoint(label: $0.0, value: $0.1) },
            weeklyWeight: zip(weekLabels, weightValues).map { DailyDataPoint(label: $0.0, value: $0.1) },
            weeklyExerciseMinutes: zip(weekLabels, minutesValues).map { DailyDataPoint(label: $0.0, value: $0.1) },
            weeklyCaloriesBurned: zip(weekLabels, burnValues).map { DailyDataPoint(label: $0.0, value: $0.1) },
            weeklySleep: zip(weekLabels, sleepValues).map { DailyDataPoint(label: $0.0, value: $0.1) },
            totalDays: totalDaysInMonth,
            activeDays: activeDays,
            bestStepDay: bestDay.map { (date: $0.date, steps: $0.steps) },
            bestStepStreak: maxStreak,
            stepGoal: stepGoal
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
                if healthKit.isHealthKitEnabled {
                    await healthKit.resumeIfAuthorized()
                } else {
                    await healthKit.requestAuthorization()
                }
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

    func setMultiActiveEnabled(_ enabled: Bool) {
        multiActiveEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.multiActiveKey)
    }

    private func loadActiveProgram() {
        // Load full library to derive active programs.
        var allPrograms: [TrainingProgram] = []
        if let data = UserDefaults.standard.data(forKey: Self.allProgramsKey),
           let decoded = try? JSONDecoder().decode([TrainingProgram].self, from: data) {
            allPrograms = decoded
        }
        allActivePrograms = allPrograms.filter { $0.isActive }

        // Pick the displayed program: previously chosen, else stored single, else first active.
        var displayed: TrainingProgram? = nil
        if let idStr = UserDefaults.standard.string(forKey: Self.displayedProgramIdKey),
           let uuid = UUID(uuidString: idStr),
           let match = allActivePrograms.first(where: { $0.id == uuid }) {
            displayed = match
        }
        if displayed == nil,
           let data = UserDefaults.standard.data(forKey: Self.programKey),
           let program = try? JSONDecoder().decode(TrainingProgram.self, from: data) {
            // Prefer the stored one if it is currently active; otherwise fall back to first active.
            if program.isActive || allActivePrograms.isEmpty {
                displayed = program
            } else {
                displayed = allActivePrograms.first ?? program
            }
        }
        if displayed == nil {
            displayed = allActivePrograms.first
        }
        activeProgram = displayed
        if allActivePrograms.isEmpty, displayed == nil {
            // No active programs at all.
            return
        }
    }

    private func programDayForDate(_ date: Date) -> ProgramDay? {
        programDaysForDate(date).first
    }

    private func programDaysForDate(_ date: Date) -> [ProgramDay] {
        guard let program = activeProgram else { return [] }
        let dayOfWeek = calendar.component(.weekday, from: date)
        let mondayBased = (dayOfWeek + 5) % 7
        if program.days.contains(where: { $0.scheduledWeekday != nil }) {
            let matches = program.days.filter { $0.scheduledWeekday == mondayBased }
            return matches.sorted { ($0.timeOfDay?.sortOrder ?? 0) < ($1.timeOfDay?.sortOrder ?? 0) }
        }
        let startOffset = UserDefaults.standard.integer(forKey: Self.programStartDayKey)
        let adjusted = (mondayBased - startOffset + 7) % 7
        guard adjusted < program.days.count else { return [] }
        return [program.days[adjusted]]
    }

    private func buildWorkoutPlan(for date: Date) -> WorkoutPlan {
        buildWorkoutPlan(for: date, program: activeProgram)
    }

    private func buildWorkoutPlan(for date: Date, program: TrainingProgram?) -> WorkoutPlan {
        guard let program = program else {
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

        let dayOfWeek = calendar.component(.weekday, from: date)
        let mondayBased = (dayOfWeek + 5) % 7
        let usesScheduledWeekdays = program.days.contains(where: { $0.scheduledWeekday != nil })
        let startOffset = UserDefaults.standard.integer(forKey: Self.programStartDayKey)
        let adjusted = (mondayBased - startOffset + 7) % 7

        let currentDay: ProgramDay?
        if usesScheduledWeekdays {
            currentDay = program.days.first { $0.scheduledWeekday == mondayBased }
        } else {
            currentDay = adjusted < program.days.count ? program.days[adjusted] : nil
        }
        let isRestDay = currentDay == nil

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

        let splitDays: [SplitDay]
        if usesScheduledWeekdays {
            splitDays = (0..<7).map { weekdayIndex in
                let day = program.days.first { $0.scheduledWeekday == weekdayIndex }
                let label = ProgramWeekday(rawValue: weekdayIndex)?.singleLetter ?? ""
                return SplitDay(
                    dayIndex: weekdayIndex,
                    name: day?.name ?? label,
                    isToday: weekdayIndex == mondayBased,
                    isRest: day == nil
                )
            }
        } else {
            splitDays = (0..<7).map { index in
                let isTrainingDay = index < program.days.count
                let dayName = isTrainingDay ? program.days[index].name : "Rest"
                return SplitDay(
                    dayIndex: index,
                    name: dayName,
                    isToday: index == adjusted,
                    isRest: !isTrainingDay
                )
            }
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
        programDaysForWeekday(weekdayIndex).first
    }

    func programDaysForWeekday(_ weekdayIndex: Int) -> [ProgramDay] {
        guard let program = activeProgram else { return [] }
        if program.days.contains(where: { $0.scheduledWeekday != nil }) {
            let matches = program.days.filter { $0.scheduledWeekday == weekdayIndex }
            return matches.sorted { ($0.timeOfDay?.sortOrder ?? 0) < ($1.timeOfDay?.sortOrder ?? 0) }
        }
        let startOffset = UserDefaults.standard.integer(forKey: Self.programStartDayKey)
        let adjusted = (weekdayIndex - startOffset + 7) % 7
        guard adjusted < program.days.count else { return [] }
        return [program.days[adjusted]]
    }

    func weekSchedule() -> [(dayLabel: String, programDay: ProgramDay?, isToday: Bool)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"

        guard let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedWeekStart)) else { return [] }

        var rows: [(dayLabel: String, programDay: ProgramDay?, isToday: Bool)] = []
        for offset in 0..<7 {
            let date = cal.date(byAdding: .day, value: offset, to: weekStart) ?? weekStart
            let dayOfWeek = cal.component(.weekday, from: date)
            let mondayBased = (dayOfWeek + 5) % 7
            let days = programDaysForWeekday(mondayBased)
            let label = dayFormatter.string(from: date)
            let isTodayFlag = cal.isDate(date, inSameDayAs: today)
            if days.isEmpty {
                rows.append((dayLabel: label, programDay: nil, isToday: isTodayFlag))
            } else {
                for (i, d) in days.enumerated() {
                    rows.append((dayLabel: i == 0 ? label : "", programDay: d, isToday: isTodayFlag))
                }
            }
        }
        return rows
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
                for p in protocols where p.isActive {
                    applyTitrationStepIfNeeded(protocolId: p.id)
                }
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
                applyProtocolDeck()
            } catch {
                print("[HomeVM] Failed to save protocol: \(error)")
                var localProto = proto
                localProto.supabaseId = nil
                activeProtocol = localProto
                allProtocols.insert(localProto, at: 0)
                applyProtocolDeck()
                protocolSaveError = error.localizedDescription
            }
        }
    }

    func setActiveProtocol(_ proto: PeptideProtocol) {
        activeProtocol = proto
        if let idx = allProtocols.firstIndex(where: { $0.id == proto.id }) {
            var updated = allProtocols
            let moved = updated.remove(at: idx)
            updated.insert(moved, at: 0)
            allProtocols = updated
        }
        applyProtocolDeck()
    }

    func archiveProtocolFromHome(_ proto: PeptideProtocol) {
        if let idx = allProtocols.firstIndex(where: { $0.id == proto.id }) {
            allProtocols[idx].isActive = false
        }
        if activeProtocol?.id == proto.id {
            activeProtocol = allProtocols.first { $0.isActive }
            lastProtocolDeckId = nil
            applyProtocolDeck()
        }
        if let sid = proto.supabaseId {
            Task {
                try? await ProtocolService.shared.updateProtocolStatus(id: sid, isActive: false)
            }
        }
    }

    func reactivateProtocolFromHome(_ proto: PeptideProtocol) {
        if let idx = allProtocols.firstIndex(where: { $0.id == proto.id }) {
            allProtocols[idx].isActive = true
        }
        var updated = proto
        updated.isActive = true
        setActiveProtocol(updated)
        if let sid = proto.supabaseId {
            Task {
                try? await ProtocolService.shared.updateProtocolStatus(id: sid, isActive: true)
            }
        }
    }

    func deleteProtocolFromHome(_ proto: PeptideProtocol) {
        allProtocols.removeAll { $0.id == proto.id }
        if activeProtocol?.id == proto.id {
            activeProtocol = allProtocols.first { $0.isActive }
            lastProtocolDeckId = nil
            applyProtocolDeck()
        }
        if let sid = proto.supabaseId {
            Task {
                try? await ProtocolService.shared.deleteProtocol(id: sid)
            }
        }
    }

    func applyTitrationStepIfNeeded(protocolId: UUID) {
        guard let schedule = TitrationScheduleStore.shared.schedule(for: protocolId),
              schedule.autoAdvanceDose,
              let currentStep = schedule.currentStep() else { return }
        guard let pIdx = allProtocols.firstIndex(where: { $0.id == protocolId }) else { return }
        guard let cIdx = allProtocols[pIdx].compounds.firstIndex(where: {
            $0.compoundName.lowercased() == schedule.compoundName.lowercased()
        }) else { return }
        let existing = allProtocols[pIdx].compounds[cIdx]
        if abs(existing.doseMcg - currentStep.doseMcg) < 0.0001 { return }
        updateCompoundSchedule(
            protocolId: protocolId,
            compoundId: existing.id,
            doseMcg: currentStep.doseMcg,
            frequency: existing.frequency
        )
    }

    func saveTitrationSchedule(_ schedule: TitrationSchedule) {
        TitrationScheduleStore.shared.save(schedule)
        applyTitrationStepIfNeeded(protocolId: schedule.protocolId)
    }

    func removeTitrationSchedule(protocolId: UUID) {
        TitrationScheduleStore.shared.remove(protocolId: protocolId)
    }

    func updateCompoundSchedule(protocolId: UUID, compoundId: UUID, doseMcg: Double, frequency: String) {
        guard let pIdx = allProtocols.firstIndex(where: { $0.id == protocolId }) else { return }
        guard let cIdx = allProtocols[pIdx].compounds.firstIndex(where: { $0.id == compoundId }) else { return }
        let old = allProtocols[pIdx].compounds[cIdx]
        var replaced = ProtocolCompound(
            compoundName: old.compoundName,
            doseMcg: doseMcg,
            frequency: frequency,
            timeOfDay: old.timeOfDay,
            injectionRoute: old.injectionRoute,
            reconstitutionVolume: old.reconstitutionVolume,
            vialSizeMg: old.vialSizeMg,
            vendorName: old.vendorName,
            batchNumber: old.batchNumber,
            manufactureDate: old.manufactureDate,
            expirationDate: old.expirationDate
        )
        replaced.supabaseId = old.supabaseId
        allProtocols[pIdx].compounds[cIdx] = replaced
        if activeProtocol?.id == protocolId {
            activeProtocol = allProtocols[pIdx]
        }
        if let sid = old.supabaseId {
            Task {
                try? await ProtocolService.shared.updateCompound(id: sid, doseMcg: doseMcg, frequency: frequency)
            }
        }
    }

    func removeCompound(protocolId: UUID, compoundId: UUID) {
        guard let pIdx = allProtocols.firstIndex(where: { $0.id == protocolId }) else { return }
        guard let cIdx = allProtocols[pIdx].compounds.firstIndex(where: { $0.id == compoundId }) else { return }
        let compound = allProtocols[pIdx].compounds[cIdx]
        allProtocols[pIdx].compounds.remove(at: cIdx)
        if activeProtocol?.id == protocolId {
            activeProtocol = allProtocols[pIdx]
        }
        if let sid = compound.supabaseId {
            Task {
                try? await ProtocolService.shared.deleteCompound(id: sid)
            }
        }
    }

    func quickLogDose(protocolId: UUID, compoundId: UUID) {
        guard let pIdx = allProtocols.firstIndex(where: { $0.id == protocolId }) else { return }
        guard let compound = allProtocols[pIdx].compounds.first(where: { $0.id == compoundId }) else { return }
        let entry = DoseLogEntry(
            compoundName: compound.compoundName,
            doseMcg: compound.doseMcg,
            injectionSite: .leftAbdomen,
            notes: ""
        )
        allProtocols[pIdx].doseLog.insert(entry, at: 0)
        if activeProtocol?.id == protocolId {
            activeProtocol = allProtocols[pIdx]
        }
        let sid = allProtocols[pIdx].supabaseId
        Task {
            let result = await DoseLogger.log(
                protocolId: sid,
                compoundName: compound.compoundName,
                doseMcg: compound.doseMcg,
                injectionSite: .leftAbdomen
            )
            if let saved = result.entry,
               let idx = allProtocols.firstIndex(where: { $0.id == protocolId }),
               let logIdx = allProtocols[idx].doseLog.firstIndex(where: { $0.id == entry.id }) {
                allProtocols[idx].doseLog[logIdx] = saved
                if activeProtocol?.id == protocolId {
                    activeProtocol = allProtocols[idx]
                }
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

    // MARK: - AI Deck

    func refreshAIDeckIfNeeded(force: Bool = false) {
        let period = DeckRefreshPeriod.current()
        if !force {
            if let last = aiDeckLastRun[period], Calendar.current.isDateInToday(last) {
                return
            }
            if aiDeckIsGenerating { return }
        }
        aiDeckIsGenerating = true
        aiDeckPeriod = period
        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await DeckAgentService.shared.generate(period: period)
                self.aiDeckSuggestions = result.suggestions
                self.aiDeckPeriod = result.period
                self.aiDeckGeneratedAt = result.generatedAt
                self.aiDeckLastRun[period] = Date()
            } catch {
                print("[DeckAgent] failed: \(error)")
            }
            self.aiDeckIsGenerating = false
        }
    }

    func dismissAISuggestion(_ suggestion: AIDeckSuggestion, reason: DeckDismissReason) {
        AILearningStore.shared.recordDismissal(suggestion: suggestion, reason: reason)
        aiDeckSuggestions.removeAll { $0.id == suggestion.id }
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
            timeAgo: current.timeAgo,
            liked: !current.liked
        )
    }
}
