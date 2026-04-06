import SwiftUI

struct SoccerGameLogSheet: View {
    @Bindable var soccerVM: SoccerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep: Int = 0
    @State private var useQuickLog: Bool = false

    private let accentColor = Color(red: 0.2, green: 0.78, blue: 0.35)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    stepIndicator

                    switch currentStep {
                    case 0: sessionTypeStep
                    case 1: statsStep
                    case 2: movementStep
                    case 3: ratingsStep
                    default: EmptyView()
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .background(PepTheme.background.ignoresSafeArea())
            .navigationTitle("Log Soccer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        soccerVM.resetLogForm()
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

    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? accentColor : PepTheme.elevated)
                    .frame(height: 4)
            }
        }
    }

    // MARK: - Step 0: Session Type & Match Info

    private var sessionTypeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("SESSION TYPE")

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(SoccerSessionType.allCases) { type in
                    let isSelected = soccerVM.selectedSessionType == type
                    Button {
                        withAnimation(.spring(duration: 0.25)) {
                            soccerVM.selectedSessionType = type
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

            sectionLabel("POSITION")

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(SoccerPosition.allCases) { pos in
                        let isSelected = soccerVM.matchPosition == pos
                        Button {
                            withAnimation(.spring(duration: 0.2)) {
                                soccerVM.matchPosition = pos
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: pos.icon)
                                    .font(.system(size: 12))
                                Text(pos.shortName)
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundStyle(isSelected ? .black : PepTheme.textSecondary)
                            .frame(width: 56)
                            .padding(.vertical, 10)
                            .background(isSelected ? accentColor : PepTheme.elevated.opacity(0.5))
                            .clipShape(.rect(cornerRadius: 10))
                        }
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)

            if soccerVM.selectedSessionType.isGame {
                matchInfoSection
            }

            durationSection
        }
    }

    private var matchInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("MATCH RESULT")

            HStack(spacing: 10) {
                ForEach(SoccerMatchResult.allCases) { result in
                    let isSelected = soccerVM.matchResult == result
                    Button {
                        withAnimation(.spring(duration: 0.2)) {
                            soccerVM.matchResult = result
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: result == .win ? "hand.thumbsup.fill" : result == .loss ? "hand.thumbsdown.fill" : "equal.circle.fill")
                                .font(.system(size: 14))
                            Text(result.label)
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(isSelected ? .white : PepTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
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
                    scoreCounter(value: $soccerVM.teamScore, color: .green)
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
                    scoreCounter(value: $soccerVM.opponentScore, color: .red)
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
                Button { soccerVM.matchDuration = max(5, soccerVM.matchDuration - 5) } label: {
                    Image(systemName: "minus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(PepTheme.elevated)
                        .clipShape(Circle())
                }

                VStack(spacing: 2) {
                    Text("\(soccerVM.matchDuration)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(PepTheme.textPrimary)
                        .contentTransition(.numericText())
                    Text("minutes")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)

                Button { soccerVM.matchDuration = min(180, soccerVM.matchDuration + 5) } label: {
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
                sectionLabel("MATCH STATS")
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
            counterRow(label: "Goals", value: $soccerVM.currentStats.goals, icon: "soccerball", color: accentColor)
            Divider().overlay(PepTheme.glassBorderTop)
            counterRow(label: "Assists", value: $soccerVM.currentStats.assists, icon: "arrow.turn.up.right", color: .blue)
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
                    Text("ATTACKING")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .tracking(0.8)
                    Spacer()
                }
                counterRow(label: "Goals", value: $soccerVM.currentStats.goals, icon: "soccerball", color: accentColor)
                Divider().overlay(PepTheme.glassBorderTop)
                counterRow(label: "Assists", value: $soccerVM.currentStats.assists, icon: "arrow.turn.up.right", color: .blue)
                Divider().overlay(PepTheme.glassBorderTop)
                counterRow(label: "Shots On Target", value: $soccerVM.currentStats.shotsOnTarget, icon: "scope", color: .green)
                Divider().overlay(PepTheme.glassBorderTop)
                counterRow(label: "Shots Off Target", value: $soccerVM.currentStats.shotsOffTarget, icon: "xmark.circle", color: .orange)
                Divider().overlay(PepTheme.glassBorderTop)
                counterRow(label: "Key Passes", value: $soccerVM.currentStats.keyPasses, icon: "arrow.right.circle", color: .cyan)
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
                    Text("DEFENDING")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .tracking(0.8)
                    Spacer()
                }
                counterRow(label: "Tackles Won", value: $soccerVM.currentStats.tacklesWon, icon: "shield.fill", color: .red)
                Divider().overlay(PepTheme.glassBorderTop)
                counterRow(label: "Tackles Lost", value: $soccerVM.currentStats.tacklesLost, icon: "shield.slash", color: .orange)
                Divider().overlay(PepTheme.glassBorderTop)
                counterRow(label: "Interceptions", value: $soccerVM.currentStats.interceptions, icon: "hand.raised.fill", color: .blue)
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
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(PepTheme.amber)
                    Text("DISCIPLINE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .tracking(0.8)
                    Spacer()
                }
                counterRow(label: "Fouls Committed", value: $soccerVM.currentStats.foulsCommitted, icon: "exclamationmark.circle", color: .orange)
                Divider().overlay(PepTheme.glassBorderTop)
                counterRow(label: "Fouls Won", value: $soccerVM.currentStats.foulsWon, icon: "checkmark.circle", color: .green)
                Divider().overlay(PepTheme.glassBorderTop)
                counterRow(label: "Yellow Cards", value: $soccerVM.currentStats.yellowCards, icon: "rectangle.portrait.fill", color: .yellow)
                Divider().overlay(PepTheme.glassBorderTop)
                counterRow(label: "Red Cards", value: $soccerVM.currentStats.redCards, icon: "rectangle.portrait.fill", color: .red)
            }
            .padding(16)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
            )

            counterRow(label: "Minutes Played", value: $soccerVM.currentStats.minutesPlayed, icon: "clock.fill", color: PepTheme.textSecondary)
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

    // MARK: - Step 2: Movement

    private var movementStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("MOVEMENT DATA")

            Text("Enter GPS/watch data if available, or estimate.")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)

            VStack(spacing: 16) {
                movementField(label: "Distance (km)", value: $soccerVM.distanceKm, icon: "map.fill", color: accentColor)
                Divider().overlay(PepTheme.glassBorderTop)
                movementIntField(label: "Sprint Count", value: $soccerVM.sprintCount, icon: "bolt.fill", color: .orange)
                Divider().overlay(PepTheme.glassBorderTop)
                movementField(label: "Top Speed (km/h)", value: $soccerVM.topSpeedKmh, icon: "speedometer", color: .red)
            }
            .padding(16)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
            )

            Text("Skip this step if you don't have movement data.")
                .font(.system(size: 11))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
        }
    }

    private func movementField(label: String, value: Binding<Double>, icon: String, color: Color) -> some View {
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
            HStack(spacing: 8) {
                Button { value.wrappedValue = max(0, value.wrappedValue - 0.5) } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Text(String(format: "%.1f", value.wrappedValue))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .frame(width: 50)
                    .contentTransition(.numericText())
                Button { value.wrappedValue += 0.5 } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(color)
                }
            }
        }
    }

    private func movementIntField(label: String, value: Binding<Int>, icon: String, color: Color) -> some View {
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

    // MARK: - Step 3: Ratings

    private var ratingsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("SELF ASSESSMENT")

            VStack(spacing: 16) {
                ratingSlider(label: "Performance", value: $soccerVM.performanceRating, icon: "star.fill", color: PepTheme.amber)
                ratingSlider(label: "Confidence", value: $soccerVM.confidenceRating, icon: "brain.head.profile.fill", color: PepTheme.violet)
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
                TextField("How did you play? Key moments?", text: $soccerVM.matchNotes, axis: .vertical)
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
        let estimatedFP: Int
        if soccerVM.selectedSessionType.isGame {
            let statScore = Double(soccerVM.currentStats.goals) * 6.0 + Double(soccerVM.currentStats.assists) * 4.0 +
                Double(soccerVM.currentStats.keyPasses) * 1.5 + Double(soccerVM.currentStats.tacklesWon) * 2.0 +
                Double(soccerVM.currentStats.interceptions) * 1.5
            let durationBonus = Double(soccerVM.matchDuration) * 1.5
            let resultMult: Double
            switch soccerVM.matchResult {
            case .win: resultMult = 1.3
            case .draw: resultMult = 1.1
            default: resultMult = 1.0
            }
            estimatedFP = Int((statScore + durationBonus) * resultMult)
        } else {
            estimatedFP = Int(Double(soccerVM.matchDuration) * 2.5 * 1.1)
        }

        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("ESTIMATED FP")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .tracking(1)
                Text("Based on stats & duration")
                    .font(.system(size: 11))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(PepTheme.teal)
                Text("\(estimatedFP)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.teal)
                    .contentTransition(.numericText())
                Text("FP")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PepTheme.teal.opacity(0.7))
            }
        }
        .padding(16)
        .background(PepTheme.teal.opacity(0.08))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.teal.opacity(0.2), lineWidth: 0.5)
        )
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
                    soccerVM.logMatch()
                    dismiss()
                }
            } label: {
                HStack(spacing: 8) {
                    if currentStep == 3 {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                    }
                    Text(currentStep == 3 ? "Log Match" : "Next")
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
