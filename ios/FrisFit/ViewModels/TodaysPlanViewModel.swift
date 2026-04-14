import SwiftUI

@Observable
final class TodaysPlanViewModel {
    var planResponse: TodaysPlanResponse?
    var isLoading: Bool = false
    var isExpanded: Bool = false
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

    func fetchPlanIfNeeded(
        firstName: String,
        activeProtocol: PeptideProtocol?,
        nutrition: NutritionSnapshot,
        nutritionTarget: MacroTarget,
        loggedMeals: [LoggedMeal],
        bodyGoalVM: BodyGoalViewModel,
        todaysPlan: WorkoutPlan,
        activeProgram: TrainingProgram?,
        bloodworkEntries: [BloodworkEntry],
        streakDays: Int,
        workoutsThisWeek: Int,
        forceRefresh: Bool = false
    ) {
        guard !isLoading else { return }

        let context = TodaysPlanService.shared.assembleContext(
            firstName: firstName,
            activeProtocol: activeProtocol,
            nutrition: nutrition,
            nutritionTarget: nutritionTarget,
            loggedMeals: loggedMeals,
            bodyGoalVM: bodyGoalVM,
            todaysPlan: todaysPlan,
            activeProgram: activeProgram,
            bloodworkEntries: bloodworkEntries,
            streakDays: streakDays,
            workoutsThisWeek: workoutsThisWeek
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
                if !hadCachedPlan {
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
        bodyGoalVM: BodyGoalViewModel,
        todaysPlan: WorkoutPlan,
        activeProgram: TrainingProgram?,
        bloodworkEntries: [BloodworkEntry],
        streakDays: Int,
        workoutsThisWeek: Int
    ) {
        fetchPlanIfNeeded(
            firstName: firstName,
            activeProtocol: activeProtocol,
            nutrition: nutrition,
            nutritionTarget: nutritionTarget,
            loggedMeals: loggedMeals,
            bodyGoalVM: bodyGoalVM,
            todaysPlan: todaysPlan,
            activeProgram: activeProgram,
            bloodworkEntries: bloodworkEntries,
            streakDays: streakDays,
            workoutsThisWeek: workoutsThisWeek,
            forceRefresh: true
        )
    }
}
