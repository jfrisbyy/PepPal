import SwiftUI

struct MartialArtsSessionDetailView: View {
    let session: MartialArtsSession
    @Environment(\.dismiss) private var dismiss

    private var accentColor: Color { session.discipline.color }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                heroCard
                statsCard
                if !session.techniquesWorked.isEmpty {
                    techniquesCard
                }
                if !session.opponentName.isEmpty || !session.coachName.isEmpty || !session.gymName.isEmpty {
                    contextCard
                }
                vibeCard
                if !session.notes.isEmpty {
                    notesCard
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .appBackground(accent: accentColor)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .foregroundStyle(accentColor)
            }
        }
    }

    private var heroCard: some View {
        PepSportCard(accent: accentColor) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text(session.discipline.rawValue.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.0)
                        .foregroundStyle(accentColor.opacity(0.95))
                    Spacer()
                    if let outcome = session.outcome {
                        Text(outcome.label.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(outcome.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(outcome.color.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                Text(heroTitle)
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .kerning(-0.4)
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(session.sessionType.rawValue.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.violet)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(PepTheme.violet.opacity(0.12))
                        .clipShape(Capsule())
                    Text(session.date.formatted(.dateTime.weekday().month(.wide).day().year()))
                        .font(.system(size: 12, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary)
                }

                LinearGradient(
                    colors: [PepTheme.textPrimary.opacity(0.16), PepTheme.textPrimary.opacity(0)],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 0.5)

                HStack(spacing: 0) {
                    heroStat(value: "\(session.durationMinutes)m", label: "TIME")
                    heroDivider
                    heroStat(value: "\(session.stats.roundsCompleted)", label: "ROUNDS")
                    heroDivider
                    heroStat(value: "\(session.intensity)/10", label: "INTENSITY")
                }
            }
        }
    }

    private var heroTitle: String {
        if session.sessionType.isCompetitive {
            return session.opponentName.isEmpty ? "Competition" : "vs \(session.opponentName)"
        }
        if !session.opponentName.isEmpty {
            return "with \(session.opponentName)"
        }
        return session.sessionType.rawValue
    }

    private func heroStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var heroDivider: some View {
        Rectangle()
            .fill(PepTheme.shimmerHighlight)
            .frame(width: 0.5, height: 28)
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "Box", title: "Stat Line", accent: PepTheme.amber)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                if session.stats.totalStrikes > 0 {
                    statTile(value: "\(session.stats.totalStrikes)", label: "Total Strikes", color: PepTheme.amber)
                }
                if session.stats.lowKicks + session.stats.bodyKicks + session.stats.headKicks > 0 {
                    statTile(value: "\(session.stats.lowKicks + session.stats.bodyKicks + session.stats.headKicks)", label: "Kicks", color: accentColor)
                }
                if session.stats.takedownsAttempted > 0 {
                    statTile(value: "\(session.stats.takedownsLanded)/\(session.stats.takedownsAttempted)", label: "Takedowns", color: PepTheme.violet)
                    statTile(value: String(format: "%.0f%%", session.stats.takedownPercentage * 100), label: "TD %", color: session.stats.takedownPercentage >= 0.5 ? .green : PepTheme.violet)
                }
                if session.stats.submissionsLanded > 0 {
                    statTile(value: "\(session.stats.submissionsLanded)", label: "Subs Landed", color: .green)
                }
                if session.stats.tapsReceived > 0 {
                    statTile(value: "\(session.stats.tapsReceived)", label: "Taps Recvd", color: .red)
                }
                if session.stats.sweepsLanded > 0 {
                    statTile(value: "\(session.stats.sweepsLanded)", label: "Sweeps", color: PepTheme.violet)
                }
                if session.stats.passesLanded > 0 {
                    statTile(value: "\(session.stats.passesLanded)", label: "Passes", color: accentColor)
                }
                if session.stats.totalStrikes == 0 && session.stats.takedownsAttempted == 0 && session.stats.submissionsLanded == 0 {
                    statTile(value: "\(session.durationMinutes)m", label: "Mat Time", color: accentColor)
                }
            }
        }
        .editorialCard(accent: PepTheme.amber)
    }

    private func statTile(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.10))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var techniquesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "Detail", title: "Techniques", accent: PepTheme.violet)
            MartialArtsTagFlow(spacing: 8) {
                ForEach(session.techniquesWorked, id: \.self) { tech in
                    Text(tech)
                        .font(.system(size: 12, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.violet)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(PepTheme.violet.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
        .editorialCard(accent: PepTheme.violet)
    }

    private var contextCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "Context", title: "Where & With", accent: accentColor)
            VStack(alignment: .leading, spacing: 10) {
                if !session.gymName.isEmpty {
                    contextRow(label: "Gym", value: session.gymName, icon: "building.2.fill")
                }
                if !session.coachName.isEmpty {
                    contextRow(label: "Coach", value: session.coachName, icon: "person.fill.checkmark")
                }
                if !session.opponentName.isEmpty {
                    contextRow(label: session.sessionType.isCompetitive ? "Opponent" : "Partner",
                               value: session.opponentName, icon: "person.fill")
                }
            }
        }
        .editorialCard(accent: accentColor)
    }

    private func contextRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(accentColor)
                .frame(width: 22)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(PepTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }

    private var vibeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "Vibe", title: "How It Felt", accent: PepTheme.amber)
            HStack(spacing: 10) {
                vibeTile(label: "Energy", value: session.energyRating, color: accentColor)
                vibeTile(label: "Technique", value: session.techniqueRating, color: PepTheme.violet)
                vibeTile(label: "Cardio", value: session.cardioRating, color: PepTheme.amber)
            }
        }
        .editorialCard(accent: PepTheme.amber)
    }

    private func vibeTile(label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 6) {
            Text("\(value)")
                .font(.system(size: 22, weight: .black, design: .serif))
                .foregroundStyle(color)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.10))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "Story", title: "Notes", accent: accentColor)
            Text(session.notes)
                .font(.system(size: 14, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .editorialCard(accent: accentColor)
    }
}

// MARK: - Simple flow layout for tags

private struct MartialArtsTagFlow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                maxRowWidth = max(maxRowWidth, rowWidth - spacing)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        maxRowWidth = max(maxRowWidth, rowWidth - spacing)
        return CGSize(width: maxRowWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
