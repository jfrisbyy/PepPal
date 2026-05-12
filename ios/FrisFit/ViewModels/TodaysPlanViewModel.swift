import SwiftUI
import UserNotifications

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
    private let memoKey = "todaysPlanPatternsMemo"
    private let memoDateKey = "todaysPlanPatternsMemoTimestamp"
    private static let windowsDoneKey = "todaysPlanWindowsDone"
    /// Pending trigger reason — set just before kicking off a refresh so the
    /// completion handler can record it alongside the cloud-saved briefing.
    private var pendingTrigger: String = "window"
    private var pendingTier: AIModelTier = .deep
    /// 30s debounce timer for log-driven refreshes so rapid-fire logs collapse
    /// into a single Haiku regen instead of one regen per log.
    private var debounceTask: Task<Void, Never>? = nil
    private var pendingDebouncedContext: ContextBundle? = nil
    private static let debounceSeconds: UInt64 = 30
    /// Anchored 1pm Haiku key — stored as "yyyy-MM-dd" so we only fire once per
    /// device-local day even if the app is foregrounded multiple times after 1pm.
    private static let middayDoneKey = "todaysPlanMiddayDone"
    /// Identifier used by the recurring local push that nudges users to open
    /// the app at 1pm so the midday Haiku refresh runs against fresh logs.
    private static let middayPushID = "smart.tasks.middayBrief"

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

    // MARK: - Active plan (today vs. historical)

    /// True when the user is viewing a non-today date in the calendar.
    var isHistoricalMode: Bool { historicalDate != nil }

    /// Resolves to the historical briefing when a past date is selected,
    /// falling back to today's plan otherwise.
    var activePlan: TodaysPlanResponse? {
        isHistoricalMode ? historicalPlan : planResponse
    }

    var activeSummary: String { activePlan?.summary ?? "" }

    var activeModules: [TodaysPlanModule] { activePlan?.modules ?? [] }

    func activeModuleContent(for type: String) -> String? {
        activePlan?.modules.first(where: { $0.type == type })?.content
    }

    func loadCachedPlan() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let timestamp = UserDefaults.standard.object(forKey: cacheDateKey) as? Date,
           Calendar.current.isDateInToday(timestamp),
           let cached = try? JSONDecoder().decode(TodaysPlanResponse.self, from: data) {
            planResponse = cached
            lastFetchDate = timestamp
        }
        // Make sure the recurring 1pm push is registered. Idempotent.
        scheduleMiddayPushIfNeeded()
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
        // Persist memo separately so we can inject it into Haiku updates even
        // after a relaunch where the in-memory plan hasn't hydrated yet.
        if let memo = plan.patternsMemo, !memo.isEmpty {
            UserDefaults.standard.set(memo, forKey: memoKey)
            UserDefaults.standard.set(Date(), forKey: memoDateKey)
        }
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

    /// The freshest pattern memo we have, preferring the in-memory plan and
    /// falling back to UserDefaults for cold-start cases.
    private func currentPatternsMemo() -> String? {
        if let memo = planResponse?.patternsMemo, !memo.isEmpty { return memo }
        return UserDefaults.standard.string(forKey: memoKey)
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

    /// Sonnet (deep) handles morning + evening windows; afternoon (1pm anchor)
    /// is always Haiku. Cold start with no memo silently upgrades to Sonnet
    /// inside the service so quality never degrades.
    private func tier(for window: Window) -> AIModelTier {
        switch window {
        case .morning, .evening: return .deep
        case .afternoon: return .fast
        }
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
    /// Whether the 1pm Haiku has already fired today.
    private func isMiddayDone() -> Bool {
        guard let raw = UserDefaults.standard.string(forKey: Self.middayDoneKey) else { return false }
        return raw == Self.dayString(Date())
    }

    private func markMiddayDone() {
        UserDefaults.standard.set(Self.dayString(Date()), forKey: Self.middayDoneKey)
    }

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
        // Catch-up for the anchored 1pm Haiku: if it's past 1pm, the user
        // hasn't gotten their midday refresh yet, and we're inside the
        // afternoon window, run it even if the window slot has been marked done.
        let nowHour = Calendar.current.component(.hour, from: Date())
        let middayCatchUp = nowHour >= 13 && nowHour < 18 && !isMiddayDone()
        if hasPlan && isCurrentWindowDone() && !middayCatchUp { return }

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

        // NOTE: We intentionally do NOT seed `planResponse` with a
        // narrative-less template fallback here. Doing so caused the brief
        // header to immediately drop into the generic `MorningBriefService`
        // copy path (because `narrative` was nil) instead of rendering the
        // loading state while the AI call ran. The view layer is responsible
        // for showing a shimmer when `isLoading == true && planResponse == nil`.
        pendingTrigger = middayCatchUp ? "midday" : "window"
        pendingTier = tier(for: currentWindow())
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
        // Stash the latest context and (re)start the 30s debounce window. Any
        // additional log inside that window resets the timer so a meal +
        // workout + weight logged 5 seconds apart collapse into one Haiku call.
        pendingDebouncedContext = context
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Self.debounceSeconds * 1_000_000_000)
            guard let self else { return }
            guard !Task.isCancelled else { return }
            guard let pending = self.pendingDebouncedContext else { return }
            self.pendingDebouncedContext = nil
            self.debounceTask = nil
            self.pendingTrigger = "event"
            self.pendingTier = .fast
            self.runHolisticRefresh(context: pending)
        }
    }

    private func runHolisticRefresh(context: ContextBundle) {
        let currentHash = context.contentHash
        let tier = pendingTier
        let trigger = pendingTrigger
        let previousBrief = planResponse
        let previousMemo = currentPatternsMemo()
        // Only treat the brief as "background refreshing" when we already have
        // a real AI brief on screen (narrative present). Otherwise this is
        // the first generation — use `isLoading` so the view shows shimmer.
        let hasRealBrief = planResponse?.narrative != nil
        if hasRealBrief {
            isBackgroundRefreshing = true
        } else {
            isLoading = true
        }
        errorMessage = nil
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let response = try await TodaysPlanService.shared.generatePlan(
                    context: context,
                    tier: tier,
                    previousBrief: previousBrief,
                    previousMemo: previousMemo
                )
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.planResponse = response
                }
                self.lastFetchDate = Date()
                self.cachePlan(response, hash: currentHash)
                self.markCurrentWindowDone()
                if trigger == "midday" {
                    self.markMiddayDone()
                }
                self.errorMessage = nil
            } catch {
                print("[TodaysPlan] Holistic refresh error: \(error)")
                // Surface the failure so the brief header can render an
                // error/retry state instead of silently dropping into the
                // local `MorningBriefService` generic copy path.
                self.errorMessage = Self.userFacingError(for: error)
            }
            self.isLoading = false
            self.isBackgroundRefreshing = false
        }
    }

    /// Maps a thrown AI error to a short, user-readable message for the
    /// brief header's error state. Keep these terse — the header is small.
    private static func userFacingError(for error: Error) -> String {
        if let planErr = error as? TodaysPlanError {
            switch planErr {
            case .apiError(let code):
                if code == 401 || code == 403 { return "Sign-in needed to refresh your brief." }
                if code == 429 { return "Rate limit hit \u{2014} try again in a moment." }
                if (500...599).contains(code) { return "Our AI service is having a moment. Tap retry." }
                return "Brief refresh failed (\(code)). Tap retry."
            case .invalidResponse:
                return "Brief response was malformed. Tap retry."
            }
        }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain { return "Network hiccup. Tap retry when you're back online." }
        return "Couldn't refresh your brief. Tap retry."
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
        // Manual pull-to-refresh always uses the cheap path — the user is
        // asking to see their newest data reflected, not a fresh deep pass.
        // The service auto-upgrades to Sonnet on cold-start (no memo).
        pendingTier = hasPlan ? .fast : .deep
        // Cancel any in-flight debounce so the manual refresh wins.
        debounceTask?.cancel()
        debounceTask = nil
        pendingDebouncedContext = nil
        runHolisticRefresh(context: context)
    }

    // MARK: - Midday push notification

    /// Schedules the recurring 1:00 PM local notification that nudges users
    /// to open the app so the midday Haiku refresh runs against fresh logs.
    /// Idempotent — safe to call on every cold start.
    private func scheduleMiddayPushIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            if requests.contains(where: { $0.identifier == Self.middayPushID }) { return }
            let content = UNMutableNotificationContent()
            content.title = "Midday brief is ready"
            content.body = "Open the app to see how your day is shaping up."
            content.sound = .default
            content.userInfo = ["smart_category": "tasks", "tab": "home"]
            var components = DateComponents()
            components.hour = 13
            components.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: Self.middayPushID,
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }
}
