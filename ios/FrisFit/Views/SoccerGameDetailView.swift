import SwiftUI

struct SoccerGameDetailView: View {
    let match: SoccerMatch
    private let accentColor = Color(red: 0.2, green: 0.78, blue: 0.35)

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                matchHeader
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
                fpCard
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(FrisTheme.background.ignoresSafeArea())
        .navigationTitle("Match Detail")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var matchHeader: some View {
        GlassCard {
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill((match.result?.color ?? accentColor).opacity(0.15))
                            .frame(width: 56, height: 56)
                        if let result = match.result {
                            Text(result.rawValue)
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundStyle(result.color)
                        } else {
                            Image(systemName: match.sessionType.icon)
                                .font(.system(size: 24))
                                .foregroundStyle(accentColor)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(match.sessionType.rawValue)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(FrisTheme.textPrimary)
                            Text(match.position.shortName)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(accentColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(accentColor.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        Text(match.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                            .font(.caption)
                            .foregroundStyle(FrisTheme.textSecondary)
                    }

                    Spacer()

                    if let ts = match.teamScore, let os = match.opponentScore {
                        VStack(spacing: 2) {
                            Text("\(ts) — \(os)")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(match.result?.color ?? FrisTheme.textPrimary)
                            Text("Final Score")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(FrisTheme.textSecondary)
                        }
                    }
                }

                if match.sessionType.isGame {
                    HStack(spacing: 0) {
                        broadcastStat(value: "\(match.stats.goals)", label: "G")
                        Divider().frame(height: 30).overlay(FrisTheme.elevated)
                        broadcastStat(value: "\(match.stats.assists)", label: "A")
                        Divider().frame(height: 30).overlay(FrisTheme.elevated)
                        broadcastStat(value: "\(match.stats.shotsOnTarget)", label: "SOT")
                        Divider().frame(height: 30).overlay(FrisTheme.elevated)
                        broadcastStat(value: "\(match.stats.tacklesWon)", label: "TKL")
                        Divider().frame(height: 30).overlay(FrisTheme.elevated)
                        broadcastStat(value: "\(match.stats.interceptions)", label: "INT")
                    }
                    .padding(.vertical, 10)
                    .background(FrisTheme.elevated.opacity(0.5))
                    .clipShape(.rect(cornerRadius: 12))
                }
            }
        }
    }

    private func broadcastStat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(FrisTheme.textPrimary)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(FrisTheme.textSecondary)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
    }

    private var statLineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Full Stat Line")
                Spacer()
                if match.stats.minutesPlayed > 0 {
                    Text("\(match.stats.minutesPlayed) min")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(FrisTheme.textSecondary)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 10) {
                detailStatCell(value: "\(match.stats.goals)", label: "GOALS", color: accentColor)
                detailStatCell(value: "\(match.stats.assists)", label: "AST", color: .blue)
                detailStatCell(value: "\(match.stats.goalContributions)", label: "G+A", color: .cyan)
                detailStatCell(value: "\(match.performanceRating)/10", label: "RATING", color: FrisTheme.amber)
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private var attackingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "scope")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Attacking")
                Spacer()
            }

            VStack(spacing: 10) {
                statRow(label: "Goals", value: "\(match.stats.goals)", color: accentColor)
                statRow(label: "Assists", value: "\(match.stats.assists)", color: .blue)
                statRow(label: "Shots On Target", value: "\(match.stats.shotsOnTarget)", color: .green)
                statRow(label: "Shots Off Target", value: "\(match.stats.shotsOffTarget)", color: .orange)
                statRow(label: "Shot Accuracy", value: String(format: "%.0f%%", match.stats.shotAccuracy), color: match.stats.shotAccuracy >= 50 ? .green : .orange)
                statRow(label: "Key Passes", value: "\(match.stats.keyPasses)", color: .cyan)
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private var defendingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundStyle(.red)
                HeadlineText(text: "Defending")
                Spacer()
            }

            VStack(spacing: 10) {
                statRow(label: "Tackles Won", value: "\(match.stats.tacklesWon)", color: .green)
                statRow(label: "Tackles Lost", value: "\(match.stats.tacklesLost)", color: .red)
                statRow(label: "Tackle Success", value: String(format: "%.0f%%", match.stats.tackleSuccessRate), color: match.stats.tackleSuccessRate >= 60 ? .green : .orange)
                statRow(label: "Interceptions", value: "\(match.stats.interceptions)", color: .blue)
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private var disciplineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(FrisTheme.amber)
                HeadlineText(text: "Discipline")
                Spacer()
            }

            HStack(spacing: 10) {
                disciplineStat(value: "\(match.stats.foulsCommitted)", label: "Fouls", color: .orange)
                disciplineStat(value: "\(match.stats.foulsWon)", label: "Fouls Won", color: .green)
                disciplineStat(value: "\(match.stats.yellowCards)", label: "Yellows", color: .yellow)
                disciplineStat(value: "\(match.stats.redCards)", label: "Reds", color: .red)
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private func disciplineStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(FrisTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 10))
    }

    private var movementCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.run")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Movement")
                Spacer()
            }

            HStack(spacing: 10) {
                movementStat(value: String(format: "%.1f", match.distanceKm), unit: "km", label: "Distance", color: accentColor)
                movementStat(value: "\(match.sprintCount)", unit: "", label: "Sprints", color: .orange)
                movementStat(value: String(format: "%.1f", match.topSpeedKmh), unit: "km/h", label: "Top Speed", color: .red)
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private func movementStat(value: String, unit: String, label: String, color: Color) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 2) {
                Text(value)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(color)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(color.opacity(0.7))
                }
            }
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(FrisTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 10))
    }

    private var selfAssessmentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile.fill")
                    .foregroundStyle(FrisTheme.violet)
                HeadlineText(text: "Self Assessment")
                Spacer()
            }

            HStack(spacing: 16) {
                VStack(spacing: 6) {
                    Text("\(match.performanceRating)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(FrisTheme.amber)
                    Text("Performance")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(FrisTheme.textSecondary)
                    ratingDots(value: match.performanceRating, color: FrisTheme.amber)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(FrisTheme.elevated)
                    .frame(width: 1, height: 50)

                VStack(spacing: 6) {
                    Text("\(match.confidenceRating)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(FrisTheme.violet)
                    Text("Confidence")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(FrisTheme.textSecondary)
                    ratingDots(value: match.confidenceRating, color: FrisTheme.violet)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [FrisTheme.violet.opacity(0.12), FrisTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    private func ratingDots(value: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            ForEach(1...10, id: \.self) { i in
                Circle()
                    .fill(i <= value ? color : FrisTheme.elevated)
                    .frame(width: 6, height: 6)
            }
        }
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundStyle(FrisTheme.textSecondary)
                HeadlineText(text: "Notes")
                Spacer()
            }
            Text(match.notes)
                .font(.subheadline)
                .foregroundStyle(FrisTheme.textSecondary)
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private var fpCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("FP EARNED")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(FrisTheme.textSecondary)
                    .tracking(1)
                Text("\(match.durationMinutes) min · \(match.sessionType.rawValue) · \(match.position.shortName)")
                    .font(.system(size: 11))
                    .foregroundStyle(FrisTheme.textSecondary.opacity(0.7))
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(FrisTheme.cyan)
                Text("\(match.fpEarned)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(FrisTheme.cyan)
                Text("FP")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FrisTheme.cyan.opacity(0.7))
            }
        }
        .padding(16)
        .background(FrisTheme.cyan.opacity(0.08))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(FrisTheme.cyan.opacity(0.2), lineWidth: 0.5)
        )
    }

    private func detailStatCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(FrisTheme.textSecondary)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.06))
        .clipShape(.rect(cornerRadius: 10))
    }

    private func statRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(FrisTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
    }

    private func cardBorder() -> some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(
                LinearGradient(colors: [FrisTheme.glassBorderTop, FrisTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 0.5
            )
    }
}
