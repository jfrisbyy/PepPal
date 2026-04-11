import Foundation

nonisolated enum BMRCalculator: Sendable {
    static func calculate(
        weightKg: Double,
        heightCm: Double,
        age: Int,
        sex: BiologicalSex
    ) -> Double {
        let base = (10.0 * weightKg) + (6.25 * heightCm) - (5.0 * Double(age))
        switch sex {
        case .male: return base + 5.0
        case .female: return base - 161.0
        }
    }

    static func calculate(profile: UserProfile, latestWeightKg: Double?) -> Double? {
        guard let dob = profile.dateOfBirth,
              let sex = profile.biologicalSex,
              let heightCm = profile.heightCm,
              let weightKg = latestWeightKg else {
            return nil
        }
        let age = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0
        guard age > 0 else { return nil }
        return calculate(weightKg: weightKg, heightCm: heightCm, age: age, sex: sex)
    }

    static func tdee(bmr: Double, activityMultiplier: Double = 1.55) -> Double {
        bmr * activityMultiplier
    }
}
