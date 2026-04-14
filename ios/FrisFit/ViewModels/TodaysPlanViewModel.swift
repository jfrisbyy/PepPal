import SwiftUI

@Observable
final class TodaysPlanViewModel {
    var planResponse: TodaysPlanResponse?
    var isLoading: Bool = false
    var isExpanded: Bool = false
    var errorMessage: String?
    var lastFetchDate: Date?

    private let cacheKey = "todaysPlanCache"
    private let cacheDateKey = "todaysPlanCacheDate"

    var hasPlan: Bool { planResponse != nil }

    var summary: String {
        planResponse?.summary ?? ""
    }

    var modules: [TodaysPlanModule] {
        planResponse?.modules ?? []
    }

    func loadCachedPlan() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let dateStr = UserDefaults.standard.string(forKey: cacheDateKey),
              let cached = try? JSONDecoder().decode(TodaysPlanResponse.self, from: data) else {
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let cacheDate = formatter.date(from: dateStr),
              Calendar.current.isDateInToday(cacheDate) else {
            return
        }

        planResponse = cached
        lastFetchDate = cacheDate
    }

    func cachePlan(_ plan: TodaysPlanResponse) {
        guard let data = try? JSONEncoder().encode(plan) else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        UserDefaults.standard.set(data, forKey: cacheKey)
        UserDefaults.standard.set(formatter.string(from: Date()), forKey: cacheDateKey)
    }

    var needsRefresh: Bool {
        guard let lastDate = lastFetchDate else { return true }
        let hoursSince = Date().timeIntervalSince(lastDate) / 3600
        return hoursSince > 4
    }

    func fetchPlan(
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
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

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

        Task {
            do {
                let response = try await TodaysPlanService.shared.generatePlan(context: context)
                planResponse = response
                lastFetchDate = Date()
                cachePlan(response)
            } catch {
                print("[TodaysPlan] Error: \(error)")
                errorMessage = "Could not generate today's plan"
            }
            isLoading = false
        }
    }
}
