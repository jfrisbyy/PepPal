import Foundation

/// Deterministic cross-domain signal detector for the Daily Brief.
///
/// Scans local stores (sleep, HK recovery, side effects, dose log, bloodwork,
/// RHR/HRV, streak, nutrition) and emits an `AdaptiveBundle` containing typed
/// per-domain adjustment lines. The bundle is the source of truth — the AI
/// only narrates it.
@MainActor
final class AdaptiveSignalsService {
    static let shared = AdaptiveSignalsService()
    private init() {}

    nonisolated struct Signal: Sendable {
        let kind: Kind
        let trigger: String
        let recommendation: String
        let priority: Int
        let lines: [AdaptiveLine]

        /// Legacy single-line shim used by the brief header until the bundle UI
        /// fully replaces it. Returns the workout line if there is one,
        /// otherwise a `.noChange` adjustment with the signal recommendation.
        var adjustment: BriefAdjustment {
            if let workout = lines.first(where: { $0.domain == .workout }) {
                switch workout.kind {
                case .halveSets:
                    return BriefAdjustment(summary: workout.summary, kind: .halveSets, magnitude: 0.5)
                case .halveReps:
                    return BriefAdjustment(summary: workout.summary, kind: .halveReps, magnitude: 0.5)
                case .deload(let m):
                    return BriefAdjustment(summary: workout.summary, kind: .deload, magnitude: m)
                case .mobilityOnly:
                    return BriefAdjustment(summary: workout.summary, kind: .mobilityOnly, magnitude: nil)
                default:
                    return BriefAdjustment(summary: workout.summary, kind: .noChange, magnitude: nil)
                }
            }
            return BriefAdjustment(summary: recommendation, kind: .noChange, magnitude: nil)
        }

        nonisolated enum Kind: String, Sendable {
            case roughSleep
            case sideEffect
            case missedDose
            case bloodworkShift
            case poorRecovery
            case streakBreak
            case borrowedProtocol
        }
    }

    // MARK: - Cached top signal for today

    private(set) var todaysTopSignal: Signal? = nil
    private(set) var todaysTopSignalDateKey: String = ""

    static func todayKey(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    func topSignalForToday() -> Signal? {
        guard todaysTopSignalDateKey == Self.todayKey() else { return nil }
        return todaysTopSignal
    }

    /// Build up to 3 signals, sorted by priority (highest first), and ingest
    /// the merged bundle into `AdaptiveAdjustmentService` so per-line decisions
    /// reconcile against any prior state from earlier today.
    func buildSignals(activeProtocol: PeptideProtocol?) -> [Signal] {
        var out: [Signal] = []
        if let s = roughSleepSignal() { out.append(s) }
        if let s = sideEffectSignal(activeProtocol: activeProtocol) { out.append(s) }
        if let s = missedDoseSignal(activeProtocol: activeProtocol) { out.append(s) }
        if let s = bloodworkShiftSignal() { out.append(s) }
        if let s = poorRecoverySignal() { out.append(s) }
        if let s = streakBreakSignal() { out.append(s) }
        if let s = borrowedProtocolSignal(activeProtocol: activeProtocol) { out.append(s) }
        let sorted = Array(out.sorted { $0.priority > $1.priority }.prefix(3))
        todaysTopSignalDateKey = Self.todayKey()
        todaysTopSignal = sorted.first

        // Ingest the merged bundle so the brief strip + domain VMs see it.
        let bundle = makeBundle(from: sorted)
        AdaptiveAdjustmentService.shared.ingest(bundle: bundle)

        return sorted
    }

    /// Merge each signal's lines into a single bundle, de-duplicating by line.id
    /// (later signals don't override earlier higher-priority lines). Workout
    /// lines come first, then nutrition, water, steps, dose, sleep, info.
    private func makeBundle(from signals: [Signal]) -> AdaptiveBundle {
        var seen = Set<String>()
        var merged: [AdaptiveLine] = []
        for s in signals {
            for line in s.lines where !seen.contains(line.id) {
                seen.insert(line.id)
                merged.append(line)
            }
        }
        // Stable order by domain rank.
        let rank: [AdaptiveDomain: Int] = [
            .workout: 0, .nutrition: 1, .water: 2, .steps: 3, .dose: 4, .sleep: 5, .info: 6
        ]
        merged.sort { (rank[$0.domain] ?? 99) < (rank[$1.domain] ?? 99) }

        let fingerprint = signals.map { $0.kind.rawValue }.sorted().joined(separator: "|")
        let trigger = signals.first?.trigger ?? ""
        return AdaptiveBundle(signalFingerprint: fingerprint, trigger: trigger, lines: merged)
    }

    /// Compact, model-friendly section to splice into the prompt body.
    /// Always includes baseline targets so the AI can connect dots across domains.
    func promptSection(signals: [Signal]) -> String {
        var lines: [String] = []
        lines.append("TODAY'S CONTEXT (baseline targets + live data — use this to weave a one-sentence \"why\" into the brief body when adjustments fire):")
        lines.append(contextBlock())

        guard !signals.isEmpty else { return lines.joined(separator: "\n") }

        lines.append("")
        lines.append("ADAPTIVE BUNDLE (deterministic — already validated; the brief MUST acknowledge these in the body and emit the top one as adaptiveCallout. Do NOT invent extra changes; only narrate these lines):")
        for (idx, s) in signals.enumerated() {
            lines.append("\(idx + 1). [\(s.kind.rawValue)] trigger=\"\(s.trigger)\" rationale=\"\(s.recommendation)\"")
            for l in s.lines {
                lines.append("   · \(l.domain.rawValue): \(l.summary)")
            }
        }
        return lines.joined(separator: "\n")
    }

    /// Pulls baseline daily targets + current vitals into a compact block.
    private func contextBlock() -> String {
        var rows: [String] = []
        let hk = HealthKitService.shared
        let water = WaterViewModel.shared
        let nutritionTarget = NutritionViewModel.shared.dailyTarget
        let stepGoal = UserDefaults.standard.integer(forKey: "step_goal")
        let effectiveStepGoal = stepGoal > 0 ? stepGoal : 10000

        rows.append("· water goal: \(water.dailyGoalMl)ml")
        rows.append("· step goal: \(effectiveStepGoal)")
        rows.append("· macros target: \(nutritionTarget.calories)kcal / \(nutritionTarget.protein)g P / \(nutritionTarget.carbs)g C / \(nutritionTarget.fat)g F")
        if hk.sleepHours > 0 {
            rows.append(String(format: "· last night sleep: %.1fh", hk.sleepHours))
        }
        if let hrv = hk.hrv { rows.append("· HRV: \(Int(hrv))ms") }
        if let rhr = hk.restingHeartRate { rows.append("· RHR: \(Int(rhr)) bpm") }
        if let recovery = hk.recoveryScore { rows.append("· recovery score: \(recovery)/100") }
        return rows.joined(separator: "\n")
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
        var lines: [AdaptiveLine] = []
        if sleep < 5 {
            rec = "Recovery-first day. Skip heavy compounds, walk + mobility instead — pushing into a sleep debt rarely banks gains."
            lines.append(AdaptiveLine(id: "roughSleep.workout", domain: .workout,
                summary: "Swap today's lifts for mobility + zone 2 walk", kind: .mobilityOnly))
        } else {
            rec = "Cut working sets in half and anchor on form. Doing something beats skipping, but lifting to true failure today eats recovery."
            lines.append(AdaptiveLine(id: "roughSleep.workout", domain: .workout,
                summary: "Halve working sets on today's lifts", kind: .halveSets))
        }
        // Cross-domain pile-ons.
        let proteinFloor = Int(Double(NutritionViewModel.shared.dailyTarget.protein) * 1.05)
        lines.append(AdaptiveLine(id: "roughSleep.nutrition", domain: .nutrition,
            summary: "Protein floor \(proteinFloor)g · prioritize whole-food sources",
            kind: .proteinFloor(grams: proteinFloor)))
        return Signal(kind: .roughSleep, trigger: trigger, recommendation: rec, priority: 80, lines: lines)
    }

    private func sideEffectSignal(activeProtocol: PeptideProtocol?) -> Signal? {
        guard let proto = activeProtocol else { return nil }
        let cutoff = Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
        let recent = proto.sideEffectLog.filter { $0.timestamp >= cutoff }
        guard !recent.isEmpty else { return nil }

        let top = recent.sorted { lhs, rhs in
            if lhs.severity != rhs.severity { return lhs.severity > rhs.severity }
            return lhs.timestamp > rhs.timestamp
        }.first!

        let effectLower = top.effect.lowercased()
        let recommendation: String
        var lines: [AdaptiveLine] = []
        if effectLower.contains("nausea") || effectLower.contains("gi") || effectLower.contains("stomach") {
            recommendation = "Keep meals smaller and protein-forward today. Lean on easy-on-the-gut sources and split your calories across 4–5 mini meals."
            lines.append(AdaptiveLine(id: "sideEffect.workout", domain: .workout,
                summary: "Deload to 80% load today", kind: .deload(magnitude: 0.8)))
            lines.append(AdaptiveLine(id: "sideEffect.nutrition", domain: .nutrition,
                summary: "Small frequent meals · easy on the gut", kind: .smallFrequentMeals))
            let carbCap = max(120, NutritionViewModel.shared.dailyTarget.carbs - 60)
            lines.append(AdaptiveLine(id: "sideEffect.carbs", domain: .nutrition,
                summary: "Ease carbs to \(carbCap)g", kind: .carbCeiling(grams: carbCap)))
            lines.append(AdaptiveLine(id: "sideEffect.steps", domain: .steps,
                summary: "Cap steps at 6,000 today", kind: .stepCap(steps: 6000)))
        } else if effectLower.contains("headache") {
            recommendation = "Front-load water and electrolytes before any training. Cap cardio at zone 2 and pull back overhead pressing."
            lines.append(AdaptiveLine(id: "sideEffect.workout", domain: .workout,
                summary: "Skip overhead pressing today", kind: .skipMovementPattern("overhead")))
            lines.append(AdaptiveLine(id: "sideEffect.water", domain: .water,
                summary: "Bump water +750ml today", kind: .waterDelta(ml: 750)))
            lines.append(AdaptiveLine(id: "sideEffect.electrolytes", domain: .nutrition,
                summary: "Add an electrolyte serving before training", kind: .electrolyteNudge))
        } else if effectLower.contains("fatigue") || effectLower.contains("tired") {
            recommendation = "Half your normal volume, then reassess. Prioritize the compound lifts and skip accessories if energy doesn't show up."
            lines.append(AdaptiveLine(id: "sideEffect.workout", domain: .workout,
                summary: "Halve volume · compound lifts only", kind: .halveSets))
            lines.append(AdaptiveLine(id: "sideEffect.water", domain: .water,
                summary: "Bump water +500ml", kind: .waterDelta(ml: 500)))
        } else if effectLower.contains("inject") || effectLower.contains("site") {
            recommendation = "Rotate injection site and avoid loaded movements that compress the area."
            lines.append(AdaptiveLine(id: "sideEffect.workout", domain: .workout,
                summary: "Soften intensity 20% around the injection site", kind: .deload(magnitude: 0.8)))
        } else {
            recommendation = "Treat today as a yellow-light day. Maintain logging, soften training intensity by ~20%."
            lines.append(AdaptiveLine(id: "sideEffect.workout", domain: .workout,
                summary: "Yellow-light day · soften intensity 20%", kind: .deload(magnitude: 0.8)))
        }

        let dayLabel: String
        if Calendar.current.isDateInToday(top.timestamp) { dayLabel = "today" }
        else if Calendar.current.isDateInYesterday(top.timestamp) { dayLabel = "yesterday" }
        else { dayLabel = "in the last 48h" }
        let trigger = "\(top.effect.capitalized) logged \(dayLabel) (severity \(top.severity)/5)"
        return Signal(kind: .sideEffect, trigger: trigger, recommendation: recommendation, priority: 75, lines: lines)
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
        var lines: [AdaptiveLine] = []
        if isWeekly {
            recommendation = "Re-anchor today: take the dose, then reset the weekly cadence from this point. Expect appetite to rebuild over 48–72h — protein floor matters more than calorie ceiling this stretch."
            lines.append(AdaptiveLine(id: "missedDose.reanchor", domain: .dose,
                summary: "Re-anchor weekly cadence tonight", kind: .doseReanchorTonight))
            let floor = Int(Double(NutritionViewModel.shared.dailyTarget.protein) * 1.1)
            lines.append(AdaptiveLine(id: "missedDose.protein", domain: .nutrition,
                summary: "Protein floor \(floor)g for the next 72h", kind: .proteinFloor(grams: floor)))
        } else if isDaily {
            recommendation = "Log today's dose and don't double up to compensate. Use the missed-window data to spot patterns."
            lines.append(AdaptiveLine(id: "missedDose.holdDouble", domain: .dose,
                summary: "Don't double up · take today's dose only", kind: .doseHoldNoDoubleUp))
        } else {
            recommendation = "Take today's dose and log it. Watch for appetite/side-effect rebound; training stays neutral today."
            lines.append(AdaptiveLine(id: "missedDose.reanchor", domain: .dose,
                summary: "Re-anchor your cadence tonight", kind: .doseReanchorTonight))
        }
        return Signal(kind: .missedDose, trigger: trigger, recommendation: recommendation, priority: 70, lines: lines)
    }

    private func bloodworkShiftSignal() -> Signal? {
        guard let interp = InsightsDataStore.shared.bloodworkInterpretation else { return nil }
        guard !interp.flags.isEmpty || interp.providerFlag else { return nil }
        let count = interp.flags.count
        let trigger = interp.providerFlag
            ? "Latest panel flagged for provider review — \(count) value\(count == 1 ? "" : "s") out of range"
            : "\(count) flagged value\(count == 1 ? "" : "s") on latest bloodwork"
        let recommendation = "Don't change protocol off this alone — pull the panel up, share it with your provider, and let this week's training/nutrition stay steady so the next recheck reads clean."
        let line = AdaptiveLine(id: "bloodwork.hold", domain: .info,
            summary: "Hold training & nutrition steady through next recheck", kind: .info)
        return Signal(kind: .bloodworkShift, trigger: trigger, recommendation: recommendation, priority: 85, lines: [line])
    }

    private func poorRecoverySignal() -> Signal? {
        let hk = HealthKitService.shared
        guard let score = hk.recoveryScore else {
            if let rhr = hk.restingHeartRate, rhr > 70 {
                let trigger = "Resting HR elevated at \(Int(rhr)) bpm"
                let recommendation = "Recovery looks taxed — push zone 2 cardio or mobility today and save the heavy session for tomorrow."
                let lines: [AdaptiveLine] = [
                    AdaptiveLine(id: "poorRecovery.workout", domain: .workout,
                        summary: "Swap today's lifts for zone 2 + mobility", kind: .mobilityOnly),
                    AdaptiveLine(id: "poorRecovery.water", domain: .water,
                        summary: "Bump water +500ml today", kind: .waterDelta(ml: 500)),
                    AdaptiveLine(id: "poorRecovery.sleep", domain: .sleep,
                        summary: "Wind down by 10:00pm tonight", kind: .windDown(hour: 22, minute: 0))
                ]
                return Signal(kind: .poorRecovery, trigger: trigger, recommendation: recommendation, priority: 50, lines: lines)
            }
            return nil
        }
        guard score < 55 else { return nil }
        var triggerParts: [String] = ["Recovery score \(score)/100"]
        if let hrv = hk.hrv { triggerParts.append("HRV \(Int(hrv))ms") }
        if let rhr = hk.restingHeartRate { triggerParts.append("RHR \(Int(rhr)) bpm") }
        let trigger = triggerParts.joined(separator: " · ")
        let recommendation = "Treat today as a deload. Same exercises, 60% of normal load, leave 2 reps in the tank on every set. Sleep and hydration matter more than the session right now."
        let lines: [AdaptiveLine] = [
            AdaptiveLine(id: "poorRecovery.workout", domain: .workout,
                summary: "Deload to 60% load · same exercises, 2 RIR", kind: .deload(magnitude: 0.6)),
            AdaptiveLine(id: "poorRecovery.steps", domain: .steps,
                summary: "Cap steps at 8,000", kind: .stepCap(steps: 8000)),
            AdaptiveLine(id: "poorRecovery.water", domain: .water,
                summary: "Bump water +500ml", kind: .waterDelta(ml: 500)),
            AdaptiveLine(id: "poorRecovery.sleep", domain: .sleep,
                summary: "Wind down by 9:45pm tonight", kind: .windDown(hour: 21, minute: 45))
        ]
        return Signal(kind: .poorRecovery, trigger: trigger, recommendation: recommendation, priority: 65, lines: lines)
    }

    /// Fires when the active protocol carries a "borrowed from" marker (name
    /// or a dose-log note). Source of truth for the Shayla demo persona; will
    /// also fire for any real protocol the user explicitly borrows from a peer.
    private func borrowedProtocolSignal(activeProtocol: PeptideProtocol?) -> Signal? {
        guard let proto = activeProtocol else { return nil }
        let nameMatch = proto.name.localizedCaseInsensitiveContains("borrowed")
        let noteMatch = proto.doseLog.contains { ($0.notes ?? "").localizedCaseInsensitiveContains("borrow") }
        guard nameMatch || noteMatch else { return nil }

        let lead = proto.compounds.first
        let doseStr: String
        if let lead {
            let mg = lead.doseMcg / 1000.0
            doseStr = mg >= 1 ? String(format: "%.0f mg", mg) : String(format: "%.0f mcg", lead.doseMcg)
        } else {
            doseStr = "current dose"
        }
        let compoundLabel = lead?.compoundName ?? "the stack"
        let trigger = "Borrowed protocol — \(compoundLabel) running at \(doseStr) (half of source)"
        let recommendation = "Hold the conservative ramp for two more weeks. Re-check labs and recovery before you talk about matching the source dose — your data is the filter, not the screenshot."
        let lines: [AdaptiveLine] = [
            AdaptiveLine(id: "borrowed.dose", domain: .dose,
                summary: "Hold half-dose for 2 more weeks before any bump",
                kind: .doseHoldNoDoubleUp),
            AdaptiveLine(id: "borrowed.info", domain: .info,
                summary: "Re-check labs + recovery before matching source dose",
                kind: .info)
        ]
        return Signal(kind: .borrowedProtocol, trigger: trigger, recommendation: recommendation, priority: 78, lines: lines)
    }

    private func streakBreakSignal() -> Signal? {
        let s = StreakManager.shared.streakData
        guard s.missedYesterday, s.currentStreak <= 1 else { return nil }
        let longest = s.longestStreak
        let trigger = longest > 7
            ? "Streak reset after the miss — longest run was \(longest)d"
            : "Streak reset yesterday"
        let recommendation = "Don't chase the lost streak with a hero day. One log — a meal, a walk, a weigh-in — restarts the counter. Consistency rebuilds faster than it ever broke."
        let line = AdaptiveLine(id: "streak.info", domain: .info,
            summary: "One small log restarts the streak — no hero day", kind: .info)
        return Signal(kind: .streakBreak, trigger: trigger, recommendation: recommendation, priority: 40, lines: [line])
    }
}
