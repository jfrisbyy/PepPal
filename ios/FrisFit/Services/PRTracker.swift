import Foundation

@MainActor
final class PRTracker {
    static let shared = PRTracker()
    private init() {}

    private let defaults = UserDefaults.standard

    private func weightKey(_ exerciseId: String) -> String { "pr.weight.\(exerciseId)" }
    private func oneRMKey(_ exerciseId: String) -> String { "pr.1rm.\(exerciseId)" }
    private func volumeKey(_ exerciseId: String) -> String { "pr.volume.\(exerciseId)" }

    struct PRHit: Sendable {
        let kind: Kind
        let exerciseId: String
        let exerciseName: String
        let newValue: Double
        let previousValue: Double

        enum Kind: String, Sendable {
            case weight
            case oneRepMax
            case volume
        }
    }

    func bestWeight(for exerciseId: String) -> Double {
        defaults.double(forKey: weightKey(exerciseId))
    }

    func best1RM(for exerciseId: String) -> Double {
        defaults.double(forKey: oneRMKey(exerciseId))
    }

    func bestVolume(for exerciseId: String) -> Double {
        defaults.double(forKey: volumeKey(exerciseId))
    }

    /// Checks set against stored bests and returns any new PRs.
    @discardableResult
    func checkAndRecord(exerciseId: String, exerciseName: String, weight: Double, reps: Int) -> [PRHit] {
        guard weight > 0, reps > 0 else { return [] }
        var hits: [PRHit] = []

        let prevWeight = bestWeight(for: exerciseId)
        if weight > prevWeight {
            hits.append(PRHit(kind: .weight, exerciseId: exerciseId, exerciseName: exerciseName, newValue: weight, previousValue: prevWeight))
            defaults.set(weight, forKey: weightKey(exerciseId))
        }

        let estimated = StrengthCalculators.estimated1RM(weight: weight, reps: reps)
        let prev1RM = best1RM(for: exerciseId)
        if estimated > prev1RM && estimated - prev1RM >= 1.0 {
            hits.append(PRHit(kind: .oneRepMax, exerciseId: exerciseId, exerciseName: exerciseName, newValue: estimated, previousValue: prev1RM))
            defaults.set(estimated, forKey: oneRMKey(exerciseId))
        }

        let volume = weight * Double(reps)
        let prevVolume = bestVolume(for: exerciseId)
        if volume > prevVolume {
            hits.append(PRHit(kind: .volume, exerciseId: exerciseId, exerciseName: exerciseName, newValue: volume, previousValue: prevVolume))
            defaults.set(volume, forKey: volumeKey(exerciseId))
        }

        return hits
    }
}
