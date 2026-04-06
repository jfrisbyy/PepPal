import SwiftUI

struct TennisMatchDetailView: View {
    let match: TennisMatch

    private let accentColor = Color(red: 0.85, green: 0.9, blue: 0.15)

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                matchHeader
                if !match.sets.isEmpty { scorecardSection }
                serveSection
                shotStatsSection
                ratingsSection
                if !match.notes.isEmpty { notesSection }
                fpSection
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(PepTheme.background.ignoresSafeArea())
        .navigationTitle(match.sessionType.isMatch ? "Match Detail" : "Session Detail")
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
                        if match.sessionType.isMatch && !match.opponentName.isEmpty {
                            Text("vs \(match.opponentName)")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(PepTheme.textPrimary)
                        } else {
                            Text(match.sessionType.rawValue)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(PepTheme.textPrimary)
                        }

                        Text(match.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().hour().minute()))
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(match.durationMinutes)")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("min")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }

                if !match.sets.isEmpty {
                    Text(match.scoreDisplay)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(match.result == .win ? .green : match.result == .loss ? .red : accentColor)
                }
            }
        }
    }

    private var scorecardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.number")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Scorecard")
                Spacer()
            }

            VStack(spacing: 8) {
                HStack(spacing: 0) {
                    Text("")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(Array(match.sets.enumerated()), id: \.offset) { i, _ in
                        Text("Set \(i + 1)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(PepTheme.textSecondary)
                            .frame(width: 50)
                    }
                }

                HStack(spacing: 0) {
                    Text("You")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(Array(match.sets.enumerated()), id: \.offset) { _, set in
                        Text("\(set.playerGames)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(set.playerWon ? .green : PepTheme.textPrimary)
                            .frame(width: 50)
                    }
                }

                Rectangle().fill(PepTheme.elevated).frame(height: 1)

                HStack(spacing: 0) {
                    Text(match.opponentName.isEmpty ? "Opponent" : match.opponentName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(Array(match.sets.enumerated()), id: \.offset) { _, set in
                        Text("\(set.opponentGames)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(!set.playerWon ? .red : PepTheme.textPrimary)
                            .frame(width: 50)
                    }
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private var serveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Serve Analysis")
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                statCell(value: String(format: "%.0f%%", match.stats.firstServePercentage), label: "1st Srv%", color: accentColor)
                statCell(value: "\(match.stats.aces)", label: "Aces", color: .green)
                statCell(value: "\(match.stats.doubleFaults)", label: "Dbl Faults", color: .red)
            }

            if match.stats.breakPointsTotal > 0 {
                HStack(spacing: 8) {
                    statCell(value: "\(match.stats.breakPointsConverted)/\(match.stats.breakPointsTotal)", label: "Break Pts", color: PepTheme.amber)
                    statCell(value: String(format: "%.0f%%", match.stats.breakPointConversionRate), label: "BP Conv%", color: PepTheme.amber)
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private var shotStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.green)
                HeadlineText(text: "Shot Stats")
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                statCell(value: "\(match.stats.winners)", label: "Winners", color: .green)
                statCell(value: "\(match.stats.unforcedErrors)", label: "UE", color: .red)
                statCell(value: String(format: "%.1f", match.stats.winnerToErrorRatio), label: "W/UE Ratio", color: match.stats.winnerToErrorRatio >= 1.0 ? .green : .orange)
            }

            if match.stats.totalShotsTracked > 0 {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    statCell(value: "\(match.stats.forehandsHit)", label: "Forehands", color: accentColor)
                    statCell(value: "\(match.stats.backhandsHit)", label: "Backhands", color: .green)
                    statCell(value: "\(match.stats.servesHit)", label: "Serves", color: .blue)
                    statCell(value: "\(match.stats.volleysHit)", label: "Volleys", color: .orange)
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private var ratingsSection: some View {
        HStack(spacing: 8) {
            ratingCard(label: "Performance", value: match.performanceRating, icon: "star.fill", color: PepTheme.amber)
            ratingCard(label: "Confidence", value: match.confidenceRating, icon: "brain.head.profile.fill", color: PepTheme.violet)
        }
    }

    private func ratingCard(label: String, value: Int, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
            Text("\(value)/10")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundStyle(PepTheme.textSecondary)
                HeadlineText(text: "Notes")
                Spacer()
            }
            Text(match.notes)
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private var fpSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("FP EARNED")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .tracking(1)
                Text(match.sessionType.rawValue)
                    .font(.system(size: 11))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(PepTheme.teal)
                Text("\(match.fpEarned)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.teal)
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

    private func statCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 10))
    }

    private func cardBorder() -> some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(
                LinearGradient(colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 0.5
            )
    }
}
