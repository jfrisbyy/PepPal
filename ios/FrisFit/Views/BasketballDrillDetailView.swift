import SwiftUI

struct BasketballDrillDetailView: View {
    let drill: BasketballDrill
    @Bindable var bbVM: BasketballViewModel
    @Environment(\.dismiss) private var dismiss

    private let accentColor = BasketballPalette.courtOrange

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    heroCard
                    masteryCard
                    if !drill.steps.isEmpty {
                        stepsCard
                    }
                    if !drill.cues.isEmpty {
                        cuesCard
                    }
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
        }
    }

    private var heroCard: some View {
        PepSportCard(accent: drill.category.color) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(drill.category.rawValue.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.0)
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

    private var masteryCard: some View {
        let mastery = bbVM.mastery(for: drill)
        let count = bbVM.sessionCount(for: drill)
        return VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Your Progress", title: mastery.rawValue, accent: mastery.color)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(PepTheme.elevated)
                    Capsule()
                        .fill(LinearGradient(colors: [mastery.color, mastery.color.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * mastery.progress)
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
        }
        .editorialCard(accent: mastery.color)
    }

    private func nextLevelText(count: Int) -> String {
        switch count {
        case 0...1: "Run it 2× to reach Working"
        case 2...4: "Run it 5× total to reach Sharp"
        case 5...9: "Run it 10× total to Lock In"
        default: "Locked in — keep it sharp"
        }
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "How To", title: "Steps", accent: drill.category.color)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(drill.steps.enumerated()), id: \.offset) { idx, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text(String(format: "%02d", idx + 1))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(drill.category.color)
                            .frame(width: 24, alignment: .leading)
                        Text(step)
                            .font(.system(size: 13, design: .serif))
                            .foregroundStyle(PepTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .editorialCard(accent: drill.category.color)
    }

    private var cuesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Coaching", title: "Cues", accent: BasketballPalette.courtAmber)
            VStack(spacing: 6) {
                ForEach(drill.cues, id: \.self) { cue in
                    HStack(spacing: 10) {
                        Image(systemName: "quote.opening")
                            .font(.system(size: 11))
                            .foregroundStyle(BasketballPalette.courtAmber)
                        Text(cue)
                            .font(.system(size: 13, design: .serif))
                            .italic()
                            .foregroundStyle(PepTheme.textPrimary)
                        Spacer()
                    }
                }
            }
        }
        .editorialCard(accent: BasketballPalette.courtAmber)
    }

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
