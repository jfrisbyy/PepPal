import SwiftUI
import HealthKit

@Observable
final class EnergyBalanceViewModel {
    var bmr: Int = 0
    var activityCalories: Int = 0
    var healthKitCalories: Int = 0
    var activityCount: Int = 0
    var proteinTarget: Int = 150
    var carbsTarget: Int = 250
    var fatTarget: Int = 73
    var isLoading: Bool = false
    var hasLoaded: Bool = false
    var todaysMeals: [SupabaseLoggedMeal] = []
    var todaysActivities: [EnergyActivityLog] = []
    var unifiedActivities: [UnifiedActivity] = []
    var watchWorkoutsToday: [HKWorkout] = []
    var suppressedManualLogIds: Set<String> = []
    var goalType: String = "weightLoss"
    var weeklyTrend: [DailyDataPoint] = []
    var stepGoal: Int = 10000

    /// Live step count — reads from HealthKitService so the card re-renders
    /// automatically as steps update throughout the day.
    var stepsToday: Int { HealthKitService.shared.steps }

    var caloriesConsumed: Int { NutritionViewModel.shared.totalCalories }
    var proteinConsumed: Double { NutritionViewModel.shared.totalProtein }
    var carbsConsumed: Double { NutritionViewModel.shared.totalCarbs }
    var fatConsumed: Double { NutritionViewModel.shared.totalFat }

    private var mealPersistedObserver: Any?
    private var fetchGeneration: Int = 0
    private var nutritionFetchGeneration: Int = 0

    static let neatMultiplier: Double = 1.2

    var restingBurn: Int {
        Int(Double(bmr) * Self.neatMultiplier)
    }

    /// Calories from manually logged activities that do NOT overlap with a Watch workout.
    /// Prevents double-counting when the Watch already captured the session.
    var nonOverlappingManualCalories: Int {
        unifiedActivities
            .filter { $0.source == .manual }
            .reduce(0) { $0 + $1.calories }
    }

    var effectiveActivityCalories: Int {
        if healthKitCalories > 0 {
            return healthKitCalories + nonOverlappingManualCalories
        }
        return activityCalories
    }

    var hasWatchData: Bool { healthKitCalories > 0 || !watchWorkoutsToday.isEmpty }

    /// Calories from logged + Watch workouts (deduped via unifiedActivities).
    var exerciseCalories: Int {
        unifiedActivities.reduce(0) { $0 + $1.calories }
    }

    /// Calories attributed to the Watch workouts specifically (to subtract
    /// from HealthKit's total active energy when deriving step-only calories).
    private var watchWorkoutCalories: Int {
        unifiedActivities
            .filter { $0.source == .appleWatch }
            .reduce(0) { $0 + $1.calories }
    }

    /// Calories burned per step, scaled to the user's body weight when known.
    /// Average adult (~75 kg) burns ~0.04 cal/step at a casual walking pace.
    private var caloriesPerStep: Double {
        let cachedLbs = UserDefaults.standard.double(forKey: "cachedWeightLbs")
        let weightKg = cachedLbs > 0 ? cachedLbs * 0.453592 : 75.0
        return weightKg * 0.0005
    }

    /// Best-estimate calories burned from walking/steps alone. Always derived
    /// from the live step count so the Activity card updates as steps tick up.
    /// When HealthKit reports a higher total active energy (minus workouts),
    /// we trust that number; otherwise we fall back to the step-based estimate.
    var stepsCalories: Int {
        let stepEstimate = Int((Double(stepsToday) * caloriesPerStep).rounded())
        guard hasWatchData else { return stepEstimate }
        let healthKitStepsOnly = max(0, healthKitCalories - watchWorkoutCalories)
        return max(healthKitStepsOnly, stepEstimate)
    }

    /// Total active calories the user has actually earned today (steps + exercise).
    /// This is the "move" number — NOT BMR.
    var activeCaloriesBurned: Int { stepsCalories + exerciseCalories }

    /// Daily target for active calories. Matches Apple Fitness default.
    var activeGoal: Int { 500 }

    /// 0...1 progress against the active goal (capped visually at 1.0).
    var activeProgress: Double {
        guard activeGoal > 0 else { return 0 }
        return min(Double(activeCaloriesBurned) / Double(activeGoal), 1.0)
    }

    var isActiveGoalMet: Bool { activeCaloriesBurned >= activeGoal }

    /// Thermic effect of food — calories burned digesting. Protein ~25%, carbs ~8%, fat ~3%.
    var tefCalories: Int {
        let protein = proteinConsumed * 4.0 * 0.25
        let carbs = carbsConsumed * 4.0 * 0.08
        let fat = fatConsumed * 9.0 * 0.03
        return Int((protein + carbs + fat).rounded())
    }

    /// Target deficit/surplus in calories based on the user's goal.
    /// Negative = deficit target; positive = surplus target; nil = maintenance.
    var targetBalanceDelta: Int? {
        switch goalType {
        case "weightLoss", "cutting": return -500
        case "bulking", "muscleGain": return 300
        default: return nil
        }
    }

    /// For cutters: additional active calories needed today to land on target deficit,
    /// given current intake + BMR + TEF. Returns nil if not a cutting goal or already met.
    var additionalActiveCaloriesNeeded: Int? {
        guard let delta = targetBalanceDelta, delta < 0 else { return nil }
        let totalBurnNeeded = caloriesConsumed - delta
        let currentBurn = restingBurn + tefCalories + activeCaloriesBurned
        let gap = totalBurnNeeded - currentBurn
        return gap > 0 ? gap : nil
    }

    /// For cutters who are already past their deficit: how much headroom they have to eat.
    var additionalFoodAllowed: Int? {
        guard let delta = targetBalanceDelta, delta < 0 else { return nil }
        let totalBurn = restingBurn + tefCalories + activeCaloriesBurned
        let allowedIntake = totalBurn + delta
        let headroom = allowedIntake - caloriesConsumed
        return headroom > 0 ? headroom : nil
    }

    /// Human-readable source attribution for the activity total.
    var activitySourceDescription: String? {
        let loggedCount = unifiedActivities.filter { $0.source == .manual }.count
        let watchCount = watchWorkoutsToday.count
        switch (hasWatchData, loggedCount, watchCount) {
        case (true, 0, 0):
            return "Synced with Apple Watch"
        case (true, 0, let w):
            return "Apple Watch · \(w) \(w == 1 ? "workout" : "workouts")"
        case (true, let l, 0):
            return "Apple Watch · \(l) logged"
        case (true, let l, let w):
            return "Apple Watch · \(w) \(w == 1 ? "workout" : "workouts") + \(l) logged"
        case (false, 0, _):
            return nil
        case (false, let l, _):
            return "\(l) logged \(l == 1 ? "activity" : "activities")"
        }
    }

    var totalBurn: Int { restingBurn + effectiveActivityCalories + tefCalories }
    var balance: Int { caloriesConsumed - totalBurn }
    var isDeficit: Bool { balance < 0 }

    var balanceLabel: String {
        let val = abs(balance)
        return isDeficit ? "\(val) cal deficit" : "\(val) cal surplus"
    }

    var isGoalAligned: Bool {
        switch goalType {
        case "weightLoss", "cutting": return isDeficit
        case "bulking", "muscleGain": return !isDeficit
        default: return abs(balance) < 200
        }
    }

    var burnProgress: Double {
        guard totalBurn > 0, caloriesConsumed > 0 else { return 0 }
        return min(Double(caloriesConsumed) / Double(totalBurn), 2.0)
    }

    var proteinProgress: Double {
        guard proteinTarget > 0 else { return 0 }
        return min(proteinConsumed / Double(proteinTarget), 1.0)
    }

    var carbsProgress: Double {
        guard carbsTarget > 0 else { return 0 }
        return min(carbsConsumed / Double(carbsTarget), 1.0)
    }

    var fatProgress: Double {
        guard fatTarget > 0 else { return 0 }
        return min(fatConsumed / Double(fatTarget), 1.0)
    }

    var dailyCalorieTarget: Int {
        let base = restingBurn > 0 ? restingBurn : 2160
        let tdee = base + effectiveActivityCalories
        switch goalType {
        case "weightLoss", "cutting": return max(tdee - 500, 1200)
        case "bulking", "muscleGain": return tdee + 300
        default: return tdee
        }
    }

    var weeklyAvgBurn: Int {
        guard !weeklyTrend.isEmpty else { return 0 }
        let total = weeklyTrend.reduce(0.0) { $0 + $1.value }
        return Int(total / Double(weeklyTrend.count))
    }

    func loadData() {
        if !hasLoaded {
            hasLoaded = true
            isLoading = true
            Task {
                await fetchEnergyData()
                isLoading = false
            }
        } else if AuthService.shared.authState == .signedIn {
            Task { await fetchEnergyData() }
        }
        if mealPersistedObserver == nil {
            mealPersistedObserver = NotificationCenter.default.addObserver(
                forName: .mealPersistedToSupabase,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    await self.fetchNutritionOnly()
                }
            }
        }
    }

    private func fetchNutritionOnly() async {
        guard AuthService.shared.authState == .signedIn else { return }
        nutritionFetchGeneration += 1
        let gen = nutritionFetchGeneration
        do {
            let userId = try AuthService.shared.currentUserId()
            let meals = try await NutritionService.shared.fetchLoggedMeals(userId: userId, date: Date())
            guard gen == nutritionFetchGeneration else {
                print("[EnergyBalanceVM] fetchNutritionOnly superseded — discarding")
                return
            }
            todaysMeals = meals
            print("[EnergyBalanceVM] fetchNutritionOnly: \(meals.count) meals")
        } catch {
            print("[EnergyBalanceVM] Failed to refresh nutrition: \(error)")
        }
    }

    func refresh() async {
        await NutritionViewModel.sharedPersistenceWaiter()
        await fetchEnergyData()
    }

    private func fetchEnergyData() async {
        guard AuthService.shared.authState == .signedIn else { return }

        fetchGeneration += 1
        nutritionFetchGeneration += 1
        let gen = fetchGeneration
        let nutGen = nutritionFetchGeneration

        do {
            let userId = try AuthService.shared.currentUserId()

            async let calorieResult = ActivityLogService.shared.todayCaloriesBurned(userId: userId)
            async let mealsResult = NutritionService.shared.fetchLoggedMeals(userId: userId, date: Date())
            async let goalResult = BodyGoalsService.shared.fetchGoal()

            let calData = try await calorieResult
            let meals = try await mealsResult
            let goal = try? await goalResult

            guard gen == fetchGeneration else {
                print("[EnergyBalanceVM] fetchEnergyData superseded — discarding")
                return
            }

            activityCalories = calData.calories

            let activities = try? await ActivityLogService.shared.fetchTodayActivities(userId: userId)
            todaysActivities = activities ?? []

            let supabaseWorkouts = (try? await WorkoutService.shared.fetchWorkouts(userId: userId, limit: 20)) ?? []

            let hk = HealthKitService.shared
            var watchWorkouts: [HKWorkout] = []
            if hk.isHealthKitEnabled, hk.isAuthorized {
                let hkCals = await hk.fetchActiveCalories(for: Date())
                healthKitCalories = Int(hkCals)
                watchWorkouts = await hk.fetchWorkouts(for: Date())
            } else {
                healthKitCalories = 0
            }
            watchWorkoutsToday = watchWorkouts

            let reconciled = ActivityReconciliation.unify(
                manual: todaysActivities,
                watchWorkouts: watchWorkouts,
                supabaseWorkouts: supabaseWorkouts
            )
            unifiedActivities = reconciled.unified
            suppressedManualLogIds = reconciled.suppressedManualIds
            activityCount = unifiedActivities.count

            if nutGen == nutritionFetchGeneration {
                todaysMeals = meals
            } else {
                print("[EnergyBalanceVM] fetchEnergyData nutrition portion superseded — keeping newer totals")
            }

            if let goal {
                goalType = goal.goal_type
            }

            let profile = try? await ProfileService.shared.fetchProfile(userId: userId)
            if let profile {
                let dob: Date? = {
                    guard let dobStr = profile.date_of_birth else { return nil }
                    let f = ISO8601DateFormatter()
                    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    let fBasic = ISO8601DateFormatter()
                    fBasic.formatOptions = [.withInternetDateTime]
                    let df = DateFormatter()
                    df.dateFormat = "yyyy-MM-dd"
                    df.locale = Locale(identifier: "en_US_POSIX")
                    return f.date(from: dobStr) ?? fBasic.date(from: dobStr) ?? df.date(from: dobStr)
                }()
                let sex = profile.biological_sex.flatMap { BiologicalSex(rawValue: $0) }
                let heightCm = profile.height_cm
                let cachedLbs = UserDefaults.standard.double(forKey: "cachedWeightLbs")
                let weightKg = cachedLbs > 0 ? cachedLbs * 0.453592 : nil

                if let dob, let sex, let heightCm, let weightKg {
                    let age = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0
                    if age > 0 {
                        let calculatedBMR = BMRCalculator.calculate(weightKg: weightKg, heightCm: heightCm, age: age, sex: sex)
                        bmr = Int(calculatedBMR)
                    }
                }
            }

            if bmr == 0 {
                bmr = 1800
            }

            await fetchWeeklyTrend(userId: userId)
        } catch {
            print("[EnergyBalanceVM] ERROR fetching energy data: \(error.localizedDescription) — \(error)")
            if bmr == 0 { bmr = 1800 }
        }
    }

    private func fetchWeeklyTrend(userId: String) async {
        let df = DateFormatter()
        df.dateFormat = "EEE"
        df.locale = Locale(identifier: "en_US_POSIX")

        let dateParse = DateFormatter()
        dateParse.dateFormat = "yyyy-MM-dd"
        dateParse.locale = Locale(identifier: "en_US_POSIX")

        do {
            let dailyData = try await ActivityLogService.shared.fetchDailyCalories(userId: userId, days: 7)

            var hkDaily: [String: Int] = [:]
            let hk = HealthKitService.shared
            if hk.isHealthKitEnabled, hk.isAuthorized {
                let calendar = Calendar.current
                for i in 0..<7 {
                    if let date = calendar.date(byAdding: .day, value: i - 6, to: Date()) {
                        let dateStr = dateParse.string(from: date)
                        let hkCals = await hk.fetchActiveCalories(for: date)
                        hkDaily[dateStr] = Int(hkCals)
                    }
                }
            }

            var points: [DailyDataPoint] = []
            for entry in dailyData {
                let hkVal = hkDaily[entry.date] ?? 0
                let bestCals = max(entry.calories, hkVal)
                let dayLabel: String
                if let d = dateParse.date(from: entry.date) {
                    dayLabel = df.string(from: d)
                } else {
                    dayLabel = String(entry.date.suffix(2))
                }
                points.append(DailyDataPoint(label: dayLabel, value: Double(bestCals)))
            }
            weeklyTrend = points
        } catch {
            print("[EnergyBalanceVM] ERROR fetching weekly trend: \(error.localizedDescription) — \(error)")
            weeklyTrend = []
        }
    }
}
