import SwiftUI

struct PRToastView: View {
    let prs: [PRTracker.PRHit]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.yellow)
                    .symbolEffect(.bounce, value: prs.count)
                Text(prs.count == 1 ? "New Personal Record!" : "\(prs.count) New PRs!")
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
            }
            ForEach(Array(prs.enumerated()), id: \.offset) { _, hit in
                HStack(spacing: 6) {
                    Image(systemName: icon(for: hit.kind))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PepTheme.teal)
                    Text(hit.exerciseName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(1)
                    Text(description(for: hit))
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [Color.yellow.opacity(0.15), PepTheme.cardSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.yellow.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
    }

    private func icon(for kind: PRTracker.PRHit.Kind) -> String {
        switch kind {
        case .weight: "scalemass.fill"
        case .oneRepMax: "bolt.fill"
        case .volume: "chart.bar.fill"
        }
    }

    private func description(for hit: PRTracker.PRHit) -> String {
        let formatted = hit.newValue.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(hit.newValue))"
            : String(format: "%.1f", hit.newValue)
        switch hit.kind {
        case .weight: return "\(formatted) lbs"
        case .oneRepMax: return "\(formatted) lbs 1RM"
        case .volume: return "\(formatted) lbs volume"
        }
    }
}
