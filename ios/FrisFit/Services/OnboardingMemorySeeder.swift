import Foundation
import HealthKit

/// Writes AIMemoryStore facts progressively at each onboarding chapter boundary
/// so the agent has warm context the moment the user lands on the home screen.
@MainActor
enum OnboardingMemorySeeder {

    static let sourceTag = "onboarding"
    static let aboutYouTag = "onboarding.aboutYou"
    static let goalsTag = "onboarding.goals"
    static let protocolTag = "onboarding.protocol"
    static let hkSummaryTag = "onboarding.hk"
    static let trackBCuriosityTag = "onboarding.trackB.curiosity"

    private static func days(_ n: Int) -> Date { Date().addingTimeInterval(Double(n) * 86400) }

    // MARK: - Chapter 2 — About You

    static func seedAboutYou(state: OnboardingState) {
        let store = AIMemoryStore.shared
        guard let dob = state.dateOfBirth,
              let sex = state.biologicalSex,
              let h = state.heightCm,
              let w = state.weightKg,
              let activity = state.activityLevel else { return }

        let age = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0
        let heightStr: String = state.unitSystem == .imperial
            ? formatImperialHeight(cm: h)
            : "\(Int(h.rounded())) cm"
        let weightStr: String = state.unitSystem == .imperial
            ? "\(Int(UnitConversion.kgToPounds(w).rounded())) lb"
            : "\(Int(w.rounded())) kg"

        var fresh: [AIMemoryFact] = []
        fresh.append(AIMemoryFact(
            kind: .preference,
            headline: "User is \(age)yo \(sex.rawValue), \(heightStr), \(weightStr)",
            detail: "Captured during onboarding About You chapter.",
            domain: "identity",
            confidence: 1.0,
            isPinned: true,
            sourceTag: aboutYouTag
        ))

        let bmi = w / pow(h / 100.0, 2)
        var anthroLine = "BMI \(String(format: "%.1f", bmi))"
        if let bf = state.bodyFatPercent {
            anthroLine += ", BF \(String(format: "%.1f", bf))%"
        }
        fresh.append(AIMemoryFact(
            kind: .pattern,
            headline: anthroLine,
            detail: "Anthropometric baseline at onboarding.",
            domain: "body",
            confidence: 1.0,
            expiresAt: days(90),
            sourceTag: aboutYouTag
        ))

        let mult = activityMultiplier(activity)
        fresh.append(AIMemoryFact(
            kind: .preference,
            headline: "Self-reported \(activity.rawValue) (TDEE multiplier \(String(format: "%.2f", mult)))",
            detail: "User-declared activity baseline at onboarding.",
            domain: "training",
            confidence: 0.7,
            expiresAt: days(60),
            sourceTag: aboutYouTag
        ))

        // Replace any prior About-You facts so re-runs do not leak stale numbers.
        store.replaceFactsWith(sourceTag: aboutYouTag, fresh: fresh)
    }

    // MARK: - Track B curiosity capture (chapter-6 equivalent)

    /// Track B users have no protocol or vials — instead we capture what they want to research.
    /// These facts seed the agent so the day-one home is not generic.
    static func seedTrackBCuriosity(topics: [String], firstName: String) {
        let store = AIMemoryStore.shared
        let cleaned = topics.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return }
        var fresh: [AIMemoryFact] = []
        let joined = cleaned.joined(separator: ", ")
        let nameLine = firstName.isEmpty ? "User" : firstName
        fresh.append(AIMemoryFact(
            kind: .investigation,
            headline: "\(nameLine) wants to research: \(joined)",
            detail: "Captured at onboarding as Track B research interests.",
            domain: "curiosity",
            confidence: 0.95,
            isPinned: true,
            expiresAt: days(180),
            sourceTag: trackBCuriosityTag
        ))
        for topic in cleaned {
            fresh.append(AIMemoryFact(
                kind: .preference,
                headline: "Curious about \(topic)",
                detail: "Track B research interest from onboarding.",
                domain: "curiosity",
                confidence: 0.9,
                expiresAt: days(180),
                sourceTag: trackBCuriosityTag
            ))
        }
        store.replaceFactsWith(sourceTag: trackBCuriosityTag, fresh: fresh)
    }

    // MARK: - Chapter 3 — Connect Your Data

    static func seedHealthKitSummary() async {
        let hk = HealthKitService.shared
        guard hk.isAvailable, hk.isAuthorized else { return }
        let store = AIMemoryStore.shared

        let sleep = await hk.fetchSleepHistory(days: 30)
        let nonZero = sleep.filter { $0.asleepHours > 0 }
        if !nonZero.isEmpty {
            let avg = nonZero.map(\.asleepHours).reduce(0, +) / Double(nonZero.count)
            let half = nonZero.count / 2
            let firstHalfAvg = Double(nonZero.prefix(half).map(\.asleepHours).reduce(0, +)) / Double(max(half, 1))
            let secondHalfAvg = Double(nonZero.suffix(half).map(\.asleepHours).reduce(0, +)) / Double(max(half, 1))
            let direction: String = abs(secondHalfAvg - firstHalfAvg) < 0.3 ? "stable" : (secondHalfAvg > firstHalfAvg ? "improving" : "declining")
            store.upsert(AIMemoryFact(
                kind: .pattern,
                headline: "Avg sleep last 30d: \(String(format: "%.1f", avg))h, trending \(direction)",
                detail: "From HealthKit at onboarding.",
                domain: "recovery",
                confidence: 0.95,
                expiresAt: days(7)
            ))
        }

        let hrvSamples = await hk.fetchRecentSamples(for: .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), limit: 60)
        if !hrvSamples.isEmpty {
            let avg = hrvSamples.map(\.value).reduce(0, +) / Double(hrvSamples.count)
            let half = hrvSamples.count / 2
            let firstAvg = hrvSamples.prefix(half).map(\.value).reduce(0, +) / Double(max(half, 1))
            let secondAvg = hrvSamples.suffix(half).map(\.value).reduce(0, +) / Double(max(half, 1))
            let direction: String
            if abs(secondAvg - firstAvg) < 2 { direction = "stable" }
            else if secondAvg > firstAvg { direction = "improving" }
            else { direction = "declining" }
            store.upsert(AIMemoryFact(
                kind: .pattern,
                headline: "Avg HRV last 30d: \(Int(avg))ms, \(direction)",
                detail: "From HealthKit at onboarding.",
                domain: "recovery",
                confidence: 0.95,
                expiresAt: days(7)
            ))
        }

        let rhrSamples = await hk.fetchRecentSamples(for: .restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), limit: 60)
        if !rhrSamples.isEmpty {
            let avg = rhrSamples.map(\.value).reduce(0, +) / Double(rhrSamples.count)
            store.upsert(AIMemoryFact(
                kind: .pattern,
                headline: "Avg RHR last 30d: \(Int(avg)) bpm, baseline established",
                detail: "From HealthKit at onboarding.",
                domain: "recovery",
                confidence: 0.95,
                expiresAt: days(14)
            ))
        }

        let weightSamples = await hk.fetchRecentSamples(for: .bodyMass, unit: .pound(), limit: 200)
        if let oldest = weightSamples.last, let newest = weightSamples.first {
            let delta = newest.value - oldest.value
            let sign = delta >= 0 ? "+" : ""
            store.upsert(AIMemoryFact(
                kind: .milestone,
                headline: "Weight 90d ago: \(String(format: "%.1f", oldest.value)) → today: \(String(format: "%.1f", newest.value)) (\(sign)\(String(format: "%.1f", delta)) lb)",
                detail: "From HealthKit at onboarding.",
                domain: "body",
                confidence: 1.0,
                expiresAt: days(14)
            ))
        }

        let snapshot = JourneyMapStagingStore.load()
        if let days30 = snapshot?.days.suffix(30), !days30.isEmpty {
            let workoutCount = days30.compactMap(\.workoutCount).reduce(0, +)
            if workoutCount > 0 {
                store.upsert(AIMemoryFact(
                    kind: .pattern,
                    headline: "\(workoutCount) workouts last 30d, mostly logged via Apple Health",
                    detail: "From staged 90-day HealthKit snapshot.",
                    domain: "training",
                    confidence: 1.0,
                    expiresAt: Self.days(7)
                ))
            }
        }
    }

    // MARK: - Chapter 4 — Journey Map

    static func seedJourneyEvents(firstName: String, primaryGoal: PrimaryGoal?) {
        let store = AIMemoryStore.shared
        let events = JourneyEventService.shared.events
        let df = DateFormatter()
        df.dateFormat = "MMM d, yyyy"

        var bodyCount = 0
        var pastCycleCount = 0
        var trainingPhaseCount = 0
        var bloodworkCount = 0

        for event in events {
            switch event.lane {
            case .body:
                bodyCount += 1
                let weight = event.payload?.weightLbs.map { "\(String(format: "%.1f", $0)) lb" } ?? ""
                let note = event.payload?.note ?? event.description ?? ""
                let line = [df.string(from: event.timestamp), weight, note].filter { !$0.isEmpty }.joined(separator: ": ")
                store.upsert(AIMemoryFact(
                    kind: .milestone,
                    headline: "Body milestone — \(line)",
                    detail: event.title,
                    domain: "body",
                    confidence: 0.9
                ))

            case .compounds:
                pastCycleCount += 1
                let p = event.payload
                let dose = [p?.doseAmount.map { "\($0)" }, p?.doseUnit].compactMap { $0 }.joined(separator: " ")
                let dates = [p?.startDate, p?.endDate].compactMap { $0 }.map { df.string(from: $0) }.joined(separator: " – ")
                let results = p?.perceivedResults ?? ""
                let sides = (p?.sideEffects ?? []).joined(separator: ", ")
                let stopped = (p?.reasonStopped ?? []).joined(separator: ", ")
                let parts = [
                    p?.compoundName ?? event.title,
                    dose,
                    p?.frequency ?? "",
                    dates,
                    results.isEmpty ? "" : "→ \(results)",
                    sides.isEmpty ? "" : "side effects: \(sides)",
                    stopped.isEmpty ? "" : "stopped: \(stopped)"
                ].filter { !$0.isEmpty }
                let fact = AIMemoryFact(
                    kind: .investigation,
                    headline: "Past cycle — \(parts.joined(separator: " "))",
                    detail: event.description ?? "",
                    domain: "protocol",
                    confidence: 0.9,
                    isPinned: true
                )
                store.upsert(fact)

                if let sideList = p?.sideEffects, !sideList.isEmpty {
                    for effect in sideList {
                        store.upsert(AIMemoryFact(
                            kind: .concern,
                            headline: "Reports \(effect) on \(p?.compoundName ?? "compound") during cycle",
                            detail: dates,
                            domain: "side_effects",
                            confidence: 0.85,
                            expiresAt: days(365)
                        ))
                    }
                }

            case .training:
                trainingPhaseCount += 1
                let phase = event.payload?.phaseType ?? event.title
                let dates = [event.timestamp, event.endDate].compactMap { $0 }.map { df.string(from: $0) }.joined(separator: " – ")
                store.upsert(AIMemoryFact(
                    kind: .pattern,
                    headline: "Training phase — \(phase) \(dates)",
                    detail: event.description ?? "",
                    domain: "training",
                    confidence: 0.85
                ))

            case .bloodwork:
                bloodworkCount += 1
                store.upsert(AIMemoryFact(
                    kind: .milestone,
                    headline: "Panel drawn \(df.string(from: event.timestamp))",
                    detail: event.description ?? event.title,
                    domain: "bloodwork",
                    confidence: 1.0
                ))

            case .life, .agentAnnotation:
                continue
            }
        }

        // Rolled-up narrative
        let goalLine = primaryGoal.map { "Goal: \($0.title)." } ?? ""
        var narrativeParts: [String] = []
        let name = firstName.isEmpty ? "User" : firstName
        narrativeParts.append("\(name)'s journey:")
        if bodyCount > 0 { narrativeParts.append("\(bodyCount) body milestones") }
        if pastCycleCount > 0 { narrativeParts.append("\(pastCycleCount) past cycle\(pastCycleCount == 1 ? "" : "s")") }
        if trainingPhaseCount > 0 { narrativeParts.append("\(trainingPhaseCount) training phase\(trainingPhaseCount == 1 ? "" : "s")") }
        if bloodworkCount > 0 { narrativeParts.append("\(bloodworkCount) bloodwork draw\(bloodworkCount == 1 ? "" : "s")") }
        if !goalLine.isEmpty { narrativeParts.append(goalLine) }

        if narrativeParts.count > 1 {
            store.upsert(AIMemoryFact(
                kind: .pattern,
                headline: narrativeParts.joined(separator: " "),
                detail: "Synthesized at end of Journey Map onboarding chapter.",
                domain: "cross",
                confidence: 0.85,
                isPinned: true,
                expiresAt: days(60)
            ))
        }
    }

    // MARK: - Chapter 5 — Goals

    static func seedGoals(state: OnboardingState) {
        let store = AIMemoryStore.shared
        guard let goal = state.primaryGoal else { return }

        let df = DateFormatter()
        df.dateFormat = "MMM d, yyyy"
        let target: String
        if let tw = state.targetWeightKg {
            let display = state.unitSystem == .imperial
                ? "\(Int(UnitConversion.kgToPounds(tw).rounded())) lb"
                : "\(Int(tw.rounded())) kg"
            target = display
        } else if !state.targetPerformanceMetric.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            target = state.targetPerformanceMetric
        } else if let bf = state.targetBodyFatPercent {
            target = "\(String(format: "%.1f", bf))% BF"
        } else {
            target = "no specific target"
        }
        let dateLine = state.targetDate.map { " by \(df.string(from: $0))" } ?? ""
        let expiry: Date? = state.targetDate.map { $0.addingTimeInterval(30 * 86400) }
        store.upsert(AIMemoryFact(
            kind: .preference,
            headline: "Primary goal: \(goal.title) to \(target)\(dateLine)",
            detail: "Captured at onboarding Goals chapter.",
            domain: "goal",
            confidence: 0.9,
            isPinned: true,
            expiresAt: expiry
        ))

        let exp = state.experienceLevel?.rawValue ?? "unknown experience"
        let prog = state.currentProgramName.trimmingCharacters(in: .whitespacesAndNewlines)
        let progLine = prog.isEmpty ? "unstructured" : prog
        store.upsert(AIMemoryFact(
            kind: .preference,
            headline: "\(state.sessionsPerWeek)x/week, \(exp), current program: \(progLine)",
            detail: "Training profile from onboarding.",
            domain: "training",
            confidence: 0.85,
            expiresAt: days(90)
        ))

        let diet = state.dietStyle?.rawValue ?? "unspecified"
        let prior = state.priorTracker?.rawValue ?? "no prior tracking"
        let proteinG = Int((state.proteinPerKgOverride ?? 0) * (state.weightKg ?? 0))
        store.upsert(AIMemoryFact(
            kind: .preference,
            headline: "\(diet), prior tracking: \(prior), target protein \(proteinG)g",
            detail: "Nutrition profile from onboarding.",
            domain: "nutrition",
            confidence: 0.85,
            expiresAt: days(90)
        ))

        for injury in state.injuries {
            store.upsert(AIMemoryFact(
                kind: .concern,
                headline: "Reports prior \(injury.rawValue) injury",
                detail: state.otherInjuryNote.isEmpty ? "" : state.otherInjuryNote,
                domain: "training",
                confidence: 0.8,
                expiresAt: days(365)
            ))
        }
    }

    // MARK: - Chapter 6 — Protocol & Vials

    static func seedProtocol(compounds: [ProtocolCompound], preferredSites: Set<InjectionSite>) {
        let store = AIMemoryStore.shared

        for c in compounds {
            let dose = CompoundUnitHelper.displayDoseShort(c.doseMcg, for: c.compoundName)
            store.upsert(AIMemoryFact(
                kind: .preference,
                headline: "Currently week 1 of \(c.compoundName) \(dose) \(c.frequency), 12-week planned",
                detail: "Active protocol from onboarding.",
                domain: "protocol",
                confidence: 1.0,
                isPinned: true,
                expiresAt: days(12 * 7)
            ))
        }

        let inventory = VialInventoryStore.shared.vials
        let grouped = Dictionary(grouping: inventory, by: \.compoundName)
        for (name, vials) in grouped {
            store.upsert(AIMemoryFact(
                kind: .pattern,
                headline: "\(vials.count) \(name) vial\(vials.count == 1 ? "" : "s") in stock",
                detail: "Vial inventory at onboarding.",
                domain: "supply",
                confidence: 0.9,
                expiresAt: days(14)
            ))
        }

        if !preferredSites.isEmpty {
            let sites = preferredSites.map { $0.rawValue }.sorted().joined(separator: ", ")
            store.upsert(AIMemoryFact(
                kind: .preference,
                headline: "Preferred injection sites: \(sites)",
                detail: "Set during onboarding.",
                domain: "protocol",
                confidence: 0.95,
                isPinned: true
            ))
        }
    }

    // MARK: - Final warm-up

    static func runCorrelationWarmUp() async {
        _ = await CorrelationEngine.shared.run(force: true)
    }

    // MARK: - Helpers

    private static func formatImperialHeight(cm: Double) -> String {
        let totalInches = cm / 2.54
        let feet = Int(totalInches / 12)
        let inches = Int(totalInches.truncatingRemainder(dividingBy: 12).rounded())
        return "\(feet)'\(inches)\""
    }

    private static func activityMultiplier(_ level: ActivityLevel) -> Double {
        switch level {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .athlete: return 1.9
        }
    }
}
