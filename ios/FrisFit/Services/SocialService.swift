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
    let edited_at: String?
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
    let edited_at: String?
    var profiles: SupabasePostAuthor?
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
    let content: String?
    let body: String?
    let text: String?
    let created_at: String?

    var commentText: String? { content ?? body ?? text }
}

nonisolated struct SupabasePostCommentWithProfile: Codable, Sendable {
    let id: String
    let post_id: String
    let user_id: String
    let content: String?
    let body: String?
    let text: String?
    let created_at: String?
    var profiles: SupabasePostAuthor?

    var commentText: String? { content ?? body ?? text }
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
    let content: String
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

    func fetchPost(postId: String) async throws -> SupabaseFeedPostWithProfile {
        var post: SupabaseFeedPostWithProfile = try await supabase
            .from("feed_posts")
            .select("*, profiles(id, display_name, username, avatar_url, avatar_color, active_program, total_fp, current_streak)")
            .eq("id", value: postId)
            .single()
            .execute()
            .value
        var arr = [post]
        await backfillAuthors(posts: &arr)
        post = arr[0]
        return post
    }

    func fetchPosts(limit: Int = 50, offset: Int = 0) async throws -> [SupabaseFeedPostWithProfile] {
        var response: [SupabaseFeedPostWithProfile] = try await supabase
            .from("feed_posts")
            .select("*, profiles(id, display_name, username, avatar_url, avatar_color, active_program, total_fp, current_streak)")
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
        await backfillAuthors(posts: &response)
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

        var full: SupabaseFeedPostWithProfile = try await supabase
            .from("feed_posts")
            .select("*, profiles(id, display_name, username, avatar_url, avatar_color, active_program, total_fp, current_streak)")
            .eq("id", value: created.id)
            .single()
            .execute()
            .value
        var arr = [full]
        await backfillAuthors(posts: &arr)
        full = arr[0]
        return full
    }

    func deletePost(postId: String) async throws {
        try await supabase
            .from("feed_posts")
            .delete()
            .eq("id", value: postId)
            .execute()
    }

    nonisolated struct UpdateFeedPostPayload: Codable, Sendable {
        let text_content: String
        let tags: [String]?
        let updated_at: String
        let edited_at: String
    }

    func updatePost(postId: String, textContent: String, tags: [String]?) async throws -> SupabaseFeedPostWithProfile {
        let now = ISO8601DateFormatter().string(from: Date())
        let payload = UpdateFeedPostPayload(text_content: textContent, tags: tags, updated_at: now, edited_at: now)
        try await supabase
            .from("feed_posts")
            .update(payload)
            .eq("id", value: postId)
            .execute()

        var full: SupabaseFeedPostWithProfile = try await supabase
            .from("feed_posts")
            .select("*, profiles(id, display_name, username, avatar_url, avatar_color, active_program, total_fp, current_streak)")
            .eq("id", value: postId)
            .single()
            .execute()
            .value
        var arr = [full]
        await backfillAuthors(posts: &arr)
        full = arr[0]
        return full
    }

    /// Fetch a page using a cursor (latest created_at seen). Returns posts older than the cursor.
    func fetchPostsPage(before cursor: Date?, pageSize: Int = 20) async throws -> [SupabaseFeedPostWithProfile] {
        var query = supabase
            .from("feed_posts")
            .select("*, profiles(id, display_name, username, avatar_url, avatar_color, active_program, total_fp, current_streak)")
        if let cursor {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            query = query.lt("created_at", value: iso.string(from: cursor))
        }
        var response: [SupabaseFeedPostWithProfile] = try await query
            .order("created_at", ascending: false)
            .limit(pageSize)
            .execute()
            .value
        await backfillAuthors(posts: &response)
        return response
    }

    func fetchComments(postId: String) async throws -> [SupabasePostCommentWithProfile] {
        var response: [SupabasePostCommentWithProfile] = try await supabase
            .from("post_comments")
            .select("*, profiles(id, display_name, username, avatar_url, avatar_color, active_program, total_fp, current_streak)")
            .eq("post_id", value: postId)
            .order("created_at", ascending: true)
            .execute()
            .value
        await backfillCommentAuthors(comments: &response)
        return response
    }

    func addComment(postId: String, userId: String, text: String) async throws -> SupabasePostCommentWithProfile {
        let payload = CreateCommentPayload(post_id: postId, user_id: userId, content: text)
        do {
            var full: SupabasePostCommentWithProfile = try await supabase
                .from("post_comments")
                .insert(payload)
                .select("*, profiles(id, display_name, username, avatar_url, avatar_color, active_program, total_fp, current_streak)")
                .single()
                .execute()
                .value
            var arr = [full]
            await backfillCommentAuthors(comments: &arr)
            full = arr[0]
            return full
        } catch {
            print("[SocialService] addComment insert+select failed: \(error). Falling back to two-step insert.")
            let inserted: SupabasePostComment = try await supabase
                .from("post_comments")
                .insert(payload)
                .select()
                .single()
                .execute()
                .value

            var full: SupabasePostCommentWithProfile = try await supabase
                .from("post_comments")
                .select("*, profiles(id, display_name, username, avatar_url, avatar_color, active_program, total_fp, current_streak)")
                .eq("id", value: inserted.id)
                .single()
                .execute()
                .value
            var arr = [full]
            await backfillCommentAuthors(comments: &arr)
            full = arr[0]
            return full
        }
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

    func searchPosts(query: String, limit: Int = 20) async throws -> [SupabaseFeedPostWithProfile] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        var response: [SupabaseFeedPostWithProfile] = try await supabase
            .from("feed_posts")
            .select("*, profiles(id, display_name, username, avatar_url, avatar_color, active_program, total_fp, current_streak)")
            .ilike("text_content", pattern: "%\(q)%")
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        await backfillAuthors(posts: &response)
        return response
    }

    func fetchUserPosts(userId: String, limit: Int = 50) async throws -> [SupabaseFeedPostWithProfile] {
        var response: [SupabaseFeedPostWithProfile] = try await supabase
            .from("feed_posts")
            .select("*, profiles(id, display_name, username, avatar_url, avatar_color, active_program, total_fp, current_streak)")
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        await backfillAuthors(posts: &response)
        return response
    }

    func deleteComment(commentId: String) async throws {
        try await supabase
            .from("post_comments")
            .delete()
            .eq("id", value: commentId)
            .execute()
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

    // MARK: - Author backfill
    //
    // PostgREST's auto-detected `profiles` embed sometimes returns null
    // for posts authored by users created via `auth.admin.createUser`
    // (e.g. our fake personas) — the inferred relationship through
    // auth.users doesn't always resolve under RLS for those rows. To
    // guarantee every post / comment renders with the real author name,
    // we batch-fetch profiles by user_id whenever the embed comes back
    // empty and merge them in client-side.

    private func fetchProfilesByIds(_ ids: [String]) async -> [String: SupabasePostAuthor] {
        guard !ids.isEmpty else { return [:] }
        do {
            let rows: [SupabasePostAuthor] = try await supabase
                .from("profiles")
                .select("id, display_name, username, avatar_url, avatar_color, active_program, total_fp, current_streak")
                .in("id", values: ids)
                .execute()
                .value
            var map: [String: SupabasePostAuthor] = [:]
            for r in rows { map[r.id] = r }
            return map
        } catch {
            print("[SocialService] backfill profiles fetch failed: \(error)")
            return [:]
        }
    }

    func backfillAuthors(posts: inout [SupabaseFeedPostWithProfile]) async {
        let missingIds = Array(Set(posts.compactMap { $0.profiles == nil ? $0.user_id : nil }))
        guard !missingIds.isEmpty else { return }
        let map = await fetchProfilesByIds(missingIds)
        guard !map.isEmpty else { return }
        for i in posts.indices where posts[i].profiles == nil {
            posts[i].profiles = map[posts[i].user_id]
        }
    }

    func backfillCommentAuthors(comments: inout [SupabasePostCommentWithProfile]) async {
        let missingIds = Array(Set(comments.compactMap { $0.profiles == nil ? $0.user_id : nil }))
        guard !missingIds.isEmpty else { return }
        let map = await fetchProfilesByIds(missingIds)
        guard !map.isEmpty else { return }
        for i in comments.indices where comments[i].profiles == nil {
            comments[i].profiles = map[comments[i].user_id]
        }
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
