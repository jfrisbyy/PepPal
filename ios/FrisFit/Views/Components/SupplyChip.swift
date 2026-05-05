import SwiftUI

struct SupplyChip: View {
    let forecast: SupplyForecast
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: compact ? 8 : 9, weight: .bold))
            Text(forecast.chipLabel)
                .font(.system(size: compact ? 9 : 10, weight: .heavy))
                .lineLimit(1)
        }
        .foregroundStyle(forecast.chipColor)
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 2 : 3)
        .background(forecast.chipColor.opacity(0.14))
        .clipShape(.capsule)
        .overlay(
            Capsule()
                .strokeBorder(forecast.chipColor.opacity(0.25), lineWidth: 0.5)
        )
    }

    private var icon: String {
        if forecast.dosesRemaining == 0 { return "xmark.circle.fill" }
        if forecast.daysRemaining <= 3 { return "exclamationmark.triangle.fill" }
        if forecast.daysRemaining <= 14 { return "hourglass" }
        return "checkmark.seal.fill"
    }
}
