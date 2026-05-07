import Foundation
import Supabase

nonisolated struct SeedTestFriendsResponse: Codable, Sendable {
    let ok: Bool?
    let version: String?
    let created: Int?
    let existed: Int?
    let total_test_profiles: Int?
    let followed: Int?
    let deleted: Int?
    let error: String?
    let error_details: [String]?
    let action: String?
}

nonisolated struct SuperActionRequest: Codable, Sendable {
    let action: String
    let payload: Payload?

    nonisolated struct Payload: Codable, Sendable {
        let count: Int?
    }
}

final class TestFriendsService {
    static let shared = TestFriendsService()
    private init() {}

    private var supabase: SupabaseClient { SupabaseService.shared.client }

    private static let presenceSlugs = ["marcus", "finn"]

    func seed(count: Int = 15) async throws -> SeedTestFriendsResponse {
        let body = SuperActionRequest(action: "seedTestFriends", payload: .init(count: count))
        let res: SeedTestFriendsResponse = try await supabase.functions
            .invoke("super-action", options: FunctionInvokeOptions(body: body))
        if res.version != "seed-v2" {
            throw NSError(domain: "TestFriendsService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Edge function 'super-action' is out of date. Redeploy it from supabase/functions/super-action."])
        }
        if let err = res.error, !err.isEmpty {
            throw NSError(domain: "TestFriendsService", code: 0, userInfo: [NSLocalizedDescriptionKey: err])
        }
        await seedLocalPresence()
        return res
    }

    /// Lightweight call right after signup. Ensures caller is mutually
    /// followed with every fake persona that already exists, and triggers a
    /// full seed if the global pool is empty. Safe to call repeatedly.
    func bootstrapFollows() async throws -> SeedTestFriendsResponse {
        let body = SuperActionRequest(action: "bootstrapFakeFollows", payload: nil)
        let res: SeedTestFriendsResponse = try await supabase.functions
            .invoke("super-action", options: FunctionInvokeOptions(body: body))
        return res
    }

    func remove() async throws -> SeedTestFriendsResponse {
        let body = SuperActionRequest(action: "clearTestFriends", payload: nil)
        let res: SeedTestFriendsResponse = try await supabase.functions
            .invoke("super-action", options: FunctionInvokeOptions(body: body))
        if res.version != "seed-v2" {
            throw NSError(domain: "TestFriendsService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Edge function 'super-action' is out of date. Redeploy it."])
        }
        if let err = res.error, !err.isEmpty {
            throw NSError(domain: "TestFriendsService", code: 0, userInfo: [NSLocalizedDescriptionKey: err])
        }
        return res
    }

    @MainActor
    private func seedLocalPresence() async {
        guard let myId = try? AuthService.shared.currentUserId() else { return }
        let following = (try? await MessagingService.shared.fetchFollowing(userId: myId)) ?? []
        guard !following.isEmpty else { return }

        let profiles = (try? await MessagingService.shared.fetchProfilesByIds(following)) ?? []
        let activities = ["Workout", "Running"]
        var i = 0
        for profile in profiles {
            guard let slug = Self.presenceSlugs.first(where: { profile.username?.lowercased().contains($0) == true }) else { continue }
            FriendSocialService.shared.setPresence(friendId: profile.id, activity: activities[i % activities.count])
            i += 1
        }
    }
}
