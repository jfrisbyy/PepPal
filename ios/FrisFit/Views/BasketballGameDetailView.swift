import SwiftUI

struct BasketballGameDetailView: View {
    let game: BasketballGame
    private let accentColor = Color(red: 1.0, green: 0.55, blue: 0.1)

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                gameHeader
                if game.sessionType.isGame {
                    statLineCard
                    shootingSplitsCard
                }
                if !game.shotChart.isEmpty {
                    shotChartCard
                }
                selfAssessmentCard
                if !game.notes.isEmpty {
                    notesCard
                }
                fpCard
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(FrisTheme.background.ignoresSafeArea())
        .navigationTitle("Game Detail")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var gameHeader: some View {
        GlassCard {
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill((game.result?.color ?? accentColor).opacity(0.15))
                            .frame(width: 56, height: 56)
                        if let result = game.result {
                            Text(result.rawValue)
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundStyle(result.color)
                        } else {
                            Image(systemName: game.sessionType.icon)
                                .font(.system(size: 24))
                                .foregroundStyle(accentColor)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(game.sessionType.rawValue)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(FrisTheme.textPrimary)
                        Text(game.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                            .font(.caption)
                            .foregroundStyle(FrisTheme.textSecondary)
                    }

                    Spacer()

                    if let ts = game.teamScore, let os = game.opponentScore {
                        VStack(spacing: 2) {
                            Text("\(ts) — \(os)")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(game.result?.color ?? FrisTheme.textPrimary)
                            Text("Final Score")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(FrisTheme.textSecondary)
                        }
                    }
                }

                if game.sessionType.isGame {
                    HStack(spacing: 0) {
                        broadcastStat(value: "\(game.stats.points)", label: "PTS")
                        Divider().frame(height: 30).overlay(FrisTheme.elevated)
                        broadcastStat(value: "\(game.stats.totalRebounds)", label: "REB")
                        Divider().frame(height: 30).overlay(FrisTheme.elevated)
                        broadcastStat(value: "\(game.stats.assists)", label: "AST")
                        Divider().frame(height: 30).overlay(FrisTheme.elevated)
                        broadcastStat(value: "\(game.stats.steals)", label: "STL")
                        Divider().frame(height: 30).overlay(FrisTheme.elevated)
                        broadcastStat(value: "\(game.stats.blocks)", label: "BLK")
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

    // MARK: - Stat Line

    private var statLineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Full Stat Line")
                Spacer()
                if game.stats.minutesPlayed > 0 {
                    Text("\(game.stats.minutesPlayed) min")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(FrisTheme.textSecondary)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 10) {
                detailStatCell(value: "\(game.stats.points)", label: "PTS", color: accentColor)
                detailStatCell(value: "\(game.stats.offensiveRebounds)", label: "OREB", color: .green)
                detailStatCell(value: "\(game.stats.defensiveRebounds)", label: "DREB", color: .green)
                detailStatCell(value: "\(game.stats.assists)", label: "AST", color: .blue)
                detailStatCell(value: "\(game.stats.steals)", label: "STL", color: FrisTheme.amber)
                detailStatCell(value: "\(game.stats.blocks)", label: "BLK", color: .red)
                detailStatCell(value: "\(game.stats.turnovers)", label: "TO", color: FrisTheme.textSecondary)
                detailStatCell(value: String(format: "%.1f", game.stats.gameScore), label: "GmSc", color: FrisTheme.violet)
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
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

    // MARK: - Shooting Splits

    private var shootingSplitsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "scope")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Shooting Splits")
                Spacer()
            }

            VStack(spacing: 10) {
                splitRow(label: "FG", made: game.stats.fieldGoalsMade, attempted: game.stats.fieldGoalsAttempted, pct: game.stats.fieldGoalPercentage, color: accentColor)
                splitRow(label: "3PT", made: game.stats.threePointersMade, attempted: game.stats.threePointersAttempted, pct: game.stats.threePointPercentage, color: .green)
                splitRow(label: "FT", made: game.stats.freeThrowsMade, attempted: game.stats.freeThrowsAttempted, pct: game.stats.freeThrowPercentage, color: FrisTheme.amber)
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private func splitRow(label: String, made: Int, attempted: Int, pct: Double, color: Color) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(FrisTheme.textPrimary)
                .frame(width: 30, alignment: .leading)

            Text("\(made)/\(attempted)")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(FrisTheme.textSecondary)
                .frame(width: 50)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(FrisTheme.elevated)
                        .frame(height: 10)
                    Capsule()
                        .fill(color)
                        .frame(width: max(geo.size.width * (pct / 100), 4), height: 10)
                }
            }
            .frame(height: 10)

            Text(String(format: "%.1f%%", pct))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .frame(width: 50, alignment: .trailing)
        }
    }

    // MARK: - Shot Chart

    private var shotChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Shot Chart")
                Spacer()
            }

            let made = game.shotChart.filter(\.made).count
            let total = game.shotChart.count
            let pct = total > 0 ? Double(made) / Double(total) * 100 : 0

            HStack(spacing: 16) {
                Text("\(made)/\(total) shots made")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FrisTheme.textSecondary)
                Spacer()
                Text(String(format: "%.0f%% overall", pct))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(pct >= 50 ? .green : pct >= 35 ? FrisTheme.amber : .red)
            }

            GeometryReader { geo in
                let w = geo.size.width
                let h: CGFloat = 180

                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(FrisTheme.elevated.opacity(0.6), lineWidth: 1)
                        .frame(width: w, height: h)

                    RoundedRectangle(cornerRadius: 2)
                        .stroke(FrisTheme.elevated.opacity(0.5), lineWidth: 1)
                        .frame(width: w * 0.32, height: h * 0.35)
                        .offset(y: h * 0.325)

                    ForEach(game.shotChart) { entry in
                        let pos = entry.zone.position
                        Circle()
                            .fill(entry.made ? .green.opacity(0.7) : .red.opacity(0.6))
                            .frame(width: 7, height: 7)
                            .position(
                                x: w * pos.x + CGFloat.random(in: -10...10),
                                y: h * pos.y + CGFloat.random(in: -10...10)
                            )
                    }
                }
                .frame(height: h)
            }
            .frame(height: 180)
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    // MARK: - Self Assessment

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
                    Text("\(game.confidenceRating)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(FrisTheme.violet)
                    Text("Confidence")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(FrisTheme.textSecondary)
                    ratingDots(value: game.confidenceRating, color: FrisTheme.violet)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(FrisTheme.elevated)
                    .frame(width: 1, height: 50)

                VStack(spacing: 6) {
                    Text("\(game.performanceRating)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(FrisTheme.amber)
                    Text("Performance")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(FrisTheme.textSecondary)
                    ratingDots(value: game.performanceRating, color: FrisTheme.amber)
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

    // MARK: - Notes

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundStyle(FrisTheme.textSecondary)
                HeadlineText(text: "Notes")
                Spacer()
            }
            Text(game.notes)
                .font(.subheadline)
                .foregroundStyle(FrisTheme.textSecondary)
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    // MARK: - FP

    private var fpCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("FP EARNED")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(FrisTheme.textSecondary)
                    .tracking(1)
                Text("\(game.durationMinutes) min · \(game.sessionType.rawValue)")
                    .font(.system(size: 11))
                    .foregroundStyle(FrisTheme.textSecondary.opacity(0.7))
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(FrisTheme.cyan)
                Text("\(game.fpEarned)")
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

    private func cardBorder() -> some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(
                LinearGradient(colors: [FrisTheme.glassBorderTop, FrisTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 0.5
            )
    }
}
