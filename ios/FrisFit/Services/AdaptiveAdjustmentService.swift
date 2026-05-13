import Foundation
import SwiftUI

/// Legacy single-line adjustment kept for backward compatibility with the
/// existing Train view-model override path. New code should use
/// `AdaptiveBundle` / `AdaptiveLine` and read overrides via
/// `AdaptiveAdjustmentService.shared.activeLines(in:)`.
nonisolated struct BriefAdjustment: Sendable, Codable, Equatable {
    let summary: String
    let kind: AdjustmentKind
    let magnitude: Double?
}

nonisolated enum AdjustmentKind: String, Sendable, Codable, Equatable {
    case halveSets
    case halveReps
    case deload
    case mobilityOnly
    case noChange

    var isApplicable: Bool { self != .noChange }
}

/// Tracks per-line accept/skip decisions for today's adaptive bundle and
/// applies the workout transforms to the active `ProgramDay` when accepted.
///
/// Decisions persist to `UserDefaults` keyed by calendar day. Lines remain
/// active until the signal fingerprint clears (auto-revert) or the user undoes
/// the bundle manually.
@MainActor
@Observable
final class AdaptiveAdjustmentService {
    static let shared = AdaptiveAdjustmentService()

    enum LineState: String, Codable, Sendable, Equatable {
        case pending
        case accepted
        case dismissed
    }

    /// Per-line decision row.
    struct LineDecision: Codable, Sendable, Equatable {
        let line: AdaptiveLine
        var state: LineState
        var decidedAt: Date?
    }

    /// All decisions for a given day, keyed by date.
    struct DailyBundleDecision: Codable, Sendable, Equatable {
        let dateKey: String
        let signalFingerprint: String
        let trigger: String
        var decisions: [LineDecision]
    }

    // MARK: - State

    private(set) var bundleDecision: DailyBundleDecision?

    // Legacy decision kept in sync with the workout line so existing
    // call sites that still read `todaysDecision` keep working.
    var todaysDecision: LegacyDailyDecision? {
        guard let bundle = bundleDecisionForToday(),
              let workout = bundle.decisions.first(where: { $0.line.domain == .workout }) else {
            return nil
        }
        let legacy = legacyAdjustment(from: workout.line)
        let state: LegacyDecisionState
        switch workout.state {
        case .accepted: state = .accepted
        case .dismissed: state = .dismissed
        case .pending: return nil
        }
        return LegacyDailyDecision(
            dateKey: bundle.dateKey,
            adjustment: legacy,
            state: state,
            decidedAt: workout.decidedAt ?? Date()
        )
    }

    enum LegacyDecisionState: String, Codable, Sendable { case accepted, dismissed }

    struct LegacyDailyDecision: Codable, Sendable, Equatable {
        let dateKey: String
        let adjustment: BriefAdjustment
        let state: LegacyDecisionState
        let decidedAt: Date
    }

    // Re-exposed for views that referenced the older nested type name.
    typealias DailyDecision = LegacyDailyDecision
    typealias DecisionState = LegacyDecisionState

    private let storageKey = "adaptive.bundle.decision.v1"

    private init() {
        load()
    }

    // MARK: - Bundle ingestion

    /// Called by `AdaptiveSignalsService` whenever it (re)builds the day's
    /// bundle. If the fingerprint matches the stored decision, existing
    /// per-line accept/skip state is preserved. If it changes, the previous
    /// decision is discarded (signal cleared → auto-revert).
    func ingest(bundle: AdaptiveBundle) {
        let today = Self.todayKey()

        if let existing = bundleDecision,
           existing.dateKey == today,
           existing.signalFingerprint == bundle.signalFingerprint {
            // Same signal set — reconcile lines (new ones default to pending,
            // dropped ones are removed, existing keep their state).
            let existingById = Dictionary(uniqueKeysWithValues: existing.decisions.map { ($0.line.id, $0) })
            let merged: [LineDecision] = bundle.lines.map { line in
                if let prior = existingById[line.id] {
                    return LineDecision(line: line, state: prior.state, decidedAt: prior.decidedAt)
                }
                return LineDecision(line: line, state: .pending, decidedAt: nil)
            }
            bundleDecision = DailyBundleDecision(
                dateKey: today,
                signalFingerprint: bundle.signalFingerprint,
                trigger: bundle.trigger,
                decisions: merged
            )
        } else {
            // Fresh bundle (or signal set changed) — replace any prior state.
            guard !bundle.isEmpty else {
                bundleDecision = nil
                persist()
                return
            }
            bundleDecision = DailyBundleDecision(
                dateKey: today,
                signalFingerprint: bundle.signalFingerprint,
                trigger: bundle.trigger,
                decisions: bundle.lines.map { LineDecision(line: $0, state: .pending, decidedAt: nil) }
            )
        }
        persist()
    }

    // MARK: - Lookup

    func bundleDecisionForToday() -> DailyBundleDecision? {
        guard let d = bundleDecision else { return nil }
        if d.dateKey != Self.todayKey() {
            bundleDecision = nil
            persist()
            return nil
        }
        return d
    }

    /// All accepted lines in a given domain that are currently active.
    func activeLines(in domain: AdaptiveDomain) -> [AdaptiveLine] {
        guard let d = bundleDecisionForToday() else { return [] }
        return d.decisions
            .filter { $0.state == .accepted && $0.line.domain == domain }
            .map { $0.line }
    }

    var hasAnyActiveLine: Bool {
        guard let d = bundleDecisionForToday() else { return false }
        return d.decisions.contains { $0.state == .accepted }
    }

    var hasActiveOverride: Bool {
        !activeLines(in: .workout).isEmpty
    }

    // MARK: - Per-line decisions

    func acceptLine(id: String) {
        mutate { decision in
            guard let idx = decision.decisions.firstIndex(where: { $0.line.id == id }) else { return }
            decision.decisions[idx].state = .accepted
            decision.decisions[idx].decidedAt = Date()
        }
    }

    func dismissLine(id: String) {
        mutate { decision in
            guard let idx = decision.decisions.firstIndex(where: { $0.line.id == id }) else { return }
            decision.decisions[idx].state = .dismissed
            decision.decisions[idx].decidedAt = Date()
        }
    }

    func acceptAll() {
        mutate { decision in
            for i in decision.decisions.indices where decision.decisions[i].state == .pending {
                decision.decisions[i].state = .accepted
                decision.decisions[i].decidedAt = Date()
            }
        }
    }

    func dismissAll() {
        mutate { decision in
            for i in decision.decisions.indices where decision.decisions[i].state == .pending {
                decision.decisions[i].state = .dismissed
                decision.decisions[i].decidedAt = Date()
            }
        }
    }

    /// Reset all lines back to pending so the brief surfaces the bundle again.
    func undo() {
        mutate { decision in
            for i in decision.decisions.indices {
                decision.decisions[i].state = .pending
                decision.decisions[i].decidedAt = nil
            }
        }
    }

    private func mutate(_ block: (inout DailyBundleDecision) -> Void) {
        guard var current = bundleDecisionForToday() else { return }
        block(&current)
        bundleDecision = current
        persist()
    }

    // MARK: - Legacy API shims (preserve existing call sites)

    /// Apply currently accepted workout-domain lines to the day's program.
    func applyOverrideIfAny(to days: [ProgramDay]) -> [ProgramDay] {
        let workoutLines = activeLines(in: .workout)
        guard !workoutLines.isEmpty else { return days }
        return days.map { day in
            var copy = day
            for line in workoutLines {
                copy = transform(copy, with: line.kind)
            }
            return copy
        }
    }

    func accept(_ adjustment: BriefAdjustment) {
        // Bridge: if the bundle has a workout line, accept it.
        guard let decision = bundleDecisionForToday() else { return }
        if let workout = decision.decisions.first(where: { $0.line.domain == .workout }) {
            acceptLine(id: workout.line.id)
        }
        _ = adjustment
    }

    func dismiss(_ adjustment: BriefAdjustment) {
        guard let decision = bundleDecisionForToday() else { return }
        if let workout = decision.decisions.first(where: { $0.line.domain == .workout }) {
            dismissLine(id: workout.line.id)
        }
        _ = adjustment
    }

    // MARK: - Workout transforms

    private func transform(_ day: ProgramDay, with kind: AdaptiveLineKind) -> ProgramDay {
        var copy = day
        switch kind {
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
        case .deload(let magnitude):
            copy.exercises = day.exercises.map { ex in
                var e = ex
                if let w = ex.prescribedWeight {
                    e.prescribedWeight = (w * magnitude).rounded()
                }
                if ex.targetSets > 1 {
                    e.targetSets = max(1, ex.targetSets - 1)
                }
                return e
            }
        case .mobilityOnly:
            copy.exercises = []
        case .skipMovementPattern(let pattern):
            let p = pattern.lowercased()
            copy.exercises = day.exercises.filter { !$0.exerciseName.lowercased().contains(p) }
        default:
            break
        }
        return copy
    }

    private func legacyAdjustment(from line: AdaptiveLine) -> BriefAdjustment {
        switch line.kind {
        case .halveSets:
            return BriefAdjustment(summary: line.summary, kind: .halveSets, magnitude: 0.5)
        case .halveReps:
            return BriefAdjustment(summary: line.summary, kind: .halveReps, magnitude: 0.5)
        case .deload(let m):
            return BriefAdjustment(summary: line.summary, kind: .deload, magnitude: m)
        case .mobilityOnly:
            return BriefAdjustment(summary: line.summary, kind: .mobilityOnly, magnitude: nil)
        default:
            return BriefAdjustment(summary: line.summary, kind: .noChange, magnitude: nil)
        }
    }

    // MARK: - Persistence

    private func persist() {
        let defaults = UserDefaults.standard
        if let d = bundleDecision, let data = try? JSONEncoder().encode(d) {
            defaults.set(data, forKey: storageKey)
        } else {
            defaults.removeObject(forKey: storageKey)
        }
    }

    private func load() {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(DailyBundleDecision.self, from: data) else {
            bundleDecision = nil
            return
        }
        if decoded.dateKey == Self.todayKey() {
            bundleDecision = decoded
        } else {
            bundleDecision = nil
            defaults.removeObject(forKey: storageKey)
        }
    }

    static func todayKey(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
