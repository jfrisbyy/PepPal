import Foundation
import Supabase

nonisolated struct SupabaseWaterEntry: Codable, Sendable {
    let id: String?
    let user_id: String?
    let amount_ml: Int
    let logged_at: String?
    let created_at: String?
}

nonisolated struct CreateWaterEntryPayload: Codable, Sendable {
    let user_id: String
    let amount_ml: Int
    let logged_at: String
}

final class WaterService {
    static let shared = WaterService()

    private var supabase: SupabaseClient { SupabaseService.shared.client }

    private init() {}

    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    func insert(userId: String, amountMl: Int, loggedAt: Date = Date()) async throws -> SupabaseWaterEntry {
        let payload = CreateWaterEntryPayload(
            user_id: userId,
            amount_ml: amountMl,
            logged_at: iso8601.string(from: loggedAt)
        )
        let created: SupabaseWaterEntry = try await supabase
            .from("water_entries")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
        return created
    }

    func delete(id: String) async throws {
        try await supabase.from("water_entries").delete().eq("id", value: id).execute()
    }

    func update(id: String, amountMl: Int, loggedAt: Date) async throws {
        struct UpdatePayload: Codable, Sendable {
            let amount_ml: Int
            let logged_at: String
        }
        let payload = UpdatePayload(amount_ml: amountMl, logged_at: iso8601.string(from: loggedAt))
        try await supabase.from("water_entries").update(payload).eq("id", value: id).execute()
    }

    func fetch(userId: String, date: Date) async throws -> [SupabaseWaterEntry] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }
        let fetchStart = cal.date(byAdding: .hour, value: -24, to: start) ?? start
        let fetchEnd = cal.date(byAdding: .hour, value: 24, to: end) ?? end
        let items: [SupabaseWaterEntry] = try await supabase
            .from("water_entries")
            .select()
            .eq("user_id", value: userId)
            .gte("logged_at", value: iso8601.string(from: fetchStart))
            .lt("logged_at", value: iso8601.string(from: fetchEnd))
            .order("logged_at", ascending: true)
            .execute()
            .value
        return items.filter {
            guard let s = $0.logged_at, let d = iso8601.date(from: s) else { return true }
            return d >= start && d < end
        }
    }

    nonisolated func insertPayload(userId: String, amountMl: Int, loggedAt: Date, clientMutationId: String = UUID().uuidString) -> [String: JSONPrimitive] {
        return [
            "user_id": .string(userId),
            "amount_ml": .int(amountMl),
            "logged_at": .string(iso8601.string(from: loggedAt)),
            "client_mutation_id": .string(clientMutationId)
        ]
    }
}
