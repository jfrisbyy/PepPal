import SwiftUI

nonisolated enum PrimaryGoal: String, CaseIterable, Identifiable, Sendable, Codable {
    case fatLoss
    case muscleGain
    case recomposition
    case performance
    case longevity
    case recoveryInjury

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fatLoss: "Fat Loss"
        case .muscleGain: "Muscle Gain"
        case .recomposition: "Recomposition"
        case .performance: "Performance"
        case .longevity: "Longevity / Health"
        case .recoveryInjury: "Recovery / Injury"
        }
    }

    var subtitle: String {
        switch self {
        case .fatLoss: "Lower body fat while keeping strength"
        case .muscleGain: "Add lean mass with a controlled surplus"
        case .recomposition: "Build muscle, lose fat at maintenance"
        case .performance: "Train harder, recover faster"
        case .longevity: "Healthspan, biomarkers, daily energy"
        case .recoveryInjury: "Heal an injury, return to training"
        }
    }

    var icon: String {
        switch self {
        case .fatLoss: "arrow.down.right.circle.fill"
        case .muscleGain: "dumbbell.fill"
        case .recomposition: "arrow.triangle.2.circlepath.circle.fill"
        case .performance: "bolt.fill"
        case .longevity: "heart.text.square.fill"
        case .recoveryInjury: "bandage.fill"
        }
    }

    var accent: Color {
        switch self {
        case .fatLoss: PepTheme.teal
        case .muscleGain: PepTheme.amber
        case .recomposition: PepTheme.violet
        case .performance: PepTheme.blue
        case .longevity: Color(red: 80/255, green: 220/255, blue: 180/255)
        case .recoveryInjury: Color(red: 255/255, green: 138/255, blue: 138/255)
        }
    }

    var targetMetricKind: GoalTargetKind {
        switch self {
        case .fatLoss, .muscleGain, .recomposition: .bodyWeight
        case .performance: .performance
        case .longevity, .recoveryInjury: .none
        }
    }
}

nonisolated enum GoalTargetKind: Sendable {
    case bodyWeight
    case performance
    case none
}

nonisolated enum TrainingModality: String, CaseIterable, Identifiable, Sendable, Codable {
    case lifting
    case cardio
    case hybrid
    case sportSpecific

    var id: String { rawValue }
    var label: String {
        switch self {
        case .lifting: "Lifting"
        case .cardio: "Cardio"
        case .hybrid: "Hybrid"
        case .sportSpecific: "Sport-specific"
        }
    }
    var icon: String {
        switch self {
        case .lifting: "dumbbell"
        case .cardio: "figure.run"
        case .hybrid: "figure.cross.training"
        case .sportSpecific: "soccerball"
        }
    }
}

nonisolated enum TrainingExperience: String, CaseIterable, Identifiable, Sendable, Codable {
    case novice
    case intermediate
    case advanced

    var id: String { rawValue }
    var label: String {
        switch self {
        case .novice: "New"
        case .intermediate: "1–3 years"
        case .advanced: "3+ years"
        }
    }
}

nonisolated enum InjuryArea: String, CaseIterable, Identifiable, Sendable, Codable {
    case back
    case shoulder
    case knee
    case hip
    case other

    var id: String { rawValue }
    var label: String {
        switch self {
        case .back: "Back"
        case .shoulder: "Shoulder"
        case .knee: "Knee"
        case .hip: "Hip"
        case .other: "Other"
        }
    }
    var icon: String {
        switch self {
        case .back: "figure.walk"
        case .shoulder: "figure.arms.open"
        case .knee: "figure.run"
        case .hip: "figure.stand"
        case .other: "bandage"
        }
    }
}

nonisolated enum DietStyle: String, CaseIterable, Identifiable, Sendable, Codable {
    case omnivore
    case vegan
    case vegetarian
    case keto
    case iifym
    case other

    var id: String { rawValue }
    var label: String {
        switch self {
        case .omnivore: "Omnivore"
        case .vegan: "Vegan"
        case .vegetarian: "Vegetarian"
        case .keto: "Keto"
        case .iifym: "IIFYM"
        case .other: "Other"
        }
    }
}

nonisolated enum PriorTracker: String, CaseIterable, Identifiable, Sendable, Codable {
    case myFitnessPal
    case cronometer
    case spreadsheet
    case none
    case other

    var id: String { rawValue }
    var label: String {
        switch self {
        case .myFitnessPal: "MyFitnessPal"
        case .cronometer: "Cronometer"
        case .spreadsheet: "Spreadsheet"
        case .none: "Never tracked"
        case .other: "Other"
        }
    }
}

nonisolated struct GoalSmartDefaults: Sendable, Codable, Equatable {
    var calories: Int
    var proteinG: Int
    var carbsG: Int
    var fatG: Int
    var waterMl: Int
    var stepFloor: Int
}

nonisolated enum GoalDefaultsCalculator: Sendable {
    /// Returns the (deficit/surplus multiplier, protein g/kg, fat ratio of calories) for a primary goal.
    static func macroParams(for goal: PrimaryGoal, isMuscleGainOverride: Bool = false) -> (calMultiplier: Double, proteinPerKg: Double, fatRatio: Double) {
        switch goal {
        case .fatLoss: return (0.80, 2.2, 0.25)
        case .muscleGain: return (1.10, 2.2, 0.25)
        case .recomposition: return (1.00, 2.0, 0.25)
        case .performance: return (1.00, 1.8, 0.25)
        case .longevity: return (1.00, 1.6, 0.30)
        case .recoveryInjury: return (1.05, 2.0, 0.30)
        }
    }

    static func compute(
        tdee: Double,
        weightKg: Double,
        goal: PrimaryGoal,
        proteinPerKgOverride: Double?,
        waterMl: Int,
        stepFloor: Int
    ) -> GoalSmartDefaults {
        let params = macroParams(for: goal)
        let calories = max(tdee * params.calMultiplier, 1200)
        let proteinPerKg = proteinPerKgOverride ?? params.proteinPerKg
        let proteinG = proteinPerKg * weightKg
        let proteinCal = proteinG * 4.0
        let fatCal = calories * params.fatRatio
        let fatG = fatCal / 9.0
        let carbCal = max(calories - proteinCal - fatCal, 0)
        let carbsG = carbCal / 4.0
        return GoalSmartDefaults(
            calories: Int(calories.rounded()),
            proteinG: Int(proteinG.rounded()),
            carbsG: Int(carbsG.rounded()),
            fatG: Int(fatG.rounded()),
            waterMl: waterMl,
            stepFloor: stepFloor
        )
    }
}
