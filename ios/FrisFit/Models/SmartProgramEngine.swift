import Foundation
import SwiftUI

nonisolated struct SmartProgramSuggestion: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let subtitle: String
    let description: String
    let icon: String
    let gradient: [Color]
    let badge: String?
    let badgeColor: Color
    let strategy: ProgramStrategy
    let aiPromptContext: String
    let relevanceScore: Int
}

nonisolated enum ProgramStrategy: String, Sendable {
    case maintenanceLift
    case aggressiveGain
    case recompFocus
    case cutPreservation
    case healingAdapted
    case highFrequencyHypertrophy
    case strengthFoundation
    case minimalistEfficient
    case peptideOptimized
}

enum SmartProgramEngine {
    static func generateSuggestions(
        activeProtocol: PeptideProtocol?,
        bodyGoal: FitnessGoalType?,
        currentWeight: Double?,
        targetWeight: Double?,
        workoutsThisWeek: Int,
        totalWorkouts: Int,
        experience: String?
    ) -> [SmartProgramSuggestion] {
        var suggestions: [SmartProgramSuggestion] = []

        let compounds = activeProtocol?.compounds.map { $0.compoundName.lowercased() } ?? []
        let protocolGoal = activeProtocol?.goal
        let phase = activeProtocol?.currentPhase

        let hasGLP1 = compounds.contains { name in
            ["semaglutide", "tirzepatide", "retatrutide", "liraglutide", "survodutide"].contains { name.contains($0) }
        }
        let hasGHSecretagogue = compounds.contains { name in
            ["cjc-1295", "ipamorelin", "tesamorelin", "sermorelin", "mk-677", "ghrp-6", "ghrp-2"].contains { name.contains($0) }
        }
        let hasAnabolic = compounds.contains { name in
            ["bpc-157", "tb-500", "igf-1", "follistatin"].contains { name.contains($0) }
        }
        let hasHealingPeptide = compounds.contains { name in
            ["bpc-157", "tb-500", "ghk-cu", "thymosin"].contains { name.contains($0) }
        }

        if hasGLP1 {
            suggestions.append(SmartProgramSuggestion(
                title: "Muscle Preservation Mode",
                subtitle: "Optimized for your GLP-1 stack",
                description: "On a GLP-1 agonist, your appetite is suppressed and you're likely in a deficit. This program prioritizes compound lifts at moderate intensity to preserve lean mass while you cut. 3-4 days, high protein emphasis.",
                icon: "shield.checkered",
                gradient: [.green, .green.opacity(0.6)],
                badge: "FOR YOUR STACK",
                badgeColor: .green,
                strategy: .cutPreservation,
                aiPromptContext: "User is on a GLP-1 agonist (\(compounds.joined(separator: ", "))). They are likely in a caloric deficit with suppressed appetite. Program must prioritize muscle preservation: focus on compound movements, moderate volume (not too high to impair recovery in a deficit), heavier loads (RPE 7-8), and adequate rest between sets. Avoid excessive metabolic conditioning that could accelerate muscle loss.",
                relevanceScore: 95
            ))

            suggestions.append(SmartProgramSuggestion(
                title: "Lean Gain Protocol",
                subtitle: "Push growth while GLP-1 manages fat",
                description: "Use the metabolic advantage of your GLP-1 to recomp — train aggressively for hypertrophy while the peptide handles fat oxidation. Higher volume, 4-5 days, progressive overload focus.",
                icon: "arrow.up.right.circle.fill",
                gradient: [PepTheme.teal, PepTheme.teal.opacity(0.6)],
                badge: "ADVANCED",
                badgeColor: PepTheme.teal,
                strategy: .aggressiveGain,
                aiPromptContext: "User is on a GLP-1 agonist (\(compounds.joined(separator: ", "))) and wants to pursue recomposition/lean gains. The GLP-1 helps partition nutrients toward muscle. Design a higher volume hypertrophy program (4-5 days) with progressive overload, moderate-to-high rep ranges (8-15), and some metabolic finishers. The user can train harder because the GLP-1 assists with recovery and fat oxidation.",
                relevanceScore: 88
            ))
        }

        if hasGHSecretagogue {
            suggestions.append(SmartProgramSuggestion(
                title: "Growth Hormone Hypertrophy",
                subtitle: "Maximize your GH secretagogue window",
                description: "GH secretagogues enhance recovery and protein synthesis. This program exploits that with higher volume and frequency — hit each muscle 2x/week with compound-focused sessions timed around your dosing.",
                icon: "chart.line.uptrend.xyaxis",
                gradient: [PepTheme.violet, PepTheme.violet.opacity(0.6)],
                badge: "SYNERGY",
                badgeColor: PepTheme.violet,
                strategy: .highFrequencyHypertrophy,
                aiPromptContext: "User is on GH secretagogues (\(compounds.joined(separator: ", "))). Enhanced GH levels improve recovery, collagen synthesis, and protein synthesis. Design a high-frequency program (each muscle 2x/week) with higher volume than normal. Include both heavy compounds (to stimulate mTOR) and higher rep isolation work. The user can handle more volume due to enhanced recovery from elevated GH.",
                relevanceScore: 90
            ))
        }

        if hasHealingPeptide {
            suggestions.append(SmartProgramSuggestion(
                title: "Recovery-Adapted Training",
                subtitle: "Built around your healing protocol",
                description: "You're running healing peptides — this program works with them. Controlled loading on recovering areas, progressive exposure, and compensatory volume on healthy muscle groups.",
                icon: "waveform.path.ecg",
                gradient: [PepTheme.blue, PepTheme.blue.opacity(0.6)],
                badge: "REHAB-SMART",
                badgeColor: PepTheme.blue,
                strategy: .healingAdapted,
                aiPromptContext: "User is on healing peptides (\(compounds.joined(separator: ", "))). They likely have an injury or tissue they're rehabbing. Design a program that includes progressive loading for the healing area (light → moderate, no heavy maximal loading early), while maintaining training intensity for unaffected muscle groups. Include mobility and prehab work. Avoid movements that create high shear forces on joints being treated.",
                relevanceScore: 85
            ))
        }

        if hasAnabolic && !hasHealingPeptide {
            suggestions.append(SmartProgramSuggestion(
                title: "Anabolic Advantage Program",
                subtitle: "Capitalize on enhanced protein synthesis",
                description: "Your stack supports elevated muscle protein synthesis. Train with higher volume and progressive overload — your body can handle it right now.",
                icon: "flame.fill",
                gradient: [.orange, .orange.opacity(0.6)],
                badge: "OPTIMIZED",
                badgeColor: .orange,
                strategy: .aggressiveGain,
                aiPromptContext: "User is on anabolic/growth peptides (\(compounds.joined(separator: ", "))). Enhanced protein synthesis means they can handle higher training volume and frequency with better recovery. Design an aggressive hypertrophy program with progressive overload, aiming for 15-20+ sets per muscle group per week across a 4-5 day split.",
                relevanceScore: 87
            ))
        }

        if let goal = bodyGoal {
            switch goal {
            case .weightLoss, .cutting:
                if !hasGLP1 {
                    suggestions.append(SmartProgramSuggestion(
                        title: "Cut & Preserve",
                        subtitle: "Matched to your \(goal.rawValue.lowercased()) goal",
                        description: "You're in a deficit phase. This program keeps intensity high and volume moderate to preserve every pound of muscle while you lean out. Full body or upper/lower splits work best here.",
                        icon: "arrow.down.right.circle.fill",
                        gradient: [Color(red: 255/255, green: 107/255, blue: 107/255), Color(red: 255/255, green: 107/255, blue: 107/255).opacity(0.6)],
                        badge: "GOAL-MATCHED",
                        badgeColor: Color(red: 255/255, green: 107/255, blue: 107/255),
                        strategy: .cutPreservation,
                        aiPromptContext: "User's body goal is \(goal.rawValue). They are in a caloric deficit. Prioritize muscle preservation: heavy compound lifts (RPE 7-8), moderate volume, adequate rest. Avoid excessive junk volume. 3-4 training days to allow recovery in a deficit.",
                        relevanceScore: 80
                    ))
                }
            case .weightGain, .bulking:
                suggestions.append(SmartProgramSuggestion(
                    title: "Mass Builder",
                    subtitle: "Fuel your bulk with serious volume",
                    description: "You're in a surplus — time to push volume and progressive overload hard. PPL or Upper/Lower with high frequency hits each muscle 2x/week for maximum growth.",
                    icon: "scalemass.fill",
                    gradient: [Color(red: 76/255, green: 217/255, blue: 100/255), Color(red: 76/255, green: 217/255, blue: 100/255).opacity(0.6)],
                    badge: "GOAL-MATCHED",
                    badgeColor: Color(red: 76/255, green: 217/255, blue: 100/255),
                    strategy: .aggressiveGain,
                    aiPromptContext: "User's body goal is \(goal.rawValue). They are in a caloric surplus. Design a high-volume hypertrophy program hitting each muscle 2x/week. Progressive overload focus, compound movements first, isolation finishers. 4-6 days per week.",
                    relevanceScore: 80
                ))
            case .recomp:
                suggestions.append(SmartProgramSuggestion(
                    title: "Recomp Engine",
                    subtitle: "Build muscle while losing fat",
                    description: "Recomp demands precision — heavy compounds to stimulate growth, moderate volume to avoid overreaching, and strategic cardio placement.",
                    icon: "arrow.triangle.2.circlepath",
                    gradient: [PepTheme.violet, PepTheme.violet.opacity(0.6)],
                    badge: "GOAL-MATCHED",
                    badgeColor: PepTheme.violet,
                    strategy: .recompFocus,
                    aiPromptContext: "User's body goal is Body Recomp. Design a program that balances heavy strength work (to build muscle) with enough volume for hypertrophy, without excessive fatigue. 4 days/week, upper/lower or full body. Include some metabolic conditioning.",
                    relevanceScore: 80
                ))
            case .maintain:
                suggestions.append(SmartProgramSuggestion(
                    title: "Maintenance Mode",
                    subtitle: "Hold your gains with minimal effort",
                    description: "Not trying to grow or cut — just maintain what you've built. Lower volume, 3 days/week, compound-focused. Train smart, not excessive.",
                    icon: "equal.circle.fill",
                    gradient: [PepTheme.teal, PepTheme.teal.opacity(0.6)],
                    badge: "EFFICIENT",
                    badgeColor: PepTheme.teal,
                    strategy: .maintenanceLift,
                    aiPromptContext: "User wants to maintain current physique. Design a minimal effective dose program: 3 days/week, full body or upper/lower, 2-3 sets per exercise at high intensity (RPE 8-9). Focus on compound movements only. Minimal junk volume.",
                    relevanceScore: 75
                ))
            }
        }

        if phase == .offCycle {
            suggestions.append(SmartProgramSuggestion(
                title: "Off-Cycle Deload",
                subtitle: "Smart training during your off-cycle",
                description: "You're in your off-cycle window. Reduce volume by 40%, keep intensity moderate, and focus on technique and mobility. Protect your gains without overreaching.",
                icon: "pause.circle.fill",
                gradient: [PepTheme.textSecondary, PepTheme.textSecondary.opacity(0.6)],
                badge: "PHASE-AWARE",
                badgeColor: PepTheme.textSecondary,
                strategy: .minimalistEfficient,
                aiPromptContext: "User is currently in the off-cycle phase of their peptide protocol. Recovery capacity is reduced. Design a deload-style program: reduce volume by 30-40% from normal, keep weights moderate (RPE 6-7), focus on compound movements and technique. 3 days/week maximum.",
                relevanceScore: 92
            ))
        }

        if phase == .loading {
            suggestions.append(SmartProgramSuggestion(
                title: "Loading Phase Program",
                subtitle: "Ramp up with your protocol",
                description: "Your protocol is in the loading phase — your body is adjusting. Start conservative and progressively increase volume as the compounds saturate.",
                icon: "arrow.up.forward.circle.fill",
                gradient: [PepTheme.teal, PepTheme.teal.opacity(0.6)],
                badge: "PHASE-AWARE",
                badgeColor: PepTheme.teal,
                strategy: .strengthFoundation,
                aiPromptContext: "User is in the loading/titration phase of their peptide protocol (\(compounds.joined(separator: ", "))). Start with moderate volume and intensity, planning to increase over 2-3 weeks as the compounds reach saturation. Focus on building movement patterns and progressive overload foundation.",
                relevanceScore: 88
            ))
        }

        if totalWorkouts == 0 && suggestions.isEmpty {
            suggestions.append(SmartProgramSuggestion(
                title: "Getting Started",
                subtitle: "Your first program, built right",
                description: "New to training? Start with a full-body program 3x/week. Master the compound lifts, build a strength base, and develop consistency.",
                icon: "figure.walk",
                gradient: [PepTheme.teal, PepTheme.teal.opacity(0.6)],
                badge: "BEGINNER",
                badgeColor: PepTheme.teal,
                strategy: .strengthFoundation,
                aiPromptContext: "User is a beginner with no workout history. Design a beginner-friendly full body program 3x/week. Focus on learning the main compound lifts (squat, bench, deadlift, overhead press, rows) with moderate weight and higher reps (8-12). Include clear progression scheme.",
                relevanceScore: 95
            ))
        }

        return suggestions.sorted { $0.relevanceScore > $1.relevanceScore }
    }

    static func buildUserContextSummary(
        activeProtocol: PeptideProtocol?,
        bodyGoal: FitnessGoalType?,
        currentWeight: Double?,
        targetWeight: Double?,
        workoutsThisWeek: Int,
        totalWorkouts: Int
    ) -> String {
        var parts: [String] = []

        if let proto = activeProtocol {
            let compoundList = proto.compounds.map { "\($0.compoundName) \($0.doseMcg)mcg \($0.frequency)" }.joined(separator: ", ")
            parts.append("Active Protocol: \(proto.name) (\(proto.goal.rawValue)) — Week \(proto.currentWeek), Phase: \(proto.currentPhase.rawValue)")
            parts.append("Compounds: \(compoundList)")
            if let tw = proto.totalWeeks {
                parts.append("Protocol Duration: \(tw) weeks total")
            }
        }

        if let goal = bodyGoal {
            parts.append("Body Goal: \(goal.rawValue)")
        }
        if let cw = currentWeight, cw > 0 {
            parts.append("Current Weight: \(String(format: "%.1f", cw)) lbs")
        }
        if let tw = targetWeight, tw > 0 {
            parts.append("Target Weight: \(String(format: "%.1f", tw)) lbs")
        }
        parts.append("Workouts This Week: \(workoutsThisWeek)")
        parts.append("Total Workout History: \(totalWorkouts) sessions")

        return parts.joined(separator: "\n")
    }
}
