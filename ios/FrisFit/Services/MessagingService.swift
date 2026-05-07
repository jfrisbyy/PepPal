import Foundation
import Supabase
import SwiftUI

nonisolated struct SupabaseFollow: Codable, Sendable {
    let id: String?
    let follower_id: String
    let following_id: String
    let created_at: String?
}

nonisolated struct CreateFollowPayload: Codable, Sendable {
    let follower_id: String
    let following_id: String
}

nonisolated struct SupabaseFollowRequest: Codable, Sendable {
    let id: String?
    let requester_id: String
    let target_id: String
    let status: String?
    let created_at: String?
}

nonisolated struct SupabaseFollowRequestWithProfile: Codable, Sendable {
    let id: String
    let requester_id: String
    let target_id: String
    let status: String?
    let created_at: String?
    let profiles: SupabasePostAuthor?
}

nonisolated struct CreateFollowRequestPayload: Codable, Sendable {
    let requester_id: String
    let target_id: String
}

nonisolated struct UpdateFollowRequestPayload: Codable, Sendable {
    let status: String
}

nonisolated struct SupabaseFriendRequest: Codable, Sendable {
    let id: String?
    let sender_id: String
    let receiver_id: String
    let status: String?
    let created_at: String?
    let updated_at: String?
}

nonisolated struct SupabaseFriendRequestWithProfile: Codable, Sendable {
    let id: String
    let sender_id: String
    let receiver_id: String
    let status: String?
    let created_at: String?
    let updated_at: String?
    let sender_profile: SupabasePostAuthor?
    let receiver_profile: SupabasePostAuthor?

    nonisolated enum CodingKeys: String, CodingKey {
        case id, sender_id, receiver_id, status, created_at, updated_at
        case sender_profile = "profiles!friend_requests_sender_id_fkey"
        case receiver_profile = "profiles!friend_requests_receiver_id_fkey"
    }
}

nonisolated struct CreateFriendRequestPayload: Codable, Sendable {
    let sender_id: String
    let receiver_id: String
}

nonisolated struct UpdateFriendRequestPayload: Codable, Sendable {
    let status: String
}

nonisolated struct SupabaseConversation: Codable, Sendable {
    let id: String
    let created_at: String?
    let updated_at: String?
}

nonisolated struct SupabaseConversationParticipant: Codable, Sendable {
    let id: String?
    let conversation_id: String
    let user_id: String
}

nonisolated struct CreateConversationParticipantPayload: Codable, Sendable {
    let conversation_id: String
    let user_id: String
}

nonisolated struct SupabaseDirectMessage: Codable, Sendable {
    let id: String?
    let conversation_id: String
    let sender_id: String
    let text_content: String?
    let is_read: Bool?
    let read_at: String?
    let attachments: [DirectMessageAttachment]?
    let created_at: String?
}

nonisolated struct SupabaseDirectMessageWithProfile: Codable, Sendable {
    let id: String
    let conversation_id: String
    let sender_id: String
    let text_content: String?
    let is_read: Bool?
    let read_at: String?
    let attachments: [DirectMessageAttachment]?
    let created_at: String?
    let profiles: SupabasePostAuthor?
}

nonisolated struct CreateDirectMessagePayload: Codable, Sendable {
    let conversation_id: String
    let sender_id: String
    let text_content: String
    let attachments: [DirectMessageAttachment]?
}

nonisolated struct MarkReadPayload: Codable, Sendable {
    let is_read: Bool
    let read_at: String?
}

nonisolated struct SupabaseNotification: Codable, Sendable {
    let id: String
    let user_id: String
    let type: String?
    let title: String?
    let body: String?
    let data: AnyCodable?
    let is_read: Bool?
    let created_at: String?
}

nonisolated struct AnyCodable: Codable, Sendable {
    let value: Any

    nonisolated init(_ value: Any) {
        self.value = value
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: String].self) {
            value = dict
        } else if let str = try? container.decode(String.self) {
            value = str
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else {
            value = ""
        }
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let str = value as? String {
            try container.encode(str)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else if let dict = value as? [String: String] {
            try container.encode(dict)
        } else {
            try container.encodeNil()
        }
    }
}

nonisolated struct CreateNotificationPayload: Codable, Sendable {
    let user_id: String
    let type: String
    let title: String
    let body: String
}

nonisolated struct MarkNotificationReadPayload: Codable, Sendable {
    let is_read: Bool
}

final class MessagingService {
    static let shared = MessagingService()

    private var supabase: SupabaseClient {
        SupabaseService.shared.client
    }

    private init() {}

    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    func parseDate(_ dateString: String?) -> Date {
        guard let dateString else { return Date() }
        return iso8601.date(from: dateString) ?? Date()
    }

    // MARK: - Follows

    enum FollowOutcome: Sendable {
        case followed
        case requested
    }

    @discardableResult
    func followUser(followerId: String, followingId: String) async throws -> FollowOutcome {
        let target: SupabaseProfile = try await supabase
            .from("profiles")
            .select()
            .eq("id", value: followingId)
            .single()
            .execute()
            .value

        if target.is_private == true {
            let payload = CreateFollowRequestPayload(requester_id: followerId, target_id: followingId)
            try await supabase
                .from("follow_requests")
                .insert(payload)
                .execute()

            try await createNotification(
                userId: followingId,
                type: "follow_request",
                title: "Follow Request",
                body: "Someone requested to follow you."
            )
            return .requested
        }

        let payload = CreateFollowPayload(follower_id: followerId, following_id: followingId)
        try await supabase
            .from("follows")
            .insert(payload)
            .execute()

        NotificationCenter.default.post(
            name: .followGraphChanged,
            object: nil,
            userInfo: ["followerId": followerId, "followingId": followingId, "isFollowing": true]
        )

        try await createNotification(
            userId: followingId,
            type: "new_follow",
            title: "New Follower",
            body: "Someone started following you!"
        )
        return .followed
    }

    func hasPendingFollowRequest(requesterId: String, targetId: String) async throws -> Bool {
        let response: [SupabaseFollowRequest] = try await supabase
            .from("follow_requests")
            .select("id")
            .eq("requester_id", value: requesterId)
            .eq("target_id", value: targetId)
            .eq("status", value: "pending")
            .execute()
            .value
        return !response.isEmpty
    }

    func cancelFollowRequest(requesterId: String, targetId: String) async throws {
        try await supabase
            .from("follow_requests")
            .delete()
            .eq("requester_id", value: requesterId)
            .eq("target_id", value: targetId)
            .eq("status", value: "pending")
            .execute()
    }

    func fetchPendingFollowRequests(userId: String, limit: Int = 200) async throws -> [SupabaseFollowRequestWithProfile] {
        let response: [SupabaseFollowRequestWithProfile] = try await supabase
            .from("follow_requests")
            .select("*, profiles!follow_requests_requester_id_fkey(id, display_name, username, avatar_url, avatar_color, active_program, total_fp, current_streak)")
            .eq("target_id", value: userId)
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return response
    }

    func fetchSentFollowRequests(userId: String, limit: Int = 200) async throws -> [SupabaseFollowRequest] {
        let response: [SupabaseFollowRequest] = try await supabase
            .from("follow_requests")
            .select()
            .eq("requester_id", value: userId)
            .eq("status", value: "pending")
            .limit(limit)
            .execute()
            .value
        return response
    }

    func approveFollowRequest(requestId: String, requesterId: String, targetId: String) async throws {
        let payload = UpdateFollowRequestPayload(status: "approved")
        try await supabase
            .from("follow_requests")
            .update(payload)
            .eq("id", value: requestId)
            .execute()

        let follow = CreateFollowPayload(follower_id: requesterId, following_id: targetId)
        try await supabase
            .from("follows")
            .insert(follow)
            .execute()

        try await createNotification(
            userId: requesterId,
            type: "follow_approved",
            title: "Follow Request Approved",
            body: "You can now see their posts."
        )
    }

    func denyFollowRequest(requestId: String) async throws {
        let payload = UpdateFollowRequestPayload(status: "denied")
        try await supabase
            .from("follow_requests")
            .update(payload)
            .eq("id", value: requestId)
            .execute()
    }

    func unfollowUser(followerId: String, followingId: String) async throws {
        try await supabase
            .from("follows")
            .delete()
            .eq("follower_id", value: followerId)
            .eq("following_id", value: followingId)
            .execute()

        NotificationCenter.default.post(
            name: .followGraphChanged,
            object: nil,
            userInfo: ["followerId": followerId, "followingId": followingId, "isFollowing": false]
        )
    }

    func isFollowing(followerId: String, followingId: String) async throws -> Bool {
        let response: [SupabaseFollow] = try await supabase
            .from("follows")
            .select("id")
            .eq("follower_id", value: followerId)
            .eq("following_id", value: followingId)
            .execute()
            .value
        return !response.isEmpty
    }

    func fetchFollowing(userId: String, limit: Int = 1000, offset: Int = 0) async throws -> [String] {
        let response: [SupabaseFollow] = try await supabase
            .from("follows")
            .select("following_id")
            .eq("follower_id", value: userId)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
        return response.map { $0.following_id }
    }

    func fetchFollowers(userId: String, limit: Int = 1000, offset: Int = 0) async throws -> [String] {
        let response: [SupabaseFollow] = try await supabase
            .from("follows")
            .select("follower_id")
            .eq("following_id", value: userId)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
        return response.map { $0.follower_id }
    }

    // MARK: - Friend Requests

    func sendFriendRequest(senderId: String, receiverId: String) async throws {
        let payload = CreateFriendRequestPayload(sender_id: senderId, receiver_id: receiverId)
        try await supabase
            .from("friend_requests")
            .insert(payload)
            .execute()

        try await createNotification(
            userId: receiverId,
            type: "friend_request",
            title: "Friend Request",
            body: "You have a new friend request!"
        )
    }

    func acceptFriendRequest(requestId: String) async throws {
        let payload = UpdateFriendRequestPayload(status: "accepted")
        try await supabase
            .from("friend_requests")
            .update(payload)
            .eq("id", value: requestId)
            .execute()
    }

    func rejectFriendRequest(requestId: String) async throws {
        let payload = UpdateFriendRequestPayload(status: "declined")
        try await supabase
            .from("friend_requests")
            .update(payload)
            .eq("id", value: requestId)
            .execute()
    }

    func fetchPendingRequests(userId: String, limit: Int = 200) async throws -> [SupabaseFriendRequestWithProfile] {
        let response: [SupabaseFriendRequestWithProfile] = try await supabase
            .from("friend_requests")
            .select("*, profiles!friend_requests_sender_id_fkey(id, display_name, username, avatar_url, avatar_color, active_program, total_fp, current_streak), profiles!friend_requests_receiver_id_fkey(id, display_name, username, avatar_url, avatar_color, active_program, total_fp, current_streak)")
            .eq("receiver_id", value: userId)
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return response
    }

    func fetchSentRequests(userId: String, limit: Int = 200) async throws -> [SupabaseFriendRequest] {
        let response: [SupabaseFriendRequest] = try await supabase
            .from("friend_requests")
            .select()
            .eq("sender_id", value: userId)
            .eq("status", value: "pending")
            .limit(limit)
            .execute()
            .value
        return response
    }

    func fetchFriendStatus(userId: String, otherUserId: String) async throws -> (status: FriendRequestStatus, requestId: String?) {
        let sent: [SupabaseFriendRequest] = try await supabase
            .from("friend_requests")
            .select()
            .eq("sender_id", value: userId)
            .eq("receiver_id", value: otherUserId)
            .in("status", values: ["pending", "accepted"])
            .execute()
            .value

        if let req = sent.first {
            return (req.status == "accepted" ? .accepted : .pending, req.id)
        }

        let received: [SupabaseFriendRequest] = try await supabase
            .from("friend_requests")
            .select()
            .eq("sender_id", value: otherUserId)
            .eq("receiver_id", value: userId)
            .in("status", values: ["pending", "accepted"])
            .execute()
            .value

        if let req = received.first {
            return (req.status == "accepted" ? .accepted : .pending, req.id)
        }

        return (.none, nil)
    }

    // MARK: - Conversations

    func fetchConversations(userId: String) async throws -> [(conversation: SupabaseConversation, participant: SupabasePostAuthor, lastMessage: SupabaseDirectMessage?, unreadCount: Int)] {
        let myParticipations: [SupabaseConversationParticipant] = try await supabase
            .from("conversation_participants")
            .select("conversation_id, user_id")
            .eq("user_id", value: userId)
            .execute()
            .value

        let conversationIds = myParticipations.map { $0.conversation_id }
        guard !conversationIds.isEmpty else { return [] }

        var results: [(conversation: SupabaseConversation, participant: SupabasePostAuthor, lastMessage: SupabaseDirectMessage?, unreadCount: Int)] = []

        for convId in conversationIds {
            let conversation: SupabaseConversation = try await supabase
                .from("conversations")
                .select()
                .eq("id", value: convId)
                .single()
                .execute()
                .value

            let otherParticipants: [SupabaseConversationParticipant] = try await supabase
                .from("conversation_participants")
                .select()
                .eq("conversation_id", value: convId)
                .neq("user_id", value: userId)
                .execute()
                .value

            guard let otherUserId = otherParticipants.first?.user_id else { continue }

            let profile: SupabasePostAuthor = try await supabase
                .from("profiles")
                .select("id, display_name, username, avatar_url, avatar_color, active_program, total_fp, current_streak")
                .eq("id", value: otherUserId)
                .single()
                .execute()
                .value

            let lastMessages: [SupabaseDirectMessage] = try await supabase
                .from("direct_messages")
                .select()
                .eq("conversation_id", value: convId)
                .order("created_at", ascending: false)
                .range(from: 0, to: 0)
                .execute()
                .value

            let unreadMessages: [SupabaseDirectMessage] = try await supabase
                .from("direct_messages")
                .select("id")
                .eq("conversation_id", value: convId)
                .neq("sender_id", value: userId)
                .eq("is_read", value: false)
                .execute()
                .value

            results.append((
                conversation: conversation,
                participant: profile,
                lastMessage: lastMessages.first,
                unreadCount: unreadMessages.count
            ))
        }

        results.sort { a, b in
            let aDate = a.lastMessage?.created_at ?? a.conversation.created_at ?? ""
            let bDate = b.lastMessage?.created_at ?? b.conversation.created_at ?? ""
            return aDate > bDate
        }

        return results
    }

    func findOrCreateConversation(userId: String, otherUserId: String) async throws -> String {
        let myConvs: [SupabaseConversationParticipant] = try await supabase
            .from("conversation_participants")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value

        for myConv in myConvs {
            let others: [SupabaseConversationParticipant] = try await supabase
                .from("conversation_participants")
                .select()
                .eq("conversation_id", value: myConv.conversation_id)
                .eq("user_id", value: otherUserId)
                .execute()
                .value

            if !others.isEmpty {
                return myConv.conversation_id
            }
        }

        let newConv: SupabaseConversation = try await supabase
            .from("conversations")
            .insert(["id": UUID().uuidString])
            .select()
            .single()
            .execute()
            .value

        let p1 = CreateConversationParticipantPayload(conversation_id: newConv.id, user_id: userId)
        let p2 = CreateConversationParticipantPayload(conversation_id: newConv.id, user_id: otherUserId)

        try await supabase
            .from("conversation_participants")
            .insert([p1, p2])
            .execute()

        return newConv.id
    }

    // MARK: - Direct Messages

    func fetchMessages(conversationId: String, limit: Int = 100) async throws -> [SupabaseDirectMessageWithProfile] {
        let response: [SupabaseDirectMessageWithProfile] = try await supabase
            .from("direct_messages")
            .select("*, profiles!direct_messages_sender_id_fkey(id, display_name, username, avatar_url, avatar_color, active_program, total_fp, current_streak)")
            .eq("conversation_id", value: conversationId)
            .order("created_at", ascending: true)
            .range(from: 0, to: limit - 1)
            .execute()
            .value
        return response
    }

    func sendMessage(conversationId: String, senderId: String, text: String, attachments: [DirectMessageAttachment] = []) async throws -> SupabaseDirectMessage {
        if let otherId = try? await otherParticipantId(conversationId: conversationId, selfUserId: senderId) {
            let blocked = (try? await ModerationService.shared.isBlocked(blockerId: otherId, blockedId: senderId)) ?? false
            if blocked {
                throw NSError(domain: "MessagingService", code: 403, userInfo: [NSLocalizedDescriptionKey: "You cannot message this user."])
            }
            let iBlocked = (try? await ModerationService.shared.isBlocked(blockerId: senderId, blockedId: otherId)) ?? false
            if iBlocked {
                throw NSError(domain: "MessagingService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Unblock this user to message them."])
            }
        }

        let payload = CreateDirectMessagePayload(
            conversation_id: conversationId,
            sender_id: senderId,
            text_content: text,
            attachments: attachments.isEmpty ? nil : attachments
        )
        let message: SupabaseDirectMessage = try await supabase
            .from("direct_messages")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        let otherParticipants: [SupabaseConversationParticipant] = try await supabase
            .from("conversation_participants")
            .select()
            .eq("conversation_id", value: conversationId)
            .neq("user_id", value: senderId)
            .execute()
            .value

        for participant in otherParticipants {
            try await createNotification(
                userId: participant.user_id,
                type: "new_message",
                title: "New Message",
                body: text.prefix(100) + (text.count > 100 ? "..." : "")
            )
        }

        return message
    }

    func markMessagesAsRead(conversationId: String, userId: String) async throws {
        let nowISO = ISO8601DateFormatter().string(from: Date())
        let payload = MarkReadPayload(is_read: true, read_at: nowISO)
        try await supabase
            .from("direct_messages")
            .update(payload)
            .eq("conversation_id", value: conversationId)
            .neq("sender_id", value: userId)
            .eq("is_read", value: false)
            .execute()
    }

    func markSingleMessageRead(messageId: String) async throws {
        let nowISO = ISO8601DateFormatter().string(from: Date())
        let payload = MarkReadPayload(is_read: true, read_at: nowISO)
        try await supabase
            .from("direct_messages")
            .update(payload)
            .eq("id", value: messageId)
            .eq("is_read", value: false)
            .execute()
    }

    private func otherParticipantId(conversationId: String, selfUserId: String) async throws -> String? {
        let others: [SupabaseConversationParticipant] = try await supabase
            .from("conversation_participants")
            .select()
            .eq("conversation_id", value: conversationId)
            .neq("user_id", value: selfUserId)
            .execute()
            .value
        return others.first?.user_id
    }

    // MARK: - DM Media Upload

    func uploadDMImage(data: Data, conversationId: String) async throws -> DirectMessageAttachment {
        let name = "\(conversationId)/\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString).jpg"
        try await supabase.storage
            .from("dm-media")
            .upload(name, data: data, options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: false))
        let signed = try await supabase.storage.from("dm-media").createSignedURL(path: name, expiresIn: 60 * 60 * 24 * 365)
        return DirectMessageAttachment(kind: .image, url: signed.absoluteString)
    }

    func uploadDMVideo(data: Data, conversationId: String, durationSeconds: Double?) async throws -> DirectMessageAttachment {
        let name = "\(conversationId)/\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString).mp4"
        try await supabase.storage
            .from("dm-media")
            .upload(name, data: data, options: FileOptions(cacheControl: "3600", contentType: "video/mp4", upsert: false))
        let signed = try await supabase.storage.from("dm-media").createSignedURL(path: name, expiresIn: 60 * 60 * 24 * 365)
        return DirectMessageAttachment(kind: .video, url: signed.absoluteString, durationSeconds: durationSeconds)
    }

    func uploadDMVoice(data: Data, conversationId: String, durationSeconds: Double?) async throws -> DirectMessageAttachment {
        let name = "\(conversationId)/\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString).m4a"
        try await supabase.storage
            .from("dm-media")
            .upload(name, data: data, options: FileOptions(cacheControl: "3600", contentType: "audio/m4a", upsert: false))
        let signed = try await supabase.storage.from("dm-media").createSignedURL(path: name, expiresIn: 60 * 60 * 24 * 365)
        return DirectMessageAttachment(kind: .voice, url: signed.absoluteString, durationSeconds: durationSeconds)
    }

    func fetchProfile(userId: String) async throws -> SupabasePostAuthor {
        return try await supabase
            .from("profiles")
            .select("id, display_name, username, avatar_url, avatar_color, active_program, total_fp, current_streak")
            .eq("id", value: userId)
            .single()
            .execute()
            .value
    }

    func fetchTestUserProfiles(excluding userId: String) async throws -> [SupabasePostAuthor] {
        let response: [SupabasePostAuthor] = try await supabase
            .from("profiles")
            .select("id, display_name, username, avatar_url, avatar_color, active_program, total_fp, current_streak")
            .eq("is_test_user", value: true)
            .neq("id", value: userId)
            .execute()
            .value
        return response
    }

    func fetchProfilesByIds(_ ids: [String]) async throws -> [SupabasePostAuthor] {
        guard !ids.isEmpty else { return [] }
        let unique = Array(Set(ids))
        do {
            let response: [SupabasePostAuthor] = try await supabase
                .from("profiles")
                .select("id, display_name, username, avatar_url, avatar_color, active_program, total_fp, current_streak")
                .in("id", values: unique)
                .execute()
                .value
            let byId = Dictionary(uniqueKeysWithValues: response.map { ($0.id.lowercased(), $0) })
            return ids.compactMap { byId[$0.lowercased()] }
        } catch {
            var results: [SupabasePostAuthor] = []
            for uid in unique {
                if let profile: SupabasePostAuthor = try? await supabase
                    .from("profiles")
                    .select("id, display_name, username, avatar_url, avatar_color, active_program, total_fp, current_streak")
                    .eq("id", value: uid)
                    .single()
                    .execute()
                    .value {
                    results.append(profile)
                }
            }
            return results
        }
    }

    // MARK: - User Search

    func searchUsers(query: String, excludeUserId: String) async throws -> [SupabasePostAuthor] {
        let response: [SupabasePostAuthor] = try await supabase
            .from("profiles")
            .select("id, display_name, username, avatar_url, avatar_color, active_program, total_fp, current_streak")
            .neq("id", value: excludeUserId)
            .or("display_name.ilike.%\(query)%,username.ilike.%\(query)%")
            .range(from: 0, to: 19)
            .execute()
            .value
        return response
    }

    // MARK: - Notifications

    func fetchNotifications(userId: String, limit: Int = 50) async throws -> [SupabaseNotification] {
        let response: [SupabaseNotification] = try await supabase
            .from("notifications")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .range(from: 0, to: limit - 1)
            .execute()
            .value
        return response
    }

    func markNotificationRead(notificationId: String) async throws {
        let payload = MarkNotificationReadPayload(is_read: true)
        try await supabase
            .from("notifications")
            .update(payload)
            .eq("id", value: notificationId)
            .execute()
    }

    func markAllNotificationsRead(userId: String) async throws {
        let payload = MarkNotificationReadPayload(is_read: true)
        try await supabase
            .from("notifications")
            .update(payload)
            .eq("user_id", value: userId)
            .eq("is_read", value: false)
            .execute()
    }

    func unreadNotificationCount(userId: String) async throws -> Int {
        let response: [SupabaseNotification] = try await supabase
            .from("notifications")
            .select("id")
            .eq("user_id", value: userId)
            .eq("is_read", value: false)
            .execute()
            .value
        return response.count
    }

    private func createNotification(userId: String, type: String, title: String, body: String) async throws {
        let payload = CreateNotificationPayload(user_id: userId, type: type, title: title, body: body)
        try await supabase
            .from("notifications")
            .insert(payload)
            .execute()
    }

    func socialUserFromAuthor(_ author: SupabasePostAuthor?) -> SocialUser {
        SocialService.shared.socialUserFromAuthor(author)
    }
}
