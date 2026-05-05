import SwiftUI
import Supabase
import Auth

@Observable
@MainActor
final class RoutineStore {
    static let shared = RoutineStore()

    var routines: [Routine] = []

    private static let storageKey = "savedRoutinesV1"
    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private init() {
        load()
        Task { await self.hydrateFromSupabase() }
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
        Task { await self.syncRoutine(routine) }
        return routine
    }

    func update(_ routine: Routine) {
        guard let idx = routines.firstIndex(where: { $0.id == routine.id }) else { return }
        var updated = routine
        updated.updatedAt = Date()
        routines[idx] = updated
        persist()
        Task { await self.syncRoutine(updated) }
    }

    func delete(_ id: UUID) {
        routines.removeAll { $0.id == id }
        persist()
        Task { await PersistenceSyncService.shared.deleteRoutine(id: id.uuidString.lowercased()) }
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
        let updated = routines[idx]
        Task { await self.syncRoutine(updated) }
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

    // MARK: - Supabase sync

    private func syncRoutine(_ routine: Routine) async {
        guard let session = try? await SupabaseService.shared.client.auth.session else { return }
        let exercisesData = (try? JSONEncoder().encode(routine.exercises)) ?? Data()
        let exercisesJSON = String(data: exercisesData, encoding: .utf8) ?? "[]"
        let row = RoutineRow(
            id: routine.id.uuidString.lowercased(),
            user_id: session.user.id.uuidString.lowercased(),
            name: routine.name,
            notes: routine.notes,
            exercises: exercisesJSON,
            times_performed: routine.timesPerformed,
            last_performed_at: routine.lastPerformedAt.map { Self.iso.string(from: $0) },
            created_at: Self.iso.string(from: routine.createdAt),
            updated_at: Self.iso.string(from: routine.updatedAt)
        )
        await PersistenceSyncService.shared.upsertRoutine(row)
    }

    func hydrateFromSupabase() async {
        let rows = await PersistenceSyncService.shared.fetchRoutines()
        guard !rows.isEmpty else {
            // First sync from a device with local data: push everything we have up.
            for r in routines {
                await syncRoutine(r)
            }
            return
        }
        var byId: [UUID: Routine] = [:]
        for r in routines { byId[r.id] = r }
        for row in rows {
            guard let id = UUID(uuidString: row.id) else { continue }
            let exData = row.exercises.data(using: .utf8) ?? Data()
            let parsedExercises = (try? JSONDecoder().decode([ProgramExercise].self, from: exData)) ?? []
            let routine = Routine(
                id: id,
                name: row.name,
                exercises: parsedExercises,
                notes: row.notes,
                createdAt: row.created_at.flatMap { Self.iso.date(from: $0) } ?? Date(),
                updatedAt: row.updated_at.flatMap { Self.iso.date(from: $0) } ?? Date(),
                lastPerformedAt: row.last_performed_at.flatMap { Self.iso.date(from: $0) },
                timesPerformed: row.times_performed
            )
            byId[id] = routine
        }
        routines = byId.values.sorted { a, b in
            let da = a.lastPerformedAt ?? a.updatedAt
            let db = b.lastPerformedAt ?? b.updatedAt
            return da > db
        }
        persist()
    }
}
