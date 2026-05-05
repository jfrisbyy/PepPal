import SwiftUI

struct AgeBlockedView: View {
    let onSupport: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(PepTheme.amber.opacity(0.16))
                    .frame(width: 96, height: 96)
                Image(systemName: "person.crop.circle.badge.exclamationmark.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(PepTheme.amber)
            }

            VStack(spacing: 12) {
                Text("EPTI is 18+ for now")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Thanks for checking us out. Right now EPTI is only available to people who are 18 or older. If this looks like a mistake — or if you have any questions — we'd love to hear from you.")
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 10) {
                Button(action: onSupport) {
                    HStack(spacing: 8) {
                        Image(systemName: "envelope.fill")
                            .font(.subheadline)
                        Text("Contact Support")
                            .font(.system(.headline, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(PepTheme.teal)
                    .clipShape(.rect(cornerRadius: 16))
                }
                .buttonStyle(.plain)

                Button(action: onBack) {
                    Text("Update my date of birth")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}
