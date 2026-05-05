import SwiftUI

struct BasketballGameLogSheet: View {
    @Bindable var bbVM: BasketballViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep: Int = 0
    @State private var useQuickLog: Bool = false

    private let accentColor = Color(red: 1.0, green: 0.55, blue: 0.1)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    stepIndicator

                    switch currentStep {
                    case 0: sessionTypeStep
                    case 1: statsStep
                    case 2: shotChartStep
                    case 3: ratingsStep
                    default: EmptyView()
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .appBackground()
            .navigationTitle("Log Basketball")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        bbVM.resetLogForm()
                        dismiss()
                    }
                    .foregroundStyle(PepTheme.textSecondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? accentColor : PepTheme.elevated)
                    .frame(height: 4)
            }
        }
    }

    // MARK: - Step 0: Session Type

    private var sessionTypeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("SESSION TYPE")

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(BasketballSessionType.allCases) { type in
                    let isSelected = bbVM.selectedSessionType == type
                    Button {
                        withAnimation(.spring(duration: 0.25)) {
                            bbVM.selectedSessionType = type
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: type.icon)
                                .font(.system(size: 16))
                            Text(type.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(isSelected ? .black : PepTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isSelected ? accentColor : PepTheme.elevated)
                        .clipShape(.rect(cornerRadius: 12))
                    }
                }
            }

            if bbVM.selectedSessionType.isGame {
                gameInfoSection
            }

            durationSection
        }
    }

    private var gameInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("GAME RESULT")

            HStack(spacing: 12) {
                ForEach(GameResult.allCases) { result in
                    let isSelected = bbVM.gameResult == result
                    Button {
                        withAnimation(.spring(duration: 0.2)) {
                            bbVM.gameResult = result
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: result == .win ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                            Text(result == .win ? "Win" : "Loss")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundStyle(isSelected ? .white : PepTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isSelected ? result.color : PepTheme.elevated)
                        .clipShape(.rect(cornerRadius: 12))
                    }
                }
            }

            HStack(spacing: 16) {
                VStack(spacing: 6) {
                    Text("YOUR TEAM")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .tracking(1)
                    scoreCounter(value: $bbVM.teamScore, color: .green)
                }
                .frame(maxWidth: .infinity)

                Text("—")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(PepTheme.textSecondary)

                VStack(spacing: 6) {
                    Text("OPPONENT")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .tracking(1)
                    scoreCounter(value: $bbVM.opponentScore, color: .red)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(16)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
            )
        }
    }

    private func scoreCounter(value: Binding<Int>, color: Color) -> some View {
        HStack(spacing: 12) {
            Button { value.wrappedValue = max(0, value.wrappedValue - 1) } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Text("\(value.wrappedValue)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .frame(width: 50)
                .contentTransition(.numericText())
            Button { value.wrappedValue += 1 } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(color)
            }
        }
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("DURATION")

            HStack(spacing: 12) {
                Button { bbVM.gameDuration = max(5, bbVM.gameDuration - 5) } label: {
                    Image(systemName: "minus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(PepTheme.elevated)
                        .clipShape(Circle())
                }

                VStack(spacing: 2) {
                    Text("\(bbVM.gameDuration)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(PepTheme.textPrimary)
                        .contentTransition(.numericText())
                    Text("minutes")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)

                Button { bbVM.gameDuration = min(300, bbVM.gameDuration + 5) } label: {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(PepTheme.elevated)
                        .clipShape(Circle())
                }
            }
            .padding(16)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
            )
        }
    }

    // MARK: - Step 1: Stats

    private var statsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                sectionLabel("GAME STATS")
                Spacer()
                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        useQuickLog.toggle()
                    }
                } label: {
                    Text(useQuickLog ? "Full Stats" : "Quick Log")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(accentColor.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            if useQuickLog {
                quickLogSection
            } else {
                fullStatsSection
            }
        }
    }

    private var quickLogSection: some View {
        VStack(spacing: 12) {
            counterRow(label: "Points", value: $bbVM.currentStats.points, icon: "target", color: accentColor)
            Divider().overlay(PepTheme.glassBorderTop)
            counterRow(label: "Rebounds", value: Binding(
                get: { bbVM.currentStats.offensiveRebounds + bbVM.currentStats.defensiveRebounds },
                set: { newVal in
                    let current = bbVM.currentStats.offensiveRebounds + bbVM.currentStats.defensiveRebounds
                    let diff = newVal - current
                    if diff > 0 { bbVM.currentStats.defensiveRebounds += diff }
                    else { bbVM.currentStats.defensiveRebounds = max(0, bbVM.currentStats.defensiveRebounds + diff) }
                }
            ), icon: "arrow.up.and.down", color: .green)
            Divider().overlay(PepTheme.glassBorderTop)
            counterRow(label: "Assists", value: $bbVM.currentStats.assists, icon: "arrow.turn.up.right", color: .blue)
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private var fullStatsSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "scope")
                        .font(.system(size: 12))
                        .foregroundStyle(accentColor)
                    Text("SCORING")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .tracking(0.8)
                    Spacer()
                }

                counterRow(label: "Points", value: $bbVM.currentStats.points, icon: "target", color: accentColor)
                Divider().overlay(PepTheme.glassBorderTop)
                madeAttemptedRow(label: "FG", made: $bbVM.currentStats.fieldGoalsMade, attempted: $bbVM.currentStats.fieldGoalsAttempted, color: accentColor)
                Divider().overlay(PepTheme.glassBorderTop)
                madeAttemptedRow(label: "3PT", made: $bbVM.currentStats.threePointersMade, attempted: $bbVM.currentStats.threePointersAttempted, color: .green)
                Divider().overlay(PepTheme.glassBorderTop)
                madeAttemptedRow(label: "FT", made: $bbVM.currentStats.freeThrowsMade, attempted: $bbVM.currentStats.freeThrowsAttempted, color: PepTheme.amber)
            }
            .padding(16)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
            )

            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "arrow.up.and.down")
                        .font(.system(size: 12))
                        .foregroundStyle(.green)
                    Text("REBOUNDS & PLAYMAKING")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .tracking(0.8)
                    Spacer()
                }

                counterRow(label: "Off. Rebounds", value: $bbVM.currentStats.offensiveRebounds, icon: "arrow.up", color: .green)
                Divider().overlay(PepTheme.glassBorderTop)
                counterRow(label: "Def. Rebounds", value: $bbVM.currentStats.defensiveRebounds, icon: "arrow.down", color: .green)
                Divider().overlay(PepTheme.glassBorderTop)
                counterRow(label: "Assists", value: $bbVM.currentStats.assists, icon: "arrow.turn.up.right", color: .blue)
            }
            .padding(16)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
            )

            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                    Text("DEFENSE & TURNOVERS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .tracking(0.8)
                    Spacer()
                }

                counterRow(label: "Steals", value: $bbVM.currentStats.steals, icon: "hand.raised.fill", color: PepTheme.amber)
                Divider().overlay(PepTheme.glassBorderTop)
                counterRow(label: "Blocks", value: $bbVM.currentStats.blocks, icon: "xmark.shield.fill", color: .red)
                Divider().overlay(PepTheme.glassBorderTop)
                counterRow(label: "Turnovers", value: $bbVM.currentStats.turnovers, icon: "arrow.uturn.left", color: PepTheme.textSecondary)
            }
            .padding(16)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
            )

            counterRow(label: "Minutes Played", value: $bbVM.currentStats.minutesPlayed, icon: "clock.fill", color: PepTheme.textSecondary)
                .padding(16)
                .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
                .clipShape(.rect(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                )
        }
    }

    private func counterRow(label: String, value: Binding<Int>, icon: String, color: Color) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
                    .frame(width: 28)
                Text(label)
                    .font(.subheadline)
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
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .frame(width: 40)
                    .contentTransition(.numericText())
                Button { value.wrappedValue += 1 } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(color)
                }
            }
        }
    }

    private func madeAttemptedRow(label: String, made: Binding<Int>, attempted: Binding<Int>, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .frame(width: 32, alignment: .leading)

            Spacer()

            HStack(spacing: 8) {
                miniCounter(value: made, color: color)
                Text("/")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary)
                miniCounter(value: attempted, color: PepTheme.textSecondary)
            }

            let pct = attempted.wrappedValue > 0 ? Double(made.wrappedValue) / Double(attempted.wrappedValue) * 100 : 0
            Text(String(format: "%.0f%%", pct))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .frame(width: 40, alignment: .trailing)
        }
    }

    private func miniCounter(value: Binding<Int>, color: Color) -> some View {
        HStack(spacing: 6) {
            Button { value.wrappedValue = max(0, value.wrappedValue - 1) } label: {
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(PepTheme.elevated)
                    .clipShape(Circle())
            }
            Text("\(value.wrappedValue)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(PepTheme.textPrimary)
                .frame(width: 28)
                .contentTransition(.numericText())
            Button { value.wrappedValue += 1 } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(color)
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Step 2: Shot Chart

    private var shotChartStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                sectionLabel("SHOT CHART")
                Spacer()
                Text("\(bbVM.shotChartEntries.count) shots")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Text("Tap a zone, then mark as made or missed")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)

            BasketballShotChartInputView(bbVM: bbVM, accentColor: accentColor)

            if !bbVM.shotChartEntries.isEmpty {
                shotChartSummary
            }

            Text("You can skip this step if you prefer not to chart shots.")
                .font(.system(size: 11))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
        }
    }

    private var shotChartSummary: some View {
        let made = bbVM.shotChartEntries.filter(\.made).count
        let total = bbVM.shotChartEntries.count
        let pct = total > 0 ? Double(made) / Double(total) * 100 : 0

        return HStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("\(made)/\(total)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(accentColor)
                Text("Made/Att")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 4) {
                Text(String(format: "%.0f%%", pct))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(pct >= 50 ? .green : .orange)
                Text("FG%")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(14)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 14))
    }

    // MARK: - Step 3: Ratings

    private var ratingsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("SELF ASSESSMENT")

            VStack(spacing: 16) {
                ratingSlider(label: "Confidence", value: $bbVM.confidenceRating, icon: "brain.head.profile.fill", color: PepTheme.violet)
                ratingSlider(label: "Performance", value: $bbVM.performanceRating, icon: "star.fill", color: PepTheme.amber)
            }
            .padding(16)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
            )

            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("NOTES")
                TextField("How did you feel? Any key moments?", text: $bbVM.gameNotes, axis: .vertical)
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textPrimary)
                    .tint(accentColor)
                    .lineLimit(3...6)
                    .padding(14)
                    .background(PepTheme.cardSurface)
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                    )
            }

            fpPreview
        }
    }

    private func ratingSlider(label: String, value: Binding<Int>, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                Text("\(value.wrappedValue)/10")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(color)
            }

            HStack(spacing: 0) {
                ForEach(1...10, id: \.self) { level in
                    Button {
                        withAnimation(.spring(duration: 0.2)) {
                            value.wrappedValue = level
                        }
                    } label: {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(level <= value.wrappedValue ? color : PepTheme.elevated)
                            .frame(height: 28)
                    }
                    if level < 10 {
                        Spacer().frame(width: 4)
                    }
                }
            }
        }
    }

    private var fpPreview: some View {
        EmptyView()
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        currentStep -= 1
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .frame(width: 50, height: 50)
                        .background(PepTheme.elevated)
                        .clipShape(.rect(cornerRadius: 14))
                }
            }

            Button {
                if currentStep < 3 {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        currentStep += 1
                    }
                } else {
                    bbVM.logGame()
                    dismiss()
                }
            } label: {
                HStack(spacing: 8) {
                    if currentStep == 3 {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                    }
                    Text(currentStep == 3 ? "Log Session" : "Next")
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(accentColor)
                .clipShape(.rect(cornerRadius: 14))
            }
            .buttonStyle(.scalePrimary)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .background(
            PepTheme.background
                .shadow(color: .black.opacity(0.5), radius: 20, y: -8)
                .ignoresSafeArea()
        )
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(PepTheme.textSecondary)
            .tracking(1)
    }
}
