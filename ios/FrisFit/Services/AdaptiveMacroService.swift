import Foundation

nonisolated enum ActivityLevel: String, CaseIterable, Sendable, Codable {
    case sedentary
    case light
    case moderate
    case active
    case athlete

    var label: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .light: return "Light (1–3 days/wk)"
        case .moderate: return "Moderate (3–5 days/wk)"
        case .active: return "Active (6–7 days/wk)"
        case .athlete: return "Athlete (2x/day)"
        }
    }

    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .athlete: return 1.9
        }
    }
}

nonisolated struct MacroGoalInputs: Sendable, Codable {
    let weightKg: Double
    let heightCm: Double
    let ageYears: Int
    let biologicalSex: String
    let activity: ActivityLevel
    let goal: FitnessGoalType
    let trainingLoadBoost: Double

    init(
        weightKg: Double,
        heightCm: Double,
        ageYears: Int,
        biologicalSex: String,
        activity: ActivityLevel,
        goal: FitnessGoalType,
        trainingLoadBoost: Double = 0
    ) {
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.ageYears = ageYears
        self.biologicalSex = biologicalSex
        self.activity = activity
        self.goal = goal
        self.trainingLoadBoost = trainingLoadBoost
    }
}

nonisolated struct AdaptiveMacroService: Sendable {
    static func compute(_ input: MacroGoalInputs, isOnGLP1: Bool = false) -> MacroTarget {
        let bmr: Double
        let sexIsMale = input.biologicalSex.lowercased().hasPrefix("m")
        if sexIsMale {
            bmr = 10 * input.weightKg + 6.25 * input.heightCm - 5 * Double(input.ageYears) + 5
        } else {
            bmr = 10 * input.weightKg + 6.25 * input.heightCm - 5 * Double(input.ageYears) - 161
        }

        var tdee = bmr * input.activity.multiplier
        tdee += input.trainingLoadBoost

        var calories: Double
        switch input.goal {
        case .weightLoss: calories = tdee - 500
        case .cutting: calories = tdee - 750
        case .weightGain: calories = tdee + 300
        case .bulking: calories = tdee + 500
        case .maintain: calories = tdee
        case .recomp: calories = tdee - 150
        }

        // GLP-1s cause rapid weight loss with heightened muscle-loss risk.
        // Cap the deficit to protect lean mass while appetite is suppressed.
        if isOnGLP1 && calories < tdee {
            let minCalories = tdee - 500
            calories = max(calories, minCalories)
        }

        var proteinPerKg: Double
        switch input.goal {
        case .cutting, .weightLoss, .recomp: proteinPerKg = 2.2
        case .bulking: proteinPerKg = 1.8
        case .weightGain, .maintain: proteinPerKg = 1.7
        }
        if isOnGLP1 { proteinPerKg = max(proteinPerKg, 2.4) }

        let proteinG = proteinPerKg * input.weightKg
        let fatRatio: Double = input.goal == .cutting ? 0.25 : 0.30
        let fatCalories = calories * fatRatio
        let fatG = fatCalories / 9.0

        let proteinCalories = proteinG * 4.0
        let carbCalories = max(calories - proteinCalories - fatCalories, 0)
        let carbsG = carbCalories / 4.0

        return MacroTarget(
            calories: max(Int(calories), 1200),
            protein: Int(proteinG),
            carbs: Int(carbsG),
            fat: Int(fatG)
        )
    }

    static func trainingLoadBoost(weeklyWorkoutMinutes: Int) -> Double {
        let perMin = 7.0
        let weekly = Double(weeklyWorkoutMinutes) * perMin
        return weekly / 7.0
    }
}

@Observable
@MainActor
final class AdaptiveMacroStore {
    static let shared = AdaptiveMacroStore()

    var inputs: MacroGoalInputs?
    var target: MacroTarget?
    var isEnabled: Bool = false

    private let inputsKey = "com.frisfit.adaptiveMacros.inputs"
    private let enabledKey = "com.frisfit.adaptiveMacros.enabled"

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        if let data = UserDefaults.standard.data(forKey: inputsKey),
           let decoded = try? JSONDecoder().decode(MacroGoalInputs.self, from: data) {
            inputs = decoded
            target = AdaptiveMacroService.compute(decoded)
        }
    }

    func save(inputs: MacroGoalInputs) {
        self.inputs = inputs
        target = AdaptiveMacroService.compute(inputs, isOnGLP1: Self.currentUserIsOnGLP1())
        isEnabled = true
        if let data = try? JSONEncoder().encode(inputs) {
            UserDefaults.standard.set(data, forKey: inputsKey)
        }
        UserDefaults.standard.set(true, forKey: enabledKey)
    }

    func recomputeForContext() {
        guard let i = inputs else { return }
        target = AdaptiveMacroService.compute(i, isOnGLP1: Self.currentUserIsOnGLP1())
    }

    private static func currentUserIsOnGLP1() -> Bool {
        let glpNames: Set<String> = ["semaglutide", "tirzepatide", "retatrutide", "cagrilintide", "liraglutide"]
        let protocols = InsightsDataStore.shared.activeProtocols.filter { $0.isActive }
        for p in protocols {
            for c in p.compounds {
                if glpNames.contains(c.compoundName.lowercased()) { return true }
            }
        }
        return false
    }

    func disable() {
        isEnabled = false
        UserDefaults.standard.set(false, forKey: enabledKey)
    }
}
