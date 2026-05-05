import Foundation
import Supabase
import SwiftUI

nonisolated struct SupabaseGroup: Codable, Sendable {
    let id: String?
    let creator_id: String
    let name: String
    let description: String?
    let privacy: String?
    let accent_color_hex: String?
    let icon_name: String?
    let stats_config: AnyCodable?
    let created_at: String?
    let updated_at: String?
}

nonisolated struct CreateGroupPayload: Codable, Sendable {
    let creator_id: String
    let name: String
    let description: String
    let privacy: String
    let accent_color_hex: String
    let icon_name: String
}

nonisolated struct SupabaseGroupMember: Codable, Sendable {
    let group_id: String
    let user_id: String
    let role: String?
    let joined_at: String?
    let is_sharing_stats: Bool?
}

nonisolated struct SupabaseGroupMemberWithProfile: Codable, Sendable {
    let group_id: String
    let user_id: String
    let role: String?
    let joined_at: String?
    let is_sharing_stats: Bool?
    let profiles: SupabasePostAuthor?
}

nonisolated struct CreateGroupMemberPayload: Codable, Sendable {
    let group_id: String
    let user_id: String
    let role: String
}

nonisolated struct SupabaseGroupMessage: Codable, Sendable {
    let id: String?
    let group_id: String
    let sender_id: String
    let text_content: String
    let attachments: [DirectMessageAttachment]?
    let like_count: Int?
    let created_at: String?
}

nonisolated struct SupabaseGroupMessageWithProfile: Codable, Sendable {
    let id: String
    let group_id: String
    let sender_id: String
    let text_content: String
    let attachments: [DirectMessageAttachment]?
    let like_count: Int?
    let created_at: String?
    let profiles: SupabasePostAuthor?
}

nonisolated struct CreateGroupMessagePayload: Codable, Sendable {
    let group_id: String
    let sender_id: String
    let text_content: String
    let attachments: [DirectMessageAttachment]?
}

final class GroupsService: @unchecked Sendable {
    static let shared = GroupsService()

    private var supabase: SupabaseClient { SupabaseService.shared.client }
    private init() {}

    private let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - Fetch

    func fetchMyGroups(userId: String) async throws -> [FitGroup] {
        let memberships: [SupabaseGroupMember] = try await supabase
            .from("group_members")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        let groupIds = memberships.map { $0.group_id }
        guard !groupIds.isEmpty else { return [] }

        let groups: [SupabaseGroup] = try await supabase
            .from("groups")
            .select()
            .in("id", values: groupIds)
            .order("updated_at", ascending: false)
            .execute()
            .value

        var results: [FitGroup] = []
        for g in groups {
            guard let gid = g.id else { continue }
            let members = (try? await fetchMembers(groupId: gid)) ?? []
            let messages = (try? await fetchMessages(groupId: gid)) ?? []
            results.append(toFitGroup(g, members: members, messages: messages))
        }
        return results
    }

    func fetchPublicGroups(userId: String, excludingMyIds: Set<String>, limit: Int = 30) async throws -> [FitGroup] {
        let groups: [SupabaseGroup] = try await supabase
            .from("groups")
            .select()
            .eq("privacy", value: "Public")
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        let visible = groups.filter { g in !(g.id.map { excludingMyIds.contains($0) } ?? true) }
        var results: [FitGroup] = []
        for g in visible {
            guard let gid = g.id else { continue }
            let members = (try? await fetchMembers(groupId: gid)) ?? []
            results.append(toFitGroup(g, members: members, messages: []))
        }
        return results
    }

    func fetchMembers(groupId: String) async throws -> [SupabaseGroupMemberWithProfile] {
        let res: [SupabaseGroupMemberWithProfile] = try await supabase
            .from("group_members")
            .select("*, profiles!group_members_user_id_fkey(id, display_name, username, avatar_url, avatar_color, active_program, total_fp, current_streak)")
            .eq("group_id", value: groupId)
            .execute()
            .value
        return res
    }

    func fetchMessages(groupId: String, limit: Int = 50) async throws -> [SupabaseGroupMessageWithProfile] {
        let res: [SupabaseGroupMessageWithProfile] = try await supabase
            .from("group_messages")
            .select("*, profiles!group_messages_sender_id_fkey(id, display_name, username, avatar_url, avatar_color, active_program, total_fp, current_streak)")
            .eq("group_id", value: groupId)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return res.reversed() // chronological order
    }

    // MARK: - Create / Modify

    func createGroup(
        creatorId: String,
        name: String,
        description: String,
        privacy: GroupPrivacy,
        accentColorHex: String,
        iconName: String
    ) async throws -> FitGroup {
        let payload = CreateGroupPayload(
            creator_id: creatorId,
            name: name,
            description: description,
            privacy: privacy.rawValue,
            accent_color_hex: accentColorHex,
            icon_name: iconName
        )
        let created: SupabaseGroup = try await supabase
            .from("groups")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        guard let gid = created.id else {
            throw NSError(domain: "GroupsService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Group creation returned no id"])
        }

        let membership = CreateGroupMemberPayload(group_id: gid, user_id: creatorId, role: "Owner")
        try await supabase.from("group_members").insert(membership).execute()

        let members = (try? await fetchMembers(groupId: gid)) ?? []
        return toFitGroup(created, members: members, messages: [])
    }

    func joinGroup(groupId: String, userId: String) async throws {
        let payload = CreateGroupMemberPayload(group_id: groupId, user_id: userId, role: "Member")
        try await supabase.from("group_members").insert(payload).execute()
    }

    func leaveGroup(groupId: String, userId: String) async throws {
        try await supabase
            .from("group_members")
            .delete()
            .eq("group_id", value: groupId)
            .eq("user_id", value: userId)
            .execute()
    }

    func deleteGroup(groupId: String) async throws {
        try await supabase.from("groups").delete().eq("id", value: groupId).execute()
    }

    func sendMessage(groupId: String, senderId: String, text: String, attachments: [DirectMessageAttachment] = []) async throws -> SupabaseGroupMessage {
        let payload = CreateGroupMessagePayload(
            group_id: groupId,
            sender_id: senderId,
            text_content: text,
            attachments: attachments.isEmpty ? nil : attachments
        )
        let msg: SupabaseGroupMessage = try await supabase
            .from("group_messages")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
        return msg
    }

    func searchGroups(query: String, userId: String, limit: Int = 20) async throws -> [FitGroup] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        let escaped = q.replacingOccurrences(of: ",", with: "")
        let groups: [SupabaseGroup] = try await supabase
            .from("groups")
            .select()
            .or("name.ilike.%\(escaped)%,description.ilike.%\(escaped)%")
            .limit(limit * 2)
            .execute()
            .value

        let myMemberships: [SupabaseGroupMember] = (try? await supabase
            .from("group_members")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value) ?? []
        let myGroupIds = Set(myMemberships.map { $0.group_id })

        let visible = groups.filter { g in
            guard let gid = g.id else { return false }
            return (g.privacy ?? "Public") == "Public" || myGroupIds.contains(gid)
        }.prefix(limit)

        var results: [FitGroup] = []
        for g in visible {
            guard let gid = g.id else { continue }
            let members = (try? await fetchMembers(groupId: gid)) ?? []
            results.append(toFitGroup(g, members: members, messages: []))
        }
        return results
    }

    // MARK: - DM Media

    func uploadGroupImage(data: Data, groupId: String) async throws -> DirectMessageAttachment {
        let name = "\(groupId)/\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString).jpg"
        try await supabase.storage
            .from("dm-media")
            .upload(name, data: data, options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: false))
        let signed = try await supabase.storage.from("dm-media").createSignedURL(path: name, expiresIn: 60 * 60 * 24 * 365)
        return DirectMessageAttachment(kind: .image, url: signed.absoluteString)
    }

    func uploadGroupVideo(data: Data, groupId: String, durationSeconds: Double?) async throws -> DirectMessageAttachment {
        let name = "\(groupId)/\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString).mp4"
        try await supabase.storage
            .from("dm-media")
            .upload(name, data: data, options: FileOptions(cacheControl: "3600", contentType: "video/mp4", upsert: false))
        let signed = try await supabase.storage.from("dm-media").createSignedURL(path: name, expiresIn: 60 * 60 * 24 * 365)
        return DirectMessageAttachment(kind: .video, url: signed.absoluteString, durationSeconds: durationSeconds)
    }

    func uploadGroupVoice(data: Data, groupId: String, durationSeconds: Double?) async throws -> DirectMessageAttachment {
        let name = "\(groupId)/\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString).m4a"
        try await supabase.storage
            .from("dm-media")
            .upload(name, data: data, options: FileOptions(cacheControl: "3600", contentType: "audio/m4a", upsert: false))
        let signed = try await supabase.storage.from("dm-media").createSignedURL(path: name, expiresIn: 60 * 60 * 24 * 365)
        return DirectMessageAttachment(kind: .voice, url: signed.absoluteString, durationSeconds: durationSeconds)
    }

    // MARK: - Mapping

    private func parseColor(_ hex: String?) -> Color {
        guard let hex, !hex.isEmpty else { return PepTheme.teal }
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6, let num = UInt64(cleaned, radix: 16) else { return PepTheme.teal }
        return Color(
            red: Double((num >> 16) & 0xFF) / 255.0,
            green: Double((num >> 8) & 0xFF) / 255.0,
            blue: Double(num & 0xFF) / 255.0
        )
    }

    private func parseDate(_ s: String?) -> Date {
        guard let s else { return Date() }
        return iso.date(from: s) ?? Date()
    }

    func toFitGroup(_ g: SupabaseGroup, members: [SupabaseGroupMemberWithProfile], messages: [SupabaseGroupMessageWithProfile]) -> FitGroup {
        let mappedMembers = members.map { m -> GroupMember in
            let user = SocialService.shared.socialUserFromAuthor(m.profiles)
            let role = GroupMemberRole(rawValue: m.role ?? "Member") ?? .member
            return GroupMember(
                id: UUID(uuidString: m.user_id) ?? UUID(),
                user: user,
                role: role,
                joinedAt: parseDate(m.joined_at),
                stats: GroupMemberStats(),
                isSharingStats: m.is_sharing_stats ?? true
            )
        }
        let mappedMessages = messages.map { msg -> GroupMessage in
            let sender = SocialService.shared.socialUserFromAuthor(msg.profiles)
            return GroupMessage(
                id: UUID(uuidString: msg.id) ?? UUID(),
                sender: sender,
                text: msg.text_content,
                timestamp: parseDate(msg.created_at),
                likeCount: msg.like_count ?? 0,
                isLiked: false,
                attachments: msg.attachments ?? []
            )
        }
        return FitGroup(
            id: UUID(uuidString: g.id ?? "") ?? UUID(),
            name: g.name,
            description: g.description ?? "",
            privacy: GroupPrivacy(rawValue: g.privacy ?? "Public") ?? .publicGroup,
            accentColor: parseColor(g.accent_color_hex),
            iconName: g.icon_name ?? "person.3.fill",
            memberCount: mappedMembers.count,
            members: mappedMembers,
            messages: mappedMessages,
            createdAt: parseDate(g.created_at),
            creatorID: UUID(uuidString: g.creator_id) ?? UUID()
        )
    }
}
