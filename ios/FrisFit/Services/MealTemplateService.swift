import Foundation

@Observable
@MainActor
final class MealTemplateStore {
    static let shared = MealTemplateStore()

    var recentMealsByTime: [MealTime: [LoggedMeal]] = [:]
    var yesterdayMealsByTime: [MealTime: [LoggedMeal]] = [:]

    private init() {
        rebuild()
        NotificationCenter.default.addObserver(
            forName: .mealDataChanged,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in self.rebuild() }
        }
    }

    func rebuild() {
        let vm = NutritionViewModel.shared
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: today) else { return }

        let yKey = NutritionViewModel.dayKey(for: yesterday)
        let yMeals = vm.mealsByDay[yKey] ?? []
        var byTime: [MealTime: [LoggedMeal]] = [:]
        for m in yMeals {
            byTime[m.mealTime, default: []].append(m)
        }
        yesterdayMealsByTime = byTime

        var allRecent: [LoggedMeal] = []
        for offset in 0..<7 {
            guard let d = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let key = NutritionViewModel.dayKey(for: d)
            allRecent.append(contentsOf: vm.mealsByDay[key] ?? [])
        }
        var recentByTime: [MealTime: [LoggedMeal]] = [:]
        for meal in allRecent {
            var existing = recentByTime[meal.mealTime] ?? []
            if !existing.contains(where: { $0.food.name == meal.food.name && $0.food.brand == meal.food.brand }) {
                existing.append(meal)
            }
            recentByTime[meal.mealTime] = existing
        }
        recentMealsByTime = recentByTime
    }

    func relogYesterday(mealTime: MealTime) {
        let meals = yesterdayMealsByTime[mealTime] ?? []
        let vm = NutritionViewModel.shared
        for m in meals {
            vm.logMeal(food: m.food, servings: m.servings, mealTime: mealTime)
        }
    }

    func relog(_ meal: LoggedMeal, at mealTime: MealTime) {
        NutritionViewModel.shared.logMeal(food: meal.food, servings: meal.servings, mealTime: mealTime)
    }
}
