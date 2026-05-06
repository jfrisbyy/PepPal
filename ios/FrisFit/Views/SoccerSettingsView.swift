import SwiftUI

struct SoccerSettingsView: View {
    @Bindable var soccerVM: SoccerViewModel
    @Environment(\.dismiss) private var dismiss

    private let accentColor = Color(red: 0.2, green: 0.78, blue: 0.35)

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
                Text("SOCCER · SETTINGS")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.0)
                    .foregroundStyle(accentColor.opacity(0.9))
                Text("Tune your game.")
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .kerning(-0.5)
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Pick your primary role and we'll surface the stats that actually matter for it.")
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
                    Text(soccerVM.primaryPosition.shortName)
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(accentColor)
                )
            )

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(SoccerPosition.allCases) { pos in
                    let isSelected = soccerVM.primaryPosition == pos
                    Button {
                        withAnimation(.spring(duration: 0.25)) {
                            soccerVM.primaryPosition = pos
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
                                .minimumScaleFactor(0.8)
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

            let gm = soccerVM.gameMatches
            if gm.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "soccerball")
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
                    summaryRow(label: "Matches Played", value: "\(soccerVM.totalGamesPlayed)")
                    summaryRow(label: "Record", value: "\(soccerVM.totalWins)W · \(soccerVM.totalDraws)D · \(soccerVM.totalLosses)L")
                    summaryRow(label: "Win Rate", value: String(format: "%.0f%%", soccerVM.winPercentage))
                    summaryRow(label: "Total Goals", value: "\(soccerVM.totalGoals)")
                    summaryRow(label: "Total Assists", value: "\(soccerVM.totalAssists)")
                    summaryRow(label: "Goal Contributions", value: "\(soccerVM.totalGoalContributions)")
                    summaryRow(label: "Avg Rating", value: String(format: "%.1f / 10", soccerVM.averageRating))
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
