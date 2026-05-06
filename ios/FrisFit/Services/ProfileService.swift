import Foundation
import Supabase
import SwiftUI

nonisolated struct SupabaseProfile: Codable, Sendable {
    let id: String
    let display_name: String?
    let username: String?
    let bio: String?
    let avatar_url: String?
    let avatar_color: String?
    let banner_url: String?
    let active_program: String?
    let total_fp: Int?
    let current_streak: Int?
    let total_workouts: Int?
    let member_since: String?
    let follower_count: Int?
    let following_count: Int?
    let friend_count: Int?
    let date_of_birth: String?
    let biological_sex: String?
    let height_cm: Double?
    let is_private: Bool?
    let medical_disclaimer_accepted_at: String?
    let instagram_handle: String?
    let twitter_handle: String?
    let facebook_handle: String?
    let tiktok_handle: String?
}

nonisolated struct ProfileUpdate: Codable, Sendable {
    let display_name: String?
    let username: String?
    let bio: String?
    let avatar_url: String?
    let avatar_color: String?
    let banner_url: String?
    let active_program: String?
    let date_of_birth: String?
    let biological_sex: String?
    let height_cm: Double?
    let is_private: Bool?
    let medical_disclaimer_accepted_at: String?
    let instagram_handle: String?
    let twitter_handle: String?
    let facebook_handle: String?
    let tiktok_handle: String?

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let v = display_name { try container.encode(v, forKey: .display_name) }
        if let v = username { try container.encode(v, forKey: .username) }
        if let v = bio { try container.encode(v, forKey: .bio) }
        if let v = avatar_url { try container.encode(v, forKey: .avatar_url) }
        if let v = avatar_color { try container.encode(v, forKey: .avatar_color) }
        if let v = banner_url { try container.encode(v, forKey: .banner_url) }
        if let v = active_program { try container.encode(v, forKey: .active_program) }
        if let v = date_of_birth { try container.encode(v, forKey: .date_of_birth) }
        if let v = biological_sex { try container.encode(v, forKey: .biological_sex) }
        if let v = height_cm { try container.encode(v, forKey: .height_cm) }
        if let v = is_private { try container.encode(v, forKey: .is_private) }
        if let v = medical_disclaimer_accepted_at { try container.encode(v, forKey: .medical_disclaimer_accepted_at) }
        if let v = instagram_handle { try container.encode(v, forKey: .instagram_handle) }
        if let v = twitter_handle { try container.encode(v, forKey: .twitter_handle) }
        if let v = facebook_handle { try container.encode(v, forKey: .facebook_handle) }
        if let v = tiktok_handle { try container.encode(v, forKey: .tiktok_handle) }
    }
}

final class ProfileService {
    static let shared = ProfileService()

    var cachedDisplayName: String?
    var cachedAvatarUrl: String?

    private var supabase: SupabaseClient {
        SupabaseService.shared.client
    }

    private init() {}

    func fetchProfile(userId: String) async throws -> SupabaseProfile {
        let response: SupabaseProfile = try await supabase
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        cachedDisplayName = response.display_name
        cachedAvatarUrl = response.avatar_url
        return response
    }

    struct FollowCounts: Sendable {
        let followers: Int
        let following: Int
        let friends: Int
    }

    func fetchFollowCounts(userId: String) async throws -> FollowCounts {
        async let followersTask = supabase
            .from("follows")
            .select("follower_id")
            .eq("following_id", value: userId)
            .execute()
        async let followingTask = supabase
            .from("follows")
            .select("following_id")
            .eq("follower_id", value: userId)
            .execute()

        let followersResp = try await followersTask
        let followingResp = try await followingTask

        let followerRows = (try? JSONDecoder().decode([FollowerRow].self, from: followersResp.data)) ?? []
        let followingRows = (try? JSONDecoder().decode([FollowingRow].self, from: followingResp.data)) ?? []

        let followerIds = Set(followerRows.map { $0.follower_id })
        let followingIds = Set(followingRows.map { $0.following_id })
        let mutuals = followerIds.intersection(followingIds)

        return FollowCounts(
            followers: followerIds.count,
            following: followingIds.count,
            friends: mutuals.count
        )
    }

    private nonisolated struct FollowerRow: Codable, Sendable { let follower_id: String }
    private nonisolated struct FollowingRow: Codable, Sendable { let following_id: String }

    func updateProfile(userId: String, update: ProfileUpdate) async throws {
        try await supabase
            .from("profiles")
            .update(update)
            .eq("id", value: userId)
            .execute()
    }

    func uploadAvatar(userId: String, imageData: Data) async throws -> String {
        let fileName = "\(userId)/avatar_\(Int(Date().timeIntervalSince1970)).jpg"

        try await supabase.storage
            .from("avatars")
            .upload(fileName, data: imageData, options: FileOptions(
                cacheControl: "3600",
                contentType: "image/jpeg",
                upsert: true
            ))

        let publicURL = try supabase.storage
            .from("avatars")
            .getPublicURL(path: fileName)

        let urlString = publicURL.absoluteString

        try await updateProfile(userId: userId, update: ProfileUpdate(
            display_name: nil,
            username: nil,
            bio: nil,
            avatar_url: urlString,
            avatar_color: nil,
            banner_url: nil,
            active_program: nil,
            date_of_birth: nil,
            biological_sex: nil,
            height_cm: nil,
            is_private: nil,
            medical_disclaimer_accepted_at: nil,
            instagram_handle: nil,
            twitter_handle: nil,
            facebook_handle: nil,
            tiktok_handle: nil
        ))

        return urlString
    }

    func uploadBanner(userId: String, imageData: Data) async throws -> String {
        let fileName = "\(userId)/banner_\(Int(Date().timeIntervalSince1970)).jpg"

        try await supabase.storage
            .from("banners")
            .upload(fileName, data: imageData, options: FileOptions(
                cacheControl: "3600",
                contentType: "image/jpeg",
                upsert: true
            ))

        let publicURL = try supabase.storage
            .from("banners")
            .getPublicURL(path: fileName)

        let urlString = publicURL.absoluteString

        try await updateProfile(userId: userId, update: ProfileUpdate(
            display_name: nil,
            username: nil,
            bio: nil,
            avatar_url: nil,
            avatar_color: nil,
            banner_url: urlString,
            active_program: nil,
            date_of_birth: nil,
            biological_sex: nil,
            height_cm: nil,
            is_private: nil,
            medical_disclaimer_accepted_at: nil,
            instagram_handle: nil,
            twitter_handle: nil,
            facebook_handle: nil,
            tiktok_handle: nil
        ))

        return urlString
    }

    func removeBanner(userId: String) async throws {
        try await updateProfile(userId: userId, update: ProfileUpdate(
            display_name: nil,
            username: nil,
            bio: nil,
            avatar_url: nil,
            avatar_color: nil,
            banner_url: "",
            active_program: nil,
            date_of_birth: nil,
            biological_sex: nil,
            height_cm: nil,
            is_private: nil,
            medical_disclaimer_accepted_at: nil,
            instagram_handle: nil,
            twitter_handle: nil,
            facebook_handle: nil,
            tiktok_handle: nil
        ))
    }
}
