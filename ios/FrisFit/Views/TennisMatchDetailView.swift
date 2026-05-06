import SwiftUI

struct TennisMatchDetailView: View {
    let match: TennisMatch

    private let accentColor = Color(red: 0.85, green: 0.9, blue: 0.15)

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                heroCard
                if !match.sets.isEmpty { scorecardCard }
                serveCard
                shotStatsCard
                ratingsCard
                if !match.notes.isEmpty { notesCard }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .appBackground(accent: accentColor)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero

    private var heroCard: some View {
        PepSportCard(accent: accentColor) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text((match.sessionType.isMatch ? "MATCH" : "SESSION") + " · " + match.sessionType.rawValue.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.0)
                        .foregroundStyle(accentColor.opacity(0.9))
                    Spacer()
                    if let result = match.result {
                        Text(result.label.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(result.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(result.color.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                Text(heroTitle)
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .kerning(-0.5)
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(2)

                Text(match.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().hour().minute()))
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)

                if !match.sets.isEmpty {
                    Text(match.scoreDisplay)
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundStyle(match.result == .win ? .green : (match.result == .loss ? .red : accentColor))
                }

                LinearGradient(
                    colors: [PepTheme.textPrimary.opacity(0.16), PepTheme.textPrimary.opacity(0)],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 0.5)

                HStack(spacing: 0) {
                    heroStat(value: "\(match.durationMinutes)", label: "MIN")
                    statDivider
                    heroStat(value: "\(match.stats.aces)", label: "ACES")
                    statDivider
                    heroStat(value: "\(match.stats.winners)", label: "WINNERS")
                    statDivider
                    heroStat(value: "\(match.stats.unforcedErrors)", label: "UE")
                }
            }
        }
    }

    private var heroTitle: String {
        if match.sessionType.isMatch && !match.opponentName.isEmpty {
            return "vs \(match.opponentName)"
        }
        return match.sessionType.rawValue
    }

    private var statDivider: some View {
        Rectangle().fill(PepTheme.shimmerHighlight).frame(width: 0.5, height: 28)
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

    // MARK: - Scorecard

    private var scorecardCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "01 — Score", title: "Scorecard", accent: accentColor)

            VStack(spacing: 10) {
                HStack(spacing: 0) {
                    Text("")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(Array(match.sets.enumerated()), id: \.offset) { i, _ in
                        Text("S\(i + 1)")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(PepTheme.textSecondary)
                            .frame(width: 50)
                    }
                }

                HStack(spacing: 0) {
                    Text("YOU")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.6)
                        .foregroundStyle(accentColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(Array(match.sets.enumerated()), id: \.offset) { _, set in
                        Text("\(set.playerGames)")
                            .font(.system(size: 18, weight: .semibold, design: .serif))
                            .foregroundStyle(set.playerWon ? .green : PepTheme.textPrimary)
                            .frame(width: 50)
                    }
                }

                Rectangle().fill(PepTheme.elevated.opacity(0.6)).frame(height: 0.5)

                HStack(spacing: 0) {
                    Text((match.opponentName.isEmpty ? "Opponent" : match.opponentName).uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.6)
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(Array(match.sets.enumerated()), id: \.offset) { _, set in
                        Text("\(set.opponentGames)")
                            .font(.system(size: 18, weight: .semibold, design: .serif))
                            .foregroundStyle(!set.playerWon && (set.playerGames + set.opponentGames > 0) ? .red : PepTheme.textPrimary)
                            .frame(width: 50)
                    }
                }
            }
        }
        .editorialCard(accent: accentColor)
    }

    // MARK: - Serve

    private var serveCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "02 — Serve", title: "Serve Analysis", accent: accentColor)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                statCell(value: String(format: "%.0f%%", match.stats.firstServePercentage), label: "1st Srv", color: accentColor)
                statCell(value: "\(match.stats.aces)", label: "Aces", color: .green)
                statCell(value: "\(match.stats.doubleFaults)", label: "Dbl Flt", color: .red)
            }

            if match.stats.breakPointsTotal > 0 {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    statCell(value: "\(match.stats.breakPointsConverted)/\(match.stats.breakPointsTotal)", label: "Break Pts", color: PepTheme.amber)
                    statCell(value: String(format: "%.0f%%", match.stats.breakPointConversionRate), label: "BP Conv", color: PepTheme.amber)
                }
            }
        }
        .editorialCard(accent: accentColor)
    }

    // MARK: - Shot stats

    private var shotStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "03 — Rally", title: "Shot Stats", accent: PepTheme.amber)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                statCell(value: "\(match.stats.winners)", label: "Winners", color: .green)
                statCell(value: "\(match.stats.unforcedErrors)", label: "UE", color: .red)
                statCell(value: String(format: "%.2f", match.stats.winnerToErrorRatio), label: "W/UE", color: match.stats.winnerToErrorRatio >= 1.0 ? .green : .orange)
            }

            if match.stats.totalShotsTracked > 0 {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    statCell(value: "\(match.stats.forehandsHit)", label: "Forehands", color: accentColor)
                    statCell(value: "\(match.stats.backhandsHit)", label: "Backhands", color: .green)
                    statCell(value: "\(match.stats.servesHit)", label: "Serves", color: .blue)
                    statCell(value: "\(match.stats.volleysHit)", label: "Volleys", color: .orange)
                }
            }
        }
        .editorialCard(accent: PepTheme.amber)
    }

    // MARK: - Ratings

    private var ratingsCard: some View {
        HStack(spacing: 10) {
            ratingCol(label: "Performance", value: match.performanceRating, icon: "star.fill", color: PepTheme.amber)
            ratingCol(label: "Confidence", value: match.confidenceRating, icon: "brain.head.profile.fill", color: PepTheme.violet)
        }
    }

    private func ratingCol(label: String, value: Int, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
            Text("\(value)/10")
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(color)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .editorialCard(accent: color)
    }

    // MARK: - Notes

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            EditorialSectionHeading(kicker: "Notes", title: "Match Journal", accent: accentColor)
            Text(match.notes)
                .font(.system(size: 14, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .editorialCard(accent: accentColor)
    }

    private func statCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 5) {
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
        .padding(.vertical, 12)
        .background(color.opacity(0.07))
        .clipShape(.rect(cornerRadius: 10))
    }
}
