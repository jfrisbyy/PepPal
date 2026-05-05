import SwiftUI

@Observable
final class RoutineStore {
    static let shared = RoutineStore()

    var routines: [Routine] = []

    private static let storageKey = "savedRoutinesV1"

    private init() {
        load()
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([Routine].self, from: data) else {
            return
        }
        routines = decoded.sorted { a, b in
            let da = a.lastPerformedAt ?? a.updatedAt
            let db = b.lastPerformedAt ?? b.updatedAt
            return da > db
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(routines) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    @discardableResult
    func add(_ routine: Routine) -> Routine {
        routines.insert(routine, at: 0)
        persist()
        return routine
    }

    func update(_ routine: Routine) {
        guard let idx = routines.firstIndex(where: { $0.id == routine.id }) else { return }
        var updated = routine
        updated.updatedAt = Date()
        routines[idx] = updated
        persist()
    }

    func delete(_ id: UUID) {
        routines.removeAll { $0.id == id }
        persist()
    }

    func duplicate(_ routine: Routine) {
        let copy = Routine(
            name: routine.name + " (Copy)",
            exercises: routine.exercises.map { pe in
                var np = pe
                return np
            },
            notes: routine.notes
        )
        add(copy)
    }

    func markPerformed(_ id: UUID) {
        guard let idx = routines.firstIndex(where: { $0.id == id }) else { return }
        routines[idx].lastPerformedAt = Date()
        routines[idx].timesPerformed += 1
        persist()
    }

    /// Build a routine from a list of completed workout exercises.
    static func routine(from name: String, exercises: [WorkoutExercise]) -> Routine {
        let programExercises: [ProgramExercise] = exercises.compactMap { we in
            let completed = we.sets.filter { $0.isCompleted }
            guard !completed.isEmpty else { return nil }
            let reps = completed.map { $0.effectiveReps }.filter { $0 > 0 }
            let minReps = reps.min() ?? 8
            let maxReps = reps.max() ?? 12
            var pe = ProgramExercise(
                exercise: we.exercise,
                targetSets: max(completed.count, 1),
                targetRepsMin: minReps,
                targetRepsMax: max(maxReps, minReps)
            )
            let topWeight = completed.map(\.effectiveWeight).max() ?? 0
            if topWeight > 0 { pe.prescribedWeight = topWeight }
            return pe
        }
        return Routine(name: name, exercises: programExercises)
    }
}
