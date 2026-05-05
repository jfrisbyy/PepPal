import Foundation
import Supabase

nonisolated struct SupabasePersonalRecord: Codable, Sendable {
    let id: String?
    let user_id: String
    let exercise_id: String
    let exercise_name: String
    let record_type: String
    let value: Double
    let reps: Int
    let logged_at: String
}

nonisolated struct SupabasePersonalRecordInsert: Codable, Sendable {
    let user_id: String
    let exercise_id: String
    let exercise_name: String
    let record_type: String
    let value: Double
    let reps: Int
    let logged_at: String
}

final class PersonalRecordService {
    static let shared = PersonalRecordService()
    private init() {}

    private var supabase: SupabaseClient { SupabaseService.shared.client }

    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    func persist(userId: String, hit: PRTracker.PRHit, reps: Int, at date: Date = Date()) async throws {
        let insert = SupabasePersonalRecordInsert(
            user_id: userId,
            exercise_id: hit.exerciseId,
            exercise_name: hit.exerciseName,
            record_type: hit.kind.rawValue,
            value: hit.newValue,
            reps: reps,
            logged_at: iso8601.string(from: date)
        )
        try await supabase
            .from("personal_records")
            .insert(insert)
            .execute()
    }

    func fetchAll(userId: String) async throws -> [SupabasePersonalRecord] {
        let rows: [SupabasePersonalRecord] = try await supabase
            .from("personal_records")
            .select()
            .eq("user_id", value: userId)
            .order("logged_at", ascending: false)
            .execute()
            .value
        return rows
    }
}
