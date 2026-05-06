import SwiftUI

struct PickleballGameLogSheet: View {
    @Bindable var pickleVM: PickleballViewModel
    @Environment(\.dismiss) private var dismiss

    private let accentColor = Color(red: 0.62, green: 0.86, blue: 0.18)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    heroCard
                    sessionTypeSection
                    formatSection
                    if pickleVM.selectedSessionType.isMatch {
                        opponentSection
                        gamesSection
                        resultSection
                    } else {
                        venueSection
                    }
                    coreStatsSection
                    softGameStatsSection
                    serveReturnStatsSection
                    duprSection
                    vibeSection
                    notesSection
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .appBackground(accent: accentColor)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") {
                        pickleVM.logMatch()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(accentColor)
                }
            }
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        PepSportCard(accent: accentColor) {
            VStack(alignment: .leading, spacing: 10) {
                Text("PICKLEBALL · LOG")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.0)
                    .foregroundStyle(accentColor.opacity(0.95))
                Text(pickleVM.selectedSessionType.isMatch ? "After the handshakes." : "After the session.")
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .kerning(-0.5)
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Capture the work — game scores, kitchen battles, third shots. Your numbers tell your story.")
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Session type

    private var sessionTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "01 — Type", title: "Session Type", accent: accentColor)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(PickleballSessionType.allCases) { type in
                        Button {
                            pickleVM.selectedSessionType = type
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 14))
                                Text(type.rawValue)
                                    .font(.system(size: 9, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .foregroundStyle(pickleVM.selectedSessionType == type ? .black : PepTheme.textSecondary)
                            .frame(width: 82)
                            .padding(.vertical, 10)
                            .background(pickleVM.selectedSessionType == type ? accentColor : PepTheme.elevated.opacity(0.5))
                            .clipShape(.rect(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)
        }
        .editorialCard(accent: accentColor)
    }

    // MARK: - Format

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "02 — Format", title: "Singles or Doubles", accent: PepTheme.violet)
            HStack(spacing: 8) {
                ForEach(PickleballFormat.allCases) { format in
                    let isSelected = pickleVM.matchFormat == format
                    Button {
                        pickleVM.matchFormat = format
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: format.icon)
                                .font(.system(size: 16))
                            Text(format.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(isSelected ? .black : PepTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isSelected ? PepTheme.violet : PepTheme.elevated.opacity(0.5))
                        .clipShape(.rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                ForEach(PickleballSide.allCases) { side in
                    let isSelected = pickleVM.matchSide == side
                    Button {
                        pickleVM.matchSide = side
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: side.icon)
                                .font(.system(size: 12))
                            Text(side.rawValue)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(isSelected ? .black : PepTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(isSelected ? accentColor : PepTheme.elevated.opacity(0.4))
                        .clipShape(.rect(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .editorialCard(accent: PepTheme.violet)
    }

    // MARK: - Opponent

    private var opponentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "03 — Match", title: "Opponent & Crew", accent: accentColor)

            TextField("Opponent / team name", text: $pickleVM.opponentName)
                .font(.system(size: 14, design: .serif))
                .padding(12)
                .background(PepTheme.elevated.opacity(0.4))
                .clipShape(.rect(cornerRadius: 10))

            if pickleVM.matchFormat != .singles {
                TextField("Partner name", text: $pickleVM.matchPartner)
                    .font(.system(size: 14, design: .serif))
                    .padding(12)
                    .background(PepTheme.elevated.opacity(0.4))
                    .clipShape(.rect(cornerRadius: 10))
            }

            TextField("Venue / court (optional)", text: $pickleVM.venue)
                .font(.system(size: 14, design: .serif))
                .padding(12)
                .background(PepTheme.elevated.opacity(0.4))
                .clipShape(.rect(cornerRadius: 10))
        }
        .editorialCard(accent: accentColor)
    }

    private var venueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "03 — Venue", title: "Where", accent: accentColor)
            TextField("Court / club (optional)", text: $pickleVM.venue)
                .font(.system(size: 14, design: .serif))
                .padding(12)
                .background(PepTheme.elevated.opacity(0.4))
                .clipShape(.rect(cornerRadius: 10))
        }
        .editorialCard(accent: accentColor)
    }

    // MARK: - Games

    private var gamesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(
                kicker: "04 — Score",
                title: "Game-by-Game",
                accent: PepTheme.amber,
                trailing: AnyView(
                    HStack(spacing: 8) {
                        Button {
                            pickleVM.removeLastLogGame()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(pickleVM.logGames.count > 1 ? PepTheme.textSecondary : PepTheme.textSecondary.opacity(0.3))
                        }
                        .disabled(pickleVM.logGames.count <= 1)
                        Button {
                            pickleVM.addLogGame()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(accentColor)
                        }
                    }
                )
            )

            VStack(spacing: 10) {
                ForEach(Array(pickleVM.logGames.enumerated()), id: \.element.id) { index, _ in
                    gameRow(index: index)
                }
            }
        }
        .editorialCard(accent: PepTheme.amber)
    }

    private func gameRow(index: Int) -> some View {
        HStack(spacing: 12) {
            Text("GAME \(index + 1)")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(PepTheme.textSecondary)
                .frame(width: 60, alignment: .leading)

            stepperBox(
                label: "Us",
                value: Binding(
                    get: { pickleVM.logGames[index].teamPoints },
                    set: { pickleVM.logGames[index].teamPoints = $0 }
                ),
                color: accentColor,
                maxValue: 25
            )
            stepperBox(
                label: "Them",
                value: Binding(
                    get: { pickleVM.logGames[index].opponentPoints },
                    set: { pickleVM.logGames[index].opponentPoints = $0 }
                ),
                color: PepTheme.textSecondary,
                maxValue: 25
            )
        }
    }

    private func stepperBox(label: String, value: Binding<Int>, color: Color, maxValue: Int) -> some View {
        HStack(spacing: 8) {
            Button { value.wrappedValue = max(0, value.wrappedValue - 1) } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            VStack(spacing: 0) {
                Text("\(value.wrappedValue)")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                Text(label.uppercased())
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .frame(minWidth: 38)
            Button { value.wrappedValue = min(maxValue, value.wrappedValue + 1) } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(color == PepTheme.textSecondary ? PepTheme.textSecondary : color)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(PepTheme.elevated.opacity(0.4))
        .clipShape(.rect(cornerRadius: 10))
    }

    // MARK: - Result

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "05 — Result", title: "Outcome", accent: accentColor)
            HStack(spacing: 10) {
                ForEach(PickleballMatchResult.allCases) { result in
                    let isSelected = pickleVM.matchResult == result
                    Button {
                        pickleVM.matchResult = isSelected ? nil : result
                    } label: {
                        VStack(spacing: 6) {
                            Text(result.rawValue)
                                .font(.system(size: 22, weight: .black, design: .serif))
                            Text(result.label.uppercased())
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(1.4)
                        }
                        .foregroundStyle(isSelected ? .black : result.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isSelected ? result.color : result.color.opacity(0.10))
                        .clipShape(.rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .editorialCard(accent: accentColor)
    }

    // MARK: - Core stats

    private var coreStatsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "06 — Stats", title: "Core Numbers", accent: accentColor)

            VStack(spacing: 10) {
                statRow(label: "Winners", value: $pickleVM.currentStats.winners, icon: "bolt.fill", color: accentColor)
                statRow(label: "Unforced Errors", value: $pickleVM.currentStats.unforcedErrors, icon: "xmark.octagon.fill", color: .red)
                statRow(label: "Aces", value: $pickleVM.currentStats.aces, icon: "star.fill", color: PepTheme.amber)
                statRow(label: "Service Faults", value: $pickleVM.currentStats.serviceFaults, icon: "arrow.down.right", color: .red.opacity(0.8))
                statRow(label: "Kitchen Violations", value: $pickleVM.currentStats.kitchenViolations, icon: "exclamationmark.triangle.fill", color: .orange)
            }

            if pickleVM.currentStats.winners + pickleVM.currentStats.unforcedErrors > 0 {
                HStack {
                    Text("W:E RATIO")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                    Text(String(format: "%.2f", pickleVM.currentStats.winnerToErrorRatio))
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .foregroundStyle(pickleVM.currentStats.winnerToErrorRatio >= 1.0 ? .green : (pickleVM.currentStats.winnerToErrorRatio >= 0.7 ? accentColor : .red))
                        .contentTransition(.numericText())
                }
                .padding(.top, 4)
            }
        }
        .editorialCard(accent: accentColor)
    }

    // MARK: - Soft game

    private var softGameStatsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "07 — Kitchen", title: "Drops & Dinks", accent: PepTheme.violet)

            VStack(spacing: 10) {
                statRow(label: "3rd Shot Drops Made", value: $pickleVM.currentStats.thirdShotDropsMade, icon: "scope", color: PepTheme.violet)
                statRow(label: "3rd Shot Drops Tried", value: $pickleVM.currentStats.thirdShotDropsAttempted, icon: "circle.dashed", color: PepTheme.textSecondary)
                statRow(label: "Dinks Won", value: $pickleVM.currentStats.dinksWon, icon: "circle.dotted", color: .green)
                statRow(label: "Dinks Lost", value: $pickleVM.currentStats.dinksLost, icon: "circle.dotted", color: .red.opacity(0.8))
                statRow(label: "Block Volleys", value: $pickleVM.currentStats.blockVolleysWon, icon: "shield.lefthalf.filled", color: .blue)
                statRow(label: "ATPs", value: $pickleVM.currentStats.atpHits, icon: "arrow.triangle.swap", color: PepTheme.amber)
                statRow(label: "Ernes", value: $pickleVM.currentStats.ernes, icon: "figure.jumprope", color: PepTheme.amber)
            }

            if pickleVM.currentStats.thirdShotDropsAttempted > 0 {
                HStack {
                    Text("DROP %")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                    Text(String(format: "%.0f%%", pickleVM.currentStats.thirdShotDropPercentage * 100))
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .foregroundStyle(pickleVM.currentStats.thirdShotDropPercentage >= 0.6 ? .green : accentColor)
                        .contentTransition(.numericText())
                }
                .padding(.top, 4)
            }
        }
        .editorialCard(accent: PepTheme.violet)
    }

    // MARK: - Serve & return

    private var serveReturnStatsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "08 — Serve & Return", title: "Setup", accent: PepTheme.amber)

            VStack(spacing: 10) {
                statRow(label: "1st Serves In", value: $pickleVM.currentStats.firstServeIn, icon: "arrow.up.right", color: PepTheme.amber)
                statRow(label: "1st Serve Attempts", value: $pickleVM.currentStats.firstServeAttempts, icon: "circle.dashed", color: PepTheme.textSecondary)
                statRow(label: "Return Points Won", value: $pickleVM.currentStats.returnPointsWon, icon: "checkmark.circle.fill", color: .green)
                statRow(label: "Return Points Played", value: $pickleVM.currentStats.returnPointsPlayed, icon: "circle.dashed", color: PepTheme.textSecondary)
            }

            if pickleVM.currentStats.firstServeAttempts > 0 {
                HStack {
                    Text("1ST SERVE %")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                    Text(String(format: "%.0f%%", pickleVM.currentStats.firstServePercentage * 100))
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .foregroundStyle(pickleVM.currentStats.firstServePercentage >= 0.75 ? .green : (pickleVM.currentStats.firstServePercentage >= 0.6 ? PepTheme.amber : .red))
                        .contentTransition(.numericText())
                }
                .padding(.top, 4)
            }
        }
        .editorialCard(accent: PepTheme.amber)
    }

    private func statRow(label: String, value: Binding<Int>, icon: String, color: Color) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(color)
                    .frame(width: 24)
                Text(label)
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            Spacer()
            HStack(spacing: 12) {
                Button { value.wrappedValue = max(0, value.wrappedValue - 1) } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Text("\(value.wrappedValue)")
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .frame(width: 36)
                    .contentTransition(.numericText())
                Button { value.wrappedValue += 1 } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(color)
                }
            }
        }
    }

    // MARK: - DUPR

    private var duprSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "09 — Rating", title: "Post-Match DUPR (optional)", accent: PepTheme.violet)
            TextField("e.g. 4.18", text: $pickleVM.matchDUPRInput)
                .keyboardType(.decimalPad)
                .font(.system(size: 14, design: .serif))
                .padding(12)
                .background(PepTheme.elevated.opacity(0.4))
                .clipShape(.rect(cornerRadius: 10))
            Text("Pull from your DUPR profile after the match.")
                .font(.system(size: 11, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
        }
        .editorialCard(accent: PepTheme.violet)
    }

    // MARK: - Vibe

    private var vibeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "10 — Vibe", title: "How It Felt", accent: accentColor)

            slider(label: "Energy", value: $pickleVM.energyRating, color: accentColor)
            slider(label: "Footwork", value: $pickleVM.footworkRating, color: PepTheme.violet)
            slider(label: "Confidence", value: $pickleVM.confidenceRating, color: PepTheme.amber)

            HStack {
                Text("DURATION")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                HStack(spacing: 12) {
                    Button { pickleVM.matchDuration = max(15, pickleVM.matchDuration - 15) } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    Text("\(pickleVM.matchDuration) min")
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .contentTransition(.numericText())
                    Button { pickleVM.matchDuration = min(240, pickleVM.matchDuration + 15) } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(accentColor)
                    }
                }
            }
        }
        .editorialCard(accent: accentColor)
    }

    private func slider(label: String, value: Binding<Int>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                Text("\(value.wrappedValue)/10")
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .foregroundStyle(color)
            }
            Slider(
                value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: { value.wrappedValue = Int($0.rounded()) }
                ),
                in: 1...10,
                step: 1
            )
            .tint(color)
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "11 — Story", title: "Notes", accent: PepTheme.violet)
            TextField("What worked, what to fix, anything to remember...", text: $pickleVM.matchNotes, axis: .vertical)
                .font(.system(size: 13, design: .serif))
                .lineLimit(4...8)
                .padding(12)
                .background(PepTheme.elevated.opacity(0.4))
                .clipShape(.rect(cornerRadius: 10))
        }
        .editorialCard(accent: PepTheme.violet)
    }
}
