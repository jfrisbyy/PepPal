import Foundation
import Supabase

nonisolated struct SupabaseManualSleepLog: Codable, Sendable {
    let id: String?
    let user_id: String?
    let night: String
    let bedtime: String?
    let wake_time: String?
    let hours: Double
    let quality: Int?
    let notes: String?
    let created_at: String?
    let updated_at: String?
}

nonisolated struct CreateManualSleepLogPayload: Codable, Sendable {
    let user_id: String
    let night: String
    let bedtime: String?
    let wake_time: String?
    let hours: Double
    let quality: Int?
    let notes: String?
}

nonisolated struct UpdateManualSleepLogPayload: Codable, Sendable {
    let bedtime: String?
    let wake_time: String?
    let hours: Double
    let quality: Int?
    let notes: String?
    let updated_at: String
}

final class ManualSleepLogService {
    static let shared = ManualSleepLogService()

    private var supabase: SupabaseClient { SupabaseService.shared.client }
    private init() {}

    private static let isoDateTime: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let nightFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func nightString(for date: Date) -> String {
        nightFormatter.string(from: date)
    }

    static func parseNight(_ s: String) -> Date? {
        nightFormatter.date(from: s)
    }

    static func parseDateTime(_ s: String?) -> Date? {
        guard let s else { return nil }
        return isoDateTime.date(from: s)
    }

    func upsert(userId: String, log: ManualSleepLog) async throws -> SupabaseManualSleepLog {
        let payload = CreateManualSleepLogPayload(
            user_id: userId,
            night: Self.nightString(for: log.night),
            bedtime: log.bedtime.map { Self.isoDateTime.string(from: $0) },
            wake_time: log.wakeTime.map { Self.isoDateTime.string(from: $0) },
            hours: log.hours,
            quality: log.quality,
            notes: (log.notes?.isEmpty == false) ? log.notes : nil
        )
        let result: SupabaseManualSleepLog = try await supabase
            .from("manual_sleep_logs")
            .upsert(payload, onConflict: "user_id,night")
            .select()
            .single()
            .execute()
            .value
        return result
    }

    func update(id: String, log: ManualSleepLog) async throws {
        let payload = UpdateManualSleepLogPayload(
            bedtime: log.bedtime.map { Self.isoDateTime.string(from: $0) },
            wake_time: log.wakeTime.map { Self.isoDateTime.string(from: $0) },
            hours: log.hours,
            quality: log.quality,
            notes: (log.notes?.isEmpty == false) ? log.notes : nil,
            updated_at: Self.isoDateTime.string(from: Date())
        )
        try await supabase.from("manual_sleep_logs")
            .update(payload)
            .eq("id", value: id)
            .execute()
    }

    func delete(id: String) async throws {
        try await supabase.from("manual_sleep_logs").delete().eq("id", value: id).execute()
    }

    func fetch(userId: String, days: Int = 30) async throws -> [SupabaseManualSleepLog] {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -days, to: cal.startOfDay(for: Date())) ?? Date()
        let rows: [SupabaseManualSleepLog] = try await supabase
            .from("manual_sleep_logs")
            .select()
            .eq("user_id", value: userId)
            .gte("night", value: Self.nightString(for: start))
            .order("night", ascending: false)
            .execute()
            .value
        return rows
    }
}
