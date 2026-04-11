import Foundation

nonisolated struct WorkoutSet: Identifiable, Sendable {
    let id: UUID
    var weight: Double
    var reps: Int
    var isCompleted: Bool
    let previousWeight: Double?
    let previousReps: Int?

    init(weight: Double = 0, reps: Int = 0, isCompleted: Bool = false, previousWeight: Double? = nil, previousReps: Int? = nil) {
        self.id = UUID()
        self.weight = weight
        self.reps = reps
        self.isCompleted = isCompleted
        self.previousWeight = previousWeight
        self.previousReps = previousReps
    }

    var effectiveWeight: Double {
        if weight > 0 { return weight }
        return previousWeight ?? 0
    }

    var effectiveReps: Int {
        if reps > 0 { return reps }
        return previousReps ?? 0
    }

    var volume: Double {
        effectiveWeight * Double(effectiveReps)
    }
}

nonisolated struct WorkoutExercise: Identifiable, Sendable {
    let id: UUID
    let exercise: Exercise
    var sets: [WorkoutSet]
    var isCompleted: Bool

    init(exercise: Exercise, targetSets: Int = 3, previousWeight: Double? = nil, previousReps: Int? = nil) {
        self.id = UUID()
        self.exercise = exercise
        self.sets = (0..<targetSets).map { _ in
            WorkoutSet(previousWeight: previousWeight, previousReps: previousReps)
        }
        self.isCompleted = false
    }

    var completedSets: Int {
        sets.filter(\.isCompleted).count
    }

    var totalVolume: Double {
        sets.filter(\.isCompleted).reduce(0) { $0 + $1.volume }
    }
}

nonisolated struct PersonalRecord: Identifiable, Sendable {
    let id: UUID
    let exerciseName: String
    let recordType: String
    let value: String

    init(exerciseName: String, recordType: String, value: String) {
        self.id = UUID()
        self.exerciseName = exerciseName
        self.recordType = recordType
        self.value = value
    }
}

nonisolated struct WorkoutSummary: Sendable {
    let workoutName: String
    let duration: TimeInterval
    let totalVolume: Double
    let totalSets: Int
    let caloriesBurned: Int
    let fpEarned: Int
    let personalRecords: [PersonalRecord]
}

nonisolated enum NumberInputField: Sendable {
    case weight(exerciseIndex: Int, setIndex: Int)
    case reps(exerciseIndex: Int, setIndex: Int)
}
