import Foundation

nonisolated enum StrengthCalculators: Sendable {
    static func epley1RM(weight: Double, reps: Int) -> Double {
        guard reps > 0, weight > 0 else { return 0 }
        if reps == 1 { return weight }
        return weight * (1.0 + Double(reps) / 30.0)
    }

    static func brzycki1RM(weight: Double, reps: Int) -> Double {
        guard reps > 0, weight > 0, reps < 37 else { return 0 }
        if reps == 1 { return weight }
        return weight * 36.0 / (37.0 - Double(reps))
    }

    static func estimated1RM(weight: Double, reps: Int) -> Double {
        let e = epley1RM(weight: weight, reps: reps)
        let b = brzycki1RM(weight: weight, reps: reps)
        if b == 0 { return e }
        return (e + b) / 2.0
    }

    static func percentOf1RM(_ oneRM: Double, percent: Double) -> Double {
        (oneRM * percent / 100.0 * 2).rounded() / 2
    }

    static let standardPlatesLbs: [Double] = [45, 35, 25, 10, 5, 2.5]
    static let standardPlatesKg: [Double] = [20, 15, 10, 5, 2.5, 1.25]

    static func platesPerSide(target: Double, barWeight: Double = 45, inKg: Bool = false) -> [Double] {
        let plates = inKg ? standardPlatesKg : standardPlatesLbs
        let remainingTotal = max(0, target - barWeight)
        var perSide = remainingTotal / 2.0
        var result: [Double] = []
        for plate in plates {
            while perSide >= plate - 0.001 {
                result.append(plate)
                perSide -= plate
            }
        }
        return result
    }
}
