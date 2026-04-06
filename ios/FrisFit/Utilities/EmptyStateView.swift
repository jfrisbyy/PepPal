import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [FrisTheme.cyan.opacity(0.08), FrisTheme.cyan.opacity(0.01)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: icon)
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [FrisTheme.cyan.opacity(0.6), FrisTheme.cyan.opacity(0.25)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(FrisTheme.textPrimary)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(FrisTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 260)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(FrisTheme.cyan, in: Capsule())
                }
                .buttonStyle(.scale)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
