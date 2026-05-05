import SwiftUI

struct LowStockBanner: View {
    let forecasts: [SupplyForecast]
    var onTap: () -> Void

    var body: some View {
        if forecasts.isEmpty {
            EmptyView()
        } else {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(worstColor.opacity(0.18))
                            .frame(width: 40, height: 40)
                        Image(systemName: "hourglass.bottomhalf.filled")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(worstColor)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(PepTheme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
                }
                .padding(12)
                .background(worstColor.opacity(0.08))
                .clipShape(.rect(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(worstColor.opacity(0.3), lineWidth: 0.75)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var worst: SupplyForecast? { forecasts.first }
    private var worstColor: Color { worst?.chipColor ?? PepTheme.amber }

    private var title: String {
        if forecasts.count == 1, let f = worst {
            return "\(f.compoundName) running low"
        }
        return "\(forecasts.count) compounds running low"
    }

    private var subtitle: String {
        guard let f = worst else { return "" }
        if forecasts.count == 1 {
            return "About \(f.chipLabel.lowercased()) at current dose"
        }
        let names = forecasts.prefix(2).map(\.compoundName).joined(separator: ", ")
        return "Tap to reorder — \(names)\(forecasts.count > 2 ? "…" : "")"
    }
}
