import Foundation

nonisolated enum ProgramTemplateSplit: String, CaseIterable, Identifiable, Sendable {
    case ppl = "Push / Pull / Legs"
    case upperLower = "Upper / Lower"
    case broSplit = "Bro Split"
    case fullBody = "Full Body 3x"
    case strength531 = "5/3/1"
    case gzclp = "GZCLP"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .ppl: "PPL"
        case .upperLower: "Upper / Lower"
        case .broSplit: "Bro Split"
        case .fullBody: "Full Body"
        case .strength531: "5/3/1"
        case .gzclp: "GZCLP"
        }
    }

    var icon: String {
        switch self {
        case .ppl: "arrow.triangle.2.circlepath"
        case .upperLower: "arrow.up.arrow.down"
        case .broSplit: "list.bullet.rectangle"
        case .fullBody: "figure.cross.training"
        case .strength531: "scalemass.fill"
        case .gzclp: "chart.line.uptrend.xyaxis"
        }
    }

    var daysPerWeek: Int {
        switch self {
        case .ppl: 6
        case .upperLower: 4
        case .broSplit: 5
        case .fullBody: 3
        case .strength531: 4
        case .gzclp: 3
        }
    }

    var subtitle: String {
        switch self {
        case .ppl: "6 days · High volume hypertrophy"
        case .upperLower: "4 days · Balanced strength & size"
        case .broSplit: "5 days · Classic bodybuilding"
        case .fullBody: "3 days · Efficient total body"
        case .strength531: "4 days · Periodized strength"
        case .gzclp: "3 days · Linear progression"
        }
    }

    var description: String {
        switch self {
        case .ppl: "Push/Pull/Legs twice per week. Each muscle hit 2x for maximum growth stimulus. Best for intermediate lifters with 6 days to train."
        case .upperLower: "Alternate upper and lower days. Great balance of frequency and recovery. Perfect for most lifters."
        case .broSplit: "Dedicate each day to a muscle group — chest, back, shoulders, arms, legs. High volume per muscle, once per week."
        case .fullBody: "Hit every major muscle group 3x per week. Maximum frequency with built-in recovery. Great for beginners and busy schedules."
        case .strength531: "Wendler's proven periodization. Focus on squat, bench, deadlift, OHP with calculated percentages and progression."
        case .gzclp: "GZCL linear progression for beginners. Tier system: heavy compounds, moderate accessories, high-rep isolation."
        }
    }

    var targetAudience: String {
        switch self {
        case .ppl: "Intermediate+"
        case .upperLower: "All Levels"
        case .broSplit: "Intermediate+"
        case .fullBody: "Beginner-Friendly"
        case .strength531: "Intermediate+"
        case .gzclp: "Beginner-Friendly"
        }
    }

    var focusTags: [String] {
        switch self {
        case .ppl: ["Hypertrophy", "Volume", "6 Days"]
        case .upperLower: ["Balanced", "Strength", "4 Days"]
        case .broSplit: ["Bodybuilding", "Volume", "5 Days"]
        case .fullBody: ["Efficiency", "Frequency", "3 Days"]
        case .strength531: ["Strength", "Periodized", "4 Days"]
        case .gzclp: ["Linear Progression", "Structure", "3 Days"]
        }
    }
}

enum ProgramTemplateFactory {
    static func buildProgram(for split: ProgramTemplateSplit) -> TrainingProgram {
        let days = buildDays(for: split)
        return TrainingProgram(
            name: split.shortName,
            type: .recurringSplit,
            daysPerWeek: split.daysPerWeek,
            days: days,
            isActive: true
        )
    }

    private static func buildDays(for split: ProgramTemplateSplit) -> [ProgramDay] {
        switch split {
        case .ppl: return pplDays()
        case .upperLower: return upperLowerDays()
        case .broSplit: return broSplitDays()
        case .fullBody: return fullBodyDays()
        case .strength531: return strength531Days()
        case .gzclp: return gzclpDays()
        }
    }

    private static func ex(_ id: String, sets: Int = 3, repsMin: Int = 8, repsMax: Int = 12) -> ProgramExercise? {
        guard let exercise = ExerciseLibrary.all.first(where: { $0.id == id }) else { return nil }
        return ProgramExercise(exercise: exercise, targetSets: sets, targetRepsMin: repsMin, targetRepsMax: repsMax)
    }

    private static func exByName(_ name: String, sets: Int = 3, repsMin: Int = 8, repsMax: Int = 12) -> ProgramExercise? {
        guard let exercise = ExerciseLibrary.all.first(where: { $0.name.lowercased() == name.lowercased() }) else { return nil }
        return ProgramExercise(exercise: exercise, targetSets: sets, targetRepsMin: repsMin, targetRepsMax: repsMax)
    }

    // MARK: - PPL

    private static func pplDays() -> [ProgramDay] {
        let push1 = ProgramDay(name: "Push A", exercises: [
            ex("barbell-bench-press", sets: 4, repsMin: 6, repsMax: 8),
            ex("incline-dumbbell-press", sets: 3, repsMin: 8, repsMax: 12),
            ex("cable-crossover", sets: 3, repsMin: 12, repsMax: 15),
            exByName("Overhead Press", sets: 3, repsMin: 8, repsMax: 10),
            exByName("Lateral Raises", sets: 3, repsMin: 12, repsMax: 15),
            exByName("Tricep Pushdowns", sets: 3, repsMin: 10, repsMax: 12),
        ].compactMap { $0 })

        let pull1 = ProgramDay(name: "Pull A", exercises: [
            exByName("Barbell Rows", sets: 4, repsMin: 6, repsMax: 8),
            exByName("Lat Pulldowns", sets: 3, repsMin: 8, repsMax: 12),
            exByName("Seated Cable Rows", sets: 3, repsMin: 10, repsMax: 12),
            exByName("Face Pulls", sets: 3, repsMin: 15, repsMax: 20),
            exByName("Barbell Curls", sets: 3, repsMin: 8, repsMax: 12),
            exByName("Hammer Curls", sets: 3, repsMin: 10, repsMax: 12),
        ].compactMap { $0 })

        let legs1 = ProgramDay(name: "Legs A", exercises: [
            exByName("Barbell Back Squat", sets: 4, repsMin: 6, repsMax: 8),
            exByName("Romanian Deadlift", sets: 3, repsMin: 8, repsMax: 10),
            exByName("Leg Press", sets: 3, repsMin: 10, repsMax: 12),
            exByName("Leg Curls", sets: 3, repsMin: 10, repsMax: 12),
            exByName("Calf Raises", sets: 4, repsMin: 12, repsMax: 15),
        ].compactMap { $0 })

        let push2 = ProgramDay(name: "Push B", exercises: [
            exByName("Overhead Press", sets: 4, repsMin: 6, repsMax: 8),
            ex("incline-barbell-press", sets: 3, repsMin: 8, repsMax: 10),
            ex("dumbbell-flyes", sets: 3, repsMin: 12, repsMax: 15),
            exByName("Lateral Raises", sets: 4, repsMin: 12, repsMax: 15),
            exByName("Overhead Tricep Extension", sets: 3, repsMin: 10, repsMax: 12),
        ].compactMap { $0 })

        let pull2 = ProgramDay(name: "Pull B", exercises: [
            exByName("Pull-Ups", sets: 4, repsMin: 6, repsMax: 10),
            exByName("Dumbbell Rows", sets: 3, repsMin: 8, repsMax: 12),
            exByName("Lat Pulldowns", sets: 3, repsMin: 10, repsMax: 12),
            exByName("Rear Delt Flyes", sets: 3, repsMin: 12, repsMax: 15),
            exByName("Incline Dumbbell Curls", sets: 3, repsMin: 10, repsMax: 12),
        ].compactMap { $0 })

        let legs2 = ProgramDay(name: "Legs B", exercises: [
            exByName("Deadlift", sets: 4, repsMin: 5, repsMax: 6),
            exByName("Bulgarian Split Squat", sets: 3, repsMin: 8, repsMax: 10),
            exByName("Leg Extensions", sets: 3, repsMin: 12, repsMax: 15),
            exByName("Leg Curls", sets: 3, repsMin: 10, repsMax: 12),
            exByName("Calf Raises", sets: 4, repsMin: 12, repsMax: 15),
        ].compactMap { $0 })

        return [push1, pull1, legs1, push2, pull2, legs2]
    }

    // MARK: - Upper/Lower

    private static func upperLowerDays() -> [ProgramDay] {
        let upper1 = ProgramDay(name: "Upper A — Strength", exercises: [
            ex("barbell-bench-press", sets: 4, repsMin: 5, repsMax: 6),
            exByName("Barbell Rows", sets: 4, repsMin: 5, repsMax: 6),
            exByName("Overhead Press", sets: 3, repsMin: 6, repsMax: 8),
            exByName("Lat Pulldowns", sets: 3, repsMin: 8, repsMax: 10),
            exByName("Lateral Raises", sets: 3, repsMin: 12, repsMax: 15),
            exByName("Barbell Curls", sets: 2, repsMin: 10, repsMax: 12),
            exByName("Tricep Pushdowns", sets: 2, repsMin: 10, repsMax: 12),
        ].compactMap { $0 })

        let lower1 = ProgramDay(name: "Lower A — Strength", exercises: [
            exByName("Barbell Back Squat", sets: 4, repsMin: 5, repsMax: 6),
            exByName("Romanian Deadlift", sets: 3, repsMin: 6, repsMax: 8),
            exByName("Leg Press", sets: 3, repsMin: 8, repsMax: 10),
            exByName("Leg Curls", sets: 3, repsMin: 10, repsMax: 12),
            exByName("Calf Raises", sets: 4, repsMin: 12, repsMax: 15),
        ].compactMap { $0 })

        let upper2 = ProgramDay(name: "Upper B — Hypertrophy", exercises: [
            ex("dumbbell-bench-press", sets: 3, repsMin: 10, repsMax: 12),
            exByName("Seated Cable Rows", sets: 3, repsMin: 10, repsMax: 12),
            ex("incline-dumbbell-press", sets: 3, repsMin: 10, repsMax: 12),
            exByName("Face Pulls", sets: 3, repsMin: 15, repsMax: 20),
            exByName("Lateral Raises", sets: 4, repsMin: 12, repsMax: 15),
            exByName("Hammer Curls", sets: 3, repsMin: 10, repsMax: 12),
            exByName("Overhead Tricep Extension", sets: 3, repsMin: 10, repsMax: 12),
        ].compactMap { $0 })

        let lower2 = ProgramDay(name: "Lower B — Hypertrophy", exercises: [
            exByName("Deadlift", sets: 3, repsMin: 6, repsMax: 8),
            exByName("Bulgarian Split Squat", sets: 3, repsMin: 10, repsMax: 12),
            exByName("Leg Extensions", sets: 3, repsMin: 12, repsMax: 15),
            exByName("Leg Curls", sets: 3, repsMin: 12, repsMax: 15),
            exByName("Hip Thrusts", sets: 3, repsMin: 10, repsMax: 12),
            exByName("Calf Raises", sets: 3, repsMin: 15, repsMax: 20),
        ].compactMap { $0 })

        return [upper1, lower1, upper2, lower2]
    }

    // MARK: - Bro Split

    private static func broSplitDays() -> [ProgramDay] {
        let chest = ProgramDay(name: "Chest", exercises: [
            ex("barbell-bench-press", sets: 4, repsMin: 6, repsMax: 8),
            ex("incline-dumbbell-press", sets: 3, repsMin: 8, repsMax: 12),
            ex("cable-crossover", sets: 3, repsMin: 12, repsMax: 15),
            ex("dumbbell-flyes", sets: 3, repsMin: 10, repsMax: 12),
            ex("machine-chest-press", sets: 3, repsMin: 10, repsMax: 12),
        ].compactMap { $0 })

        let back = ProgramDay(name: "Back", exercises: [
            exByName("Deadlift", sets: 4, repsMin: 5, repsMax: 6),
            exByName("Barbell Rows", sets: 4, repsMin: 6, repsMax: 8),
            exByName("Lat Pulldowns", sets: 3, repsMin: 8, repsMax: 12),
            exByName("Seated Cable Rows", sets: 3, repsMin: 10, repsMax: 12),
            exByName("Face Pulls", sets: 3, repsMin: 15, repsMax: 20),
        ].compactMap { $0 })

        let shoulders = ProgramDay(name: "Shoulders", exercises: [
            exByName("Overhead Press", sets: 4, repsMin: 6, repsMax: 8),
            exByName("Lateral Raises", sets: 4, repsMin: 12, repsMax: 15),
            exByName("Rear Delt Flyes", sets: 3, repsMin: 12, repsMax: 15),
            exByName("Face Pulls", sets: 3, repsMin: 15, repsMax: 20),
            exByName("Shrugs", sets: 3, repsMin: 10, repsMax: 12),
        ].compactMap { $0 })

        let arms = ProgramDay(name: "Arms", exercises: [
            exByName("Barbell Curls", sets: 3, repsMin: 8, repsMax: 10),
            exByName("Tricep Pushdowns", sets: 3, repsMin: 10, repsMax: 12),
            exByName("Hammer Curls", sets: 3, repsMin: 10, repsMax: 12),
            exByName("Overhead Tricep Extension", sets: 3, repsMin: 10, repsMax: 12),
            exByName("Incline Dumbbell Curls", sets: 3, repsMin: 10, repsMax: 12),
        ].compactMap { $0 })

        let legs = ProgramDay(name: "Legs", exercises: [
            exByName("Barbell Back Squat", sets: 4, repsMin: 6, repsMax: 8),
            exByName("Romanian Deadlift", sets: 3, repsMin: 8, repsMax: 10),
            exByName("Leg Press", sets: 3, repsMin: 10, repsMax: 12),
            exByName("Leg Extensions", sets: 3, repsMin: 12, repsMax: 15),
            exByName("Leg Curls", sets: 3, repsMin: 10, repsMax: 12),
            exByName("Calf Raises", sets: 4, repsMin: 12, repsMax: 15),
        ].compactMap { $0 })

        return [chest, back, shoulders, arms, legs]
    }

    // MARK: - Full Body 3x

    private static func fullBodyDays() -> [ProgramDay] {
        let dayA = ProgramDay(name: "Full Body A", exercises: [
            exByName("Barbell Back Squat", sets: 3, repsMin: 6, repsMax: 8),
            ex("barbell-bench-press", sets: 3, repsMin: 6, repsMax: 8),
            exByName("Barbell Rows", sets: 3, repsMin: 8, repsMax: 10),
            exByName("Lateral Raises", sets: 3, repsMin: 12, repsMax: 15),
            exByName("Barbell Curls", sets: 2, repsMin: 10, repsMax: 12),
            exByName("Calf Raises", sets: 3, repsMin: 12, repsMax: 15),
        ].compactMap { $0 })

        let dayB = ProgramDay(name: "Full Body B", exercises: [
            exByName("Deadlift", sets: 3, repsMin: 5, repsMax: 6),
            exByName("Overhead Press", sets: 3, repsMin: 6, repsMax: 8),
            exByName("Lat Pulldowns", sets: 3, repsMin: 8, repsMax: 12),
            exByName("Leg Curls", sets: 3, repsMin: 10, repsMax: 12),
            exByName("Tricep Pushdowns", sets: 2, repsMin: 10, repsMax: 12),
            exByName("Face Pulls", sets: 3, repsMin: 15, repsMax: 20),
        ].compactMap { $0 })

        let dayC = ProgramDay(name: "Full Body C", exercises: [
            exByName("Bulgarian Split Squat", sets: 3, repsMin: 8, repsMax: 10),
            ex("incline-dumbbell-press", sets: 3, repsMin: 8, repsMax: 12),
            exByName("Dumbbell Rows", sets: 3, repsMin: 8, repsMax: 12),
            exByName("Romanian Deadlift", sets: 3, repsMin: 8, repsMax: 10),
            exByName("Hammer Curls", sets: 2, repsMin: 10, repsMax: 12),
            exByName("Calf Raises", sets: 3, repsMin: 15, repsMax: 20),
        ].compactMap { $0 })

        return [dayA, dayB, dayC]
    }

    // MARK: - 5/3/1

    private static func strength531Days() -> [ProgramDay] {
        let squat = ProgramDay(name: "Squat Day", exercises: [
            exByName("Barbell Back Squat", sets: 3, repsMin: 3, repsMax: 5),
            exByName("Leg Press", sets: 5, repsMin: 10, repsMax: 15),
            exByName("Leg Curls", sets: 5, repsMin: 10, repsMax: 15),
            exByName("Calf Raises", sets: 3, repsMin: 15, repsMax: 20),
        ].compactMap { $0 })

        let bench = ProgramDay(name: "Bench Day", exercises: [
            ex("barbell-bench-press", sets: 3, repsMin: 3, repsMax: 5),
            ex("dumbbell-bench-press", sets: 5, repsMin: 10, repsMax: 15),
            exByName("Barbell Rows", sets: 5, repsMin: 10, repsMax: 15),
            exByName("Lateral Raises", sets: 3, repsMin: 12, repsMax: 15),
        ].compactMap { $0 })

        let deadlift = ProgramDay(name: "Deadlift Day", exercises: [
            exByName("Deadlift", sets: 3, repsMin: 3, repsMax: 5),
            exByName("Romanian Deadlift", sets: 5, repsMin: 10, repsMax: 15),
            exByName("Pull-Ups", sets: 5, repsMin: 6, repsMax: 10),
            exByName("Barbell Curls", sets: 3, repsMin: 10, repsMax: 12),
        ].compactMap { $0 })

        let ohp = ProgramDay(name: "OHP Day", exercises: [
            exByName("Overhead Press", sets: 3, repsMin: 3, repsMax: 5),
            ex("incline-barbell-press", sets: 5, repsMin: 10, repsMax: 15),
            exByName("Lat Pulldowns", sets: 5, repsMin: 10, repsMax: 15),
            exByName("Face Pulls", sets: 3, repsMin: 15, repsMax: 20),
        ].compactMap { $0 })

        return [squat, bench, deadlift, ohp]
    }

    // MARK: - GZCLP

    private static func gzclpDays() -> [ProgramDay] {
        let dayA = ProgramDay(name: "GZCLP A1", exercises: [
            exByName("Barbell Back Squat", sets: 5, repsMin: 3, repsMax: 3),
            ex("barbell-bench-press", sets: 3, repsMin: 10, repsMax: 10),
            exByName("Lat Pulldowns", sets: 3, repsMin: 15, repsMax: 15),
        ].compactMap { $0 })

        let dayB = ProgramDay(name: "GZCLP B1", exercises: [
            exByName("Overhead Press", sets: 5, repsMin: 3, repsMax: 3),
            exByName("Deadlift", sets: 3, repsMin: 10, repsMax: 10),
            exByName("Dumbbell Rows", sets: 3, repsMin: 15, repsMax: 15),
        ].compactMap { $0 })

        let dayC = ProgramDay(name: "GZCLP A2", exercises: [
            ex("barbell-bench-press", sets: 5, repsMin: 3, repsMax: 3),
            exByName("Barbell Back Squat", sets: 3, repsMin: 10, repsMax: 10),
            exByName("Lat Pulldowns", sets: 3, repsMin: 15, repsMax: 15),
        ].compactMap { $0 })

        return [dayA, dayB, dayC]
    }
}
