import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var authService = AuthService.shared
    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showError: Bool = false
    @State private var showSuccess: Bool = false

    private var isFormValid: Bool {
        !fullName.isEmpty && !email.isEmpty && !password.isEmpty && password == confirmPassword && password.count >= 6
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("Create Account")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)

                    Text("Join FrisFit and start your fitness journey")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                VStack(spacing: 16) {
                    AuthTextField(label: "Full Name", placeholder: "John Doe", text: $fullName, contentType: .name)
                        .textInputAutocapitalization(.words)

                    AuthTextField(label: "Email", placeholder: "you@example.com", text: $email, contentType: .emailAddress, keyboardType: .emailAddress)
                        .textInputAutocapitalization(.never)

                    AuthSecureField(label: "Password", placeholder: "Minimum 6 characters", text: $password, contentType: .newPassword)

                    VStack(alignment: .leading, spacing: 6) {
                        AuthSecureField(label: "Confirm Password", placeholder: "Re-enter your password", text: $confirmPassword, contentType: .newPassword)

                        if !confirmPassword.isEmpty && password != confirmPassword {
                            Text("Passwords do not match")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }

                Button {
                    signUp()
                } label: {
                    Group {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Create Account")
                                .font(.body.weight(.semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [PepTheme.teal, PepTheme.teal.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(.rect(cornerRadius: 14))
                }
                .disabled(!isFormValid || isLoading)
                .opacity(isFormValid ? 1 : 0.6)

                HStack(spacing: 4) {
                    Text("Already have an account?")
                        .foregroundStyle(PepTheme.textSecondary)
                    Button("Sign In") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(PepTheme.teal)
                }
                .font(.subheadline)
            }
            .padding(.horizontal, 24)
        }
        .background(PepTheme.background)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Sign Up Failed", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
        .alert("Check Your Email", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("We sent a confirmation link to \(email). Please verify your email to sign in.")
        }
    }

    private func signUp() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await authService.signUp(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password,
                    fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                showSuccess = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }
}

private struct AuthTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var contentType: UITextContentType?
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PepTheme.textSecondary)

            TextField(placeholder, text: $text)
                .textContentType(contentType)
                .keyboardType(keyboardType)
                .autocorrectionDisabled()
                .padding(14)
                .background(PepTheme.elevated)
                .clipShape(.rect(cornerRadius: 12))
        }
    }
}

private struct AuthSecureField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var contentType: UITextContentType?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PepTheme.textSecondary)

            SecureField(placeholder, text: $text)
                .textContentType(contentType)
                .padding(14)
                .background(PepTheme.elevated)
                .clipShape(.rect(cornerRadius: 12))
        }
    }
}
