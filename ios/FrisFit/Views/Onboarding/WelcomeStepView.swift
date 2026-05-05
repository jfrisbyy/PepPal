import SwiftUI

struct WelcomeStepView: View {
    let onContinue: () -> Void
    let onSignIn: () -> Void

    @State private var appeared: Bool = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [PepTheme.teal.opacity(0.25), PepTheme.violet.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 140, height: 140)
                        .blur(radius: 20)

                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [PepTheme.teal, PepTheme.violet],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolEffect(.pulse, options: .repeating)
                }
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)

                VStack(spacing: 14) {
                    Text("Welcome to EPTI")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(PepTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Train smart. Track every signal.\nUnderstand your body like never before.")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(PepTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
            }

            Spacer()

            VStack(spacing: 12) {
                Button(action: onContinue) {
                    Text("Get Started")
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [PepTheme.teal, PepTheme.teal.opacity(0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(.rect(cornerRadius: 16))
                        .shadow(color: PepTheme.teal.opacity(0.35), radius: 16, y: 6)
                }
                .buttonStyle(.plain)

                HStack(spacing: 4) {
                    Text("Already have an account?")
                        .foregroundStyle(PepTheme.textSecondary)
                    Button("Sign in", action: onSignIn)
                        .fontWeight(.semibold)
                        .foregroundStyle(PepTheme.teal)
                }
                .font(.subheadline)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .opacity(appeared ? 1 : 0)
        }
        .padding(.horizontal, 24)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
                appeared = true
            }
        }
    }
}
