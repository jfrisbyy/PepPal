import Foundation
import SwiftUI

// MARK: - Persona model

nonisolated enum DemoScenario: String, CaseIterable, Sendable {
    case maya, priya, theo, marcus, ava, shayla

    var displayName: String {
        switch self {
        case .maya: return "Maya"
        case .priya: return "Priya"
        case .theo: return "Theo"
        case .marcus: return "Marcus"
        case .ava: return "Ava"
        case .shayla: return "Shayla"
        }
    }

    var fullName: String {
        switch self {
        case .maya: return "Maya Chen"
        case .priya: return "Priya Patel"
        case .theo: return "Theo Walker"
        case .marcus: return "Marcus Reed"
        case .ava: return "Ava Lindqvist"
        case .shayla: return "Shayla Brooks"
        }
    }

    var username: String { "@" + displayName.lowercased() }

    var headline: String {
        switch self {
        case .maya: return "Rough sleep → adaptive lift"
        case .priya: return "Side effect → nutrition pivot"
        case .theo: return "Missed dose → recalibrated week"
        case .marcus: return "Bloodwork shifted → protocol + plate"
        case .ava: return "RHR elevated 5 days → fork"
        case .shayla: return "Borrowed protocol → safer dose"
        }
    }

    var archetype: String {
        switch self {
        case .maya: return "Hypertrophy lifter"
        case .priya: return "GLP-1 journey"
        case .theo: return "Tendon recovery · BPC-157"
        case .marcus: return "Health optimizer · TRT"
        case .ava: return "Endurance runner"
        case .shayla: return "Recomp · learning"
        }
    }

    var teaser: String {
        switch self {
        case .maya: return "4h 38m last night, HRV -18%, RHR +6. Leg day today — half-volume bundle ready."
        case .priya: return "Tirzepatide 5mg yesterday, stomach discomfort logged 4h ago. Easy-on-the-gut plan armed for 48h."
        case .theo: return "BPC-157 missed Wednesday. Compound level dipped, Saturday pull flagged."
        case .marcus: return "ALT 38 → 52 → 68. LDL creeping. Two compounds flagged for review."
        case .ava: return "RHR +8 bpm for 5 mornings, sleep normal. Two-path prompt waiting."
        case .shayla: return "Marcus runs Test Cyp at 100mg. Your labs say start at 50mg."
        }
    }

    var accent: Color {
        switch self {
        case .maya: return Color(red: 0.55, green: 0.45, blue: 0.95)
        case .priya: return Color(red: 0.95, green: 0.55, blue: 0.35)
        case .theo: return Color(red: 0.30, green: 0.75, blue: 0.70)
        case .marcus: return Color(red: 0.95, green: 0.30, blue: 0.30)
        case .ava: return Color(red: 0.30, green: 0.65, blue: 0.95)
        case .shayla: return Color(red: 0.95, green: 0.45, blue: 0.65)
        }
    }

    var avatarInitial: String { String(displayName.prefix(1)) }
}

nonisolated struct DemoPersona: Sendable {
    let scenario: DemoScenario
    let bio: String
    let heightCm: Double
    let currentStreak: Int
    let longestStreak: Int
    let weightStartLbs: Double
    let weightTodayLbs: Double
    let weightTargetLbs: Double
    let activeProgramName: String
    let archivedProgramName: String
    let totalWorkouts: Int
    let followers: Int
    let following: Int
    let goalType: String
    let macroCalories: Int
    let macroProtein: Int
    let macroCarbs: Int
    let macroFat: Int
    let avgStepsPerDay: Int
    let avgSleepHours: Double
}

// MARK: - Demo Mode manager

@MainActor
@Observable
final class DemoModeManager {
    static let shared = DemoModeManager()

    private(set) var activeScenario: DemoScenario?
    var activePersona: DemoPersona? {
        guard let s = activeScenario else { return nil }
        return DemoPersonaLibrary.persona(for: s)
    }

    var isActive: Bool { activeScenario != nil }

    private let storageKey = "demoMode.activeScenario"

    private init() {
        if let raw = UserDefaults.standard.string(forKey: storageKey),
           let s = DemoScenario(rawValue: raw) {
            activeScenario = s
            DispatchQueue.main.async { [weak self] in
                guard let self, let s = self.activeScenario else { return }
                self.applyData(for: s)
            }
        }
    }

    func activate(_ scenario: DemoScenario) {
        activeScenario = scenario
        UserDefaults.standard.set(scenario.rawValue, forKey: storageKey)
        applyData(for: scenario)
        NotificationCenter.default.post(name: .demoPersonaChanged, object: scenario)
    }

    func deactivate() {
        activeScenario = nil
        UserDefaults.standard.removeObject(forKey: storageKey)
        DemoDataInjector.clearAll()
        NotificationCenter.default.post(name: .demoPersonaChanged, object: nil)
    }

    private func applyData(for scenario: DemoScenario) {
        DemoDataInjector.injectShared(scenario: scenario)
    }
}

extension Notification.Name {
    static let demoPersonaChanged = Notification.Name("demoPersonaChanged")
}

// MARK: - Demo mode probes (safe to call from nonisolated contexts)

/// Lightweight, nonisolated read of the active demo scenario. Backed by the
/// same UserDefaults key the `DemoModeManager` writes on activate/deactivate,
/// so this stays correct without hopping to the main actor.
nonisolated enum DemoModeProbe {
    private static let storageKey = "demoMode.activeScenario"

    static var activeScenario: DemoScenario? {
        guard let raw = UserDefaults.standard.string(forKey: storageKey) else { return nil }
        return DemoScenario(rawValue: raw)
    }

    static var isActive: Bool { activeScenario != nil }

    /// Hand-tuned profile memo per persona so the deep brief has the right
    /// long-term anchor instead of falling back to the signed-in user's
    /// real Supabase memo. Mirrors the shape of `LongTermMemoryService`
    /// memos so the prompt reads the same.
    static func profileMemo(for scenario: DemoScenario) -> String {
        switch scenario {
        case .maya:
            return """
            Maya Chen, 32, hypertrophy block week 6, three years of training age. Running Upper/Lower Hypertrophy 4x/week (Leg Day (Deadlift), Upper Body A, Leg Day (Squat), Upper Body B). Recomp goal — currently 139.4 lb, target 138 lb, started at 142 lb. Calorie target 2,100, protein floor 145 g. Recent PR: back squat 185x5 twelve days ago, off a prior 175 lb best.
            Cross-domain patterns: training adherence ~92% over the last four weeks, push days move clean, leg days slip when sleep dips under 6h. Hip thrust and RDL are her strongest lifts. Protein lands in the 130-150 g band most days; calories run within 10% of target 5 of 7 days.
            Peptide stack: low-dose Retatrutide 1 mg weekly (microdose for the last two recomp pounds, week 6 of 16) + GHK-Cu 1 mg daily under-the-skin (skin and recovery support during the lean phase, no GH stack). Sleep baseline ~7.1h; current night was 4h 38m (rough — HRV -18%, RHR +6). Recovery green most weeks except after low-sleep nights, which line up with regressions on squat speed-out.
            Voice: direct, lift-friend tone, lead with the number, never preachy. No emojis.
            """
        case .priya:
            return """
            Priya Patel, 34, six weeks into Tirzepatide 5 mg weekly (GLP-1 weight loss). Started at 198 lb, currently 174.8 lb, target 158 lb — averaging -0.9 lb/week, on the conservative side of ideal. Active program: Full Body Beginner 3x/week. Calorie target 1,500, protein 130 g (muscle preservation floor on Tirz). Logs GI discomfort within 24h of dose day fairly consistently.
            Cross-domain patterns: appetite suppressed for ~48h post-injection so calories often land at 1,100-1,250 on dose day +1; rebounds Wednesday-Thursday. Protein adherence ~70% of days hitting the 130 g floor — biggest miss is dose-day evenings. Sleep ~7.4h, RHR stable in the low 60s.
            Recent labs unremarkable. No bloodwork shifts flagged.
            Voice: warm, supportive but specific, frame side effects matter-of-factly, no diet-culture language. No emojis.
            """
        case .theo:
            return """
            Theo Walker, 35, powerlifter rebuilding from a partial supraspinatus strain. Running 5/3/1 BBB four days a week (Bench, Squat, OHP, Deadlift). Bodyweight 201.2 lb, target 205 lb (slow lean gain). Peptide stack: BPC-157 250 mcg sub-q twice daily + TB-500 weekly — tendon recovery only, no GH stack.
            Cross-domain patterns: deadlift and squat back to ~90% of pre-injury maxes (squat 365 working, pull 425 last top single). Pressing still down ~10% — bench 275 working when fresh. Misses Wednesday BPC-157 occasionally; tendon flare-ups historically follow within 48h. Calorie target 3,000, protein 200 g — hits both 5-6 days/week.
            Sleep ~7.6h. HRV stable mid-40s. No bloodwork concerns; last panel within range.
            Voice: direct, peer-coach tone, talk in working sets and percentages, never alarmist about minor regressions. No emojis.
            """
        case .marcus:
            return """
            Marcus Reed, 41, health optimizer. TRT — Testosterone Cypionate 100 mg/wk for ~14 months — plus low-dose Ipamorelin nightly for sleep/recovery. Active program: Optimizer PPL four days/week. 188.6 lb, target 190 lb (lean recomp). Calorie target 2,600, protein 180 g — disciplined, almost always on target.
            Cross-domain patterns: bloodwork trend is the headline — ALT moved 38 → 52 → 68 across the last three panels, LDL creeping into the 130s. Last panel ~75 days ago, due for a recheck. Sleep ~7.8h, HRV mid-50s, RHR sub-60. Trains consistently — adherence ~95% over 12 weeks.
            Voice: analytical, biomarker-fluent, give him the receipts. Frame liver/lipid drift as worth bringing up with his provider, not as alarm. No emojis.
            """
        case .ava:
            return """
            Ava Lindqvist, 29, marathon base block 2 (week 8 of 16). Five sessions/week — easy, tempo, intervals, long run, plus one strength maintenance day. 131.4 lb, target 130 lb. Calorie target 2,400, protein 120 g, carbs 330 g. Low-dose Ipamorelin nightly for tendon recovery only.
            Cross-domain patterns: RHR up +8 bpm across the last 5 mornings with sleep unchanged at ~7.9h — classic overtraining vs illness fork pattern. HRV holding mid-50s, not crashed yet. Mileage held steady week-over-week; interval session Thursday was the hardest of the block.
            Voice: calm, endurance-coach tone, talk in mileage and HR zones, surface the fork (overtraining vs illness) without picking for her. No emojis.
            """
        case .shayla:
            return """
            Shayla Brooks, 27, year 2 of training. Running Upper/Lower 4x/week. 149.8 lb, target 145 lb — cutting. Calorie target 1,800, protein 140 g. Borrowed Marcus's TRT-style stack but reading it at half-dose for her context — Test Cyp 50 mg/wk would be the start, not 100.
            Cross-domain patterns: lifts progressing — hip thrust 165 working, cable row 90, incline DB press 30. Sleep averages ~6.4h (lower than ideal), HRV 50s, RHR upper 50s. Calorie adherence ~75%, weekends drift +400 cal.
            Voice: curious-friend tone, never lecture her about borrowing a protocol — show the math instead. Make safety the side door, not the headline. No emojis.
            """
        }
    }
}

// MARK: - Data injector

@MainActor
enum DemoDataInjector {
    /// Inject the shared singletons (no view-model touch). Used at app launch /
    /// `DemoModeManager.activate` before HomeView mounts.
    static func injectShared(scenario: DemoScenario) {
        guard let p = DemoPersonaLibrary.persona(for: scenario) else { return }
        let bundle = DemoDataGenerator.buildBundle(scenario: scenario, persona: p)
        applySharedSingletons(persona: p, bundle: bundle)
    }

    /// Inject the persona's bundled data into the per-screen view-models that
    /// HomeView owns. Called every time the persona changes or HomeView reappears.
    static func injectInto(
        home: HomeViewModel,
        train: TrainViewModel,
        body: BodyGoalViewModel,
        nutrition: NutritionViewModel,
        scenario: DemoScenario
    ) {
        guard let p = DemoPersonaLibrary.persona(for: scenario) else { return }
        let bundle = DemoDataGenerator.buildBundle(scenario: scenario, persona: p)

        // Programs — feed both HomeViewModel and TrainViewModel so Train screen,
        // Today's Plan, and the brief all see a real active program.
        train.savedPrograms = [bundle.activeProgram, bundle.archivedProgram]
        train.activeProgram = bundle.activeProgram
        home.activeProgram = bundle.activeProgram
        home.allActivePrograms = [bundle.activeProgram]

        // Protocols
        home.allProtocols = bundle.protocols
        home.activeProtocol = bundle.protocols.first(where: { $0.isActive }) ?? bundle.protocols.first

        // Train data
        train.workoutHistory = bundle.workouts
        train.personalRecords = bundle.prs

        // Body goal
        body.weightEntries = bundle.weights.sorted { $0.date < $1.date }
        body.targetWeight = p.weightTargetLbs
        body.goalTargetWeightText = String(format: "%.1f", p.weightTargetLbs)
        body.heightCm = p.heightCm
        switch p.goalType.lowercased() {
        case "weight loss": body.currentGoal = .weightLoss
        case "cutting": body.currentGoal = .cutting
        case "recovery + strength", "recomp": body.currentGoal = .recomp
        case "optimization", "endurance": body.currentGoal = .maintain
        default: body.currentGoal = .weightLoss
        }
        body.hasLoaded = true

        // Nutrition — 30 days of varied meals
        for (date, meals) in bundle.mealsByDay {
            nutrition.mealsByDay[NutritionViewModel.dayKey(for: date)] = meals
        }

        // Shared singletons (insights store, sleep, HK, vials, streak, profile)
        applySharedSingletons(persona: p, bundle: bundle, weights: body.weightEntries, todayMeals: bundle.todayMeals)
    }

    private static func applySharedSingletons(
        persona p: DemoPersona,
        bundle: DemoPersonaBundle,
        weights: [WeightEntry]? = nil,
        todayMeals: [LoggedMeal]? = nil
    ) {
        let weightSeries = weights ?? bundle.weights.sorted { $0.date < $1.date }
        let today = todayMeals ?? bundle.todayMeals

        // Profile display
        ProfileService.shared.cachedDisplayName = p.scenario.fullName

        // Baseline daily targets follow the persona so the brief prompt sees
        // "1,500 kcal target / 130 g protein" etc. instead of leftover values
        // from the previously-signed-in real account.
        applyPersonaTargets(persona: p)

        // Insights data store
        let store = InsightsDataStore.shared
        store.update(
            firstName: p.scenario.displayName,
            activeProtocols: bundle.protocols,
            workoutHistory: bundle.workouts,
            todayMeals: today,
            macroTarget: MacroTarget(calories: p.macroCalories, protein: p.macroProtein, carbs: p.macroCarbs, fat: p.macroFat),
            weightEntries: weightSeries,
            bodyMeasurements: [],
            startingWeight: p.weightStartLbs,
            targetWeight: p.weightTargetLbs,
            bloodwork: bundle.bloodwork,
            muscleRecovery: bundle.muscleRecovery,
            weeklyVolumes: bundle.weeklyVolumes,
            personalRecords: bundle.prs,
            activeProgram: bundle.activeProgram
        )
        for (date, meals) in bundle.mealsByDay {
            store.ingestDailyMeals(date: date, meals: meals)
        }
        store.updateInventory(vials: bundle.vials, lowStock: bundle.lowStock)
        store.updateGoal(goalType: p.goalType, adaptiveReason: nil)
        if let interp = bundle.bloodworkInterpretation {
            store.updateBloodworkInterpretation(interp)
            BloodworkInterpretationService.shared.interpretation = interp
        } else {
            store.updateBloodworkInterpretation(nil)
            BloodworkInterpretationService.shared.interpretation = nil
        }

        // Persona name in the brief greeting follows the persona, not the
        // signed-in account.
        InsightsDataStore.shared.firstName = p.scenario.displayName

        // Vial inventory (drives compound detail vial math & supply line)
        VialInventoryStore.shared.vials = bundle.vials

        // Sleep logs — last 90 nights
        let sleepVM = SleepLogViewModel.shared
        for log in bundle.sleepLogs {
            sleepVM.manualByNight[SleepLogViewModel.nightKey(for: log.night)] = log
        }

        // HealthKit snapshot — sleep/HRV/RHR/steps for the brief
        let hk = HealthKitService.shared
        hk.isAuthorized = true
        hk.sleepHours = bundle.todaySleepHours
        hk.hrv = bundle.todayHRV
        hk.restingHeartRate = bundle.todayRHR
        hk.steps = bundle.todaySteps

        // Streak
        StreakManager.shared.activityLog = bundle.activityLogs
        StreakManager.shared.recalculateStreak()

        // Coherence self-test (printed once per activate)
        DemoCoherenceCheck.run(persona: p, bundle: bundle)
    }

    /// Push the persona's macro / water / step targets into the shared stores
    /// the brief prompt and adaptive context block read from. This is the
    /// difference between the brief saying "vs. your 2,200 kcal target" (the
    /// old default that bled in from a real account) and "vs. your 1,500 kcal
    /// target" (Priya's actual target).
    private static func applyPersonaTargets(persona p: DemoPersona) {
        // Macros — push through AdaptiveMacroStore so `NutritionViewModel.baselineTarget`
        // reads the persona target instead of the hardcoded 2200/150/250/73 default.
        let weightKg = p.weightTodayLbs / 2.2046
        let goal: FitnessGoalType
        switch p.goalType.lowercased() {
        case "weight loss": goal = .weightLoss
        case "cutting": goal = .cutting
        case "recomp", "recovery + strength": goal = .recomp
        case "endurance", "optimization": goal = .maintain
        default: goal = .maintain
        }
        let activity: ActivityLevel
        switch p.avgStepsPerDay {
        case 0..<6000: activity = .sedentary
        case 6000..<9000: activity = .light
        case 9000..<12000: activity = .moderate
        case 12000..<15000: activity = .active
        default: activity = .athlete
        }
        let inputs = MacroGoalInputs(
            weightKg: weightKg,
            heightCm: p.heightCm,
            ageYears: 32,
            biologicalSex: (p.scenario == .theo || p.scenario == .marcus) ? "male" : "female",
            activity: activity,
            goal: goal,
            trainingLoadBoost: 0
        )
        // Bypass `save()` because that recomputes; we want the persona's hand-tuned
        // calorie/protein values to be the source of truth for the brief copy.
        AdaptiveMacroStore.shared.inputs = inputs
        AdaptiveMacroStore.shared.target = MacroTarget(
            calories: p.macroCalories, protein: p.macroProtein,
            carbs: p.macroCarbs, fat: p.macroFat
        )
        AdaptiveMacroStore.shared.isEnabled = true

        // Water goal — scale with body weight (rough "30 ml/kg" rule of thumb).
        let waterMl = max(1800, min(4000, Int(weightKg * 30)))
        WaterViewModel.shared.setGoal(waterMl)

        // Step goal — round the persona's daily average up to the nearest 1k.
        let stepGoal = max(6000, ((p.avgStepsPerDay + 999) / 1000) * 1000)
        UserDefaults.standard.set(stepGoal, forKey: "step_goal")
    }

    static func clearAll() {
        InsightsDataStore.shared.update(
            firstName: "",
            activeProtocols: [],
            workoutHistory: [],
            todayMeals: [],
            macroTarget: MacroTarget(calories: 2200, protein: 150, carbs: 220, fat: 70),
            weightEntries: [],
            bodyMeasurements: [],
            startingWeight: 0,
            targetWeight: 0,
            bloodwork: [],
            muscleRecovery: [],
            weeklyVolumes: [],
            personalRecords: [],
            activeProgram: nil
        )
        InsightsDataStore.shared.updateInventory(vials: [], lowStock: [])
        InsightsDataStore.shared.updateBloodworkInterpretation(nil)
        BloodworkInterpretationService.shared.interpretation = nil
        VialInventoryStore.shared.vials = []
        SleepLogViewModel.shared.manualByNight = [:]
        StreakManager.shared.activityLog = []
        StreakManager.shared.recalculateStreak()
        let hk = HealthKitService.shared
        hk.sleepHours = 0
        hk.hrv = nil
        hk.restingHeartRate = nil
        hk.steps = 0
    }
}

// MARK: - Library

nonisolated enum DemoPersonaLibrary {
    static func persona(for scenario: DemoScenario) -> DemoPersona? {
        switch scenario {
        case .maya:
            return DemoPersona(
                scenario: .maya, bio: "Hypertrophy block · 3 yr training age · listening to recovery for the first time",
                heightCm: 168, currentStreak: 23, longestStreak: 58,
                weightStartLbs: 142, weightTodayLbs: 139.4, weightTargetLbs: 138,
                activeProgramName: "Upper/Lower Hypertrophy", archivedProgramName: "Push/Pull/Legs",
                totalWorkouts: 112, followers: 184, following: 96,
                goalType: "Recomp",
                macroCalories: 2100, macroProtein: 145, macroCarbs: 220, macroFat: 70,
                avgStepsPerDay: 8600, avgSleepHours: 7.1
            )
        case .priya:
            return DemoPersona(
                scenario: .priya, bio: "GLP-1 journey · Tirzepatide 5 mg weekly · learning what foods love me back",
                heightCm: 162, currentStreak: 41, longestStreak: 41,
                weightStartLbs: 198, weightTodayLbs: 174.8, weightTargetLbs: 158,
                activeProgramName: "Full Body Beginner 3x", archivedProgramName: "Walk + Mobility",
                totalWorkouts: 47, followers: 312, following: 88,
                goalType: "Weight Loss",
                macroCalories: 1500, macroProtein: 130, macroCarbs: 130, macroFat: 50,
                avgStepsPerDay: 9100, avgSleepHours: 7.4
            )
        case .theo:
            return DemoPersona(
                scenario: .theo, bio: "Powerlifter rebuild · BPC-157 + TB-500 tendon stack · coming back smart",
                heightCm: 183, currentStreak: 14, longestStreak: 102,
                weightStartLbs: 198, weightTodayLbs: 201.2, weightTargetLbs: 205,
                activeProgramName: "5/3/1 · BBB", archivedProgramName: "Conjugate 2024",
                totalWorkouts: 138, followers: 421, following: 134,
                goalType: "Recovery + Strength",
                macroCalories: 3000, macroProtein: 200, macroCarbs: 350, macroFat: 90,
                avgStepsPerDay: 7200, avgSleepHours: 7.6
            )
        case .marcus:
            return DemoPersona(
                scenario: .marcus, bio: "Health optimization · Test Cyp 100 mg/wk + Ipamorelin · quarterly bloodwork",
                heightCm: 180, currentStreak: 89, longestStreak: 89,
                weightStartLbs: 192, weightTodayLbs: 188.6, weightTargetLbs: 190,
                activeProgramName: "Optimizer PPL", archivedProgramName: "Pre-cycle Conditioning",
                totalWorkouts: 165, followers: 1840, following: 211,
                goalType: "Optimization",
                macroCalories: 2600, macroProtein: 180, macroCarbs: 250, macroFat: 90,
                avgStepsPerDay: 11400, avgSleepHours: 7.8
            )
        case .ava:
            return DemoPersona(
                scenario: .ava, bio: "Marathon block · base phase · low-dose ipamorelin for tendon recovery",
                heightCm: 170, currentStreak: 67, longestStreak: 142,
                weightStartLbs: 132, weightTodayLbs: 131.4, weightTargetLbs: 130,
                activeProgramName: "Marathon Base · Block 2", archivedProgramName: "Marathon Base · Block 1",
                totalWorkouts: 154, followers: 612, following: 188,
                goalType: "Endurance",
                macroCalories: 2400, macroProtein: 120, macroCarbs: 330, macroFat: 80,
                avgStepsPerDay: 14200, avgSleepHours: 7.9
            )
        case .shayla:
            return DemoPersona(
                scenario: .shayla, bio: "Year 2 of training · borrowed Marcus's stack at half-dose · curious not chasing",
                heightCm: 165, currentStreak: 31, longestStreak: 31,
                weightStartLbs: 154, weightTodayLbs: 149.8, weightTargetLbs: 145,
                activeProgramName: "Upper/Lower 4x", archivedProgramName: "Full Body 3x",
                totalWorkouts: 72, followers: 224, following: 142,
                goalType: "Cutting",
                macroCalories: 1800, macroProtein: 140, macroCarbs: 170, macroFat: 65,
                avgStepsPerDay: 9600, avgSleepHours: 6.4
            )
        }
    }
}

// MARK: - Bundle

nonisolated struct DemoPersonaBundle: Sendable {
    let activeProgram: TrainingProgram
    let archivedProgram: TrainingProgram
    let workouts: [WorkoutHistoryDetail]
    let prs: [TrainPersonalRecord]
    let protocols: [PeptideProtocol]
    let vials: [Vial]
    let lowStock: [SupplyForecast]
    let weights: [WeightEntry]
    let bloodwork: [BloodworkEntry]
    let bloodworkInterpretation: BloodworkInterpretation?
    let mealsByDay: [Date: [LoggedMeal]]
    let todayMeals: [LoggedMeal]
    let muscleRecovery: [MuscleRecoveryItem]
    let weeklyVolumes: [WeeklyMuscleVolume]
    let sleepLogs: [ManualSleepLog]
    let todaySleepHours: Double
    let todayHRV: Double?
    let todayRHR: Double?
    let todaySteps: Int
    let activityLogs: [ActivityLog]
}

// MARK: - Data generator

@MainActor
enum DemoDataGenerator {
    static func buildBundle(scenario: DemoScenario, persona p: DemoPersona) -> DemoPersonaBundle {
        let (active, archived) = programs(for: scenario)
        let workouts = workoutHistory(scenario: scenario, program: active, days: 180)
        let prs = personalRecords(scenario: scenario)
        let protocols = protocolStack(scenario: scenario)
        let vials = vialInventory(for: protocols)
        let lowStock = SupplyForecastService.lowStockForecasts(from: protocols)
        let weights = weightSeries(startLbs: p.weightStartLbs, endLbs: p.weightTodayLbs, days: 180)
        let bloodwork = bloodworkPanels(scenario: scenario)
        let interp = bloodworkInterpretation(scenario: scenario, panels: bloodwork)
        let mealsByDay = mealsByDay(scenario: scenario, days: 30)
        let todayMeals = mealsByDay[Calendar.current.startOfDay(for: Date())] ?? mealsForToday(scenario: scenario)
        let (muscleRec, weeklyVol) = muscleSnapshots(scenario: scenario, workouts: workouts)
        let (sleepLogs, todaySleep, todayHRV, todayRHR) = sleepBundle(scenario: scenario, persona: p)

        return DemoPersonaBundle(
            activeProgram: active,
            archivedProgram: archived,
            workouts: workouts,
            prs: prs,
            protocols: protocols,
            vials: vials,
            lowStock: lowStock,
            weights: weights,
            bloodwork: bloodwork,
            bloodworkInterpretation: interp,
            mealsByDay: mealsByDay,
            todayMeals: todayMeals,
            muscleRecovery: muscleRec,
            weeklyVolumes: weeklyVol,
            sleepLogs: sleepLogs,
            todaySleepHours: todaySleep,
            todayHRV: todayHRV,
            todayRHR: todayRHR,
            todaySteps: stepsForToday(scenario: scenario, persona: p),
            activityLogs: activityLogs(scenario: scenario, persona: p)
        )
    }

    // MARK: Seeded RNG

    private static func seededRandom(_ seed: Int) -> () -> Double {
        var state = UInt64(bitPattern: Int64(seed &* 2654435761))
        if state == 0 { state = 0x9E3779B97F4A7C15 }
        return {
            state ^= state >> 12
            state ^= state << 25
            state ^= state >> 27
            let v = state &* 0x2545F4914F6CDD1D
            return Double(v >> 11) / Double(UInt64(1) << 53)
        }
    }

    private static func seed(_ scenario: DemoScenario, _ salt: Int = 0) -> Int {
        let base = scenario.rawValue.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return base &* 31 &+ salt
    }

    // MARK: Weights

    static func weightSeries(startLbs: Double, endLbs: Double, days: Int) -> [WeightEntry] {
        let rand = seededRandom(Int(startLbs * 100) &+ Int(endLbs * 100))
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let delta = (endLbs - startLbs) / Double(max(1, days - 1))
        var out: [WeightEntry] = []
        out.reserveCapacity(days)
        for i in 0..<days {
            let dayOffset = -(days - 1 - i)
            guard let date = cal.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let noise = (rand() - 0.5) * 1.4
            let weight = startLbs + delta * Double(i) + noise
            out.append(WeightEntry(weight: round(weight * 10) / 10, date: date))
        }
        return out
    }

    // MARK: Programs

    private static func ex(_ id: String, sets: Int = 3, repsMin: Int = 8, repsMax: Int = 12) -> ProgramExercise? {
        guard let exercise = ExerciseLibrary.all.first(where: { $0.id == id }) else { return nil }
        return ProgramExercise(exercise: exercise, targetSets: sets, targetRepsMin: repsMin, targetRepsMax: repsMax)
    }

    private static func day(_ name: String, weekday: ProgramWeekday, _ exercises: [ProgramExercise?]) -> ProgramDay {
        ProgramDay(name: name, exercises: exercises.compactMap { $0 }, scheduledWeekday: weekday.rawValue)
    }

    static func programs(for scenario: DemoScenario) -> (active: TrainingProgram, archived: TrainingProgram) {
        switch scenario {
        case .maya:
            let lowerA = day("Leg Day (Deadlift)", weekday: .monday, [
                ex("barbell-squat", sets: 4, repsMin: 6, repsMax: 8),
                ex("romanian-deadlift", sets: 3, repsMin: 8, repsMax: 10),
                ex("hip-thrust", sets: 3, repsMin: 8, repsMax: 12),
                ex("leg-press", sets: 3, repsMin: 10, repsMax: 12),
                ex("standing-calf-raise", sets: 3, repsMin: 12, repsMax: 15)
            ])
            let upperA = day("Upper Body A", weekday: .tuesday, [
                ex("barbell-bench-press", sets: 4, repsMin: 6, repsMax: 8),
                ex("barbell-row", sets: 4, repsMin: 6, repsMax: 8),
                ex("dumbbell-shoulder-press", sets: 3, repsMin: 8, repsMax: 12),
                ex("lat-pulldown", sets: 3, repsMin: 10, repsMax: 12),
                ex("dumbbell-curl", sets: 3, repsMin: 10, repsMax: 12)
            ])
            let lowerB = day("Leg Day (Squat)", weekday: .thursday, [
                ex("hip-thrust", sets: 4, repsMin: 6, repsMax: 8),
                ex("front-squat", sets: 3, repsMin: 6, repsMax: 8),
                ex("dumbbell-rdl", sets: 3, repsMin: 8, repsMax: 10),
                ex("walking-lunges", sets: 3, repsMin: 10, repsMax: 12),
                ex("seated-leg-curl", sets: 3, repsMin: 10, repsMax: 12)
            ])
            let upperB = day("Upper Body B", weekday: .friday, [
                ex("incline-dumbbell-press", sets: 4, repsMin: 8, repsMax: 10),
                ex("dumbbell-row", sets: 4, repsMin: 8, repsMax: 10),
                ex("lateral-raises", sets: 3, repsMin: 12, repsMax: 15),
                ex("face-pulls", sets: 3, repsMin: 12, repsMax: 15),
                ex("tricep-pushdown", sets: 3, repsMin: 12, repsMax: 15)
            ])
            let active = TrainingProgram(name: "Upper/Lower Hypertrophy", type: .recurringSplit, daysPerWeek: 4, days: [lowerA, upperA, lowerB, upperB], isActive: true)
            let archived = TrainingProgram(name: "Push/Pull/Legs", type: .recurringSplit, daysPerWeek: 6, days: pplArchive(), isActive: false)
            return (active, archived)

        case .priya:
            let fbA = day("Full Body A", weekday: .monday, [
                ex("goblet-squat", sets: 3, repsMin: 8, repsMax: 12),
                ex("dumbbell-row", sets: 3, repsMin: 10, repsMax: 12),
                ex("push-ups", sets: 3, repsMin: 6, repsMax: 10),
                ex("plank", sets: 3, repsMin: 30, repsMax: 45)
            ])
            let fbB = day("Full Body B", weekday: .wednesday, [
                ex("dumbbell-rdl", sets: 3, repsMin: 10, repsMax: 12),
                ex("lat-pulldown", sets: 3, repsMin: 10, repsMax: 12),
                ex("dumbbell-shoulder-press", sets: 3, repsMin: 10, repsMax: 12),
                ex("glute-bridge", sets: 3, repsMin: 12, repsMax: 15)
            ])
            let fbC = day("Full Body C", weekday: .friday, [
                ex("goblet-squat", sets: 3, repsMin: 10, repsMax: 12),
                ex("seated-cable-row", sets: 3, repsMin: 10, repsMax: 12),
                ex("incline-dumbbell-press", sets: 3, repsMin: 10, repsMax: 12),
                ex("dead-bug", sets: 3, repsMin: 8, repsMax: 10)
            ])
            let active = TrainingProgram(name: "Full Body Beginner 3x", type: .recurringSplit, daysPerWeek: 3, days: [fbA, fbB, fbC], isActive: true)
            let walking = day("Walk + Mobility", weekday: .saturday, [
                ex("plank", sets: 3, repsMin: 20, repsMax: 30)
            ])
            let archived = TrainingProgram(name: "Walk + Mobility", type: .flexible, daysPerWeek: 5, days: [walking], isActive: false)
            return (active, archived)

        case .theo:
            let bench = day("Bench Day", weekday: .monday, [
                ex("barbell-bench-press", sets: 5, repsMin: 3, repsMax: 5),
                ex("incline-barbell-press", sets: 5, repsMin: 8, repsMax: 10),
                ex("barbell-row", sets: 4, repsMin: 6, repsMax: 8),
                ex("tricep-pushdown", sets: 3, repsMin: 10, repsMax: 12)
            ])
            let squat = day("Squat Day", weekday: .tuesday, [
                ex("barbell-squat", sets: 5, repsMin: 3, repsMax: 5),
                ex("front-squat", sets: 5, repsMin: 5, repsMax: 8),
                ex("romanian-deadlift", sets: 3, repsMin: 6, repsMax: 8),
                ex("standing-calf-raise", sets: 3, repsMin: 10, repsMax: 12)
            ])
            let press = day("OHP Day", weekday: .thursday, [
                ex("overhead-press", sets: 5, repsMin: 3, repsMax: 5),
                ex("dumbbell-shoulder-press", sets: 5, repsMin: 8, repsMax: 10),
                ex("pull-ups", sets: 4, repsMin: 5, repsMax: 8),
                ex("dumbbell-curl", sets: 3, repsMin: 8, repsMax: 10)
            ])
            let pull = day("Deadlift Day", weekday: .saturday, [
                ex("barbell-deadlift", sets: 5, repsMin: 1, repsMax: 3),
                ex("barbell-row", sets: 5, repsMin: 6, repsMax: 8),
                ex("lat-pulldown", sets: 3, repsMin: 8, repsMax: 10),
                ex("plank", sets: 3, repsMin: 45, repsMax: 60)
            ])
            let active = TrainingProgram(name: "5/3/1 · BBB", type: .timedProgram, daysPerWeek: 4, days: [bench, squat, press, pull], isActive: true)
            let archived = TrainingProgram(name: "Conjugate 2024", type: .recurringSplit, daysPerWeek: 4, days: [
                day("Max Effort Upper", weekday: .monday, [ex("barbell-bench-press", sets: 5, repsMin: 1, repsMax: 3)]),
                day("Max Effort Lower", weekday: .wednesday, [ex("barbell-squat", sets: 5, repsMin: 1, repsMax: 3)])
            ], isActive: false)
            return (active, archived)

        case .marcus:
            let push = day("Push", weekday: .monday, [
                ex("incline-barbell-press", sets: 4, repsMin: 5, repsMax: 8),
                ex("dumbbell-shoulder-press", sets: 3, repsMin: 8, repsMax: 12),
                ex("chest-dips", sets: 3, repsMin: 8, repsMax: 12),
                ex("tricep-pushdown", sets: 3, repsMin: 12, repsMax: 15),
                ex("lateral-raises", sets: 3, repsMin: 12, repsMax: 15)
            ])
            let pull = day("Pull", weekday: .tuesday, [
                ex("pull-ups", sets: 4, repsMin: 5, repsMax: 8),
                ex("barbell-row", sets: 4, repsMin: 6, repsMax: 8),
                ex("seated-cable-row", sets: 3, repsMin: 10, repsMax: 12),
                ex("face-pulls", sets: 3, repsMin: 12, repsMax: 15),
                ex("dumbbell-curl", sets: 3, repsMin: 10, repsMax: 12)
            ])
            let legs = day("Legs", weekday: .thursday, [
                ex("front-squat", sets: 4, repsMin: 5, repsMax: 8),
                ex("romanian-deadlift", sets: 3, repsMin: 6, repsMax: 8),
                ex("walking-lunges", sets: 3, repsMin: 10, repsMax: 12),
                ex("seated-leg-curl", sets: 3, repsMin: 10, repsMax: 12),
                ex("standing-calf-raise", sets: 3, repsMin: 12, repsMax: 15)
            ])
            let cond = day("Conditioning", weekday: .saturday, [
                ex("rowing-machine", sets: 1, repsMin: 20, repsMax: 30),
                ex("kettlebell-swing", sets: 5, repsMin: 15, repsMax: 20)
            ])
            let active = TrainingProgram(name: "Optimizer PPL", type: .recurringSplit, daysPerWeek: 4, days: [push, pull, legs, cond], isActive: true)
            let archived = TrainingProgram(name: "Pre-cycle Conditioning", type: .recurringSplit, daysPerWeek: 3, days: [
                day("Conditioning A", weekday: .monday, [ex("rowing-machine", sets: 1, repsMin: 30, repsMax: 30)]),
                day("Conditioning B", weekday: .wednesday, [ex("cycling", sets: 1, repsMin: 45, repsMax: 45)])
            ], isActive: false)
            return (active, archived)

        case .ava:
            // Runner program: easy + tempo + intervals + long run + 1 strength maint.
            let easy = day("Easy Run · 6 mi", weekday: .monday, [
                ex("treadmill-run", sets: 1, repsMin: 50, repsMax: 60)
            ])
            let tempo = day("Tempo · 4 mi", weekday: .tuesday, [
                ex("treadmill-run", sets: 1, repsMin: 35, repsMax: 40)
            ])
            let strength = day("Strength Maint.", weekday: .wednesday, [
                ex("dumbbell-rdl", sets: 3, repsMin: 8, repsMax: 10),
                ex("walking-lunges", sets: 3, repsMin: 10, repsMax: 12),
                ex("plank", sets: 3, repsMin: 45, repsMax: 60),
                ex("standing-calf-raise", sets: 3, repsMin: 12, repsMax: 15)
            ])
            let intervals = day("Intervals · 6x800m", weekday: .thursday, [
                ex("treadmill-run", sets: 1, repsMin: 40, repsMax: 45)
            ])
            let long = day("Long Run · 14 mi", weekday: .saturday, [
                ex("treadmill-run", sets: 1, repsMin: 105, repsMax: 120)
            ])
            let active = TrainingProgram(name: "Marathon Base · Block 2", type: .timedProgram, daysPerWeek: 5, days: [easy, tempo, strength, intervals, long], isActive: true)
            let archived = TrainingProgram(name: "Marathon Base · Block 1", type: .timedProgram, daysPerWeek: 4, days: [
                day("Easy", weekday: .monday, [ex("treadmill-run", sets: 1, repsMin: 40, repsMax: 50)]),
                day("Long", weekday: .saturday, [ex("treadmill-run", sets: 1, repsMin: 75, repsMax: 90)])
            ], isActive: false)
            return (active, archived)

        case .shayla:
            let upperA = day("Upper Body A", weekday: .monday, [
                ex("dumbbell-bench-press", sets: 4, repsMin: 8, repsMax: 10),
                ex("seated-cable-row", sets: 4, repsMin: 8, repsMax: 10),
                ex("lateral-raises", sets: 3, repsMin: 12, repsMax: 15),
                ex("dumbbell-curl", sets: 3, repsMin: 10, repsMax: 12),
                ex("tricep-pushdown", sets: 3, repsMin: 12, repsMax: 15)
            ])
            let lowerA = day("Leg Day (Deadlift)", weekday: .tuesday, [
                ex("hip-thrust", sets: 4, repsMin: 8, repsMax: 10),
                ex("goblet-squat", sets: 3, repsMin: 10, repsMax: 12),
                ex("dumbbell-rdl", sets: 3, repsMin: 8, repsMax: 10),
                ex("walking-lunges", sets: 3, repsMin: 10, repsMax: 12)
            ])
            let upperB = day("Upper Body B", weekday: .thursday, [
                ex("incline-dumbbell-press", sets: 4, repsMin: 8, repsMax: 10),
                ex("lat-pulldown", sets: 4, repsMin: 10, repsMax: 12),
                ex("face-pulls", sets: 3, repsMin: 12, repsMax: 15),
                ex("hammer-curl", sets: 3, repsMin: 10, repsMax: 12)
            ])
            let lowerB = day("Leg Day (Squat)", weekday: .friday, [
                ex("hip-thrust", sets: 3, repsMin: 10, repsMax: 12),
                ex("leg-press", sets: 3, repsMin: 10, repsMax: 12),
                ex("seated-leg-curl", sets: 3, repsMin: 12, repsMax: 15),
                ex("standing-calf-raise", sets: 3, repsMin: 12, repsMax: 15)
            ])
            let active = TrainingProgram(name: "Upper/Lower 4x", type: .recurringSplit, daysPerWeek: 4, days: [upperA, lowerA, upperB, lowerB], isActive: true)
            let archived = TrainingProgram(name: "Full Body 3x", type: .recurringSplit, daysPerWeek: 3, days: [
                day("FB A", weekday: .monday, [ex("goblet-squat", sets: 3, repsMin: 10, repsMax: 12)]),
                day("FB B", weekday: .wednesday, [ex("dumbbell-rdl", sets: 3, repsMin: 10, repsMax: 12)])
            ], isActive: false)
            return (active, archived)
        }
    }

    private static func pplArchive() -> [ProgramDay] {
        return [
            day("Push", weekday: .monday, [
                ex("barbell-bench-press", sets: 4, repsMin: 6, repsMax: 8),
                ex("dumbbell-shoulder-press", sets: 3, repsMin: 8, repsMax: 10)
            ]),
            day("Pull", weekday: .tuesday, [
                ex("barbell-row", sets: 4, repsMin: 6, repsMax: 8),
                ex("lat-pulldown", sets: 3, repsMin: 10, repsMax: 12)
            ]),
            day("Legs", weekday: .wednesday, [
                ex("barbell-squat", sets: 4, repsMin: 6, repsMax: 8),
                ex("romanian-deadlift", sets: 3, repsMin: 8, repsMax: 10)
            ])
        ]
    }

    // MARK: Workouts

    static func workoutHistory(scenario: DemoScenario, program: TrainingProgram, days: Int) -> [WorkoutHistoryDetail] {
        let rand = seededRandom(seed(scenario, 1))
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var out: [WorkoutHistoryDetail] = []
        let daysPerWeek = max(1, program.daysPerWeek)
        let target = Int(Double(days) * Double(daysPerWeek) / 7.0)
        var dayOffset = 1
        var dayIdx = 0

        while out.count < target && dayOffset < days {
            guard let date = cal.date(byAdding: .day, value: -dayOffset, to: today) else { break }
            dayOffset += 1
            // Skip rare days (life happens)
            if rand() < 0.08 { continue }
            let dayPlan = program.days[dayIdx % program.days.count]
            dayIdx += 1
            var exercises: [WorkoutHistoryExerciseDetail] = []
            var totalVolume = 0
            for pe in dayPlan.exercises {
                let setCount = max(1, pe.targetSets + (rand() < 0.3 ? -1 : 0))
                let baseWeight = baseLoadFor(scenario: scenario, exerciseName: pe.exerciseName)
                let baseReps = (pe.targetRepsMin + pe.targetRepsMax) / 2
                var sets: [WorkoutHistorySetDetail] = []
                for s in 1...setCount {
                    let weightJitter = (rand() - 0.5) * max(5, baseWeight * 0.05)
                    let weight = baseWeight > 0 ? max(0, round(baseWeight + weightJitter)) : 0
                    let reps = max(1, baseReps + Int((rand() - 0.5) * 3))
                    sets.append(WorkoutHistorySetDetail(setNumber: s, weight: weight, reps: reps))
                    totalVolume += Int(weight) * reps
                }
                exercises.append(WorkoutHistoryExerciseDetail(exerciseName: pe.exerciseName, sets: sets))
            }
            out.append(WorkoutHistoryDetail(
                name: dayPlan.name,
                date: date,
                durationMinutes: 45 + Int(rand() * 35),
                totalVolume: totalVolume,
                caloriesBurned: 220 + Int(rand() * 220),
                exercises: exercises
            ))
        }
        return out
    }

    private static func baseLoadFor(scenario: DemoScenario, exerciseName: String) -> Double {
        // Loads scaled to archetype. lbs.
        switch scenario {
        case .maya:
            switch exerciseName {
            case "Barbell Back Squat": return 175
            case "Barbell Bench Press": return 115
            case "Romanian Deadlift": return 185
            case "Barbell Hip Thrust": return 245
            case "Front Squat": return 135
            case "Incline Dumbbell Press": return 35
            case "Dumbbell Shoulder Press": return 30
            case "Barbell Row": return 115
            case "Single-Arm Dumbbell Row": return 40
            case "Lat Pulldown": return 105
            case "Leg Press": return 280
            case "Dumbbell Romanian Deadlift": return 50
            case "Walking Lunges": return 25
            case "Lateral Raises", "Face Pulls", "Tricep Pushdown", "Dumbbell Curl": return 25
            case "Standing Calf Raise", "Seated Leg Curl": return 90
            default: return 0
            }
        case .priya:
            switch exerciseName {
            case "Goblet Squat": return 35
            case "Single-Arm Dumbbell Row": return 25
            case "Push-Ups": return 0
            case "Plank": return 0
            case "Dumbbell Romanian Deadlift": return 30
            case "Lat Pulldown": return 60
            case "Dumbbell Shoulder Press": return 15
            case "Glute Bridge": return 0
            case "Seated Cable Row": return 60
            case "Incline Dumbbell Press": return 20
            case "Dead Bug": return 0
            default: return 0
            }
        case .theo:
            switch exerciseName {
            case "Barbell Bench Press": return 275
            case "Incline Barbell Press": return 205
            case "Barbell Row": return 225
            case "Barbell Back Squat": return 365
            case "Front Squat": return 275
            case "Romanian Deadlift": return 315
            case "Barbell Overhead Press": return 175
            case "Dumbbell Shoulder Press": return 70
            case "Pull-Ups": return 0
            case "Barbell Deadlift": return 425
            case "Lat Pulldown": return 200
            case "Dumbbell Curl": return 40
            case "Tricep Pushdown": return 70
            case "Standing Calf Raise": return 180
            case "Plank": return 0
            default: return 0
            }
        case .marcus:
            switch exerciseName {
            case "Incline Barbell Press": return 185
            case "Dumbbell Shoulder Press": return 60
            case "Chest Dips": return 45
            case "Tricep Pushdown": return 75
            case "Lateral Raises": return 25
            case "Pull-Ups": return 25 // weighted
            case "Barbell Row": return 185
            case "Seated Cable Row": return 160
            case "Face Pulls": return 60
            case "Dumbbell Curl": return 40
            case "Front Squat": return 225
            case "Romanian Deadlift": return 245
            case "Walking Lunges": return 40
            case "Seated Leg Curl": return 130
            case "Standing Calf Raise": return 200
            case "Rowing Machine", "Stationary Cycling": return 0
            case "Kettlebell Swing": return 53
            default: return 0
            }
        case .ava:
            switch exerciseName {
            case "Dumbbell Romanian Deadlift": return 80
            case "Walking Lunges": return 25
            case "Plank": return 0
            case "Standing Calf Raise": return 90
            case "Treadmill Run": return 0
            default: return 0
            }
        case .shayla:
            switch exerciseName {
            case "Dumbbell Bench Press": return 35
            case "Seated Cable Row": return 90
            case "Lateral Raises": return 12
            case "Dumbbell Curl": return 20
            case "Tricep Pushdown": return 50
            case "Barbell Hip Thrust": return 165
            case "Goblet Squat": return 50
            case "Dumbbell Romanian Deadlift": return 45
            case "Walking Lunges": return 25
            case "Incline Dumbbell Press": return 30
            case "Lat Pulldown": return 85
            case "Face Pulls": return 40
            case "Hammer Curl": return 22
            case "Leg Press": return 230
            case "Seated Leg Curl": return 90
            case "Standing Calf Raise": return 110
            default: return 0
            }
        }
    }

    // MARK: PRs

    static func personalRecords(scenario: DemoScenario) -> [TrainPersonalRecord] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        func d(_ daysAgo: Int) -> Date { cal.date(byAdding: .day, value: -daysAgo, to: today) ?? today }
        switch scenario {
        case .maya:
            return [
                TrainPersonalRecord(exerciseName: "Barbell Back Squat", weight: 185, reps: 5, dateAchieved: d(12), isNew: true, previousBest: 175),
                TrainPersonalRecord(exerciseName: "Barbell Hip Thrust", weight: 265, reps: 8, dateAchieved: d(28), isNew: false, previousBest: 245),
                TrainPersonalRecord(exerciseName: "Romanian Deadlift", weight: 205, reps: 6, dateAchieved: d(45), isNew: false, previousBest: 185),
                TrainPersonalRecord(exerciseName: "Barbell Bench Press", weight: 125, reps: 6, dateAchieved: d(64), isNew: false, previousBest: 120),
                TrainPersonalRecord(exerciseName: "Front Squat", weight: 145, reps: 5, dateAchieved: d(78), isNew: false, previousBest: 135)
            ]
        case .priya:
            return [
                TrainPersonalRecord(exerciseName: "Goblet Squat", weight: 45, reps: 12, dateAchieved: d(8), isNew: true, previousBest: 35),
                TrainPersonalRecord(exerciseName: "Single-Arm Dumbbell Row", weight: 30, reps: 12, dateAchieved: d(22), isNew: false, previousBest: 25),
                TrainPersonalRecord(exerciseName: "Plank", weight: 0, reps: 75, dateAchieved: d(35), isNew: false, previousBest: 60),
                TrainPersonalRecord(exerciseName: "Dumbbell Romanian Deadlift", weight: 35, reps: 10, dateAchieved: d(56), isNew: false, previousBest: 25)
            ]
        case .theo:
            return [
                TrainPersonalRecord(exerciseName: "Barbell Deadlift", weight: 485, reps: 1, dateAchieved: d(31), isNew: false, previousBest: 475),
                TrainPersonalRecord(exerciseName: "Barbell Back Squat", weight: 405, reps: 3, dateAchieved: d(48), isNew: false, previousBest: 395),
                TrainPersonalRecord(exerciseName: "Barbell Bench Press", weight: 305, reps: 3, dateAchieved: d(62), isNew: false, previousBest: 295),
                TrainPersonalRecord(exerciseName: "Barbell Overhead Press", weight: 195, reps: 3, dateAchieved: d(88), isNew: false, previousBest: 185),
                TrainPersonalRecord(exerciseName: "Front Squat", weight: 315, reps: 3, dateAchieved: d(104), isNew: false, previousBest: 305)
            ]
        case .marcus:
            return [
                TrainPersonalRecord(exerciseName: "Pull-Ups", weight: 70, reps: 5, dateAchieved: d(18), isNew: true, previousBest: 60),
                TrainPersonalRecord(exerciseName: "Incline Barbell Press", weight: 205, reps: 6, dateAchieved: d(35), isNew: false, previousBest: 195),
                TrainPersonalRecord(exerciseName: "Front Squat", weight: 245, reps: 5, dateAchieved: d(52), isNew: false, previousBest: 235),
                TrainPersonalRecord(exerciseName: "Romanian Deadlift", weight: 275, reps: 5, dateAchieved: d(70), isNew: false, previousBest: 265)
            ]
        case .ava:
            return [
                TrainPersonalRecord(exerciseName: "Half Marathon", weight: 13, reps: 1, dateAchieved: d(21), isNew: true, previousBest: nil),
                TrainPersonalRecord(exerciseName: "5K", weight: 3, reps: 1, dateAchieved: d(56), isNew: false, previousBest: nil),
                TrainPersonalRecord(exerciseName: "10K", weight: 6, reps: 1, dateAchieved: d(90), isNew: false, previousBest: nil),
                TrainPersonalRecord(exerciseName: "Long Run", weight: 18, reps: 1, dateAchieved: d(35), isNew: false, previousBest: nil)
            ]
        case .shayla:
            return [
                TrainPersonalRecord(exerciseName: "Barbell Hip Thrust", weight: 185, reps: 8, dateAchieved: d(14), isNew: true, previousBest: 165),
                TrainPersonalRecord(exerciseName: "Goblet Squat", weight: 60, reps: 8, dateAchieved: d(34), isNew: false, previousBest: 50),
                TrainPersonalRecord(exerciseName: "Dumbbell Bench Press", weight: 40, reps: 10, dateAchieved: d(55), isNew: false, previousBest: 35),
                TrainPersonalRecord(exerciseName: "Lat Pulldown", weight: 100, reps: 10, dateAchieved: d(72), isNew: false, previousBest: 90)
            ]
        }
    }

    // MARK: Protocols

    static func protocolStack(scenario: DemoScenario) -> [PeptideProtocol] {
        let cal = Calendar.current
        let today = Date()
        let sites: [InjectionSite] = InjectionSite.allCases
        func ts(daysAgo: Int) -> Date { cal.date(byAdding: .day, value: -daysAgo, to: today) ?? today }

        switch scenario {
        case .maya:
            // Low-dose Retatrutide 1 mg weekly (microdose for the last recomp pounds) +
            // GHK-Cu 1 mg daily under-the-skin for skin/recovery support during the lean.
            // Retatrutide vial: 10 mg / 2 mL → 5 mg/mL → 0.2 mL per 1 mg dose.
            // GHK-Cu vial: 50 mg / 5 mL → 10 mg/mL → 0.1 mL per 1 mg dose.
            let reta = ProtocolCompound(
                compoundName: "Retatrutide", doseMcg: 1000, frequency: "Weekly",
                injectionRoute: .subcutaneous, reconstitutionVolume: 2.0, vialSizeMg: 10
            )
            let ghk = ProtocolCompound(
                compoundName: "GHK-Cu", doseMcg: 1000, frequency: "Daily",
                injectionRoute: .subcutaneous, reconstitutionVolume: 5.0, vialSizeMg: 50
            )
            var logs: [DoseLogEntry] = []
            // Retatrutide: weekly on Mondays for 6 weeks of clean adherence.
            for w in 0..<6 {
                let d = w * 7 + 1
                logs.append(DoseLogEntry(
                    compoundName: "Retatrutide", doseMcg: 1000,
                    timestamp: ts(daysAgo: d), injectionSite: sites[w % sites.count]
                ))
            }
            // GHK-Cu: daily, ~95% adherence across the 6 weeks.
            for d in 0..<42 {
                // Two missed days early (week 1) — feels real, not robotic.
                if d == 37 || d == 35 {
                    logs.append(DoseLogEntry(
                        compoundName: "GHK-Cu", doseMcg: 1000,
                        timestamp: ts(daysAgo: d), injectionSite: sites[d % sites.count],
                        wasSkipped: true,
                        skipReason: "Out of town, forgot kit"
                    ))
                    continue
                }
                logs.append(DoseLogEntry(
                    compoundName: "GHK-Cu", doseMcg: 1000,
                    timestamp: ts(daysAgo: d), injectionSite: sites[d % sites.count]
                ))
            }
            let proto = PeptideProtocol(
                name: "Recomp Finish + Skin Support", goal: .weightLoss, compounds: [reta, ghk],
                startDate: ts(daysAgo: 42), totalWeeks: 16, loadingWeeks: 2,
                maintenanceWeeks: 12, taperingWeeks: 2, offCycleWeeks: 4,
                isActive: true, doseLog: logs
            )
            return [proto]

        case .priya:
            // Tirzepatide 5 mg weekly. Vial = 10 mg reconstituted with 2 mL diluent
            // → 5 mg/mL, draw 1 mL per 5 mg dose. 18 weekly doses (titrated 2.5→5).
            let compound = ProtocolCompound(
                compoundName: "Tirzepatide", doseMcg: 5000, frequency: "Weekly",
                injectionRoute: .subcutaneous, reconstitutionVolume: 2.0, vialSizeMg: 10
            )
            var logs: [DoseLogEntry] = []
            // Weeks 0-3: titration at 2.5mg, then 5mg from week 4 onward.
            for w in 0..<18 {
                let d = w * 7 + 2 // dosed every Wed
                let dose: Double = w < 4 ? 2500 : 5000
                logs.append(DoseLogEntry(
                    compoundName: "Tirzepatide", doseMcg: dose,
                    timestamp: ts(daysAgo: d), injectionSite: sites[w % sites.count]
                ))
            }
            var proto = PeptideProtocol(
                name: "Tirzepatide Titration", goal: .weightLoss, compounds: [compound],
                startDate: ts(daysAgo: 126), totalWeeks: 26, loadingWeeks: 4,
                maintenanceWeeks: 18, taperingWeeks: 4, offCycleWeeks: nil,
                isActive: true, doseLog: logs
            )
            proto.sideEffectLog = [
                SideEffectEntry(timestamp: cal.date(byAdding: .hour, value: -4, to: today) ?? today, effect: "GI discomfort", severity: 3, notes: "After dinner, ~28h post-dose. Burrito night."),
                SideEffectEntry(timestamp: cal.date(byAdding: .day, value: -8, to: today) ?? today, effect: "Mild nausea", severity: 2, notes: "Morning after dose."),
                SideEffectEntry(timestamp: cal.date(byAdding: .day, value: -22, to: today) ?? today, effect: "Constipation", severity: 2, notes: "Resolved after fiber bump.")
            ]
            return [proto]

        case .theo:
            // BPC-157 250 mcg daily SC, TB-500 2.5 mg twice weekly.
            // BPC vial: 5 mg / 2 mL → 2.5 mg/mL → 0.1 mL per 250 mcg dose.
            // TB-500 vial: 10 mg / 2 mL → 5 mg/mL → 0.5 mL per 2.5 mg dose.
            let bpc = ProtocolCompound(
                compoundName: "BPC-157", doseMcg: 250, frequency: "Daily",
                injectionRoute: .subcutaneous, reconstitutionVolume: 2.0, vialSizeMg: 5
            )
            let tb = ProtocolCompound(
                compoundName: "TB-500", doseMcg: 2500, frequency: "Twice weekly",
                injectionRoute: .subcutaneous, reconstitutionVolume: 2.0, vialSizeMg: 10
            )
            var logs: [DoseLogEntry] = []
            // BPC-157 daily, but the last 3 days are skipped — that's the
            // "missed dose" hero story. Last non-skipped dose is 3 days ago,
            // which trips the daily-frequency `missedDose` signal (>=2d).
            for d in 0..<90 {
                let isRecentMiss = d <= 2
                if isRecentMiss {
                    logs.append(DoseLogEntry(
                        compoundName: "BPC-157", doseMcg: 250,
                        timestamp: ts(daysAgo: d), injectionSite: sites[d % sites.count],
                        wasSkipped: true,
                        skipReason: d == 2 ? "Forgot — out of town Wednesday" : (d == 1 ? "Travel day — no kit" : "Still rebuilding cadence")
                    ))
                    continue
                }
                logs.append(DoseLogEntry(
                    compoundName: "BPC-157", doseMcg: 250,
                    timestamp: ts(daysAgo: d), injectionSite: sites[d % sites.count]
                ))
            }
            // TB-500 twice weekly: Mon + Thu (offsets 0/3/7/10/14/17/...)
            for week in 0..<13 {
                for offset in [0, 3] {
                    let d = week * 7 + offset
                    guard d < 90 else { continue }
                    logs.append(DoseLogEntry(
                        compoundName: "TB-500", doseMcg: 2500,
                        timestamp: ts(daysAgo: d), injectionSite: sites[(d + 1) % sites.count]
                    ))
                }
            }
            let proto = PeptideProtocol(
                name: "Tendon Recovery Stack", goal: .healing, compounds: [bpc, tb],
                startDate: ts(daysAgo: 120), totalWeeks: 16, loadingWeeks: 2,
                maintenanceWeeks: 12, taperingWeeks: 2, offCycleWeeks: 4,
                isActive: true, doseLog: logs
            )
            return [proto]

        case .marcus:
            // Test Cyp 100 mg/wk IM (oil-based, no reconstitution; 200 mg/mL vial).
            // Ipamorelin 300 mcg daily SC (5 mg vial / 2 mL → 2.5 mg/mL → 0.12 mL/dose).
            let test = ProtocolCompound(
                compoundName: "Testosterone Cypionate", doseMcg: 100_000, frequency: "Weekly",
                injectionRoute: .intramuscular, reconstitutionVolume: nil, vialSizeMg: 2000 // 200mg/mL × 10mL
            )
            let ipa = ProtocolCompound(
                compoundName: "Ipamorelin", doseMcg: 300, frequency: "Daily",
                injectionRoute: .subcutaneous, reconstitutionVolume: 2.0, vialSizeMg: 5
            )
            var logs: [DoseLogEntry] = []
            for d in 0..<120 {
                logs.append(DoseLogEntry(
                    compoundName: "Ipamorelin", doseMcg: 300,
                    timestamp: ts(daysAgo: d), injectionSite: sites[d % sites.count]
                ))
                if d % 7 == 0 {
                    logs.append(DoseLogEntry(
                        compoundName: "Testosterone Cypionate", doseMcg: 100_000,
                        timestamp: ts(daysAgo: d), injectionSite: sites[(d + 2) % sites.count]
                    ))
                }
            }
            let proto = PeptideProtocol(
                name: "Optimizer Stack", goal: .general, compounds: [test, ipa],
                startDate: ts(daysAgo: 160), totalWeeks: nil, loadingWeeks: nil,
                maintenanceWeeks: nil, taperingWeeks: nil, offCycleWeeks: nil,
                isActive: true, doseLog: logs
            )
            return [proto]

        case .ava:
            // Low-dose Ipamorelin 200 mcg daily for tendon recovery during marathon block.
            let ipa = ProtocolCompound(
                compoundName: "Ipamorelin", doseMcg: 200, frequency: "Daily",
                injectionRoute: .subcutaneous, reconstitutionVolume: 2.0, vialSizeMg: 5
            )
            var logs: [DoseLogEntry] = []
            for d in 0..<90 {
                logs.append(DoseLogEntry(
                    compoundName: "Ipamorelin", doseMcg: 200,
                    timestamp: ts(daysAgo: d), injectionSite: sites[d % sites.count]
                ))
            }
            let proto = PeptideProtocol(
                name: "Endurance Recovery", goal: .healing, compounds: [ipa],
                startDate: ts(daysAgo: 100), totalWeeks: 16, loadingWeeks: nil,
                maintenanceWeeks: 14, taperingWeeks: 2, offCycleWeeks: 4,
                isActive: true, doseLog: logs
            )
            return [proto]

        case .shayla:
            // Borrowed Marcus's TRT stack — Test Cyp at HALF dose (50mg/wk), no Ipamorelin yet.
            // This makes "Marcus runs this at 100mg — start at 50mg for 2 weeks" literally consistent.
            let test = ProtocolCompound(
                compoundName: "Testosterone Cypionate", doseMcg: 50_000, frequency: "Weekly",
                injectionRoute: .intramuscular, reconstitutionVolume: nil, vialSizeMg: 2000
            )
            var logs: [DoseLogEntry] = []
            for w in 0..<6 {
                let d = w * 7 + 2
                logs.append(DoseLogEntry(
                    compoundName: "Testosterone Cypionate", doseMcg: 50_000,
                    timestamp: ts(daysAgo: d), injectionSite: sites[w % sites.count],
                    notes: w == 0 ? "Borrowed from Marcus's protocol — half-dose start" : ""
                ))
            }
            let proto = PeptideProtocol(
                name: "Borrowed: Marcus's Stack (½ Dose)", goal: .weightLoss, compounds: [test],
                startDate: ts(daysAgo: 42), totalWeeks: 14, loadingWeeks: 2,
                maintenanceWeeks: 10, taperingWeeks: 2, offCycleWeeks: 4,
                isActive: true, doseLog: logs
            )
            return [proto]
        }
    }

    // MARK: Vials

    static func vialInventory(for protocols: [PeptideProtocol]) -> [Vial] {
        let cal = Calendar.current
        let today = Date()
        var out: [Vial] = []
        for proto in protocols {
            for c in proto.compounds {
                let used = proto.doseLog
                    .filter { $0.compoundName == c.compoundName && !$0.wasSkipped }
                    .reduce(0.0) { $0 + $1.doseMcg }
                let vialMg = c.vialSizeMg ?? 5
                let vialsNeeded = max(1, Int((used / (vialMg * 1000)).rounded(.up)))
                let currentUsage = used.truncatingRemainder(dividingBy: vialMg * 1000)
                let bud = ReconHelper.defaultBUDDays(for: c.compoundName)
                // Historical (depleted) vials
                for i in 0..<max(0, vialsNeeded - 1) {
                    let recon = cal.date(byAdding: .day, value: -(bud * (vialsNeeded - i)), to: today)
                    out.append(Vial(
                        compoundName: c.compoundName, vialSizeMg: vialMg,
                        diluentMl: c.reconstitutionVolume, reconstitutedOn: recon,
                        storage: .fridge, lotNumber: "LOT-\(c.compoundName.prefix(3))-\(100 + i)",
                        vialNumber: "#\(i + 1)", expirationDate: cal.date(byAdding: .month, value: 18, to: recon ?? today),
                        typicalDoseMcg: c.doseMcg, mcgUsed: vialMg * 1000, budDays: bud
                    ))
                }
                // Active (current) vial
                out.append(Vial(
                    compoundName: c.compoundName, vialSizeMg: vialMg,
                    diluentMl: c.reconstitutionVolume,
                    reconstitutedOn: cal.date(byAdding: .day, value: -7, to: today),
                    storage: .fridge, lotNumber: "LOT-\(c.compoundName.prefix(3))-\(100 + vialsNeeded)",
                    vialNumber: "#\(vialsNeeded)",
                    expirationDate: cal.date(byAdding: .month, value: 18, to: today),
                    typicalDoseMcg: c.doseMcg, mcgUsed: currentUsage, budDays: bud
                ))
            }
        }
        return out
    }

    // MARK: Bloodwork

    static func bloodworkPanels(scenario: DemoScenario) -> [BloodworkEntry] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        func d(_ daysAgo: Int) -> Date { cal.date(byAdding: .day, value: -daysAgo, to: today) ?? today }
        func panel(_ pairs: [(Biomarker, Double)], date: Date, notes: String = "") -> BloodworkEntry {
            var e = BloodworkEntry(date: date)
            e.results = pairs.map { BiomarkerResult(biomarker: $0.0, value: $0.1) }
            e.notes = notes
            return e
        }
        switch scenario {
        case .marcus:
            return [
                panel([
                    (.alt, 68), (.ast, 42), (.ldl, 162), (.hdl, 48), (.totalCholesterol, 232), (.triglycerides, 145),
                    (.testosteroneTotal, 612), (.igf1, 198), (.fastingGlucose, 92), (.a1c, 5.3),
                    (.tsh, 1.9), (.creatinine, 1.1), (.bun, 16)
                ], date: d(7), notes: "ALT up again. LDL creeping. Talk to provider before next stack."),
                panel([
                    (.alt, 52), (.ast, 38), (.ldl, 138), (.hdl, 51), (.totalCholesterol, 210), (.triglycerides, 132),
                    (.testosteroneTotal, 634), (.igf1, 210), (.fastingGlucose, 90), (.a1c, 5.2),
                    (.tsh, 1.8), (.creatinine, 1.0)
                ], date: d(70)),
                panel([
                    (.alt, 38), (.ast, 28), (.ldl, 118), (.hdl, 55), (.totalCholesterol, 188), (.triglycerides, 118),
                    (.testosteroneTotal, 648), (.igf1, 205), (.fastingGlucose, 88), (.a1c, 5.1),
                    (.tsh, 1.7), (.creatinine, 1.0)
                ], date: d(154))
            ]
        case .priya:
            // GLP-1-relevant: a1c, glucose, insulin, lipids, ALT (GLP-1 can elevate transiently)
            return [
                panel([
                    (.a1c, 5.4), (.fastingGlucose, 95), (.fastingInsulin, 8.2), (.ldl, 108), (.hdl, 58),
                    (.totalCholesterol, 184), (.triglycerides, 122), (.alt, 28), (.ast, 22), (.tsh, 2.1)
                ], date: d(14), notes: "Down from baseline — Tirzepatide working."),
                panel([
                    (.a1c, 6.1), (.fastingGlucose, 118), (.fastingInsulin, 14.5), (.ldl, 132), (.hdl, 48),
                    (.totalCholesterol, 218), (.triglycerides, 168), (.alt, 32), (.ast, 26), (.tsh, 2.0)
                ], date: d(98), notes: "Pre-medication baseline.")
            ]
        case .theo:
            // 3 panels — pre-injury → mid-rehab → recent recovery. Inflammation
            // (ALT/AST) recedes, creatinine normalizes as training load returns.
            return [
                panel([
                    (.alt, 34), (.ast, 28), (.ldl, 102), (.hdl, 56), (.totalCholesterol, 192), (.triglycerides, 102),
                    (.testosteroneTotal, 728), (.igf1, 282), (.creatinine, 1.1), (.bun, 17),
                    (.fastingGlucose, 88), (.a1c, 5.1)
                ], date: d(14), notes: "Recovery panel — tendons holding, training load returning."),
                panel([
                    (.alt, 41), (.ast, 33), (.ldl, 108), (.hdl, 52), (.totalCholesterol, 198), (.triglycerides, 110),
                    (.testosteroneTotal, 712), (.igf1, 268), (.creatinine, 1.2), (.bun, 18)
                ], date: d(90), notes: "Mid-rehab — BPC-157 + TB-500 stack working."),
                panel([
                    (.alt, 46), (.ast, 38), (.ldl, 114), (.hdl, 50), (.totalCholesterol, 204), (.triglycerides, 124),
                    (.testosteroneTotal, 684), (.igf1, 248), (.creatinine, 1.3), (.bun, 19)
                ], date: d(178), notes: "Pre-injury baseline — full conjugate volume.")
            ]
        case .ava:
            // Endurance: monitor thyroid, hormones, iron-related (closest = creatinine/HDL), and lipids.
            // 3 panels over ~6 months — base block adaptation arc:
            // HDL rising with mileage, TSH dipping (endurance load), T3/T4 stable,
            // free-T trending mildly low (REDS watch), lipids excellent throughout.
            return [
                panel([
                    (.hdl, 76), (.ldl, 84), (.totalCholesterol, 164), (.triglycerides, 72),
                    (.tsh, 1.4), (.t3, 3.0), (.t4, 1.2),
                    (.testosteroneFree, 7.6), (.fastingGlucose, 82), (.a1c, 4.9),
                    (.creatinine, 0.9), (.bun, 15)
                ], date: d(10), notes: "Mid-block — peak mileage week. HDL pushing higher, free-T watching."),
                panel([
                    (.hdl, 72), (.ldl, 88), (.totalCholesterol, 168), (.triglycerides, 78),
                    (.tsh, 1.6), (.t3, 3.1), (.t4, 1.2),
                    (.testosteroneFree, 8.2), (.fastingGlucose, 84), (.a1c, 5.0),
                    (.creatinine, 0.8), (.bun, 14)
                ], date: d(70), notes: "Base block check-in — adaptation underway."),
                panel([
                    (.hdl, 68), (.ldl, 92), (.totalCholesterol, 174), (.triglycerides, 88),
                    (.tsh, 1.8), (.t3, 3.2), (.t4, 1.3),
                    (.testosteroneFree, 9.1), (.fastingGlucose, 86), (.a1c, 5.0),
                    (.creatinine, 0.8), (.bun, 14)
                ], date: d(168), notes: "Pre-season baseline before marathon block.")
            ]
        case .maya:
            // 3 panels — baseline → 3 months in → recent. IGF-1 trends up modestly
            // with hypertrophy work, lipids improve, body composition shifting.
            return [
                panel([
                    (.igf1, 228), (.testosteroneFree, 9.4), (.tsh, 1.9), (.fastingGlucose, 86), (.a1c, 4.9),
                    (.ldl, 88), (.hdl, 66), (.totalCholesterol, 174), (.triglycerides, 82),
                    (.alt, 20), (.ast, 19), (.creatinine, 0.9), (.bun, 13)
                ], date: d(14), notes: "Recent panel — IGF-1 trending up with the hypertrophy block."),
                panel([
                    (.igf1, 212), (.testosteroneFree, 8.9), (.tsh, 2.0), (.fastingGlucose, 87), (.a1c, 5.0),
                    (.ldl, 92), (.hdl, 64), (.totalCholesterol, 178), (.triglycerides, 88),
                    (.alt, 21), (.ast, 19)
                ], date: d(96), notes: "Recomp check-in — three months in."),
                panel([
                    (.igf1, 198), (.testosteroneFree, 8.6), (.tsh, 2.0), (.fastingGlucose, 88), (.a1c, 5.0),
                    (.ldl, 96), (.hdl, 62), (.totalCholesterol, 180), (.triglycerides, 92),
                    (.alt, 22), (.ast, 20), (.creatinine, 0.9), (.bun, 13)
                ], date: d(184), notes: "Baseline panel — start of recomp tracking.")
            ]
        case .shayla:
            // 3 panels — pre-protocol → 6-week check → recent. Half-dose stack is
            // moving lipids favorably without taxing the liver.
            return [
                panel([
                    (.alt, 24), (.ast, 22), (.ldl, 104), (.hdl, 68), (.totalCholesterol, 188),
                    (.triglycerides, 86), (.testosteroneFree, 8.4), (.fastingGlucose, 84), (.a1c, 5.0),
                    (.tsh, 1.9), (.creatinine, 0.8), (.bun, 13)
                ], date: d(8), notes: "12-week check — half-dose stack working without liver stress."),
                panel([
                    (.alt, 28), (.ast, 23), (.ldl, 112), (.hdl, 64), (.totalCholesterol, 192),
                    (.triglycerides, 90), (.testosteroneFree, 8.0), (.fastingGlucose, 86), (.a1c, 5.0),
                    (.tsh, 2.0)
                ], date: d(54), notes: "6-week check — small ALT bump, monitoring."),
                panel([
                    (.alt, 32), (.ast, 24), (.ldl, 118), (.hdl, 62), (.totalCholesterol, 198),
                    (.triglycerides, 94), (.testosteroneFree, 7.8), (.fastingGlucose, 88), (.a1c, 5.1),
                    (.tsh, 2.1), (.creatinine, 0.8), (.bun, 14)
                ], date: d(112), notes: "Pre-protocol baseline — slightly elevated LDL.")
            ]
        }
    }

    static func bloodworkInterpretation(scenario: DemoScenario, panels: [BloodworkEntry]) -> BloodworkInterpretation? {
        switch scenario {
        case .marcus:
            return BloodworkInterpretation(
                headline: "ALT 38 → 52 → 68, LDL 118 → 138 → 162 across 3 panels",
                summary: "Hepatic and lipid markers are trending the wrong way. Two compounds in the current stack are the most likely contributors — worth a provider conversation before the next draw.",
                flags: [
                    BloodworkFlag(biomarker: "ALT", value: "68 U/L", status: "high", interpretation: "Above range and rising panel-over-panel.", protocolContext: "Common with oral 17α-alkylated compounds or sustained TRT load."),
                    BloodworkFlag(biomarker: "LDL", value: "162 mg/dL", status: "high", interpretation: "Up 44 mg/dL from baseline.", protocolContext: "Track lipid response to current TRT dose.")
                ],
                recheckRecommendationDays: 56,
                recheckReason: "Re-test in 8 weeks after omega-3 + fiber + provider review.",
                providerFlag: true,
                generatedAt: Date()
            )
        case .priya:
            return BloodworkInterpretation(
                headline: "A1C 6.1 → 5.4, glucose 118 → 95 since starting Tirzepatide",
                summary: "Metabolic markers responding well to medication. Mild ALT bump is within expected range; keep an eye on it.",
                flags: [],
                recheckRecommendationDays: 84,
                recheckReason: "Next routine check in 12 weeks.",
                providerFlag: false,
                generatedAt: Date()
            )
        default:
            return nil
        }
    }

    // MARK: Meals

    private struct MealRecipe: Sendable {
        let name: String
        let cal: Int
        let p: Double
        let c: Double
        let f: Double
        let mealTime: MealTime
    }

    private static func mealPool(for scenario: DemoScenario) -> (breakfast: [MealRecipe], lunch: [MealRecipe], dinner: [MealRecipe], snacks: [MealRecipe], cheats: [MealRecipe]) {
        switch scenario {
        case .maya:
            return (
                [MealRecipe(name: "Greek yogurt + berries", cal: 280, p: 22, c: 30, f: 7, mealTime: .breakfast),
                 MealRecipe(name: "3-egg omelet + spinach", cal: 320, p: 26, c: 4, f: 22, mealTime: .breakfast),
                 MealRecipe(name: "Oats + whey + banana", cal: 420, p: 32, c: 60, f: 8, mealTime: .breakfast)],
                [MealRecipe(name: "Chicken + rice bowl", cal: 540, p: 42, c: 65, f: 12, mealTime: .lunch),
                 MealRecipe(name: "Turkey wrap + greens", cal: 480, p: 38, c: 45, f: 14, mealTime: .lunch),
                 MealRecipe(name: "Salmon + sweet potato", cal: 560, p: 38, c: 50, f: 18, mealTime: .lunch)],
                [MealRecipe(name: "Ground beef + rice", cal: 620, p: 45, c: 70, f: 18, mealTime: .dinner),
                 MealRecipe(name: "Stir fry chicken + veg", cal: 520, p: 42, c: 55, f: 14, mealTime: .dinner)],
                [MealRecipe(name: "Protein shake", cal: 180, p: 30, c: 6, f: 3, mealTime: .snacks),
                 MealRecipe(name: "Cottage cheese + fruit", cal: 220, p: 24, c: 18, f: 5, mealTime: .snacks)],
                [MealRecipe(name: "Pizza night", cal: 920, p: 38, c: 90, f: 38, mealTime: .dinner)]
            )
        case .priya:
            return (
                [MealRecipe(name: "Egg whites + toast", cal: 240, p: 28, c: 22, f: 4, mealTime: .breakfast),
                 MealRecipe(name: "Greek yogurt + low-FODMAP granola", cal: 260, p: 24, c: 28, f: 6, mealTime: .breakfast),
                 MealRecipe(name: "Oatmeal + protein", cal: 280, p: 22, c: 38, f: 5, mealTime: .breakfast)],
                [MealRecipe(name: "Grilled chicken + white rice", cal: 380, p: 38, c: 50, f: 6, mealTime: .lunch),
                 MealRecipe(name: "Tuna + rice cakes", cal: 320, p: 32, c: 40, f: 4, mealTime: .lunch),
                 MealRecipe(name: "Cod + jasmine rice", cal: 360, p: 34, c: 45, f: 5, mealTime: .lunch)],
                [MealRecipe(name: "Shrimp + rice bowl", cal: 420, p: 36, c: 55, f: 8, mealTime: .dinner),
                 MealRecipe(name: "Chicken + roasted carrots", cal: 380, p: 38, c: 30, f: 10, mealTime: .dinner),
                 MealRecipe(name: "Low-FODMAP stir fry", cal: 400, p: 32, c: 48, f: 8, mealTime: .dinner)],
                [MealRecipe(name: "Rice cake + almond butter", cal: 180, p: 6, c: 22, f: 8, mealTime: .snacks),
                 MealRecipe(name: "Boiled egg + cucumber", cal: 90, p: 7, c: 4, f: 5, mealTime: .snacks)],
                [MealRecipe(name: "Restaurant burrito (off-plan)", cal: 880, p: 32, c: 95, f: 38, mealTime: .dinner)]
            )
        case .theo:
            return (
                [MealRecipe(name: "Oats + whey + banana", cal: 540, p: 42, c: 78, f: 8, mealTime: .breakfast),
                 MealRecipe(name: "4-egg scramble + bagel", cal: 620, p: 38, c: 60, f: 24, mealTime: .breakfast)],
                [MealRecipe(name: "Steak + sweet potato", cal: 720, p: 55, c: 75, f: 22, mealTime: .lunch),
                 MealRecipe(name: "Chicken thigh + pasta", cal: 780, p: 52, c: 90, f: 18, mealTime: .lunch)],
                [MealRecipe(name: "Ground beef chili + rice", cal: 820, p: 58, c: 85, f: 26, mealTime: .dinner),
                 MealRecipe(name: "Salmon + potatoes", cal: 740, p: 48, c: 65, f: 28, mealTime: .dinner)],
                [MealRecipe(name: "Pre-workout shake", cal: 260, p: 30, c: 30, f: 4, mealTime: .snacks),
                 MealRecipe(name: "Whey + oats", cal: 320, p: 28, c: 42, f: 6, mealTime: .snacks)],
                [MealRecipe(name: "Burger + fries (refeed)", cal: 1240, p: 52, c: 120, f: 56, mealTime: .dinner)]
            )
        case .marcus:
            return (
                [MealRecipe(name: "Salmon + greens + olive oil", cal: 520, p: 38, c: 14, f: 32, mealTime: .breakfast),
                 MealRecipe(name: "Egg + avocado + sourdough", cal: 480, p: 26, c: 38, f: 24, mealTime: .breakfast)],
                [MealRecipe(name: "Lentil + quinoa bowl", cal: 480, p: 24, c: 62, f: 14, mealTime: .lunch),
                 MealRecipe(name: "Tuna salad + olive oil", cal: 440, p: 38, c: 18, f: 26, mealTime: .lunch)],
                [MealRecipe(name: "Wild salmon + sweet potato", cal: 580, p: 42, c: 50, f: 22, mealTime: .dinner),
                 MealRecipe(name: "Grass-fed steak + veg", cal: 620, p: 48, c: 18, f: 38, mealTime: .dinner)],
                [MealRecipe(name: "Walnuts + apple", cal: 220, p: 6, c: 22, f: 14, mealTime: .snacks),
                 MealRecipe(name: "Greek yogurt + chia", cal: 200, p: 18, c: 14, f: 8, mealTime: .snacks)],
                [MealRecipe(name: "Date night pasta", cal: 880, p: 36, c: 110, f: 28, mealTime: .dinner)]
            )
        case .ava:
            return (
                [MealRecipe(name: "Oatmeal + peanut butter + banana", cal: 480, p: 18, c: 65, f: 18, mealTime: .breakfast),
                 MealRecipe(name: "Pancakes + maple syrup", cal: 520, p: 14, c: 88, f: 12, mealTime: .breakfast),
                 MealRecipe(name: "Toast + eggs + jam", cal: 420, p: 22, c: 50, f: 14, mealTime: .breakfast)],
                [MealRecipe(name: "Pasta + chicken + tomato", cal: 620, p: 38, c: 78, f: 14, mealTime: .lunch),
                 MealRecipe(name: "Rice + tofu + veggies", cal: 540, p: 24, c: 78, f: 12, mealTime: .lunch)],
                [MealRecipe(name: "Spaghetti bolognese", cal: 720, p: 36, c: 92, f: 22, mealTime: .dinner),
                 MealRecipe(name: "Sushi night", cal: 640, p: 32, c: 88, f: 14, mealTime: .dinner)],
                [MealRecipe(name: "Banana + honey + toast", cal: 320, p: 8, c: 62, f: 6, mealTime: .snacks),
                 MealRecipe(name: "Dates + almonds", cal: 240, p: 5, c: 40, f: 8, mealTime: .snacks)],
                [MealRecipe(name: "Long-run pizza", cal: 980, p: 38, c: 115, f: 38, mealTime: .dinner)]
            )
        case .shayla:
            return (
                [MealRecipe(name: "Greek yogurt + granola", cal: 320, p: 22, c: 38, f: 8, mealTime: .breakfast),
                 MealRecipe(name: "Protein pancakes", cal: 360, p: 28, c: 42, f: 8, mealTime: .breakfast)],
                [MealRecipe(name: "Grilled chicken salad", cal: 380, p: 36, c: 18, f: 18, mealTime: .lunch),
                 MealRecipe(name: "Turkey chili + rice", cal: 440, p: 34, c: 50, f: 10, mealTime: .lunch)],
                [MealRecipe(name: "Lean beef + veggies", cal: 480, p: 42, c: 28, f: 22, mealTime: .dinner),
                 MealRecipe(name: "Shrimp + zoodles", cal: 360, p: 38, c: 18, f: 14, mealTime: .dinner)],
                [MealRecipe(name: "Cottage cheese + berries", cal: 180, p: 22, c: 14, f: 3, mealTime: .snacks),
                 MealRecipe(name: "Rice cake + PB2", cal: 140, p: 6, c: 18, f: 3, mealTime: .snacks)],
                [MealRecipe(name: "Dinner out (refeed)", cal: 820, p: 42, c: 75, f: 32, mealTime: .dinner)]
            )
        }
    }

    private static func mealsForToday(scenario: DemoScenario) -> [LoggedMeal] {
        let pool = mealPool(for: scenario)
        let now = Date()
        let cal = Calendar.current
        func at(_ h: Int) -> Date { cal.date(bySettingHour: h, minute: 0, second: 0, of: now) ?? now }
        return [
            log(pool.breakfast[0], at: at(7)),
            log(pool.lunch[0], at: at(12)),
            log(pool.snacks[0], at: at(15))
        ]
    }

    private static func log(_ r: MealRecipe, at date: Date) -> LoggedMeal {
        let food = FoodItem(name: r.name, calories: r.cal, protein: r.p, carbs: r.c, fat: r.f)
        return LoggedMeal(food: food, mealTime: r.mealTime, timestamp: date)
    }

    static func mealsByDay(scenario: DemoScenario, days: Int) -> [Date: [LoggedMeal]] {
        let rand = seededRandom(seed(scenario, 7))
        let pool = mealPool(for: scenario)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var out: [Date: [LoggedMeal]] = [:]
        for d in 0..<days {
            guard let date = cal.date(byAdding: .day, value: -d, to: today) else { continue }
            let weekday = cal.component(.weekday, from: date)
            let isWeekend = weekday == 1 || weekday == 7

            let bf = pool.breakfast[Int(rand() * Double(pool.breakfast.count)) % pool.breakfast.count]
            let ln = pool.lunch[Int(rand() * Double(pool.lunch.count)) % pool.lunch.count]
            // Weekend ~25% chance of cheat-dinner
            let dn: MealRecipe = (isWeekend && rand() < 0.25)
                ? (pool.cheats.first ?? pool.dinner[0])
                : pool.dinner[Int(rand() * Double(pool.dinner.count)) % pool.dinner.count]

            var meals: [LoggedMeal] = [
                log(bf, at: cal.date(bySettingHour: 7, minute: 0, second: 0, of: date) ?? date),
                log(ln, at: cal.date(bySettingHour: 12, minute: 30, second: 0, of: date) ?? date),
                log(dn, at: cal.date(bySettingHour: 19, minute: 0, second: 0, of: date) ?? date)
            ]
            if rand() < 0.6, let snack = pool.snacks.randomElement() {
                meals.append(log(snack, at: cal.date(bySettingHour: 15, minute: 30, second: 0, of: date) ?? date))
            }
            out[date] = meals
        }
        return out
    }

    // MARK: Muscle snapshots — derived from workouts so they're per-persona naturally.

    static func muscleSnapshots(scenario: DemoScenario, workouts: [WorkoutHistoryDetail]) -> ([MuscleRecoveryItem], [WeeklyMuscleVolume]) {
        let now = Date()
        let cal = Calendar.current
        let weekStart = cal.date(byAdding: .day, value: -7, to: now) ?? now

        var lastWorked: [MuscleGroup: Date] = [:]
        var weeklySets: [MuscleGroup: Int] = [:]
        for entry in workouts {
            for exercise in entry.exercises {
                guard let ex = ExerciseLibrary.all.first(where: { $0.name == exercise.exerciseName }) else { continue }
                if let prev = lastWorked[ex.primaryMuscle] {
                    if entry.date > prev { lastWorked[ex.primaryMuscle] = entry.date }
                } else {
                    lastWorked[ex.primaryMuscle] = entry.date
                }
                if entry.date >= weekStart {
                    weeklySets[ex.primaryMuscle, default: 0] += exercise.sets.count
                }
            }
        }

        // Persona-specific tracked muscles
        let tracked: [MuscleGroup]
        switch scenario {
        case .maya, .shayla: tracked = [.chest, .back, .shoulders, .quadriceps, .hamstrings, .glutes, .biceps]
        case .priya: tracked = [.chest, .back, .quadriceps, .glutes, .core]
        case .theo, .marcus: tracked = [.chest, .back, .shoulders, .quadriceps, .hamstrings, .triceps, .biceps]
        case .ava: tracked = [.quadriceps, .hamstrings, .glutes, .calves, .core]
        }
        let targets: [MuscleGroup: Int] = [
            .chest: 16, .back: 18, .shoulders: 14, .quadriceps: 16,
            .hamstrings: 12, .biceps: 10, .triceps: 10, .glutes: 12,
            .calves: 8, .core: 8
        ]

        let recovery = tracked.map { m -> MuscleRecoveryItem in
            let last = lastWorked[m]
            let hoursSince = last.map { Int(now.timeIntervalSince($0) / 3600) } ?? 999
            let status: MuscleRecoveryStatus
            let hoursRemaining: Int
            if hoursSince >= 72 { status = .recovered; hoursRemaining = 0 }
            else if hoursSince >= 48 { status = .recovering; hoursRemaining = 72 - hoursSince }
            else { status = .fatigued; hoursRemaining = 48 - hoursSince }
            return MuscleRecoveryItem(muscle: m, status: status, lastWorked: last, hoursRemaining: hoursRemaining)
        }

        let volumes = tracked.map { m in
            WeeklyMuscleVolume(muscle: m, setsCompleted: weeklySets[m] ?? 0, targetSets: targets[m] ?? 12)
        }
        return (recovery, volumes)
    }

    // MARK: Sleep + HRV/RHR

    static func sleepBundle(scenario: DemoScenario, persona p: DemoPersona) -> ([ManualSleepLog], Double, Double?, Double?) {
        let rand = seededRandom(seed(scenario, 11))
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var logs: [ManualSleepLog] = []
        let baseSleep = p.avgSleepHours

        for i in 0..<90 {
            guard let night = cal.date(byAdding: .day, value: -i, to: today) else { continue }
            var hours = baseSleep + (rand() - 0.5) * 1.4
            // Persona-specific anomalies for storytelling
            if scenario == .maya && i == 0 { hours = 4.633 } // 4h 38m last night
            if scenario == .shayla { hours = 6.0 + (rand() - 0.5) * 1.0 } // ~6.2h avg
            hours = max(3.5, min(9.5, hours))
            let quality = Int(min(10, max(2, (hours - 4.0) * 1.8 + (rand() - 0.5) * 2)))
            logs.append(ManualSleepLog(night: night, hours: round(hours * 10) / 10, quality: quality))
        }

        // Today's snapshot
        let todaySleep: Double
        let todayHRV: Double?
        let todayRHR: Double?
        switch scenario {
        case .maya:
            todaySleep = 4.633
            todayHRV = 32  // -18% from a ~39 baseline
            todayRHR = 64
        case .ava:
            todaySleep = baseSleep
            todayHRV = 58
            // Baseline RHR ~48; elevated +8 for 5 mornings → 71. Crosses the
            // >70 threshold so `poorRecovery` fires reliably.
            todayRHR = 71
        case .priya:
            todaySleep = baseSleep
            todayHRV = 48
            todayRHR = 62
        case .marcus:
            todaySleep = baseSleep
            todayHRV = 52
            todayRHR = 58
        case .theo:
            todaySleep = baseSleep
            todayHRV = 46
            todayRHR = 56
        case .shayla:
            // Sleep stays in the healthy range so `roughSleep` doesn't crowd
            // out her hero story (borrowed protocol → safer dose).
            todaySleep = 7.4
            todayHRV = 52
            todayRHR = 58
        }
        return (logs, todaySleep, todayHRV, todayRHR)
    }

    static func stepsForToday(scenario: DemoScenario, persona p: DemoPersona) -> Int {
        // Scaled fraction of the daily average (mid-day-ish).
        let hour = Calendar.current.component(.hour, from: Date())
        let progress = min(1.0, max(0.1, Double(hour) / 22.0))
        return Int(Double(p.avgStepsPerDay) * progress)
    }

    // MARK: Activity logs (streak)

    static func activityLogs(scenario: DemoScenario, persona p: DemoPersona) -> [ActivityLog] {
        let cal = Calendar.current
        var logs: [ActivityLog] = []
        for i in 0..<max(1, p.currentStreak) {
            guard let date = cal.date(byAdding: .day, value: -i, to: Date()) else { continue }
            logs.append(ActivityLog(id: UUID(), date: date, type: i % 4 == 0 ? .pin : .workout))
        }
        return logs
    }
}

// MARK: - Coherence self-test

@MainActor
enum DemoCoherenceCheck {
    static func run(persona p: DemoPersona, bundle: DemoPersonaBundle) {
        var issues: [String] = []

        // 1. Protocol frequency vs dose log cadence
        for proto in bundle.protocols {
            for c in proto.compounds {
                let logs = proto.doseLog.filter { $0.compoundName == c.compoundName && !$0.wasSkipped }
                if logs.isEmpty {
                    issues.append("\(c.compoundName): no dose log entries")
                    continue
                }
                let perWeek = SupplyForecastService.dosesPerWeek(for: c.frequency)
                let span = max(1.0, Double(Calendar.current.dateComponents([.day], from: proto.startDate, to: Date()).day ?? 1))
                let actualPerWeek = Double(logs.count) / (span / 7.0)
                if perWeek > 0 && abs(actualPerWeek - perWeek) / perWeek > 0.35 {
                    issues.append("\(c.compoundName): freq says \(c.frequency) (~\(perWeek)/wk) but log shows \(String(format: "%.1f", actualPerWeek))/wk")
                }
            }
        }

        // 2. Active program present
        if bundle.activeProgram.days.isEmpty {
            issues.append("active program has no days")
        }

        // 3. Workout names map to program days
        let programDayNames = Set(bundle.activeProgram.days.map { $0.name })
        let workoutNames = Set(bundle.workouts.map { $0.name })
        if !workoutNames.isSubset(of: programDayNames) {
            let stray = workoutNames.subtracting(programDayNames)
            if !stray.isEmpty {
                issues.append("workouts with no matching program day: \(stray.prefix(3).joined(separator: ", "))")
            }
        }

        // 4. Bloodwork archetype check
        let panelCount = bundle.bloodwork.count
        if panelCount == 0 {
            issues.append("no bloodwork panels — every archetype should have at least one")
        }

        // 5. Sleep / HRV / RHR present
        if bundle.sleepLogs.isEmpty {
            issues.append("no sleep logs injected")
        }

        // 6. Brief generator produces non-empty body
        let lines = MorningBriefService.shared.buildLines()
        let body = MorningBriefService.shared.fallbackBody(from: lines)
        if body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("brief generator returned empty body")
        }

        // 7. Vials sane
        if !bundle.protocols.isEmpty && bundle.vials.isEmpty {
            issues.append("protocols present but no vials")
        }
        for v in bundle.vials where v.typicalDoseMcg > v.totalMcg {
            issues.append("vial \(v.compoundName) #\(v.vialNumber): dose > vial capacity")
        }

        // 8. Hero adaptive signal fires for this persona. Caught here so a
        // future data tweak doesn't silently break the screenshot story.
        let signals = AdaptiveSignalsService.shared.buildSignals(
            activeProtocol: bundle.protocols.first(where: { $0.isActive }) ?? bundle.protocols.first
        )
        let firedKinds = Set(signals.map { $0.kind })
        let expected: AdaptiveSignalsService.Signal.Kind?
        switch p.scenario {
        case .maya: expected = .roughSleep
        case .priya: expected = .sideEffect
        case .theo: expected = .missedDose
        case .marcus: expected = .bloodworkShift
        case .ava: expected = .poorRecovery
        case .shayla: expected = .borrowedProtocol
        }
        if let expected, !firedKinds.contains(expected) {
            issues.append("hero signal \(expected.rawValue) did not fire — fired: [\(firedKinds.map(\.rawValue).sorted().joined(separator: ", "))]")
        }

        if issues.isEmpty {
            print("[DemoMode] \(p.scenario.displayName) coherence ✅ — \(bundle.workouts.count) workouts, \(bundle.protocols.flatMap(\.doseLog).count) dose logs, \(bundle.sleepLogs.count) sleep nights, \(bundle.vials.count) vials, \(bundle.bloodwork.count) bw panels")
        } else {
            print("[DemoMode] \(p.scenario.displayName) coherence ⚠️ — \(issues.count) issue(s):")
            for i in issues { print("  • \(i)") }
        }
    }
}
