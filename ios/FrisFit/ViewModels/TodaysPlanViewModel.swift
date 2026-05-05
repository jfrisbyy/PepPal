import SwiftUI

@Observable
final class TodaysPlanViewModel {
    var planResponse: TodaysPlanResponse?
    var isLoading: Bool = false
    var errorMessage: String?
    var lastFetchDate: Date?
    var isBackgroundRefreshing: Bool = false

    private let cacheKey = "todaysPlanCache"
    private let cacheHashKey = "todaysPlanHash"
    private let cacheDateKey = "todaysPlanCacheTimestamp"

    private var scopedDebounceTasks: [String: Task<Void, Never>] = [:]
    private var dirtyDomains: Set<String> = []
    private var lastHolisticDate: Date?
    private var lastSignalSnapshot: SignalSnapshot?

    private struct SignalSnapshot: Equatable {
        let proteinGoalHit: Bool
        let calorieGoalHit: Bool
        let calorieBudgetBlown: Bool
        let workoutCompletedToday: Bool
        let hasAnyLogToday: Bool
        let doseLoggedToday: Bool
    }

    private static let scopedDebounceSeconds: UInt64 = 45
    private static let holisticMaxStaleSeconds: TimeInterval = 4 * 60 * 60

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
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let timestamp = UserDefaults.standard.object(forKey: cacheDateKey) as? Date,
              Calendar.current.isDateInToday(timestamp),
              let cached = try? JSONDecoder().decode(TodaysPlanResponse.self, from: data) else {
            return
        }
        planResponse = cached
        lastFetchDate = timestamp
    }

    private func cachePlan(_ plan: TodaysPlanResponse, hash: String) {
        guard let data = try? JSONEncoder().encode(plan) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
        UserDefaults.standard.set(hash, forKey: cacheHashKey)
        UserDefaults.standard.set(Date(), forKey: cacheDateKey)
    }

    private var cachedHash: String? {
        UserDefaults.standard.string(forKey: cacheHashKey)
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

    private static func domain(forSource source: String) -> String? {
        switch source {
        case "meal", "meal_delete": return "nutrition"
        case "workout", "activity": return "training"
        case "weight", "measurement", "bodyGoal": return "body"
        case "dose", "sideEffect": return "protocol"
        case "bloodwork": return "bloodwork"
        default: return nil
        }
    }

    private func computeSignals(_ context: ContextBundle) -> SignalSnapshot {
        let proteinHit: Bool = {
            guard let n = context.nutritionToday, n.proteinTarget > 0 else { return false }
            return n.proteinConsumed >= n.proteinTarget
        }()
        let calorieHit: Bool = {
            guard let n = context.nutritionToday, n.caloriesTarget > 0 else { return false }
            return n.caloriesConsumed >= Int(Double(n.caloriesTarget) * 0.95)
        }()
        let calorieBlown: Bool = {
            guard let n = context.nutritionToday, n.caloriesTarget > 0 else { return false }
            return n.caloriesConsumed > Int(Double(n.caloriesTarget) * 1.1)
        }()
        let workoutDone = context.trainingContext?.completedToday ?? false
        let hasLog = (context.nutritionToday?.mealsLogged ?? 0) > 0 ||
            (context.trainingContext?.completedToday ?? false) ||
            (context.protocolContext?.doseLoggedToday ?? false)
        let doseLogged = context.protocolContext?.doseLoggedToday ?? false
        return SignalSnapshot(
            proteinGoalHit: proteinHit,
            calorieGoalHit: calorieHit,
            calorieBudgetBlown: calorieBlown,
            workoutCompletedToday: workoutDone,
            hasAnyLogToday: hasLog,
            doseLoggedToday: doseLogged
        )
    }

    private func shouldTriggerHolistic(_ newSignals: SignalSnapshot) -> Bool {
        guard let previous = lastSignalSnapshot else {
            return newSignals.hasAnyLogToday
        }
        if newSignals.proteinGoalHit != previous.proteinGoalHit { return true }
        if newSignals.calorieGoalHit != previous.calorieGoalHit { return true }
        if newSignals.calorieBudgetBlown != previous.calorieBudgetBlown { return true }
        if newSignals.workoutCompletedToday != previous.workoutCompletedToday { return true }
        if newSignals.doseLoggedToday != previous.doseLoggedToday { return true }
        if newSignals.hasAnyLogToday && !previous.hasAnyLogToday { return true }
        if let last = lastHolisticDate, Date().timeIntervalSince(last) > Self.holisticMaxStaleSeconds, newSignals.hasAnyLogToday {
            return true
        }
        return false
    }

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

        let signals = computeSignals(context)

        if shouldTriggerHolistic(signals) {
            lastSignalSnapshot = signals
            scopedDebounceTasks.values.forEach { $0.cancel() }
            scopedDebounceTasks.removeAll()
            dirtyDomains.removeAll()
            runHolisticRefresh(context: context)
            return
        }
        lastSignalSnapshot = signals

        guard let domain = Self.domain(forSource: source) else { return }
        dirtyDomains.insert(domain)
        scheduleScopedRefresh(domain: domain, context: context)
    }

    private func scheduleScopedRefresh(domain: String, context: ContextBundle) {
        scopedDebounceTasks[domain]?.cancel()
        let task = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Self.scopedDebounceSeconds))
            guard !Task.isCancelled, let self else { return }
            await self.performScopedRefresh(domain: domain, context: context)
        }
        scopedDebounceTasks[domain] = task
    }

    @MainActor
    private func performScopedRefresh(domain: String, context: ContextBundle) async {
        guard hasPlan else {
            runHolisticRefresh(context: context)
            return
        }
        isBackgroundRefreshing = true
        defer { isBackgroundRefreshing = false }
        do {
            let module = try await TodaysPlanService.shared.generateModule(domain: domain, context: context)
            guard var plan = planResponse else { return }
            var modules = plan.modules
            if let idx = modules.firstIndex(where: { $0.type == domain }) {
                modules[idx] = module
            } else {
                modules.append(module)
            }
            plan = TodaysPlanResponse(summary: plan.summary, modules: modules)
            withAnimation(.easeInOut(duration: 0.3)) {
                planResponse = plan
            }
            cachePlan(plan, hash: context.contentHash)
            dirtyDomains.remove(domain)
            scopedDebounceTasks.removeValue(forKey: domain)
        } catch {
            print("[TodaysPlan] Scoped \(domain) refresh failed: \(error)")
        }
    }

    private func runHolisticRefresh(context: ContextBundle) {
        let currentHash = context.contentHash
        if let cached = cachedHash, cached == currentHash, hasPlan {
            lastHolisticDate = Date()
            return
        }
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
                self.lastHolisticDate = Date()
                self.cachePlan(response, hash: currentHash)
            } catch {
                print("[TodaysPlan] Holistic refresh error: \(error)")
            }
            self.isLoading = false
            self.isBackgroundRefreshing = false
        }
    }

    func fetchPlanIfNeeded(
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
        personalRecords: [TrainPersonalRecord] = [],
        forceRefresh: Bool = false
    ) {
        guard !isLoading else { return }

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

        let currentHash = context.contentHash

        if !forceRefresh, let cached = cachedHash, cached == currentHash, hasPlan {
            return
        }

        let hadCachedPlan = hasPlan
        if hadCachedPlan {
            isBackgroundRefreshing = true
        } else {
            isLoading = true
            let fallback = templateFallback(
                firstName: firstName,
                activeProtocol: activeProtocol,
                nutritionTarget: nutritionTarget
            )
            if planResponse == nil {
                planResponse = fallback
            }
        }
        errorMessage = nil

        Task {
            do {
                let response = try await TodaysPlanService.shared.generatePlan(context: context)
                withAnimation(.easeInOut(duration: 0.3)) {
                    planResponse = response
                }
                lastFetchDate = Date()
                lastHolisticDate = Date()
                lastSignalSnapshot = computeSignals(context)
                cachePlan(response, hash: currentHash)
            } catch {
                print("[TodaysPlan] Error: \(error)")
                if !hadCachedPlan && planResponse?.summary.contains("Log your first data") == true {
                    errorMessage = "Could not generate today's plan"
                }
            }
            isLoading = false
            isBackgroundRefreshing = false
        }
    }

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
        fetchPlanIfNeeded(
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
            personalRecords: personalRecords,
            forceRefresh: true
        )
    }
}
