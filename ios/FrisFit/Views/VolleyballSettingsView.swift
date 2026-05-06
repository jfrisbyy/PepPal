import SwiftUI

struct VolleyballSettingsView: View {
    @Bindable var volleyballVM: VolleyballViewModel
    @Environment(\.dismiss) private var dismiss

    private let accentColor = Color(red: 0.95, green: 0.30, blue: 0.20)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    heroCard
                    positionSection
                    seasonSummarySection
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .appBackground(accent: accentColor)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(accentColor)
                }
            }
        }
    }

    private var heroCard: some View {
        PepSportCard(accent: accentColor) {
            VStack(alignment: .leading, spacing: 10) {
                Text("VOLLEYBALL · SETTINGS")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.0)
                    .foregroundStyle(accentColor.opacity(0.9))
                Text("Tune your role.")
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .kerning(-0.5)
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Pick your primary position and the dashboard surfaces the stats that actually matter for it.")
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var positionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "Role",
                title: "Primary Position",
                accent: accentColor,
                trailing: AnyView(
                    Text(volleyballVM.primaryPosition.shortName)
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(accentColor)
                )
            )

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(VolleyballPosition.allCases) { pos in
                    let isSelected = volleyballVM.primaryPosition == pos
                    Button {
                        withAnimation(.spring(duration: 0.25)) {
                            volleyballVM.primaryPosition = pos
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: pos.icon)
                                .font(.system(size: 14))
                            Text(pos.shortName)
                                .font(.system(size: 11, weight: .bold))
                            Text(pos.rawValue)
                                .font(.system(size: 7, weight: .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(isSelected ? .black : PepTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isSelected ? accentColor : PepTheme.elevated.opacity(0.5))
                        .clipShape(.rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .editorialCard(accent: accentColor)
    }

    private var seasonSummarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "Season", title: "Summary", accent: PepTheme.amber)

            let gm = volleyballVM.gameMatches
            if gm.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "figure.volleyball")
                            .font(.title2)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                        Text("No matches played yet.")
                            .font(.system(size: 12, design: .serif))
                            .italic()
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
            } else {
                VStack(spacing: 10) {
                    summaryRow(label: "Matches Played", value: "\(volleyballVM.totalMatchesPlayed)")
                    summaryRow(label: "Record", value: "\(volleyballVM.totalWins)W · \(volleyballVM.totalLosses)L")
                    summaryRow(label: "Win Rate", value: String(format: "%.0f%%", volleyballVM.winPercentage))
                    summaryRow(label: "Total Kills", value: "\(volleyballVM.totalKills)")
                    summaryRow(label: "Avg Hit %", value: String(format: "%+.3f", volleyballVM.averageHittingPercentage))
                    summaryRow(label: "Total Aces", value: "\(volleyballVM.totalAces)")
                    summaryRow(label: "Total Blocks", value: "\(volleyballVM.totalBlocks)")
                    summaryRow(label: "Total Digs", value: "\(volleyballVM.totalDigs)")
                }
            }
        }
        .editorialCard(accent: PepTheme.amber)
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, design: .serif))
                .foregroundStyle(PepTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
        }
        .padding(.vertical, 4)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PepTheme.glassBorderTop)
                .frame(height: 0.5)
                .offset(y: 2)
        }
    }
}
