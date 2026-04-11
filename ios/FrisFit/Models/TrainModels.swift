import Foundation

nonisolated enum ProgramType: String, CaseIterable, Identifiable, Sendable, Codable {
    case recurringSplit = "Recurring Split"
    case timedProgram = "Timed Program"
    case flexible = "Flexible"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .recurringSplit: "arrow.triangle.2.circlepath"
        case .timedProgram: "calendar.badge.clock"
        case .flexible: "shuffle"
        }
    }

    var description: String {
        switch self {
        case .recurringSplit: "Repeat the same split each week"
        case .timedProgram: "Fixed duration with progression"
        case .flexible: "Choose workouts as you go"
        }
    }
}

nonisolated struct ProgramExercise: Identifiable, Sendable, Codable {
    let id: UUID
    let exerciseId: String
    let exerciseName: String
    let primaryMuscle: MuscleGroup
    let equipment: Equipment
    var targetSets: Int
    var targetRepsMin: Int
    var targetRepsMax: Int
    var restSeconds: Int

    init(exercise: Exercise, targetSets: Int = 3, targetRepsMin: Int = 8, targetRepsMax: Int = 12, restSeconds: Int = 90) {
        self.id = UUID()
        self.exerciseId = exercise.id
        self.exerciseName = exercise.name
        self.primaryMuscle = exercise.primaryMuscle
        self.equipment = exercise.equipment
        self.targetSets = targetSets
        self.targetRepsMin = targetRepsMin
        self.targetRepsMax = targetRepsMax
        self.restSeconds = exercise.defaultRestSeconds
    }
}

nonisolated struct ProgramDay: Identifiable, Sendable, Codable {
    let id: UUID
    var name: String
    var exercises: [ProgramExercise]

    init(name: String = "", exercises: [ProgramExercise] = []) {
        self.id = UUID()
        self.name = name
        self.exercises = exercises
    }
}

nonisolated struct TrainingProgram: Identifiable, Sendable, Codable {
    let id: UUID
    var name: String
    var type: ProgramType
    var daysPerWeek: Int
    var days: [ProgramDay]
    let createdAt: Date
    var isActive: Bool
    var currentWeek: Int

    init(name: String, type: ProgramType, daysPerWeek: Int, days: [ProgramDay], isActive: Bool = false) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.daysPerWeek = daysPerWeek
        self.days = days
        self.createdAt = Date()
        self.isActive = isActive
        self.currentWeek = 1
    }
}

nonisolated struct WorkoutTemplate: Identifiable, Sendable {
    let id: UUID
    let name: String
    let exerciseCount: Int
    let muscleGroups: [MuscleGroup]
    let estimatedMinutes: Int

    init(name: String, exerciseCount: Int, muscleGroups: [MuscleGroup], estimatedMinutes: Int) {
        self.id = UUID()
        self.name = name
        self.exerciseCount = exerciseCount
        self.muscleGroups = muscleGroups
        self.estimatedMinutes = estimatedMinutes
    }
}

nonisolated struct WorkoutHistoryEntry: Identifiable, Sendable {
    let id: UUID
    let name: String
    let date: Date
    let durationMinutes: Int
    let totalVolume: Int
    let fpEarned: Int

    init(name: String, date: Date, durationMinutes: Int, totalVolume: Int, fpEarned: Int) {
        self.id = UUID()
        self.name = name
        self.date = date
        self.durationMinutes = durationMinutes
        self.totalVolume = totalVolume
        self.fpEarned = fpEarned
    }
}

nonisolated struct CombinedHistoryItem: Identifiable, Sendable {
    let id: UUID
    let name: String
    let date: Date
    let durationMinutes: Int
    let fpEarned: Int
    let totalVolume: Int
    let sportSession: SportSession?
    let exercises: [WorkoutHistoryExerciseDetail]

    var isSportSession: Bool { sportSession != nil }
}

nonisolated enum MuscleRecoveryStatus: String, Sendable {
    case recovered = "Recovered"
    case recovering = "Recovering"
    case fatigued = "Fatigued"

    var icon: String {
        switch self {
        case .recovered: "checkmark.circle.fill"
        case .recovering: "clock.arrow.circlepath"
        case .fatigued: "exclamationmark.triangle.fill"
        }
    }
}

nonisolated struct MuscleRecoveryItem: Identifiable, Sendable {
    let id = UUID()
    let muscle: MuscleGroup
    let status: MuscleRecoveryStatus
    let lastWorked: Date?
    let hoursRemaining: Int
}

nonisolated struct TrainPersonalRecord: Identifiable, Sendable {
    let id = UUID()
    let exerciseName: String
    let weight: Double
    let reps: Int
    let dateAchieved: Date
    let isNew: Bool
    let previousBest: Double?
}

nonisolated struct WeeklyMuscleVolume: Identifiable, Sendable {
    let id = UUID()
    let muscle: MuscleGroup
    let setsCompleted: Int
    let targetSets: Int
}

nonisolated struct TrainingInsight: Identifiable, Sendable {
    let id = UUID()
    let totalSessions: Int
    let totalVolume: Int
    let avgDuration: Int
    let totalFP: Int
    let totalCaloriesBurned: Int
}

nonisolated struct WarmupExercise: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let icon: String
    let durationOrReps: String
    let type: WarmupType
}

nonisolated enum WarmupType: String, Sendable {
    case mobility = "Mobility"
    case activation = "Activation"
    case dynamic = "Dynamic"
}
