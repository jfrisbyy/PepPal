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
                }
            }
        }
    }

    func signUp(email: String, password: String, fullName: String) async throws {
        errorMessage = nil
        _ = try await supabase.auth.signUp(
            email: email,
            password: password,
            data: ["full_name": .string(fullName)]
        )
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
}
