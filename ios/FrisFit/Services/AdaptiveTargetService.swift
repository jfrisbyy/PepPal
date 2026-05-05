import Foundation
import SwiftUI

/// Weekly recalibration that proposes adjustments to calorie target, protein
/// target, training volume, and dose-day nutrition based on actual trajectory.
/// Every proposal is surfaced to the user for review — nothing changes silently.
@MainActor
@Observable
final class AdaptiveTargetService {
    static let shared = AdaptiveTargetService()

    var latestRecalibration: WeeklyRecalibration?
    var pendingAdjustments: [AdaptiveAdjustment] = []

    private let cacheKey = "adaptive_recalibration_v1"
    private let pendingKey = "adaptive_pending_v1"

    private init() { load() }

    var shouldRecalibrate: Bool {
        guard let last = latestRecalibration else { return true }
        return Date().timeIntervalSince(last.generatedAt) > 6 * 24 * 60 * 60
    }

    func recalibrate(force: Bool = false) async {
        guard force || shouldRecalibrate else { return }
        let store = InsightsDataStore.shared
        var adjustments: [AdaptiveAdjustment] = []

        adjustments.append(contentsOf: calorieAdjustment(store: store))
        adjustments.append(contentsOf: proteinAdjustment(store: store))
        adjustments.append(contentsOf: trainingVolumeAdjustment(store: store))
        adjustments.append(contentsOf: doseDayAdjustment(store: store))

        let summary = buildSummary(adjustments)
        let weekStart = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        let recalibration = WeeklyRecalibration(
            weekStart: weekStart,
            adjustments: adjustments,
            summary: summary,
            generatedAt: Date()
        )
        latestRecalibration = recalibration
        pendingAdjustments = adjustments
        persist()
    }

    func accept(_ id: UUID) {
        guard let idx = pendingAdjustments.firstIndex(where: { $0.id == id }) else { return }
        pendingAdjustments[idx].status = .accepted
        apply(pendingAdjustments[idx])
        persist()
    }

    func dismiss(_ id: UUID) {
        guard let idx = pendingAdjustments.firstIndex(where: { $0.id == id }) else { return }
        pendingAdjustments[idx].status = .dismissed
        persist()
    }

    func revert(_ id: UUID) {
        guard let idx = pendingAdjustments.firstIndex(where: { $0.id == id }) else { return }
        pendingAdjustments[idx].status = .reverted
        persist()
    }

    var activeProposals: [AdaptiveAdjustment] {
        pendingAdjustments.filter { $0.status == .proposed }
    }

    // MARK: - Computations

    private func calorieAdjustment(store: InsightsDataStore) -> [AdaptiveAdjustment] {
        let target = store.macroTarget
        let entries = store.weightEntries.sorted { $0.date < $1.date }
        guard entries.count >= 4,
              let first = entries.first, let last = entries.last else { return [] }
        let days = max(7.0, Date().timeIntervalSince(first.date) / 86400)
        let weeklyRate = (last.weight - first.weight) / (days / 7.0)
        let goal = store.targetWeight
        let currentTarget = target.calories
        let isLosing = goal < last.weight
        let isGaining = goal > last.weight

        var delta = 0
        var reason = ""

        if isLosing {
            if weeklyRate > -0.3 {
                delta = -150
                reason = "Losing \(String(format: "%.2f", weeklyRate)) lb/week — below a healthy deficit. Trim \(-delta) cal to restart movement."
            } else if weeklyRate < -2.0 {
                delta = 200
                reason = "Dropping \(String(format: "%.2f", weeklyRate)) lb/week — aggressive for muscle retention. Add \(delta) cal to protect lean mass."
            }
        } else if isGaining {
            if weeklyRate < 0.2 {
                delta = 150
                reason = "Gaining only \(String(format: "%.2f", weeklyRate)) lb/week — under-fueled for a bulk. Add \(delta) cal."
            } else if weeklyRate > 1.0 {
                delta = -150
                reason = "Gaining \(String(format: "%.2f", weeklyRate)) lb/week — faster than lean bulk pace. Trim \(-delta) cal."
            }
        }

        guard delta != 0 else { return [] }
        let proposed = max(1200, currentTarget + delta)
        return [AdaptiveAdjustment(
            domain: .calories,
            label: "Daily calorie target",
            previousValue: "\(currentTarget) cal",
            proposedValue: "\(proposed) cal",
            reasoning: reason
        )]
    }

    private func proteinAdjustment(store: InsightsDataStore) -> [AdaptiveAdjustment] {
        let target = store.macroTarget
        let meals = store.recentMealsByDay
        guard meals.count >= 5 else { return [] }
        let days = meals.keys.sorted()
        let totals = days.map { day -> Double in
            (meals[day] ?? []).reduce(0) { $0 + $1.totalProtein }
        }
        let avg = totals.reduce(0, +) / Double(totals.count)
        let hitRate = Double(totals.filter { $0 >= Double(target.protein) * 0.9 }.count) / Double(totals.count)

        // Recomp signal: weight flat + body measurements trending down
        let weights = store.weightEntries.sorted { $0.date < $1.date }
        let hasRecompSignal: Bool = {
            guard weights.count >= 4, let first = weights.first, let last = weights.last else { return false }
            let weeklyChange = abs(last.weight - first.weight) / max(1, Date().timeIntervalSince(first.date) / (7 * 86400))
            return weeklyChange < 0.3
        }()

        var adjustments: [AdaptiveAdjustment] = []
        if hasRecompSignal && target.protein < 180 && avg >= Double(target.protein) * 0.9 {
            let proposed = min(target.protein + 15, 220)
            adjustments.append(AdaptiveAdjustment(
                domain: .protein,
                label: "Daily protein target",
                previousValue: "\(target.protein)g",
                proposedValue: "\(proposed)g",
                reasoning: "Weight is holding flat while you're hitting protein on \(Int(hitRate * 100))% of logged days — recomp signal. Raising the target \(proposed - target.protein)g gives lean mass more material to work with."
            ))
        } else if hitRate < 0.4 && avg > 0 {
            adjustments.append(AdaptiveAdjustment(
                domain: .protein,
                label: "Protein plan — front-load",
                previousValue: "\(Int(avg))g avg",
                proposedValue: "\(target.protein)g, 40g by lunch",
                reasoning: "Hitting protein only \(Int(hitRate * 100))% of the time. Front-loading 40g by lunch makes the evening math much easier."
            ))
        }
        return adjustments
    }

    private func trainingVolumeAdjustment(store: InsightsDataStore) -> [AdaptiveAdjustment] {
        let volumes = store.weeklyVolumes
        guard !volumes.isEmpty else { return [] }
        var adjustments: [AdaptiveAdjustment] = []
        for v in volumes {
            if v.targetSets > 0 && v.setsCompleted < v.targetSets - 3 {
                adjustments.append(AdaptiveAdjustment(
                    domain: .training,
                    label: "\(v.muscle.rawValue) volume",
                    previousValue: "\(v.setsCompleted)/\(v.targetSets) sets",
                    proposedValue: "add 2-3 sets this week",
                    reasoning: "\(v.muscle.rawValue) is \(v.targetSets - v.setsCompleted) sets short of target. Adding 2-3 targeted sets keeps weekly volume on track."
                ))
            }
        }
        return Array(adjustments.prefix(2))
    }

    private func doseDayAdjustment(store: InsightsDataStore) -> [AdaptiveAdjustment] {
        guard let proto = store.primaryProtocol else { return [] }
        let recentEffects = proto.sideEffectLog.filter {
            Calendar.current.dateComponents([.day], from: $0.timestamp, to: Date()).day ?? 999 <= 30
        }
        let appetiteSuppressors = recentEffects.filter {
            let name = $0.effect.lowercased()
            return name.contains("nausea") || name.contains("appetite") || name.contains("fullness")
        }
        guard appetiteSuppressors.count >= 3 else { return [] }
        return [AdaptiveAdjustment(
            domain: .doseDayNutrition,
            label: "Dose-day nutrition plan",
            previousValue: "Same as any other day",
            proposedValue: "Front-load protein + calories before dose",
            reasoning: "\(appetiteSuppressors.count) appetite-suppressing side effects logged in the last 30 days. Eating 60%+ of your calories before the dose protects macros and lean mass."
        )]
    }

    private func buildSummary(_ adjustments: [AdaptiveAdjustment]) -> String {
        if adjustments.isEmpty {
            return "Your targets are tracking well — nothing to change this week."
        }
        return "\(adjustments.count) proposed adjustment\(adjustments.count == 1 ? "" : "s") based on your last week of data. Review and accept the ones that make sense."
    }

    // MARK: - Apply

    private func apply(_ adj: AdaptiveAdjustment) {
        // Integration points are intentionally light: we record the acceptance
        // in memory so subsequent AI outputs respect it. Concrete numeric
        // updates are still owned by the feature that owns that data
        // (AdaptiveMacroStore, program builder, etc.).
        AIMemoryStore.shared.upsert(AIMemoryFact(
            kind: .preference,
            headline: "Accepted adjustment: \(adj.label)",
            detail: "\(adj.previousValue) → \(adj.proposedValue). Reason: \(adj.reasoning)",
            domain: adj.domain.rawValue,
            confidence: 0.85
        ))
    }

    // MARK: - Persistence

    private func persist() {
        if let r = latestRecalibration, let data = try? JSONEncoder().encode(r) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
        if let data = try? JSONEncoder().encode(pendingAdjustments) {
            UserDefaults.standard.set(data, forKey: pendingKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let decoded = try? JSONDecoder().decode(WeeklyRecalibration.self, from: data) {
            latestRecalibration = decoded
        }
        if let data = UserDefaults.standard.data(forKey: pendingKey),
           let decoded = try? JSONDecoder().decode([AdaptiveAdjustment].self, from: data) {
            pendingAdjustments = decoded
        }
    }
}
