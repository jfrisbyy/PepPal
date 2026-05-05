import SwiftUI
import UIKit

/// Inline sign-in sheet used inside the onboarding account step so a user who
/// already has an account isn't forced to background the app.
struct OnboardingSignInSheet: View {
    let prefillEmail: String
    let onSignedIn: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?
    @State private var showPassword: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Welcome back")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("Sign in and we'll pick up where you left off.")
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 14) {
                        labeledField("Email") {
                            TextField("you@example.com", text: $email)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                        }
                        labeledField("Password") {
                            Group {
                                if showPassword {
                                    TextField("Password", text: $password)
                                } else {
                                    SecureField("Password", text: $password)
                                }
                            }
                            .textContentType(.password)
                            .overlay(alignment: .trailing) {
                                Button { showPassword.toggle() } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundStyle(PepTheme.textSecondary)
                                }
                                .padding(.trailing, 4)
                            }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task { await signIn() }
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView().tint(.white)
                            } else {
                                Text("Sign in")
                                    .font(.system(.headline, weight: .semibold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canSubmit ? PepTheme.teal : PepTheme.elevated)
                        .clipShape(.rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSubmit || isSubmitting)
                }
                .padding(24)
            }
            .appBackground()
            .navigationTitle("Sign in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            if email.isEmpty { email = prefillEmail }
        }
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && password.count >= 6
    }

    private func labeledField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
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

    private func signIn() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await AuthService.shared.signIn(email: trimmed, password: password)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onSignedIn()
        } catch {
            errorMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
