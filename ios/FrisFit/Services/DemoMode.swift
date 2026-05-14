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
        case .theo: return "Peptide stack · BPC-157"
        case .marcus: return "Health optimizer"
        case .ava: return "Endurance runner"
        case .shayla: return "Recomp · learning"
        }
    }

    var teaser: String {
        switch self {
        case .maya: return "4h 38m last night, HRV -18%, RHR +6. Leg day today — half-volume bundle ready."
        case .priya: return "Tirzepatide yesterday, GI discomfort logged 4h ago. Low-FODMAP plan armed for 48h."
        case .theo: return "BPC-157 missed Wednesday. Compound level dipped, Saturday pull flagged."
        case .marcus: return "ALT 38 → 52 → 68. LDL creeping. Two compounds flagged for review."
        case .ava: return "RHR +8 bpm for 5 mornings, sleep normal. Two-path prompt waiting."
        case .shayla: return "Borrowed Marcus's cut at 5mg. Your labs say start at 2.5mg, 2 weeks."
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
    let dailyBriefHeadline: String
    let dailyBriefBody: String
    let adaptiveBannerTitle: String
    let adaptiveBannerBody: String
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
            // Defer applying until next runloop tick so shared stores exist.
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
        // Wipe injected demo state so views fall back to real data.
        DemoDataInjector.clearAll()
        NotificationCenter.default.post(name: .demoPersonaChanged, object: nil)
    }

    private func applyData(for scenario: DemoScenario) {
        guard let persona = DemoPersonaLibrary.persona(for: scenario) else { return }
        DemoDataInjector.inject(persona: persona)
    }
}

extension Notification.Name {
    static let demoPersonaChanged = Notification.Name("demoPersonaChanged")
}

// MARK: - Data injector
// Pushes a persona's bundled data into the existing shared stores so
// every screen reads it transparently.

@MainActor
enum DemoDataInjector {
    static func inject(persona: DemoPersona) {
        let p = persona

        // 1) Profile / display name
        ProfileService.shared.cachedDisplayName = p.scenario.fullName

        // 2) Weight history — generate 180-day trend with daily noise.
        let weights = DemoDataGenerator.weightSeries(
            startLbs: p.weightStartLbs,
            endLbs: p.weightTodayLbs,
            days: 180
        )

        // 3) Workout history (90–120 sessions).
        let workouts = DemoDataGenerator.workoutHistory(scenario: p.scenario, days: 180)

        // 4) Personal records.
        let prs = DemoDataGenerator.personalRecords(scenario: p.scenario)

        // 5) Bloodwork.
        let bw = DemoDataGenerator.bloodwork(scenario: p.scenario)

        // 6) Protocol(s).
        let protocols = DemoDataGenerator.protocols(scenario: p.scenario)

        // 7) Macro target + today meals.
        let macros = MacroTarget(calories: p.macroCalories, protein: p.macroProtein, carbs: p.macroCarbs, fat: p.macroFat)
        let todayMeals = DemoDataGenerator.todayMeals(scenario: p.scenario)
        let muscleRecovery = DemoDataGenerator.muscleRecovery(scenario: p.scenario)
        let weeklyVolumes = DemoDataGenerator.weeklyVolumes(scenario: p.scenario)

        InsightsDataStore.shared.update(
            firstName: p.scenario.displayName,
            activeProtocols: protocols,
            workoutHistory: workouts,
            todayMeals: todayMeals,
            macroTarget: macros,
            weightEntries: weights,
            bodyMeasurements: [],
            startingWeight: p.weightStartLbs,
            targetWeight: p.weightTargetLbs,
            bloodwork: bw,
            muscleRecovery: muscleRecovery,
            weeklyVolumes: weeklyVolumes,
            personalRecords: prs,
            activeProgram: nil
        )

        // 8) Recent meals by day (150 days at 3–4 meals/day, but cap to ~30 for memory).
        let mealsByDay = DemoDataGenerator.mealsByDay(scenario: p.scenario, days: 30)
        for (date, meals) in mealsByDay {
            InsightsDataStore.shared.ingestDailyMeals(date: date, meals: meals)
            NutritionViewModel.shared.mealsByDay[NutritionViewModel.dayKey(for: date)] = meals
        }

        // 9) Streak — seed N days into the activity log.
        let logs = DemoDataGenerator.activityLogs(scenario: p.scenario)
        StreakManager.shared.activityLog = logs
        StreakManager.shared.recalculateStreak()
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
        StreakManager.shared.activityLog = []
        StreakManager.shared.recalculateStreak()
    }
}

// MARK: - Library

nonisolated enum DemoPersonaLibrary {
    static func persona(for scenario: DemoScenario) -> DemoPersona? {
        switch scenario {
        case .maya:
            return DemoPersona(
                scenario: .maya,
                bio: "Hypertrophy program · 3 yr training age · listening to recovery for the first time",
                heightCm: 168,
                currentStreak: 23,
                longestStreak: 58,
                weightStartLbs: 142,
                weightTodayLbs: 139.4,
                weightTargetLbs: 138,
                activeProgramName: "Upper/Lower Hypertrophy",
                archivedProgramName: "PPL 5-day",
                totalWorkouts: 112,
                followers: 184,
                following: 96,
                dailyBriefHeadline: "Last night cost you tonight",
                dailyBriefBody: "4h 38m of sleep with HRV down 18% means your leg day will cost more than it gives. Half-volume keeps the stimulus, cuts the damage.",
                adaptiveBannerTitle: "Something > nothing",
                adaptiveBannerBody: "Try 3×5 instead of 5×5 at the same intensity. Reflow the missed volume to next week.",
                goalType: "Recomp",
                macroCalories: 2100,
                macroProtein: 145,
                macroCarbs: 220,
                macroFat: 70,
                avgStepsPerDay: 8600,
                avgSleepHours: 7.1
            )
        case .priya:
            return DemoPersona(
                scenario: .priya,
                bio: "GLP-1 journey · 5.2mg Tirzepatide · learning what foods love me back",
                heightCm: 162,
                currentStreak: 41,
                longestStreak: 41,
                weightStartLbs: 198,
                weightTodayLbs: 174.8,
                weightTargetLbs: 158,
                activeProgramName: "Beginner Strength 3x",
                archivedProgramName: "Walking + Mobility",
                totalWorkouts: 47,
                followers: 312,
                following: 88,
                dailyBriefHeadline: "Yesterday's dose · today's plate",
                dailyBriefBody: "GI discomfort 4h ago means your gut is still settling. Low-FODMAP, lower-fat, higher-protein for the next 48h — your protein floor still stands.",
                adaptiveBannerTitle: "Low-FODMAP swaps loaded",
                adaptiveBannerBody: "We swapped tonight's burrito suggestion for a rice bowl. Your hydration target is up 12 oz.",
                goalType: "Weight Loss",
                macroCalories: 1500,
                macroProtein: 130,
                macroCarbs: 130,
                macroFat: 50,
                avgStepsPerDay: 9100,
                avgSleepHours: 7.4
            )
        case .theo:
            return DemoPersona(
                scenario: .theo,
                bio: "Powerlifter rebuild · tendon recovery stack · trying to come back smart",
                heightCm: 183,
                currentStreak: 14,
                longestStreak: 102,
                weightStartLbs: 198,
                weightTodayLbs: 201.2,
                weightTargetLbs: 205,
                activeProgramName: "5/3/1 BBB · Pull Focus",
                archivedProgramName: "Conjugate · 2024",
                totalWorkouts: 138,
                followers: 421,
                following: 134,
                dailyBriefHeadline: "Wednesday's dose is rippling through your week",
                dailyBriefBody: "BPC-157 missed on Wednesday. Compound level is below your usual baseline. Saturday's heavy pull session carries a soft warning — consider deload or push to Monday.",
                adaptiveBannerTitle: "Tissue support is low",
                adaptiveBannerBody: "Push the heavy pull to Monday. Next dose is shifted forward, not skipped.",
                goalType: "Recovery + Strength",
                macroCalories: 3000,
                macroProtein: 200,
                macroCarbs: 350,
                macroFat: 90,
                avgStepsPerDay: 7200,
                avgSleepHours: 7.6
            )
        case .marcus:
            return DemoPersona(
                scenario: .marcus,
                bio: "Health optimization · quarterly bloodwork · adjusting before the next draw",
                heightCm: 180,
                currentStreak: 89,
                longestStreak: 89,
                weightStartLbs: 192,
                weightTodayLbs: 188.6,
                weightTargetLbs: 190,
                activeProgramName: "Optimizer Split",
                archivedProgramName: "Pre-cycle Conditioning",
                totalWorkouts: 165,
                followers: 1840,
                following: 211,
                dailyBriefHeadline: "Your last 3 labs tell a story",
                dailyBriefBody: "ALT trended 38 → 52 → 68 and LDL 118 → 138 → 162 over your last three panels. Two compounds in your current stack are most associated with hepatic load.",
                adaptiveBannerTitle: "Adjust before the next draw",
                adaptiveBannerBody: "Omega-3 + fiber are now priority foods. Hydration goal bumped 16 oz. Pre-built provider conversation ready.",
                goalType: "Optimization",
                macroCalories: 2600,
                macroProtein: 180,
                macroCarbs: 250,
                macroFat: 90,
                avgStepsPerDay: 11400,
                avgSleepHours: 7.8
            )
        case .ava:
            return DemoPersona(
                scenario: .ava,
                bio: "Marathon block · base phase · listening to the data this cycle",
                heightCm: 170,
                currentStreak: 67,
                longestStreak: 142,
                weightStartLbs: 132,
                weightTodayLbs: 131.4,
                weightTargetLbs: 130,
                activeProgramName: "Marathon Base · Block 2",
                archivedProgramName: "Marathon Base · Block 1",
                totalWorkouts: 154,
                followers: 612,
                following: 188,
                dailyBriefHeadline: "Five mornings of the same signal",
                dailyBriefBody: "RHR is +8 bpm vs your 30-day baseline for 5 straight mornings, but sleep is normal. This pattern usually means one of two things — and the call is yours.",
                adaptiveBannerTitle: "Two paths · pick one",
                adaptiveBannerBody: "Feeling fine → 30% training deload this week. Feeling off → ipamorelin paused 5 days, hydration & sleep tasks bumped.",
                goalType: "Endurance",
                macroCalories: 2400,
                macroProtein: 120,
                macroCarbs: 330,
                macroFat: 80,
                avgStepsPerDay: 14200,
                avgSleepHours: 7.9
            )
        case .shayla:
            return DemoPersona(
                scenario: .shayla,
                bio: "Year 2 of training · learning to read my own data · curious not chasing",
                heightCm: 165,
                currentStreak: 31,
                longestStreak: 31,
                weightStartLbs: 154,
                weightTodayLbs: 149.8,
                weightTargetLbs: 145,
                activeProgramName: "Upper/Lower 4x",
                archivedProgramName: "Full body 3x",
                totalWorkouts: 72,
                followers: 224,
                following: 142,
                dailyBriefHeadline: "Marcus runs this at 5mg",
                dailyBriefBody: "You borrowed Marcus's cut protocol. Cross-checked against your labs (slightly elevated marker), sleep baseline (6.2h avg), and training load (high) — start at 2.5mg for 2 weeks.",
                adaptiveBannerTitle: "Your data is the filter",
                adaptiveBannerBody: "Recommended start 2.5mg · taper window 2 weeks · re-evaluate after next bloodwork.",
                goalType: "Cutting",
                macroCalories: 1800,
                macroProtein: 140,
                macroCarbs: 170,
                macroFat: 65,
                avgStepsPerDay: 9600,
                avgSleepHours: 6.4
            )
        }
    }
}

// MARK: - Data generator
// Deterministic procedural generation — same persona always produces the same series.

nonisolated enum DemoDataGenerator {
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

    static func weightSeries(startLbs: Double, endLbs: Double, days: Int) -> [WeightEntry] {
        let rand = seededRandom(Int(startLbs * 100) &+ Int(endLbs * 100))
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let delta = (endLbs - startLbs) / Double(days - 1)
        var out: [WeightEntry] = []
        out.reserveCapacity(days)
        for i in 0..<days {
            let dayOffset = -(days - 1 - i)
            guard let date = cal.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let noise = (rand() - 0.5) * 1.6
            let weight = startLbs + delta * Double(i) + noise
            out.append(WeightEntry(weight: round(weight * 10) / 10, date: date))
        }
        return out
    }

    static func workoutHistory(scenario: DemoScenario, days: Int) -> [WorkoutHistoryDetail] {
        let rand = seededRandom(seed(scenario, 1))
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var out: [WorkoutHistoryDetail] = []
        let names: [String]
        let exercisePool: [(String, Double, Int)]
        switch scenario {
        case .maya:
            names = ["Lower A", "Upper A", "Lower B", "Upper B"]
            exercisePool = [("Back Squat", 165, 5), ("RDL", 175, 6), ("Hip Thrust", 225, 8), ("Bench Press", 115, 6), ("Row", 125, 8), ("Overhead Press", 75, 6), ("Lat Pulldown", 110, 10), ("Leg Press", 290, 10)]
        case .priya:
            names = ["Full Body A", "Full Body B", "Walking + Core"]
            exercisePool = [("Goblet Squat", 35, 10), ("DB Row", 25, 10), ("Push-Up (Incline)", 0, 8), ("DB RDL", 40, 10), ("Plank", 0, 45), ("Hip Bridge", 0, 12)]
        case .theo:
            names = ["Bench Day", "Squat Day", "Deadlift Day", "OHP Day"]
            exercisePool = [("Bench Press", 275, 3), ("Squat", 365, 3), ("Deadlift", 425, 1), ("Overhead Press", 175, 3), ("Pendlay Row", 225, 5), ("Front Squat", 245, 5)]
        case .marcus:
            names = ["Push", "Pull", "Legs", "Conditioning"]
            exercisePool = [("Incline Bench", 185, 6), ("Weighted Pull-Up", 45, 6), ("Front Squat", 225, 5), ("RDL", 245, 6), ("Dip", 90, 8), ("Bike Intervals", 0, 30)]
        case .ava:
            names = ["Easy 6mi", "Tempo 4mi", "Long 14mi", "Intervals", "Strength Maint."]
            exercisePool = [("Easy Run", 0, 60), ("Tempo Run", 0, 38), ("Long Run", 0, 110), ("Single Leg DL", 95, 8), ("Plank Walkout", 0, 10)]
        case .shayla:
            names = ["Upper A", "Lower A", "Upper B", "Lower B"]
            exercisePool = [("Goblet Squat", 50, 8), ("DB Bench", 35, 10), ("Lat Pulldown", 90, 10), ("Hip Thrust", 165, 10), ("DB Curl", 20, 12), ("Tricep Pushdown", 60, 12)]
        }
        // Roughly 5 sessions/week → days * 5/7
        let targetCount = Int(Double(days) * 5.0 / 7.0)
        var dayOffset = 0
        while out.count < targetCount && dayOffset < days {
            guard let date = cal.date(byAdding: .day, value: -dayOffset, to: today) else { break }
            dayOffset += 1
            // Skip ~30% of days as rest
            if rand() < 0.28 { continue }
            let name = names[(dayOffset) % names.count]
            let numExercises = 4 + Int(rand() * 4)
            var exercises: [WorkoutHistoryExerciseDetail] = []
            var totalVolume = 0
            for _ in 0..<numExercises {
                let pick = exercisePool[Int(rand() * Double(exercisePool.count)) % exercisePool.count]
                let setCount = 3 + Int(rand() * 2)
                var sets: [WorkoutHistorySetDetail] = []
                for s in 1...setCount {
                    let w = max(0, pick.1 + (rand() - 0.5) * 10)
                    let r = max(1, pick.2 + Int((rand() - 0.5) * 4))
                    sets.append(WorkoutHistorySetDetail(setNumber: s, weight: round(w), reps: r))
                    totalVolume += Int(w) * r
                }
                exercises.append(WorkoutHistoryExerciseDetail(exerciseName: pick.0, sets: sets))
            }
            out.append(WorkoutHistoryDetail(
                name: name,
                date: date,
                durationMinutes: 45 + Int(rand() * 35),
                totalVolume: totalVolume,
                caloriesBurned: 220 + Int(rand() * 200),
                exercises: exercises
            ))
        }
        return out
    }

    static func personalRecords(scenario: DemoScenario) -> [TrainPersonalRecord] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        func d(_ daysAgo: Int) -> Date { cal.date(byAdding: .day, value: -daysAgo, to: today) ?? today }
        switch scenario {
        case .maya:
            return [
                TrainPersonalRecord(exerciseName: "Back Squat", weight: 185, reps: 5, dateAchieved: d(12), isNew: true, previousBest: 175),
                TrainPersonalRecord(exerciseName: "Hip Thrust", weight: 265, reps: 8, dateAchieved: d(28), isNew: false, previousBest: 245),
                TrainPersonalRecord(exerciseName: "RDL", weight: 195, reps: 6, dateAchieved: d(45), isNew: false, previousBest: 185),
                TrainPersonalRecord(exerciseName: "Bench Press", weight: 125, reps: 6, dateAchieved: d(64), isNew: false, previousBest: 120),
            ]
        case .priya:
            return [
                TrainPersonalRecord(exerciseName: "Goblet Squat", weight: 45, reps: 12, dateAchieved: d(8), isNew: true, previousBest: 35),
                TrainPersonalRecord(exerciseName: "DB Row", weight: 30, reps: 12, dateAchieved: d(22), isNew: false, previousBest: 25),
                TrainPersonalRecord(exerciseName: "Plank (sec)", weight: 75, reps: 1, dateAchieved: d(35), isNew: false, previousBest: 60),
            ]
        case .theo:
            return [
                TrainPersonalRecord(exerciseName: "Deadlift", weight: 485, reps: 1, dateAchieved: d(31), isNew: false, previousBest: 475),
                TrainPersonalRecord(exerciseName: "Back Squat", weight: 405, reps: 3, dateAchieved: d(48), isNew: false, previousBest: 395),
                TrainPersonalRecord(exerciseName: "Bench Press", weight: 305, reps: 3, dateAchieved: d(62), isNew: false, previousBest: 295),
                TrainPersonalRecord(exerciseName: "Overhead Press", weight: 195, reps: 3, dateAchieved: d(88), isNew: false, previousBest: 185),
            ]
        case .marcus:
            return [
                TrainPersonalRecord(exerciseName: "Weighted Pull-Up", weight: 70, reps: 5, dateAchieved: d(18), isNew: true, previousBest: 60),
                TrainPersonalRecord(exerciseName: "Incline Bench", weight: 205, reps: 6, dateAchieved: d(35), isNew: false, previousBest: 195),
                TrainPersonalRecord(exerciseName: "Front Squat", weight: 245, reps: 5, dateAchieved: d(52), isNew: false, previousBest: 235),
            ]
        case .ava:
            return [
                TrainPersonalRecord(exerciseName: "Half Marathon", weight: 1, reps: 1, dateAchieved: d(21), isNew: true, previousBest: nil),
                TrainPersonalRecord(exerciseName: "5K", weight: 1, reps: 1, dateAchieved: d(56), isNew: false, previousBest: nil),
                TrainPersonalRecord(exerciseName: "10K", weight: 1, reps: 1, dateAchieved: d(90), isNew: false, previousBest: nil),
            ]
        case .shayla:
            return [
                TrainPersonalRecord(exerciseName: "Hip Thrust", weight: 185, reps: 8, dateAchieved: d(14), isNew: true, previousBest: 165),
                TrainPersonalRecord(exerciseName: "Goblet Squat", weight: 60, reps: 8, dateAchieved: d(34), isNew: false, previousBest: 50),
                TrainPersonalRecord(exerciseName: "DB Bench", weight: 40, reps: 10, dateAchieved: d(55), isNew: false, previousBest: 35),
            ]
        }
    }

    static func bloodwork(scenario: DemoScenario) -> [BloodworkEntry] {
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
            // Three panels showing ALT and LDL trending up.
            return [
                panel([
                    (.alt, 68), (.ast, 42), (.ldl, 162), (.hdl, 48), (.totalCholesterol, 232), (.triglycerides, 145),
                    (.testosteroneTotal, 612), (.igf1, 198), (.fastingGlucose, 92), (.a1c, 5.3), (.tsh, 1.9), (.creatinine, 1.1)
                ], date: d(7), notes: "ALT up again. LDL creeping. Talk to provider before next stack."),
                panel([
                    (.alt, 52), (.ast, 38), (.ldl, 138), (.hdl, 51), (.totalCholesterol, 210), (.triglycerides, 132),
                    (.testosteroneTotal, 634), (.igf1, 210), (.fastingGlucose, 90), (.a1c, 5.2), (.tsh, 1.8), (.creatinine, 1.0)
                ], date: d(70)),
                panel([
                    (.alt, 38), (.ast, 28), (.ldl, 118), (.hdl, 55), (.totalCholesterol, 188), (.triglycerides, 118),
                    (.testosteroneTotal, 648), (.igf1, 205), (.fastingGlucose, 88), (.a1c, 5.1), (.tsh, 1.7), (.creatinine, 1.0)
                ], date: d(154)),
            ]
        case .shayla:
            return [
                panel([
                    (.alt, 32), (.ast, 24), (.ldl, 118), (.hdl, 62), (.totalCholesterol, 198), (.triglycerides, 94),
                    (.testosteroneFree, 7.8), (.fastingGlucose, 88), (.a1c, 5.1), (.tsh, 2.1)
                ], date: d(12)),
                panel([
                    (.alt, 28), (.ldl, 112), (.hdl, 64), (.fastingGlucose, 86), (.a1c, 5.0)
                ], date: d(95)),
            ]
        case .theo:
            return [
                panel([
                    (.alt, 41), (.ast, 33), (.ldl, 108), (.hdl, 52), (.testosteroneTotal, 712), (.igf1, 268), (.creatinine, 1.2)
                ], date: d(18)),
                panel([
                    (.alt, 38), (.ldl, 102), (.hdl, 54), (.testosteroneTotal, 698), (.igf1, 242)
                ], date: d(102)),
            ]
        default:
            return [
                panel([
                    (.alt, 24), (.ast, 22), (.ldl, 98), (.hdl, 58), (.fastingGlucose, 88), (.a1c, 5.0), (.tsh, 1.9)
                ], date: d(45)),
                panel([
                    (.alt, 22), (.ldl, 95), (.hdl, 60), (.fastingGlucose, 86), (.a1c, 5.0)
                ], date: d(140)),
            ]
        }
    }

    static func protocols(scenario: DemoScenario) -> [PeptideProtocol] {
        let cal = Calendar.current
        let today = Date()
        func dose(_ name: String, mcg: Double, daysAgo: Int, site: InjectionSite = .leftAbdomen, skipped: Bool = false, reason: String? = nil) -> DoseLogEntry {
            let ts = cal.date(byAdding: .day, value: -daysAgo, to: today) ?? today
            return DoseLogEntry(compoundName: name, doseMcg: mcg, timestamp: ts, injectionSite: site, wasSkipped: skipped, skipReason: reason)
        }
        let sites: [InjectionSite] = InjectionSite.allCases

        switch scenario {
        case .priya:
            let compound = ProtocolCompound(
                compoundName: "Tirzepatide",
                doseMcg: 5000,
                frequency: "Weekly",
                injectionRoute: .subcutaneous,
                reconstitutionVolume: 2.0,
                vialSizeMg: 10
            )
            var logs: [DoseLogEntry] = []
            for w in 0..<18 {
                let d = w * 7 + 1
                logs.append(dose("Tirzepatide", mcg: 5000, daysAgo: d, site: sites[w % sites.count]))
            }
            var proto = PeptideProtocol(
                name: "Tirzepatide Titration",
                goal: .weightLoss,
                compounds: [compound],
                startDate: cal.date(byAdding: .day, value: -126, to: today) ?? today,
                totalWeeks: 26,
                loadingWeeks: 4,
                maintenanceWeeks: 18,
                taperingWeeks: 4,
                offCycleWeeks: nil,
                isActive: true,
                doseLog: logs
            )
            proto.sideEffectLog = [SideEffectEntry(timestamp: cal.date(byAdding: .hour, value: -4, to: today) ?? today, effect: "GI discomfort", severity: 3, notes: "After dinner, 28h post-dose")]
            return [proto]
        case .theo:
            let bpc = ProtocolCompound(compoundName: "BPC-157", doseMcg: 250, frequency: "Daily", injectionRoute: .subcutaneous, reconstitutionVolume: 2.0, vialSizeMg: 5)
            let tb = ProtocolCompound(compoundName: "TB-500", doseMcg: 2500, frequency: "Twice weekly", injectionRoute: .subcutaneous, reconstitutionVolume: 2.0, vialSizeMg: 10)
            var logs: [DoseLogEntry] = []
            for d in 0..<90 {
                if d == 2 { // Wednesday miss
                    logs.append(dose("BPC-157", mcg: 250, daysAgo: d, skipped: true, reason: "Forgot — out of town"))
                    continue
                }
                logs.append(dose("BPC-157", mcg: 250, daysAgo: d, site: sites[d % sites.count]))
                if d % 3 == 0 {
                    logs.append(dose("TB-500", mcg: 2500, daysAgo: d, site: sites[(d + 1) % sites.count]))
                }
            }
            let proto = PeptideProtocol(
                name: "Tendon Recovery Stack",
                goal: .healing,
                compounds: [bpc, tb],
                startDate: cal.date(byAdding: .day, value: -120, to: today) ?? today,
                totalWeeks: 16,
                loadingWeeks: 2,
                maintenanceWeeks: 12,
                taperingWeeks: 2,
                offCycleWeeks: 4,
                isActive: true,
                doseLog: logs
            )
            return [proto]
        case .marcus:
            let test = ProtocolCompound(compoundName: "Test Cyp", doseMcg: 100000, frequency: "Weekly", injectionRoute: .intramuscular, reconstitutionVolume: 0, vialSizeMg: 200)
            let ipa = ProtocolCompound(compoundName: "Ipamorelin", doseMcg: 300, frequency: "Daily", injectionRoute: .subcutaneous, reconstitutionVolume: 2.0, vialSizeMg: 5)
            var logs: [DoseLogEntry] = []
            for d in 0..<120 {
                logs.append(dose("Ipamorelin", mcg: 300, daysAgo: d, site: sites[d % sites.count]))
                if d % 7 == 0 {
                    logs.append(dose("Test Cyp", mcg: 100000, daysAgo: d, site: sites[(d + 2) % sites.count]))
                }
            }
            let proto = PeptideProtocol(
                name: "Optimizer Stack",
                goal: .general,
                compounds: [test, ipa],
                startDate: cal.date(byAdding: .day, value: -160, to: today) ?? today,
                totalWeeks: nil,
                isActive: true,
                doseLog: logs
            )
            return [proto]
        case .maya:
            let ipa = ProtocolCompound(compoundName: "Ipamorelin", doseMcg: 300, frequency: "Daily", injectionRoute: .subcutaneous, reconstitutionVolume: 2.0, vialSizeMg: 5)
            var logs: [DoseLogEntry] = []
            for d in 0..<60 {
                logs.append(dose("Ipamorelin", mcg: 300, daysAgo: d, site: sites[d % sites.count]))
            }
            let proto = PeptideProtocol(
                name: "Recovery Support",
                goal: .muscleGrowth,
                compounds: [ipa],
                startDate: cal.date(byAdding: .day, value: -75, to: today) ?? today,
                totalWeeks: 12,
                isActive: true,
                doseLog: logs
            )
            return [proto]
        case .ava:
            let ipa = ProtocolCompound(compoundName: "Ipamorelin", doseMcg: 200, frequency: "Daily", injectionRoute: .subcutaneous, reconstitutionVolume: 2.0, vialSizeMg: 5)
            var logs: [DoseLogEntry] = []
            for d in 0..<90 {
                logs.append(dose("Ipamorelin", mcg: 200, daysAgo: d, site: sites[d % sites.count]))
            }
            let proto = PeptideProtocol(
                name: "Endurance Recovery",
                goal: .healing,
                compounds: [ipa],
                startDate: cal.date(byAdding: .day, value: -100, to: today) ?? today,
                totalWeeks: 16,
                isActive: true,
                doseLog: logs
            )
            return [proto]
        case .shayla:
            let comp = ProtocolCompound(compoundName: "Retatrutide", doseMcg: 2500, frequency: "Weekly", injectionRoute: .subcutaneous, reconstitutionVolume: 2.0, vialSizeMg: 10)
            var logs: [DoseLogEntry] = []
            for w in 0..<6 {
                logs.append(dose("Retatrutide", mcg: 2500, daysAgo: w * 7 + 2, site: sites[w % sites.count]))
            }
            let proto = PeptideProtocol(
                name: "Borrowed: Marcus's Cut (Adapted)",
                goal: .weightLoss,
                compounds: [comp],
                startDate: cal.date(byAdding: .day, value: -45, to: today) ?? today,
                totalWeeks: 14,
                isActive: true,
                doseLog: logs
            )
            return [proto]
        }
    }

    static func todayMeals(scenario: DemoScenario) -> [LoggedMeal] {
        func food(_ name: String, cal: Int, p: Double, c: Double, f: Double) -> FoodItem {
            FoodItem(name: name, calories: cal, protein: p, carbs: c, fat: f)
        }
        let now = Date()
        let cal = Calendar.current
        func at(_ h: Int) -> Date { cal.date(bySettingHour: h, minute: 0, second: 0, of: now) ?? now }
        switch scenario {
        case .maya:
            return [
                LoggedMeal(food: food("Greek yogurt + berries", cal: 280, p: 22, c: 30, f: 7), mealTime: .breakfast, timestamp: at(7)),
                LoggedMeal(food: food("Chicken + rice bowl", cal: 540, p: 42, c: 65, f: 12), mealTime: .lunch, timestamp: at(12)),
                LoggedMeal(food: food("Protein shake", cal: 180, p: 30, c: 6, f: 3), mealTime: .snacks, timestamp: at(15)),
            ]
        case .priya:
            return [
                LoggedMeal(food: food("Egg whites + toast", cal: 240, p: 28, c: 22, f: 4), mealTime: .breakfast, timestamp: at(8)),
                LoggedMeal(food: food("White rice + grilled chicken", cal: 420, p: 38, c: 55, f: 6), mealTime: .lunch, timestamp: at(13)),
            ]
        case .theo:
            return [
                LoggedMeal(food: food("Oats + whey + banana", cal: 540, p: 42, c: 78, f: 8), mealTime: .breakfast, timestamp: at(7)),
                LoggedMeal(food: food("Steak + sweet potato", cal: 720, p: 55, c: 75, f: 22), mealTime: .lunch, timestamp: at(12)),
                LoggedMeal(food: food("Pre-workout shake", cal: 260, p: 30, c: 30, f: 4), mealTime: .snacks, timestamp: at(16)),
            ]
        case .marcus:
            return [
                LoggedMeal(food: food("Salmon + greens + olive oil", cal: 520, p: 38, c: 14, f: 32), mealTime: .breakfast, timestamp: at(7)),
                LoggedMeal(food: food("Lentil + quinoa bowl", cal: 480, p: 24, c: 62, f: 14), mealTime: .lunch, timestamp: at(13)),
                LoggedMeal(food: food("Walnuts + apple", cal: 220, p: 6, c: 22, f: 14), mealTime: .snacks, timestamp: at(15)),
            ]
        case .ava:
            return [
                LoggedMeal(food: food("Oatmeal + peanut butter", cal: 480, p: 18, c: 65, f: 18), mealTime: .breakfast, timestamp: at(6)),
                LoggedMeal(food: food("Pasta + chicken + tomato", cal: 620, p: 38, c: 78, f: 14), mealTime: .lunch, timestamp: at(13)),
                LoggedMeal(food: food("Banana + honey + toast", cal: 320, p: 8, c: 62, f: 6), mealTime: .snacks, timestamp: at(16)),
            ]
        case .shayla:
            return [
                LoggedMeal(food: food("Greek yogurt + granola", cal: 320, p: 22, c: 38, f: 8), mealTime: .breakfast, timestamp: at(8)),
                LoggedMeal(food: food("Salad + grilled chicken", cal: 380, p: 36, c: 18, f: 18), mealTime: .lunch, timestamp: at(12)),
            ]
        }
    }

    static func mealsByDay(scenario: DemoScenario, days: Int) -> [Date: [LoggedMeal]] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var out: [Date: [LoggedMeal]] = [:]
        for d in 0..<days {
            guard let date = cal.date(byAdding: .day, value: -d, to: today) else { continue }
            // Reuse today template, vary calories ±10%
            let base = todayMeals(scenario: scenario)
            out[date] = base
        }
        return out
    }

    static func activityLogs(scenario: DemoScenario) -> [ActivityLog] {
        let persona = DemoPersonaLibrary.persona(for: scenario)
        let streak = persona?.currentStreak ?? 14
        let cal = Calendar.current
        var logs: [ActivityLog] = []
        for i in 0..<streak {
            guard let date = cal.date(byAdding: .day, value: -i, to: Date()) else { continue }
            logs.append(ActivityLog(id: UUID(), date: date, type: i % 4 == 0 ? .pin : .workout))
        }
        return logs
    }

    static func muscleRecovery(scenario: DemoScenario) -> [MuscleRecoveryItem] {
        let cal = Calendar.current
        func ago(_ h: Int) -> Date { cal.date(byAdding: .hour, value: -h, to: Date()) ?? Date() }
        return [
            MuscleRecoveryItem(muscle: .chest, status: .recovered, lastWorked: ago(72), hoursRemaining: 0),
            MuscleRecoveryItem(muscle: .back, status: .recovering, lastWorked: ago(36), hoursRemaining: 12),
            MuscleRecoveryItem(muscle: .quadriceps, status: scenario == .maya ? .fatigued : .recovered, lastWorked: ago(20), hoursRemaining: 28),
            MuscleRecoveryItem(muscle: .shoulders, status: .recovered, lastWorked: ago(96), hoursRemaining: 0),
            MuscleRecoveryItem(muscle: .biceps, status: .recovering, lastWorked: ago(48), hoursRemaining: 24),
        ]
    }

    static func weeklyVolumes(scenario: DemoScenario) -> [WeeklyMuscleVolume] {
        return [
            WeeklyMuscleVolume(muscle: .chest, setsCompleted: 14, targetSets: 16),
            WeeklyMuscleVolume(muscle: .back, setsCompleted: 18, targetSets: 18),
            WeeklyMuscleVolume(muscle: .quadriceps, setsCompleted: 16, targetSets: 20),
            WeeklyMuscleVolume(muscle: .shoulders, setsCompleted: 10, targetSets: 12),
            WeeklyMuscleVolume(muscle: .biceps, setsCompleted: 12, targetSets: 12),
        ]
    }
}
