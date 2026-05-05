import Foundation

nonisolated struct Routine: Identifiable, Sendable, Codable, Hashable {
    static func == (lhs: Routine, rhs: Routine) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    let id: UUID
    var name: String
    var exercises: [ProgramExercise]
    var notes: String
    let createdAt: Date
    var updatedAt: Date
    var lastPerformedAt: Date?
    var timesPerformed: Int

    init(
        id: UUID = UUID(),
        name: String,
        exercises: [ProgramExercise] = [],
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastPerformedAt: Date? = nil,
        timesPerformed: Int = 0
    ) {
        self.id = id
        self.name = name
        self.exercises = exercises
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastPerformedAt = lastPerformedAt
        self.timesPerformed = timesPerformed
    }

    var muscleGroups: [MuscleGroup] {
        var seen: Set<MuscleGroup> = []
        var ordered: [MuscleGroup] = []
        for ex in exercises where !seen.contains(ex.primaryMuscle) {
            seen.insert(ex.primaryMuscle)
            ordered.append(ex.primaryMuscle)
        }
        return ordered
    }

    var estimatedMinutes: Int {
        let totalSets = exercises.reduce(0) { $0 + $1.targetSets }
        let restSec = exercises.reduce(0) { $0 + ($1.restSeconds * max($1.targetSets - 1, 0)) }
        let working = totalSets * 45
        return max(10, (working + restSec) / 60)
    }
}
