import Foundation
import SwiftUI

/// One-line, structured workout adjustment paired with an adaptive callout.
/// The `summary` is what the brief renders under the conversational body;
/// `kind` + `magnitude` describe how to actually transform today's `ProgramDay`.
nonisolated struct BriefAdjustment: Sendable, Codable, Equatable {
    let summary: String
    let kind: AdjustmentKind
    let magnitude: Double?
}

nonisolated enum AdjustmentKind: String, Sendable, Codable, Equatable {
    /// Halve target set count on every exercise.
    case halveSets
    /// Halve target rep range on every exercise.
    case halveReps
    /// Multiply prescribed/last load by `magnitude` (e.g. 0.6 for a 60% deload).
    case deload
    /// Replace the day with a mobility + zone-2 placeholder (no loaded work).
    case mobilityOnly
    /// Non-training callout — informational only, nothing to apply to the workout.
    case noChange

    var isApplicable: Bool { self != .noChange }
}

/// Tracks the user's accept/skip decision for today's adaptive adjustment and
/// applies the transform to the active `ProgramDay` when accepted.
///
/// Decisions are keyed by calendar day so brief refreshes don't re-prompt.
/// Persisted to `UserDefaults` so the override survives launches.
@MainActor
@Observable
final class AdaptiveAdjustmentService {
    static let shared = AdaptiveAdjustmentService()

    enum DecisionState: String, Codable, Sendable {
        case accepted
        case dismissed
    }

    struct DailyDecision: Codable, Sendable, Equatable {
        let dateKey: String
        let adjustment: BriefAdjustment
        let state: DecisionState
        let decidedAt: Date
    }

    private(set) var todaysDecision: DailyDecision?

    private let storageKey = "adaptive.adjustment.decision.v1"

    private init() {
        load()
    }

    // MARK: - Public API

    /// The current decision for today, if any. Cleared lazily when the day rolls over.
    func decisionForToday() -> DailyDecision? {
        guard let d = todaysDecision else { return nil }
        if d.dateKey != Self.todayKey() {
            todaysDecision = nil
            persist()
            return nil
        }
        return d
    }

    func accept(_ adjustment: BriefAdjustment) {
        todaysDecision = DailyDecision(
            dateKey: Self.todayKey(),
            adjustment: adjustment,
            state: .accepted,
            decidedAt: Date()
        )
        persist()
    }

    func dismiss(_ adjustment: BriefAdjustment) {
        todaysDecision = DailyDecision(
            dateKey: Self.todayKey(),
            adjustment: adjustment,
            state: .dismissed,
            decidedAt: Date()
        )
        persist()
    }

    /// Wipe today's decision so the brief surfaces the callout again.
    func undo() {
        todaysDecision = nil
        persist()
    }

    /// Transparently rewrite today's program days when the user has accepted
    /// an adjustment. Called by `TrainViewModel.todayWorkoutDays`.
    func applyOverrideIfAny(to days: [ProgramDay]) -> [ProgramDay] {
        guard let decision = decisionForToday(),
              decision.state == .accepted,
              decision.adjustment.kind.isApplicable else {
            return days
        }
        return days.map { transform($0, with: decision.adjustment) }
    }

    /// True when today's program is currently rewritten by an accepted adjustment.
    /// Surfaces small "ADJUSTED" badges in the training UI.
    var hasActiveOverride: Bool {
        guard let d = decisionForToday() else { return false }
        return d.state == .accepted && d.adjustment.kind.isApplicable
    }

    // MARK: - Transforms

    private func transform(_ day: ProgramDay, with adjustment: BriefAdjustment) -> ProgramDay {
        var copy = day
        switch adjustment.kind {
        case .halveSets:
            copy.exercises = day.exercises.map { ex in
                var e = ex
                e.targetSets = max(1, Int((Double(ex.targetSets) * 0.5).rounded()))
                return e
            }
        case .halveReps:
            copy.exercises = day.exercises.map { ex in
                var e = ex
                e.targetRepsMin = max(1, Int((Double(ex.targetRepsMin) * 0.5).rounded()))
                e.targetRepsMax = max(e.targetRepsMin, Int((Double(ex.targetRepsMax) * 0.5).rounded()))
                return e
            }
        case .deload:
            let m = adjustment.magnitude ?? 0.6
            copy.exercises = day.exercises.map { ex in
                var e = ex
                if let w = ex.prescribedWeight {
                    e.prescribedWeight = (w * m).rounded()
                }
                // Trim one set so the deload also lowers volume a touch.
                if ex.targetSets > 1 {
                    e.targetSets = max(1, ex.targetSets - 1)
                }
                return e
            }
        case .mobilityOnly:
            // Keep the day shell but drop loaded work — the running workout
            // screen treats an empty exercise list as a mobility / walk session.
            copy.exercises = []
        case .noChange:
            break
        }
        return copy
    }

    // MARK: - Persistence

    private func persist() {
        let defaults = UserDefaults.standard
        if let d = todaysDecision, let data = try? JSONEncoder().encode(d) {
            defaults.set(data, forKey: storageKey)
        } else {
            defaults.removeObject(forKey: storageKey)
        }
    }

    private func load() {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(DailyDecision.self, from: data) else {
            todaysDecision = nil
            return
        }
        if decoded.dateKey == Self.todayKey() {
            todaysDecision = decoded
        } else {
            todaysDecision = nil
            defaults.removeObject(forKey: storageKey)
        }
    }

    static func todayKey(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
