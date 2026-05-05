import Foundation
import Supabase

nonisolated struct SupabaseBlock: Codable, Sendable {
    let id: String?
    let blocker_id: String
    let blocked_id: String
    let created_at: String?
}

nonisolated struct CreateBlockPayload: Codable, Sendable {
    let blocker_id: String
    let blocked_id: String
}

nonisolated struct SupabaseReport: Codable, Sendable {
    let id: String?
    let reporter_id: String
    let target_type: String
    let target_id: String
    let reason: String
    let details: String?
    let created_at: String?
}

nonisolated struct CreateReportPayload: Codable, Sendable {
    let reporter_id: String
    let target_type: String
    let target_id: String
    let reason: String
    let details: String?
}

final class ModerationService {
    static let shared = ModerationService()
    private init() {}

    private var supabase: SupabaseClient { SupabaseService.shared.client }

    func block(blockerId: String, blockedId: String) async throws {
        let payload = CreateBlockPayload(blocker_id: blockerId, blocked_id: blockedId)
        try await supabase.from("user_blocks").insert(payload).execute()
    }

    func unblock(blockerId: String, blockedId: String) async throws {
        try await supabase.from("user_blocks")
            .delete()
            .eq("blocker_id", value: blockerId)
            .eq("blocked_id", value: blockedId)
            .execute()
    }

    func isBlocked(blockerId: String, blockedId: String) async throws -> Bool {
        let rows: [SupabaseBlock] = try await supabase.from("user_blocks")
            .select("id")
            .eq("blocker_id", value: blockerId)
            .eq("blocked_id", value: blockedId)
            .execute()
            .value
        return !rows.isEmpty
    }

    func blockedUserIds(blockerId: String) async throws -> Set<String> {
        let rows: [SupabaseBlock] = try await supabase.from("user_blocks")
            .select("blocked_id, blocker_id")
            .eq("blocker_id", value: blockerId)
            .execute()
            .value
        return Set(rows.map { $0.blocked_id })
    }

    func report(reporterId: String, targetType: String, targetId: String, reason: String, details: String?) async throws {
        let payload = CreateReportPayload(
            reporter_id: reporterId,
            target_type: targetType,
            target_id: targetId,
            reason: reason,
            details: details
        )
        try await supabase.from("content_reports").insert(payload).execute()
    }
}

nonisolated enum ReportReason: String, CaseIterable, Sendable, Identifiable {
    case spam = "Spam or misleading"
    case harassment = "Harassment or bullying"
    case hate = "Hate speech"
    case violence = "Violence or threats"
    case sexual = "Sexual content"
    case selfHarm = "Self-harm"
    case misinformation = "Medical misinformation"
    case illegal = "Illegal activity"
    case other = "Other"

    var id: String { rawValue }
}
