import Foundation
import Supabase

nonisolated struct SupabaseChatMessage: Codable, Sendable {
    let id: String?
    let user_id: String?
    let role: String
    let content: String
    let created_at: String?
}

nonisolated struct SupabaseChatMessageInsert: Codable, Sendable {
    let user_id: String
    let role: String
    let content: String
}

final class ChatPersistenceService {
    static let shared = ChatPersistenceService()
    private init() {}

    private var supabase: SupabaseClient { SupabaseService.shared.client }

    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private let iso8601Basic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private func parse(_ s: String?) -> Date {
        guard let s else { return Date() }
        return iso8601.date(from: s) ?? iso8601Basic.date(from: s) ?? Date()
    }

    func fetchRecent(limit: Int = 40) async throws -> [PepMessage] {
        guard let session = try? await supabase.auth.session else { return [] }
        let userId = session.user.id.uuidString.lowercased()

        let rows: [SupabaseChatMessage] = try await supabase
            .from("chat_messages")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        return rows.reversed().map { row in
            let role: PepMessageRole = (row.role == "user") ? .user : .pep
            return PepMessage(role: role, content: row.content, timestamp: parse(row.created_at))
        }
    }

    func save(role: PepMessageRole, content: String) async {
        guard let session = try? await supabase.auth.session else { return }
        let userId = session.user.id.uuidString.lowercased()
        let payload = SupabaseChatMessageInsert(
            user_id: userId,
            role: role == .user ? "user" : "pep",
            content: content
        )
        _ = try? await supabase.from("chat_messages").insert(payload).execute()
    }

    func clearAll() async {
        guard let session = try? await supabase.auth.session else { return }
        let userId = session.user.id.uuidString.lowercased()
        _ = try? await supabase.from("chat_messages").delete().eq("user_id", value: userId).execute()
    }
}
