import SwiftUI

struct AIInsightStrip: View {
    let content: String
    let color: Color
    var actionLabel: String? = nil
    var actionIcon: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Rectangle()
                    .fill(color)
                    .frame(width: 2)
                    .padding(.vertical, 1)

                Text(content)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PepTheme.textPrimary.opacity(0.82))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let label = actionLabel, let action = onAction {
                Button {
                    action()
                } label: {
                    HStack(spacing: 6) {
                        if let icon = actionIcon {
                            Image(systemName: icon)
                                .font(.system(size: 11, weight: .bold))
                        }
                        Text(label)
                            .font(.system(.caption, weight: .bold))
                    }
                    .foregroundStyle(color)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(color.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(color.opacity(0.2), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.scale)
                .sensoryFeedback(.impact(weight: .medium), trigger: label)
            }
        }
        .padding(10)
        .background(color.opacity(0.06))
        .clipShape(.rect(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(color.opacity(0.12), lineWidth: 0.5)
        )
    }
}
