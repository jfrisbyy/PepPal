import Foundation
import Supabase

nonisolated struct SupabaseWorkout: Codable, Sendable {
    let id: String?
    let user_id: String
    let name: String
    let type: String?
    let duration_minutes: Int?
    let calories_burned: Int?
    let notes: String?
    let completed_at: String?
    let created_at: String?
}

nonisolated struct CreateWorkoutPayload: Codable, Sendable {
    let user_id: String
    let name: String
    let type: String?
    let duration_minutes: Int?
    let calories_burned: Int?
    let notes: String?
    let completed_at: String
}

final class WorkoutService {
    static let shared = WorkoutService()

    private var supabase: SupabaseClient {
        SupabaseService.shared.client
    }

    private init() {}

    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    func fetchWorkouts(userId: String, limit: Int = 50) async throws -> [SupabaseWorkout] {
        let response: [SupabaseWorkout] = try await supabase
            .from("workouts")
            .select()
            .eq("user_id", value: userId)
            .order("completed_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return response
    }

    func createWorkout(userId: String, name: String, type: String?, durationMinutes: Int?, caloriesBurned: Int?, notes: String?) async throws -> SupabaseWorkout {
        let payload = CreateWorkoutPayload(
            user_id: userId,
            name: name,
            type: type,
            duration_minutes: durationMinutes,
            calories_burned: caloriesBurned,
            notes: notes,
            completed_at: iso8601.string(from: Date())
        )

        let created: SupabaseWorkout = try await supabase
            .from("workouts")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
        return created
    }

    func deleteWorkout(workoutId: String) async throws {
        try await supabase
            .from("workouts")
            .delete()
            .eq("id", value: workoutId)
            .execute()
    }

    func toWorkoutHistoryDetail(_ workout: SupabaseWorkout) -> WorkoutHistoryDetail {
        let date: Date
        if let dateStr = workout.completed_at {
            date = iso8601.date(from: dateStr) ?? Date()
        } else {
            date = Date()
        }
        let durationMinutes = workout.duration_minutes ?? 0
        let fpEarned = (durationMinutes * 5) + ((workout.calories_burned ?? 0) / 10)

        return WorkoutHistoryDetail(
            name: workout.name,
            date: date,
            durationMinutes: durationMinutes,
            totalVolume: 0,
            fpEarned: fpEarned,
            exercises: []
        )
    }
}
