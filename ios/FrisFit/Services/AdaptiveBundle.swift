import Foundation

/// A single, typed adjustment line that targets one domain of the user's day.
///
/// Lines are the atomic unit the user accepts or skips in the daily brief.
/// Each line carries:
///   - `summary`: the short, user-facing string rendered in the pulsing strip
///   - `kind` + `payload`: the structured rewrite the rest of the app reads
///     through `AdaptiveAdjustmentService.shared.activeLines(in:)`
nonisolated struct AdaptiveLine: Sendable, Codable, Equatable, Identifiable {
    let id: String              // stable id per (signal, domain) — used for per-line decisions
    let domain: AdaptiveDomain
    let summary: String
    let kind: AdaptiveLineKind

    init(id: String, domain: AdaptiveDomain, summary: String, kind: AdaptiveLineKind) {
        self.id = id
        self.domain = domain
        self.summary = summary
        self.kind = kind
    }
}

nonisolated enum AdaptiveDomain: String, Sendable, Codable, Equatable, CaseIterable {
    case workout
    case nutrition
    case water
    case steps
    case dose
    case sleep
    case info       // no rewrite — informational only (bloodwork hold, streak)
}

/// Typed payload per domain. The view layer reads only the cases relevant to
/// its surface (e.g. WaterViewModel reads `.waterDelta`).
nonisolated enum AdaptiveLineKind: Sendable, Codable, Equatable {
    // Workout
    case halveSets
    case halveReps
    case deload(magnitude: Double)
    case mobilityOnly
    case skipMovementPattern(String)        // e.g. "overhead"

    // Nutrition
    case proteinFloor(grams: Int)
    case carbCeiling(grams: Int)
    case calorieDelta(kcal: Int)
    case smallFrequentMeals
    case electrolyteNudge

    // Water (delta added to baseline goal, in ml; positive = bump, negative = ease)
    case waterDelta(ml: Int)

    // Steps (absolute cap or raise; nil = no change to that direction)
    case stepCap(steps: Int)
    case stepRaise(steps: Int)

    // Dose
    case doseHoldNoDoubleUp
    case doseShiftWindowEarlier
    case doseReanchorTonight

    // Sleep — wind down by this clock hour:minute (24h) tonight
    case windDown(hour: Int, minute: Int)

    // Info-only
    case info
}

/// A user-visible bundle of one or more `AdaptiveLine`s, all driven by the
/// same set of deterministic signals fired today.
nonisolated struct AdaptiveBundle: Sendable, Codable, Equatable {
    /// Stable fingerprint of the firing signals (e.g. "roughSleep|sideEffect").
    /// Used to detect when the underlying signal set clears so we can auto-revert.
    let signalFingerprint: String
    /// Short trigger phrase used in the brief strip header (e.g. "Slept 5.1h vs 7.4h avg").
    let trigger: String
    /// The lines, ordered by priority (workout first, then nutrition/water/steps, etc.).
    let lines: [AdaptiveLine]

    var isEmpty: Bool { lines.isEmpty }
}
