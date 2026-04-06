import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var authService = AuthService.shared
    @State private var email: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showError: Bool = false
    @State private var showSuccess: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                VStack(spacing: 12) {
                    Image(systemName: "lock.rotation")
                        .font(.system(size: 48))
                        .foregroundStyle(PepTheme.teal)

                    Text("Reset Password")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)

                    Text("Enter your email and we'll send you a link to reset your password.")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Email")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(PepTheme.textSecondary)

                    TextField("you@example.com", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(14)
                        .background(PepTheme.elevated)
                        .clipShape(.rect(cornerRadius: 12))
                }

                Button {
                    resetPassword()
                } label: {
                    Group {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Send Reset Link")
                                .font(.body.weight(.semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(PepTheme.teal)
                    .foregroundStyle(.white)
                    .clipShape(.rect(cornerRadius: 14))
                }
                .disabled(isLoading || email.isEmpty)
                .opacity(email.isEmpty ? 0.6 : 1)

                Spacer()
            }
            .padding(.horizontal, 24)
            .background(PepTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred.")
            }
            .alert("Email Sent", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Check your inbox for a password reset link.")
            }
        }
        .presentationDetents([.medium])
    }

    private func resetPassword() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await authService.resetPassword(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
                showSuccess = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }
}
