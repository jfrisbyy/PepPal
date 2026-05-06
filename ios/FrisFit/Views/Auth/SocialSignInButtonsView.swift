import SwiftUI
import AuthenticationServices
import CryptoKit
import Supabase
import Auth

/// Shared Apple + Google sign-in buttons used by both LoginView and SignUpView.
///
/// Both flows resolve to the same Supabase session — `signInWithIdToken` for
/// Apple (native flow, no web view) and `signInWithOAuth` over an
/// ASWebAuthenticationSession for Google. After a successful sign-in we
/// best-effort backfill the profile's display name (only when the row is
/// brand-new and has no name yet).
struct SocialSignInButtonsView: View {
    enum Mode {
        case signIn
        case signUp

        var appleAuthorization: SignInWithAppleButton.Label {
            switch self {
            case .signIn: return .signIn
            case .signUp: return .signUp
            }
        }
    }

    let mode: Mode
    var onCompletion: () -> Void
    var onError: (String) -> Void
    @State private var currentNonce: String?
    @State private var isGoogleLoading: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            SignInWithAppleButton(mode.appleAuthorization) { request in
                let nonce = Self.randomNonce()
                currentNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = Self.sha256(nonce)
            } onCompletion: { result in
                handleAppleResult(result)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .clipShape(.rect(cornerRadius: 14))

            Button {
                Task { await signInWithGoogle() }
            } label: {
                HStack(spacing: 10) {
                    if isGoogleLoading {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: "globe")
                            .font(.body.weight(.semibold))
                    }
                    Text(isGoogleLoading ? "Connecting…" : "Continue with Google")
                        .font(.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .foregroundStyle(.black)
                .background(Color.white)
                .clipShape(.rect(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                )
            }
            .disabled(isGoogleLoading)
        }
    }

    // MARK: - Apple

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        Task {
            switch result {
            case .failure(let error):
                // User-cancellation is not an error worth surfacing.
                if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                    onError(error.localizedDescription)
                }
            case .success(let auth):
                guard
                    let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                    let tokenData = credential.identityToken,
                    let token = String(data: tokenData, encoding: .utf8),
                    let nonce = currentNonce
                else {
                    onError("Apple sign-in failed.")
                    return
                }
                do {
                    try await SupabaseService.shared.client.auth.signInWithIdToken(
                        credentials: .init(provider: .apple, idToken: token, nonce: nonce)
                    )
                    let appleName = [credential.fullName?.givenName, credential.fullName?.familyName]
                        .compactMap { $0 }
                        .joined(separator: " ")
                    let nameSeed = appleName.isEmpty
                        ? (credential.email?.split(separator: "@").first.map(String.init) ?? "")
                        : appleName
                    await Self.backfillProfileNameIfMissing(displayName: nameSeed)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    onCompletion()
                } catch {
                    onError(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Google

    private func signInWithGoogle() async {
        isGoogleLoading = true
        defer { isGoogleLoading = false }
        do {
            let session = try await SupabaseService.shared.client.auth.signInWithOAuth(
                provider: .google,
                redirectTo: URL(string: "epti://login-callback")
            ) { (asSession: ASWebAuthenticationSession) in
                asSession.prefersEphemeralWebBrowserSession = false
            }
            let nameSeed = session.user.userMetadata["full_name"]?.stringValue
                ?? session.user.userMetadata["name"]?.stringValue
                ?? session.user.email?.split(separator: "@").first.map(String.init)
                ?? ""
            await Self.backfillProfileNameIfMissing(displayName: nameSeed)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onCompletion()
        } catch is CancellationError {
            // User dismissed the web sheet — silent.
        } catch {
            let nsError = error as NSError
            // ASWebAuthenticationSession user-cancel: code 1.
            if nsError.domain == "com.apple.AuthenticationServices.WebAuthenticationSession",
               nsError.code == 1 {
                return
            }
            onError(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    /// Best-effort: only fill display_name if the profile row is brand new
    /// and currently has no name set. Never overwrite a chosen name.
    private static func backfillProfileNameIfMissing(displayName: String) async {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let userId = try? AuthService.shared.currentUserId() else { return }
        let existing = try? await ProfileService.shared.fetchProfile(userId: userId)
        if let existing, let current = existing.display_name, !current.isEmpty {
            return
        }
        let update = ProfileUpdate(
            display_name: trimmed,
            username: nil,
            bio: nil,
            avatar_url: nil,
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
        )
        try? await ProfileService.shared.updateProfile(userId: userId, update: update)
    }

    private static func randomNonce(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                return random
            }
            for r in randoms where remaining > 0 {
                if r < charset.count {
                    result.append(charset[Int(r)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
