import SwiftUI

enum ProtocolDeckEngine {

    struct DeckContext: Sendable {
        let goal: ProtocolGoal
        let currentWeek: Int
        let currentPhase: CyclePhase
        let compoundNames: [String]
        let totalWeeks: Int?
        let isOpenEnded: Bool
        let hasSideEffects: Bool
        let recentSideEffectCount: Int
    }

    static func context(from proto: PeptideProtocol) -> DeckContext {
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let recentEffects = proto.sideEffectLog.filter { $0.timestamp >= twoWeeksAgo }

        return DeckContext(
            goal: proto.goal,
            currentWeek: proto.currentWeek,
            currentPhase: proto.currentPhase,
            compoundNames: proto.compounds.map(\.compoundName),
            totalWeeks: proto.totalWeeks,
            isOpenEnded: proto.isOpenEnded,
            hasSideEffects: !recentEffects.isEmpty,
            recentSideEffectCount: recentEffects.count
        )
    }

    static func generateTasks(for ctx: DeckContext) -> [DailyTask] {
        var tasks: [DailyTask] = []

        tasks.append(contentsOf: coreTasks(for: ctx))
        tasks.append(contentsOf: goalSpecificTasks(for: ctx))
        tasks.append(contentsOf: phaseSpecificTasks(for: ctx))
        if ctx.hasSideEffects {
            tasks.append(contentsOf: sideEffectTasks(for: ctx))
        }

        return tasks
    }

    static func deckFocusNote(for ctx: DeckContext) -> String {
        let compound = ctx.compoundNames.first ?? "your compound"
        let week = ctx.currentWeek
        let phase = ctx.currentPhase.rawValue.lowercased()

        switch ctx.goal {
        case .weightLoss:
            return weeklyWeightLossFocus(compound: compound, week: week, phase: phase, ctx: ctx)
        case .muscleGrowth:
            return weeklyMuscleGrowthFocus(compound: compound, week: week, phase: phase, ctx: ctx)
        case .healing:
            return weeklyHealingFocus(compound: compound, week: week, phase: phase, ctx: ctx)
        case .cognitive:
            return weeklyCognitiveFocus(compound: compound, week: week, phase: phase, ctx: ctx)
        case .tanning:
            return "Week \(week) \(phase) — stay consistent with sun exposure timing relative to your \(compound) dose."
        case .general, .custom:
            return "Week \(week) of \(compound) — \(phase) phase. Tasks are tuned to your current stage."
        }
    }

    // MARK: - Core Tasks (all protocols)

    private static func coreTasks(for ctx: DeckContext) -> [DailyTask] {
        var tasks: [DailyTask] = []

        let compound = ctx.compoundNames.first ?? "compound"
        let isDoseDay = true

        if isDoseDay {
            tasks.append(DailyTask(
                name: "Log \(compound) Dose",
                icon: "syringe.fill",
                category: .wellness,
                isProtocolRecommended: true,
                protocolReason: "Week \(ctx.currentWeek) \(ctx.currentPhase.rawValue) — stay on schedule",
            source: .protocolDeck
            ))
        }

        tasks.append(DailyTask(
            name: "Drink Gallon of Water",
            icon: "drop.fill",
            category: .nutrition,
            actionLink: .waterIntake,
            actionTarget: 128,
            isProtocolRecommended: true,
            protocolReason: "Hydration is critical for \(compound) absorption",
        source: .protocolDeck
        ))

        return tasks
    }

    // MARK: - Goal-Specific Tasks

    private static func goalSpecificTasks(for ctx: DeckContext) -> [DailyTask] {
        switch ctx.goal {
        case .weightLoss:
            return weightLossTasks(for: ctx)
        case .muscleGrowth:
            return muscleGrowthTasks(for: ctx)
        case .healing:
            return healingTasks(for: ctx)
        case .cognitive:
            return cognitiveTasks(for: ctx)
        case .tanning:
            return tanningTasks(for: ctx)
        case .general, .custom:
            return generalTasks(for: ctx)
        }
    }

    private static func weightLossTasks(for ctx: DeckContext) -> [DailyTask] {
        var tasks: [DailyTask] = []

        let proteinTarget = ctx.currentWeek <= 2 ? 130 : 150
        tasks.append(DailyTask(
            name: "Hit \(proteinTarget)g Protein",
            icon: "fish.fill",
            category: .nutrition,
            actionLink: .proteinGoal,
            actionTarget: proteinTarget,
            isProtocolRecommended: true,
            protocolReason: ctx.currentWeek <= 2
                ? "Start building the protein habit early"
                : "Muscle preservation is non-negotiable on a deficit"
        ))

        tasks.append(DailyTask(
            name: "Log All Meals",
            icon: "list.clipboard.fill",
            category: .nutrition,
            isProtocolRecommended: true,
            protocolReason: "Appetite suppression can mask undereating — track everything",
        source: .protocolDeck
        ))

        if ctx.currentWeek >= 3 {
            tasks.append(DailyTask(
                name: "Resistance Training",
                icon: "figure.strengthtraining.traditional",
                category: .fitness,
                isProtocolRecommended: true,
                protocolReason: "Week \(ctx.currentWeek) — resistance work preserves lean mass during fat loss",
            source: .protocolDeck
            ))
        } else {
            tasks.append(DailyTask(
                name: "30 Min Walk",
                icon: "figure.walk",
                category: .fitness,
                isProtocolRecommended: true,
                protocolReason: "Light movement while your body adjusts to the compound",
            source: .protocolDeck
            ))
        }

        tasks.append(DailyTask(
            name: "Weigh In (Morning)",
            icon: "scalemass.fill",
            category: .wellness,
            isProtocolRecommended: true,
            protocolReason: "Consistent daily weigh-ins give the best trend data",
        source: .protocolDeck
        ))

        return tasks
    }

    private static func muscleGrowthTasks(for ctx: DeckContext) -> [DailyTask] {
        var tasks: [DailyTask] = []

        tasks.append(DailyTask(
            name: "Hit 180g Protein",
            icon: "fish.fill",
            category: .nutrition,
            actionLink: .proteinGoal,
            actionTarget: 180,
            isProtocolRecommended: true,
            protocolReason: "High protein maximizes the anabolic window your protocol creates",
        source: .protocolDeck
        ))

        tasks.append(DailyTask(
            name: "Complete Workout",
            icon: "dumbbell.fill",
            category: .fitness,
            actionLink: .workoutCompleted,
            isProtocolRecommended: true,
            protocolReason: "Training stimulus is required to capitalize on your protocol",
        source: .protocolDeck
        ))

        tasks.append(DailyTask(
            name: "8 Hours Sleep",
            icon: "moon.fill",
            category: .wellness,
            isProtocolRecommended: true,
            protocolReason: "Growth happens during deep sleep — prioritize recovery",
        source: .protocolDeck
        ))

        if ctx.currentWeek >= 4 {
            tasks.append(DailyTask(
                name: "Progress Photo",
                icon: "camera.fill",
                category: .wellness,
                isProtocolRecommended: true,
                protocolReason: "Week \(ctx.currentWeek) — visible changes should be emerging",
            source: .protocolDeck
            ))
        }

        return tasks
    }

    private static func healingTasks(for ctx: DeckContext) -> [DailyTask] {
        var tasks: [DailyTask] = []

        tasks.append(DailyTask(
            name: "Rate Recovery (1-10)",
            icon: "heart.text.clipboard",
            category: .wellness,
            isProtocolRecommended: true,
            protocolReason: "Tracking subjective recovery helps identify what's working",
        source: .protocolDeck
        ))

        tasks.append(DailyTask(
            name: "Light Movement",
            icon: "figure.walk",
            category: .fitness,
            isProtocolRecommended: true,
            protocolReason: "Blood flow supports healing — keep it gentle",
        source: .protocolDeck
        ))

        tasks.append(DailyTask(
            name: "Hit Protein Goal",
            icon: "fish.fill",
            category: .nutrition,
            actionLink: .proteinGoal,
            actionTarget: 120,
            isProtocolRecommended: true,
            protocolReason: "Protein provides the raw material for tissue repair",
        source: .protocolDeck
        ))

        tasks.append(DailyTask(
            name: "8+ Hours Sleep",
            icon: "moon.fill",
            category: .wellness,
            isProtocolRecommended: true,
            protocolReason: "Healing compounds work synergistically with deep sleep",
        source: .protocolDeck
        ))

        return tasks
    }

    private static func cognitiveTasks(for ctx: DeckContext) -> [DailyTask] {
        var tasks: [DailyTask] = []

        tasks.append(DailyTask(
            name: "Cognitive Check-In",
            icon: "brain.head.profile",
            category: .wellness,
            isProtocolRecommended: true,
            protocolReason: "Track focus and clarity to correlate with your protocol",
        source: .protocolDeck
        ))

        tasks.append(DailyTask(
            name: "20 Min Focused Work",
            icon: "timer",
            category: .lifestyle,
            isProtocolRecommended: true,
            protocolReason: "Deliberate focus sessions help measure cognitive improvements",
        source: .protocolDeck
        ))

        tasks.append(DailyTask(
            name: "Omega-3 / Brain Supps",
            icon: "pills.fill",
            category: .wellness,
            isProtocolRecommended: true,
            protocolReason: "Stack synergistic supplements with your nootropic protocol",
        source: .protocolDeck
        ))

        tasks.append(DailyTask(
            name: "7+ Hours Sleep",
            icon: "moon.fill",
            category: .wellness,
            isProtocolRecommended: true,
            protocolReason: "Cognitive function is directly tied to sleep quality",
        source: .protocolDeck
        ))

        return tasks
    }

    private static func tanningTasks(for ctx: DeckContext) -> [DailyTask] {
        var tasks: [DailyTask] = []

        tasks.append(DailyTask(
            name: "UV Exposure Window",
            icon: "sun.max.fill",
            category: .lifestyle,
            isProtocolRecommended: true,
            protocolReason: "Time sun exposure 2-4 hours post-dose for best results",
        source: .protocolDeck
        ))

        tasks.append(DailyTask(
            name: "Apply SPF to Face",
            icon: "face.smiling",
            category: .wellness,
            isProtocolRecommended: true,
            protocolReason: "Protect sensitive areas while letting the compound work",
        source: .protocolDeck
        ))

        tasks.append(DailyTask(
            name: "Hydrate Extra",
            icon: "drop.fill",
            category: .nutrition,
            actionLink: .waterIntake,
            actionTarget: 100,
            isProtocolRecommended: true,
            protocolReason: "Sun exposure and the compound both increase dehydration risk",
        source: .protocolDeck
        ))

        return tasks
    }

    private static func generalTasks(for ctx: DeckContext) -> [DailyTask] {
        var tasks: [DailyTask] = []

        tasks.append(DailyTask(
            name: "Log All Meals",
            icon: "list.clipboard.fill",
            category: .nutrition,
            isProtocolRecommended: true,
            protocolReason: "Consistent tracking helps identify what's working",
        source: .protocolDeck
        ))

        tasks.append(DailyTask(
            name: "Take Vitamins",
            icon: "pills.fill",
            category: .lifestyle,
            isProtocolRecommended: true,
            protocolReason: "Support your protocol with baseline micronutrients",
        source: .protocolDeck
        ))

        return tasks
    }

    // MARK: - Phase-Specific Tasks

    private static func phaseSpecificTasks(for ctx: DeckContext) -> [DailyTask] {
        switch ctx.currentPhase {
        case .loading:
            return [
                DailyTask(
                    name: "Monitor for Side Effects",
                    icon: "exclamationmark.triangle.fill",
                    category: .wellness,
                    isProtocolRecommended: true,
                    protocolReason: "Loading phase — your body is adjusting. Log anything unusual."
                ),
                DailyTask(
                    name: "Eat Smaller Meals",
                    icon: "fork.knife",
                    category: .nutrition,
                    isProtocolRecommended: true,
                    protocolReason: "Smaller, more frequent meals reduce GI side effects during loading"
                )
            ]
        case .tapering:
            return [
                DailyTask(
                    name: "Note Any Changes",
                    icon: "note.text",
                    category: .wellness,
                    isProtocolRecommended: true,
                    protocolReason: "Tapering phase — track how you feel as the dose reduces"
                )
            ]
        case .offCycle:
            return [
                DailyTask(
                    name: "Maintain Habits",
                    icon: "arrow.triangle.2.circlepath",
                    category: .wellness,
                    isProtocolRecommended: true,
                    protocolReason: "Off-cycle — keep your nutrition and training locked in"
                )
            ]
        default:
            return []
        }
    }

    // MARK: - Side Effect Tasks

    private static func sideEffectTasks(for ctx: DeckContext) -> [DailyTask] {
        var tasks: [DailyTask] = []

        if ctx.recentSideEffectCount >= 3 {
            tasks.append(DailyTask(
                name: "Log Side Effects",
                icon: "exclamationmark.bubble.fill",
                category: .wellness,
                isProtocolRecommended: true,
                protocolReason: "\(ctx.recentSideEffectCount) reports in 2 weeks — keep logging to spot patterns",
            source: .protocolDeck
            ))
        }

        return tasks
    }

    // MARK: - Weekly Focus Notes

    private static func weeklyWeightLossFocus(compound: String, week: Int, phase: String, ctx: DeckContext) -> String {
        switch week {
        case 1:
            return "Week 1 of \(compound) — focus on hydration and adjusting to the compound. Nausea is common. Eat bland, high-protein meals in smaller portions. No need to crush the gym yet."
        case 2:
            return "Week 2 — appetite suppression is kicking in. The danger now is undereating. Hit your protein target even if you're not hungry. Your body needs fuel to burn fat, not muscle."
        case 3:
            return "Week 3 — time to add resistance training if you haven't. The compound is doing its job on appetite. Your job is making sure the weight you lose is fat, not muscle. Lift heavy."
        case 4:
            return "Week 4 of \(compound) — you should be seeing the scale move. If protein has been consistent and you're training, the composition shift will be noticeable. Stay the course."
        case 5...8:
            return "Week \(week), \(phase) phase — this is where discipline matters most. The novelty has worn off but the compound is still working. Keep protein high, training consistent."
        default:
            return "Week \(week) on \(compound) — deep into the protocol. Consistency is your superpower right now. Keep logging everything."
        }
    }

    private static func weeklyMuscleGrowthFocus(compound: String, week: Int, phase: String, ctx: DeckContext) -> String {
        switch week {
        case 1...2:
            return "Week \(week) of \(compound) — loading phase. Focus on training volume and caloric surplus. The compound needs a stimulus to work with."
        case 3...4:
            return "Week \(week) — you should feel recovery improving. Push training intensity up. Eat in a surplus with protein above 1g per pound of bodyweight."
        default:
            return "Week \(week), \(phase) — the compound is fully saturated. Maximize training stimulus and recovery. This is your growth window."
        }
    }

    private static func weeklyHealingFocus(compound: String, week: Int, phase: String, ctx: DeckContext) -> String {
        switch week {
        case 1...2:
            return "Week \(week) of \(compound) — early healing phase. Prioritize sleep and gentle movement. The compound needs time to build up."
        case 3...4:
            return "Week \(week) — healing should be accelerating. Slowly increase activity if the injury allows. Keep protein high for tissue repair."
        default:
            return "Week \(week) on \(compound) — assess your recovery progress. Note improvements in mobility, pain levels, and function."
        }
    }

    private static func weeklyCognitiveFocus(compound: String, week: Int, phase: String, ctx: DeckContext) -> String {
        switch week {
        case 1...2:
            return "Week \(week) of \(compound) — baseline period. Track your focus, memory, and mood daily. Effects may be subtle at first."
        default:
            return "Week \(week) — cognitive effects should be noticeable. Track your focused work sessions and compare to baseline."
        }
    }
}
