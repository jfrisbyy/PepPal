import SwiftUI

struct ProactiveInsightsBanner: View {
    let insights: [ProactiveInsight]
    @State private var currentIndex: Int = 0

    var body: some View {
        if insights.isEmpty {
            EmptyView()
        } else {
            let insight = insights[min(currentIndex, insights.count - 1)]
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: insight.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(insight.tint)
                    .frame(width: 32, height: 32)
                    .background(insight.tint.opacity(0.15))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(insight.title)
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(insight.message)
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if insights.count > 1 {
                    Button {
                        withAnimation(.spring) {
                            currentIndex = (currentIndex + 1) % insights.count
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
            }
            .padding(12)
            .background(insight.tint.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(insight.tint.opacity(0.3), lineWidth: 0.5)
            )
            .clipShape(.rect(cornerRadius: 14))
        }
    }
}
