import Foundation

nonisolated enum ProgressionScheme: String, CaseIterable, Sendable, Codable, Identifiable {
    case none = "None"
    case linear = "Linear"
    case doubleProgression = "Double Progression"
    case rpe = "RPE-Based"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .none: "Manually pick weights each session."
        case .linear: "Add a fixed amount each session once you hit the target reps."
        case .doubleProgression: "Add reps until you hit the top of the range, then add weight and drop to the bottom."
        case .rpe: "Adjust weight so the last set hits the target RPE (perceived effort)."
        }
    }
}

nonisolated struct ProgressionSuggestion: Sendable {
    let suggestedWeight: Double
    let suggestedReps: Int
    let note: String
}

nonisolated enum ProgressionEngine: Sendable {
    static func suggestNext(
        scheme: ProgressionScheme,
        lastWeight: Double,
        lastReps: Int,
        targetRepsLow: Int,
        targetRepsHigh: Int,
        incrementLbs: Double = 5,
        hitAllSets: Bool = true,
        lastRPE: Double? = nil,
        targetRPE: Double = 8
    ) -> ProgressionSuggestion {
        switch scheme {
        case .none:
            return ProgressionSuggestion(
                suggestedWeight: lastWeight,
                suggestedReps: lastReps,
                note: "Match last session."
            )

        case .linear:
            if hitAllSets && lastReps >= targetRepsHigh {
                return ProgressionSuggestion(
                    suggestedWeight: lastWeight + incrementLbs,
                    suggestedReps: targetRepsLow,
                    note: "Add \(Int(incrementLbs)) lbs. Drop reps to \(targetRepsLow)."
                )
            } else {
                return ProgressionSuggestion(
                    suggestedWeight: lastWeight,
                    suggestedReps: lastReps,
                    note: "Hit \(targetRepsHigh) reps for all sets to progress."
                )
            }

        case .doubleProgression:
            if hitAllSets && lastReps >= targetRepsHigh {
                return ProgressionSuggestion(
                    suggestedWeight: lastWeight + incrementLbs,
                    suggestedReps: targetRepsLow,
                    note: "Hit the top of the range — bump weight, reset reps."
                )
            } else if lastReps < targetRepsHigh {
                return ProgressionSuggestion(
                    suggestedWeight: lastWeight,
                    suggestedReps: min(lastReps + 1, targetRepsHigh),
                    note: "Try for \(min(lastReps + 1, targetRepsHigh)) reps this session."
                )
            } else {
                return ProgressionSuggestion(
                    suggestedWeight: lastWeight,
                    suggestedReps: lastReps,
                    note: "Repeat last session."
                )
            }

        case .rpe:
            guard let lastRPE else {
                return ProgressionSuggestion(
                    suggestedWeight: lastWeight,
                    suggestedReps: lastReps,
                    note: "Log an RPE to get suggestions."
                )
            }
            let delta = targetRPE - lastRPE
            let adjustment = delta * 2.5
            let newWeight = max(0, (lastWeight + adjustment / 2.5 * incrementLbs).rounded() / 1)
            let rounded = (newWeight / incrementLbs).rounded() * incrementLbs
            let note: String
            if abs(delta) < 0.5 {
                note = "RPE on target — hold weight."
            } else if delta > 0 {
                note = "Last set felt easy. Add \(Int(rounded - lastWeight)) lbs."
            } else {
                note = "Last set was too hard. Drop \(Int(lastWeight - rounded)) lbs."
            }
            return ProgressionSuggestion(
                suggestedWeight: rounded,
                suggestedReps: lastReps,
                note: note
            )
        }
    }
}
