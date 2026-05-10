import Foundation
import Supabase
import Auth

nonisolated enum AuthState: Sendable {
    case loading
    case signedOut
    case signedIn
}

@Observable
final class AuthService {
    static let shared = AuthService()

    var authState: AuthState = .loading
    var session: Session?
    var errorMessage: String?

    private var authStateTask: Task<Void, Never>?

    private var supabase: SupabaseClient {
        SupabaseService.shared.client
    }

    private init() {
        setupAuthListener()
    }

    deinit {
        authStateTask?.cancel()
    }

    private var lastBroadcastUserId: String? = nil

    private func setupAuthListener() {
        authStateTask = Task { [weak self] in
            for await (event, session) in SupabaseService.shared.client.auth.authStateChanges {
                guard let self else { return }
                await MainActor.run {
                    self.session = session
                    switch event {
                    case .initialSession:
                        self.authState = session != nil ? .signedIn : .signedOut
                    case .signedIn:
                        self.authState = .signedIn
                    case .signedOut:
                        self.authState = .signedOut
                    case .tokenRefreshed:
                        break
                    case .userUpdated:
                        break
                    case .passwordRecovery:
                        break
                    case .mfaChallengeVerified:
                        break
                    default:
                        break
                    }
                    let newUserId = session?.user.id.uuidString.lowercased()
                    if newUserId != self.lastBroadcastUserId {
                        let previousUserId = self.lastBroadcastUserId
                        self.lastBroadcastUserId = newUserId
                        // Account switch (or sign-out): scrub the previous
                        // user's locally-persisted state before broadcasting
                        // so observers reload fresh data for the new id.
                        // Skip the very first transition from `nil → user`
                        // on app launch (initialSession) — there's no prior
                        // user to clean up after.
                        if previousUserId != nil {
                            LocalStateResetCoordinator.purgeUserScopedState(previousUserId: previousUserId)
                        }
                        var info: [AnyHashable: Any] = [:]
                        if let newUserId { info["userId"] = newUserId }
                        if let previousUserId { info["previousUserId"] = previousUserId }
                        NotificationCenter.default.post(name: .authUserChanged, object: nil, userInfo: info)
                    }
                }
            }
        }
    }

    @discardableResult
    func signUp(email: String, password: String, fullName: String) async throws -> String {
        errorMessage = nil
        let response = try await supabase.auth.signUp(
            email: email,
            password: password,
            data: ["full_name": .string(fullName)]
        )
        // The auth-state listener updates `self.session` asynchronously, so
        // anything that runs immediately after sign-up could otherwise read
        // the *previous* user's id and clobber that account's profile row.
        // Update the cache synchronously here from the SDK response.
        let newUserId = response.user.id
        if let session = response.session {
            self.session = session
            self.authState = .signedIn
            if self.lastBroadcastUserId != newUserId.uuidString.lowercased() {
                self.lastBroadcastUserId = newUserId.uuidString.lowercased()
                NotificationCenter.default.post(
                    name: .authUserChanged,
                    object: nil,
                    userInfo: ["userId": newUserId.uuidString.lowercased()]
                )
            }
        }
        let lowerId = newUserId.uuidString.lowercased()
        // Personas are seeded once globally via Developer Settings — new
        // sign-ups are not auto-connected to them. Users discover personas
        // organically through Community / Discover / search.
        return lowerId
    }

    func signIn(email: String, password: String) async throws {
        errorMessage = nil
        try await supabase.auth.signIn(email: email, password: password)
    }

    func signOut() async throws {
        errorMessage = nil
        // Capture the current user id BEFORE the network round-trip so we can
        // wipe their per-user caches even if the auth-state listener fires
        // before our continuation resumes.
        let previousUserId = try? currentUserId()
        // Tear down every Realtime subscription before we sign out so we never
        // leave the previous user's channels open under a new session.
        await RealtimeLifecycleCoordinator.shared.unsubscribeAll()
        try await supabase.auth.signOut()
        LocalStateResetCoordinator.purgeUserScopedState(previousUserId: previousUserId)
    }

    func resetPassword(email: String) async throws {
        errorMessage = nil
        try await supabase.auth.resetPasswordForEmail(email)
    }

    /// Recover from a stale JWT (e.g. project's JWT signing keys were rotated
    /// — PostgREST returns PGRST301 "No suitable key or wrong key type").
    /// Tries a session refresh first; if that also fails, signs out so the next
    /// sign-in mints a token under the current signing key.
    /// Returns true if the session was successfully refreshed and callers can retry.
    @discardableResult
    func recoverFromInvalidJWT() async -> Bool {
        do {
            _ = try await supabase.auth.refreshSession()
            print("[AuthService] Session refreshed after invalid-JWT error")
            return true
        } catch {
            print("[AuthService] Refresh failed after invalid-JWT (\(error)). Signing out.")
            try? await supabase.auth.signOut()
            await MainActor.run {
                self.session = nil
                self.authState = .signedOut
                self.errorMessage = "Your session expired. Please sign in again."
                DebugBanner.shared.log(.error, "Session expired", "Please sign in again to continue syncing.")
            }
            return false
        }
    }

    /// Returns true if the given error looks like a stale-JWT / signing-key
    /// mismatch coming back from PostgREST (PGRST301).
    nonisolated static func isInvalidJWTError(_ error: Error) -> Bool {
        let desc = String(describing: error).lowercased()
        if desc.contains("pgrst301") { return true }
        if desc.contains("no suitable key") { return true }
        if desc.contains("wrong key type") { return true }
        if desc.contains("jwt expired") { return true }
        if desc.contains("invalid jwt") { return true }
        return false
    }

    func currentUserId() throws -> String {
        // Prefer the SDK's authoritative current session (updated synchronously
        // by sign-up / sign-in / OAuth callbacks) over our cached `session`,
        // which only updates when the auth-state listener task runs. Without
        // this, the first profile write right after creating a brand-new
        // account could be attributed to the *previous* signed-in user.
        if let sdkUser = supabase.auth.currentUser {
            return sdkUser.id.uuidString.lowercased()
        }
        if let session {
            return session.user.id.uuidString.lowercased()
        }
        throw NSError(domain: "AuthService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
    }
}
