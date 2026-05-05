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
                        self.lastBroadcastUserId = newUserId
                        var info: [AnyHashable: Any] = [:]
                        if let newUserId { info["userId"] = newUserId }
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
        return newUserId.uuidString.lowercased()
    }

    func signIn(email: String, password: String) async throws {
        errorMessage = nil
        try await supabase.auth.signIn(email: email, password: password)
    }

    func signOut() async throws {
        errorMessage = nil
        try await supabase.auth.signOut()
    }

    func resetPassword(email: String) async throws {
        errorMessage = nil
        try await supabase.auth.resetPasswordForEmail(email)
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
