import Foundation

/// Deterministic cross-domain signal detector for the Daily Brief.
///
/// Scans local stores (sleep, HK recovery, side effects, dose log, bloodwork,
/// RHR/HRV, streak, nutrition) and surfaces 0–3 high-confidence scenarios that
/// the brief must visibly account for. Each signal is rendered into the prompt
/// so the AI weaves it into the narrative and emits a matching `adaptiveCallout`.
@MainActor
struct AdaptiveSignalsService {
    static let shared = AdaptiveSignalsService()

    nonisolated struct Signal: Sendable {
        let kind: Kind
        let trigger: String         // e.g. "Slept 5.1h last night (vs 7.4h avg)"
        let recommendation: String  // e.g. "Cut working sets in half, anchor on form"
        let priority: Int           // higher wins when we have too many

        nonisolated enum Kind: String, Sendable {
            case roughSleep
            case sideEffect
            case missedDose
            case bloodworkShift
            case poorRecovery
            case streakBreak
        }
    }

    /// Build up to 3 signals, sorted by priority (highest first).
    func buildSignals(activeProtocol: PeptideProtocol?) -> [Signal] {
        var out: [Signal] = []
        if let s = roughSleepSignal() { out.append(s) }
        if let s = sideEffectSignal(activeProtocol: activeProtocol) { out.append(s) }
        if let s = missedDoseSignal(activeProtocol: activeProtocol) { out.append(s) }
        if let s = bloodworkShiftSignal() { out.append(s) }
        if let s = poorRecoverySignal() { out.append(s) }
        if let s = streakBreakSignal() { out.append(s) }
        return Array(out.sorted { $0.priority > $1.priority }.prefix(3))
    }

    /// Compact, model-friendly section to splice into the prompt body.
    /// Returns empty string when no signals fire so the prompt stays lean.
    func promptSection(signals: [Signal]) -> String {
        guard !signals.isEmpty else { return "" }
        var lines: [String] = ["ADAPTIVE SIGNALS (deterministic — already validated against the user's data; the brief MUST acknowledge these and surface the top one as adaptiveCallout):"]
        for (idx, s) in signals.enumerated() {
            lines.append("\(idx + 1). [\(s.kind.rawValue)] trigger=\"\(s.trigger)\" → recommendation=\"\(s.recommendation)\"")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Detectors

    private func roughSleepSignal() -> Signal? {
        let hk = HealthKitService.shared
        let manual = SleepLogViewModel.shared.lastNightLog()?.hours ?? 0
        let sleep = hk.sleepHours > 0 ? hk.sleepHours : manual
        guard sleep > 0, sleep < 6.5 else { return nil }
        let store = InsightsDataStore.shared
        let avg = store.sleepCorrelation?.averageSleepHours
        var trigger = "Slept \(String(format: "%.1f", sleep))h last night"
        if let avg, avg > 0 {
            trigger += " (vs \(String(format: "%.1f", avg))h avg)"
        }
        let rec: String
        if sleep < 5 {
            rec = "Recovery-first day. Skip heavy compounds, walk + mobility instead — pushing into a sleep debt rarely banks gains."
        } else {
            rec = "Cut working sets in half and anchor on form. Doing something beats skipping, but lifting to true failure today eats recovery."
        }
        return Signal(kind: .roughSleep, trigger: trigger, recommendation: rec, priority: 80)
    }

    private func sideEffectSignal(activeProtocol: PeptideProtocol?) -> Signal? {
        guard let proto = activeProtocol else { return nil }
        let cutoff = Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
        let recent = proto.sideEffectLog.filter { $0.timestamp >= cutoff }
        guard !recent.isEmpty else { return nil }

        // Pick the most severe / most recent
        let top = recent.sorted { lhs, rhs in
            if lhs.severity != rhs.severity { return lhs.severity > rhs.severity }
            return lhs.timestamp > rhs.timestamp
        }.first!

        let effectLower = top.effect.lowercased()
        let recommendation: String
        if effectLower.contains("nausea") || effectLower.contains("gi") || effectLower.contains("stomach") {
            recommendation = "Keep meals smaller and protein-forward today. Lean on easy-on-the-gut sources (eggs, yogurt, lean ground beef) and split your calories across 4–5 mini meals instead of forcing big plates."
        } else if effectLower.contains("headache") {
            recommendation = "Front-load water and electrolytes before any training. Cap cardio at zone 2 and pull back overhead pressing — vascular load through a headache rarely pays off."
        } else if effectLower.contains("fatigue") || effectLower.contains("tired") {
            recommendation = "Half your normal volume, then reassess. Prioritize the compound lifts and skip accessories if energy doesn't show up."
        } else if effectLower.contains("inject") || effectLower.contains("site") {
            recommendation = "Rotate injection site and avoid loaded movements that compress the area. Warm compress before tonight's dose."
        } else {
            recommendation = "Treat today as a yellow-light day. Maintain logging, soften training intensity by ~20%, and watch whether the effect tracks with dose timing."
        }

        let dayLabel: String
        if Calendar.current.isDateInToday(top.timestamp) { dayLabel = "today" }
        else if Calendar.current.isDateInYesterday(top.timestamp) { dayLabel = "yesterday" }
        else { dayLabel = "in the last 48h" }

        let trigger = "\(top.effect.capitalized) logged \(dayLabel) (severity \(top.severity)/5)"
        return Signal(kind: .sideEffect, trigger: trigger, recommendation: recommendation, priority: 75)
    }

    private func missedDoseSignal(activeProtocol: PeptideProtocol?) -> Signal? {
        guard let proto = activeProtocol, let compound = proto.compounds.first else { return nil }
        let realLogs = proto.doseLog.filter { !$0.wasSkipped }.sorted { $0.timestamp > $1.timestamp }
        guard let last = realLogs.first else { return nil }
        let daysSince = Calendar.current.dateComponents([.day], from: last.timestamp, to: Date()).day ?? 0

        let freq = compound.frequency.lowercased()
        let isWeekly = freq.contains("weekly") || freq.contains("once a week")
        let isDaily = freq.contains("daily") || freq.contains("every day")

        let overdue: Bool
        if isWeekly { overdue = daysSince >= 8 }
        else if isDaily { overdue = daysSince >= 2 }
        else { overdue = daysSince >= 4 }

        guard overdue else { return nil }

        let trigger = "\(compound.compoundName) — \(daysSince)d since last dose (frequency: \(compound.frequency.lowercased()))"
        let recommendation: String
        if isWeekly {
            recommendation = "Re-anchor today: take the dose, then reset the weekly cadence from this point. Expect appetite to return as levels rebuild over the next 48–72h — protein floor matters more than calorie ceiling this stretch."
        } else if isDaily {
            recommendation = "Log today's dose and don't double up to compensate. Use the missed-window data to flag any patterns (travel, schedule) so the next miss doesn't sneak up."
        } else {
            recommendation = "Take today's dose and log it. Watch for appetite/side-effect rebound as levels climb back; nutrition and training stay neutral today."
        }
        return Signal(kind: .missedDose, trigger: trigger, recommendation: recommendation, priority: 70)
    }

    private func bloodworkShiftSignal() -> Signal? {
        guard let interp = InsightsDataStore.shared.bloodworkInterpretation else { return nil }
        guard !interp.flags.isEmpty || interp.providerFlag else { return nil }
        let count = interp.flags.count
        let trigger = interp.providerFlag
            ? "Latest panel flagged for provider review — \(count) value\(count == 1 ? "" : "s") out of range"
            : "\(count) flagged value\(count == 1 ? "" : "s") on latest bloodwork"
        let recommendation = "Don't change protocol off this alone — pull the panel up, share it with your provider, and let this week's training/nutrition stay steady so the next recheck reads clean."
        return Signal(kind: .bloodworkShift, trigger: trigger, recommendation: recommendation, priority: 85)
    }

    private func poorRecoverySignal() -> Signal? {
        let hk = HealthKitService.shared
        guard let score = hk.recoveryScore else {
            // Fallback on RHR alone
            if let rhr = hk.restingHeartRate, rhr > 70 {
                let trigger = "Resting HR elevated at \(Int(rhr)) bpm"
                let recommendation = "Recovery looks taxed — push zone 2 cardio or mobility today and save the heavy session for tomorrow."
                return Signal(kind: .poorRecovery, trigger: trigger, recommendation: recommendation, priority: 50)
            }
            return nil
        }
        guard score < 55 else { return nil }
        var triggerParts: [String] = ["Recovery score \(score)/100"]
        if let hrv = hk.hrv { triggerParts.append("HRV \(Int(hrv))ms") }
        if let rhr = hk.restingHeartRate { triggerParts.append("RHR \(Int(rhr)) bpm") }
        let trigger = triggerParts.joined(separator: " · ")
        let recommendation = "Treat today as a deload. Same exercises, 60% of normal load, leave 2 reps in the tank on every set. Sleep and hydration matter more than the session right now."
        return Signal(kind: .poorRecovery, trigger: trigger, recommendation: recommendation, priority: 65)
    }

    private func streakBreakSignal() -> Signal? {
        let s = StreakManager.shared.streakData
        guard s.missedYesterday, s.currentStreak <= 1 else { return nil }
        let longest = s.longestStreak
        let trigger = longest > 7
            ? "Streak reset after the miss — longest run was \(longest)d"
            : "Streak reset yesterday"
        let recommendation = "Don't chase the lost streak with a hero day. One log — a meal, a walk, a weigh-in — restarts the counter. Consistency rebuilds faster than it ever broke."
        return Signal(kind: .streakBreak, trigger: trigger, recommendation: recommendation, priority: 40)
    }
}
