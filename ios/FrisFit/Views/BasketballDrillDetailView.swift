import SwiftUI

struct BasketballDrillDetailView: View {
    let drill: BasketballDrill
    @Bindable var bbVM: BasketballViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var heroAppeared: Bool = false

    private let accentColor = BasketballPalette.courtOrange

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    heroCard
                    videoPreviewCard
                    masteryCard
                    if !drill.description.isEmpty {
                        aboutCard
                    }
                    equipmentCard
                    if !drill.steps.isEmpty {
                        stepsCard
                    }
                    if !drill.cues.isEmpty {
                        cuesCard
                    }
                    commonMistakesCard
                    progressionsCard
                    relatedCard
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .appBackground(accent: drill.category.color)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(drill.category.color)
                }
            }
            .safeAreaInset(edge: .bottom) {
                runBar
            }
            .task {
                withAnimation(.spring(duration: 0.6)) { heroAppeared = true }
            }
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        PepSportCard(accent: drill.category.color) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    HStack(spacing: 6) {
                        Image(systemName: drill.category.icon)
                            .font(.system(size: 9, weight: .bold))
                        Text(drill.category.rawValue.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(2.0)
                    }
                    .foregroundStyle(drill.category.color)

                    Spacer()

                    Text(drill.difficulty.rawValue.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(drill.difficulty.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(drill.difficulty.color.opacity(0.12))
                        .clipShape(Capsule())
                }

                Text(drill.name)
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .kerning(-0.5)
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(2)

                Text(drill.purpose)
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                LinearGradient(
                    colors: [PepTheme.textPrimary.opacity(0.16), PepTheme.textPrimary.opacity(0)],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 0.5)

                HStack(spacing: 0) {
                    statCol(value: "\(drill.durationMinutes)", label: "MIN")
                    divider
                    statCol(value: drill.setsReps ?? "—", label: "VOLUME")
                    divider
                    statCol(value: drill.equipment.first?.rawValue ?? "Any", label: "GEAR")
                }
            }
        }
        .opacity(heroAppeared ? 1 : 0)
        .offset(y: heroAppeared ? 0 : 8)
    }

    private var divider: some View {
        Rectangle()
            .fill(PepTheme.shimmerHighlight)
            .frame(width: 0.5, height: 28)
    }

    private func statCol(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.subheadline, design: .serif, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Video Preview Placeholder

    private var videoPreviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            EditorialSectionHeading(kicker: "Watch", title: "Demo", accent: drill.category.color)

            ZStack {
                LinearGradient(
                    colors: [
                        drill.category.color.opacity(0.22),
                        Color.black.opacity(0.5)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Subtle court line motif
                GeometryReader { geo in
                    Path { path in
                        let w = geo.size.width
                        let h = geo.size.height
                        path.move(to: CGPoint(x: 0, y: h * 0.5))
                        path.addLine(to: CGPoint(x: w, y: h * 0.5))
                    }
                    .stroke(PepTheme.textPrimary.opacity(0.06), lineWidth: 0.5)

                    Circle()
                        .stroke(PepTheme.textPrimary.opacity(0.06), lineWidth: 0.5)
                        .frame(width: 90, height: 90)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }

                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 56, height: 56)
                        Circle()
                            .strokeBorder(drill.category.color.opacity(0.5), lineWidth: 0.5)
                            .frame(width: 56, height: 56)
                        Image(systemName: "play.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(drill.category.color)
                            .offset(x: 1)
                    }
                    Text("VIDEO COMING SOON")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.6)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            .frame(height: 160)
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(drill.category.color.opacity(0.18), lineWidth: 0.5)
            )
        }
        .editorialCard(accent: drill.category.color)
    }

    // MARK: - Mastery + Personal Best

    private var masteryCard: some View {
        let mastery = bbVM.mastery(for: drill)
        let count = bbVM.sessionCount(for: drill)
        return VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "Your Progress", title: mastery.rawValue, accent: mastery.color)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(PepTheme.elevated)
                    Capsule()
                        .fill(LinearGradient(colors: [mastery.color, mastery.color.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, geo.size.width * mastery.progress))
                }
            }
            .frame(height: 8)

            HStack {
                Text("\(count) session\(count == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                Text(nextLevelText(count: count))
                    .font(.system(size: 11, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
            }

            // Mastery ladder
            HStack(spacing: 6) {
                ForEach(DrillMastery.allCases, id: \.rawValue) { level in
                    let reached = masteryThreshold(level) <= count
                    VStack(spacing: 4) {
                        Image(systemName: reached ? "checkmark.seal.fill" : "circle.dashed")
                            .font(.system(size: 12))
                            .foregroundStyle(reached ? level.color : PepTheme.textSecondary.opacity(0.4))
                        Text(level.rawValue.uppercased())
                            .font(.system(size: 8, weight: .bold))
                            .tracking(1.0)
                            .foregroundStyle(reached ? level.color : PepTheme.textSecondary.opacity(0.5))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(reached ? level.color.opacity(0.06) : Color.clear)
                    .clipShape(.rect(cornerRadius: 8))
                }
            }
        }
        .editorialCard(accent: mastery.color)
    }

    private func masteryThreshold(_ level: DrillMastery) -> Int {
        switch level {
        case .touched: 0
        case .working: 2
        case .sharp: 5
        case .lockedIn: 10
        }
    }

    private func nextLevelText(count: Int) -> String {
        switch count {
        case 0...1: "Run it 2× to reach Working"
        case 2...4: "Run it 5× total to reach Sharp"
        case 5...9: "Run it 10× total to Lock In"
        default: "Locked in — keep it sharp"
        }
    }

    // MARK: - About

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            EditorialSectionHeading(kicker: "About", title: "The Why", accent: drill.category.color)
            Text(drill.description)
                .font(.system(size: 14, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .editorialCard(accent: drill.category.color)
    }

    // MARK: - Equipment

    private var equipmentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            EditorialSectionHeading(kicker: "What You Need", title: "Setup", accent: BasketballPalette.courtAmber)

            if drill.equipment.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(BasketballPalette.courtAmber)
                    Text("Nothing required — just you.")
                        .font(.system(size: 13, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textPrimary)
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(drill.equipment) { eq in
                        HStack(spacing: 8) {
                            Image(systemName: eq.icon)
                                .font(.system(size: 11))
                                .foregroundStyle(BasketballPalette.courtAmber)
                                .frame(width: 22, height: 22)
                                .background(BasketballPalette.courtAmber.opacity(0.12))
                                .clipShape(Circle())
                            Text(eq.rawValue)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(PepTheme.textPrimary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(PepTheme.elevated.opacity(0.5))
                        .clipShape(.rect(cornerRadius: 9))
                    }
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundStyle(PepTheme.textSecondary)
                Text("Plan around \(drill.durationMinutes) minutes")
                    .font(.system(size: 11, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                if let sr = drill.setsReps {
                    Text("·")
                        .foregroundStyle(PepTheme.textSecondary)
                    Text(sr)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Spacer()
            }
            .padding(.top, 2)
        }
        .editorialCard(accent: BasketballPalette.courtAmber)
    }

    // MARK: - Steps

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "How To", title: "Steps", accent: drill.category.color)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(drill.steps.enumerated()), id: \.offset) { idx, step in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(drill.category.color.opacity(0.12))
                                .frame(width: 26, height: 26)
                            Text(String(format: "%02d", idx + 1))
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(drill.category.color)
                        }
                        Text(step)
                            .font(.system(size: 13, design: .serif))
                            .foregroundStyle(PepTheme.textPrimary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .editorialCard(accent: drill.category.color)
    }

    // MARK: - Cues

    private var cuesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Coaching", title: "Cues", accent: BasketballPalette.courtAmber)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(drill.cues, id: \.self) { cue in
                    HStack(alignment: .top, spacing: 10) {
                        Rectangle()
                            .fill(BasketballPalette.courtAmber)
                            .frame(width: 2)
                            .frame(maxHeight: .infinity)
                        Text(cue)
                            .font(.system(size: 13, design: .serif))
                            .italic()
                            .foregroundStyle(PepTheme.textPrimary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .editorialCard(accent: BasketballPalette.courtAmber)
    }

    // MARK: - Common Mistakes

    private var commonMistakesCard: some View {
        let mistakes = commonMistakes(for: drill.category)
        return VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Watch Out", title: "Common Mistakes", accent: Color(red: 0.92, green: 0.46, blue: 0.42))
            VStack(alignment: .leading, spacing: 10) {
                ForEach(mistakes, id: \.self) { mistake in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(red: 0.92, green: 0.46, blue: 0.42))
                            .padding(.top, 2)
                        Text(mistake)
                            .font(.system(size: 13, design: .serif))
                            .foregroundStyle(PepTheme.textPrimary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .editorialCard(accent: Color(red: 0.92, green: 0.46, blue: 0.42))
    }

    private func commonMistakes(for category: DrillCategory) -> [String] {
        switch category {
        case .shooting:
            return [
                "Dropping the elbow — keep it under the ball at the set point.",
                "Rushing the release before reaching full extension.",
                "Letting the off-hand push the shot instead of guiding it."
            ]
        case .ballHandling:
            return [
                "Slapping the ball with your palm instead of pushing through your fingertips.",
                "Eyes drifting down to the ball — keep your gaze up the floor.",
                "Standing too tall — stay low and athletic in your stance."
            ]
        case .defense:
            return [
                "Crossing your feet on a slide — shuffle, don't cross.",
                "Reaching with your hands instead of moving your feet.",
                "Standing straight up — bend at the knees, not the waist."
            ]
        case .conditioning:
            return [
                "Going too hard on early reps and fading at the end.",
                "Skipping the warm-up and risking a tweak.",
                "Holding your breath — breathe rhythmically through the work."
            ]
        case .finishing:
            return [
                "Off-foot takeoffs that kill your balance at the rim.",
                "Forcing the strong-hand finish instead of using the available angle.",
                "Avoiding contact instead of absorbing it through the shot."
            ]
        case .footwork:
            return [
                "Wide, unbalanced stops — land in athletic position.",
                "Telegraphing the pivot before you actually move.",
                "Lifting the pivot foot before the ball leaves your hands."
            ]
        case .iq:
            return [
                "Reading only one defender — scan the full floor.",
                "Forcing the play instead of letting the read come to you.",
                "Talking through the rep instead of internalizing the read."
            ]
        }
    }

    // MARK: - Progressions

    private var progressionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Level Up", title: "Progressions", accent: drill.category.color)

            VStack(spacing: 8) {
                progressionRow(
                    label: "Easier",
                    body: "Halve the pace or reps. Focus on form over speed.",
                    icon: "arrow.down.right.circle.fill",
                    color: DrillDifficulty.beginner.color
                )
                progressionRow(
                    label: "Match",
                    body: drill.setsReps.map { "Run as written: \($0)." } ?? "Run \(drill.durationMinutes) minutes at game pace.",
                    icon: "equal.circle.fill",
                    color: drill.difficulty.color
                )
                progressionRow(
                    label: "Harder",
                    body: progressionUp(for: drill),
                    icon: "arrow.up.right.circle.fill",
                    color: DrillDifficulty.advanced.color
                )
            }
        }
        .editorialCard(accent: drill.category.color)
    }

    private func progressionRow(label: String, body: String, icon: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(color)
                Text(body)
                    .font(.system(size: 12, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(color.opacity(0.05))
        .clipShape(.rect(cornerRadius: 10))
    }

    private func progressionUp(for drill: BasketballDrill) -> String {
        switch drill.category {
        case .shooting: "Add a closeout, shorten the clock, or chart makes per spot."
        case .ballHandling: "Add a second ball, a chair series, or a defender shadow."
        case .defense: "Live partner, longer slides, or chase a recovery to a closeout."
        case .conditioning: "Add a basketball, shorten rest, or extend the work block."
        case .finishing: "Add contact pads, a defender, or off-hand finishes only."
        case .footwork: "Add a live read, smaller spacing, or a second pivot before the move."
        case .iq: "Add a second read, a shot clock, or a live defender."
        }
    }

    // MARK: - Related

    private var relatedCard: some View {
        let related = BasketballDrillLibrary.all.filter { $0.category == drill.category && $0.id != drill.id }.prefix(4)
        return VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "More like this", title: drill.category.rawValue, accent: drill.category.color)
            VStack(spacing: 6) {
                ForEach(Array(related), id: \.id) { related in
                    Button {
                        bbVM.selectedDrill = related
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: related.category.icon)
                                .font(.system(size: 11))
                                .foregroundStyle(related.category.color)
                                .frame(width: 26, height: 26)
                                .background(related.category.color.opacity(0.12))
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 1) {
                                Text(related.name)
                                    .font(.system(size: 12, weight: .semibold, design: .serif))
                                    .foregroundStyle(PepTheme.textPrimary)
                                Text(related.difficulty.rawValue)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                            Spacer()
                            Text("\(related.durationMinutes)m")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(PepTheme.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .editorialCard(accent: drill.category.color)
    }

    // MARK: - Run Bar

    private var runBar: some View {
        EditorialPrimaryButton("Run This Drill", icon: "play.fill", accent: accentColor) {
            bbVM.runningDrill = drill
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .background(
            PepTheme.background
                .shadow(color: .black.opacity(0.5), radius: 20, y: -8)
                .ignoresSafeArea()
        )
    }
}
