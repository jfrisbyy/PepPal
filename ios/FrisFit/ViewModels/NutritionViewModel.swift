import SwiftUI
import Supabase

@Observable
final class NutritionViewModel {
    @MainActor static let shared = NutritionViewModel()

    @MainActor static var globalPendingPersistenceTasks: [Task<Void, Never>] = []

    @MainActor static func sharedPersistenceWaiter() async {
        let tasks = globalPendingPersistenceTasks
        for task in tasks { await task.value }
        globalPendingPersistenceTasks.removeAll { t in tasks.contains { $0 == t } }
    }

    var mealsByDay: [String: [LoggedMeal]] = [:]
    var isFollowingNutritionPlan: Bool = true
    var searchText: String = ""
    var selectedCategory: FoodCategory? = nil
    var isLoading: Bool = false
    var supabaseMealIds: [UUID: String] = [:]
    var savedMeals: [SavedMeal] = []
    var selectedDate: Date = Date()

    private let savedMealsKey = "com.frisfit.savedMeals"
    private var pendingPersistenceTasks: [Task<Void, Never>] = []
    private var loadGeneration: Int = 0
    private var activeLoadTask: Task<Void, Never>?
    private var loadedDays: Set<String> = []

    static func dayKey(for date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    var loggedMeals: [LoggedMeal] {
        get { mealsByDay[Self.dayKey(for: selectedDate)] ?? [] }
        set { mealsByDay[Self.dayKey(for: selectedDate)] = newValue }
    }

    func meals(for date: Date) -> [LoggedMeal] {
        mealsByDay[Self.dayKey(for: date)] ?? []
    }

    func totalCalories(for date: Date) -> Int {
        meals(for: date).reduce(0) { $0 + $1.totalCalories }
    }
    func totalProtein(for date: Date) -> Double { meals(for: date).reduce(0) { $0 + $1.totalProtein } }
    func totalCarbs(for date: Date) -> Double { meals(for: date).reduce(0) { $0 + $1.totalCarbs } }
    func totalFat(for date: Date) -> Double { meals(for: date).reduce(0) { $0 + $1.totalFat } }

    func waitForPendingPersistence() async {
        let tasks = pendingPersistenceTasks
        for task in tasks { await task.value }
        pendingPersistenceTasks.removeAll { t in tasks.contains { $0 == t } }
        Self.globalPendingPersistenceTasks.removeAll { t in tasks.contains { $0 == t } }
    }

    /// Baseline macro target without adaptive bundle overrides.
    var baselineTarget: MacroTarget {
        if AdaptiveMacroStore.shared.isEnabled, let t = AdaptiveMacroStore.shared.target {
            return t
        }
        return MacroTarget(calories: 2200, protein: 150, carbs: 250, fat: 73)
    }

    /// Daily macro target with any currently-accepted adaptive bundle lines
    /// applied (protein floor, carb ceiling, calorie delta).
    var dailyTarget: MacroTarget {
        var t = baselineTarget
        for line in AdaptiveAdjustmentService.shared.activeLines(in: .nutrition) {
            switch line.kind {
            case .proteinFloor(let grams):
                t = MacroTarget(calories: t.calories, protein: max(t.protein, grams), carbs: t.carbs, fat: t.fat)
            case .carbCeiling(let grams):
                t = MacroTarget(calories: t.calories, protein: t.protein, carbs: min(t.carbs, grams), fat: t.fat)
            case .calorieDelta(let kcal):
                t = MacroTarget(calories: max(1000, t.calories + kcal), protein: t.protein, carbs: t.carbs, fat: t.fat)
            default:
                break
            }
        }
        return t
    }

    /// Compact reason string for the "Adaptive" chip on the nutrition surface.
    /// Falls back to the baseline `AdaptiveMacroStore` reason when no bundle
    /// override is active.
    var adaptiveTargetReason: String? {
        let bundleLines = AdaptiveAdjustmentService.shared.activeLines(in: .nutrition)
        if !bundleLines.isEmpty {
            return bundleLines.map { $0.summary }.joined(separator: " · ")
        }
        guard AdaptiveMacroStore.shared.isEnabled, let i = AdaptiveMacroStore.shared.inputs else { return nil }
        var parts: [String] = []
        parts.append("\(Int(i.weightKg))kg · \(i.goal.rawValue)")
        parts.append(i.activity.label)
        if i.trainingLoadBoost > 0 {
            parts.append("+\(Int(i.trainingLoadBoost)) cal training boost")
        }
        return parts.joined(separator: " · ")
    }

    /// True when any nutrition-domain adjustment is active for today.
    var hasAdaptiveNutritionOverride: Bool {
        !AdaptiveAdjustmentService.shared.activeLines(in: .nutrition).isEmpty
    }

    var totalCalories: Int { loggedMeals.reduce(0) { $0 + $1.totalCalories } }
    var totalProtein: Double { loggedMeals.reduce(0) { $0 + $1.totalProtein } }
    var totalCarbs: Double { loggedMeals.reduce(0) { $0 + $1.totalCarbs } }
    var totalFat: Double { loggedMeals.reduce(0) { $0 + $1.totalFat } }

    var todayTotalCalories: Int { totalCalories(for: Date()) }
    var todayTotalProtein: Double { totalProtein(for: Date()) }
    var todayTotalCarbs: Double { totalCarbs(for: Date()) }
    var todayTotalFat: Double { totalFat(for: Date()) }

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
        let targetDate = resolvedLogDate()
        let meal = LoggedMeal(food: food, servings: servings, mealTime: mealTime, timestamp: targetDate)
        let key = Self.dayKey(for: targetDate)
        var arr = mealsByDay[key] ?? []
        arr.append(meal)
        mealsByDay[key] = arr
        persistMealToSupabase(meal: meal, food: food, servings: servings, mealTime: mealTime, loggedAt: targetDate)
        StreakManager.shared.logActivity(type: .food, at: targetDate)
        Task { @MainActor in _ = await CorrelationEngine.shared.run() }
    }

    func copyMeal(_ meal: LoggedMeal, to date: Date, mealTime: MealTime? = nil) {
        let cal = Calendar.current
        let base = cal.startOfDay(for: date)
        let target = cal.isDateInToday(date) ? Date() : (cal.date(byAdding: .hour, value: 12, to: base) ?? base)
        let time = mealTime ?? meal.mealTime
        let copy = LoggedMeal(food: meal.food, servings: meal.servings, mealTime: time, timestamp: target)
        let key = Self.dayKey(for: target)
        var arr = mealsByDay[key] ?? []
        arr.append(copy)
        mealsByDay[key] = arr
        persistMealToSupabase(meal: copy, food: meal.food, servings: meal.servings, mealTime: time, loggedAt: target)
    }

    private func resolvedLogDate() -> Date {
        let cal = Calendar.current
        if cal.isDateInToday(selectedDate) {
            return Date()
        }
        // For past/future selected dates, use noon on that day so timestamps land mid-day in local tz.
        let start = cal.startOfDay(for: selectedDate)
        return cal.date(byAdding: .hour, value: 12, to: start) ?? start
    }

    private func persistMealToSupabase(meal: LoggedMeal, food: FoodItem, servings: Double, mealTime: MealTime, loggedAt: Date) {
        let diagAuthState = AuthService.shared.authState
        let diagCurrentUserId: String? = (try? AuthService.shared.currentUserId())
        print("[NutritionVM][DIAG] persistMealToSupabase called — authState=\(diagAuthState), currentUserId=\(diagCurrentUserId ?? "nil")")
        Task { @MainActor in
            let sessionUserId: String? = await {
                do {
                    let uid = try await SupabaseService.shared.client.auth.session.user.id
                    return uid.uuidString
                } catch {
                    print("[NutritionVM][DIAG] session.user.id threw: \(error)")
                    return nil
                }
            }()
            print("[NutritionVM][DIAG] supabase session userId=\(sessionUserId ?? "nil")")
        }
        guard AuthService.shared.authState == .signedIn else {
            print("[NutritionVM] Not signed in — meal not persisted to Supabase")
            return
        }

        if !NetworkMonitor.shared.isOnline {
            if let userId = try? AuthService.shared.currentUserId() {
                let payload = NutritionService.shared.mealInsertPayload(
                    userId: userId, food: food, servings: servings, mealTime: mealTime, loggedAt: loggedAt
                )
                OfflineQueue.shared.enqueueInsert(table: "logged_meals", payload: payload)
            }
            return
        }

        let task = Task { @MainActor in
            do {
                let userId = try AuthService.shared.currentUserId()
                let created = try await NutritionService.shared.logMeal(userId: userId, food: food, servings: servings, mealTime: mealTime, loggedAt: loggedAt)
                if let sid = created.id {
                    supabaseMealIds[meal.id] = sid
                }
                loadedDays.insert(Self.dayKey(for: loggedAt))
                NotificationCenter.default.post(name: .mealPersistedToSupabase, object: nil)
                NotificationCenter.default.post(name: .supabaseDataChanged, object: nil, userInfo: ["source": "meal"])
                NotificationCenter.default.post(
                    name: .mealDataChanged,
                    object: nil,
                    userInfo: [
                        "action": "add",
                        "calories": Int(Double(food.calories) * servings),
                        "protein": food.protein * servings,
                        "carbs": food.carbs * servings,
                        "fat": food.fat * servings,
                        "food_name": food.name,
                        "food_brand": food.brand,
                        "meal_time": mealTime.rawValue,
                        "servings": servings
                    ]
                )
                print("[NutritionVM] Meal persisted to Supabase: \(food.name) (id: \(created.id ?? "nil"))")
            } catch {
                if let userId = try? AuthService.shared.currentUserId() {
                    let payload = NutritionService.shared.mealInsertPayload(
                        userId: userId, food: food, servings: servings, mealTime: mealTime, loggedAt: loggedAt
                    )
                    OfflineQueue.shared.enqueueInsert(table: "logged_meals", payload: payload)
                }
                print("[NutritionVM] ERROR persisting meal '\(food.name)' to Supabase: \(error.localizedDescription) — \(error)")
                print("[NutritionVM][DIAG] raw error: \(error)")
                let mirror = Mirror(reflecting: error)
                var code: Any? = nil
                var message: Any? = nil
                var details: Any? = nil
                var hint: Any? = nil
                for child in mirror.children {
                    if child.label == "code" { code = child.value }
                    if child.label == "message" { message = child.value }
                    if child.label == "details" { details = child.value }
                    if child.label == "hint" { hint = child.value }
                }
                if code != nil || message != nil {
                    print("[NutritionVM][DIAG] PostgrestError code=\(code ?? "nil") message=\(message ?? "nil")")
                }
                var detail = "\(error.localizedDescription)"
                if let m = message { detail += "\nmessage: \(m)" }
                if let c = code { detail += "\ncode: \(c)" }
                if let d = details { detail += "\ndetails: \(d)" }
                if let h = hint { detail += "\nhint: \(h)" }
                detail += "\nraw: \(error)"
                _ = detail
            }
        }
        pendingPersistenceTasks.append(task)
        Self.globalPendingPersistenceTasks.append(task)
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
        let removedCalories = meal.totalCalories
        let removedProtein = meal.totalProtein
        let removedCarbs = meal.totalCarbs
        let removedFat = meal.totalFat
        let key = Self.dayKey(for: meal.timestamp)
        mealsByDay[key]?.removeAll { $0.id == meal.id }
        NotificationCenter.default.post(
            name: .mealDataChanged,
            object: nil,
            userInfo: [
                "action": "remove",
                "calories": removedCalories,
                "protein": removedProtein,
                "carbs": removedCarbs,
                "fat": removedFat
            ]
        )
        if let supabaseId = supabaseMealIds[meal.id] {
            supabaseMealIds.removeValue(forKey: meal.id)
            Task {
                do {
                    try await NutritionService.shared.deleteMeal(mealId: supabaseId)
                    print("[NutritionVM] Deleted meal \(supabaseId) from Supabase")
                    await MainActor.run {
                        NotificationCenter.default.post(name: .supabaseDataChanged, object: nil, userInfo: ["source": "meal_delete"])
                    }
                } catch {
                    print("[NutritionVM] ERROR deleting meal \(supabaseId): \(error.localizedDescription) — \(error)")
                }
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
        loadFromSupabase(date: selectedDate)
    }

    func loadFromSupabase(date: Date) {
        guard AuthService.shared.authState == .signedIn else {
            print("[NutritionVM] loadFromSupabase skipped — user not signed in")
            return
        }
        activeLoadTask?.cancel()
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        activeLoadTask = Task { @MainActor in
            await waitForPendingPersistence()
            guard !Task.isCancelled, generation == self.loadGeneration else { return }
            await performLoad(date: date)
            if generation == self.loadGeneration {
                isLoading = false
            }
        }
    }

    func loadFromSupabaseAsync(force: Bool = false) async {
        await loadFromSupabaseAsync(date: selectedDate, force: force)
    }

    func loadFromSupabaseAsync(date: Date, force: Bool = false) async {
        if DemoModeManager.shared.isActive {
            print("[NutritionVM] loadFromSupabaseAsync skipped — demo mode active")
            return
        }
        guard AuthService.shared.authState == .signedIn else {
            print("[NutritionVM] loadFromSupabaseAsync skipped — user not signed in")
            return
        }
        let key = Self.dayKey(for: date)
        if !force && loadedDays.contains(key) {
            print("[NutritionVM] loadFromSupabaseAsync skipped — already loaded day \(key)")
            return
        }
        await waitForPendingPersistence()
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        defer {
            if generation == self.loadGeneration { isLoading = false }
        }
        await performLoad(date: date)
        _ = generation
    }

    private func performLoad(date: Date) async {
        let key = Self.dayKey(for: date)
        do {
            let userId = try AuthService.shared.currentUserId()
            let meals = try await NutritionService.shared.fetchLoggedMeals(userId: userId, date: date)
            let converted = meals.map { NutritionService.shared.toLoggedMeal($0) }
            var idMap: [UUID: String] = supabaseMealIds
            for (i, meal) in meals.enumerated() {
                if let sid = meal.id {
                    idMap[converted[i].id] = sid
                }
            }
            let existing = mealsByDay[key] ?? []
            let unpersisted = existing.filter { supabaseMealIds[$0.id] == nil }
            mealsByDay[key] = converted + unpersisted
            supabaseMealIds = idMap
            loadedDays.insert(key)
            print("[NutritionVM] Loaded \(meals.count) meals for \(key), \(unpersisted.count) unpersisted kept")
        } catch {
            print("[NutritionVM] ERROR loading meals for \(key): \(error.localizedDescription) — \(error)")
        }
    }

    func loadSampleData() {
        if AuthService.shared.authState == .signedIn {
            return
        }
        let todayKey = Self.dayKey(for: Date())
        guard (mealsByDay[todayKey] ?? []).isEmpty else { return }
        let sampleMeals: [(String, MealTime)] = [
            ("Greek Yogurt (plain, nonfat)", .breakfast),
            ("Banana", .breakfast),
            ("Oatmeal (dry)", .breakfast),
            ("Chicken & Rice Bowl", .lunch),
            ("Mixed Salad Greens", .lunch),
            ("Protein Bar", .snacks),
            ("Almonds", .snacks),
        ]

        var arr: [LoggedMeal] = mealsByDay[todayKey] ?? []
        for (foodName, mealTime) in sampleMeals {
            if let food = FoodDatabase.allFoods.first(where: { $0.name == foodName }) {
                let meal = LoggedMeal(food: food, servings: 1.0, mealTime: mealTime)
                arr.append(meal)
            }
        }
        mealsByDay[todayKey] = arr
    }
}
