import SwiftUI

@Observable
final class EnergyBalanceViewModel {
    var bmr: Int = 0
    var activityCalories: Int = 0
    var caloriesConsumed: Int = 0
    var activityCount: Int = 0
    var proteinConsumed: Double = 0
    var carbsConsumed: Double = 0
    var fatConsumed: Double = 0
    var proteinTarget: Int = 150
    var carbsTarget: Int = 250
    var fatTarget: Int = 73
    var isLoading: Bool = false
    var hasLoaded: Bool = false
    var goalType: String = "weightLoss"

    var totalBurn: Int { bmr + activityCalories }
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

    func loadData() {
        guard !hasLoaded else { return }
        hasLoaded = true
        isLoading = true
        Task {
            await fetchEnergyData()
            isLoading = false
        }
    }

    func refresh() async {
        await fetchEnergyData()
    }

    private func fetchEnergyData() async {
        guard AuthService.shared.authState == .signedIn else { return }

        do {
            let userId = try AuthService.shared.currentUserId()

            async let calorieResult = ActivityLogService.shared.todayCaloriesBurned(userId: userId)
            async let mealsResult = NutritionService.shared.fetchLoggedMeals(userId: userId, date: Date())
            async let goalResult = BodyGoalsService.shared.fetchGoal()

            let calData = try await calorieResult
            let meals = try await mealsResult
            let goal = try? await goalResult

            activityCalories = calData.calories
            activityCount = calData.count

            var totalCal = 0
            var totalPro = 0.0
            var totalCarb = 0.0
            var totalFt = 0.0
            for meal in meals {
                let cal = meal.calories ?? 0
                let servings = meal.servings
                totalCal += Int(Double(cal) * servings)
                totalPro += (meal.protein_g ?? 0) * servings
                totalCarb += (meal.carbs_g ?? 0) * servings
                totalFt += (meal.fat_g ?? 0) * servings
            }
            caloriesConsumed = totalCal
            proteinConsumed = totalPro
            carbsConsumed = totalCarb
            fatConsumed = totalFt

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
        } catch {
            if bmr == 0 { bmr = 1800 }
        }
    }
}
