import Foundation
import HealthKit

/// Generates predictive forecasts (weight trajectory, flare risk, PR readiness)
/// from the user's own data. Math-first — no AI calls needed, so it's fast and
/// deterministic. Results cached by data hash + refreshed weekly.
@MainActor
@Observable
final class ForecastService {
    static let shared = ForecastService()

    var bundle: ForecastBundle?
    var isGenerating: Bool = false

    private let cacheKey = "forecast_bundle_v1"
    private let refreshInterval: TimeInterval = 3 * 24 * 60 * 60 // 3 days

    private init() { loadCached() }

    func refreshIfNeeded(force: Bool = false) {
        if !force, let b = bundle,
           Date().timeIntervalSince(b.generatedAt) < refreshInterval,
           b.dataHash == InsightsDataStore.shared.dataHash {
            return
        }
        Task { await generate() }
    }

    func generate() async {
        isGenerating = true
        defer { isGenerating = false }

        let store = InsightsDataStore.shared
        let weight = forecastWeight(store: store)
        let flare = await forecastFlare(store: store)
        let prs = forecastPRReadiness(store: store)

        let b = ForecastBundle(
            weight: weight,
            flare: flare,
            prReadiness: prs,
            generatedAt: Date(),
            dataHash: store.dataHash
        )
        bundle = b
        cache(b)
    }

    // MARK: - Weight trajectory

    private func forecastWeight(store: InsightsDataStore) -> WeightForecast? {
        let entries = store.weightEntries.sorted { $0.date < $1.date }
        guard entries.count >= 3, let first = entries.first, let last = entries.last else { return nil }
        let days = max(7.0, Date().timeIntervalSince(first.date) / 86400)
        let totalChange = last.weight - first.weight
        let weeklyRate = totalChange / (days / 7.0)

        // Plateau: stdev of last 7 entries small relative to weekly rate
        let recent = entries.suffix(7).map(\.weight)
        let mean = recent.reduce(0, +) / Double(recent.count)
        let variance = recent.reduce(0.0) { $0 + pow($1 - mean, 2) } / Double(recent.count)
        let std = sqrt(variance)
        let plateauRisk: Int = {
            if abs(weeklyRate) < 0.2 && std < 0.6 { return 78 }
            if abs(weeklyRate) < 0.4 { return 45 }
            return 18
        }()

        var points: [WeightForecastPoint] = []
        let cal = Calendar.current
        let sigma = max(std, 0.4)
        for weekOffset in 1...4 {
            guard let date = cal.date(byAdding: .day, value: weekOffset * 7, to: Date()) else { continue }
            let projected = last.weight + weeklyRate * Double(weekOffset)
            let band = sigma * sqrt(Double(weekOffset))
            points.append(WeightForecastPoint(
                date: date,
                projected: projected,
                lowerBound: projected - band,
                upperBound: projected + band
            ))
        }

        let direction = weeklyRate < -0.2 ? "losing" : (weeklyRate > 0.2 ? "gaining" : "holding")
        let reasoning = "Over the last \(Int(days)) days you're \(direction) an average of \(String(format: "%.2f", weeklyRate)) lb/week. Calibrated on \(entries.count) weigh-ins."

        return WeightForecast(
            currentWeight: last.weight,
            goalWeight: store.targetWeight,
            weeklyRate: weeklyRate,
            plateauRiskPercent: plateauRisk,
            points: points,
            reasoning: reasoning,
            calibrationDays: Int(days)
        )
    }

    // MARK: - Flare risk

    private func forecastFlare(store: InsightsDataStore) async -> FlareRisk? {
        guard let proto = store.primaryProtocol else { return nil }
        var drivers: [String] = []
        var score = 0

        let recent = proto.sideEffectLog.filter {
            Calendar.current.dateComponents([.day], from: $0.timestamp, to: Date()).day ?? 999 <= 7
        }
        if recent.count >= 2 {
            drivers.append("\(recent.count) side effects in the last week")
            score += 20
        }
        if recent.contains(where: { $0.severity >= 3 }) {
            drivers.append("moderate+ severity reported")
            score += 15
        }

        let hk = HealthKitService.shared
        if hk.isAuthorized {
            let sleep = await hk.fetchSleepHistory(days: 5)
            let avg = sleep.isEmpty ? 8 : sleep.map(\.asleepHours).reduce(0, +) / Double(sleep.count)
            if avg < 6.5 {
                drivers.append("sleep averaging \(String(format: "%.1f", avg))h, below 6.5h threshold")
                score += 18
            }
            if let hrv = hk.hrv, hrv < 40 {
                drivers.append("HRV trending low at \(Int(hrv)) ms")
                score += 12
            }
        }

        // Dose ramp: did dose change in the last 10 days?
        if let compound = proto.compounds.first {
            let history = proto.doseLog.filter { !$0.wasSkipped }
            let last10 = history.filter {
                Calendar.current.dateComponents([.day], from: $0.timestamp, to: Date()).day ?? 999 <= 10
            }
            let earlier = history.filter {
                let d = Calendar.current.dateComponents([.day], from: $0.timestamp, to: Date()).day ?? 0
                return d > 10 && d <= 30
            }
            if let recentAvg = average(last10.map(\.doseMcg)),
               let earlierAvg = average(earlier.map(\.doseMcg)),
               earlierAvg > 0,
               (recentAvg - earlierAvg) / earlierAvg > 0.15 {
                drivers.append("\(compound.compoundName) dose up \(Int((recentAvg - earlierAvg) / earlierAvg * 100))% vs prior weeks")
                score += 22
            }
        }

        let level: FlareRisk.RiskLevel
        switch score {
        case 0..<20: level = .low
        case 20..<45: level = .elevated
        default: level = .high
        }

        let reasoning: String
        switch level {
        case .low: reasoning = "Signals are mostly clean. No clustered flare drivers in the last week."
        case .elevated: reasoning = "A few flare drivers are stacking up. Good time to protect sleep and hydration."
        case .high: reasoning = "Multiple flare drivers are stacking. Consider easing intensity and talking to your provider if symptoms worsen."
        }

        return FlareRisk(
            riskLevel: level,
            scorePercent: min(score, 100),
            drivers: drivers,
            reasoning: reasoning
        )
    }

    // MARK: - PR readiness

    private func forecastPRReadiness(store: InsightsDataStore) -> [PRReadiness] {
        let hist = store.workoutHistory
        guard !hist.isEmpty else { return [] }
        var perExercise: [String: [(date: Date, topWeight: Double)]] = [:]
        for w in hist {
            for ex in w.exercises {
                let top = ex.sets.map(\.weight).max() ?? 0
                if top > 0 {
                    perExercise[ex.exerciseName, default: []].append((w.date, top))
                }
            }
        }

        let hk = HealthKitService.shared
        let recoveryGreen = (hk.recoveryScore ?? 0) >= 75
        let sleepOk = hk.sleepHours >= 7
        let recoveringMuscles = Set(store.muscleRecovery
            .filter { $0.status != .recovered }
            .map { $0.muscle.rawValue.lowercased() })

        var out: [PRReadiness] = []
        for (name, sessions) in perExercise {
            let sorted = sessions.sorted { $0.date > $1.date }
            guard sorted.count >= 3 else { continue }
            let latest = sorted[0].topWeight
            let prev = sorted[1].topWeight
            let prior = sorted[2].topWeight

            var readiness = 50
            var greens: [String] = []
            var reds: [String] = []

            if latest >= prev, prev >= prior {
                readiness += 20
                greens.append("progressing 2 sessions in a row at \(Int(latest)) lb")
            } else if latest < prev {
                readiness -= 18
                reds.append("last session regressed from \(Int(prev)) to \(Int(latest)) lb")
            }
            if recoveryGreen {
                readiness += 14
                greens.append("recovery score in the green")
            } else if hk.isAuthorized {
                reds.append("recovery score not yet in green zone")
            }
            if sleepOk {
                readiness += 8
                greens.append("slept \(String(format: "%.1f", hk.sleepHours))h")
            } else if hk.isAuthorized {
                reds.append("sleep under 7h")
            }

            let primaryMuscle = primaryMuscle(forExercise: name)
            if let m = primaryMuscle, recoveringMuscles.contains(m.lowercased()) {
                readiness -= 20
                reds.append("\(m) still recovering")
            }

            readiness = max(5, min(99, readiness))

            let rec: String
            if readiness >= 75 {
                rec = "Good day to push. Warm up thorough, then target a small PR (+5 lb or +1 rep)."
            } else if readiness >= 50 {
                rec = "Leaning toward a clean volume day — save the max attempt for later in the week."
            } else {
                rec = "Not the day for a PR. Hit your working sets and bank recovery."
            }

            out.append(PRReadiness(
                exercise: name,
                readinessPercent: readiness,
                recommendation: rec,
                greenLights: greens,
                redFlags: reds
            ))
        }
        return out.sorted { $0.readinessPercent > $1.readinessPercent }.prefix(5).map { $0 }
    }

    private func primaryMuscle(forExercise name: String) -> String? {
        let lower = name.lowercased()
        if lower.contains("bench") || lower.contains("press") && !lower.contains("leg") { return "chest" }
        if lower.contains("squat") || lower.contains("leg press") { return "quads" }
        if lower.contains("deadlift") || lower.contains("row") { return "back" }
        if lower.contains("curl") { return "biceps" }
        if lower.contains("tricep") || lower.contains("pushdown") { return "triceps" }
        if lower.contains("shoulder") || lower.contains("ohp") || lower.contains("overhead") { return "shoulders" }
        return nil
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    // MARK: - Persistence

    private func loadCached() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode(ForecastBundle.self, from: data) else { return }
        bundle = decoded
    }

    private func cache(_ b: ForecastBundle) {
        if let data = try? JSONEncoder().encode(b) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
}
