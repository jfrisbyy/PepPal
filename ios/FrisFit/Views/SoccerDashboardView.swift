import SwiftUI

struct SoccerDashboardView: View {
    @Bindable var soccerVM: SoccerViewModel
    let accentColor: Color

    var body: some View {
        VStack(spacing: 16) {
            quickStatsHeader
            sessionTypeSelector
            positionDashboardCard
            recentMatchesList
            formChartCard
            seasonStatsCard
            movementStatsCard
            workoutBuilderButton
            drillLibraryButton
        }
    }

    private var quickStatsHeader: some View {
        GlassCard {
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [accentColor.opacity(0.3), accentColor.opacity(0.05)],
                                    center: .center, startRadius: 0, endRadius: 32
                                )
                            )
                            .frame(width: 56, height: 56)
                        Image(systemName: "soccerball")
                            .font(.system(size: 24))
                            .foregroundStyle(accentColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Soccer")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(FrisTheme.textPrimary)
                        Text("\(soccerVM.thisWeekSessions) session\(soccerVM.thisWeekSessions == 1 ? "" : "s") this week · \(soccerVM.totalWins)W-\(soccerVM.totalDraws)D-\(soccerVM.totalLosses)L")
                            .font(.caption)
                            .foregroundStyle(FrisTheme.textSecondary)
                    }

                    Spacer()

                    if soccerVM.totalGamesPlayed > 0 {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "%.0f%%", soccerVM.winPercentage))
                                .font(.system(.title2, design: .rounded, weight: .bold))
                                .foregroundStyle(soccerVM.winPercentage >= 50 ? .green : .orange)
                            Text("Win %")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(FrisTheme.textSecondary)
                        }
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    quickStat(value: String(format: "%.1f", soccerVM.averageGoals), label: "G/G", icon: "soccerball")
                    quickStat(value: String(format: "%.1f", soccerVM.averageAssists), label: "A/G", icon: "arrow.turn.up.right")
                    quickStat(value: "\(soccerVM.totalGoalContributions)", label: "G+A", icon: "flame.fill")
                    quickStat(value: String(format: "%.1f", soccerVM.averageRating), label: "Avg Rating", icon: "star.fill")
                }
            }
        }
    }

    private func quickStat(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(accentColor.opacity(0.7))
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(FrisTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(FrisTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(FrisTheme.elevated.opacity(0.5))
        .clipShape(.rect(cornerRadius: 10))
    }

    private var sessionTypeSelector: some View {
        VStack(spacing: 14) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(SoccerSessionType.allCases) { type in
                        Button {
                            soccerVM.selectedSessionType = type
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 14))
                                Text(type.rawValue)
                                    .font(.system(size: 8, weight: .semibold))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(soccerVM.selectedSessionType == type ? .black : FrisTheme.textSecondary)
                            .frame(width: 72)
                            .padding(.vertical, 10)
                            .background(soccerVM.selectedSessionType == type ? accentColor : FrisTheme.elevated.opacity(0.5))
                            .clipShape(.rect(cornerRadius: 10))
                        }
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)

            Button {
                soccerVM.showGameLog = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                    Text("Log \(soccerVM.selectedSessionType.isGame ? "Match" : "Session")")
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [accentColor, accentColor.opacity(0.8)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(.rect(cornerRadius: 14))
            }
            .buttonStyle(.scalePrimary)
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [accentColor.opacity(0.15), FrisTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    private var positionDashboardCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: soccerVM.primaryPosition.icon)
                    .foregroundStyle(accentColor)
                HeadlineText(text: "\(soccerVM.primaryPosition.rawValue) Dashboard")
                Spacer()
                Button {
                    soccerVM.showSettings = true
                } label: {
                    HStack(spacing: 4) {
                        Text(soccerVM.primaryPosition.shortName)
                            .font(.system(size: 10, weight: .bold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accentColor.opacity(0.12))
                    .clipShape(Capsule())
                }
            }

            if soccerVM.totalGamesPlayed == 0 {
                noDataPlaceholder("Log matches to see position stats")
            } else {
                HStack(spacing: 10) {
                    ForEach(soccerVM.positionDashboardStats, id: \.label) { stat in
                        statBubble(value: stat.value, label: stat.label, color: stat.color)
                    }
                }
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private func statBubble(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(FrisTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var recentMatchesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Recent Matches")
                Spacer()
                Text("\(soccerVM.matches.count) total")
                    .font(.caption)
                    .foregroundStyle(FrisTheme.textSecondary)
            }

            if soccerVM.matches.isEmpty {
                noDataPlaceholder("No matches logged yet")
            } else {
                ForEach(soccerVM.matches.prefix(5)) { match in
                    Button {
                        soccerVM.selectedMatch = match
                        soccerVM.showMatchDetail = true
                    } label: {
                        recentMatchRow(match)
                    }
                }
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private func recentMatchRow(_ match: SoccerMatch) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((match.result?.color ?? accentColor).opacity(0.12))
                    .frame(width: 40, height: 40)
                if let result = match.result {
                    Text(result.rawValue)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(result.color)
                } else {
                    Image(systemName: match.sessionType.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(accentColor)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(match.sessionType.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FrisTheme.textPrimary)
                    if let ts = match.teamScore, let os = match.opponentScore {
                        Text("\(ts)-\(os)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(match.result?.color ?? FrisTheme.textSecondary)
                    }
                    Text(match.position.shortName)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(accentColor.opacity(0.12))
                        .clipShape(Capsule())
                }
                Text(match.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(.system(size: 10))
                    .foregroundStyle(FrisTheme.textSecondary)
            }

            Spacer()

            if match.sessionType.isGame {
                VStack(alignment: .trailing, spacing: 3) {
                    HStack(spacing: 4) {
                        if match.stats.goals > 0 {
                            Text("\(match.stats.goals)G")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(accentColor)
                        }
                        if match.stats.assists > 0 {
                            Text("\(match.stats.assists)A")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.blue)
                        }
                        if match.stats.goals == 0 && match.stats.assists == 0 {
                            Text("\(match.performanceRating)/10")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(FrisTheme.textSecondary)
                        }
                    }
                }
            } else {
                Text("\(match.fpEarned) FP")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(FrisTheme.amber)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(FrisTheme.textSecondary.opacity(0.5))
        }
        .padding(.vertical, 4)
    }

    private var formChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Form Chart")
                Spacer()
            }

            let data = soccerVM.formData
            if data.count < 2 {
                noDataPlaceholder("Need 2+ matches to show form")
            } else {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(data.enumerated()), id: \.offset) { _, entry in
                        VStack(spacing: 4) {
                            Text("\(entry.rating)")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(ratingColor(entry.rating))

                            RoundedRectangle(cornerRadius: 4)
                                .fill(ratingColor(entry.rating))
                                .frame(height: max(CGFloat(entry.rating) / 10.0 * 60, 4))

                            Text(dayLabel(entry.date))
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(FrisTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 90)

                let avgRating = data.reduce(0.0) { $0 + Double($1.rating) } / Double(data.count)
                HStack {
                    Text("Last \(data.count) matches")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(FrisTheme.textSecondary)
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                        Text(String(format: "%.1f avg", avgRating))
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(ratingColor(Int(avgRating)))
                }
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private var seasonStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(FrisTheme.amber)
                HeadlineText(text: "Season Stats")
                Spacer()
                Text("\(soccerVM.totalGamesPlayed) matches")
                    .font(.caption)
                    .foregroundStyle(FrisTheme.textSecondary)
            }

            if soccerVM.totalGamesPlayed == 0 {
                noDataPlaceholder("Play matches to see season stats")
            } else {
                let gm = soccerVM.gameMatches
                let avgKeyPasses = gm.isEmpty ? 0 : Double(gm.reduce(0) { $0 + $1.stats.keyPasses }) / Double(gm.count)
                let avgTackles = gm.isEmpty ? 0 : Double(gm.reduce(0) { $0 + $1.stats.tacklesWon }) / Double(gm.count)
                let avgInterceptions = gm.isEmpty ? 0 : Double(gm.reduce(0) { $0 + $1.stats.interceptions }) / Double(gm.count)
                let totalYellows = gm.reduce(0) { $0 + $1.stats.yellowCards }
                let totalReds = gm.reduce(0) { $0 + $1.stats.redCards }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    avgStatCell(value: "\(soccerVM.totalGoals)", label: "Goals", color: accentColor)
                    avgStatCell(value: "\(soccerVM.totalAssists)", label: "Assists", color: .blue)
                    avgStatCell(value: String(format: "%.1f", avgKeyPasses), label: "Key Pass/G", color: .cyan)
                    avgStatCell(value: String(format: "%.1f", avgTackles), label: "Tackle/G", color: .red)
                    avgStatCell(value: String(format: "%.1f", avgInterceptions), label: "INT/G", color: .orange)
                    avgStatCell(value: "\(totalYellows)Y \(totalReds)R", label: "Cards", color: FrisTheme.amber)
                }
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private func avgStatCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(FrisTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 10))
    }

    private var movementStatsCard: some View {
        let matchesWithDist = soccerVM.matches.filter { $0.distanceKm > 0 }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.run")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Movement")
                Spacer()
            }

            if matchesWithDist.isEmpty {
                noDataPlaceholder("Log matches with distance data")
            } else {
                let totalDist = matchesWithDist.reduce(0.0) { $0 + $1.distanceKm }
                let avgSprints = matchesWithDist.reduce(0) { $0 + $1.sprintCount } / matchesWithDist.count
                let topSpeed = matchesWithDist.map(\.topSpeedKmh).max() ?? 0

                HStack(spacing: 10) {
                    statBubble(value: String(format: "%.1f", soccerVM.averageDistance), label: "Avg Dist (km)", color: accentColor)
                    statBubble(value: "\(avgSprints)", label: "Avg Sprints", color: .orange)
                    statBubble(value: String(format: "%.1f", topSpeed), label: "Top Speed", color: .red)
                }

                HStack(spacing: 6) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(accentColor.opacity(0.7))
                    Text(String(format: "%.1f km total distance covered", totalDist))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(FrisTheme.textSecondary)
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private var drillLibraryButton: some View {
        Button {
            soccerVM.showDrillLibrary = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "figure.soccer")
                    .font(.title3)
                    .foregroundStyle(accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Drill Library")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(FrisTheme.textPrimary)
                    Text("\(SoccerDrillLibrary.all.count) drills across \(SoccerDrillCategory.allCases.count) categories")
                        .font(.caption)
                        .foregroundStyle(FrisTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FrisTheme.textSecondary)
            }
            .padding(16)
            .background(FrisTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 16))
            .overlay(cardBorder())
        }
        .buttonStyle(.scale)
    }

    private func ratingColor(_ rating: Int) -> Color {
        switch rating {
        case 8...10: .green
        case 6...7: accentColor
        case 4...5: .orange
        default: .red
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private var workoutBuilderButton: some View {
        Button {
            soccerVM.showWorkoutBuilder = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "plus.rectangle.on.folder")
                        .font(.system(size: 16))
                        .foregroundStyle(accentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Create Training Session")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FrisTheme.textPrimary)
                    Text("Build custom drill circuits")
                        .font(.system(size: 11))
                        .foregroundStyle(FrisTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FrisTheme.textSecondary)
            }
            .padding(16)
            .background(FrisTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 16))
            .overlay(cardBorder())
        }
        .buttonStyle(.scale)
    }

    private func noDataPlaceholder(_ message: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .font(.title2)
                    .foregroundStyle(FrisTheme.textSecondary.opacity(0.5))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(FrisTheme.textSecondary)
            }
            .padding(.vertical, 16)
            Spacer()
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
