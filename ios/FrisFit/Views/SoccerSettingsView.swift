import SwiftUI

struct SoccerSettingsView: View {
    @Bindable var soccerVM: SoccerViewModel
    @Environment(\.dismiss) private var dismiss

    private let accentColor = Color(red: 0.2, green: 0.78, blue: 0.35)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    positionSection
                    seasonSummarySection
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .background(PepTheme.background.ignoresSafeArea())
            .navigationTitle("Soccer Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(accentColor)
                }
            }
        }
    }

    private var positionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.fill")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Primary Position")
                Spacer()
            }

            Text("Your dashboard will show stats tailored to your position.")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)

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
                        .background(isSelected ? accentColor : PepTheme.elevated)
                        .clipShape(.rect(cornerRadius: 12))
                    }
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    private var seasonSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(PepTheme.amber)
                HeadlineText(text: "Season Summary")
                Spacer()
            }

            let gm = soccerVM.gameMatches
            if gm.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "soccerball")
                            .font(.title2)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                        Text("No matches played yet")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
            } else {
                VStack(spacing: 8) {
                    summaryRow(label: "Matches Played", value: "\(soccerVM.totalGamesPlayed)")
                    summaryRow(label: "Record", value: "\(soccerVM.totalWins)W · \(soccerVM.totalDraws)D · \(soccerVM.totalLosses)L")
                    summaryRow(label: "Win Rate", value: String(format: "%.0f%%", soccerVM.winPercentage))
                    summaryRow(label: "Total Goals", value: "\(soccerVM.totalGoals)")
                    summaryRow(label: "Total Assists", value: "\(soccerVM.totalAssists)")
                    summaryRow(label: "Goal Contributions", value: "\(soccerVM.totalGoalContributions)")
                    summaryRow(label: "Avg Rating", value: String(format: "%.1f/10", soccerVM.averageRating))
                    summaryRow(label: "Total FP", value: "\(soccerVM.totalFPEarned)")
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(PepTheme.textPrimary)
        }
        .padding(.vertical, 2)
    }
}
