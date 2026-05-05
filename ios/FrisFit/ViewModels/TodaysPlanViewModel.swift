import SwiftUI

@Observable
final class TodaysPlanViewModel {
    static let shared = TodaysPlanViewModel()

    var planResponse: TodaysPlanResponse?
    var isLoading: Bool = false
    var errorMessage: String?
    var lastFetchDate: Date?
    var isBackgroundRefreshing: Bool = false
    /// When the user picks a past date in the calendar, this holds that day's
    /// locked briefing pulled from the cloud. Today always reads from `planResponse`.
    var historicalPlan: TodaysPlanResponse?
    var historicalDate: Date?
    var isLoadingHistorical: Bool = false

    private let cacheKey = "todaysPlanCache"
    private let cacheHashKey = "todaysPlanHash"
    private let cacheDateKey = "todaysPlanCacheTimestamp"
    private static let windowsDoneKey = "todaysPlanWindowsDone"
    /// Pending trigger reason — set just before kicking off a refresh so the
    /// completion handler can record it alongside the cloud-saved briefing.
    private var pendingTrigger: String = "window"

    /// Log sources that should trigger an immediate holistic brief refresh.
    private static let logTriggerSources: Set<String> = [
        "meal", "meal_delete",
        "workout", "activity",
        "weight", "measurement", "bodyGoal",
        "dose", "sideEffect",
        "bloodwork"
    ]

    var hasPlan: Bool { planResponse != nil }

    var summary: String {
        planResponse?.summary ?? ""
    }

    var modules: [TodaysPlanModule] {
        planResponse?.modules ?? []
    }

    func moduleContent(for type: String) -> String? {
        planResponse?.modules.first(where: { $0.type == type })?.content
    }

    func loadCachedPlan() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let timestamp = UserDefaults.standard.object(forKey: cacheDateKey) as? Date,
           Calendar.current.isDateInToday(timestamp),
           let cached = try? JSONDecoder().decode(TodaysPlanResponse.self, from: data) {
            planResponse = cached
            lastFetchDate = timestamp
        }
        // Cloud fallback: if local cache was empty (cold install, signed in on
        // another device), hydrate today's brief from Supabase before any AI call.
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard self.planResponse == nil || !Calendar.current.isDateInToday(self.lastFetchDate ?? .distantPast) else { return }
            if let latest = await BriefingCloudService.shared.fetchLatestBriefing(),
               Calendar.current.isDateInToday(latest.day) {
                self.planResponse = latest.plan
                self.lastFetchDate = Date()
            }
            await BriefingCloudService.shared.lockYesterdayIfNeeded()
        }
    }

    /// Loads a saved briefing for a past date (calendar picker on home screen).
    /// Today always renders `planResponse`; older days render `historicalPlan`.
    func loadHistoricalBriefing(for date: Date) {
        if Calendar.current.isDateInToday(date) {
            historicalPlan = nil
            historicalDate = nil
            return
        }
        if let existing = historicalDate, Calendar.current.isDate(existing, inSameDayAs: date), historicalPlan != nil {
            return
        }
        historicalPlan = nil
        historicalDate = date
        isLoadingHistorical = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            let plan = await BriefingCloudService.shared.fetchBriefing(for: date)
            if let pinned = self.historicalDate, Calendar.current.isDate(pinned, inSameDayAs: date) {
                self.historicalPlan = plan
            }
            self.isLoadingHistorical = false
        }
    }

    private func cachePlan(_ plan: TodaysPlanResponse, hash: String) {
        guard let data = try? JSONEncoder().encode(plan) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
        UserDefaults.standard.set(hash, forKey: cacheHashKey)
        UserDefaults.standard.set(Date(), forKey: cacheDateKey)
        // Persist to the cloud so other devices and historical lookups find it.
        let trigger = pendingTrigger
        let windowKey = currentWindow().rawValue
        Task.detached { @MainActor in
            await BriefingCloudService.shared.saveBriefing(
                date: Date(),
                plan: plan,
                dataHash: hash,
                trigger: trigger,
                windowKey: windowKey
            )
        }
    }

    func templateFallback(
        firstName: String,
        activeProtocol: PeptideProtocol?,
        nutritionTarget: MacroTarget
    ) -> TodaysPlanResponse {
        let hour = Calendar.current.component(.hour, from: Date())
        let greeting: String
        switch hour {
        case 0..<12: greeting = "Morning"
        case 12..<17: greeting = "Afternoon"
        default: greeting = "Evening"
        }

        var summaryParts = ["\(greeting), \(firstName)."]

        if let proto = activeProtocol, let compound = proto.compounds.first {
            summaryParts.append("Week \(proto.currentWeek) of \(compound.compoundName).")
        }

        summaryParts.append("Log your first data of the day to get personalized insights.")

        var templateModules: [TodaysPlanModule] = []

        if let proto = activeProtocol, let compound = proto.compounds.first {
            templateModules.append(TodaysPlanModule(
                type: "protocol",
                title: compound.compoundName,
                content: "Week \(proto.currentWeek), \(proto.currentPhase.rawValue) phase. Log your dose to track progress."
            ))
        }

        templateModules.append(TodaysPlanModule(
            type: "nutrition",
            title: "Nutrition",
            content: "You have \(nutritionTarget.calories) cal and \(nutritionTarget.protein)g protein to work with today. Log a meal to start tracking."
        ))

        return TodaysPlanResponse(
            summary: summaryParts.joined(separator: " "),
            modules: templateModules
        )
    }

    // MARK: - Time-of-day windows

    /// Three refresh windows anchored at 6 AM / 1 PM / 6 PM. Hours before 6 AM
    /// fall into the previous evening's window so a 5 AM open doesn't burn a
    /// generation that the 6 AM one will redo.
    private enum Window: String { case morning, afternoon, evening }

    private func currentWindow(_ date: Date = Date()) -> Window {
        let hour = Calendar.current.component(.hour, from: date)
        if hour < 6 { return .evening }       // overnight rolls into prior evening
        if hour < 13 { return .morning }      // 6 AM – 12:59 PM
        if hour < 18 { return .afternoon }    // 1 PM – 5:59 PM
        return .evening                       // 6 PM onward
    }

    private static func dayString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f.string(from: date)
    }

    private func windowsDoneToday() -> Set<String> {
        guard let raw = UserDefaults.standard.string(forKey: Self.windowsDoneKey) else { return [] }
        let parts = raw.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, String(parts[0]) == Self.dayString(Date()) else { return [] }
        return Set(parts[1].split(separator: ",").map(String.init))
    }

    private func markCurrentWindowDone() {
        var done = windowsDoneToday()
        done.insert(currentWindow().rawValue)
        let today = Self.dayString(Date())
        UserDefaults.standard.set("\(today)|\(done.sorted().joined(separator: ","))", forKey: Self.windowsDoneKey)
    }

    private func isCurrentWindowDone() -> Bool {
        windowsDoneToday().contains(currentWindow().rawValue)
    }

    // MARK: - Refresh entry points

    /// Called when the home view appears or the app returns to foreground.
    /// Runs a holistic refresh if there's no plan yet, or if the current
    /// time-of-day window hasn't been refreshed today. Otherwise is a no-op.
    func refreshForWindowIfDue(
        firstName: String,
        activeProtocol: PeptideProtocol?,
        nutrition: NutritionSnapshot,
        nutritionTarget: MacroTarget,
        loggedMeals: [LoggedMeal],
        recentDailyMeals: [[LoggedMeal]] = [],
        bodyGoalVM: BodyGoalViewModel,
        todaysPlan: WorkoutPlan,
        activeProgram: TrainingProgram?,
        bloodworkEntries: [BloodworkEntry],
        streakDays: Int,
        workoutsThisWeek: Int,
        workoutHistory: [WorkoutHistoryDetail] = [],
        muscleRecoveryItems: [MuscleRecoveryItem] = [],
        weeklyMuscleVolumes: [WeeklyMuscleVolume] = [],
        personalRecords: [TrainPersonalRecord] = []
    ) {
        guard !isLoading else { return }
        if hasPlan && isCurrentWindowDone() { return }

        let context = TodaysPlanService.shared.assembleContext(
            firstName: firstName,
            activeProtocol: activeProtocol,
            nutrition: nutrition,
            nutritionTarget: nutritionTarget,
            loggedMeals: loggedMeals,
            recentDailyMeals: recentDailyMeals,
            bodyGoalVM: bodyGoalVM,
            todaysPlan: todaysPlan,
            activeProgram: activeProgram,
            bloodworkEntries: bloodworkEntries,
            streakDays: streakDays,
            workoutsThisWeek: workoutsThisWeek,
            workoutHistory: workoutHistory,
            muscleRecoveryItems: muscleRecoveryItems,
            weeklyMuscleVolumes: weeklyMuscleVolumes,
            personalRecords: personalRecords
        )

        if !hasPlan {
            let fallback = templateFallback(
                firstName: firstName,
                activeProtocol: activeProtocol,
                nutritionTarget: nutritionTarget
            )
            planResponse = fallback
        }
        pendingTrigger = "window"
        runHolisticRefresh(context: context)
    }

    /// Called on any user-generated log. Any meal/workout/weight/dose/bloodwork
    /// log triggers an immediate holistic refresh; non-log notifications are
    /// ignored.
    func handleDataChange(
        source: String,
        firstName: String,
        activeProtocol: PeptideProtocol?,
        nutrition: NutritionSnapshot,
        nutritionTarget: MacroTarget,
        loggedMeals: [LoggedMeal],
        recentDailyMeals: [[LoggedMeal]] = [],
        bodyGoalVM: BodyGoalViewModel,
        todaysPlan: WorkoutPlan,
        activeProgram: TrainingProgram?,
        bloodworkEntries: [BloodworkEntry],
        streakDays: Int,
        workoutsThisWeek: Int,
        workoutHistory: [WorkoutHistoryDetail] = [],
        muscleRecoveryItems: [MuscleRecoveryItem] = [],
        weeklyMuscleVolumes: [WeeklyMuscleVolume] = [],
        personalRecords: [TrainPersonalRecord] = []
    ) {
        guard Self.logTriggerSources.contains(source) else { return }

        let context = TodaysPlanService.shared.assembleContext(
            firstName: firstName,
            activeProtocol: activeProtocol,
            nutrition: nutrition,
            nutritionTarget: nutritionTarget,
            loggedMeals: loggedMeals,
            recentDailyMeals: recentDailyMeals,
            bodyGoalVM: bodyGoalVM,
            todaysPlan: todaysPlan,
            activeProgram: activeProgram,
            bloodworkEntries: bloodworkEntries,
            streakDays: streakDays,
            workoutsThisWeek: workoutsThisWeek,
            workoutHistory: workoutHistory,
            muscleRecoveryItems: muscleRecoveryItems,
            weeklyMuscleVolumes: weeklyMuscleVolumes,
            personalRecords: personalRecords
        )
        pendingTrigger = "event"
        runHolisticRefresh(context: context)
    }

    private func runHolisticRefresh(context: ContextBundle) {
        let currentHash = context.contentHash
        if hasPlan {
            isBackgroundRefreshing = true
        } else {
            isLoading = true
        }
        errorMessage = nil
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let response = try await TodaysPlanService.shared.generatePlan(context: context)
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.planResponse = response
                }
                self.lastFetchDate = Date()
                self.cachePlan(response, hash: currentHash)
                self.markCurrentWindowDone()
            } catch {
                print("[TodaysPlan] Holistic refresh error: \(error)")
            }
            self.isLoading = false
            self.isBackgroundRefreshing = false
        }
    }

    /// Manual force-refresh (e.g. pull-to-refresh, chat context builder).
    func forceRefresh(
        firstName: String,
        activeProtocol: PeptideProtocol?,
        nutrition: NutritionSnapshot,
        nutritionTarget: MacroTarget,
        loggedMeals: [LoggedMeal],
        recentDailyMeals: [[LoggedMeal]] = [],
        bodyGoalVM: BodyGoalViewModel,
        todaysPlan: WorkoutPlan,
        activeProgram: TrainingProgram?,
        bloodworkEntries: [BloodworkEntry],
        streakDays: Int,
        workoutsThisWeek: Int,
        workoutHistory: [WorkoutHistoryDetail] = [],
        muscleRecoveryItems: [MuscleRecoveryItem] = [],
        weeklyMuscleVolumes: [WeeklyMuscleVolume] = [],
        personalRecords: [TrainPersonalRecord] = []
    ) {
        let context = TodaysPlanService.shared.assembleContext(
            firstName: firstName,
            activeProtocol: activeProtocol,
            nutrition: nutrition,
            nutritionTarget: nutritionTarget,
            loggedMeals: loggedMeals,
            recentDailyMeals: recentDailyMeals,
            bodyGoalVM: bodyGoalVM,
            todaysPlan: todaysPlan,
            activeProgram: activeProgram,
            bloodworkEntries: bloodworkEntries,
            streakDays: streakDays,
            workoutsThisWeek: workoutsThisWeek,
            workoutHistory: workoutHistory,
            muscleRecoveryItems: muscleRecoveryItems,
            weeklyMuscleVolumes: weeklyMuscleVolumes,
            personalRecords: personalRecords
        )
        pendingTrigger = "manual"
        runHolisticRefresh(context: context)
    }
}
