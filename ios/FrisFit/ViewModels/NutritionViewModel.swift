import SwiftUI

@Observable
final class NutritionViewModel {
    var loggedMeals: [LoggedMeal] = []
    var isFollowingNutritionPlan: Bool = true
    var searchText: String = ""
    var selectedCategory: FoodCategory? = nil
    var isLoading: Bool = false
    var supabaseMealIds: [UUID: String] = [:]
    var savedMeals: [SavedMeal] = []

    private let savedMealsKey = "com.frisfit.savedMeals"

    let dailyTarget = MacroTarget(calories: 2200, protein: 150, carbs: 250, fat: 73)

    var totalCalories: Int { loggedMeals.reduce(0) { $0 + $1.totalCalories } }
    var totalProtein: Double { loggedMeals.reduce(0) { $0 + $1.totalProtein } }
    var totalCarbs: Double { loggedMeals.reduce(0) { $0 + $1.totalCarbs } }
    var totalFat: Double { loggedMeals.reduce(0) { $0 + $1.totalFat } }

    var calorieProgress: Double {
        guard dailyTarget.calories > 0 else { return 0 }
        return min(Double(totalCalories) / Double(dailyTarget.calories), 1.0)
    }

    var proteinProgress: Double {
        guard dailyTarget.protein > 0 else { return 0 }
        return min(totalProtein / Double(dailyTarget.protein), 1.0)
    }

    var carbsProgress: Double {
        guard dailyTarget.carbs > 0 else { return 0 }
        return min(totalCarbs / Double(dailyTarget.carbs), 1.0)
    }

    var fatProgress: Double {
        guard dailyTarget.fat > 0 else { return 0 }
        return min(totalFat / Double(dailyTarget.fat), 1.0)
    }

    var caloriesRemaining: Int { max(dailyTarget.calories - totalCalories, 0) }

    var fpBonus: Int {
        let proteinInRange = abs(totalProtein - Double(dailyTarget.protein)) <= Double(dailyTarget.protein) * 0.1
        let carbsInRange = abs(totalCarbs - Double(dailyTarget.carbs)) <= Double(dailyTarget.carbs) * 0.15
        let fatInRange = abs(totalFat - Double(dailyTarget.fat)) <= Double(dailyTarget.fat) * 0.15
        let calorieInRange = abs(Double(totalCalories) - Double(dailyTarget.calories)) <= Double(dailyTarget.calories) * 0.05

        var bonus = 0
        if proteinInRange { bonus += 15 }
        if carbsInRange { bonus += 10 }
        if fatInRange { bonus += 10 }
        if calorieInRange { bonus += 15 }
        return bonus
    }

    func mealsForTime(_ mealTime: MealTime) -> [LoggedMeal] {
        loggedMeals.filter { $0.mealTime == mealTime }
    }

    func caloriesForMealTime(_ mealTime: MealTime) -> Int {
        mealsForTime(mealTime).reduce(0) { $0 + $1.totalCalories }
    }

    func adherenceStatus(for mealTime: MealTime) -> AdherenceStatus {
        let mealCalories = caloriesForMealTime(mealTime)
        let expectedPerMeal = dailyTarget.calories / 4
        let tolerance = Int(Double(expectedPerMeal) * 0.25)

        if mealCalories == 0 { return .underTarget }
        if mealCalories > expectedPerMeal + tolerance { return .overTarget }
        if mealCalories < expectedPerMeal - tolerance { return .underTarget }
        return .onTrack
    }

    var filteredFoods: [FoodItem] {
        var results = FoodDatabase.allFoods
        if let category = selectedCategory {
            results = results.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            results = results.filter {
                $0.name.localizedStandardContains(searchText) ||
                $0.brand.localizedStandardContains(searchText)
            }
        }
        return results
    }

    func logMeal(food: FoodItem, servings: Double, mealTime: MealTime) {
        let meal = LoggedMeal(food: food, servings: servings, mealTime: mealTime)
        loggedMeals.append(meal)
        persistMealToSupabase(meal: meal, food: food, servings: servings, mealTime: mealTime)
    }

    private func persistMealToSupabase(meal: LoggedMeal, food: FoodItem, servings: Double, mealTime: MealTime) {
        guard AuthService.shared.authState == .signedIn else {
            print("[NutritionVM] Not signed in — meal not persisted to Supabase")
            return
        }
        Task {
            do {
                let userId = try AuthService.shared.currentUserId()
                let created = try await NutritionService.shared.logMeal(userId: userId, food: food, servings: servings, mealTime: mealTime)
                if let sid = created.id {
                    supabaseMealIds[meal.id] = sid
                }
                NotificationCenter.default.post(name: .mealDataChanged, object: nil)
                print("[NutritionVM] Meal persisted to Supabase: \(food.name)")
            } catch {
                print("[NutritionVM] Failed to persist meal to Supabase: \(error)")
            }
        }
    }

    func quickAddMeal(name: String, calories: Int, protein: Double, carbs: Double, fat: Double, mealTime: MealTime) {
        let customFood = FoodItem(
            name: name.isEmpty ? "Quick Add" : name,
            brand: "Custom",
            servingSize: "1 serving",
            servingGrams: 0,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            category: .other
        )
        logMeal(food: customFood, servings: 1.0, mealTime: mealTime)
    }

    func removeMeal(_ meal: LoggedMeal) {
        loggedMeals.removeAll { $0.id == meal.id }
        if let supabaseId = supabaseMealIds[meal.id] {
            supabaseMealIds.removeValue(forKey: meal.id)
            Task {
                try? await NutritionService.shared.deleteMeal(mealId: supabaseId)
                NotificationCenter.default.post(name: .mealDataChanged, object: nil)
            }
        }
    }

    func saveMeal(_ meal: SavedMeal) {
        savedMeals.insert(meal, at: 0)
        persistSavedMeals()
    }

    func deleteSavedMeal(_ meal: SavedMeal) {
        savedMeals.removeAll { $0.id == meal.id }
        persistSavedMeals()
    }

    func loadSavedMeals() {
        guard let data = UserDefaults.standard.data(forKey: savedMealsKey),
              let decoded = try? JSONDecoder().decode([SavedMeal].self, from: data) else { return }
        savedMeals = decoded
    }

    private func persistSavedMeals() {
        guard let data = try? JSONEncoder().encode(savedMeals) else { return }
        UserDefaults.standard.set(data, forKey: savedMealsKey)
    }

    func loadFromSupabase() {
        guard AuthService.shared.authState == .signedIn else { return }
        isLoading = true
        Task {
            do {
                let userId = try AuthService.shared.currentUserId()
                let meals = try await NutritionService.shared.fetchLoggedMeals(userId: userId, date: Date())
                let converted = meals.map { NutritionService.shared.toLoggedMeal($0) }
                var idMap: [UUID: String] = [:]
                for (i, meal) in meals.enumerated() {
                    if let sid = meal.id {
                        idMap[converted[i].id] = sid
                    }
                }
                loggedMeals = converted
                supabaseMealIds = idMap
            } catch {
                print("[NutritionVM] Failed to load meals from Supabase: \(error)")
            }
            isLoading = false
        }
    }

    func loadSampleData() {
        if AuthService.shared.authState == .signedIn {
            loadFromSupabase()
            return
        }
        guard loggedMeals.isEmpty else { return }
        let sampleMeals: [(String, MealTime)] = [
            ("Greek Yogurt (plain, nonfat)", .breakfast),
            ("Banana", .breakfast),
            ("Oatmeal (dry)", .breakfast),
            ("Chicken & Rice Bowl", .lunch),
            ("Mixed Salad Greens", .lunch),
            ("Protein Bar", .snacks),
            ("Almonds", .snacks),
        ]

        for (foodName, mealTime) in sampleMeals {
            if let food = FoodDatabase.allFoods.first(where: { $0.name == foodName }) {
                let meal = LoggedMeal(food: food, servings: 1.0, mealTime: mealTime)
                loggedMeals.append(meal)
            }
        }
    }
}
