import SwiftUI

struct PickleballSettingsView: View {
    @Bindable var pickleVM: PickleballViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var duprInput: String = ""

    private let accentColor = Color(red: 0.62, green: 0.86, blue: 0.18)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    heroCard
                    formatSection
                    sideSection
                    duprSection
                    partnerSection
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
                    Button("Done") {
                        commitDUPR()
                        dismiss()
                    }
                    .foregroundStyle(accentColor)
                }
            }
            .onAppear {
                if pickleVM.dupr > 0 {
                    duprInput = String(format: "%.2f", pickleVM.dupr)
                }
            }
        }
    }

    private func commitDUPR() {
        let trimmed = duprInput.trimmingCharacters(in: .whitespaces)
        if let value = Double(trimmed), value > 0 {
            pickleVM.dupr = value
        } else if trimmed.isEmpty {
            pickleVM.dupr = 0
        }
    }

    private var heroCard: some View {
        PepSportCard(accent: accentColor) {
            VStack(alignment: .leading, spacing: 10) {
                Text("PICKLEBALL · SETTINGS")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.0)
                    .foregroundStyle(accentColor.opacity(0.95))
                Text("Tune your game.")
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .kerning(-0.5)
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Set your default format, side, partner, and DUPR — the dashboard surfaces the stats that match your game.")
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "Format",
                title: "Default Format",
                accent: accentColor,
                trailing: AnyView(
                    Text(pickleVM.preferredFormat.shortName.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(accentColor)
                )
            )

            HStack(spacing: 8) {
                ForEach(PickleballFormat.allCases) { format in
                    let isSelected = pickleVM.preferredFormat == format
                    Button {
                        withAnimation(.spring(duration: 0.25)) {
                            pickleVM.preferredFormat = format
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: format.icon)
                                .font(.system(size: 16))
                            Text(format.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(isSelected ? .black : PepTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isSelected ? accentColor : PepTheme.elevated.opacity(0.5))
                        .clipShape(.rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .editorialCard(accent: accentColor)
    }

    private var sideSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "Position",
                title: "Court Side",
                accent: PepTheme.violet,
                trailing: AnyView(
                    Text(pickleVM.preferredSide.shortName)
                        .font(.system(size: 11, weight: .bold, design: .serif))
                        .foregroundStyle(PepTheme.violet)
                )
            )

            VStack(spacing: 8) {
                ForEach(PickleballSide.allCases) { side in
                    let isSelected = pickleVM.preferredSide == side
                    Button {
                        withAnimation(.spring(duration: 0.25)) {
                            pickleVM.preferredSide = side
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: side.icon)
                                .font(.system(size: 18))
                                .foregroundStyle(isSelected ? .black : PepTheme.violet)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(side.rawValue)
                                    .font(.system(size: 14, weight: .semibold, design: .serif))
                                    .foregroundStyle(isSelected ? .black : PepTheme.textPrimary)
                                Text(side.description)
                                    .font(.system(size: 11, design: .serif))
                                    .italic()
                                    .foregroundStyle(isSelected ? .black.opacity(0.7) : PepTheme.textSecondary)
                            }
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.black)
                            }
                        }
                        .padding(12)
                        .background(isSelected ? PepTheme.violet : PepTheme.elevated.opacity(0.5))
                        .clipShape(.rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .editorialCard(accent: PepTheme.violet)
    }

    private var duprSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Rating", title: "DUPR", accent: PepTheme.amber)
            TextField("e.g. 4.18", text: $duprInput)
                .keyboardType(.decimalPad)
                .font(.system(size: 14, design: .serif))
                .padding(12)
                .background(PepTheme.elevated.opacity(0.4))
                .clipShape(.rect(cornerRadius: 10))
            Text("Used to track your rating trajectory match-by-match.")
                .font(.system(size: 11, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
        }
        .editorialCard(accent: PepTheme.amber)
    }

    private var partnerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Crew", title: "Default Partner", accent: accentColor)
            TextField("Partner name (optional)", text: $pickleVM.partnerName)
                .font(.system(size: 14, design: .serif))
                .padding(12)
                .background(PepTheme.elevated.opacity(0.4))
                .clipShape(.rect(cornerRadius: 10))
        }
        .editorialCard(accent: accentColor)
    }

    private var seasonSummarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "Season", title: "Summary", accent: PepTheme.amber)

            let gm = pickleVM.gameMatches
            if gm.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "figure.pickleball")
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
                    summaryRow(label: "Matches Played", value: "\(pickleVM.totalMatchesPlayed)")
                    summaryRow(label: "Record", value: "\(pickleVM.totalWins)W · \(pickleVM.totalLosses)L")
                    summaryRow(label: "Win Rate", value: String(format: "%.0f%%", pickleVM.winPercentage))
                    summaryRow(label: "Total Winners", value: "\(pickleVM.totalWinners)")
                    summaryRow(label: "Avg W:E Ratio", value: String(format: "%.2f", pickleVM.averageWinnerErrorRatio))
                    summaryRow(label: "Avg Drop %", value: String(format: "%.0f%%", pickleVM.averageThirdShotDropPercentage * 100))
                    summaryRow(label: "Avg Dink Win %", value: String(format: "%.0f%%", pickleVM.averageDinkWinPercentage * 100))
                    summaryRow(label: "Avg 1st Serve %", value: String(format: "%.0f%%", pickleVM.averageFirstServePercentage * 100))
                    summaryRow(label: "Total Aces", value: "\(pickleVM.totalAces)")
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
