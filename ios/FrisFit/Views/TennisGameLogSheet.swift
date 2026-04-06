import SwiftUI

struct TennisGameLogSheet: View {
    @Bindable var tennisVM: TennisViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep: Int = 0

    private let accentColor = Color(red: 0.85, green: 0.9, blue: 0.15)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    stepIndicator

                    switch currentStep {
                    case 0: sessionTypeStep
                    case 1: statsStep
                    case 2: ratingsStep
                    default: EmptyView()
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .background(PepTheme.background.ignoresSafeArea())
            .navigationTitle("Log Tennis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        tennisVM.resetLogForm()
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
            ForEach(0..<3, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? accentColor : PepTheme.elevated)
                    .frame(height: 4)
            }
        }
    }

    private var sessionTypeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("SESSION TYPE")

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(TennisSessionType.allCases) { type in
                    let isSelected = tennisVM.selectedSessionType == type
                    Button {
                        withAnimation(.spring(duration: 0.25)) {
                            tennisVM.selectedSessionType = type
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

            if tennisVM.selectedSessionType.isMatch {
                matchInfoSection
            }

            durationSection

            if tennisVM.selectedSessionType.isMatch {
                scoreSection
            }
        }
    }

    private var matchInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("MATCH INFO")

            HStack(spacing: 12) {
                ForEach(TennisMatchFormat.allCases) { format in
                    let isSelected = tennisVM.matchFormat == format
                    Button {
                        withAnimation(.spring(duration: 0.2)) {
                            tennisVM.matchFormat = format
                        }
                    } label: {
                        Text(format.rawValue)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(isSelected ? .black : PepTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isSelected ? accentColor : PepTheme.elevated)
                            .clipShape(.rect(cornerRadius: 12))
                    }
                }
            }

            TextField("Opponent name", text: $tennisVM.opponentName)
                .font(.subheadline)
                .foregroundStyle(PepTheme.textPrimary)
                .tint(accentColor)
                .padding(14)
                .background(PepTheme.cardSurface)
                .clipShape(.rect(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                )

            if !tennisVM.regularOpponents.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(tennisVM.regularOpponents, id: \.self) { name in
                            Button {
                                tennisVM.opponentName = name
                            } label: {
                                Text(name)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(tennisVM.opponentName == name ? .black : PepTheme.textSecondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(tennisVM.opponentName == name ? accentColor : PepTheme.elevated)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .contentMargins(.horizontal, 0)
                .scrollIndicators(.hidden)
            }

            sectionLabel("RESULT")

            HStack(spacing: 12) {
                ForEach(TennisMatchResult.allCases) { result in
                    let isSelected = tennisVM.matchResult == result
                    Button {
                        withAnimation(.spring(duration: 0.2)) {
                            tennisVM.matchResult = result
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: result == .win ? "trophy.fill" : "xmark.circle.fill")
                            Text(result.label)
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
        }
    }

    private var scoreSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionLabel("SET SCORES")
                Spacer()
                if tennisVM.logSets.count < 5 {
                    Button {
                        tennisVM.addLogSet()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(accentColor)
                    }
                }
                if tennisVM.logSets.count > 1 {
                    Button {
                        tennisVM.removeLastLogSet()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.red)
                    }
                }
            }

            ForEach(Array(tennisVM.logSets.enumerated()), id: \.offset) { index, _ in
                HStack(spacing: 12) {
                    Text("Set \(index + 1)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 40)

                    HStack(spacing: 8) {
                        miniGameCounter(value: Binding(
                            get: { tennisVM.logSets[index].playerGames },
                            set: { tennisVM.logSets[index].playerGames = $0 }
                        ), color: accentColor, label: "You")

                        Text("-")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(PepTheme.textSecondary)

                        miniGameCounter(value: Binding(
                            get: { tennisVM.logSets[index].opponentGames },
                            set: { tennisVM.logSets[index].opponentGames = $0 }
                        ), color: .red, label: "Opp")
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(12)
                .background(PepTheme.cardSurface)
                .clipShape(.rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                )
            }
        }
    }

    private func miniGameCounter(value: Binding<Int>, color: Color, label: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(PepTheme.textSecondary)
            HStack(spacing: 8) {
                Button { value.wrappedValue = max(0, value.wrappedValue - 1) } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 22, height: 22)
                        .background(PepTheme.elevated)
                        .clipShape(Circle())
                }
                Text("\(value.wrappedValue)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .frame(width: 28)
                    .contentTransition(.numericText())
                Button { value.wrappedValue = min(13, value.wrappedValue + 1) } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(color)
                        .clipShape(Circle())
                }
            }
        }
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("DURATION")

            HStack(spacing: 12) {
                Button { tennisVM.matchDuration = max(5, tennisVM.matchDuration - 5) } label: {
                    Image(systemName: "minus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(PepTheme.elevated)
                        .clipShape(Circle())
                }

                VStack(spacing: 2) {
                    Text("\(tennisVM.matchDuration)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(PepTheme.textPrimary)
                        .contentTransition(.numericText())
                    Text("minutes")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)

                Button { tennisVM.matchDuration = min(300, tennisVM.matchDuration + 5) } label: {
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

    private var statsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("MATCH STATS")

            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12))
                        .foregroundStyle(accentColor)
                    Text("SERVE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .tracking(0.8)
                    Spacer()
                }

                counterRow(label: "Aces", value: $tennisVM.currentStats.aces, icon: "bolt.fill", color: accentColor)
                Divider().overlay(PepTheme.glassBorderTop)
                counterRow(label: "Double Faults", value: $tennisVM.currentStats.doubleFaults, icon: "xmark.circle", color: .red)
                Divider().overlay(PepTheme.glassBorderTop)
                madeAttemptedRow(label: "1st Serve", made: $tennisVM.currentStats.firstServesIn, attempted: $tennisVM.currentStats.firstServesTotal, color: accentColor)
                Divider().overlay(PepTheme.glassBorderTop)
                madeAttemptedRow(label: "Break Pts", made: $tennisVM.currentStats.breakPointsConverted, attempted: $tennisVM.currentStats.breakPointsTotal, color: PepTheme.amber)
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
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.green)
                    Text("RALLY STATS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .tracking(0.8)
                    Spacer()
                }

                counterRow(label: "Winners", value: $tennisVM.currentStats.winners, icon: "star.fill", color: .green)
                Divider().overlay(PepTheme.glassBorderTop)
                counterRow(label: "Unforced Errors", value: $tennisVM.currentStats.unforcedErrors, icon: "exclamationmark.triangle", color: .red)
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
                    Image(systemName: "tennis.racket")
                        .font(.system(size: 12))
                        .foregroundStyle(.blue)
                    Text("SHOT TRACKING")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .tracking(0.8)
                    Spacer()
                }

                counterRow(label: "Forehands", value: $tennisVM.currentStats.forehandsHit, icon: "arrow.right", color: accentColor)
                Divider().overlay(PepTheme.glassBorderTop)
                counterRow(label: "Backhands", value: $tennisVM.currentStats.backhandsHit, icon: "arrow.left", color: .green)
                Divider().overlay(PepTheme.glassBorderTop)
                counterRow(label: "Serves", value: $tennisVM.currentStats.servesHit, icon: "arrow.up.right", color: .blue)
                Divider().overlay(PepTheme.glassBorderTop)
                counterRow(label: "Volleys", value: $tennisVM.currentStats.volleysHit, icon: "hand.raised.fill", color: .orange)
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

    private var ratingsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("SELF ASSESSMENT")

            VStack(spacing: 16) {
                ratingSlider(label: "Confidence", value: $tennisVM.confidenceRating, icon: "brain.head.profile.fill", color: PepTheme.violet)
                ratingSlider(label: "Performance", value: $tennisVM.performanceRating, icon: "star.fill", color: PepTheme.amber)
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
                TextField("How did you play? Key moments?", text: $tennisVM.matchNotes, axis: .vertical)
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
        let estimatedFP = tennisVM.selectedSessionType.isMatch
            ? Int((Double(tennisVM.currentStats.aces) * 3.0 + Double(tennisVM.currentStats.winners) * 2.0 + Double(tennisVM.matchDuration) * 1.8) * (tennisVM.matchResult == .win ? 1.3 : 1.0))
            : Int(Double(tennisVM.matchDuration) * 2.5 * 1.1)

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
                if currentStep < 2 {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        currentStep += 1
                    }
                } else {
                    tennisVM.logMatch()
                    dismiss()
                }
            } label: {
                HStack(spacing: 8) {
                    if currentStep == 2 {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                    }
                    Text(currentStep == 2 ? "Log Session" : "Next")
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
