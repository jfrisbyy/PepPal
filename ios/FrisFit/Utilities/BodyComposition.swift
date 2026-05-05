import Foundation

nonisolated enum BodyComposition: Sendable {
    /// US Navy method body fat percentage.
    /// - Parameters:
    ///   - sex: biological sex
    ///   - heightCm: standing height in cm
    ///   - neckCm: neck circumference
    ///   - waistCm: waist circumference (at navel for men, narrowest point for women)
    ///   - hipCm: hip circumference (women only — required)
    /// Returns body fat % or nil if inputs are invalid.
    static func usNavyBodyFat(
        sex: BiologicalSex,
        heightCm: Double,
        neckCm: Double,
        waistCm: Double,
        hipCm: Double?
    ) -> Double? {
        guard heightCm > 0, neckCm > 0, waistCm > 0 else { return nil }
        switch sex {
        case .male:
            let waistMinusNeck = waistCm - neckCm
            guard waistMinusNeck > 0 else { return nil }
            let bf = 495 / (1.0324 - 0.19077 * log10(waistMinusNeck) + 0.15456 * log10(heightCm)) - 450
            return clamp(bf)
        case .female:
            guard let hipCm, hipCm > 0 else { return nil }
            let sum = waistCm + hipCm - neckCm
            guard sum > 0 else { return nil }
            let bf = 495 / (1.29579 - 0.35004 * log10(sum) + 0.22100 * log10(heightCm)) - 450
            return clamp(bf)
        }
    }

    private static func clamp(_ value: Double) -> Double? {
        guard value.isFinite else { return nil }
        return min(max(value, 2), 70)
    }

    /// Katch-McArdle BMR (uses lean body mass, requires body fat %).
    static func katchMcArdleBMR(weightKg: Double, bodyFatPercent: Double) -> Double {
        let leanMass = weightKg * (1.0 - (bodyFatPercent / 100.0))
        return 370 + (21.6 * leanMass)
    }

    /// Daily water target (ml). Baseline 35 ml/kg, adjusted by activity.
    static func dailyWaterMl(weightKg: Double, activity: ActivityLevel) -> Int {
        let base = weightKg * 35.0
        let adjusted: Double
        switch activity {
        case .sedentary: adjusted = base
        case .light: adjusted = base + 250
        case .moderate: adjusted = base + 500
        case .active: adjusted = base + 750
        case .athlete: adjusted = base + 1000
        }
        return Int((adjusted / 50).rounded() * 50)
    }

    /// Daily step floor by activity level.
    static func dailyStepFloor(activity: ActivityLevel) -> Int {
        switch activity {
        case .sedentary: return 6000
        case .light: return 7500
        case .moderate: return 9000
        case .active: return 10000
        case .athlete: return 12000
        }
    }
}
