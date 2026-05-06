import Foundation
import SwiftUI

/// Builds the four deterministic status lines (recovery, dose, training, nutrition)
/// shown on the Morning Brief card. The narrative (greeting, headline, body,
/// watch-for) now comes from `TodaysPlanViewModel.planResponse.narrative` so the
/// dashboard makes a single AI call instead of two.
@MainActor
@Observable
final class MorningBriefService {
    static let shared = MorningBriefService()

    private init() {}

    struct Lines {
        let recovery: BriefLine?
        let dose: BriefLine?
        let training: BriefLine?
        let nutrition: BriefLine?
        let supply: BriefLine?
        let bloodwork: BriefLine?
        let bodyGoal: BriefLine?
        let watchFor: String?
    }

    func buildLines() -> Lines {
        let store = InsightsDataStore.shared
        let hk = HealthKitService.shared
        return Lines(
            recovery: buildRecoveryLine(hk: hk, store: store),
            dose: buildDoseLine(store: store),
            training: buildTrainingLine(store: store),
            nutrition: buildNutritionLine(store: store),
            supply: buildSupplyLine(store: store),
            bloodwork: buildBloodworkLine(store: store),
            bodyGoal: buildBodyGoalLine(store: store),
            watchFor: pickWatchFor()
        )
    }

    func fallbackGreeting(firstName: String) -> String {
        let name = firstName.isEmpty ? "there" : firstName
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Morning, \(name)."
        case 12..<17: return "Afternoon, \(name)."
        case 17..<22: return "Evening, \(name)."
        default: return "Late night, \(name)."
        }
    }

    func fallbackHeadline(from lines: Lines) -> String {
        let store = InsightsDataStore.shared
        let hour = Calendar.current.component(.hour, from: Date())
        let isEvening = hour >= 17

        if let proto = store.primaryProtocol, let compound = proto.compounds.first {
            let phase = proto.currentPhase.rawValue.lowercased()
            return "Week \(proto.currentWeek) on \(compound.compoundName) — \(phase) phase"
        }
        if store.targetWeight > 0, let latest = store.weightEntries.last?.weight, latest > 0 {
            let remaining = abs(latest - store.targetWeight)
            return "\(String(format: "%.1f", remaining)) lb to your goal of \(String(format: "%.1f", store.targetWeight))"
        }
        if let program = store.activeProgram {
            return "\(program.name) — week \(program.currentWeek)"
        }
        if isEvening, let n = lines.nutrition, !isPlaceholder(n) {
            return "Day in review — \(n.value.lowercased())"
        }
        if let r = lines.recovery {
            return "\(r.label) \(r.value.lowercased())"
        }
        return "Your day, at a glance"
    }

    func fallbackBody(from lines: Lines) -> String {
        let store = InsightsDataStore.shared
        let hk = HealthKitService.shared
        var parts: [String] = []

        // 1. Journey position (protocol or program)
        if let proto = store.primaryProtocol, let compound = proto.compounds.first {
            let days = max(1, Calendar.current.dateComponents([.day], from: proto.startDate, to: Date()).day ?? 1)
            let dose = CompoundUnitHelper.displayDoseShort(compound.doseMcg, for: compound.compoundName)
            parts.append("You're \(days) days into \(compound.compoundName) at \(dose), \(proto.currentPhase.rawValue.lowercased()) phase.")
        } else if let program = store.activeProgram {
            parts.append("\(program.name), week \(program.currentWeek) — \(program.daysPerWeek)x/week split.")
        }

        // 2. Body trajectory
        if store.targetWeight > 0, let latest = store.weightEntries.last?.weight, latest > 0 {
            let remaining = abs(latest - store.targetWeight)
            if store.startingWeight > 0 {
                let moved = abs(store.startingWeight - latest)
                parts.append("You're \(String(format: "%.1f", moved)) lb in, \(String(format: "%.1f", remaining)) lb to go.")
            } else {
                parts.append("\(String(format: "%.1f", remaining)) lb between you and goal.")
            }
        }

        // 3. Today's real data — only when actually logged
        if let d = lines.dose, !isPlaceholder(d) {
            parts.append("Dose: \(d.detail)")
        }
        if let t = lines.training, !isPlaceholder(t) {
            parts.append("Training: \(t.detail)")
        }
        if let n = lines.nutrition, !isPlaceholder(n) {
            parts.append("Nutrition: \(n.detail)")
        }

        // 4. HealthKit signals if no logs yet
        if parts.count < 2 {
            let sleepHours = hk.sleepHours > 0 ? hk.sleepHours : (SleepLogViewModel.shared.lastNightLog()?.hours ?? 0)
            if sleepHours > 0 {
                parts.append("Slept \(String(format: "%.1f", sleepHours))h last night.")
            }
            if hk.isAuthorized && hk.steps > 0 {
                parts.append("\(hk.steps) steps banked so far.")
            }
        }

        // 5. Workout history baseline
        if parts.count < 2, !store.workoutHistory.isEmpty {
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let recent = store.workoutHistory.filter { $0.date >= weekAgo }.count
            if recent > 0 {
                parts.append("\(recent) session\(recent == 1 ? "" : "s") this week so far.")
            }
        }

        // 6. One concrete action
        let action = pickAction(lines: lines, store: store)
        if !action.isEmpty { parts.append(action) }

        if parts.isEmpty {
            let hour = Calendar.current.component(.hour, from: Date())
            let name = store.firstName.isEmpty ? "" : " \(store.firstName)"
            if hour < 11 { return "Quiet morning so far\(name). Log a meal, dose, or session and I'll have a real read on where today should land." }
            if hour < 17 { return "Nothing logged yet today\(name). Drop in a meal or session and I'll sharpen this up against your patterns." }
            return "Day's almost in the books\(name). A quick weigh-in or meal log keeps the journey honest."
        }
        return parts.joined(separator: " ")
    }

    private func isPlaceholder(_ line: BriefLine) -> Bool {
        let detail = line.detail.lowercased()
        let value = line.value.lowercased()
        let placeholders = [
            "build one to get",
            "log your first meal",
            "no active program",
            "no dose scheduled"
        ]
        return placeholders.contains(where: { detail.contains($0) || value.contains($0) })
    }

    private func pickAction(lines: Lines, store: InsightsDataStore) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let target = store.macroTarget
        let consumed = store.todayMeals.reduce(0) { $0 + $1.totalCalories }
        let protein = store.todayMeals.reduce(0.0) { $0 + $1.totalProtein }

        if let proto = store.primaryProtocol, let compound = proto.compounds.first {
            let logged = proto.doseLog.contains { Calendar.current.isDateInToday($0.timestamp) && !$0.wasSkipped }
            if !logged && isScheduledToday(compound: compound) {
                return "Log \(compound.compoundName) when you take it today."
            }
        }

        if target.protein > 0 {
            let remainingProtein = max(target.protein - Int(protein), 0)
            if remainingProtein > 30 && hour >= 11 && hour < 21 {
                return "Land \(remainingProtein)g more protein before you wind down."
            }
        }

        if target.calories > 0 && consumed == 0 && hour >= 9 && hour < 20 {
            return "Log your first meal — \(target.calories) cal, \(target.protein)g protein on the board today."
        }

        if store.activeProgram != nil {
            let doneToday = store.workoutHistory.contains { Calendar.current.isDateInToday($0.date) }
            if !doneToday && hour < 21 {
                return "Get today's session in or move it to tomorrow on purpose."
            }
        } else if store.primaryProtocol != nil {
            return "Add a training program — resistance work protects lean mass through the cycle."
        }

        if store.weightEntries.isEmpty || (store.weightEntries.last.map { Date().timeIntervalSince($0.date) > 4 * 86400 } ?? false) {
            return "Drop a quick weigh-in to keep the trend honest."
        }

        return ""
    }

    // MARK: - Structured line builders

    private func buildRecoveryLine(hk: HealthKitService, store: InsightsDataStore) -> BriefLine? {
        // Prefer the correlated sleep insight when available.
        if let corr = store.sleepCorrelation {
            let tone: BriefLine.Tone
            switch corr.severity {
            case .good: tone = .positive
            case .watch: tone = .caution
            case .warn: tone = .warning
            }
            var value = "\(String(format: "%.1f", corr.averageSleepHours))h avg"
            if let hrv = corr.averageHRV { value += " · HRV \(Int(hrv))ms" }
            return BriefLine(label: "Recovery", value: value, detail: corr.insight, tone: tone)
        }
        let manualSleep = SleepLogViewModel.shared.lastNightLog()?.hours ?? 0
        guard hk.isAuthorized || manualSleep > 0 else { return nil }
        let sleep = hk.sleepHours > 0 ? hk.sleepHours : manualSleep
        let hrv = hk.hrv
        let score = hk.recoveryScore
        var parts: [String] = []
        var tone: BriefLine.Tone = .neutral
        if sleep > 0 {
            parts.append("\(String(format: "%.1f", sleep))h sleep")
            if sleep < 6.5 { tone = .caution }
            else if sleep >= 7.5 { tone = .positive }
        }
        if let h = hrv {
            parts.append("HRV \(Int(h)) ms")
            if h < 35 { tone = .caution }
        }
        let value: String
        if let s = score {
            value = "\(s)/100"
            if s >= 75 { tone = .positive }
            else if s < 50 { tone = .warning }
        } else if !parts.isEmpty {
            value = parts.first ?? "—"
        } else {
            return nil
        }
        return BriefLine(
            label: "Recovery",
            value: value,
            detail: parts.joined(separator: " · "),
            tone: tone
        )
    }

    private func buildDoseLine(store: InsightsDataStore) -> BriefLine? {
        guard let proto = store.primaryProtocol, let compound = proto.compounds.first else {
            return nil
        }
        let today = proto.doseLog.filter { Calendar.current.isDateInToday($0.timestamp) && !$0.wasSkipped }
        let doseStr = CompoundUnitHelper.displayDoseShort(compound.doseMcg, for: compound.compoundName)
        if let logged = today.first {
            let time = logged.timestamp.formatted(date: .omitted, time: .shortened)
            return BriefLine(
                label: "Dose",
                value: "\(compound.compoundName) · logged \(time)",
                detail: "Week \(proto.currentWeek), \(proto.currentPhase.rawValue) phase. Already logged today.",
                tone: .positive
            )
        }
        let isDueToday = isScheduledToday(compound: compound)
        if isDueToday {
            return BriefLine(
                label: "Dose",
                value: "\(compound.compoundName) \(doseStr) due",
                detail: "Week \(proto.currentWeek), \(proto.currentPhase.rawValue). Log when you take it.",
                tone: .caution
            )
        }
        // No dose scheduled today — surface last-logged context instead of a dead line.
        let realLogs = proto.doseLog.filter { !$0.wasSkipped }.sorted { $0.timestamp > $1.timestamp }
        if let last = realLogs.first {
            let days = Calendar.current.dateComponents([.day], from: last.timestamp, to: Date()).day ?? 0
            let when = days == 0 ? "earlier today" : (days == 1 ? "yesterday" : "\(days)d ago")
            return BriefLine(
                label: "Dose",
                value: "\(compound.compoundName) · last \(when)",
                detail: "Week \(proto.currentWeek), \(proto.currentPhase.rawValue) phase. Frequency: \(compound.frequency.lowercased()).",
                tone: days >= 3 ? .caution : .neutral
            )
        }
        return BriefLine(
            label: "Dose",
            value: "\(compound.compoundName) · \(compound.frequency.lowercased())",
            detail: "Week \(proto.currentWeek), \(proto.currentPhase.rawValue) phase. No dose logged yet.",
            tone: .caution
        )
    }

    private func isScheduledToday(compound: ProtocolCompound) -> Bool {
        let freq = compound.frequency.lowercased()
        if freq.contains("daily") || freq.contains("every day") { return true }
        if freq.contains("weekly") || freq.contains("once a week") { return Calendar.current.component(.weekday, from: Date()) == 1 }
        return false
    }

    private func buildTrainingLine(store: InsightsDataStore) -> BriefLine? {
        guard let program = store.activeProgram else {
            let cal = Calendar.current
            let weekAgo = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let recent = store.workoutHistory.filter { $0.date >= weekAgo }
            if !recent.isEmpty {
                let lastDays = cal.dateComponents([.day], from: recent.first?.date ?? Date(), to: Date()).day ?? 0
                return BriefLine(
                    label: "Training",
                    value: "\(recent.count) session\(recent.count == 1 ? "" : "s") last 7d",
                    detail: "Last logged \(lastDays)d ago. Add a program for adaptive targets.",
                    tone: .neutral
                )
            }
            if let last = store.workoutHistory.first {
                let days = cal.dateComponents([.day], from: last.date, to: Date()).day ?? 0
                return BriefLine(
                    label: "Training",
                    value: "Last session \(days)d ago",
                    detail: "Add a program to lock in volume targets.",
                    tone: .caution
                )
            }
            return nil
        }
        let recovering = store.muscleRecovery
            .filter { $0.status != .recovered }
            .map { $0.muscle.rawValue }
        let today = Date()
        let doneToday = store.workoutHistory.contains { Calendar.current.isDate($0.date, inSameDayAs: today) }
        if doneToday {
            return BriefLine(
                label: "Training",
                value: "Today's session complete",
                detail: program.name,
                tone: .positive
            )
        }
        if !recovering.isEmpty {
            return BriefLine(
                label: "Training",
                value: "Heads up: \(recovering.prefix(2).joined(separator: ", ")) still recovering",
                detail: "Keep loads moderate on those groups today.",
                tone: .caution
            )
        }
        return BriefLine(
            label: "Training",
            value: program.name,
            detail: "Session ahead — green light to push.",
            tone: .neutral
        )
    }

    private func buildNutritionLine(store: InsightsDataStore) -> BriefLine? {
        let target = store.macroTarget
        let consumed = store.todayMeals.reduce(0) { $0 + $1.totalCalories }
        let protein = store.todayMeals.reduce(0.0) { $0 + $1.totalProtein }
        if consumed == 0 {
            let cal = Calendar.current
            // Try yesterday
            if let y = cal.date(byAdding: .day, value: -1, to: Date()),
               let yMeals = store.recentMealsByDay[cal.startOfDay(for: y)], !yMeals.isEmpty {
                let yCal = yMeals.reduce(0) { $0 + $1.totalCalories }
                let yProt = Int(yMeals.reduce(0.0) { $0 + $1.totalProtein })
                return BriefLine(
                    label: "Nutrition",
                    value: "Target \(target.calories) cal · \(target.protein)g protein",
                    detail: "Yesterday landed at \(yCal) cal / \(yProt)g. Log your first meal to track today.",
                    tone: .neutral
                )
            }
            // Try 7d avg
            let last7 = (1...7).compactMap { i -> [LoggedMeal]? in
                guard let d = cal.date(byAdding: .day, value: -i, to: Date()) else { return nil }
                return store.recentMealsByDay[cal.startOfDay(for: d)]
            }.flatMap { $0 }
            if !last7.isEmpty {
                let days = max(1, Set(last7.map { cal.startOfDay(for: $0.timestamp) }).count)
                let avgCal = last7.reduce(0) { $0 + $1.totalCalories } / days
                let avgProt = Int(last7.reduce(0.0) { $0 + $1.totalProtein }) / days
                return BriefLine(
                    label: "Nutrition",
                    value: "Target \(target.calories) cal · \(target.protein)g protein",
                    detail: "7d avg \(avgCal) cal / \(avgProt)g protein. Log today's first meal.",
                    tone: .neutral
                )
            }
            return BriefLine(
                label: "Nutrition",
                value: "\(target.calories) cal · \(target.protein)g protein target",
                detail: "Log your first meal to start tracking.",
                tone: .neutral
            )
        }
        let pctProtein = target.protein > 0 ? Int(protein / Double(target.protein) * 100) : 0
        let remaining = max(target.calories - consumed, 0)
        let tone: BriefLine.Tone = pctProtein < 35 ? .caution : .neutral
        return BriefLine(
            label: "Nutrition",
            value: "\(consumed)/\(target.calories) cal · \(Int(protein))/\(target.protein)g protein",
            detail: "\(remaining) cal remaining. \(pctProtein)% of protein banked.",
            tone: tone
        )
    }

    private func buildSupplyLine(store: InsightsDataStore) -> BriefLine? {
        // BUD-imminent vials outrank low stock.
        let budSoon = store.vialInventory.filter { v in
            if let d = v.daysUntilBUD, d >= 0, d <= 2, !v.isExpired { return true }
            return false
        }
        if let v = budSoon.first {
            let days = v.daysUntilBUD ?? 0
            return BriefLine(
                label: "Supply",
                value: "\(v.compoundName) · BUD in \(days)d",
                detail: "Use or discard soon.",
                tone: .warning
            )
        }
        if let low = store.lowStockForecasts.first {
            let tone: BriefLine.Tone = low.isCritical ? .warning : .caution
            return BriefLine(
                label: "Supply",
                value: "\(low.compoundName) · \(low.chipLabel)",
                detail: "Reorder before you run dry.",
                tone: tone
            )
        }
        return nil
    }

    private func buildBloodworkLine(store: InsightsDataStore) -> BriefLine? {
        guard let interp = store.bloodworkInterpretation else { return nil }
        let tone: BriefLine.Tone = interp.providerFlag ? .warning : (interp.flags.isEmpty ? .positive : .caution)
        let flagCount = interp.flags.count
        let value = flagCount == 0 ? "All values in range" : "\(flagCount) flagged value\(flagCount == 1 ? "" : "s")"
        return BriefLine(label: "Bloodwork", value: value, detail: interp.headline, tone: tone)
    }

    private func buildBodyGoalLine(store: InsightsDataStore) -> BriefLine? {
        guard store.targetWeight > 0, let latest = store.weightEntries.last?.weight, latest > 0 else { return nil }
        let start = store.startingWeight > 0 ? store.startingWeight : latest
        let total = abs(start - store.targetWeight)
        guard total > 0 else { return nil }
        let done = max(0, min(total, total - abs(latest - store.targetWeight)))
        let pct = Int((done / total) * 100)
        let remaining = abs(latest - store.targetWeight)
        return BriefLine(
            label: "Body goal",
            value: "\(pct)% to goal",
            detail: "\(String(format: "%.1f", remaining)) lb to go from \(String(format: "%.1f", latest)) lb.",
            tone: pct >= 90 ? .positive : .neutral
        )
    }

    private func pickWatchFor() -> String? {
        let facts = AIMemoryStore.shared.allFacts()
        if let fact = facts.first(where: { $0.kind == .correlation || $0.kind == .pattern }) {
            return fact.headline
        }
        return nil
    }
}
