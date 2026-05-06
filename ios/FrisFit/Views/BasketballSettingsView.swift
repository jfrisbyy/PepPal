import SwiftUI

struct BasketballSettingsView: View {
    @Bindable var bbVM: BasketballViewModel
    @Environment(\.dismiss) private var dismiss

    private let accentColor = BasketballPalette.courtOrange

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    seriousModeCard
                    statsCard
                    aboutCard
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .appBackground(accent: accentColor)
            .navigationTitle("Basketball Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(accentColor)
                }
            }
        }
    }

    private var seriousModeCard: some View {
        PepSportCard(accent: accentColor) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("MODE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2.0)
                        .foregroundStyle(accentColor)
                    Spacer()
                }

                Text("Serious mode")
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)

                Text("Track full box-score stats, FG%, 3PT%, scoring trends, and the four-step game logger. Off by default — most hoopers don't track this stuff.")
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle(isOn: $bbVM.seriousMode) {
                    HStack(spacing: 10) {
                        Image(systemName: bbVM.seriousMode ? "chart.bar.fill" : "chart.bar")
                            .foregroundStyle(accentColor)
                        Text(bbVM.seriousMode ? "On" : "Off")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                    }
                }
                .tint(accentColor)
                .sensoryFeedback(.selection, trigger: bbVM.seriousMode)
            }
        }
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Your hoop life", title: "By the Numbers", accent: accentColor)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                statTile(value: "\(bbVM.games.count)", label: "RUNS LOGGED", color: accentColor)
                statTile(value: "\(bbVM.currentStreak)", label: "DAY STREAK", color: BasketballPalette.courtAmber)
                statTile(value: "\(bbVM.drillSessions.values.reduce(0, +))", label: "DRILLS RUN", color: .green)
                statTile(value: "\(bbVM.practicePlans.count)", label: "PLANS SAVED", color: PepTheme.violet)
            }
        }
        .editorialCard(accent: accentColor)
    }

    private func statTile(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BUILT FOR")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(PepTheme.textSecondary)
            Text("Casual hoopers, gym rats, weekend warriors — anyone who plays for the love of the game. Calories sync to your daily activity log automatically.")
                .font(.system(size: 12, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(PepTheme.cardSurface.opacity(0.5))
        .clipShape(.rect(cornerRadius: 14))
    }
}
