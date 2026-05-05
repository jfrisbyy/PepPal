import SwiftUI

struct BasketballDashboardView: View {
    @Bindable var bbVM: BasketballViewModel
    let accentColor: Color

    var body: some View {
        VStack(spacing: 16) {
            quickStatsHeader
            sessionTypeSelector
            SportCoachCard(sport: .basketball, accent: accentColor)
            recentGamesList
            shootingBreakdownCard
            pointsTrendCard
            shotChartPreviewCard
            seasonAveragesCard
            confidenceInsightCard
            practicePlansCard
            workoutBuilderButton
            drillLibraryButton
        }
    }

    // MARK: - Quick Stats Header

    private var quickStatsHeader: some View {
        PepSportCard(accent: accentColor) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("BASKETBALL")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.0)
                        .foregroundStyle(accentColor.opacity(0.9))
                    Spacer()
                    if bbVM.totalGamesPlayed > 0 {
                        Text("WIN \(String(format: "%.0f%%", bbVM.winPercentage))")
                            .font(.system(size: 10, weight: .medium))
                            .tracking(1.4)
                            .foregroundStyle(PepTheme.textTertiary)
                    }
                }

                Text("\(bbVM.thisWeekSessions) session\(bbVM.thisWeekSessions == 1 ? "" : "s") this week  ·  \(bbVM.totalWins)W–\(bbVM.totalLosses)L")
                    .font(.system(size: 12, design: .serif))
                    .foregroundStyle(PepTheme.textSecondary)

                LinearGradient(
                    colors: [PepTheme.textPrimary.opacity(0.16), PepTheme.textPrimary.opacity(0)],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 0.5)

                HStack(spacing: 0) {
                    quickStat(value: String(format: "%.1f", bbVM.averagePoints), label: "PPG")
                    quickStatDivider
                    quickStat(value: String(format: "%.1f", bbVM.averageRebounds), label: "RPG")
                    quickStatDivider
                    quickStat(value: String(format: "%.1f", bbVM.averageAssists), label: "APG")
                    quickStatDivider
                    quickStat(value: "\(bbVM.seasonHighPoints)", label: "HIGH")
                }
            }
        }
    }

    private var quickStatDivider: some View {
        Rectangle()
            .fill(PepTheme.shimmerHighlight)
            .frame(width: 0.5, height: 28)
    }

    private func quickStat(value: String, label: String) -> some View {
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

    // MARK: - Session Type Selector

    private var sessionTypeSelector: some View {
        VStack(spacing: 14) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach([BasketballSessionType.pickupGame, .fullGame5v5, .fullGame3v3, .soloShooting, .skillsPractice], id: \.id) { type in
                        Button {
                            bbVM.selectedSessionType = type
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 14))
                                Text(type.rawValue)
                                    .font(.system(size: 8, weight: .semibold))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(bbVM.selectedSessionType == type ? .black : PepTheme.textSecondary)
                            .frame(width: 72)
                            .padding(.vertical, 10)
                            .background(bbVM.selectedSessionType == type ? accentColor : PepTheme.elevated.opacity(0.5))
                            .clipShape(.rect(cornerRadius: 10))
                        }
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)

            Button {
                bbVM.showGameLog = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                    Text("Log \(bbVM.selectedSessionType.isGame ? "Game" : "Session")")
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
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [accentColor.opacity(0.15), PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    // MARK: - Recent Games

    private var recentGamesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Recent Games")
                Spacer()
                Text("\(bbVM.games.count) total")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }

            if bbVM.games.isEmpty {
                noDataPlaceholder("No games logged yet")
            } else {
                ForEach(bbVM.games.prefix(5)) { game in
                    Button {
                        bbVM.selectedGame = game
                        bbVM.showGameDetail = true
                    } label: {
                        recentGameRow(game)
                    }
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private func recentGameRow(_ game: BasketballGame) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((game.result?.color ?? accentColor).opacity(0.12))
                    .frame(width: 40, height: 40)
                if let result = game.result {
                    Text(result.rawValue)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(result.color)
                } else {
                    Image(systemName: game.sessionType.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(accentColor)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(game.sessionType.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    if let ts = game.teamScore, let os = game.opponentScore {
                        Text("\(ts)-\(os)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(game.result?.color ?? PepTheme.textSecondary)
                    }
                }
                Text(game.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(.system(size: 10))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            if game.sessionType.isGame {
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(game.stats.points) pts")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(accentColor)
                    Text("\(game.stats.totalRebounds)r · \(game.stats.assists)a")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            } else {
                Text("\(game.durationMinutes)m")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
        }
        .padding(.vertical, 4)
    }

    // MARK: - Shooting Breakdown

    private var shootingBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "scope")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Shooting Splits")
                Spacer()
            }

            if bbVM.totalGamesPlayed == 0 {
                noDataPlaceholder("Log games to see shooting stats")
            } else {
                HStack(spacing: 8) {
                    shootingRing(label: "FG%", value: bbVM.overallFGPercentage, color: accentColor)
                    shootingRing(label: "3PT%", value: bbVM.overall3PTPercentage, color: .green)
                    shootingRing(label: "FT%", value: bbVM.overallFTPercentage, color: PepTheme.amber)
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private func shootingRing(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(PepTheme.elevated, lineWidth: 6)
                    .frame(width: 56, height: 56)
                Circle()
                    .trim(from: 0, to: min(value / 100, 1.0))
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                Text(String(format: "%.0f", value))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Points Trend

    private var pointsTrendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Scoring Trend")
                Spacer()
            }

            let data = bbVM.pointsTrendData
            if data.count < 2 {
                noDataPlaceholder("Need 2+ games to show trend")
            } else {
                let minPts = max((data.map(\.points).min() ?? 0) - 5, 0)
                let maxPts = (data.map(\.points).max() ?? 30) + 5
                let range = Double(max(maxPts - minPts, 1))

                GeometryReader { geo in
                    let width = geo.size.width
                    let height: CGFloat = 100
                    let stepX = width / CGFloat(max(data.count - 1, 1))

                    ZStack(alignment: .topLeading) {
                        Path { path in
                            for (i, point) in data.enumerated() {
                                let x = CGFloat(i) * stepX
                                let y = height - CGFloat(Double(point.points - minPts) / range) * height
                                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                        }
                        .stroke(accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                        Path { path in
                            for (i, point) in data.enumerated() {
                                let x = CGFloat(i) * stepX
                                let y = height - CGFloat(Double(point.points - minPts) / range) * height
                                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                            if let last = data.indices.last {
                                path.addLine(to: CGPoint(x: CGFloat(last) * stepX, y: height))
                                path.addLine(to: CGPoint(x: 0, y: height))
                                path.closeSubpath()
                            }
                        }
                        .fill(
                            LinearGradient(colors: [accentColor.opacity(0.2), accentColor.opacity(0)], startPoint: .top, endPoint: .bottom)
                        )

                        ForEach(Array(data.enumerated()), id: \.offset) { i, point in
                            let x = CGFloat(i) * stepX
                            let y = height - CGFloat(Double(point.points - minPts) / range) * height
                            Circle()
                                .fill(accentColor)
                                .frame(width: 6, height: 6)
                                .position(x: x, y: y)
                        }
                    }
                    .frame(height: height)
                }
                .frame(height: 100)

                HStack {
                    Text("Last \(data.count) games")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                    if let first = data.first, let last = data.last {
                        let diff = last.points - first.points
                        HStack(spacing: 3) {
                            Image(systemName: diff >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 9))
                            Text("\(diff >= 0 ? "+" : "")\(diff) pts")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(diff >= 0 ? .green : .orange)
                    }
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    // MARK: - Shot Chart Preview

    private var shotChartPreviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Shot Chart")
                Spacer()
                Button {
                    bbVM.showShotChart = true
                } label: {
                    Text("Full View")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(accentColor)
                }
            }

            if bbVM.allShotChartEntries.isEmpty {
                noDataPlaceholder("Log shots to see your chart")
            } else {
                miniShotChart
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private var miniShotChart: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h: CGFloat = 180

            ZStack {
                courtShape(width: w, height: h)

                ForEach(ShotZone.allCases) { zone in
                    let stats = bbVM.shotZoneStats(for: zone)
                    if stats.attempted > 0 {
                        let pos = zone.position
                        VStack(spacing: 1) {
                            Text(String(format: "%.0f%%", stats.percentage))
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                            Text("\(stats.made)/\(stats.attempted)")
                                .font(.system(size: 7, weight: .medium))
                        }
                        .foregroundStyle(stats.percentage >= 50 ? .green : stats.percentage >= 35 ? PepTheme.amber : .red)
                        .position(x: w * pos.x, y: h * pos.y)
                    }
                }
            }
            .frame(height: h)
        }
        .frame(height: 180)
    }

    private func courtShape(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .stroke(PepTheme.elevated.opacity(0.6), lineWidth: 1)
                .frame(width: width, height: height)

            RoundedRectangle(cornerRadius: 2)
                .stroke(PepTheme.elevated.opacity(0.5), lineWidth: 1)
                .frame(width: width * 0.32, height: height * 0.35)
                .offset(y: height * 0.325)

            Circle()
                .stroke(PepTheme.elevated.opacity(0.4), lineWidth: 1)
                .frame(width: width * 0.22, height: width * 0.22)
                .offset(y: height * 0.15)

            Path { path in
                let centerX = width / 2
                let radius = width * 0.42
                let startAngle = Angle(degrees: 160)
                let endAngle = Angle(degrees: 20)
                path.addArc(center: CGPoint(x: centerX, y: height), radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            }
            .stroke(PepTheme.elevated.opacity(0.4), lineWidth: 1)
        }
    }

    // MARK: - Season Averages

    private var seasonAveragesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(PepTheme.amber)
                HeadlineText(text: "Season Averages")
                Spacer()
                Text("\(bbVM.totalGamesPlayed) games")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }

            if bbVM.totalGamesPlayed == 0 {
                noDataPlaceholder("Play games to see averages")
            } else {
                let gameOnly = bbVM.games.filter { $0.sessionType.isGame }
                let avgSteals = gameOnly.isEmpty ? 0 : Double(gameOnly.reduce(0) { $0 + $1.stats.steals }) / Double(gameOnly.count)
                let avgBlocks = gameOnly.isEmpty ? 0 : Double(gameOnly.reduce(0) { $0 + $1.stats.blocks }) / Double(gameOnly.count)
                let avgTO = gameOnly.isEmpty ? 0 : Double(gameOnly.reduce(0) { $0 + $1.stats.turnovers }) / Double(gameOnly.count)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    avgStatCell(value: String(format: "%.1f", bbVM.averagePoints), label: "PTS", color: accentColor)
                    avgStatCell(value: String(format: "%.1f", bbVM.averageRebounds), label: "REB", color: .green)
                    avgStatCell(value: String(format: "%.1f", bbVM.averageAssists), label: "AST", color: .blue)
                    avgStatCell(value: String(format: "%.1f", avgSteals), label: "STL", color: PepTheme.amber)
                    avgStatCell(value: String(format: "%.1f", avgBlocks), label: "BLK", color: .red)
                    avgStatCell(value: String(format: "%.1f", avgTO), label: "TO", color: PepTheme.textSecondary)
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private func avgStatCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 10))
    }

    // MARK: - Confidence Insight

    private var confidenceInsightCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile.fill")
                    .foregroundStyle(PepTheme.violet)
                HeadlineText(text: "Mental Game")
                Spacer()
            }

            let data = bbVM.confidenceCorrelation
            if data.count < 3 {
                noDataPlaceholder("Need 3+ games for insights")
            } else {
                let highConf = data.filter { $0.confidence >= 7 }
                let lowConf = data.filter { $0.confidence < 7 }
                let highAvgFG = highConf.isEmpty ? 0 : highConf.reduce(0.0) { $0 + $1.fgPct } / Double(highConf.count)
                let lowAvgFG = lowConf.isEmpty ? 0 : lowConf.reduce(0.0) { $0 + $1.fgPct } / Double(lowConf.count)
                let diff = highAvgFG - lowAvgFG

                HStack(spacing: 16) {
                    VStack(spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.green)
                            Text("High Confidence")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        Text(String(format: "%.0f%%", highAvgFG))
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(.green)
                        Text("FG%")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)

                    Rectangle()
                        .fill(PepTheme.elevated)
                        .frame(width: 1, height: 50)

                    VStack(spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.orange)
                            Text("Low Confidence")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        Text(String(format: "%.0f%%", lowAvgFG))
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(.orange)
                        Text("FG%")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 4)

                if diff > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(PepTheme.violet)
                        Text("Your FG% jumps \(String(format: "%.0f%%", diff)) when confidence is 7+. Stay confident!")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [PepTheme.violet.opacity(0.12), PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    // MARK: - Practice Plans

    private var practicePlansCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.clipboard.fill")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Practice Plans")
                Spacer()
                Button {
                    bbVM.showPracticePlanBuilder = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(accentColor)
                }
            }

            if bbVM.practicePlans.isEmpty {
                noDataPlaceholder("Create a practice plan from the drill library")
            } else {
                ForEach(bbVM.practicePlans.prefix(3)) { plan in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(accentColor.opacity(0.12))
                                .frame(width: 38, height: 38)
                            Image(systemName: "list.clipboard")
                                .font(.system(size: 14))
                                .foregroundStyle(accentColor)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(plan.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                            Text("\(plan.drills.count) drills · \(plan.totalDuration) min")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(PepTheme.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    // MARK: - Drill Library Button

    private var drillLibraryButton: some View {
        Button {
            bbVM.showDrillLibrary = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "figure.basketball")
                    .font(.title3)
                    .foregroundStyle(accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Drill Library")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("\(BasketballDrillLibrary.all.count) drills across \(DrillCategory.allCases.count) categories")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(16)
            .background(PepTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 16))
            .overlay(cardBorder())
        }
        .buttonStyle(.scale)
    }

    // MARK: - Workout Builder Button

    private var workoutBuilderButton: some View {
        Button {
            bbVM.showPracticePlanBuilder = true
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
                    Text("Create Practice Plan")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Build custom drill sessions")
                        .font(.system(size: 11))
                        .foregroundStyle(PepTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(16)
            .background(PepTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 16))
            .overlay(cardBorder())
        }
        .buttonStyle(.scale)
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

    private func cardBorder() -> some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(
                LinearGradient(colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 0.5
            )
    }
}
