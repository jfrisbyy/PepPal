import SwiftUI

struct PickleballMatchDetailView: View {
    let match: PickleballMatch
    @Environment(\.dismiss) private var dismiss

    private let accentColor = Color(red: 0.62, green: 0.86, blue: 0.18)

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                heroCard
                if !match.games.isEmpty {
                    gamesCard
                }
                statsCard
                if match.stats.thirdShotDropsAttempted > 0 || match.stats.dinksWon + match.stats.dinksLost > 0 {
                    softGameCard
                }
                if !match.partnerName.isEmpty || !match.venue.isEmpty || match.dupr != nil {
                    contextCard
                }
                vibeCard
                if !match.notes.isEmpty {
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
                    Text(match.sessionType.rawValue.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.0)
                        .foregroundStyle(accentColor.opacity(0.95))
                    Spacer()
                    if let result = match.result {
                        Text(result.label.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(result.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(result.color.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                Text(heroTitle)
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .kerning(-0.4)
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(match.format.rawValue.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.violet)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(PepTheme.violet.opacity(0.12))
                        .clipShape(Capsule())
                    Text(match.date.formatted(.dateTime.weekday().month(.wide).day().year()))
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
                    heroStat(value: "\(match.stats.winners)", label: "WINNERS")
                    heroDivider
                    heroStat(value: "\(match.stats.unforcedErrors)", label: "ERRORS")
                    heroDivider
                    heroStat(value: "\(match.stats.aces)", label: "ACES")
                    heroDivider
                    heroStat(value: "\(match.durationMinutes)m", label: "TIME")
                }
            }
        }
    }

    private var heroTitle: String {
        if !match.opponentName.isEmpty {
            return "vs \(match.opponentName)"
        }
        return match.sessionType.rawValue
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

    private var gamesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "Score", title: "Game-by-Game", accent: accentColor)
            VStack(spacing: 8) {
                ForEach(Array(match.games.enumerated()), id: \.offset) { idx, game in
                    HStack {
                        Text("GAME \(idx + 1)")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(PepTheme.textSecondary)
                            .frame(width: 64, alignment: .leading)
                        Spacer()
                        HStack(spacing: 8) {
                            Text("\(game.teamPoints)")
                                .font(.system(size: 16, weight: .bold, design: .serif))
                                .foregroundStyle(game.teamWon ? .green : PepTheme.textPrimary)
                            Text("–")
                                .font(.system(size: 12))
                                .foregroundStyle(PepTheme.textSecondary)
                            Text("\(game.opponentPoints)")
                                .font(.system(size: 16, weight: .bold, design: .serif))
                                .foregroundStyle(!game.teamWon ? .red : PepTheme.textSecondary)
                        }
                    }
                    .padding(.vertical, 6)
                    .overlay(alignment: .bottom) {
                        if idx < match.games.count - 1 {
                            Rectangle()
                                .fill(PepTheme.glassBorderTop)
                                .frame(height: 0.5)
                        }
                    }
                }
            }
        }
        .editorialCard(accent: accentColor)
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "Box", title: "Stat Line", accent: PepTheme.amber)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                statTile(value: "\(match.stats.winners)", label: "Winners", color: accentColor)
                statTile(value: "\(match.stats.unforcedErrors)", label: "Errors", color: .red)
                statTile(value: String(format: "%.2f", match.stats.winnerToErrorRatio), label: "W:E Ratio", color: match.stats.winnerToErrorRatio >= 1.0 ? .green : accentColor)
                statTile(value: "\(match.stats.aces)", label: "Aces", color: PepTheme.amber)
                if match.stats.firstServeAttempts > 0 {
                    statTile(value: String(format: "%.0f%%", match.stats.firstServePercentage * 100), label: "1st Serve %", color: .green)
                } else {
                    statTile(value: "\(match.stats.serviceFaults)", label: "Faults", color: .red)
                }
                if match.stats.returnPointsPlayed > 0 {
                    statTile(value: String(format: "%.0f%%", match.stats.returnPointPercentage * 100), label: "Return Pts %", color: PepTheme.violet)
                } else {
                    statTile(value: "\(match.stats.kitchenViolations)", label: "Kitchen Vio.", color: .orange)
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

    private var softGameCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "Kitchen", title: "Soft Game", accent: PepTheme.violet)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                if match.stats.thirdShotDropsAttempted > 0 {
                    statTile(value: "\(match.stats.thirdShotDropsMade)/\(match.stats.thirdShotDropsAttempted)", label: "Drops", color: PepTheme.violet)
                    statTile(value: String(format: "%.0f%%", match.stats.thirdShotDropPercentage * 100), label: "Drop %", color: match.stats.thirdShotDropPercentage >= 0.6 ? .green : PepTheme.violet)
                }
                if match.stats.dinksWon + match.stats.dinksLost > 0 {
                    statTile(value: "\(match.stats.dinksWon)", label: "Dinks Won", color: .green)
                    statTile(value: "\(match.stats.dinksLost)", label: "Dinks Lost", color: .red)
                }
                if match.stats.atpHits > 0 || match.stats.ernes > 0 {
                    statTile(value: "\(match.stats.atpHits)", label: "ATPs", color: PepTheme.amber)
                    statTile(value: "\(match.stats.ernes)", label: "Ernes", color: PepTheme.amber)
                }
                if match.stats.blockVolleysWon > 0 {
                    statTile(value: "\(match.stats.blockVolleysWon)", label: "Block Volleys", color: .blue)
                }
            }
        }
        .editorialCard(accent: PepTheme.violet)
    }

    private var contextCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "Context", title: "Where & With", accent: accentColor)
            VStack(alignment: .leading, spacing: 10) {
                if !match.venue.isEmpty {
                    contextRow(label: "Venue", value: match.venue, icon: "building.2.fill")
                }
                contextRow(label: "Side", value: match.side.description, icon: match.side.icon)
                contextRow(label: "Format", value: match.format.rawValue, icon: match.format.icon)
                if !match.partnerName.isEmpty {
                    contextRow(label: "Partner", value: match.partnerName, icon: "person.fill")
                }
                if let dupr = match.dupr {
                    contextRow(label: "DUPR", value: String(format: "%.2f", dupr), icon: "chart.line.uptrend.xyaxis")
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
                vibeTile(label: "Energy", value: match.energyRating, color: accentColor)
                vibeTile(label: "Footwork", value: match.footworkRating, color: PepTheme.violet)
                vibeTile(label: "Confidence", value: match.confidenceRating, color: PepTheme.amber)
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
            Text(match.notes)
                .font(.system(size: 14, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .editorialCard(accent: accentColor)
    }
}
