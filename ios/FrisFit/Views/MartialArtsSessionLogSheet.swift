import SwiftUI

struct MartialArtsSessionLogSheet: View {
    @Bindable var maVM: MartialArtsViewModel
    @Environment(\.dismiss) private var dismiss

    private var accentColor: Color { maVM.logDiscipline.color }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    heroCard
                    disciplineSection
                    sessionTypeSection
                    durationSection
                    contextSection
                    if maVM.logSessionType.isCompetitive {
                        outcomeSection
                    }
                    if focusIsStriking {
                        strikingStatsSection
                    }
                    if focusIsGrappling {
                        grapplingStatsSection
                    }
                    roundsSection
                    techniquesSection
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
                        maVM.logSession()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(accentColor)
                }
            }
        }
    }

    private var focusIsStriking: Bool {
        let f = maVM.logDiscipline.primaryFocus
        return f == .striking || f == .hybrid
    }
    private var focusIsGrappling: Bool {
        let f = maVM.logDiscipline.primaryFocus
        return f == .grappling || f == .hybrid
    }

    // MARK: - Hero

    private var heroCard: some View {
        PepSportCard(accent: accentColor) {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(maVM.logDiscipline.rawValue.uppercased()) · LOG")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.0)
                    .foregroundStyle(accentColor.opacity(0.95))
                Text(heroTitle)
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .kerning(-0.5)
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Capture the work — type, time, technique, and the way it felt. Your reps tell the story.")
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var heroTitle: String {
        switch maVM.logSessionType {
        case .competition: "After the bow."
        case .sparring, .rolling: "After the rounds."
        case .padwork, .bagwork: "After the bag."
        default: "After the session."
        }
    }

    // MARK: - Discipline

    private var disciplineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(
                kicker: "01 — Discipline",
                title: "Style",
                accent: accentColor,
                trailing: AnyView(
                    Text(maVM.logDiscipline.rawValue.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(accentColor)
                )
            )
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(MartialArtsDiscipline.allCases) { d in
                        let isSelected = maVM.logDiscipline == d
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                maVM.logDiscipline = d
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: d.icon)
                                    .font(.system(size: 14))
                                Text(d.rawValue)
                                    .font(.system(size: 9, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .foregroundStyle(isSelected ? .black : PepTheme.textSecondary)
                            .frame(width: 86)
                            .padding(.vertical, 10)
                            .background(isSelected ? d.color : PepTheme.elevated.opacity(0.5))
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

    // MARK: - Session type

    private var sessionTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "02 — Type", title: "Session Type", accent: PepTheme.violet)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(MartialArtsSessionType.allCases) { type in
                    let isSelected = maVM.logSessionType == type
                    Button {
                        maVM.logSessionType = type
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: type.icon)
                                .font(.system(size: 13))
                            Text(type.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Spacer()
                        }
                        .foregroundStyle(isSelected ? .black : PepTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .frame(maxWidth: .infinity)
                        .background(isSelected ? PepTheme.violet : PepTheme.elevated.opacity(0.5))
                        .clipShape(.rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .editorialCard(accent: PepTheme.violet)
    }

    // MARK: - Duration

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "03 — Duration", title: "Time on the Mat", accent: PepTheme.amber)
            HStack {
                Button { maVM.logDuration = max(15, maVM.logDuration - 15) } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Spacer()
                VStack(spacing: 0) {
                    Text("\(maVM.logDuration)")
                        .font(.system(size: 44, weight: .bold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                        .contentTransition(.numericText())
                    Text("MINUTES")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.6)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Spacer()
                Button { maVM.logDuration = min(300, maVM.logDuration + 15) } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(accentColor)
                }
            }

            HStack {
                Text("INTENSITY")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                Text("\(maVM.logIntensity)/10")
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .foregroundStyle(accentColor)
            }
            Slider(value: Binding(
                get: { Double(maVM.logIntensity) },
                set: { maVM.logIntensity = Int($0.rounded()) }
            ), in: 1...10, step: 1)
            .tint(accentColor)
        }
        .editorialCard(accent: PepTheme.amber)
    }

    // MARK: - Context

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "04 — Context", title: "Where & With", accent: accentColor)

            TextField("Gym / academy", text: $maVM.logGym)
                .font(.system(size: 14, design: .serif))
                .padding(12)
                .background(PepTheme.elevated.opacity(0.4))
                .clipShape(.rect(cornerRadius: 10))

            TextField("Coach / instructor (optional)", text: $maVM.logCoach)
                .font(.system(size: 14, design: .serif))
                .padding(12)
                .background(PepTheme.elevated.opacity(0.4))
                .clipShape(.rect(cornerRadius: 10))

            TextField(
                maVM.logSessionType.isLive ? "Partner / opponent" : "Training partner (optional)",
                text: $maVM.logOpponent
            )
            .font(.system(size: 14, design: .serif))
            .padding(12)
            .background(PepTheme.elevated.opacity(0.4))
            .clipShape(.rect(cornerRadius: 10))
        }
        .editorialCard(accent: accentColor)
    }

    // MARK: - Outcome

    private var outcomeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "05 — Result", title: "Outcome", accent: accentColor)
            HStack(spacing: 8) {
                ForEach(MartialArtsOutcome.allCases) { outcome in
                    let isSelected = maVM.logOutcome == outcome
                    Button {
                        maVM.logOutcome = isSelected ? nil : outcome
                    } label: {
                        VStack(spacing: 6) {
                            Text(outcome.rawValue)
                                .font(.system(size: 18, weight: .black, design: .serif))
                            Text(outcome.label.uppercased())
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(1.2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(isSelected ? .black : outcome.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isSelected ? outcome.color : outcome.color.opacity(0.10))
                        .clipShape(.rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .editorialCard(accent: accentColor)
    }

    // MARK: - Striking

    private var strikingStatsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "Striking", title: "Output", accent: PepTheme.amber)
            VStack(spacing: 10) {
                statRow(label: "Jabs", value: $maVM.logStats.jabs, icon: "1.circle.fill", color: PepTheme.amber)
                statRow(label: "Crosses", value: $maVM.logStats.crosses, icon: "2.circle.fill", color: accentColor)
                statRow(label: "Hooks", value: $maVM.logStats.hooks, icon: "arrow.triangle.turn.up.right.circle.fill", color: PepTheme.violet)
                statRow(label: "Uppercuts", value: $maVM.logStats.uppercuts, icon: "arrow.up.circle.fill", color: .green)
                statRow(label: "Low Kicks", value: $maVM.logStats.lowKicks, icon: "figure.kickboxing", color: .red.opacity(0.85))
                statRow(label: "Body Kicks", value: $maVM.logStats.bodyKicks, icon: "figure.kickboxing", color: PepTheme.amber)
                statRow(label: "Head Kicks", value: $maVM.logStats.headKicks, icon: "figure.kickboxing", color: accentColor)
                statRow(label: "Knees", value: $maVM.logStats.knees, icon: "shoe.fill", color: PepTheme.violet)
                statRow(label: "Elbows", value: $maVM.logStats.elbows, icon: "bolt.horizontal.fill", color: .orange)
            }
        }
        .editorialCard(accent: PepTheme.amber)
    }

    // MARK: - Grappling

    private var grapplingStatsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "Grappling", title: "Mat Game", accent: PepTheme.violet)
            VStack(spacing: 10) {
                statRow(label: "Takedowns Landed", value: $maVM.logStats.takedownsLanded, icon: "arrow.down.to.line", color: PepTheme.violet)
                statRow(label: "Takedown Attempts", value: $maVM.logStats.takedownsAttempted, icon: "circle.dashed", color: PepTheme.textSecondary)
                statRow(label: "Sweeps Landed", value: $maVM.logStats.sweepsLanded, icon: "arrow.left.arrow.right", color: .green)
                statRow(label: "Passes Landed", value: $maVM.logStats.passesLanded, icon: "arrow.right.circle.fill", color: accentColor)
                statRow(label: "Subs Landed", value: $maVM.logStats.submissionsLanded, icon: "hand.raised.fill", color: .green)
                statRow(label: "Sub Attempts", value: $maVM.logStats.submissionsAttempted, icon: "circle.dashed", color: PepTheme.textSecondary)
                statRow(label: "Subs Defended", value: $maVM.logStats.submissionsDefended, icon: "shield.lefthalf.filled", color: .blue)
                statRow(label: "Taps Given", value: $maVM.logStats.tapsGiven, icon: "checkmark.circle.fill", color: PepTheme.amber)
                statRow(label: "Taps Received", value: $maVM.logStats.tapsReceived, icon: "xmark.octagon.fill", color: .red)
            }

            if maVM.logStats.takedownsAttempted > 0 {
                HStack {
                    Text("TAKEDOWN %")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                    Text(String(format: "%.0f%%", maVM.logStats.takedownPercentage * 100))
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .foregroundStyle(maVM.logStats.takedownPercentage >= 0.5 ? .green : PepTheme.amber)
                        .contentTransition(.numericText())
                }
                .padding(.top, 4)
            }
        }
        .editorialCard(accent: PepTheme.violet)
    }

    // MARK: - Rounds

    private var roundsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "Rounds", title: "Live Time", accent: accentColor)
            HStack(spacing: 12) {
                stepperBox(
                    label: "Rounds",
                    value: Binding(
                        get: { maVM.logStats.roundsCompleted },
                        set: { maVM.logStats.roundsCompleted = $0 }
                    ),
                    color: accentColor,
                    maxValue: 30
                )
                stepperBox(
                    label: "Sec/Round",
                    value: Binding(
                        get: { maVM.logStats.roundDurationSeconds },
                        set: { maVM.logStats.roundDurationSeconds = $0 }
                    ),
                    color: PepTheme.violet,
                    maxValue: 600,
                    step: 30
                )
            }
        }
        .editorialCard(accent: accentColor)
    }

    private func stepperBox(label: String, value: Binding<Int>, color: Color, maxValue: Int, step: Int = 1) -> some View {
        HStack(spacing: 8) {
            Button { value.wrappedValue = max(0, value.wrappedValue - step) } label: {
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(minWidth: 56)
            Button { value.wrappedValue = min(maxValue, value.wrappedValue + step) } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(color)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(PepTheme.elevated.opacity(0.4))
        .clipShape(.rect(cornerRadius: 10))
    }

    // MARK: - Techniques

    private var techniquesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Detail", title: "Techniques Worked", accent: PepTheme.amber)
            TextField("Triangle, knee cut pass, switch kick…", text: $maVM.logTechniquesText, axis: .vertical)
                .font(.system(size: 13, design: .serif))
                .lineLimit(2...4)
                .padding(12)
                .background(PepTheme.elevated.opacity(0.4))
                .clipShape(.rect(cornerRadius: 10))
            Text("Comma-separated. Tap any in your log later for trends.")
                .font(.system(size: 11, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
        }
        .editorialCard(accent: PepTheme.amber)
    }

    // MARK: - Vibe

    private var vibeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "Vibe", title: "How It Felt", accent: accentColor)
            slider(label: "Energy", value: $maVM.logEnergyRating, color: accentColor)
            slider(label: "Technique", value: $maVM.logTechniqueRating, color: PepTheme.violet)
            slider(label: "Cardio", value: $maVM.logCardioRating, color: PepTheme.amber)
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
            Slider(value: Binding(
                get: { Double(value.wrappedValue) },
                set: { value.wrappedValue = Int($0.rounded()) }
            ), in: 1...10, step: 1)
            .tint(color)
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Story", title: "Notes", accent: PepTheme.violet)
            TextField("What worked, what to fix, how you felt…", text: $maVM.logNotes, axis: .vertical)
                .font(.system(size: 13, design: .serif))
                .lineLimit(4...8)
                .padding(12)
                .background(PepTheme.elevated.opacity(0.4))
                .clipShape(.rect(cornerRadius: 10))
        }
        .editorialCard(accent: PepTheme.violet)
    }

    // MARK: - Helpers

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
}
