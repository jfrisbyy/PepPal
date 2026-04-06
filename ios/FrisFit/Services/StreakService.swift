import Foundation
import Supabase

nonisolated struct SupabaseActivityLog: Codable, Sendable {
    let id: String?
    let user_id: String
    let activity_date: String
    let activity_type: String
    let sport: String?
    let duration_minutes: Int?
    let notes: String?
    let created_at: String?
}

nonisolated struct CreateActivityLogPayload: Codable, Sendable {
    let user_id: String
    let activity_date: String
    let activity_type: String
    let sport: String?
    let duration_minutes: Int?
    let notes: String?
}

final class StreakService {
    static let shared = StreakService()

    private var supabase: SupabaseClient {
        SupabaseService.shared.client
    }

    private init() {}

    private let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    func fetchActivityLogs(userId: String, limit: Int = 365) async throws -> [SupabaseActivityLog] {
        let response: [SupabaseActivityLog] = try await supabase
            .from("activity_logs")
            .select()
            .eq("user_id", value: userId)
            .order("activity_date", ascending: false)
            .limit(limit)
            .execute()
            .value
        return response
    }

    func logActivity(userId: String, type: ActivityType, sport: Sport? = nil, durationMinutes: Int? = nil, notes: String? = nil) async throws -> SupabaseActivityLog {
        let payload = CreateActivityLogPayload(
            user_id: userId,
            activity_date: dateOnly.string(from: Date()),
            activity_type: type.rawValue,
            sport: sport?.rawValue,
            duration_minutes: durationMinutes,
            notes: notes
        )

        let created: SupabaseActivityLog = try await supabase
            .from("activity_logs")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
        return created
    }

    func deleteLog(logId: String) async throws {
        try await supabase
            .from("activity_logs")
            .delete()
            .eq("id", value: logId)
            .execute()
    }

    func toActivityLog(_ log: SupabaseActivityLog) -> ActivityLog {
        let date: Date
        if let d = dateOnly.date(from: log.activity_date) {
            date = d
        } else {
            date = Date()
        }
        let type = ActivityType(rawValue: log.activity_type) ?? .workout
        let sport = log.sport.flatMap { Sport(rawValue: $0) }

        return ActivityLog(
            id: UUID(uuidString: log.id ?? "") ?? UUID(),
            date: date,
            type: type,
            sport: sport
        )
    }
}
