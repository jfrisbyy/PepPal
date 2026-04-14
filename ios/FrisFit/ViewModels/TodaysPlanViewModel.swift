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
