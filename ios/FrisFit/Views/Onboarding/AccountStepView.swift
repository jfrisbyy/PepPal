import SwiftUI
import AuthenticationServices
import CryptoKit
import Supabase
import Auth

struct AccountStepView: View {
    @Bindable var state: OnboardingState
    let onCreated: () -> Void
    var onSignIn: (() -> Void)? = nil

    @State private var showPassword: Bool = false
    @State private var currentNonce: String?
    @State private var showSignInSheet: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Create your account")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("You'll use this to sign in across devices.")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                SignInWithAppleButton(.signUp) { request in
                    let nonce = randomNonce()
                    currentNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = sha256(nonce)
                } onCompletion: { result in
                    handleAppleResult(result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 52)
                .clipShape(.rect(cornerRadius: 14))

                HStack(spacing: 10) {
                    Rectangle().fill(PepTheme.glassBorderBottom).frame(height: 0.5)
                    Text("or")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                    Rectangle().fill(PepTheme.glassBorderBottom).frame(height: 0.5)
                }

                VStack(spacing: 14) {
                    field(label: "Email", placeholder: "you@example.com") {
                        TextField("you@example.com", text: $state.email)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                    }

                    field(label: "Password", placeholder: "Minimum 6 characters") {
                        Group {
                            if showPassword {
                                TextField("Password", text: $state.password)
                            } else {
                                SecureField("Password", text: $state.password)
                            }
                        }
                        .textContentType(.newPassword)
                        .overlay(alignment: .trailing) {
                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                            .padding(.trailing, 4)
                        }
                    }
                }

                if let error = state.errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                        if errorSuggestsExistingAccount(error) {
                            Button {
                                openSignIn()
                            } label: {
                                Text("Sign in to that account instead")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(PepTheme.teal)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    Task { await createAccount() }
                } label: {
                    HStack {
                        if state.isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Create Account")
                                .font(.system(.headline, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(state.canAdvance(from: .account) ? PepTheme.teal : PepTheme.elevated)
                    .clipShape(.rect(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .disabled(!state.canAdvance(from: .account) || state.isSubmitting)
                .animation(.easeInOut(duration: 0.2), value: state.canAdvance(from: .account))

                consentLine

                Button {
                    openSignIn()
                } label: {
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .foregroundStyle(PepTheme.textSecondary)
                        Text("Sign in")
                            .foregroundStyle(PepTheme.teal)
                            .fontWeight(.semibold)
                    }
                    .font(.footnote)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .sheet(isPresented: $showSignInSheet) {
            OnboardingSignInSheet(prefillEmail: state.email) {
                showSignInSheet = false
                onCreated()
            }
        }
    }

    private var consentLine: some View {
        let base = Text("By continuing you agree to our ")
            .foregroundStyle(PepTheme.textSecondary)
        let privacy = Text("[Privacy Policy](https://peppalapp.com/privacy)")
            .foregroundStyle(PepTheme.teal)
        let and = Text(" and ")
            .foregroundStyle(PepTheme.textSecondary)
        let terms = Text("[Terms](https://peppalapp.com/terms)")
            .foregroundStyle(PepTheme.teal)
        let dot = Text(".")
            .foregroundStyle(PepTheme.textSecondary)
        return (base + privacy + and + terms + dot)
            .font(.footnote)
            .multilineTextAlignment(.center)
            .tint(PepTheme.teal)
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
    }

    private func errorSuggestsExistingAccount(_ error: String) -> Bool {
        let lower = error.lowercased()
        return lower.contains("already") || lower.contains("exists") || lower.contains("registered") || lower.contains("taken")
    }

    private func openSignIn() {
        UISelectionFeedbackGenerator().selectionChanged()
        if let onSignIn {
            onSignIn()
        } else {
            showSignInSheet = true
        }
    }

    private func field<Content: View>(label: String, placeholder: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PepTheme.textSecondary)
            content()
                .padding(14)
                .background(PepTheme.elevated)
                .clipShape(.rect(cornerRadius: 12))
                .foregroundStyle(PepTheme.textPrimary)
        }
    }

    private func createAccount() async {
        state.errorMessage = nil
        state.isSubmitting = true
        defer { state.isSubmitting = false }

        let email = state.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayNameSeed = email.split(separator: "@").first.map(String.init) ?? ""

        do {
            try await AuthService.shared.signUp(email: email, password: state.password, fullName: displayNameSeed)
            try? await Task.sleep(for: .milliseconds(400))
            await persistInitialProfile(username: nil, displayName: displayNameSeed)
            await persistDisclaimerIfNeeded()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onCreated()
        } catch {
            state.errorMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        Task {
            state.errorMessage = nil
            state.isSubmitting = true
            defer { state.isSubmitting = false }

            switch result {
            case .failure(let error):
                state.errorMessage = error.localizedDescription
            case .success(let auth):
                guard
                    let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                    let tokenData = credential.identityToken,
                    let token = String(data: tokenData, encoding: .utf8),
                    let nonce = currentNonce
                else {
                    state.errorMessage = "Apple sign-in failed."
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
                    await persistInitialProfile(
                        username: nil,
                        displayName: nameSeed
                    )
                    await persistDisclaimerIfNeeded()
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    onCreated()
                } catch {
                    state.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func persistInitialProfile(username: String?, displayName: String) async {
        guard let userId = try? AuthService.shared.currentUserId() else { return }
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let update = ProfileUpdate(
            display_name: trimmedName.isEmpty ? nil : trimmedName,
            username: username,
            bio: nil,
            avatar_url: nil,
            avatar_color: nil,
            banner_url: nil,
            active_program: nil,
            date_of_birth: nil,
            biological_sex: nil,
            height_cm: nil,
            is_private: nil,
            medical_disclaimer_accepted_at: nil
        )
        try? await ProfileService.shared.updateProfile(userId: userId, update: update)

        if let persona = state.personaTrack {
            await OnboardingManager.persistPersona(persona)
        }
    }

    private func persistDisclaimerIfNeeded() async {
        guard let acceptedAt = state.disclaimerAcceptedAt else { return }
        await OnboardingManager.persistDisclaimerAcknowledgement(
            version: state.disclaimerVersion,
            acceptedAt: acceptedAt
        )
    }

    private func randomNonce(length: Int = 32) -> String {
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

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
