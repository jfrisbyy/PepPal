import SwiftUI

struct BasketballLogRunSheet: View {
    @Bindable var bbVM: BasketballViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showBoxScore: Bool = false
    @State private var showShotChart: Bool = false
    @State private var partnerInput: String = ""

    private let accentColor = BasketballPalette.courtOrange

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    sessionTypeSection
                    durationSection
                    vibeSection
                    locationSection
                    partnersSection
                    notesSection
                    expanderRow

                    if showBoxScore {
                        boxScoreSection
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    if showShotChart {
                        shotChartSection
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
            .appBackground(accent: accentColor)
            .navigationTitle("Log a Run")
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
                saveBar
            }
        }
    }

    // MARK: - Session Type

    private var sessionTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("WHAT KIND OF RUN")

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(BasketballSessionType.allCases) { type in
                        let isSelected = bbVM.selectedSessionType == type
                        Button {
                            withAnimation(.spring(duration: 0.25)) {
                                bbVM.selectedSessionType = type
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 12))
                                Text(type.rawValue)
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(isSelected ? .black : PepTheme.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(isSelected ? accentColor : PepTheme.elevated.opacity(0.6))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.selection, trigger: isSelected)
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)

            if bbVM.selectedSessionType.isGame {
                gameResultRow
                    .transition(.opacity)
            }
        }
    }

    private var gameResultRow: some View {
        HStack(spacing: 10) {
            ForEach(GameResult.allCases) { result in
                let isSelected = bbVM.gameResult == result
                Button {
                    withAnimation(.spring(duration: 0.2)) {
                        bbVM.gameResult = isSelected ? nil : result
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: result == .win ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                            .font(.system(size: 11))
                        Text(result == .win ? "Win" : "Loss")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(isSelected ? .white : PepTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isSelected ? result.color : PepTheme.elevated.opacity(0.5))
                    .clipShape(.rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Duration

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("DURATION")

            HStack(spacing: 14) {
                Button {
                    bbVM.gameDuration = max(5, bbVM.gameDuration - 5)
                } label: {
                    Image(systemName: "minus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(PepTheme.elevated)
                        .clipShape(Circle())
                }
                .buttonStyle(.scale)
                .sensoryFeedback(.selection, trigger: bbVM.gameDuration)

                VStack(spacing: 2) {
                    Text("\(bbVM.gameDuration)")
                        .font(.system(size: 44, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                        .contentTransition(.numericText())
                    Text("minutes")
                        .font(.system(size: 11))
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)

                Button {
                    bbVM.gameDuration = min(300, bbVM.gameDuration + 5)
                } label: {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(accentColor.opacity(0.18))
                        .clipShape(Circle())
                }
                .buttonStyle(.scale)
                .sensoryFeedback(.selection, trigger: bbVM.gameDuration)
            }

            HStack(spacing: 6) {
                ForEach([15, 30, 45, 60, 90], id: \.self) { preset in
                    Button {
                        bbVM.gameDuration = preset
                    } label: {
                        Text("\(preset)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(bbVM.gameDuration == preset ? .black : PepTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(bbVM.gameDuration == preset ? accentColor : PepTheme.elevated.opacity(0.5))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [accentColor.opacity(0.18), PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    // MARK: - Vibe

    private var vibeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("HOW IT FELT")

            vibeSlider(label: "Energy", icon: "bolt.fill", value: $bbVM.energyRating, color: BasketballPalette.courtAmber)
            vibeSlider(label: "Legs", icon: "figure.run", value: $bbVM.legsRating, color: Color(red: 0.20, green: 0.78, blue: 0.35))
            vibeSlider(label: "Confidence", icon: "brain.head.profile.fill", value: $bbVM.confidenceRating, color: PepTheme.violet)
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
        .onChange(of: bbVM.energyRating) { _, _ in syncVibeRating() }
        .onChange(of: bbVM.legsRating) { _, _ in syncVibeRating() }
        .onChange(of: bbVM.confidenceRating) { _, _ in syncVibeRating() }
    }

    private func syncVibeRating() {
        bbVM.vibeRating = Int(round(Double(bbVM.energyRating + bbVM.legsRating + bbVM.confidenceRating) / 3))
        bbVM.performanceRating = bbVM.vibeRating
    }

    private func vibeSlider(label: String, icon: String, value: Binding<Int>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                Text("\(value.wrappedValue)/10")
                    .font(.system(.subheadline, design: .serif, weight: .semibold))
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
            }

            HStack(spacing: 4) {
                ForEach(1...10, id: \.self) { level in
                    Button {
                        withAnimation(.spring(duration: 0.2)) {
                            value.wrappedValue = level
                        }
                    } label: {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(level <= value.wrappedValue ? color : PepTheme.elevated)
                            .frame(height: 24)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: value.wrappedValue)
                }
            }
        }
    }

    // MARK: - Location

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("WHERE")

            HStack(spacing: 10) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 13))
                    .foregroundStyle(accentColor)
                TextField("Court, gym, or park", text: $bbVM.location)
                    .font(.system(size: 14, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                    .tint(accentColor)
            }
            .padding(14)
            .background(PepTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
            )
        }
    }

    // MARK: - Partners

    private var partnersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("RAN WITH")

            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(accentColor)
                TextField("Add a name and hit return", text: $partnerInput)
                    .font(.system(size: 14, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                    .tint(accentColor)
                    .submitLabel(.done)
                    .onSubmit { addPartner() }
                if !partnerInput.isEmpty {
                    Button {
                        addPartner()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(accentColor)
                    }
                }
            }
            .padding(14)
            .background(PepTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
            )

            if !bbVM.partners.isEmpty {
                FlowChips(items: bbVM.partners) { partner in
                    bbVM.partners.removeAll { $0 == partner }
                }
            }
        }
    }

    private func addPartner() {
        let trimmed = partnerInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if !bbVM.partners.contains(trimmed) {
            bbVM.partners.append(trimmed)
        }
        partnerInput = ""
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("NOTES")
            TextField("How did it go? Anything to remember?", text: $bbVM.gameNotes, axis: .vertical)
                .font(.system(size: 14, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .tint(accentColor)
                .lineLimit(3...6)
                .padding(14)
                .background(PepTheme.cardSurface)
                .clipShape(.rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                )
        }
    }

    // MARK: - Expanders

    private var expanderRow: some View {
        VStack(spacing: 8) {
            expanderButton(title: "Add box score", icon: "list.bullet.clipboard", isOpen: showBoxScore) {
                withAnimation(.spring(duration: 0.3)) { showBoxScore.toggle() }
            }
            expanderButton(title: "Add shot chart", icon: "scope", isOpen: showShotChart) {
                withAnimation(.spring(duration: 0.3)) { showShotChart.toggle() }
            }
        }
    }

    private func expanderButton(title: String, icon: String, isOpen: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(accentColor)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                Image(systemName: isOpen ? "minus.circle.fill" : "plus.circle.fill")
                    .foregroundStyle(accentColor)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(PepTheme.cardSurface.opacity(0.6))
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(accentColor.opacity(isOpen ? 0.3 : 0.15), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Box Score

    private var boxScoreSection: some View {
        VStack(spacing: 12) {
            sectionLabel("BOX SCORE")

            counterRow(label: "Points", value: $bbVM.currentStats.points, icon: "target", color: accentColor)
            Divider().overlay(PepTheme.glassBorderTop)
            counterRow(label: "Rebounds", value: $bbVM.currentStats.defensiveRebounds, icon: "arrow.up.and.down", color: .green)
            Divider().overlay(PepTheme.glassBorderTop)
            counterRow(label: "Assists", value: $bbVM.currentStats.assists, icon: "arrow.turn.up.right", color: .blue)
            Divider().overlay(PepTheme.glassBorderTop)
            counterRow(label: "Steals", value: $bbVM.currentStats.steals, icon: "hand.raised.fill", color: BasketballPalette.courtAmber)
            Divider().overlay(PepTheme.glassBorderTop)
            counterRow(label: "Blocks", value: $bbVM.currentStats.blocks, icon: "xmark.shield.fill", color: .red)
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(accentColor.opacity(0.2), lineWidth: 0.5)
        )
    }

    private func counterRow(label: String, value: Binding<Int>, icon: String, color: Color) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(color)
                    .frame(width: 24)
                Text(label)
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            Spacer()
            HStack(spacing: 12) {
                Button { value.wrappedValue = max(0, value.wrappedValue - 1) } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .buttonStyle(.plain)
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
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Shot Chart inline

    private var shotChartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("SHOT CHART")
            Text("Tap a zone, then mark made or missed.")
                .font(.system(size: 11, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
            BasketballShotChartInputView(bbVM: bbVM, accentColor: accentColor)
            if !bbVM.shotChartEntries.isEmpty {
                let made = bbVM.shotChartEntries.filter(\.made).count
                let total = bbVM.shotChartEntries.count
                let pct = total > 0 ? Double(made) / Double(total) * 100 : 0
                HStack(spacing: 12) {
                    Text("\(made)/\(total)")
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .foregroundStyle(accentColor)
                    Text(String(format: "%.0f%% FG", pct))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                    Button {
                        bbVM.shotChartEntries.removeAll()
                    } label: {
                        Text("CLEAR")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(accentColor.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Save Bar

    private var saveBar: some View {
        let estCals = METCalculator.caloriesBurned(
            sport: "Basketball",
            workoutType: nil,
            durationMinutes: bbVM.gameDuration,
            weightKg: BasketballViewModel.userWeightKg(),
            intensity: max(min(Int(round(Double(bbVM.energyRating + bbVM.legsRating + bbVM.confidenceRating) / 3)), 10), 1)
        )

        return VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(BasketballPalette.courtAmber)
                Text("Est. \(estCals) kcal")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                Text("·")
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                Text("synced to your activity logs")
                    .font(.system(size: 11, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
            }

            EditorialPrimaryButton("Save Run", icon: "checkmark.circle.fill", accent: accentColor) {
                bbVM.logRun()
                dismiss()
            }
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
            .font(.system(size: 10, weight: .bold))
            .tracking(1.6)
            .foregroundStyle(PepTheme.textSecondary)
    }
}

// MARK: - FlowChips helper

private struct FlowChips: View {
    let items: [String]
    let onRemove: (String) -> Void

    var body: some View {
        BBFlowLayout(spacing: 6) {
            ForEach(items, id: \.self) { item in
                Button {
                    onRemove(item)
                } label: {
                    HStack(spacing: 4) {
                        Text(item)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(BasketballPalette.courtOrange.opacity(0.14))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().strokeBorder(BasketballPalette.courtOrange.opacity(0.25), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct BBFlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if rowWidth + s.width > maxWidth {
                totalHeight += rowHeight + spacing
                rowWidth = s.width + spacing
                rowHeight = s.height
            } else {
                rowWidth += s.width + spacing
                rowHeight = max(rowHeight, s.height)
            }
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
    }
}
