import SwiftUI

struct LeaderboardView: View {
    let entries: [LeaderboardEntry]
    @Binding var selectedPeriod: LeaderboardPeriod

    var body: some View {
        VStack(spacing: 20) {
            Picker("Period", selection: $selectedPeriod) {
                ForEach(LeaderboardPeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if entries.count >= 3 {
                podiumView
            }

            let remaining = entries.count >= 3 ? Array(entries.dropFirst(3)) : entries
            if !remaining.isEmpty {
                VStack(spacing: 2) {
                    ForEach(remaining) { entry in
                        LeaderboardRow(entry: entry)
                    }
                }
                .background(PepTheme.cardSurface.opacity(0.5))
                .clipShape(.rect(cornerRadius: 16))
                .padding(.horizontal)
            }
        }
    }

    private var podiumView: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if entries.count >= 2 {
                podiumUser(entry: entries[1], height: 100, crown: false)
            }
            if entries.count >= 1 {
                podiumUser(entry: entries[0], height: 130, crown: true)
            }
            if entries.count >= 3 {
                podiumUser(entry: entries[2], height: 80, crown: false)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private func podiumUser(entry: LeaderboardEntry, height: CGFloat, crown: Bool) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .top) {
                Circle()
                    .fill(entry.user.avatarColor.opacity(0.2))
                    .frame(width: crown ? 64 : 50, height: crown ? 64 : 50)
                    .overlay {
                        Text(entry.user.avatarInitial)
                            .font(.system(crown ? .title2 : .headline, design: .rounded, weight: .bold))
                            .foregroundStyle(entry.user.avatarColor)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Text("\(entry.rank)")
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(entry.rank == 1 ? PepTheme.amber : PepTheme.elevated)
                            .clipShape(.circle)
                    }

                if crown {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(PepTheme.amber)
                        .offset(y: -22)
                }
            }

            Text(entry.user.name.components(separatedBy: " ").first ?? "")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)

            Text(formatFP(entry.fp))
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.teal)

            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            entry.rank == 1 ? PepTheme.amber.opacity(0.3) : PepTheme.teal.opacity(0.15),
                            entry.rank == 1 ? PepTheme.amber.opacity(0.1) : PepTheme.teal.opacity(0.05),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: height)
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            entry.rank == 1 ? PepTheme.amber.opacity(0.3) : PepTheme.teal.opacity(0.15),
                            lineWidth: 0.5
                        )
                }
        }
        .frame(maxWidth: .infinity)
    }

    private func formatFP(_ fp: Int) -> String {
        if fp >= 1000 {
            return String(format: "%.1fk FP", Double(fp) / 1000.0)
        }
        return "\(fp) FP"
    }
}

private struct LeaderboardRow: View {
    let entry: LeaderboardEntry

    var body: some View {
        HStack(spacing: 12) {
            Text("\(entry.rank)")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textSecondary)
                .frame(width: 28)

            Circle()
                .fill(entry.user.avatarColor.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay {
                    Text(entry.user.avatarInitial)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(entry.user.avatarColor)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.user.name)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)

                HStack(spacing: 8) {
                    if let program = entry.user.activeProgramName {
                        Text(program)
                            .font(.caption2)
                            .foregroundStyle(PepTheme.teal.opacity(0.8))
                    }
                    if entry.user.streak > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 9))
                            Text("\(entry.user.streak)")
                                .font(.caption2)
                        }
                        .foregroundStyle(PepTheme.amber.opacity(0.8))
                    }
                }
            }

            Spacer()

            Text("\(entry.fp) FP")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.teal)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
