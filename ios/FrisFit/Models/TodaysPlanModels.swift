import SwiftUI

nonisolated struct TodaysPlanResponse: Codable, Sendable {
    let summary: String
    let modules: [TodaysPlanModule]
}

nonisolated struct TodaysPlanModule: Codable, Sendable, Identifiable {
    var id: String { type }
    let type: String
    let title: String
    let content: String
}

nonisolated enum PlanModuleType: String, Sendable {
    case `protocol` = "protocol"
    case nutrition = "nutrition"
    case training = "training"
    case body = "body"
    case sideEffects = "side_effects"
    case bloodwork = "bloodwork"
    case supplements = "supplements"

    var icon: String {
        switch self {
        case .protocol: return "pill.fill"
        case .nutrition: return "fork.knife"
        case .training: return "figure.strengthtraining.traditional"
        case .body: return "scalemass.fill"
        case .sideEffects: return "exclamationmark.triangle.fill"
        case .bloodwork: return "drop.fill"
        case .supplements: return "leaf.fill"
        }
    }

    var color: Color {
        switch self {
        case .protocol: return PepTheme.teal
        case .nutrition: return PepTheme.amber
        case .training: return PepTheme.blue
        case .body: return .green
        case .sideEffects: return .orange
        case .bloodwork: return .red
        case .supplements: return PepTheme.violet
        }
    }
}

nonisolated struct ContextBundle: Sendable {
    let userProfile: UserProfileContext
    let protocolContext: ProtocolContext?
    let compoundKnowledge: String?
    let nutritionToday: NutritionTodayContext?
    let nutritionTrends: NutritionTrendsContext?
    let bodyContext: BodyContext?
    let trainingContext: TrainingContext?
    let sideEffectsContext: SideEffectsContext?
    let bloodworkContext: BloodworkContext?
    let supplementsContext: SupplementsContext?

    var contentHash: String {
        var parts: [String] = []
        parts.append(userProfile.timeOfDay)
        if let p = protocolContext {
            parts.append("proto:\(p.compoundName):\(p.currentDose):\(p.currentWeek):\(p.currentPhase):\(p.doseLoggedToday):\(p.doseLoggedTime ?? "none")")
        }
        if let n = nutritionToday {
            parts.append("nutr:\(n.caloriesConsumed):\(n.proteinConsumed):\(n.carbsConsumed):\(n.fatConsumed):\(n.mealsLogged)")
        }
        if let nt = nutritionTrends {
            parts.append("ntrend:\(nt.avgCalories):\(nt.avgProtein):\(nt.daysProteinHit):\(nt.daysCalorieHit)")
        }
        if let b = bodyContext {
            parts.append("body:\(String(format: "%.1f", b.currentWeight)):\(b.plateauDetected):\(b.latestMeasurements ?? "none")")
        }
        if let t = trainingContext {
            parts.append("train:\(t.todayWorkout ?? "rest"):\(t.completedToday):\(t.workoutsThisWeek):\(t.todayExercises.count):\(t.adherenceRate ?? 0)")
        }
        if let se = sideEffectsContext {
            let effectStr = se.effects.map { "\($0.name):\($0.count):\($0.trend)" }.joined(separator: ",")
            parts.append("se:\(effectStr)")
        }
        if let bw = bloodworkContext {
            parts.append("bw:\(bw.daysSinceLastPanel ?? -1):\(bw.recheckDue):\(bw.flaggedBiomarkers.count)")
        }
        if let s = supplementsContext {
            parts.append("sup:\(s.totalActive):\(s.loggedToday)")
        }
        let combined = parts.joined(separator: "|")
        var hasher = Hasher()
        hasher.combine(combined)
        return String(hasher.finalize())
    }

    func toPromptString() -> String {
        var sections: [String] = []

        sections.append("""
        USER PROFILE:
        First name: \(userProfile.firstName)
        Current date/time: \(userProfile.currentDateTime)
        Time of day: \(userProfile.timeOfDay)
        """)

        if let p = protocolContext {
            var protocolStr = """
            PROTOCOL:
            Compound: \(p.compoundName)
            Current dose: \(p.currentDose)
            Frequency: \(p.frequency)
            Start date: \(p.startDate)
            Current week: \(p.currentWeek)
            Current phase: \(p.currentPhase)
            Total days on protocol: \(p.totalDays)
            """
            if let pct = p.percentThrough {
                protocolStr += "\nPercent through cycle: \(pct)%"
            }
            if p.doseLoggedToday {
                protocolStr += "\nDose logged today: Yes"
                if let t = p.doseLoggedTime { protocolStr += " at \(t)" }
            } else {
                protocolStr += "\nDose logged today: No"
            }
            sections.append(protocolStr)
        }

        if let ck = compoundKnowledge, !ck.isEmpty {
            sections.append("COMPOUND KNOWLEDGE:\n\(ck)")
        }

        if let n = nutritionToday {
            sections.append("""
            NUTRITION TODAY:
            Calories: \(n.caloriesConsumed)/\(n.caloriesTarget) (\(n.caloriesRemaining) remaining)
            Protein: \(n.proteinConsumed)g/\(n.proteinTarget)g (\(n.proteinRemaining)g remaining)
            Carbs: \(n.carbsConsumed)g/\(n.carbsTarget)g
            Fat: \(n.fatConsumed)g/\(n.fatTarget)g
            Meals logged: \(n.mealsLogged)
            On pace for time of day: \(n.onPace ? "Yes" : "No")
            """)
        }

        if let nt = nutritionTrends {
            sections.append("""
            NUTRITION TRENDS (last 7 days):
            Avg daily calories: \(nt.avgCalories)
            Avg daily protein: \(nt.avgProtein)g
            Days protein target hit: \(nt.daysProteinHit)/7
            Days calorie target hit: \(nt.daysCalorieHit)/7
            Notable pattern: \(nt.notablePattern ?? "None detected")
            """)
        }

        if let b = bodyContext {
            var bodyStr = """
            BODY:
            Current weight: \(String(format: "%.1f", b.currentWeight)) lbs
            Goal weight: \(String(format: "%.1f", b.goalWeight)) lbs
            Distance to goal: \(String(format: "%.1f", b.distanceToGoal)) lbs
            Total weight change since start: \(String(format: "%.1f", b.totalWeightChange)) lbs
            """
            if let rate = b.weeklyAvgLossRate {
                bodyStr += "\nWeekly avg rate: \(String(format: "%.1f", rate)) lbs/week"
            }
            if b.plateauDetected {
                bodyStr += "\nPlateau detected: Yes (< 0.5 lb change over 14+ days)"
            }
            if let m = b.latestMeasurements {
                bodyStr += "\nLatest measurements: \(m)"
            }
            sections.append(bodyStr)
        }

        if let t = trainingContext {
            var trainStr = """
            TRAINING:
            Today's workout: \(t.todayWorkout ?? "Rest day")
            Completed today: \(t.completedToday ? "Yes" : "No")
            Workouts this week: \(t.workoutsThisWeek)/\(t.weeklyTarget)
            """
            if let name = t.programName {
                trainStr += "\nProgram: \(name)"
            }
            if let week = t.programWeek {
                trainStr += "\nProgram week: \(week)"
            }
            if let y = t.yesterdayWorkout {
                trainStr += "\nYesterday's workout: \(y)"
            }
            if let next = t.nextTrainingDay {
                trainStr += "\nNext training day: \(next)"
            }
            if let adherence = t.adherenceRate {
                trainStr += "\nAdherence rate (last 4 weeks): \(Int(adherence * 100))%"
            }
            if !t.todayExercises.isEmpty {
                trainStr += "\n\nToday's exercises:"
                for ex in t.todayExercises {
                    var line = "- \(ex.name) (\(ex.muscle)): \(ex.targetSets) sets x \(ex.repRange)"
                    if let w = ex.lastWeight, let r = ex.lastReps {
                        line += " [last: \(Int(w)) lbs x \(r)]"
                    }
                    if let trend = ex.trend {
                        line += " trend: \(trend)"
                    }
                    trainStr += "\n\(line)"
                }
            }
            let fatiguedMuscles = t.muscleRecovery.filter { $0.status == "Fatigued" || $0.status == "Recovering" }
            if !fatiguedMuscles.isEmpty {
                trainStr += "\n\nMuscle recovery:"
                for m in fatiguedMuscles {
                    trainStr += "\n- \(m.muscle): \(m.status) (\(m.hoursRemaining)h remaining)"
                }
            }
            let underVolume = t.weeklyVolume.filter { $0.setsCompleted < $0.targetSets }
            if !underVolume.isEmpty {
                trainStr += "\n\nWeekly volume gaps:"
                for v in underVolume {
                    trainStr += "\n- \(v.muscle): \(v.setsCompleted)/\(v.targetSets) sets"
                }
            }
            if !t.recentPRs.isEmpty {
                trainStr += "\n\nRecent PRs:"
                for pr in t.recentPRs.prefix(3) {
                    trainStr += "\n- \(pr.exercise): \(Int(pr.weight)) lbs x \(pr.reps)\(pr.isRecent ? " (this week!)" : "")"
                }
            }
            sections.append(trainStr)
        }

        if let se = sideEffectsContext, !se.effects.isEmpty {
            var seStr = "SIDE EFFECTS (last 14 days):\n"
            for effect in se.effects {
                seStr += "- \(effect.name): reported \(effect.count)x, severity trend: \(effect.trend)\n"
            }
            if let top = se.mostFrequentThisWeek {
                seStr += "Most frequent this week: \(top)"
            }
            sections.append(seStr)
        }

        if let bw = bloodworkContext {
            var bwStr = """
            BLOODWORK:
            Last panel date: \(bw.lastPanelDate ?? "None on record")
            Days since last panel: \(bw.daysSinceLastPanel ?? -1)
            Recheck due: \(bw.recheckDue ? "Yes" : "No")
            """
            if !bw.flaggedBiomarkers.isEmpty {
                bwStr += "\nFlagged values: \(bw.flaggedBiomarkers.joined(separator: ", "))"
            }
            sections.append(bwStr)
        }

        if let s = supplementsContext, !s.supplements.isEmpty {
            var supStr = "SUPPLEMENTS:\n"
            supStr += "Active: \(s.supplements.joined(separator: ", "))\n"
            supStr += "Logged today: \(s.loggedToday)/\(s.totalActive)"
            sections.append(supStr)
        }

        return sections.joined(separator: "\n\n")
    }
}

nonisolated struct UserProfileContext: Sendable {
    let firstName: String
    let currentDateTime: String
    let timeOfDay: String
}

nonisolated struct ProtocolContext: Sendable {
    let compoundName: String
    let currentDose: String
    let frequency: String
    let startDate: String
    let currentWeek: Int
    let currentPhase: String
    let totalDays: Int
    let percentThrough: Int?
    let doseLoggedToday: Bool
    let doseLoggedTime: String?
}

nonisolated struct NutritionTodayContext: Sendable {
    let caloriesConsumed: Int
    let caloriesTarget: Int
    let caloriesRemaining: Int
    let proteinConsumed: Int
    let proteinTarget: Int
    let proteinRemaining: Int
    let carbsConsumed: Int
    let carbsTarget: Int
    let fatConsumed: Int
    let fatTarget: Int
    let mealsLogged: Int
    let onPace: Bool
}

nonisolated struct NutritionTrendsContext: Sendable {
    let avgCalories: Int
    let avgProtein: Int
    let daysProteinHit: Int
    let daysCalorieHit: Int
    let notablePattern: String?
}

nonisolated struct BodyContext: Sendable {
    let currentWeight: Double
    let goalWeight: Double
    let distanceToGoal: Double
    let totalWeightChange: Double
    let weeklyAvgLossRate: Double?
    let plateauDetected: Bool
    let latestMeasurements: String?
}

nonisolated struct TrainingExerciseContext: Sendable {
    let name: String
    let muscle: String
    let targetSets: Int
    let repRange: String
    let lastWeight: Double?
    let lastReps: Int?
    let trend: String?
}

nonisolated struct MuscleRecoveryContext: Sendable {
    let muscle: String
    let status: String
    let hoursRemaining: Int
}

nonisolated struct VolumeContext: Sendable {
    let muscle: String
    let setsCompleted: Int
    let targetSets: Int
}

nonisolated struct PRContext: Sendable {
    let exercise: String
    let weight: Double
    let reps: Int
    let isRecent: Bool
}

nonisolated struct TrainingContext: Sendable {
    let todayWorkout: String?
    let completedToday: Bool
    let workoutsThisWeek: Int
    let weeklyTarget: Int
    let yesterdayWorkout: String?
    let nextTrainingDay: String?
    let todayExercises: [TrainingExerciseContext]
    let muscleRecovery: [MuscleRecoveryContext]
    let weeklyVolume: [VolumeContext]
    let adherenceRate: Double?
    let recentPRs: [PRContext]
    let programName: String?
    let programWeek: Int?
}

nonisolated struct SideEffectContext: Sendable {
    let name: String
    let count: Int
    let trend: String
}

nonisolated struct SideEffectsContext: Sendable {
    let effects: [SideEffectContext]
    let mostFrequentThisWeek: String?
}

nonisolated struct BloodworkContext: Sendable {
    let lastPanelDate: String?
    let daysSinceLastPanel: Int?
    let recheckDue: Bool
    let flaggedBiomarkers: [String]
}

nonisolated struct SupplementsContext: Sendable {
    let supplements: [String]
    let totalActive: Int
    let loggedToday: Int
}
