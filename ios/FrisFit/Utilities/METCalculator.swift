import Foundation

nonisolated enum METCalculator: Sendable {

    struct METEntry: Sendable {
        let low: Double
        let moderate: Double
        let high: Double
        let vigorous: Double

        func forIntensity(_ intensity: Int) -> Double {
            switch intensity {
            case 1...3: return low
            case 4...5: return moderate
            case 6...7: return high
            case 8...10: return vigorous
            default: return moderate
            }
        }
    }

    static let sportMETs: [String: METEntry] = [
        "strength": METEntry(low: 3.5, moderate: 5.0, high: 6.0, vigorous: 6.0),
        "weight_training": METEntry(low: 3.5, moderate: 5.0, high: 6.0, vigorous: 6.0),
        "Running": METEntry(low: 6.0, moderate: 8.3, high: 10.0, vigorous: 12.8),
        "Cycling": METEntry(low: 4.0, moderate: 6.8, high: 8.0, vigorous: 10.0),
        "Swimming": METEntry(low: 4.8, moderate: 5.8, high: 8.0, vigorous: 9.8),
        "Basketball": METEntry(low: 4.5, moderate: 6.5, high: 8.0, vigorous: 8.0),
        "Soccer": METEntry(low: 5.0, moderate: 7.0, high: 10.0, vigorous: 10.0),
        "Tennis": METEntry(low: 4.0, moderate: 5.0, high: 7.3, vigorous: 8.0),
        "Football": METEntry(low: 5.0, moderate: 8.0, high: 8.0, vigorous: 8.0),
        "Baseball": METEntry(low: 3.5, moderate: 5.0, high: 5.0, vigorous: 5.0),
        "Walking": METEntry(low: 2.5, moderate: 3.5, high: 4.3, vigorous: 5.0),
        "Hiking": METEntry(low: 4.0, moderate: 5.3, high: 6.5, vigorous: 7.8),
        "Yoga": METEntry(low: 2.0, moderate: 2.5, high: 4.0, vigorous: 4.0),
        "HIIT": METEntry(low: 6.0, moderate: 8.0, high: 10.0, vigorous: 12.0),
        "Dancing": METEntry(low: 3.0, moderate: 4.8, high: 6.5, vigorous: 7.8),
        "Rowing": METEntry(low: 3.5, moderate: 4.8, high: 7.0, vigorous: 8.5),
        "Elliptical": METEntry(low: 4.0, moderate: 5.0, high: 6.0, vigorous: 7.0),
        "Jump Rope": METEntry(low: 8.8, moderate: 10.0, high: 11.8, vigorous: 12.3),
        "Stretching": METEntry(low: 2.0, moderate: 2.3, high: 2.5, vigorous: 2.5),
        "Yard Work": METEntry(low: 3.0, moderate: 4.0, high: 5.5, vigorous: 6.3),
        "Stair Climbing": METEntry(low: 4.0, moderate: 6.0, high: 8.8, vigorous: 9.0),
        "Boxing": METEntry(low: 5.5, moderate: 7.8, high: 9.0, vigorous: 12.8),
        "Martial Arts": METEntry(low: 5.0, moderate: 6.8, high: 10.3, vigorous: 10.3),
        "Pilates": METEntry(low: 2.5, moderate: 3.0, high: 4.0, vigorous: 4.0),
        "Rock Climbing": METEntry(low: 5.0, moderate: 5.8, high: 7.5, vigorous: 8.0),
    ]

    static let defaultMET = METEntry(low: 3.0, moderate: 4.5, high: 6.0, vigorous: 7.5)

    static func caloriesBurned(
        sport: String?,
        workoutType: String?,
        durationMinutes: Int,
        weightKg: Double,
        intensity: Int = 5
    ) -> Int {
        let key = sport ?? workoutType ?? "strength"
        let entry = sportMETs[key] ?? defaultMET
        let met = entry.forIntensity(intensity)
        let hours = Double(durationMinutes) / 60.0
        return Int(met * weightKg * hours)
    }

    static func caloriesBurned(
        metValue: Double,
        durationMinutes: Int,
        weightKg: Double
    ) -> Int {
        let hours = Double(durationMinutes) / 60.0
        return Int(metValue * weightKg * hours)
    }

    static var availableActivities: [String] {
        sportMETs.keys.sorted()
    }
}
