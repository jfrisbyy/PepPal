import SwiftUI

struct AIInsightStrip: View {
    let content: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
                .padding(.top, 2)

            Text(content)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PepTheme.textPrimary.opacity(0.82))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.06))
        .clipShape(.rect(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(color.opacity(0.12), lineWidth: 0.5)
        )
    }
}
