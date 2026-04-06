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
    let active_program: String?
    let total_fp: Int?
    let current_streak: Int?
    let total_workouts: Int?
    let member_since: String?
    let follower_count: Int?
    let following_count: Int?
    let friend_count: Int?
}

nonisolated struct ProfileUpdate: Codable, Sendable {
    let display_name: String?
    let username: String?
    let bio: String?
    let avatar_url: String?
    let avatar_color: String?
    let active_program: String?
}

final class ProfileService {
    static let shared = ProfileService()

    var cachedDisplayName: String?

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
        return response
    }

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
            active_program: nil
        ))

        return urlString
    }
}
