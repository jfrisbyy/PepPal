import Foundation
import HealthKit

/// Runs the 14 tools the insights agent can call. Tool results are returned as
/// compact strings the model can reason over, plus structured EvidencePoints for UI.
@MainActor
final class InsightToolkit {
    static let shared = InsightToolkit()

    private var store: InsightsDataStore { InsightsDataStore.shared }
    private var hk: HealthKitService { HealthKitService.shared }

    private init() {}

    struct ToolResult: Sendable {
        let text: String
        let evidence: [EvidencePoint]
    }

    nonisolated static let toolDefinitions: [[String: Any]] = [
        tool("get_protocol_overview", "Active protocol(s): compound, dose, start date, current week, phase, total doses logged, days since start, expected effects from internal compound database.", params: [:]),
        tool("get_hrv_trend", "Daily HRV (SDNN, ms) for the last N days. Returns average, latest, percent change over the window. Use to assess recovery trend.", params: ["days": intParam("Number of days to look back (7, 14, 30). Default 14.", default: 14)]),
        tool("get_recovery_trend", "Composite recovery score (HRV + resting HR + sleep + respiratory rate) trend over the last N days. Returns series + avg, latest, change.", params: ["days": intParam("Number of days to look back. Default 14.", default: 14)]),
        tool("get_sleep_debt", "Sleep hours per night for the last N days, target hours, total debt vs target.", params: ["days": intParam("Days to look back. Default 7.", default: 7), "target": intParam("Target hours per night. Default 8.", default: 8)]),
        tool("get_training_volume_weekly", "Total training volume (sets and lbs) per week for the last N weeks, plus week-over-week change percent.", params: ["weeks": intParam("Weeks to look back. Default 4.", default: 4)]),
        tool("get_training_adherence", "Training adherence: sessions completed vs scheduled for the last N weeks. Returns percent and trend.", params: ["weeks": intParam("Weeks to look back. Default 4.", default: 4)]),
        tool("get_pr_velocity", "Recent PRs with dates and previous best. Shows how fast lifts are progressing.", params: [:]),
        tool("get_muscle_volume_balance", "Weekly volume vs target per muscle group for this week. Flags under/over-worked groups.", params: [:]),
        tool("get_nutrition_trend", "Daily calories and protein for the last N days vs target. Returns average, days target hit, calories on training vs rest days.", params: ["days": intParam("Days to look back. Default 7.", default: 7)]),
        tool("get_meal_timing", "Meal-time distribution: what percent of calories are eaten before noon, 12-6pm, after 6pm.", params: [:]),
        tool("get_body_trajectory", "Weight trend: current, starting, target, weekly loss/gain rate, plateau detection, distance to goal, latest waist/chest/hips measurements.", params: [:]),
        tool("get_side_effect_frequency", "Side effects reported per week for the last N weeks, most common symptoms, severity trend, correlation with dose days.", params: ["weeks": intParam("Weeks to look back. Default 4.", default: 4)]),
        tool("get_bloodwork_deltas", "Most recent bloodwork panel: flagged biomarkers, values, and delta vs previous panel if available.", params: [:]),
        tool("get_dose_day_comparison", "Compare a metric on dose days vs non-dose days. Metrics: 'training_volume', 'calories', 'protein', 'hrv', 'sleep', 'side_effects'. Use to surface cross-domain correlations.", params: ["metric": stringParam("One of training_volume, calories, protein, hrv, sleep, side_effects", enumValues: ["training_volume", "calories", "protein", "hrv", "sleep", "side_effects"])]),
        tool("get_progression_stalls", "Identify exercises where the working weight has not moved in the last 3+ sessions. Flags candidates for a deload or rep-scheme change.", params: [:]),
        tool("get_sleep_vs_performance", "Correlate sleep hours with training performance (volume) on the following day. Returns avg volume on well-rested vs under-rested days.", params: ["threshold": intParam("Sleep hours threshold that divides well-rested vs under-rested. Default 7.", default: 7)]),
        tool("get_what_changed_this_week", "Summarize the biggest changes in the user's recent data vs the prior week — HRV, sleep, training volume, calories, protein, weight, and side effect counts. Used for 'what changed this week' chips and weekly digests.", params: [:]),
        tool("get_protein_deficit_today", "Return how much protein the user still needs to hit their daily target, how many hours are left, and whether they are ahead or behind pace.", params: [:]),
        tool("get_today_nutrition_status", "Return calories consumed today, calories remaining, protein remaining, and whether today is a dose day and/or a training day.", params: [:]),
        tool("get_measurement_gaps", "Return how many days since the user last logged a weight entry or body measurement. Flags entries that are overdue.", params: [:]),
        tool("get_dose_schedule_today", "Return today's scheduled doses by compound and whether each has been logged yet.", params: [:]),
        tool("get_water_status", "Today's water intake (ml + oz), daily goal, and 7-day adherence (% of days hitting goal).", params: [:]),
        tool("get_cardio_history", "Most recent cardio sessions (runs + rides) with date, distance, duration, avg HR, calories. Use to assess endurance load alongside resistance training.", params: ["limit": intParam("How many recent sessions to return. Default 6.", default: 6)]),
        tool("get_streak_status", "Current logging streak, longest streak, last activity date, and whether yesterday was missed.", params: [:]),
        tool("get_multi_protocol_history", "All protocols on file (active + inactive): name, compounds, start/end dates, total doses logged, and side effect counts. Use to compare cycles or reference what worked before.", params: [:]),
        tool("get_cached_health_signals", "Latest HealthKit observable cache (no live fetch): HRV, resting heart rate, sleep hours, steps, active calories, mindful minutes. Cheaper than get_hrv_trend / get_recovery_trend when you only need the most recent values.", params: [:]),
    ]

    nonisolated private static func tool(_ name: String, _ description: String, params: [String: [String: Any]]) -> [String: Any] {
        var required: [String] = []
        var properties: [String: Any] = [:]
        for (k, v) in params {
            properties[k] = v
            required.append(k)
        }
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": [
                    "type": "object",
                    "properties": properties,
                    "required": required,
                ] as [String: Any]
            ] as [String: Any]
        ]
    }

    nonisolated private static func intParam(_ desc: String, default defaultValue: Int) -> [String: Any] {
        ["type": "integer", "description": "\(desc) Default \(defaultValue).", "default": defaultValue]
    }

    nonisolated private static func stringParam(_ desc: String, enumValues: [String] = []) -> [String: Any] {
        var d: [String: Any] = ["type": "string", "description": desc]
        if !enumValues.isEmpty { d["enum"] = enumValues }
        return d
    }

    func dispatch(_ name: String, arguments: [String: Any]) async -> ToolResult {
        switch name {
        case "get_protocol_overview": return getProtocolOverview()
        case "get_hrv_trend": return await getHRVTrend(days: intArg(arguments, "days", 14))
        case "get_recovery_trend": return await getRecoveryTrend(days: intArg(arguments, "days", 14))
        case "get_sleep_debt": return await getSleepDebt(days: intArg(arguments, "days", 7), target: intArg(arguments, "target", 8))
        case "get_training_volume_weekly": return getTrainingVolume(weeks: intArg(arguments, "weeks", 4))
        case "get_training_adherence": return getTrainingAdherence(weeks: intArg(arguments, "weeks", 4))
        case "get_pr_velocity": return getPRVelocity()
        case "get_muscle_volume_balance": return getMuscleVolumeBalance()
        case "get_nutrition_trend": return getNutritionTrend(days: intArg(arguments, "days", 7))
        case "get_meal_timing": return getMealTiming()
        case "get_body_trajectory": return getBodyTrajectory()
        case "get_side_effect_frequency": return getSideEffectFrequency(weeks: intArg(arguments, "weeks", 4))
        case "get_bloodwork_deltas": return getBloodworkDeltas()
        case "get_dose_day_comparison": return await getDoseDayComparison(metric: stringArg(arguments, "metric", "training_volume"))
        case "get_progression_stalls": return getProgressionStalls()
        case "get_sleep_vs_performance": return await getSleepVsPerformance(threshold: intArg(arguments, "threshold", 7))
        case "get_what_changed_this_week": return await getWhatChangedThisWeek()
        case "get_protein_deficit_today": return getProteinDeficitToday()
        case "get_today_nutrition_status": return getTodayNutritionStatus()
        case "get_measurement_gaps": return getMeasurementGaps()
        case "get_dose_schedule_today": return getDoseScheduleToday()
        case "get_water_status": return getWaterStatus()
        case "get_cardio_history": return getCardioHistory(limit: intArg(arguments, "limit", 6))
        case "get_streak_status": return getStreakStatus()
        case "get_multi_protocol_history": return await getMultiProtocolHistory()
        case "get_cached_health_signals": return getCachedHealthSignals()
        default:
            return ToolResult(text: "Unknown tool: \(name)", evidence: [])
        }
    }

    private func intArg(_ args: [String: Any], _ key: String, _ fallback: Int) -> Int {
        if let v = args[key] as? Int { return v }
        if let v = args[key] as? Double { return Int(v) }
        if let s = args[key] as? String, let v = Int(s) { return v }
        return fallback
    }

    private func stringArg(_ args: [String: Any], _ key: String, _ fallback: String) -> String {
        (args[key] as? String) ?? fallback
    }

    // MARK: - Tools

    private func getProtocolOverview() -> ToolResult {
        let active = store.activeProtocols.filter { $0.isActive }
        guard !active.isEmpty else {
            return ToolResult(text: "User has no active protocol.", evidence: [])
        }
        var text = ""
        var ev: [EvidencePoint] = []
        for p in active {
            let days = max(0, Calendar.current.dateComponents([.day], from: p.startDate, to: Date()).day ?? 0)
            let compounds = p.compounds.map { "\($0.compoundName) \(CompoundUnitHelper.displayDoseShort($0.doseMcg, for: $0.compoundName))" }.joined(separator: ", ")
            text += "Protocol \"\(p.name)\" (\(p.goal.rawValue)): week \(p.currentWeek), \(p.currentPhase.rawValue) phase, day \(days). Compounds: \(compounds). Doses logged: \(p.doseLog.filter { !$0.wasSkipped }.count). Side effects logged: \(p.sideEffectLog.count).\n"
            for c in p.compounds {
                if let profile = CompoundDatabase.all.first(where: { $0.name.lowercased() == c.compoundName.lowercased() }) {
                    text += "  • \(c.compoundName) expected effects: \(profile.sideEffects.prefix(4).joined(separator: ", ")).\n"
                    if !profile.watchOut.isEmpty {
                        let short = String(profile.watchOut.prefix(200))
                        text += "  • Watch out: \(short)\n"
                    }
                }
            }
            ev.append(EvidencePoint(label: p.name, value: "Day \(days) · \(compounds)", detail: "Started \(DateFormatter.localizedString(from: p.startDate, dateStyle: .medium, timeStyle: .none))", tool: "get_protocol_overview"))
        }
        return ToolResult(text: text, evidence: ev)
    }

    private func getHRVTrend(days: Int) async -> ToolResult {
        guard hk.isAuthorized else { return ToolResult(text: "HealthKit unavailable.", evidence: []) }
        let series = await hk.fetchDailyAverageSeries(for: .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), days: days)
        guard !series.isEmpty else { return ToolResult(text: "No HRV data in the last \(days) days.", evidence: []) }
        let values = series.map(\.value)
        let avg = values.reduce(0, +) / Double(values.count)
        let latest = values.last ?? 0
        let first = values.first ?? avg
        let change = first > 0 ? ((latest - first) / first * 100) : 0
        let text = "HRV (last \(days)d): avg \(Int(avg)) ms, latest \(Int(latest)) ms, \(String(format: "%+.0f", change))% vs start of window."
        let ev = [EvidencePoint(label: "HRV trend (\(days)d)", value: "\(Int(latest)) ms · \(String(format: "%+.0f", change))%", detail: "avg \(Int(avg)) ms", tool: "get_hrv_trend")]
        return ToolResult(text: text, evidence: ev)
    }

    private func getRecoveryTrend(days: Int) async -> ToolResult {
        guard hk.isAuthorized else { return ToolResult(text: "HealthKit unavailable.", evidence: []) }
        let hrvSeries = await hk.fetchDailyAverageSeries(for: .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), days: days)
        let rhrSeries = await hk.fetchDailyAverageSeries(for: .restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), days: days)
        let sleepSeries = await hk.fetchSleepHistory(days: days)
        guard !hrvSeries.isEmpty || !rhrSeries.isEmpty else {
            return ToolResult(text: "Not enough recovery data.", evidence: [])
        }
        // Compute daily composite (0-100)
        var scores: [(Date, Int)] = []
        let cal = Calendar.current
        let daysList = (0..<days).compactMap { cal.date(byAdding: .day, value: -$0, to: cal.startOfDay(for: Date())) }.sorted()
        for d in daysList {
            let key = cal.startOfDay(for: d)
            let hrv = hrvSeries.first { cal.isDate($0.date, inSameDayAs: key) }?.value
            let rhr = rhrSeries.first { cal.isDate($0.date, inSameDayAs: key) }?.value
            let sleep = sleepSeries.first { cal.isDate($0.date, inSameDayAs: key) }?.asleepHours
            var comps: [Double] = []
            if let h = hrv, h > 0 { comps.append(min(max((h - 20) / 80.0, 0), 1) * 100) }
            if let r = rhr, r > 0 { comps.append(min(max(1 - (r - 50) / 40.0, 0), 1) * 100) }
            if let s = sleep, s > 0 { comps.append(min(max(s / 8.0, 0), 1) * 100) }
            if !comps.isEmpty {
                scores.append((key, Int(comps.reduce(0, +) / Double(comps.count))))
            }
        }
        guard scores.count >= 2 else { return ToolResult(text: "Not enough recovery data for trend.", evidence: []) }
        let values = scores.map { Double($0.1) }
        let avg = values.reduce(0, +) / Double(values.count)
        let latest = values.last ?? 0
        let first = values.first ?? avg
        let change = first > 0 ? ((latest - first) / first * 100) : 0
        let text = "Recovery score (\(days)d): avg \(Int(avg))/100, latest \(Int(latest))/100, \(String(format: "%+.0f", change))% vs start."
        let ev = [EvidencePoint(label: "Recovery (\(days)d)", value: "\(Int(latest))/100 · \(String(format: "%+.0f", change))%", detail: "avg \(Int(avg))", tool: "get_recovery_trend")]
        return ToolResult(text: text, evidence: ev)
    }

    private func getSleepDebt(days: Int, target: Int) async -> ToolResult {
        guard hk.isAuthorized else { return ToolResult(text: "HealthKit unavailable.", evidence: []) }
        let series = await hk.fetchSleepHistory(days: days)
        guard !series.isEmpty else { return ToolResult(text: "No sleep data in the last \(days) days.", evidence: []) }
        let hours = series.map(\.asleepHours)
        let avg = hours.reduce(0, +) / Double(hours.count)
        let debt = max(0, Double(target * days) - hours.reduce(0, +))
        let below = hours.filter { $0 < Double(target) }.count
        let text = "Sleep (\(days)d): avg \(String(format: "%.1f", avg))h/night vs \(target)h target. Total debt: \(String(format: "%.1f", debt))h. \(below)/\(days) nights under target."
        let ev = [EvidencePoint(label: "Sleep \(days)d avg", value: "\(String(format: "%.1f", avg))h", detail: "debt \(String(format: "%.1f", debt))h", tool: "get_sleep_debt")]
        return ToolResult(text: text, evidence: ev)
    }

    private func getTrainingVolume(weeks: Int) -> ToolResult {
        let cal = Calendar.current
        let now = Date()
        var buckets: [Int: (volume: Int, sessions: Int)] = [:]
        for w in store.workoutHistory {
            let daysAgo = cal.dateComponents([.day], from: w.date, to: now).day ?? 0
            let weekIndex = daysAgo / 7
            if weekIndex >= weeks { continue }
            let e = buckets[weekIndex] ?? (0, 0)
            buckets[weekIndex] = (e.volume + w.totalVolume, e.sessions + 1)
        }
        guard !buckets.isEmpty else {
            return ToolResult(text: "No training logged in the last \(weeks) weeks.", evidence: [])
        }
        var text = "Training volume (last \(weeks) weeks):\n"
        for i in 0..<weeks {
            let b = buckets[i] ?? (0, 0)
            text += "  Week -\(i): \(b.volume) lbs across \(b.sessions) sessions\n"
        }
        let thisWeek = buckets[0]?.volume ?? 0
        let lastWeek = buckets[1]?.volume ?? 0
        let change = lastWeek > 0 ? ((Double(thisWeek) - Double(lastWeek)) / Double(lastWeek) * 100) : 0
        text += "Week-over-week: \(String(format: "%+.0f", change))%"
        let ev = [EvidencePoint(label: "Training volume WoW", value: "\(String(format: "%+.0f", change))%", detail: "\(thisWeek) vs \(lastWeek) lbs", tool: "get_training_volume_weekly")]
        return ToolResult(text: text, evidence: ev)
    }

    private func getTrainingAdherence(weeks: Int) -> ToolResult {
        guard let program = store.activeProgram, program.daysPerWeek > 0 else {
            return ToolResult(text: "No active training program.", evidence: [])
        }
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -(weeks * 7), to: Date()) ?? Date()
        let recent = store.workoutHistory.filter { $0.date >= cutoff }.count
        let expected = program.daysPerWeek * weeks
        let pct = expected > 0 ? Double(recent) / Double(expected) * 100 : 0
        let text = "Training adherence (\(weeks)w): \(recent)/\(expected) sessions = \(Int(pct))% of plan. Program: \(program.name), \(program.daysPerWeek) days/week."
        let ev = [EvidencePoint(label: "Adherence \(weeks)w", value: "\(Int(pct))%", detail: "\(recent)/\(expected) sessions", tool: "get_training_adherence")]
        return ToolResult(text: text, evidence: ev)
    }

    private func getPRVelocity() -> ToolResult {
        let prs = store.personalRecords.sorted { $0.dateAchieved > $1.dateAchieved }.prefix(6)
        guard !prs.isEmpty else { return ToolResult(text: "No PRs on record.", evidence: []) }
        var text = "Recent PRs:\n"
        for pr in prs {
            let ago = Calendar.current.dateComponents([.day], from: pr.dateAchieved, to: Date()).day ?? 0
            let prev = pr.previousBest.map { " (prev \(Int($0)))" } ?? ""
            text += "  • \(pr.exerciseName): \(Int(pr.weight)) x \(pr.reps)\(prev) — \(ago)d ago\(pr.isNew ? " [NEW]" : "")\n"
        }
        let ev = [EvidencePoint(label: "Recent PRs", value: "\(prs.count)", detail: prs.first.map { "\($0.exerciseName) \(Int($0.weight))" } ?? "", tool: "get_pr_velocity")]
        return ToolResult(text: text, evidence: ev)
    }

    private func getMuscleVolumeBalance() -> ToolResult {
        guard !store.weeklyVolumes.isEmpty else { return ToolResult(text: "No weekly volume data.", evidence: []) }
        var text = "Weekly volume vs target per muscle:\n"
        let under = store.weeklyVolumes.filter { $0.setsCompleted < $0.targetSets }
        let over = store.weeklyVolumes.filter { $0.setsCompleted > Int(Double($0.targetSets) * 1.2) }
        for v in store.weeklyVolumes {
            text += "  \(v.muscle.rawValue): \(v.setsCompleted)/\(v.targetSets) sets\n"
        }
        if !under.isEmpty {
            text += "Undervolume: \(under.map { $0.muscle.rawValue }.joined(separator: ", "))\n"
        }
        if !over.isEmpty {
            text += "Over target: \(over.map { $0.muscle.rawValue }.joined(separator: ", "))\n"
        }
        let ev = [EvidencePoint(label: "Volume balance", value: "\(under.count) under / \(over.count) over", detail: nil, tool: "get_muscle_volume_balance")]
        return ToolResult(text: text, evidence: ev)
    }

    private func getNutritionTrend(days: Int) -> ToolResult {
        let cal = Calendar.current
        let now = Date()
        let target = store.macroTarget
        var trainingDays: [Int] = []
        var restDays: [Int] = []
        var allCals: [Int] = []
        var allProt: [Double] = []
        var daysHit = 0
        var daysTracked = 0
        for i in 0..<days {
            guard let day = cal.date(byAdding: .day, value: -i, to: now) else { continue }
            let key = cal.startOfDay(for: day)
            let meals = store.recentMealsByDay[key] ?? (cal.isDateInToday(day) ? store.todayMeals : [])
            guard !meals.isEmpty else { continue }
            daysTracked += 1
            let cals = meals.reduce(0) { $0 + $1.totalCalories }
            let prot = meals.reduce(0) { $0 + $1.totalProtein }
            allCals.append(cals)
            allProt.append(prot)
            if abs(cals - target.calories) <= Int(Double(target.calories) * 0.1) { daysHit += 1 }
            let trained = store.workoutHistory.contains { cal.isDate($0.date, inSameDayAs: day) }
            if trained { trainingDays.append(cals) } else { restDays.append(cals) }
        }
        guard daysTracked > 0 else { return ToolResult(text: "No meals logged in the last \(days) days.", evidence: []) }
        let avgCal = allCals.reduce(0, +) / daysTracked
        let avgProt = Int(allProt.reduce(0, +) / Double(daysTracked))
        let trainingAvg = trainingDays.isEmpty ? 0 : trainingDays.reduce(0, +) / trainingDays.count
        let restAvg = restDays.isEmpty ? 0 : restDays.reduce(0, +) / restDays.count
        var text = "Nutrition (\(daysTracked)d logged of \(days)): avg \(avgCal) kcal (target \(target.calories)), avg protein \(avgProt)g (target \(target.protein)g). Calorie target hit \(daysHit)/\(daysTracked) days."
        if trainingAvg > 0 && restAvg > 0 {
            text += " Training days avg \(trainingAvg) kcal, rest days avg \(restAvg) kcal."
        }
        let ev = [EvidencePoint(label: "Nutrition \(days)d", value: "\(avgCal) kcal avg", detail: "protein \(avgProt)/\(target.protein)g", tool: "get_nutrition_trend")]
        return ToolResult(text: text, evidence: ev)
    }

    private func getMealTiming() -> ToolResult {
        let meals = store.todayMeals
        guard !meals.isEmpty else { return ToolResult(text: "No meals logged today yet.", evidence: []) }
        var morning = 0, midday = 0, evening = 0
        for m in meals {
            let h = Calendar.current.component(.hour, from: m.timestamp)
            switch h {
            case 0..<12: morning += m.totalCalories
            case 12..<18: midday += m.totalCalories
            default: evening += m.totalCalories
            }
        }
        let total = max(1, morning + midday + evening)
        let text = "Meal timing today: \(morning) kcal before noon (\(morning * 100 / total)%), \(midday) kcal 12-6pm (\(midday * 100 / total)%), \(evening) kcal after 6pm (\(evening * 100 / total)%)."
        let ev = [EvidencePoint(label: "Meal timing", value: "\(morning)/\(midday)/\(evening) kcal", detail: "AM / midday / PM", tool: "get_meal_timing")]
        return ToolResult(text: text, evidence: ev)
    }

    private func getBodyTrajectory() -> ToolResult {
        let entries = store.weightEntries.sorted { $0.date < $1.date }
        guard let current = entries.last else { return ToolResult(text: "No weight entries logged.", evidence: []) }
        let start = store.startingWeight > 0 ? store.startingWeight : (entries.first?.weight ?? current.weight)
        let target = store.targetWeight
        let change = current.weight - start
        var rateText = ""
        if entries.count >= 4 {
            let recent = entries.suffix(min(14, entries.count))
            if let first = recent.first, let last = recent.last {
                let weeks = max(1, Calendar.current.dateComponents([.weekOfYear], from: first.date, to: last.date).weekOfYear ?? 1)
                let rate = (last.weight - first.weight) / Double(weeks)
                rateText = " Weekly rate: \(String(format: "%+.2f", rate)) lbs/wk."
            }
        }
        var plateau = false
        if entries.count >= 3 {
            let r = entries.suffix(3).map(\.weight)
            plateau = (r.max() ?? 0) - (r.min() ?? 0) < 0.5
        }
        var measureText = ""
        if let latest = store.bodyMeasurements.sorted(by: { $0.date < $1.date }).last {
            var parts: [String] = []
            if let w = latest.waist { parts.append("waist \(String(format: "%.1f", w))in") }
            if let c = latest.chest { parts.append("chest \(String(format: "%.1f", c))in") }
            if let h = latest.hips { parts.append("hips \(String(format: "%.1f", h))in") }
            if !parts.isEmpty { measureText = " Latest measurements: \(parts.joined(separator: ", "))." }
        }
        let distance = target > 0 ? abs(current.weight - target) : 0
        let text = "Body: current \(String(format: "%.1f", current.weight)) lbs (start \(String(format: "%.1f", start)), target \(String(format: "%.1f", target))). Total change: \(String(format: "%+.1f", change)) lbs.\(rateText)\(plateau ? " Plateau detected (<0.5 lb over 3 entries)." : "")\(measureText) Distance to goal: \(String(format: "%.1f", distance)) lbs."
        let ev = [EvidencePoint(label: "Weight trajectory", value: "\(String(format: "%.1f", current.weight)) lbs", detail: "\(String(format: "%+.1f", change)) since start", tool: "get_body_trajectory")]
        return ToolResult(text: text, evidence: ev)
    }

    private func getSideEffectFrequency(weeks: Int) -> ToolResult {
        let all = store.activeProtocols.flatMap(\.sideEffectLog)
        let cutoff = Calendar.current.date(byAdding: .day, value: -(weeks * 7), to: Date()) ?? Date()
        let recent = all.filter { $0.timestamp >= cutoff }
        guard !recent.isEmpty else {
            return ToolResult(text: "No side effects logged in the last \(weeks) weeks.", evidence: [])
        }
        var counts: [String: Int] = [:]
        for e in recent { counts[e.effect, default: 0] += 1 }
        let sorted = counts.sorted { $0.value > $1.value }
        // Dose-day correlation
        let cal = Calendar.current
        let doseDays = Set(store.activeProtocols.flatMap(\.doseLog).filter { !$0.wasSkipped }.map { cal.startOfDay(for: $0.timestamp) })
        let onDose = recent.filter { doseDays.contains(cal.startOfDay(for: $0.timestamp)) }.count
        let offDose = recent.count - onDose
        let top = sorted.prefix(4).map { "\($0.key): \($0.value)x" }.joined(separator: ", ")
        let text = "Side effects (last \(weeks)w): \(recent.count) total. Most common: \(top). \(onDose) on dose days, \(offDose) on non-dose days."
        let ev = [EvidencePoint(label: "Side effects \(weeks)w", value: "\(recent.count) total", detail: top, tool: "get_side_effect_frequency")]
        return ToolResult(text: text, evidence: ev)
    }

    private func getBloodworkDeltas() -> ToolResult {
        let sorted = store.bloodwork.sorted { $0.date > $1.date }
        guard let latest = sorted.first else { return ToolResult(text: "No bloodwork on record.", evidence: []) }
        let daysSince = Calendar.current.dateComponents([.day], from: latest.date, to: Date()).day ?? 0
        let flagged = latest.results.filter { !$0.isInRange }
        var text = "Latest panel (\(daysSince)d ago): \(latest.results.count) biomarkers, \(flagged.count) flagged."
        if !flagged.isEmpty {
            text += " Out of range: " + flagged.map { "\($0.biomarker.rawValue) \($0.value) \($0.biomarker.unit) (\($0.status.rawValue))" }.joined(separator: ", ")
        }
        if let prev = sorted.dropFirst().first {
            var deltas: [String] = []
            for r in latest.results {
                if let pr = prev.results.first(where: { $0.biomarker == r.biomarker }) {
                    let d = r.value - pr.value
                    if abs(d) > abs(pr.value) * 0.05 {
                        deltas.append("\(r.biomarker.rawValue) \(String(format: "%+.1f", d))")
                    }
                }
            }
            if !deltas.isEmpty { text += " Notable changes vs prior panel: \(deltas.prefix(5).joined(separator: ", "))." }
        }
        if daysSince > 90 { text += " Recheck overdue." }
        let ev = [EvidencePoint(label: "Bloodwork", value: "\(flagged.count) flagged", detail: "\(daysSince)d ago", tool: "get_bloodwork_deltas")]
        return ToolResult(text: text, evidence: ev)
    }

    private func getDoseDayComparison(metric: String) async -> ToolResult {
        let cal = Calendar.current
        let doseDays = Set(store.activeProtocols.flatMap(\.doseLog).filter { !$0.wasSkipped }.map { cal.startOfDay(for: $0.timestamp) })
        guard !doseDays.isEmpty else { return ToolResult(text: "No logged doses, cannot compare dose days.", evidence: []) }

        switch metric {
        case "training_volume":
            var on: [Int] = [], off: [Int] = []
            for w in store.workoutHistory {
                let key = cal.startOfDay(for: w.date)
                if doseDays.contains(key) { on.append(w.totalVolume) } else { off.append(w.totalVolume) }
            }
            guard !on.isEmpty && !off.isEmpty else { return ToolResult(text: "Not enough overlap to compare training volume.", evidence: []) }
            let onAvg = on.reduce(0, +) / on.count
            let offAvg = off.reduce(0, +) / off.count
            let delta = offAvg > 0 ? Double(onAvg - offAvg) / Double(offAvg) * 100 : 0
            return ToolResult(
                text: "Training volume on dose days avg \(onAvg) lbs vs \(offAvg) on non-dose days (\(String(format: "%+.0f", delta))%).",
                evidence: [EvidencePoint(label: "Vol dose vs non-dose", value: "\(String(format: "%+.0f", delta))%", detail: "\(onAvg) vs \(offAvg) lbs", tool: "get_dose_day_comparison")]
            )
        case "calories":
            var on: [Int] = [], off: [Int] = []
            for (day, meals) in store.recentMealsByDay {
                let cals = meals.reduce(0) { $0 + $1.totalCalories }
                if doseDays.contains(day) { on.append(cals) } else { off.append(cals) }
            }
            guard !on.isEmpty && !off.isEmpty else { return ToolResult(text: "Not enough overlap to compare calories.", evidence: []) }
            let onAvg = on.reduce(0, +) / on.count
            let offAvg = off.reduce(0, +) / off.count
            let delta = offAvg > 0 ? Double(onAvg - offAvg) / Double(offAvg) * 100 : 0
            return ToolResult(
                text: "Calories on dose days avg \(onAvg) kcal vs \(offAvg) on non-dose days (\(String(format: "%+.0f", delta))%).",
                evidence: [EvidencePoint(label: "Cals dose vs non-dose", value: "\(String(format: "%+.0f", delta))%", detail: "\(onAvg) vs \(offAvg) kcal", tool: "get_dose_day_comparison")]
            )
        case "hrv":
            guard hk.isAuthorized else { return ToolResult(text: "HealthKit unavailable.", evidence: []) }
            let series = await hk.fetchDailyAverageSeries(for: .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), days: 30)
            var on: [Double] = [], off: [Double] = []
            for s in series {
                let key = cal.startOfDay(for: s.date)
                if doseDays.contains(key) { on.append(s.value) } else { off.append(s.value) }
            }
            guard !on.isEmpty && !off.isEmpty else { return ToolResult(text: "Not enough HRV overlap to compare.", evidence: []) }
            let onAvg = on.reduce(0, +) / Double(on.count)
            let offAvg = off.reduce(0, +) / Double(off.count)
            let delta = offAvg > 0 ? (onAvg - offAvg) / offAvg * 100 : 0
            return ToolResult(
                text: "HRV on dose days avg \(Int(onAvg)) ms vs \(Int(offAvg)) on non-dose days (\(String(format: "%+.0f", delta))%).",
                evidence: [EvidencePoint(label: "HRV dose vs non-dose", value: "\(String(format: "%+.0f", delta))%", detail: "\(Int(onAvg)) vs \(Int(offAvg)) ms", tool: "get_dose_day_comparison")]
            )
        case "sleep":
            guard hk.isAuthorized else { return ToolResult(text: "HealthKit unavailable.", evidence: []) }
            let series = await hk.fetchSleepHistory(days: 30)
            var on: [Double] = [], off: [Double] = []
            for s in series {
                let key = cal.startOfDay(for: s.date)
                if doseDays.contains(key) { on.append(s.asleepHours) } else { off.append(s.asleepHours) }
            }
            guard !on.isEmpty && !off.isEmpty else { return ToolResult(text: "Not enough sleep overlap to compare.", evidence: []) }
            let onAvg = on.reduce(0, +) / Double(on.count)
            let offAvg = off.reduce(0, +) / Double(off.count)
            let delta = offAvg > 0 ? (onAvg - offAvg) / offAvg * 100 : 0
            return ToolResult(
                text: "Sleep on dose days avg \(String(format: "%.1f", onAvg))h vs \(String(format: "%.1f", offAvg)) on non-dose days (\(String(format: "%+.0f", delta))%).",
                evidence: [EvidencePoint(label: "Sleep dose vs non-dose", value: "\(String(format: "%+.0f", delta))%", detail: "\(String(format: "%.1f", onAvg)) vs \(String(format: "%.1f", offAvg))h", tool: "get_dose_day_comparison")]
            )
        case "side_effects":
            let all = store.activeProtocols.flatMap(\.sideEffectLog)
            let on = all.filter { doseDays.contains(cal.startOfDay(for: $0.timestamp)) }.count
            let off = all.count - on
            return ToolResult(
                text: "Side effects on dose days: \(on). On non-dose days: \(off).",
                evidence: [EvidencePoint(label: "Effects dose vs non-dose", value: "\(on) vs \(off)", detail: nil, tool: "get_dose_day_comparison")]
            )
        case "protein":
            var on: [Double] = [], off: [Double] = []
            for (day, meals) in store.recentMealsByDay {
                let prot = meals.reduce(0) { $0 + $1.totalProtein }
                if doseDays.contains(day) { on.append(prot) } else { off.append(prot) }
            }
            guard !on.isEmpty && !off.isEmpty else { return ToolResult(text: "Not enough overlap to compare protein.", evidence: []) }
            let onAvg = on.reduce(0, +) / Double(on.count)
            let offAvg = off.reduce(0, +) / Double(off.count)
            let delta = offAvg > 0 ? (onAvg - offAvg) / offAvg * 100 : 0
            return ToolResult(
                text: "Protein on dose days avg \(Int(onAvg))g vs \(Int(offAvg))g on non-dose days (\(String(format: "%+.0f", delta))%).",
                evidence: [EvidencePoint(label: "Protein dose vs non-dose", value: "\(String(format: "%+.0f", delta))%", detail: "\(Int(onAvg)) vs \(Int(offAvg))g", tool: "get_dose_day_comparison")]
            )
        default:
            return ToolResult(text: "Unknown metric: \(metric)", evidence: [])
        }
    }

    // MARK: - New Tools

    private func getProgressionStalls() -> ToolResult {
        let history = store.workoutHistory.sorted { $0.date > $1.date }
        guard history.count >= 3 else {
            return ToolResult(text: "Not enough training history to detect stalls.", evidence: [])
        }
        var byExercise: [String: [(date: Date, maxWeight: Double)]] = [:]
        for w in history.prefix(20) {
            for ex in w.exercises {
                let maxW = ex.sets.compactMap({ $0.weight }).max() ?? 0
                guard maxW > 0 else { continue }
                byExercise[ex.exerciseName, default: []].append((w.date, maxW))
            }
        }
        var stalls: [(name: String, weight: Double, sessions: Int)] = []
        for (name, sessions) in byExercise where sessions.count >= 3 {
            let recent = Array(sessions.prefix(3))
            let weights = recent.map(\.maxWeight)
            let maxW = weights.max() ?? 0
            let minW = weights.min() ?? 0
            if maxW > 0 && maxW - minW < 2.5 {
                stalls.append((name, maxW, recent.count))
            }
        }
        guard !stalls.isEmpty else {
            return ToolResult(text: "No progression stalls detected in the last 3 sessions per lift.", evidence: [])
        }
        let sorted = stalls.sorted { $0.weight > $1.weight }.prefix(4)
        let text = "Stalled lifts (same top weight for 3+ sessions): " + sorted.map { "\($0.name) at \(Int($0.weight)) lbs" }.joined(separator: ", ")
        let ev = [EvidencePoint(label: "Stalled lifts", value: "\(sorted.count)", detail: sorted.map(\.name).joined(separator: ", "), tool: "get_progression_stalls")]
        return ToolResult(text: text, evidence: ev)
    }

    private func getSleepVsPerformance(threshold: Int) async -> ToolResult {
        guard hk.isAuthorized else { return ToolResult(text: "HealthKit unavailable.", evidence: []) }
        let sleep = await hk.fetchSleepHistory(days: 30)
        guard !sleep.isEmpty else { return ToolResult(text: "No sleep data available.", evidence: []) }
        let cal = Calendar.current
        var wellVolumes: [Int] = []
        var poorVolumes: [Int] = []
        for w in store.workoutHistory {
            guard let prevDay = cal.date(byAdding: .day, value: -1, to: w.date) else { continue }
            let sleepRec = sleep.first { cal.isDate($0.date, inSameDayAs: prevDay) }
            guard let s = sleepRec else { continue }
            if s.asleepHours >= Double(threshold) { wellVolumes.append(w.totalVolume) }
            else { poorVolumes.append(w.totalVolume) }
        }
        guard !wellVolumes.isEmpty && !poorVolumes.isEmpty else {
            return ToolResult(text: "Not enough overlap between sleep and training data to compare.", evidence: [])
        }
        let wellAvg = wellVolumes.reduce(0, +) / wellVolumes.count
        let poorAvg = poorVolumes.reduce(0, +) / poorVolumes.count
        let delta = poorAvg > 0 ? Double(wellAvg - poorAvg) / Double(poorAvg) * 100 : 0
        let text = "After \(threshold)+ hrs sleep: avg \(wellAvg) lbs volume (n=\(wellVolumes.count)). After less: avg \(poorAvg) lbs (n=\(poorVolumes.count)). Delta \(String(format: "%+.0f", delta))%."
        let ev = [EvidencePoint(label: "Sleep vs volume", value: "\(String(format: "%+.0f", delta))%", detail: "\(wellAvg) vs \(poorAvg) lbs", tool: "get_sleep_vs_performance")]
        return ToolResult(text: text, evidence: ev)
    }

    private func getWhatChangedThisWeek() async -> ToolResult {
        var lines: [String] = []
        var ev: [EvidencePoint] = []

        // HRV last 7 vs prior 7
        if hk.isAuthorized {
            let hrv = await hk.fetchDailyAverageSeries(for: .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), days: 14)
            if hrv.count >= 6 {
                let sorted = hrv.sorted { $0.date < $1.date }
                let half = sorted.count / 2
                let prior = Array(sorted.prefix(half)).map(\.value)
                let current = Array(sorted.suffix(sorted.count - half)).map(\.value)
                let priorAvg = prior.reduce(0, +) / Double(max(prior.count, 1))
                let currentAvg = current.reduce(0, +) / Double(max(current.count, 1))
                if priorAvg > 0 {
                    let delta = (currentAvg - priorAvg) / priorAvg * 100
                    lines.append("HRV: \(Int(priorAvg)) → \(Int(currentAvg)) ms (\(String(format: "%+.0f", delta))%)")
                    ev.append(EvidencePoint(label: "HRV WoW", value: "\(String(format: "%+.0f", delta))%", detail: "\(Int(priorAvg))→\(Int(currentAvg)) ms", tool: "get_what_changed_this_week"))
                }
            }
            let sleep = await hk.fetchSleepHistory(days: 14)
            if sleep.count >= 6 {
                let sorted = sleep.sorted { $0.date < $1.date }
                let half = sorted.count / 2
                let prior = Array(sorted.prefix(half)).map(\.asleepHours)
                let current = Array(sorted.suffix(sorted.count - half)).map(\.asleepHours)
                let pAvg = prior.reduce(0, +) / Double(max(prior.count, 1))
                let cAvg = current.reduce(0, +) / Double(max(current.count, 1))
                lines.append("Sleep: \(String(format: "%.1f", pAvg))h → \(String(format: "%.1f", cAvg))h")
                ev.append(EvidencePoint(label: "Sleep WoW", value: "\(String(format: "%+.1f", cAvg - pAvg))h", detail: "\(String(format: "%.1f", pAvg))→\(String(format: "%.1f", cAvg))h", tool: "get_what_changed_this_week"))
            }
        }

        // Training volume
        let cal = Calendar.current
        let now = Date()
        var thisWeekVol = 0, priorWeekVol = 0
        for w in store.workoutHistory {
            let days = cal.dateComponents([.day], from: w.date, to: now).day ?? 0
            if days < 7 { thisWeekVol += w.totalVolume }
            else if days < 14 { priorWeekVol += w.totalVolume }
        }
        if priorWeekVol > 0 || thisWeekVol > 0 {
            let delta = priorWeekVol > 0 ? Double(thisWeekVol - priorWeekVol) / Double(priorWeekVol) * 100 : 0
            lines.append("Training volume: \(priorWeekVol) → \(thisWeekVol) lbs (\(String(format: "%+.0f", delta))%)")
            ev.append(EvidencePoint(label: "Volume WoW", value: "\(String(format: "%+.0f", delta))%", detail: "\(priorWeekVol)→\(thisWeekVol) lbs", tool: "get_what_changed_this_week"))
        }

        // Weight
        let weights = store.weightEntries.sorted { $0.date < $1.date }
        if weights.count >= 2 {
            let weekAgo = cal.date(byAdding: .day, value: -7, to: now) ?? now
            let priorWeight = weights.last(where: { $0.date <= weekAgo })?.weight
            let current = weights.last?.weight ?? 0
            if let prior = priorWeight, prior > 0 {
                let delta = current - prior
                lines.append("Weight: \(String(format: "%.1f", prior)) → \(String(format: "%.1f", current)) lbs (\(String(format: "%+.1f", delta)))")
                ev.append(EvidencePoint(label: "Weight WoW", value: "\(String(format: "%+.1f", delta)) lbs", detail: "\(String(format: "%.1f", prior))→\(String(format: "%.1f", current))", tool: "get_what_changed_this_week"))
            }
        }

        // Side effects
        let all = store.activeProtocols.flatMap(\.sideEffectLog)
        let oneWeekAgo = cal.date(byAdding: .day, value: -7, to: now) ?? now
        let twoWeeksAgo = cal.date(byAdding: .day, value: -14, to: now) ?? now
        let thisWeekEffects = all.filter { $0.timestamp >= oneWeekAgo }.count
        let priorWeekEffects = all.filter { $0.timestamp >= twoWeeksAgo && $0.timestamp < oneWeekAgo }.count
        if thisWeekEffects > 0 || priorWeekEffects > 0 {
            lines.append("Side effects: \(priorWeekEffects) → \(thisWeekEffects) reports")
            ev.append(EvidencePoint(label: "Side effects WoW", value: "\(thisWeekEffects - priorWeekEffects)", detail: "\(priorWeekEffects)→\(thisWeekEffects)", tool: "get_what_changed_this_week"))
        }

        guard !lines.isEmpty else {
            return ToolResult(text: "Not enough week-over-week data to compute changes.", evidence: [])
        }
        return ToolResult(text: "Week over week changes:\n" + lines.map { "• \($0)" }.joined(separator: "\n"), evidence: ev)
    }

    private func getProteinDeficitToday() -> ToolResult {
        let target = store.macroTarget.protein
        let consumed = Int(store.todayMeals.reduce(0) { $0 + $1.totalProtein })
        let remaining = max(0, target - consumed)
        let hour = Calendar.current.component(.hour, from: Date())
        let hoursLeft = max(0, 22 - hour)
        let expected = Int(Double(target) * (Double(min(hour, 22)) / 22.0))
        let pace = consumed - expected
        let text = "Protein today: \(consumed)/\(target)g (\(remaining)g remaining, \(hoursLeft)h left before typical last meal). Pace vs expected-for-time-of-day: \(String(format: "%+d", pace))g."
        let ev = [EvidencePoint(label: "Protein deficit", value: "\(remaining)g left", detail: "\(hoursLeft)h until 10pm, pace \(String(format: "%+d", pace))g", tool: "get_protein_deficit_today")]
        return ToolResult(text: text, evidence: ev)
    }

    private func getTodayNutritionStatus() -> ToolResult {
        let target = store.macroTarget
        let cal = store.todayMeals.reduce(0) { $0 + $1.totalCalories }
        let prot = Int(store.todayMeals.reduce(0) { $0 + $1.totalProtein })
        let isDoseDay = store.activeProtocols.flatMap(\.doseLog).contains {
            Calendar.current.isDateInToday($0.timestamp) && !$0.wasSkipped
        }
        let isTrainingDay = store.workoutHistory.contains { Calendar.current.isDateInToday($0.date) }
        let text = "Today: \(cal)/\(target.calories) kcal, \(prot)/\(target.protein)g protein. Dose day: \(isDoseDay ? "yes" : "no"). Training today: \(isTrainingDay ? "yes" : "no")."
        let ev = [EvidencePoint(label: "Today", value: "\(cal)/\(target.calories) kcal", detail: "\(prot)/\(target.protein)g protein", tool: "get_today_nutrition_status")]
        return ToolResult(text: text, evidence: ev)
    }

    private func getMeasurementGaps() -> ToolResult {
        let now = Date()
        let cal = Calendar.current
        var parts: [String] = []
        var ev: [EvidencePoint] = []
        if let lastWeight = store.weightEntries.sorted(by: { $0.date > $1.date }).first {
            let d = cal.dateComponents([.day], from: lastWeight.date, to: now).day ?? 0
            parts.append("Last weight: \(d)d ago (\(String(format: "%.1f", lastWeight.weight)) lbs)")
            ev.append(EvidencePoint(label: "Last weigh-in", value: "\(d)d ago", detail: "\(String(format: "%.1f", lastWeight.weight)) lbs", tool: "get_measurement_gaps"))
        } else {
            parts.append("No weight entries on record.")
        }
        if let lastM = store.bodyMeasurements.sorted(by: { $0.date > $1.date }).first {
            let d = cal.dateComponents([.day], from: lastM.date, to: now).day ?? 0
            parts.append("Last body measurement: \(d)d ago")
            ev.append(EvidencePoint(label: "Last measurement", value: "\(d)d ago", detail: nil, tool: "get_measurement_gaps"))
        } else {
            parts.append("No body measurements on record.")
        }
        return ToolResult(text: parts.joined(separator: ". "), evidence: ev)
    }

    private func getDoseScheduleToday() -> ToolResult {
        let active = store.activeProtocols.filter(\.isActive)
        guard !active.isEmpty else { return ToolResult(text: "No active protocol.", evidence: []) }
        var lines: [String] = []
        var ev: [EvidencePoint] = []
        for p in active {
            for c in p.compounds {
                let logged = p.doseLog.contains {
                    $0.compoundName == c.compoundName &&
                    Calendar.current.isDateInToday($0.timestamp) &&
                    !$0.wasSkipped
                }
                let dose = CompoundUnitHelper.displayDoseShort(c.doseMcg, for: c.compoundName)
                lines.append("\(c.compoundName) \(dose) (\(c.frequency)): \(logged ? "logged today" : "not yet logged")")
                ev.append(EvidencePoint(label: c.compoundName, value: logged ? "logged" : "pending", detail: "\(dose) · \(c.frequency)", tool: "get_dose_schedule_today"))
            }
        }
        return ToolResult(text: lines.joined(separator: "\n"), evidence: ev)
    }

    // MARK: - Expansion tools

    private func getWaterStatus() -> ToolResult {
        let vm = WaterViewModel.shared
        let today = Date()
        let cal = Calendar.current
        let totalMl = vm.totalMl(for: today)
        let goal = max(vm.dailyGoalMl, 1)
        let oz = Int(Double(totalMl) / 29.5735)
        let goalOz = Int(Double(goal) / 29.5735)
        let pct = Int(Double(totalMl) / Double(goal) * 100)
        var hits = 0
        var tracked = 0
        for i in 1...7 {
            guard let d = cal.date(byAdding: .day, value: -i, to: today) else { continue }
            let ml = vm.totalMl(for: d)
            if ml > 0 { tracked += 1 }
            if ml >= goal { hits += 1 }
        }
        let adherence = tracked > 0 ? Int(Double(hits) / Double(tracked) * 100) : 0
        let text = "Water today: \(totalMl) ml / \(oz) oz (target \(goal) ml / \(goalOz) oz) — \(pct)%. 7-day adherence: \(hits)/\(tracked) days at goal (\(adherence)%)."
        let ev = [EvidencePoint(label: "Water today", value: "\(pct)%", detail: "\(totalMl)/\(goal) ml · \(adherence)% 7d", tool: "get_water_status")]
        return ToolResult(text: text, evidence: ev)
    }

    private func getCardioHistory(limit: Int) -> ToolResult {
        let runs = RunningViewModel.shared.completedRuns.prefix(limit).map { run -> (Date, String) in
            let pace = run.averagePace > 0 ? String(format: " · %.1f min/mi", run.averagePace) : ""
            return (run.date, "Run \(String(format: "%.2f", run.distanceMiles)) mi · \(Int(run.durationSeconds / 60)) min\(pace) · \(run.caloriesBurned) kcal")
        }
        let rides = CyclingViewModel.shared.completedRides.prefix(limit).map { ride -> (Date, String) in
            let speed = ride.averageSpeed > 0 ? String(format: " · %.1f mph", ride.averageSpeed) : ""
            return (ride.date, "Ride \(String(format: "%.1f", ride.distanceMiles)) mi · \(Int(ride.durationSeconds / 60)) min\(speed) · \(ride.caloriesBurned) kcal")
        }
        let merged = (Array(runs) + Array(rides)).sorted { $0.0 > $1.0 }.prefix(limit)
        guard !merged.isEmpty else { return ToolResult(text: "No cardio sessions on record.", evidence: []) }
        var text = "Recent cardio (\(merged.count)):\n"
        let df = DateFormatter()
        df.dateStyle = .medium
        for (date, line) in merged {
            text += "  • \(df.string(from: date)) — \(line)\n"
        }
        let totalMiles = (RunningViewModel.shared.completedRuns.prefix(limit).map(\.distanceMiles)
            + CyclingViewModel.shared.completedRides.prefix(limit).map(\.distanceMiles)).reduce(0, +)
        let ev = [EvidencePoint(label: "Cardio recent", value: "\(merged.count) sessions", detail: String(format: "%.1f mi total", totalMiles), tool: "get_cardio_history")]
        return ToolResult(text: text, evidence: ev)
    }

    private func getStreakStatus() -> ToolResult {
        let s = StreakManager.shared.streakData
        let lastStr: String
        if let last = s.lastActivityDate {
            let days = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
            lastStr = days == 0 ? "today" : (days == 1 ? "yesterday" : "\(days)d ago")
        } else {
            lastStr = "never"
        }
        let text = "Streak: \(s.currentStreak) days (longest \(s.longestStreak)). Last activity: \(lastStr). Missed yesterday: \(s.missedYesterday ? "yes" : "no"). Freeze available: \(s.streakFreezeAvailable ? "yes" : "no")."
        let ev = [EvidencePoint(label: "Streak", value: "\(s.currentStreak)d", detail: "longest \(s.longestStreak), last \(lastStr)", tool: "get_streak_status")]
        return ToolResult(text: text, evidence: ev)
    }

    private func getMultiProtocolHistory() async -> ToolResult {
        let all: [PeptideProtocol]
        if let fetched = try? await ProtocolService.shared.fetchProtocols(), !fetched.isEmpty {
            all = fetched
        } else {
            all = store.activeProtocols
        }
        guard !all.isEmpty else { return ToolResult(text: "No protocols on file.", evidence: []) }
        let df = DateFormatter()
        df.dateStyle = .medium
        var lines: [String] = []
        var ev: [EvidencePoint] = []
        for p in all.sorted(by: { $0.startDate > $1.startDate }) {
            let compounds = p.compounds.map { "\($0.compoundName) \(CompoundUnitHelper.displayDoseShort($0.doseMcg, for: $0.compoundName))" }.joined(separator: ", ")
            let realLogs = p.doseLog.filter { !$0.wasSkipped }
            let lastDose = realLogs.sorted(by: { $0.timestamp > $1.timestamp }).first?.timestamp
            let endStr: String
            if p.isActive {
                endStr = "active (week \(p.currentWeek), \(p.currentPhase.rawValue))"
            } else if let last = lastDose {
                endStr = "ended ~\(df.string(from: last))"
            } else {
                endStr = "inactive"
            }
            lines.append("\(p.name) — \(compounds). Started \(df.string(from: p.startDate)). \(realLogs.count) doses, \(p.sideEffectLog.count) side effects. \(endStr).")
            ev.append(EvidencePoint(label: p.name, value: "\(realLogs.count) doses", detail: "\(compounds) · \(endStr)", tool: "get_multi_protocol_history"))
        }
        return ToolResult(text: "Protocols on file (\(all.count)):\n" + lines.map { "  • \($0)" }.joined(separator: "\n"), evidence: ev)
    }

    private func getCachedHealthSignals() -> ToolResult {
        guard hk.isAuthorized else { return ToolResult(text: "HealthKit unavailable.", evidence: []) }
        var parts: [String] = []
        if let h = hk.hrv { parts.append("HRV \(Int(h)) ms") }
        if let r = hk.restingHeartRate { parts.append("RHR \(Int(r)) bpm") }
        if hk.sleepHours > 0 { parts.append(String(format: "sleep %.1fh", hk.sleepHours)) }
        if hk.steps > 0 { parts.append("\(hk.steps) steps") }
        if hk.activeCalories > 0 { parts.append("\(Int(hk.activeCalories)) active kcal") }
        if hk.mindfulMinutesToday > 0 { parts.append("\(Int(hk.mindfulMinutesToday)) mindful min") }
        guard !parts.isEmpty else { return ToolResult(text: "No cached HealthKit signals yet.", evidence: []) }
        let staleStr: String
        if let last = hk.lastRefreshedAt {
            let secs = Int(Date().timeIntervalSince(last))
            staleStr = secs < 60 ? "just now" : "\(secs / 60)m ago"
        } else { staleStr = "unknown" }
        let text = "Cached HealthKit signals (last refresh \(staleStr)): " + parts.joined(separator: ", ") + "."
        let ev = [EvidencePoint(label: "HK cache", value: parts.first ?? "signals", detail: parts.dropFirst().joined(separator: " · "), tool: "get_cached_health_signals")]
        return ToolResult(text: text, evidence: ev)
    }
}
