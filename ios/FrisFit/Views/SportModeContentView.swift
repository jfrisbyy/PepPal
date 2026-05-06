import SwiftUI

struct SportModeContentView: View {
    let mode: TrainMode
    @Bindable var viewModel: TrainViewModel
    let onLogSession: () -> Void

    private var sport: Sport? { mode.type.sport }
    private var sessions: [SportSession] {
        guard let sport else { return viewModel.sportSessions }
        return viewModel.sessionsForSport(sport)
    }
    private var recentSessions: [SportSession] {
        guard let sport else { return Array(viewModel.sportSessions.prefix(5)) }
        return viewModel.recentSessionsForSport(sport)
    }
    private var accentColor: Color { mode.type.color }

    var body: some View {
        VStack(spacing: 20) {
            modeHeader

            ForEach(mode.cards) { card in
                cardView(for: card)
            }

            logSessionButton
        }
    }

    // MARK: - Header

    private var modeHeader: some View {
        let weekSessions = sport.map { viewModel.sportThisWeek($0).count } ?? 0
        let totalTime = sport.map { viewModel.sportTotalTime($0) } ?? viewModel.sportSessions.reduce(0) { $0 + $1.durationMinutes }
        let avgIntensity = sport.map { viewModel.sportAvgIntensity($0) } ?? 0

        return EditorialSportHeader(
            kicker: mode.name,
            title: "In Practice",
            subtitle: "\(weekSessions) session\(weekSessions == 1 ? "" : "s") this week  ·  \(sessions.count) logged",
            accent: accentColor,
            stats: [
                EditorialStat("\(sessions.count)", "Total"),
                EditorialStat(totalTime >= 60 ? "\(totalTime / 60)h" : "\(totalTime)m", "Time"),
                EditorialStat(String(format: "%.1f", avgIntensity), "RPE")
            ]
        )
    }

    // MARK: - Card Router

    @ViewBuilder
    private func cardView(for card: TrainCardType) -> some View {
        switch card {
        case .sportSessions: sessionsOverviewCard
        case .sportStats: statsCard
        case .weeklyDistance: weeklyDistanceCard
        case .paceChart: paceCard
        case .gameLog: gameLogCard
        case .shootingStats: shootingStatsCard
        case .lapTracker: lapTrackerCard
        case .goals: goalsCard
        case .sportHistory: sportHistoryCard
        default: EmptyView()
        }
    }

    // MARK: - Sessions Overview

    private var sessionsOverviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Overview")
                Spacer()
            }

            let totalTime = sport.map { viewModel.sportTotalTime($0) } ?? viewModel.sportSessions.reduce(0) { $0 + $1.durationMinutes }
            let avgIntensity = sport.map { viewModel.sportAvgIntensity($0) } ?? 0

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                overviewStat(value: "\(sessions.count)", label: "Sessions", icon: "list.bullet")
                overviewStat(value: totalTime >= 60 ? "\(totalTime / 60)h" : "\(totalTime)m", label: "Total Time", icon: "clock.fill")
                overviewStat(value: String(format: "%.1f", avgIntensity), label: "Avg RPE", icon: "flame.fill")
            }


        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [accentColor.opacity(0.12), PepTheme.glassBorderBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }

    private func overviewStat(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(accentColor.opacity(0.7))
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(PepTheme.elevated.opacity(0.5))
        .clipShape(.rect(cornerRadius: 10))
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.xyaxis.line")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Sport Stats")
                Spacer()
            }

            if let sport, !sessions.isEmpty {
                sportSpecificStats(sport: sport)
            } else {
                noDataPlaceholder("Log sessions to see stats")
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    @ViewBuilder
    private func sportSpecificStats(sport: Sport) -> some View {
        switch sport {
        case .basketball:
            basketballStatsContent
        case .running:
            runningStatsContent
        case .swimming:
            swimmingStatsContent
        case .cycling:
            cyclingStatsContent
        case .soccer:
            soccerStatsContent
        case .tennis:
            tennisStatsContent
        case .volleyball:
            volleyballStatsContent
        default:
            generalStatsContent
        }
    }

    private var volleyballStatsContent: some View {
        let volleyballSessions = sessions.compactMap { session -> VolleyballSessionStats? in
            if case .volleyball(let stats) = session.specificStats { return stats }
            return nil
        }
        let totalKills = volleyballSessions.reduce(0) { $0 + $1.kills }
        let totalAces = volleyballSessions.reduce(0) { $0 + $1.aces }
        let totalBlocks = volleyballSessions.reduce(0) { $0 + $1.blocks }

        return HStack(spacing: 10) {
            statBubble(value: "\(totalKills)", label: "Kills", color: accentColor)
            statBubble(value: "\(totalAces)", label: "Aces", color: .green)
            statBubble(value: "\(totalBlocks)", label: "Blocks", color: PepTheme.violet)
        }
    }

    private var basketballStatsContent: some View {
        let basketballSessions = sessions.compactMap { session -> BasketballStats? in
            if case .basketball(let stats) = session.specificStats { return stats }
            return nil
        }
        let avgPts = basketballSessions.isEmpty ? 0 : basketballSessions.reduce(0) { $0 + $1.points } / basketballSessions.count
        let avgAst = basketballSessions.isEmpty ? 0 : basketballSessions.reduce(0) { $0 + $1.assists } / basketballSessions.count
        let avgReb = basketballSessions.isEmpty ? 0 : basketballSessions.reduce(0) { $0 + $1.rebounds } / basketballSessions.count

        return HStack(spacing: 10) {
            statBubble(value: "\(avgPts)", label: "Avg PTS", color: accentColor)
            statBubble(value: "\(avgAst)", label: "Avg AST", color: .green)
            statBubble(value: "\(avgReb)", label: "Avg REB", color: PepTheme.violet)
        }
    }

    private var runningStatsContent: some View {
        let runningSessions = sessions.compactMap { session -> RunningStats? in
            if case .running(let stats) = session.specificStats { return stats }
            return nil
        }
        let totalDist = runningSessions.reduce(0.0) { $0 + $1.distanceMiles }
        let avgPace = runningSessions.isEmpty ? 0 : runningSessions.reduce(0.0) { $0 + $1.paceMinutesPerMile } / Double(runningSessions.count)

        return HStack(spacing: 10) {
            statBubble(value: String(format: "%.1f", totalDist), label: "Total Mi", color: accentColor)
            statBubble(value: String(format: "%.1f", avgPace), label: "Avg Pace", color: .green)
            statBubble(value: "\(runningSessions.count)", label: "Runs", color: PepTheme.violet)
        }
    }

    private var swimmingStatsContent: some View {
        let swimmingSessions = sessions.compactMap { session -> SwimmingStats? in
            if case .swimming(let stats) = session.specificStats { return stats }
            return nil
        }
        let totalLaps = swimmingSessions.reduce(0) { $0 + $1.laps }
        let avgLaps = swimmingSessions.isEmpty ? 0 : totalLaps / swimmingSessions.count

        return HStack(spacing: 10) {
            statBubble(value: "\(totalLaps)", label: "Total Laps", color: accentColor)
            statBubble(value: "\(avgLaps)", label: "Avg/Session", color: .green)
            statBubble(value: "\(swimmingSessions.count)", label: "Swims", color: PepTheme.violet)
        }
    }

    private var soccerStatsContent: some View {
        let soccerSessions = sessions.compactMap { session -> SoccerSessionStats? in
            if case .soccer(let stats) = session.specificStats { return stats }
            return nil
        }
        let totalGoals = soccerSessions.reduce(0) { $0 + $1.goals }
        let totalAssists = soccerSessions.reduce(0) { $0 + $1.assists }
        let avgDist = soccerSessions.isEmpty ? 0 : soccerSessions.reduce(0.0) { $0 + $1.distanceKm } / Double(soccerSessions.count)

        return HStack(spacing: 10) {
            statBubble(value: "\(totalGoals)", label: "Goals", color: accentColor)
            statBubble(value: "\(totalAssists)", label: "Assists", color: .blue)
            statBubble(value: String(format: "%.1f km", avgDist), label: "Avg Dist", color: .orange)
        }
    }

    private var tennisStatsContent: some View {
        let tennisSessions = sessions.compactMap { session -> TennisSessionStats? in
            if case .tennis(let stats) = session.specificStats { return stats }
            return nil
        }
        let totalAces = tennisSessions.reduce(0) { $0 + $1.aces }
        let totalWinners = tennisSessions.reduce(0) { $0 + $1.winners }
        let avgServe = tennisSessions.filter({ $0.firstServePercentage > 0 }).isEmpty ? 0 : tennisSessions.filter({ $0.firstServePercentage > 0 }).reduce(0.0) { $0 + $1.firstServePercentage } / Double(tennisSessions.filter({ $0.firstServePercentage > 0 }).count)

        return HStack(spacing: 10) {
            statBubble(value: "\(totalAces)", label: "Aces", color: accentColor)
            statBubble(value: "\(totalWinners)", label: "Winners", color: .green)
            statBubble(value: String(format: "%.0f%%", avgServe), label: "1st Srv%", color: .blue)
        }
    }

    private var generalStatsContent: some View {
        let avgDur = sessions.isEmpty ? 0 : sessions.reduce(0) { $0 + $1.durationMinutes } / sessions.count
        let avgInt = sessions.isEmpty ? 0.0 : Double(sessions.reduce(0) { $0 + $1.intensity }) / Double(sessions.count)
        let games = sessions.filter { $0.sessionType == .game }.count

        return HStack(spacing: 10) {
            statBubble(value: "\(avgDur)m", label: "Avg Time", color: accentColor)
            statBubble(value: String(format: "%.1f", avgInt), label: "Avg RPE", color: .orange)
            statBubble(value: "\(games)", label: "Games", color: .green)
        }
    }

    private func statBubble(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 12))
    }

    // MARK: - Weekly Distance

    private var weeklyDistanceCard: some View {
        let weekDays = (0..<7).map { offset in
            Calendar.current.date(byAdding: .day, value: -(6 - offset), to: Date())!
        }
        let runningSessions = sessions.compactMap { session -> (Date, Double)? in
            if case .running(let stats) = session.specificStats {
                return (session.date, stats.distanceMiles)
            }
            return nil
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "map.fill")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Weekly Distance")
                Spacer()
            }

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(0..<7, id: \.self) { dayIndex in
                    let dayDate = weekDays[dayIndex]
                    let distance = runningSessions
                        .filter { Calendar.current.isDate($0.0, inSameDayAs: dayDate) }
                        .reduce(0.0) { $0 + $1.1 }
                    let maxDist = max(runningSessions.map(\.1).max() ?? 1, 1)

                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(distance > 0 ? accentColor : PepTheme.elevated)
                            .frame(height: max(CGFloat(distance / maxDist) * 60, 4))

                        Text(dayLabel(dayDate))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 80)
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    // MARK: - Pace Card

    private var paceCard: some View {
        let paces = sessions.compactMap { session -> (Date, Double)? in
            if case .running(let stats) = session.specificStats, stats.paceMinutesPerMile > 0 {
                return (session.date, stats.paceMinutesPerMile)
            }
            return nil
        }.sorted { $0.0 < $1.0 }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "speedometer")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Pace Tracking")
                Spacer()
            }

            if paces.isEmpty {
                noDataPlaceholder("Log runs to track pace")
            } else {
                HStack(spacing: 10) {
                    let best = paces.min(by: { $0.1 < $1.1 })?.1 ?? 0
                    let avg = paces.reduce(0.0) { $0 + $1.1 } / Double(paces.count)

                    statBubble(value: String(format: "%.1f", best), label: "Best Pace", color: .green)
                    statBubble(value: String(format: "%.1f", avg), label: "Avg Pace", color: accentColor)
                    statBubble(value: "\(paces.count)", label: "Runs", color: PepTheme.violet)
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    // MARK: - Game Log

    private var gameLogCard: some View {
        let games = sessions.filter { $0.sessionType == .game }.sorted { $0.date > $1.date }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sportscourt.fill")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Game Log")
                Spacer()
                Text("\(games.count) game\(games.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }

            if games.isEmpty {
                noDataPlaceholder("No games logged yet")
            } else {
                ForEach(games.prefix(4)) { game in
                    gameRow(game)
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    private func gameRow(_ session: SportSession) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(dayLabel(session.date).uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary)
                Text("\(Calendar.current.component(.day, from: session.date))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)

                HStack(spacing: 8) {
                    Label("\(session.durationMinutes)m", systemImage: "clock")
                    Label("\(session.intensity)/10", systemImage: "flame")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            specificStatsLabel(session)
        }
        .padding(.vertical, 4)
    }

    private var cyclingStatsContent: some View {
        let cyclingSessions = sessions.compactMap { session -> CyclingStats? in
            if case .cycling(let stats) = session.specificStats { return stats }
            return nil
        }
        let totalDist = cyclingSessions.reduce(0.0) { $0 + $1.distanceMiles }
        let avgSpeed = cyclingSessions.isEmpty ? 0 : cyclingSessions.reduce(0.0) { $0 + $1.averageSpeed } / Double(cyclingSessions.count)
        let totalElev = cyclingSessions.reduce(0.0) { $0 + $1.elevationGain }

        return VStack(spacing: 8) {
            HStack(spacing: 10) {
                statBubble(value: String(format: "%.1f", totalDist), label: "Total Mi", color: accentColor)
                statBubble(value: String(format: "%.1f", avgSpeed), label: "Avg MPH", color: .green)
                statBubble(value: String(format: "%.0f", totalElev), label: "Elev ft", color: .orange)
            }
        }
    }

    @ViewBuilder
    private func specificStatsLabel(_ session: SportSession) -> some View {
        switch session.specificStats {
        case .basketball(let stats):
            Text("\(stats.points) pts")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(accentColor)
        case .running(let stats):
            Text(String(format: "%.1f mi", stats.distanceMiles))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(accentColor)
        case .swimming(let stats):
            Text("\(stats.laps) laps")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(accentColor)
        case .cycling(let stats):
            Text(String(format: "%.1f mi", stats.distanceMiles))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(accentColor)
        case .soccer(let stats):
            HStack(spacing: 4) {
                if stats.goals > 0 {
                    Text("\(stats.goals)G")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(accentColor)
                }
                if stats.assists > 0 {
                    Text("\(stats.assists)A")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.blue)
                }
                if stats.goals == 0 && stats.assists == 0 {
                    Text("\(session.durationMinutes)m")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        case .tennis(let stats):
            HStack(spacing: 4) {
                if stats.aces > 0 {
                    Text("\(stats.aces) aces")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(accentColor)
                } else {
                    Text("\(session.durationMinutes)m")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        case .volleyball(let stats):
            HStack(spacing: 4) {
                if stats.kills > 0 {
                    Text("\(stats.kills)K")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(accentColor)
                }
                if stats.aces > 0 {
                    Text("\(stats.aces) ACE")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                }
                if stats.kills == 0 && stats.aces == 0 {
                    Text("\(session.durationMinutes)m")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        case .none:
            Text("\(session.durationMinutes)m")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(PepTheme.textSecondary)
        }
    }

    // MARK: - Shooting Stats

    private var shootingStatsCard: some View {
        let basketballSessions = sessions.compactMap { session -> BasketballStats? in
            if case .basketball(let stats) = session.specificStats { return stats }
            return nil
        }
        let totalPts = basketballSessions.reduce(0) { $0 + $1.points }
        let totalAst = basketballSessions.reduce(0) { $0 + $1.assists }
        let totalReb = basketballSessions.reduce(0) { $0 + $1.rebounds }
        let highPts = basketballSessions.map(\.points).max() ?? 0

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "scope")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Career Stats")
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                careerStatCell(value: "\(totalPts)", label: "Total Points", color: accentColor)
                careerStatCell(value: "\(highPts)", label: "Season High", color: PepTheme.amber)
                careerStatCell(value: "\(totalAst)", label: "Total Assists", color: .green)
                careerStatCell(value: "\(totalReb)", label: "Total Rebounds", color: PepTheme.violet)
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    private func careerStatCell(value: String, label: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Spacer()
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(12)
        .background(PepTheme.elevated.opacity(0.5))
        .clipShape(.rect(cornerRadius: 10))
    }

    // MARK: - Lap Tracker

    private var lapTrackerCard: some View {
        let swimmingSessions = sessions.compactMap { session -> (SwimmingStats, Date)? in
            if case .swimming(let stats) = session.specificStats { return (stats, session.date) }
            return nil
        }.sorted { $0.1 > $1.1 }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "stopwatch.fill")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Lap Tracker")
                Spacer()
            }

            if swimmingSessions.isEmpty {
                noDataPlaceholder("Log swims to track laps")
            } else {
                let totalLaps = swimmingSessions.reduce(0) { $0 + $1.0.laps }
                let bestLaps = swimmingSessions.map(\.0.laps).max() ?? 0

                HStack(spacing: 10) {
                    statBubble(value: "\(totalLaps)", label: "Total Laps", color: accentColor)
                    statBubble(value: "\(bestLaps)", label: "Best Session", color: .green)
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    // MARK: - Goals

    private var goalsCard: some View {
        let weekSessions = sport.map { viewModel.sportThisWeek($0).count } ?? 0
        let weeklyGoal = 3

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flag.checkered")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Goals")
                Spacer()
            }

            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(PepTheme.elevated, lineWidth: 6)
                        .frame(width: 56, height: 56)
                    Circle()
                        .trim(from: 0, to: min(CGFloat(weekSessions) / CGFloat(weeklyGoal), 1.0))
                        .stroke(accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))
                    Text("\(weekSessions)/\(weeklyGoal)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(accentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Weekly Sessions")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PepTheme.textPrimary)

                    if weekSessions >= weeklyGoal {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11))
                            Text("Goal reached!")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.green)
                    } else {
                        Text("\(weeklyGoal - weekSessions) more to hit your goal")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }

                Spacer()
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    // MARK: - Sport History

    private var sportHistoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Recent Sessions")
                Spacer()
            }

            if recentSessions.isEmpty {
                noDataPlaceholder("No sessions logged yet")
            } else {
                ForEach(recentSessions) { session in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(session.sport.color.opacity(0.12))
                                .frame(width: 36, height: 36)
                            Image(systemName: session.sport.icon)
                                .font(.system(size: 14))
                                .foregroundStyle(session.sport.color)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(session.displayName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(PepTheme.textPrimary)
                                Text(session.sessionType.rawValue)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(session.sport.color)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(session.sport.color.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            Text(session.date.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                                .font(.system(size: 10))
                                .foregroundStyle(PepTheme.textSecondary)
                        }

                        Spacer()

                        Text("\(session.durationMinutes)m")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    // MARK: - Log Button

    private var logSessionButton: some View {
        EditorialPrimaryButton("Log \(mode.name) Session", icon: "plus", accent: accentColor) {
            onLogSession()
        }
    }

    // MARK: - Helpers

    private func noDataPlaceholder(_ message: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .font(.title2)
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(.vertical, 16)
            Spacer()
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}
