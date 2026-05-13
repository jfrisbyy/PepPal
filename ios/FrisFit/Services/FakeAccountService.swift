import Foundation
import Supabase

// MARK: - DTOs

nonisolated struct FakeUserItem: Codable, Sendable, Identifiable {
    let id: String
    let display_name: String?
    let username: String?
    let avatar_url: String?
    let avatar_color: String?
    let current_streak: Int?
    let total_fp: Int?
    let updated_at: String?
    let email: String?
    let archetype_label: String?
    let archetype_tagline: String?
}

nonisolated struct FakeUserListResponse: Codable, Sendable {
    let ok: Bool?
    let version: String?
    let items: [FakeUserItem]?
    let error: String?
}

nonisolated struct FakeUserCreateResponse: Codable, Sendable {
    let ok: Bool?
    let version: String?
    let user_id: String?
    let email: String?
    let password: String?
    let display_name: String?
    let username: String?
    let error: String?
    let populated: Int?
    let populate_level: String?
}

nonisolated struct FakeUserPasswordResponse: Codable, Sendable {
    let ok: Bool?
    let user_id: String?
    let email: String?
    let password: String?
    let error: String?
}

nonisolated struct FakeUserActivityResponse: Codable, Sendable {
    let ok: Bool?
    let inserted: Int?
    let error: String?
}

nonisolated struct FakeUserDeleteResponse: Codable, Sendable {
    let ok: Bool?
    let deleted_user_id: String?
    let error: String?
}

nonisolated struct FakeBulkPopulateResponse: Codable, Sendable {
    let ok: Bool?
    let fakes: Int?
    let posts_added: Int?
    let likes: Int?
    let comments: Int?
    let groups_created: Int?
    let group_messages: Int?
    let dm_pairs: Int?
    let dm_messages: Int?
    let error: String?
}

private nonisolated struct FakeActionRequest: Codable, Sendable {
    let action: String
    let payload: Payload?

    nonisolated struct Payload: Codable, Sendable {
        var user_id: String?
        var display_name: String?
        var username: String?
        var follow_caller: Bool?
        var count: Int?
        var days_back: Int?
        var populate_level: String?
        var archetype: String?
        var level: String?
    }
}

// MARK: - Stash for switch-back

/// Persists the operator's real session refresh+access tokens in the
/// keychain so we can restore them after impersonating a fake account.
nonisolated final class OriginalSessionStash: @unchecked Sendable {
    static let shared = OriginalSessionStash()
    private init() {}

    private let service = "peppal.fakeaccount.original-session"
    private let accountKey = "session"

    private struct Stash: Codable {
        let userId: String
        let email: String?
        let accessToken: String
        let refreshToken: String
        let stashedAt: Date
    }

    func save(userId: String, email: String?, accessToken: String, refreshToken: String) {
        let stash = Stash(userId: userId, email: email, accessToken: accessToken, refreshToken: refreshToken, stashedAt: Date())
        guard let data = try? JSONEncoder().encode(stash) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }

    func load() -> (userId: String, email: String?, accessToken: String, refreshToken: String)? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let stash = try? JSONDecoder().decode(Stash.self, from: data)
        else { return nil }
        return (stash.userId, stash.email, stash.accessToken, stash.refreshToken)
    }

    func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey
        ]
        SecItemDelete(query as CFDictionary)
    }

    var hasStash: Bool { load() != nil }
}

// MARK: - Service

@MainActor
final class FakeAccountService {
    static let shared = FakeAccountService()
    private init() {}

    private var supabase: SupabaseClient { SupabaseService.shared.client }

    func list() async throws -> [FakeUserItem] {
        let body = FakeActionRequest(action: "listFakeUsers", payload: nil)
        let res: FakeUserListResponse = try await supabase.functions
            .invoke("super-action", options: FunctionInvokeOptions(body: body))
        if let err = res.error, !err.isEmpty {
            throw NSError(domain: "FakeAccountService", code: 0, userInfo: [NSLocalizedDescriptionKey: err])
        }
        return res.items ?? []
    }

    func create(
        displayName: String?,
        username: String?,
        followCaller: Bool = true,
        populateLevel: String = "light",
        archetype: String? = nil
    ) async throws -> FakeUserCreateResponse {
        var payload = FakeActionRequest.Payload(
            user_id: nil,
            display_name: displayName?.isEmpty == false ? displayName : nil,
            username: username?.isEmpty == false ? username : nil,
            follow_caller: followCaller,
            count: nil,
            days_back: nil
        )
        payload.populate_level = populateLevel
        payload.archetype = archetype
        let body = FakeActionRequest(action: "createFakeUser", payload: payload)
        let res: FakeUserCreateResponse = try await supabase.functions
            .invoke("super-action", options: FunctionInvokeOptions(body: body))
        if let err = res.error, !err.isEmpty {
            throw NSError(domain: "FakeAccountService", code: 0, userInfo: [NSLocalizedDescriptionKey: err])
        }
        return res
    }

    func rotatePassword(userId: String) async throws -> FakeUserPasswordResponse {
        var p = FakeActionRequest.Payload()
        p.user_id = userId
        let body = FakeActionRequest(action: "rotateFakeUserPassword", payload: p)
        let res: FakeUserPasswordResponse = try await supabase.functions
            .invoke("super-action", options: FunctionInvokeOptions(body: body))
        if let err = res.error, !err.isEmpty {
            throw NSError(domain: "FakeAccountService", code: 0, userInfo: [NSLocalizedDescriptionKey: err])
        }
        return res
    }

    func generateActivity(userId: String, count: Int = 3, daysBack: Int = 7) async throws -> Int {
        var p = FakeActionRequest.Payload()
        p.user_id = userId
        p.count = count
        p.days_back = daysBack
        let body = FakeActionRequest(action: "generateFakeActivity", payload: p)
        let res: FakeUserActivityResponse = try await supabase.functions
            .invoke("super-action", options: FunctionInvokeOptions(body: body))
        if let err = res.error, !err.isEmpty {
            throw NSError(domain: "FakeAccountService", code: 0, userInfo: [NSLocalizedDescriptionKey: err])
        }
        return res.inserted ?? 0
    }

    nonisolated struct WipeMyDataResponse: Codable, Sendable {
        let ok: Bool?
        let error: String?
    }

    func wipeMyScreenshotData() async throws {
        let body = FakeActionRequest(action: "wipeMyScreenshotData", payload: nil)
        let res: WipeMyDataResponse = try await supabase.functions
            .invoke("super-action", options: FunctionInvokeOptions(body: body))
        if let err = res.error, !err.isEmpty {
            throw NSError(domain: "FakeAccountService", code: 0, userInfo: [NSLocalizedDescriptionKey: err])
        }
    }

    func bulkPopulateAll(level: String = "medium") async throws -> FakeBulkPopulateResponse {
        var p = FakeActionRequest.Payload()
        p.level = level
        let body = FakeActionRequest(action: "bulkPopulateAllFakes", payload: p)
        let res: FakeBulkPopulateResponse = try await supabase.functions
            .invoke("super-action", options: FunctionInvokeOptions(body: body))
        if let err = res.error, !err.isEmpty {
            throw NSError(domain: "FakeAccountService", code: 0, userInfo: [NSLocalizedDescriptionKey: err])
        }
        return res
    }

    func deleteFake(userId: String) async throws {
        var p = FakeActionRequest.Payload()
        p.user_id = userId
        let body = FakeActionRequest(action: "deleteFakeUser", payload: p)
        let res: FakeUserDeleteResponse = try await supabase.functions
            .invoke("super-action", options: FunctionInvokeOptions(body: body))
        if let err = res.error, !err.isEmpty {
            throw NSError(domain: "FakeAccountService", code: 0, userInfo: [NSLocalizedDescriptionKey: err])
        }
    }

    // MARK: - Switch flows

    /// Stash the operator's current session, then sign in as the fake user.
    /// If a stash already exists (we're already impersonating), it is kept
    /// so the user can always get back to their *real* account.
    func switchTo(userId: String) async throws {
        if !OriginalSessionStash.shared.hasStash {
            let session = try await supabase.auth.session
            OriginalSessionStash.shared.save(
                userId: session.user.id.uuidString.lowercased(),
                email: session.user.email,
                accessToken: session.accessToken,
                refreshToken: session.refreshToken
            )
        }
        let creds = try await rotatePassword(userId: userId)
        guard let email = creds.email, let password = creds.password else {
            throw NSError(domain: "FakeAccountService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing credentials"])
        }
        // Tear down any active realtime channels under the previous session
        await RealtimeLifecycleCoordinator.shared.unsubscribeAll()
        try await supabase.auth.signIn(email: email, password: password)
    }

    /// Restore the operator's real account from the keychain stash. Safe
    /// to call from any signed-in state — the existing session is replaced.
    func switchBackToOriginal() async throws {
        guard let stash = OriginalSessionStash.shared.load() else {
            throw NSError(domain: "FakeAccountService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No original account stashed"])
        }
        await RealtimeLifecycleCoordinator.shared.unsubscribeAll()
        _ = try await supabase.auth.setSession(accessToken: stash.accessToken, refreshToken: stash.refreshToken)
        OriginalSessionStash.shared.clear()
    }

    var isImpersonating: Bool { OriginalSessionStash.shared.hasStash }
    var stashedOriginalEmail: String? { OriginalSessionStash.shared.load()?.email }
}
