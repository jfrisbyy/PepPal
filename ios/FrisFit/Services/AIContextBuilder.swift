import Foundation

/// Builds a single comprehensive "everything the AI should know" context block
/// shared by FinnChatViewModel, PeptideAIChatViewModel, MorningBriefService,
/// and any other AI-consuming surface. Reads primarily from InsightsDataStore
/// (populated by HomeView.syncInsightsStore) plus live HealthKit state so all
/// consumers see the same snapshot.
@MainActor
enum AIContextBuilder {
    struct Options: Sendable {
        var includeHealthKit: Bool = true
        var includeInventory: Bool = true
        var includeBloodwork: Bool = true
        var includeWorkouts: Bool = true
        var includeNutrition: Bool = true
        var includeSleep: Bool = true
        var includeAIMemory: Bool = true
        var sourceScreen: String = ""
    }

    static func build(options: Options = Options()) -> String {
        let store = InsightsDataStore.shared
        let hk = HealthKitService.shared

        var out = "\nCURRENT USER DATA (shared snapshot — source of truth for every AI surface):\n"

        // Identity
        if !store.firstName.isEmpty {
            out += "- Name: \(store.firstName)\n"
        }
        if !store.goalType.isEmpty {
            out += "- Body goal: \(store.goalType)"
            if store.targetWeight > 0 {
                out += " → \(String(format: "%.1f", store.targetWeight)) lb"
            }
            out += "\n"
        }
        if store.startingWeight > 0 || !store.weightEntries.isEmpty {
            let latest = store.weightEntries.last?.weight ?? 0
            if latest > 0 {
                out += "- Current weight: \(String(format: "%.1f", latest)) lb"
                if store.startingWeight > 0 {
                    let delta = latest - store.startingWeight
                    let sign = delta >= 0 ? "+" : ""
                    out += " (\(sign)\(String(format: "%.1f", delta)) lb since start)"
                }
                out += "\n"
            }
        }
        if let reason = store.adaptiveMacroReason {
            out += "- Macro plan: \(reason)\n"
        }
        out += "- Macro target: \(store.macroTarget.calories) cal / \(store.macroTarget.protein)g P / \(store.macroTarget.carbs)g C / \(store.macroTarget.fat)g F\n"

        // Protocols + doses
        if let proto = store.primaryProtocol {
            let phase = proto.currentPhase.rawValue
            let week = proto.currentWeek
            if let tw = proto.totalWeeks {
                out += "- Active protocol: \(proto.name) — Week \(week) of \(tw) (\(phase))\n"
            } else {
                out += "- Active protocol: \(proto.name) — Week \(week), ongoing (\(phase))\n"
            }
            let compoundSummaries = proto.compounds.map { compound in
                let dose = CompoundUnitHelper.displayDoseShort(compound.doseMcg, for: compound.compoundName)
                return "\(compound.compoundName) \(dose) \(compound.frequency.lowercased())"
            }
            if !compoundSummaries.isEmpty {
                out += "  Compounds: \(compoundSummaries.joined(separator: "; "))\n"
            }
            // Recent doses
            let recent = proto.doseLog.prefix(5)
            if !recent.isEmpty {
                let f = DateFormatter()
                f.dateFormat = "MMM d"
                let rows = recent.map { e -> String in
                    let dose = CompoundUnitHelper.displayDoseShort(e.doseMcg, for: e.compoundName)
                    let status = e.wasSkipped ? "skipped" : dose
                    return "\(f.string(from: e.timestamp)) \(e.compoundName) \(status)"
                }
                out += "  Recent doses: \(rows.joined(separator: " | "))\n"
            }
            // Side effects
            let recentSE = proto.sideEffectLog.prefix(3)
            if !recentSE.isEmpty {
                let rows = recentSE.map { "\($0.effect) (sev \($0.severity))" }
                out += "  Recent side effects: \(rows.joined(separator: ", "))\n"
            }
        } else if !store.activeProtocols.isEmpty {
            out += "- Protocols: \(store.activeProtocols.count) saved, none currently active\n"
        } else {
            out += "- Active protocol: none\n"
        }

        // Inventory & supply
        if options.includeInventory {
            if !store.vialInventory.isEmpty {
                let low = store.vialInventory.filter { $0.isLowStock || $0.isEmpty || $0.isExpired }
                let bud = store.vialInventory.filter { ($0.daysUntilBUD ?? 99) <= 3 && !$0.isExpired }
                out += "- Vial inventory: \(store.vialInventory.count) vials"
                if !low.isEmpty { out += ", \(low.count) low/empty/expired" }
                if !bud.isEmpty { out += ", \(bud.count) with BUD ≤ 3 days" }
                out += "\n"
            }
            if !store.lowStockForecasts.isEmpty {
                let rows = store.lowStockForecasts.prefix(3).map { f in
                    "\(f.compoundName): \(f.chipLabel)"
                }
                out += "  Supply warnings: \(rows.joined(separator: ", "))\n"
            }
        }

        // Sleep & recovery
        if options.includeSleep {
            if let corr = store.sleepCorrelation {
                out += "- Sleep/recovery: \(String(format: "%.1f", corr.averageSleepHours))h avg (\(corr.weeklySessions) sessions this week"
                if let hrv = corr.averageHRV { out += ", HRV \(Int(hrv))ms" }
                out += "). \(corr.insight)\n"
            }
        }

        // HealthKit
        if options.includeHealthKit, hk.isAvailable && hk.isAuthorized {
            out += "- Today (Apple Health): \(hk.steps) steps, \(Int(hk.activeCalories))kcal active"
            if hk.sleepHours > 0 { out += ", \(String(format: "%.1f", hk.sleepHours))h sleep" }
            if let hrv = hk.hrv { out += ", HRV \(Int(hrv))ms" }
            if let rhr = hk.restingHeartRate { out += ", RHR \(Int(rhr))" }
            if let r = hk.recoveryScore { out += ", recovery \(r)/100" }
            out += "\n"
        }

        // Nutrition
        if options.includeNutrition {
            if !store.todayMeals.isEmpty {
                let cal = store.todayMeals.reduce(0) { $0 + $1.totalCalories }
                let p = store.todayMeals.reduce(0.0) { $0 + $1.totalProtein }
                out += "- Today's nutrition: \(cal)/\(store.macroTarget.calories) cal, \(Int(p))/\(store.macroTarget.protein)g protein\n"
            } else {
                out += "- Today's nutrition: nothing logged yet\n"
            }
            if !store.recentMealsByDay.isEmpty {
                let days = store.recentMealsByDay.values
                let allMeals = days.flatMap { $0 }
                if !allMeals.isEmpty {
                    let avgCal = allMeals.reduce(0) { $0 + $1.totalCalories } / max(days.count, 1)
                    let avgP = allMeals.reduce(0.0) { $0 + $1.totalProtein } / Double(max(days.count, 1))
                    out += "  7-day avg: ~\(avgCal) cal, \(Int(avgP))g protein\n"
                }
            }
        }

        // Workouts
        if options.includeWorkouts {
            if let program = store.activeProgram {
                out += "- Training program: \(program.name)\n"
            }
            let recent = store.workoutHistory.prefix(3)
            if !recent.isEmpty {
                let f = DateFormatter()
                f.dateFormat = "MMM d"
                let rows = recent.map { w in
                    "\(f.string(from: w.date)) \(w.name) (\(w.durationMinutes)min, vol \(w.totalVolume))"
                }
                out += "- Recent workouts: \(rows.joined(separator: "; "))\n"
            }
            if !store.personalRecords.isEmpty {
                out += "- PRs tracked: \(store.personalRecords.count)\n"
            }
            if !store.muscleRecovery.isEmpty {
                let stillRecovering = store.muscleRecovery.filter { $0.status != .recovered }.map { $0.muscle.rawValue }
                if !stillRecovering.isEmpty {
                    out += "  Still recovering: \(stillRecovering.prefix(4).joined(separator: ", "))\n"
                }
            }
        }

        // Bloodwork
        if options.includeBloodwork, !store.bloodwork.isEmpty {
            let latest = store.bloodwork.max(by: { $0.date < $1.date })
            if let latest {
                let df = DateFormatter()
                df.dateStyle = .medium
                let flagged = latest.results.filter { !$0.isInRange }
                out += "- Latest bloodwork (\(df.string(from: latest.date))): \(latest.results.count) markers"
                if !flagged.isEmpty {
                    let names = flagged.prefix(4).map { "\($0.biomarker.rawValue) \($0.status.rawValue)" }
                    out += ", flagged: \(names.joined(separator: ", "))"
                }
                out += "\n"
                if let interp = store.bloodworkInterpretation {
                    out += "  Interpretation: \(interp.headline)\n"
                    if interp.providerFlag {
                        out += "  ⚠ Provider follow-up recommended.\n"
                    }
                }
            }
        }

        // Body measurements
        if !store.bodyMeasurements.isEmpty {
            out += "- Body measurements on file: \(store.bodyMeasurements.count)\n"
        }

        // AI memory
        if options.includeAIMemory {
            let memo = AIMemoryStore.shared.memoForAgent(limit: 10)
            if !memo.isEmpty {
                out += "\n\(memo)\n"
            }
        }

        if !options.sourceScreen.isEmpty {
            out += "- Opened from: \(options.sourceScreen)\n"
        }

        return out
    }
}
