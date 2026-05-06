import SwiftUI

struct SoccerGameDetailView: View {
    let match: SoccerMatch
    private let accentColor = Color(red: 0.2, green: 0.78, blue: 0.35)

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                heroCard
                if match.sessionType.isGame {
                    statLineCard
                    attackingCard
                    defendingCard
                    disciplineCard
                }
                if match.distanceKm > 0 {
                    movementCard
                }
                selfAssessmentCard
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
    }

    private var heroCard: some View {
        PepSportCard(accent: match.result?.color ?? accentColor) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    HStack(spacing: 6) {
                        Image(systemName: match.sessionType.icon)
                            .font(.system(size: 9, weight: .bold))
                        Text(match.sessionType.rawValue.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(2.0)
                    }
                    .foregroundStyle(accentColor.opacity(0.9))

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

                if let ts = match.teamScore, let os = match.opponentScore {
                    Text("\(ts) – \(os)")
                        .font(.system(size: 40, weight: .semibold, design: .serif))
                        .kerning(-1.0)
                        .foregroundStyle(match.result?.color ?? PepTheme.textPrimary)
                } else {
                    Text(match.sessionType.rawValue)
                        .font(.system(size: 28, weight: .semibold, design: .serif))
                        .kerning(-0.5)
                        .foregroundStyle(PepTheme.textPrimary)
                }

                HStack(spacing: 8) {
                    Text(match.position.shortName)
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(accentColor.opacity(0.12))
                        .clipShape(Capsule())
                    Text(match.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                        .font(.system(size: 12, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                }

                LinearGradient(
                    colors: [PepTheme.textPrimary.opacity(0.16), PepTheme.textPrimary.opacity(0)],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 0.5)

                if match.sessionType.isGame {
                    HStack(spacing: 0) {
                        broadcastStat(value: "\(match.stats.goals)", label: "G")
                        divider
                        broadcastStat(value: "\(match.stats.assists)", label: "A")
                        divider
                        broadcastStat(value: "\(match.stats.shotsOnTarget)", label: "SOT")
                        divider
                        broadcastStat(value: "\(match.stats.tacklesWon)", label: "TKL")
                        divider
                        broadcastStat(value: "\(match.stats.interceptions)", label: "INT")
                    }
                }
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(PepTheme.shimmerHighlight)
            .frame(width: 0.5, height: 28)
    }

    private func broadcastStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var statLineCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "Headline",
                title: "Stat Line",
                accent: accentColor,
                trailing: match.stats.minutesPlayed > 0 ? AnyView(
                    Text("\(match.stats.minutesPlayed) MIN")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textSecondary)
                ) : nil
            )

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 10) {
                detailStatCell(value: "\(match.stats.goals)", label: "GOALS", color: accentColor)
                detailStatCell(value: "\(match.stats.assists)", label: "AST", color: .blue)
                detailStatCell(value: "\(match.stats.goalContributions)", label: "G+A", color: .cyan)
                detailStatCell(value: "\(match.performanceRating)/10", label: "RATING", color: PepTheme.amber)
            }
        }
        .editorialCard(accent: accentColor)
    }

    private var attackingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "Final Third", title: "Attacking", accent: accentColor)

            VStack(spacing: 10) {
                statRow(label: "Goals", value: "\(match.stats.goals)", color: accentColor)
                statRow(label: "Assists", value: "\(match.stats.assists)", color: .blue)
                statRow(label: "Shots on target", value: "\(match.stats.shotsOnTarget)", color: .green)
                statRow(label: "Shots off target", value: "\(match.stats.shotsOffTarget)", color: .orange)
                statRow(label: "Shot accuracy", value: String(format: "%.0f%%", match.stats.shotAccuracy), color: match.stats.shotAccuracy >= 50 ? .green : .orange)
                statRow(label: "Key passes", value: "\(match.stats.keyPasses)", color: .cyan)
            }
        }
        .editorialCard(accent: accentColor)
    }

    private var defendingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "Backline", title: "Defending", accent: .red)

            VStack(spacing: 10) {
                statRow(label: "Tackles won", value: "\(match.stats.tacklesWon)", color: .green)
                statRow(label: "Tackles lost", value: "\(match.stats.tacklesLost)", color: .red)
                statRow(label: "Tackle success", value: String(format: "%.0f%%", match.stats.tackleSuccessRate), color: match.stats.tackleSuccessRate >= 60 ? .green : .orange)
                statRow(label: "Interceptions", value: "\(match.stats.interceptions)", color: .blue)
            }
        }
        .editorialCard(accent: .red)
    }

    private var disciplineCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "Conduct", title: "Discipline", accent: PepTheme.amber)

            HStack(spacing: 10) {
                disciplineStat(value: "\(match.stats.foulsCommitted)", label: "Fouls", color: .orange)
                disciplineStat(value: "\(match.stats.foulsWon)", label: "Fouls Won", color: .green)
                disciplineStat(value: "\(match.stats.yellowCards)", label: "Yellows", color: .yellow)
                disciplineStat(value: "\(match.stats.redCards)", label: "Reds", color: .red)
            }
        }
        .editorialCard(accent: PepTheme.amber)
    }

    private func disciplineStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(color)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 10))
    }

    private var movementCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "Engine", title: "Movement", accent: accentColor)

            HStack(spacing: 0) {
                movementCol(value: String(format: "%.1f", match.distanceKm), unit: "km", label: "DISTANCE", color: accentColor)
                divider
                movementCol(value: "\(match.sprintCount)", unit: "", label: "SPRINTS", color: .orange)
                divider
                movementCol(value: String(format: "%.1f", match.topSpeedKmh), unit: "km/h", label: "TOP SPEED", color: .red)
            }
        }
        .editorialCard(accent: accentColor)
    }

    private func movementCol(value: String, unit: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                Text(value)
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(color)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(color.opacity(0.7))
                }
            }
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var selfAssessmentCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "How It Felt", title: "Self Assessment", accent: PepTheme.violet)

            HStack(spacing: 16) {
                ratingColumn(value: match.performanceRating, label: "Performance", color: PepTheme.amber)
                Rectangle()
                    .fill(PepTheme.glassBorderTop)
                    .frame(width: 0.5, height: 60)
                ratingColumn(value: match.confidenceRating, label: "Confidence", color: PepTheme.violet)
            }
        }
        .editorialCard(accent: PepTheme.violet)
    }

    private func ratingColumn(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text("\(value)")
                .font(.system(size: 32, weight: .semibold, design: .serif))
                .foregroundStyle(color)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(PepTheme.textSecondary)
            HStack(spacing: 3) {
                ForEach(1...10, id: \.self) { i in
                    Circle()
                        .fill(i <= value ? color : PepTheme.elevated)
                        .frame(width: 5, height: 5)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            EditorialSectionHeading(kicker: "Reflection", title: "Notes", accent: PepTheme.textSecondary)
            Text(match.notes)
                .font(.system(size: 14, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .editorialCard(accent: nil)
    }

    private func detailStatCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.06))
        .clipShape(.rect(cornerRadius: 10))
    }

    private func statRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, design: .serif))
                .foregroundStyle(PepTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundStyle(color)
        }
    }
}
