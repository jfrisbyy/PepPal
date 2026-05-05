import Foundation
import HealthKit

/// Runs cross-domain correlations on the user's data and writes findings to
/// AIMemoryStore as patterns/correlations. Uses local math first (cheap,
/// deterministic), then optionally enriches the most important finding with a
/// natural-language explanation via the fast AI tier.
@MainActor
final class CorrelationEngine {
    static let shared = CorrelationEngine()

    private let lastRunKey = "correlation_engine_last_run"
    private let refreshInterval: TimeInterval = 5 * 24 * 60 * 60 // 5 days

    private init() {}

    var lastRun: Date? {
        UserDefaults.standard.object(forKey: lastRunKey) as? Date
    }

    func shouldRun(force: Bool = false) -> Bool {
        if force { return true }
        guard let last = lastRun else { return true }
        return Date().timeIntervalSince(last) >= refreshInterval
    }

    /// Run all correlations, upsert results to memory. Safe to call often —
    /// respects `shouldRun` unless forced.
    @discardableResult
    func run(force: Bool = false) async -> [AIMemoryFact] {
        guard shouldRun(force: force) else { return [] }
        UserDefaults.standard.set(Date(), forKey: lastRunKey)

        var facts: [AIMemoryFact] = []

        facts.append(contentsOf: await correlateSleepVsTraining())
        facts.append(contentsOf: await correlateDoseDays())
        facts.append(contentsOf: correlateProteinVsWeight())
        facts.append(contentsOf: correlateProgressionStalls())

        AIMemoryStore.shared.upsertMany(facts)
        await generateJourneyAnnotations()
        return facts
    }

    // MARK: - Journey Map agent annotations

    /// Examines journey events + correlations and writes lane=.agentAnnotation
    /// pins onto the timeline. Each annotation is dedup'd by kind — we won't
    /// re-fire the same kind within the same 14-day window.
    func generateJourneyAnnotations() async {
        let service = JourneyEventService.shared
        let now = Date()
        let cal = Calendar.current
        let dedupeWindow: TimeInterval = 14 * 86400

        let existing = service.events.filter { $0.lane == .agentAnnotation }
        func recentlyFired(_ kind: String) -> Bool {
            existing.contains { $0.payload?.annotationKind == kind && now.timeIntervalSince($0.timestamp) < dedupeWindow }
        }

        // 1. Plateau detected — weight unchanged 14+ days during fat loss.
        if !recentlyFired("plateau_detected") {
            let bodyEvents = service.events(in: .body)
                .compactMap { e -> (Date, Double)? in
                    guard let w = e.payload?.weightLbs, w > 0 else { return nil }
                    return (e.timestamp, w)
                }
                .sorted { $0.0 > $1.0 }
            if bodyEvents.count >= 3 {
                let recent = Array(bodyEvents.prefix(5))
                let firstDate = recent.last!.0
                let span = now.timeIntervalSince(firstDate) / 86400
                let weights = recent.map(\.1)
                let spread = (weights.max() ?? 0) - (weights.min() ?? 0)
                let isFatLoss = (InsightsDataStore.shared.targetWeight > 0
                                 && InsightsDataStore.shared.targetWeight < weights.last!)
                if span >= 14, spread < 1.5, isFatLoss {
                    autoAddAnnotation(
                        kind: "plateau_detected",
                        targetLane: .body,
                        title: "Plateau detected",
                        reasoning: "Weight has held within \(String(format: "%.1f", spread)) lb across the last \(recent.count) entries spanning \(Int(span)) days. Plateaus during fat loss are normal — a refeed day, sleep audit, or step bump usually breaks them.",
                        timestamp: now
                    )
                }
            }
        }

        // 2. Sleep dropped during this cycle.
        let cycles = service.events(in: .compounds).filter { ($0.durationDays ?? 0) > 0 }
        let activeCycle = cycles.first { c in
            let end = c.endDate ?? c.timestamp
            return c.timestamp <= now && end >= now
        }
        if let cycle = activeCycle, !recentlyFired("sleep_dropped_in_cycle") {
            let hk = HealthKitService.shared
            if hk.isAvailable, hk.isAuthorized {
                let sleepHistory = await hk.fetchSleepHistory(days: 60)
                let pre = sleepHistory.filter { $0.date < cycle.timestamp }
                let inCycle = sleepHistory.filter { $0.date >= cycle.timestamp }
                if pre.count >= 5, inCycle.count >= 5 {
                    let avgPre = pre.map(\.asleepHours).reduce(0, +) / Double(pre.count)
                    let avgIn = inCycle.map(\.asleepHours).reduce(0, +) / Double(inCycle.count)
                    if avgPre > 0 {
                        let drop = (avgPre - avgIn) / avgPre * 100
                        if drop >= 10 {
                            autoAddAnnotation(
                                kind: "sleep_dropped_in_cycle",
                                targetLane: .compounds,
                                title: "Sleep dropped during this cycle",
                                reasoning: "Average sleep is \(String(format: "%.1f", avgIn))h since \(cycle.payload?.compoundName ?? "this cycle") started, down from \(String(format: "%.1f", avgPre))h before — a \(Int(drop))% drop. Some peptides shift sleep architecture; protein and dose timing can help.",
                                timestamp: now
                            )
                        }
                    }
                }
            }
        }

        // 3. First PR after starting protocol.
        if let cycle = cycles.sorted(by: { $0.timestamp > $1.timestamp }).first,
           !recentlyFired("first_pr_after_protocol") {
            let history = InsightsDataStore.shared.workoutHistory.sorted { $0.date < $1.date }
            let prCutoff = cycle.timestamp
            let after = history.filter { $0.date >= prCutoff && $0.date <= cal.date(byAdding: .day, value: 30, to: prCutoff)! }
            let before = history.filter { $0.date < prCutoff }
            var prHits: [(name: String, weight: Double)] = []
            for w in after {
                for ex in w.exercises {
                    let best = ex.sets.map(\.weight).max() ?? 0
                    let priorBest = before.flatMap { $0.exercises.filter { $0.exerciseName == ex.exerciseName } }
                        .flatMap(\.sets).map(\.weight).max() ?? 0
                    if best > priorBest, best > 0, priorBest > 0 {
                        prHits.append((ex.exerciseName, best))
                    }
                }
            }
            if let pr = prHits.first {
                autoAddAnnotation(
                    kind: "first_pr_after_protocol",
                    targetLane: .training,
                    title: "First PR since starting \(cycle.payload?.compoundName ?? "this protocol")",
                    reasoning: "You hit a new working-weight high on \(pr.name) at \(Int(pr.weight)) lb within 30 days of starting \(cycle.payload?.compoundName ?? "the protocol"). \(prHits.count > 1 ? "And \(prHits.count - 1) other lifts moved up too." : "") Worth noting in your training log.",
                    timestamp: now
                )
            }
        }

        // 4. Side effect cluster — 3+ in a 7-day window.
        if let proto = InsightsDataStore.shared.primaryProtocol,
           !recentlyFired("side_effect_cluster") {
            let recent = proto.sideEffectLog.filter { now.timeIntervalSince($0.timestamp) < 7 * 86400 }
            if recent.count >= 3 {
                let symptoms = Set(recent.map { $0.effect }).prefix(3).joined(separator: ", ")
                autoAddAnnotation(
                    kind: "side_effect_cluster",
                    targetLane: .compounds,
                    title: "Side effect cluster",
                    reasoning: "\(recent.count) side effects logged in the last week (\(symptoms)). Worth flagging timing relative to dose day and discussing with your provider if this persists.",
                    timestamp: now
                )
            }
        }

        // 5. Adherence streak — 30 days perfect dose adherence.
        if let proto = InsightsDataStore.shared.primaryProtocol,
           !recentlyFired("adherence_streak_30") {
            let logs = proto.doseLog.filter { !$0.wasSkipped }
            let cutoff = cal.date(byAdding: .day, value: -30, to: now)!
            let recentLogs = logs.filter { $0.timestamp >= cutoff }
            let skipped = proto.doseLog.filter { $0.wasSkipped && $0.timestamp >= cutoff }
            if recentLogs.count >= 4, skipped.isEmpty {
                autoAddAnnotation(
                    kind: "adherence_streak_30",
                    targetLane: .compounds,
                    title: "30 days of perfect adherence",
                    reasoning: "You haven't missed a dose in the last 30 days — \(recentLogs.count) logged, zero skipped. Consistency like this is what makes the data clean enough to learn from.",
                    timestamp: now
                )
            }
        }
    }

    private func autoAddAnnotation(
        kind: String,
        targetLane: JourneyLane,
        title: String,
        reasoning: String,
        timestamp: Date
    ) {
        JourneyEventService.shared.autoAdd(
            lane: .agentAnnotation,
            timestamp: timestamp,
            title: title,
            description: reasoning,
            sourceType: .agent,
            confidence: 0.8,
            payload: JourneyEventPayload(
                annotationKind: kind,
                annotationTargetLane: targetLane.rawValue
            )
        )
    }

    // MARK: - Correlations

    private func correlateSleepVsTraining() async -> [AIMemoryFact] {
        let hk = HealthKitService.shared
        guard hk.isAvailable, hk.isAuthorized else { return [] }

        let sleep = await hk.fetchSleepHistory(days: 45)
        let workouts = InsightsDataStore.shared.workoutHistory
        guard sleep.count >= 10, workouts.count >= 6 else { return [] }

        let cal = Calendar.current
        var pairs: [(sleepHours: Double, volume: Double)] = []
        for night in sleep {
            let nextDay = cal.date(byAdding: .day, value: 1, to: night.date) ?? night.date
            let workoutsOnDay = workouts.filter { cal.isDate($0.date, inSameDayAs: nextDay) }
            guard !workoutsOnDay.isEmpty else { continue }
            let volume = workoutsOnDay.reduce(0.0) { total, w in
                total + w.exercises.reduce(0.0) { t, ex in
                    t + ex.sets.reduce(0.0) { ts, set in
                        ts + set.weight * Double(set.reps)
                    }
                }
            }
            pairs.append((night.asleepHours, volume))
        }
        guard pairs.count >= 6 else { return [] }

        let threshold = 7.0
        let wellRested = pairs.filter { $0.sleepHours >= threshold }
        let underSlept = pairs.filter { $0.sleepHours < threshold }
        guard !wellRested.isEmpty, !underSlept.isEmpty else { return [] }
        let avgRested = wellRested.map(\.volume).reduce(0, +) / Double(wellRested.count)
        let avgTired = underSlept.map(\.volume).reduce(0, +) / Double(underSlept.count)
        guard avgRested > 0 else { return [] }
        let diffPct = (avgRested - avgTired) / avgRested * 100

        guard abs(diffPct) >= 8 else { return [] }
        let direction = diffPct > 0 ? "drops" : "rises"
        let headline = "Training volume \(direction) on nights under \(Int(threshold))h of sleep"
        let detail = "Average volume \(Int(avgRested)) lb when rested (≥\(Int(threshold))h) vs \(Int(avgTired)) lb after under-sleeping — a \(abs(Int(diffPct)))% \(diffPct > 0 ? "drop" : "rise"). Sample: \(pairs.count) sessions across the last 45 days."
        let confidence = min(0.5 + (abs(diffPct) / 100.0) * 0.4, 0.92)
        return [AIMemoryFact(
            kind: .correlation,
            headline: headline,
            detail: detail,
            domain: "training",
            evidence: "sleep_vs_volume n=\(pairs.count)",
            confidence: confidence
        )]
    }

    private func correlateDoseDays() async -> [AIMemoryFact] {
        let store = InsightsDataStore.shared
        guard let proto = store.primaryProtocol else { return [] }
        let realLogs = proto.doseLog.filter { !$0.wasSkipped }
        guard realLogs.count >= 4 else { return [] }

        let hk = HealthKitService.shared
        var facts: [AIMemoryFact] = []
        let cal = Calendar.current

        // Dose-day vs non-dose-day HRV
        if hk.isAuthorized {
            let hrv = await hk.fetchDailyAverageSeries(for: .heartRateVariabilitySDNN, unit: HKUnit(from: "ms"), days: 45)
            if hrv.count >= 10 {
                let doseDays = Set(realLogs.map { cal.startOfDay(for: $0.timestamp) })
                var onDose: [Double] = []
                var offDose: [Double] = []
                for entry in hrv {
                    if doseDays.contains(cal.startOfDay(for: entry.date)) { onDose.append(entry.value) }
                    else { offDose.append(entry.value) }
                }
                if onDose.count >= 3, offDose.count >= 3 {
                    let avgOn = onDose.reduce(0, +) / Double(onDose.count)
                    let avgOff = offDose.reduce(0, +) / Double(offDose.count)
                    if avgOff > 0 {
                        let deltaPct = (avgOn - avgOff) / avgOff * 100
                        if abs(deltaPct) >= 6 {
                            let dir = deltaPct < 0 ? "drops" : "rises"
                            facts.append(AIMemoryFact(
                                kind: .correlation,
                                headline: "HRV \(dir) on dose days",
                                detail: "On dose days HRV averages \(Int(avgOn)) ms vs \(Int(avgOff)) ms on off-days — \(abs(Int(deltaPct)))% \(deltaPct < 0 ? "lower" : "higher"). Across \(hrv.count) days tracked.",
                                domain: "protocol",
                                evidence: "dose_vs_hrv on=\(onDose.count) off=\(offDose.count)",
                                confidence: min(0.55 + abs(deltaPct) / 100.0 * 0.4, 0.9)
                            ))
                        }
                    }
                }
            }
        }

        // Side effect clustering around dose days
        let effects = proto.sideEffectLog
        if effects.count >= 4 {
            let doseDays = realLogs.map { cal.startOfDay(for: $0.timestamp) }
            var within48h = 0
            for e in effects {
                let day = cal.startOfDay(for: e.timestamp)
                let near = doseDays.contains { cal.dateComponents([.hour], from: $0, to: day).hour ?? 999 <= 48 && day >= $0 }
                if near { within48h += 1 }
            }
            let pct = Double(within48h) / Double(effects.count) * 100
            if pct >= 65 {
                facts.append(AIMemoryFact(
                    kind: .pattern,
                    headline: "Side effects cluster within 48h of a dose",
                    detail: "\(Int(pct))% of your \(effects.count) logged side effects fall within 48 hours of a dose. Timing hydration and food around dose day may help.",
                    domain: "side_effects",
                    evidence: "se_cluster_48h n=\(effects.count)",
                    confidence: min(0.55 + pct / 200, 0.9)
                ))
            }
        }
        return facts
    }

    private func correlateProteinVsWeight() -> [AIMemoryFact] {
        let store = InsightsDataStore.shared
        let meals = store.recentMealsByDay
        guard meals.count >= 7, store.weightEntries.count >= 3 else { return [] }

        let sorted = meals.keys.sorted()
        let proteinTarget = Double(store.macroTarget.protein)
        guard proteinTarget > 0 else { return [] }
        var hitDays = 0
        for day in sorted {
            let p = meals[day]?.reduce(0.0) { $0 + $1.totalProtein } ?? 0
            if p >= proteinTarget * 0.9 { hitDays += 1 }
        }
        let hitRate = Double(hitDays) / Double(sorted.count)
        let weights = store.weightEntries.sorted { $0.date < $1.date }
        guard let first = weights.first, let last = weights.last else { return [] }
        let weeks = max(1.0, Date().timeIntervalSince(first.date) / (7 * 86400))
        let weeklyChange = (last.weight - first.weight) / weeks

        if hitRate >= 0.7 && abs(weeklyChange) < 0.3 && store.targetWeight > 0 {
            return [AIMemoryFact(
                kind: .pattern,
                headline: "Holding weight while consistently hitting protein",
                detail: "You've hit \(Int(hitRate * 100))% of your protein target across \(sorted.count) tracked days and your weekly weight change is \(String(format: "%.1f", weeklyChange)) lb — classic recomposition signal.",
                domain: "body",
                evidence: "protein_vs_weight rate=\(hitRate) dw=\(weeklyChange)",
                confidence: 0.72
            )]
        }
        if hitRate < 0.4 {
            return [AIMemoryFact(
                kind: .pattern,
                headline: "Protein target missed more often than hit",
                detail: "You've hit protein on only \(hitDays) of the last \(sorted.count) tracked days (\(Int(hitRate * 100))%). This matters more than usual if you're on a GLP-1 — muscle preservation relies on it.",
                domain: "nutrition",
                evidence: "protein_miss hit=\(hitDays)/\(sorted.count)",
                confidence: 0.78
            )]
        }
        return []
    }

    private func correlateProgressionStalls() -> [AIMemoryFact] {
        let history = InsightsDataStore.shared.workoutHistory
        guard history.count >= 6 else { return [] }
        var exerciseSessions: [String: [(date: Date, weight: Double)]] = [:]
        for w in history {
            for ex in w.exercises {
                let best = ex.sets.map(\.weight).max() ?? 0
                if best > 0 {
                    exerciseSessions[ex.exerciseName, default: []].append((w.date, best))
                }
            }
        }
        var stalls: [String] = []
        for (name, sessions) in exerciseSessions {
            let recent = sessions.sorted { $0.date > $1.date }.prefix(4)
            guard recent.count >= 3 else { continue }
            let weights = recent.map(\.weight)
            let spread = (weights.max() ?? 0) - (weights.min() ?? 0)
            if spread < 2.5, weights.first ?? 0 > 50 {
                stalls.append(name)
            }
        }
        guard !stalls.isEmpty else { return [] }
        return [AIMemoryFact(
            kind: .pattern,
            headline: "Stalled lifts: \(stalls.prefix(3).joined(separator: ", "))",
            detail: "Working weight hasn't moved in 3+ sessions on \(stalls.count) lift\(stalls.count == 1 ? "" : "s"). Candidates for a rep-scheme change, pause reps, or a deload.",
            domain: "training",
            evidence: "stalls=\(stalls.count)",
            confidence: 0.75
        )]
    }
}
