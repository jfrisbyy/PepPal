import SwiftUI

struct LoginView: View {
    @State private var authService = AuthService.shared
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var showSignUp: Bool = false
    @State private var showForgotPassword: Bool = false
    @State private var errorMessage: String?
    @State private var showError: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    Spacer().frame(height: 40)

                    VStack(spacing: 12) {
                        Image(systemName: "figure.run.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [PepTheme.teal, PepTheme.teal.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("FrisFit")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(PepTheme.textPrimary)

                        Text("Your fitness companion")
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textSecondary)
                    }

                    VStack(spacing: 16) {
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

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(PepTheme.textSecondary)

                            SecureField("Enter your password", text: $password)
                                .textContentType(.password)
                                .padding(14)
                                .background(PepTheme.elevated)
                                .clipShape(.rect(cornerRadius: 12))
                        }

                        HStack {
                            Spacer()
                            Button("Forgot Password?") {
                                showForgotPassword = true
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(PepTheme.teal)
                        }
                    }

                    Button {
                        signIn()
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Sign In")
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
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                    .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1)

                    HStack(spacing: 4) {
                        Text("Don't have an account?")
                            .foregroundStyle(PepTheme.textSecondary)
                        Button("Sign Up") {
                            showSignUp = true
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(PepTheme.teal)
                    }
                    .font(.subheadline)
                }
                .padding(.horizontal, 24)
            }
            .background(PepTheme.background)
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView()
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView()
            }
            .alert("Sign In Failed", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred.")
            }
        }
    }

    private func signIn() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await authService.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }
}
