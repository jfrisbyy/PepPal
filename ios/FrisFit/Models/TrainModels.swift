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
    var progressionScheme: ProgressionScheme?
    var progressionIncrement: Double?
    var progressionTargetRPE: Double?
    var prescribedWeight: Double?

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
        self.progressionScheme = nil
        self.progressionIncrement = nil
        self.progressionTargetRPE = nil
        self.prescribedWeight = nil
    }

    enum CodingKeys: String, CodingKey {
        case id, exerciseId, exerciseName, primaryMuscle, equipment
        case targetSets, targetRepsMin, targetRepsMax, restSeconds
        case progressionScheme, progressionIncrement, progressionTargetRPE, prescribedWeight
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.exerciseId = try c.decode(String.self, forKey: .exerciseId)
        self.exerciseName = try c.decode(String.self, forKey: .exerciseName)
        self.primaryMuscle = try c.decode(MuscleGroup.self, forKey: .primaryMuscle)
        self.equipment = try c.decode(Equipment.self, forKey: .equipment)
        self.targetSets = try c.decode(Int.self, forKey: .targetSets)
        self.targetRepsMin = try c.decode(Int.self, forKey: .targetRepsMin)
        self.targetRepsMax = try c.decode(Int.self, forKey: .targetRepsMax)
        self.restSeconds = try c.decode(Int.self, forKey: .restSeconds)
        self.progressionScheme = try c.decodeIfPresent(ProgressionScheme.self, forKey: .progressionScheme)
        self.progressionIncrement = try c.decodeIfPresent(Double.self, forKey: .progressionIncrement)
        self.progressionTargetRPE = try c.decodeIfPresent(Double.self, forKey: .progressionTargetRPE)
        self.prescribedWeight = try c.decodeIfPresent(Double.self, forKey: .prescribedWeight)
    }
}

nonisolated struct ProgramDay: Identifiable, Sendable, Codable {
    let id: UUID
    var name: String
    var exercises: [ProgramExercise]
    var scheduledWeekday: Int?
    var timeOfDay: ProgramTimeOfDay?

    init(name: String = "", exercises: [ProgramExercise] = [], scheduledWeekday: Int? = nil, timeOfDay: ProgramTimeOfDay? = nil) {
        self.id = UUID()
        self.name = name
        self.exercises = exercises
        self.scheduledWeekday = scheduledWeekday
        self.timeOfDay = timeOfDay
    }

    enum CodingKeys: String, CodingKey {
        case id, name, exercises, scheduledWeekday, timeOfDay
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.exercises = try c.decode([ProgramExercise].self, forKey: .exercises)
        self.scheduledWeekday = try c.decodeIfPresent(Int.self, forKey: .scheduledWeekday)
        self.timeOfDay = try c.decodeIfPresent(ProgramTimeOfDay.self, forKey: .timeOfDay)
    }
}

nonisolated enum ProgramTimeOfDay: String, CaseIterable, Sendable, Codable, Identifiable {
    case morning, afternoon, evening

    var id: String { rawValue }

    var label: String {
        switch self {
        case .morning: "Morning"
        case .afternoon: "Afternoon"
        case .evening: "Evening"
        }
    }

    var shortLabel: String {
        switch self {
        case .morning: "AM"
        case .afternoon: "PM"
        case .evening: "Eve"
        }
    }

    var icon: String {
        switch self {
        case .morning: "sunrise.fill"
        case .afternoon: "sun.max.fill"
        case .evening: "moon.stars.fill"
        }
    }

    var sortOrder: Int {
        switch self {
        case .morning: 0
        case .afternoon: 1
        case .evening: 2
        }
    }
}

nonisolated enum ProgramWeekday: Int, CaseIterable, Sendable, Codable, Identifiable {
    case monday = 0, tuesday, wednesday, thursday, friday, saturday, sunday

    var id: Int { rawValue }

    var shortLabel: String {
        switch self {
        case .monday: "Mon"
        case .tuesday: "Tue"
        case .wednesday: "Wed"
        case .thursday: "Thu"
        case .friday: "Fri"
        case .saturday: "Sat"
        case .sunday: "Sun"
        }
    }

    var singleLetter: String {
        switch self {
        case .monday: "M"
        case .tuesday: "T"
        case .wednesday: "W"
        case .thursday: "T"
        case .friday: "F"
        case .saturday: "S"
        case .sunday: "S"
        }
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

    init(name: String, date: Date, durationMinutes: Int, totalVolume: Int, fpEarned: Int = 0) {
        self.id = UUID()
        self.name = name
        self.date = date
        self.durationMinutes = durationMinutes
        self.totalVolume = totalVolume
        _ = fpEarned
    }
}

nonisolated struct CombinedHistoryItem: Identifiable, Sendable {
    let id: UUID
    let name: String
    let date: Date
    let durationMinutes: Int
    let totalVolume: Int
    let sportSession: SportSession?
    let exercises: [WorkoutHistoryExerciseDetail]

    init(id: UUID, name: String, date: Date, durationMinutes: Int, fpEarned: Int = 0, totalVolume: Int, sportSession: SportSession?, exercises: [WorkoutHistoryExerciseDetail]) {
        self.id = id
        self.name = name
        self.date = date
        self.durationMinutes = durationMinutes
        _ = fpEarned
        self.totalVolume = totalVolume
        self.sportSession = sportSession
        self.exercises = exercises
    }

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
    let totalCaloriesBurned: Int

    init(totalSessions: Int, totalVolume: Int, avgDuration: Int, totalFP: Int = 0, totalCaloriesBurned: Int) {
        self.totalSessions = totalSessions
        self.totalVolume = totalVolume
        self.avgDuration = avgDuration
        _ = totalFP
        self.totalCaloriesBurned = totalCaloriesBurned
    }
}

nonisolated struct WarmupExercise: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let icon: String
    let durationOrReps: String
    let type: WarmupType
}

nonisolated struct ProgressionNotice: Identifiable, Sendable {
    let id = UUID()
    let exerciseName: String
    let previousWeight: Double
    let nextWeight: Double
    let delta: Double
    let note: String
}

nonisolated enum WarmupType: String, Sendable {
    case mobility = "Mobility"
    case activation = "Activation"
    case dynamic = "Dynamic"
}
