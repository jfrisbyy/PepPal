import Foundation
import Supabase
import SwiftUI

nonisolated struct SupabaseFeedPost: Codable, Sendable {
    let id: String
    let user_id: String
    let text_content: String?
    let media_urls: [String]?
    let audio_url: String?
    let audio_duration: Double?
    let tags: [String]?
    let high_five_count: Int?
    let repost_count: Int?
    let created_at: String?
    let updated_at: String?
}

nonisolated struct SupabaseFeedPostWithProfile: Codable, Sendable {
    let id: String
    let user_id: String
    let text_content: String?
    let media_urls: [String]?
    let audio_url: String?
    let audio_duration: Double?
    let tags: [String]?
    let high_five_count: Int?
    let repost_count: Int?
    let created_at: String?
    let updated_at: String?
    let profiles: SupabasePostAuthor?
}

nonisolated struct SupabasePostAuthor: Codable, Sendable {
    let id: String
    let display_name: String?
    let username: String?
    let avatar_url: String?
    let avatar_color: String?
    let active_program: String?
    let total_fp: Int?
    let current_streak: Int?
}

nonisolated struct SupabasePostComment: Codable, Sendable {
    let id: String
    let post_id: String
    let user_id: String
    let text_content: String?
    let created_at: String?
}

nonisolated struct SupabasePostCommentWithProfile: Codable, Sendable {
    let id: String
    let post_id: String
    let user_id: String
    let text_content: String?
    let created_at: String?
    let profiles: SupabasePostAuthor?
}

nonisolated struct SupabasePostLike: Codable, Sendable {
    let id: String?
    let post_id: String
    let user_id: String
    let created_at: String?
}

nonisolated struct CreateFeedPostPayload: Codable, Sendable {
    let user_id: String
    let text_content: String
    let media_urls: [String]?
    let tags: [String]?
    let audio_url: String?
    let audio_duration: Double?
}

nonisolated struct CreateCommentPayload: Codable, Sendable {
    let post_id: String
    let user_id: String
    let text_content: String
}

nonisolated struct CreateLikePayload: Codable, Sendable {
    let post_id: String
    let user_id: String
}

nonisolated struct SupabasePostRepost: Codable, Sendable {
    let id: String?
    let post_id: String
    let user_id: String
    let created_at: String?
}

nonisolated struct CreateRepostPayload: Codable, Sendable {
    let post_id: String
    let user_id: String
}

final class SocialService {
    static let shared = SocialService()

    private var supabase: SupabaseClient {
        SupabaseService.shared.client
    }

    private init() {}

    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    func fetchPosts(limit: Int = 50, offset: Int = 0) async throws -> [SupabaseFeedPostWithProfile] {
        let response: [SupabaseFeedPostWithProfile] = try await supabase
            .from("feed_posts")
            .select("*, profiles(id, display_name, username, avatar_url, avatar_color, active_program, total_fp, current_streak)")
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
        return response
    }

    func createPost(userId: String, textContent: String, mediaUrls: [String]?, tags: [String]?, audioUrl: String? = nil, audioDuration: Double? = nil) async throws -> SupabaseFeedPostWithProfile {
        let payload = CreateFeedPostPayload(
            user_id: userId,
            text_content: textContent,
            media_urls: mediaUrls,
            tags: tags,
            audio_url: audioUrl,
            audio_duration: audioDuration
        )
        let created: SupabaseFeedPost = try await supabase
            .from("feed_posts")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        let full: SupabaseFeedPostWithProfile = try await supabase
            .from("feed_posts")
            .select("*, profiles(id, display_name, username, avatar_url, avatar_color, active_program, total_fp, current_streak)")
            .eq("id", value: created.id)
            .single()
            .execute()
            .value
        return full
    }

    func deletePost(postId: String) async throws {
        try await supabase
            .from("feed_posts")
            .delete()
            .eq("id", value: postId)
            .execute()
    }

    func fetchComments(postId: String) async throws -> [SupabasePostCommentWithProfile] {
        let response: [SupabasePostCommentWithProfile] = try await supabase
            .from("post_comments")
            .select("*, profiles(id, display_name, username, avatar_url, avatar_color, active_program, total_fp, current_streak)")
            .eq("post_id", value: postId)
            .order("created_at", ascending: true)
            .execute()
            .value
        return response
    }

    func addComment(postId: String, userId: String, text: String) async throws -> SupabasePostCommentWithProfile {
        let payload = CreateCommentPayload(post_id: postId, user_id: userId, text_content: text)
        let created: SupabasePostComment = try await supabase
            .from("post_comments")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        let full: SupabasePostCommentWithProfile = try await supabase
            .from("post_comments")
            .select("*, profiles(id, display_name, username, avatar_url, avatar_color, active_program, total_fp, current_streak)")
            .eq("id", value: created.id)
            .single()
            .execute()
            .value
        return full
    }

    func fetchLikeStatus(postId: String, userId: String) async throws -> Bool {
        let response: [SupabasePostLike] = try await supabase
            .from("post_likes")
            .select()
            .eq("post_id", value: postId)
            .eq("user_id", value: userId)
            .execute()
            .value
        return !response.isEmpty
    }

    func fetchLikedPostIds(userId: String, postIds: [String]) async throws -> Set<String> {
        guard !postIds.isEmpty else { return [] }
        let response: [SupabasePostLike] = try await supabase
            .from("post_likes")
            .select("post_id, user_id")
            .eq("user_id", value: userId)
            .in("post_id", values: postIds)
            .execute()
            .value
        return Set(response.map { $0.post_id })
    }

    func likePost(postId: String, userId: String) async throws {
        let payload = CreateLikePayload(post_id: postId, user_id: userId)
        try await supabase
            .from("post_likes")
            .insert(payload)
            .execute()

        try await supabase
            .rpc("increment_high_five_count", params: ["row_id": postId])
            .execute()
    }

    func unlikePost(postId: String, userId: String) async throws {
        try await supabase
            .from("post_likes")
            .delete()
            .eq("post_id", value: postId)
            .eq("user_id", value: userId)
            .execute()

        try await supabase
            .rpc("decrement_high_five_count", params: ["row_id": postId])
            .execute()
    }

    func fetchRepostedPostIds(userId: String, postIds: [String]) async throws -> Set<String> {
        guard !postIds.isEmpty else { return [] }
        let response: [SupabasePostRepost] = try await supabase
            .from("post_reposts")
            .select("post_id, user_id")
            .eq("user_id", value: userId)
            .in("post_id", values: postIds)
            .execute()
            .value
        return Set(response.map { $0.post_id })
    }

    func repostPost(postId: String, userId: String) async throws {
        let payload = CreateRepostPayload(post_id: postId, user_id: userId)
        try await supabase
            .from("post_reposts")
            .insert(payload)
            .execute()

        try await supabase
            .rpc("increment_repost_count", params: ["row_id": postId])
            .execute()
    }

    func unrepostPost(postId: String, userId: String) async throws {
        try await supabase
            .from("post_reposts")
            .delete()
            .eq("post_id", value: postId)
            .eq("user_id", value: userId)
            .execute()

        try await supabase
            .rpc("decrement_repost_count", params: ["row_id": postId])
            .execute()
    }

    func uploadAudio(userId: String, audioData: Data) async throws -> String {
        let fileName = "\(userId)/\(UUID().uuidString).m4a"
        try await supabase.storage
            .from("post-media")
            .upload(fileName, data: audioData, options: FileOptions(
                cacheControl: "3600",
                contentType: "audio/mp4",
                upsert: false
            ))

        let publicURL = try supabase.storage
            .from("post-media")
            .getPublicURL(path: fileName)

        return publicURL.absoluteString
    }

    func uploadMedia(userId: String, imageData: Data, index: Int) async throws -> String {
        let fileName = "\(userId)/\(UUID().uuidString)_\(index).jpg"
        try await supabase.storage
            .from("post-media")
            .upload(fileName, data: imageData, options: FileOptions(
                cacheControl: "3600",
                contentType: "image/jpeg",
                upsert: false
            ))

        let publicURL = try supabase.storage
            .from("post-media")
            .getPublicURL(path: fileName)

        return publicURL.absoluteString
    }

    func fetchUserPosts(userId: String, limit: Int = 50) async throws -> [SupabaseFeedPostWithProfile] {
        let response: [SupabaseFeedPostWithProfile] = try await supabase
            .from("feed_posts")
            .select("*, profiles(id, display_name, username, avatar_url, avatar_color, active_program, total_fp, current_streak)")
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return response
    }

    func fetchCommentCount(postId: String) async throws -> Int {
        let response: [SupabasePostComment] = try await supabase
            .from("post_comments")
            .select("id")
            .eq("post_id", value: postId)
            .execute()
            .value
        return response.count
    }

    func fetchCommentCounts(postIds: [String]) async throws -> [String: Int] {
        guard !postIds.isEmpty else { return [:] }
        let response: [SupabasePostComment] = try await supabase
            .from("post_comments")
            .select("id, post_id")
            .in("post_id", values: postIds)
            .execute()
            .value
        var counts: [String: Int] = [:]
        for comment in response {
            counts[comment.post_id, default: 0] += 1
        }
        return counts
    }

    func parseDate(_ dateString: String?) -> Date {
        guard let dateString else { return Date() }
        return iso8601.date(from: dateString) ?? Date()
    }

    func socialUserFromAuthor(_ author: SupabasePostAuthor?) -> SocialUser {
        let name = author?.display_name ?? "Unknown"
        let username = author?.username ?? "user"
        let initial = String(name.prefix(1)).uppercased()
        let color = parseAvatarColor(author?.avatar_color)

        return SocialUser(
            id: UUID(uuidString: author?.id ?? "") ?? UUID(),
            name: name,
            username: username,
            avatarInitial: initial,
            avatarColor: color,
            avatarURL: author?.avatar_url,
            activeProgramName: author?.active_program,
            streak: author?.current_streak ?? 0,
            totalFP: author?.total_fp ?? 0
        )
    }

    private func parseAvatarColor(_ hex: String?) -> Color {
        guard let hex, !hex.isEmpty else { return Color(red: 0.2, green: 0.6, blue: 0.9) }
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6, let num = UInt64(cleaned, radix: 16) else {
            return Color(red: 0.2, green: 0.6, blue: 0.9)
        }
        return Color(
            red: Double((num >> 16) & 0xFF) / 255.0,
            green: Double((num >> 8) & 0xFF) / 255.0,
            blue: Double(num & 0xFF) / 255.0
        )
    }
}
