import SwiftUI

struct SwimDrillDetailView: View {
    let drill: SwimDrill
    @Environment(\.dismiss) private var dismiss
    @State private var heroAppeared: Bool = false
    @State private var marked: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    heroCard
                    visualCard
                    aboutCard
                    if !drill.steps.isEmpty { stepsCard }
                    if !drill.cues.isEmpty { cuesCard }
                    equipmentCard
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
                    .lineLimit(3)

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
                    statCol(
                        value: drill.targetStroke?.rawValue.prefix(4).uppercased().description ?? "ANY",
                        label: "STROKE"
                    )
                    divider
                    statCol(value: drill.difficulty.rawValue.prefix(3).uppercased(), label: "LEVEL")
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

    private var visualCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            EditorialSectionHeading(kicker: "Visualize", title: "In the Lane", accent: drill.category.color)

            ZStack {
                LinearGradient(
                    colors: [drill.category.color.opacity(0.22), Color.black.opacity(0.45)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    // Lane lines
                    ForEach(0..<5) { i in
                        Path { p in
                            let y = h * CGFloat(i + 1) / 6
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: w, y: y))
                        }
                        .stroke(PepTheme.textPrimary.opacity(0.08), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                    }
                    // Wave
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: h * 0.5))
                        for x in stride(from: 0, through: w, by: 6) {
                            let y = h * 0.5 + sin(x / 18) * 6
                            p.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    .stroke(drill.category.color.opacity(0.45), lineWidth: 1.2)
                }

                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 56, height: 56)
                        Circle()
                            .strokeBorder(drill.category.color.opacity(0.5), lineWidth: 0.5)
                            .frame(width: 56, height: 56)
                        Image(systemName: drill.category.icon)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(drill.category.color)
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

    private var cuesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Coaching", title: "Cues", accent: PepTheme.amber)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(drill.cues, id: \.self) { cue in
                    HStack(alignment: .top, spacing: 10) {
                        Rectangle()
                            .fill(PepTheme.amber)
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
        .editorialCard(accent: PepTheme.amber)
    }

    private var equipmentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            EditorialSectionHeading(kicker: "What You Need", title: "Setup", accent: PepTheme.amber)

            HStack(spacing: 8) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(PepTheme.amber)
                    .frame(width: 26, height: 26)
                    .background(PepTheme.amber.opacity(0.12))
                    .clipShape(Circle())
                Text(drill.equipment)
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
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
        }
        .editorialCard(accent: PepTheme.amber)
    }

    private var commonMistakesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(
                kicker: "Watch Out",
                title: "Common Mistakes",
                accent: Color(red: 0.92, green: 0.46, blue: 0.42)
            )
            VStack(alignment: .leading, spacing: 10) {
                ForEach(commonMistakes(for: drill.category), id: \.self) { mistake in
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

    private func commonMistakes(for category: SwimDrillCategory) -> [String] {
        switch category {
        case .technique:
            return [
                "Rushing the catch — stay patient at the front.",
                "Crossing centerline on entry — wider, cleaner hands.",
                "Lifting the head to breathe — rotate, don't lift."
            ]
        case .kick:
            return [
                "Bending at the knee — kick from the hip.",
                "Stiff ankles — let feet whip.",
                "Kicks too wide — narrow flutter, faster tempo."
            ]
        case .pull:
            return [
                "Dropped elbow on the catch — keep it high.",
                "Pulling water down instead of back.",
                "Overgripping the paddle — relax the hand."
            ]
        case .speed:
            return [
                "Sprinting with broken form — speed needs structure.",
                "Cheating the rest interval — discipline pays off.",
                "Glide-finishing into the wall — drive through."
            ]
        case .endurance:
            return [
                "Going out too hot — negative split it.",
                "Losing breathing rhythm under fatigue.",
                "Letting the kick die — even effort, even kick."
            ]
        case .warmUpCoolDown:
            return [
                "Skipping the warm-up to save time — costs you the set.",
                "Treating cool-down as 'just laps' — actively decelerate.",
                "Holding tension in the shoulders the whole way."
            ]
        }
    }

    private var progressionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Level Up", title: "Progressions", accent: drill.category.color)

            VStack(spacing: 8) {
                progressionRow(
                    label: "Easier",
                    body: "Halve the distance or add 15s rest. Form before pace.",
                    icon: "arrow.down.right.circle.fill",
                    color: SwimDrillDifficulty.beginner.color
                )
                progressionRow(
                    label: "Match",
                    body: drill.setsReps.map { "Run as written: \($0)." } ?? "Run \(drill.durationMinutes) minutes at steady effort.",
                    icon: "equal.circle.fill",
                    color: drill.difficulty.color
                )
                progressionRow(
                    label: "Harder",
                    body: progressionUp(for: drill),
                    icon: "arrow.up.right.circle.fill",
                    color: SwimDrillDifficulty.advanced.color
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

    private func progressionUp(for drill: SwimDrill) -> String {
        switch drill.category {
        case .technique: "Add fins for resistance, hold a tighter streamline, or layer in tempo work."
        case .kick: "Stack with fins or add 25m sprints between sets."
        case .pull: "Add paddles or band the ankles to magnify any leg drop."
        case .speed: "Shorten rest, race the clock, or finish with a fly leg."
        case .endurance: "Add 25% more distance or hold a tighter pace window."
        case .warmUpCoolDown: "Mix in 25m drill segments to keep the warm-up productive."
        }
    }

    private var relatedCard: some View {
        let related = SwimDrillLibraryData.all.filter { $0.category == drill.category && $0.id != drill.id }.prefix(4)
        return VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "More like this", title: drill.category.rawValue, accent: drill.category.color)
            if related.isEmpty {
                Text("This is the only drill in this category — for now.")
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(related), id: \.id) { rel in
                        HStack(spacing: 10) {
                            Image(systemName: rel.category.icon)
                                .font(.system(size: 11))
                                .foregroundStyle(rel.category.color)
                                .frame(width: 26, height: 26)
                                .background(rel.category.color.opacity(0.12))
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 1) {
                                Text(rel.name)
                                    .font(.system(size: 12, weight: .semibold, design: .serif))
                                    .foregroundStyle(PepTheme.textPrimary)
                                    .lineLimit(1)
                                Text(rel.difficulty.rawValue)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                            Spacer()
                            Text("\(rel.durationMinutes)m")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .editorialCard(accent: drill.category.color)
    }

    private var runBar: some View {
        EditorialPrimaryButton(marked ? "Marked Complete" : "Mark Drill Run", icon: marked ? "checkmark.seal.fill" : "checkmark.circle.fill", accent: drill.category.color) {
            withAnimation(.spring(duration: 0.3)) { marked = true }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
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
}
