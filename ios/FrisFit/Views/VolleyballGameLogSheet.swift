import SwiftUI

struct VolleyballGameLogSheet: View {
    @Bindable var volleyballVM: VolleyballViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var teammateInput: String = ""

    private let accentColor = Color(red: 0.95, green: 0.30, blue: 0.20)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    heroCard
                    sessionTypeSection
                    if volleyballVM.selectedSessionType.isMatch {
                        opponentSection
                        setsSection
                        resultSection
                    } else {
                        venueSection
                    }
                    coreStatsSection
                    advancedStatsSection
                    teammatesSection
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
                        volleyballVM.logMatch()
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
                Text("VOLLEYBALL · LOG")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.0)
                    .foregroundStyle(accentColor.opacity(0.9))
                Text(volleyballVM.selectedSessionType.isMatch ? "After the whistle." : "After the session.")
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .kerning(-0.5)
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Capture the work — set scores, swings, serves, defense. Your numbers are your story.")
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
                    ForEach(VolleyballSessionType.allCases) { type in
                        Button {
                            volleyballVM.selectedSessionType = type
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 14))
                                Text(type.rawValue)
                                    .font(.system(size: 9, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .foregroundStyle(volleyballVM.selectedSessionType == type ? .black : PepTheme.textSecondary)
                            .frame(width: 78)
                            .padding(.vertical, 10)
                            .background(volleyballVM.selectedSessionType == type ? accentColor : PepTheme.elevated.opacity(0.5))
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

    // MARK: - Opponent

    private var opponentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "02 — Match", title: "Opponent & Venue", accent: accentColor)

            TextField("Opponent name", text: $volleyballVM.opponentName)
                .font(.system(size: 14, design: .serif))
                .padding(12)
                .background(PepTheme.elevated.opacity(0.4))
                .clipShape(.rect(cornerRadius: 10))

            TextField("Venue (optional)", text: $volleyballVM.venue)
                .font(.system(size: 14, design: .serif))
                .padding(12)
                .background(PepTheme.elevated.opacity(0.4))
                .clipShape(.rect(cornerRadius: 10))
        }
        .editorialCard(accent: accentColor)
    }

    private var venueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "02 — Venue", title: "Where", accent: accentColor)
            TextField("Court / gym (optional)", text: $volleyballVM.venue)
                .font(.system(size: 14, design: .serif))
                .padding(12)
                .background(PepTheme.elevated.opacity(0.4))
                .clipShape(.rect(cornerRadius: 10))
        }
        .editorialCard(accent: accentColor)
    }

    // MARK: - Sets

    private var setsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(
                kicker: "03 — Score",
                title: "Set-by-Set",
                accent: PepTheme.amber,
                trailing: AnyView(
                    HStack(spacing: 8) {
                        Button {
                            volleyballVM.removeLastLogSet()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(volleyballVM.logSets.count > 1 ? PepTheme.textSecondary : PepTheme.textSecondary.opacity(0.3))
                        }
                        .disabled(volleyballVM.logSets.count <= 1)
                        Button {
                            volleyballVM.addLogSet()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(accentColor)
                        }
                    }
                )
            )

            VStack(spacing: 10) {
                ForEach(Array(volleyballVM.logSets.enumerated()), id: \.element.id) { index, _ in
                    setRow(index: index)
                }
            }
        }
        .editorialCard(accent: PepTheme.amber)
    }

    private func setRow(index: Int) -> some View {
        HStack(spacing: 12) {
            Text("SET \(index + 1)")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(PepTheme.textSecondary)
                .frame(width: 50, alignment: .leading)

            stepperBox(
                label: "Us",
                value: Binding(
                    get: { volleyballVM.logSets[index].teamPoints },
                    set: { volleyballVM.logSets[index].teamPoints = $0 }
                ),
                color: accentColor
            )
            stepperBox(
                label: "Them",
                value: Binding(
                    get: { volleyballVM.logSets[index].opponentPoints },
                    set: { volleyballVM.logSets[index].opponentPoints = $0 }
                ),
                color: PepTheme.textSecondary
            )
        }
    }

    private func stepperBox(label: String, value: Binding<Int>, color: Color) -> some View {
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
            Button { value.wrappedValue = min(50, value.wrappedValue + 1) } label: {
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
            EditorialSectionHeading(kicker: "04 — Result", title: "Outcome", accent: accentColor)
            HStack(spacing: 10) {
                ForEach(VolleyballMatchResult.allCases) { result in
                    let isSelected = volleyballVM.matchResult == result
                    Button {
                        volleyballVM.matchResult = isSelected ? nil : result
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
            EditorialSectionHeading(kicker: "05 — Stats", title: "Core Numbers", accent: accentColor)

            VStack(spacing: 10) {
                statRow(label: "Kills", value: $volleyballVM.currentStats.kills, icon: "bolt.fill", color: accentColor)
                statRow(label: "Attack Attempts", value: $volleyballVM.currentStats.attackAttempts, icon: "scope", color: PepTheme.amber)
                statRow(label: "Attack Errors", value: $volleyballVM.currentStats.attackErrors, icon: "xmark.octagon.fill", color: .red)
                statRow(label: "Aces", value: $volleyballVM.currentStats.aces, icon: "star.fill", color: .green)
                statRow(label: "Service Errors", value: $volleyballVM.currentStats.serviceErrors, icon: "arrow.down.right", color: .red.opacity(0.8))
            }

            if volleyballVM.currentStats.attackAttempts > 0 {
                HStack {
                    Text("HITTING %")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                    Text(String(format: "%+.3f", volleyballVM.currentStats.hittingPercentage))
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .foregroundStyle(volleyballVM.currentStats.hittingPercentage >= 0.200 ? .green : (volleyballVM.currentStats.hittingPercentage >= 0 ? accentColor : .red))
                        .contentTransition(.numericText())
                }
                .padding(.top, 4)
            }
        }
        .editorialCard(accent: accentColor)
    }

    private var advancedStatsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "06 — Defense & Setting", title: "Block · Dig · Assist", accent: PepTheme.violet)

            VStack(spacing: 10) {
                statRow(label: "Blocks (Solo)", value: $volleyballVM.currentStats.blocks, icon: "shield.lefthalf.filled", color: PepTheme.violet)
                statRow(label: "Block Assists", value: $volleyballVM.currentStats.blockAssists, icon: "shield.fill", color: PepTheme.violet.opacity(0.7))
                statRow(label: "Digs", value: $volleyballVM.currentStats.digs, icon: "hand.tap.fill", color: .blue)
                statRow(label: "Assists", value: $volleyballVM.currentStats.assists, icon: "hand.raised.fingers.spread.fill", color: .green)
                statRow(label: "Reception (3-pass)", value: $volleyballVM.currentStats.receptionPerfect, icon: "checkmark.circle.fill", color: .green)
                statRow(label: "Reception Total", value: $volleyballVM.currentStats.receptionAttempts, icon: "circle.dashed", color: PepTheme.textSecondary)
                statRow(label: "Reception Errors", value: $volleyballVM.currentStats.receptionErrors, icon: "xmark.circle.fill", color: .red)
            }
        }
        .editorialCard(accent: PepTheme.violet)
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

    // MARK: - Teammates

    private var teammatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "07 — Crew", title: "Played With", accent: PepTheme.amber)

            if !volleyballVM.teammates.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                    ForEach(volleyballVM.teammates, id: \.self) { name in
                        HStack(spacing: 6) {
                            Text(name)
                                .font(.system(size: 12, weight: .semibold, design: .serif))
                                .foregroundStyle(PepTheme.textPrimary)
                            Button {
                                volleyballVM.teammates.removeAll { $0 == name }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(PepTheme.amber.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
            }

            HStack {
                TextField("Add a teammate", text: $teammateInput)
                    .font(.system(size: 13, design: .serif))
                Button {
                    let trimmed = teammateInput.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    if !volleyballVM.teammates.contains(trimmed) {
                        volleyballVM.teammates.append(trimmed)
                    }
                    teammateInput = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(PepTheme.amber)
                }
            }
            .padding(12)
            .background(PepTheme.elevated.opacity(0.4))
            .clipShape(.rect(cornerRadius: 10))
        }
        .editorialCard(accent: PepTheme.amber)
    }

    // MARK: - Vibe

    private var vibeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "08 — Vibe", title: "How It Felt", accent: accentColor)

            slider(label: "Performance", value: $volleyballVM.performanceRating, color: accentColor)
            slider(label: "Confidence", value: $volleyballVM.confidenceRating, color: PepTheme.amber)

            HStack {
                Text("DURATION")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                HStack(spacing: 12) {
                    Button { volleyballVM.matchDuration = max(15, volleyballVM.matchDuration - 15) } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    Text("\(volleyballVM.matchDuration) min")
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .contentTransition(.numericText())
                    Button { volleyballVM.matchDuration = min(240, volleyballVM.matchDuration + 15) } label: {
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
            EditorialSectionHeading(kicker: "09 — Story", title: "Notes", accent: PepTheme.violet)
            TextField("What worked, what to fix, anything to remember...", text: $volleyballVM.matchNotes, axis: .vertical)
                .font(.system(size: 13, design: .serif))
                .lineLimit(4...8)
                .padding(12)
                .background(PepTheme.elevated.opacity(0.4))
                .clipShape(.rect(cornerRadius: 10))
        }
        .editorialCard(accent: PepTheme.violet)
    }
}
