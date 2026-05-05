import SwiftUI

struct TennisDashboardView: View {
    @Bindable var tennisVM: TennisViewModel
    let accentColor: Color

    var body: some View {
        VStack(spacing: 16) {
            quickStatsHeader
            sessionTypeSelector
            recentMatchesList
            serveStatsCard
            winnerErrorCard
            formChartCard
            headToHeadCard
            shotDistributionCard
            workoutBuilderButton
            drillLibraryButton
        }
    }

    private var quickStatsHeader: some View {
        EditorialSportHeader(
            kicker: "Tennis",
            title: "On the Court",
            subtitle: "\(tennisVM.thisWeekSessions) session\(tennisVM.thisWeekSessions == 1 ? "" : "s") this week  ·  \(tennisVM.totalWins)W–\(tennisVM.totalLosses)L",
            accent: accentColor,
            stats: [
                EditorialStat(String(format: "%.1f", tennisVM.averageAcesPerMatch), "Aces"),
                EditorialStat(String(format: "%.0f%%", tennisVM.averageFirstServePercentage), "1st Srv"),
                EditorialStat(String(format: "%.1f", tennisVM.averageWinners), "Win/M"),
                EditorialStat("\(tennisVM.totalMatchesPlayed)", "Mtch")
            ]
        ) {
            if tennisVM.totalMatchesPlayed > 0 {
                Text("WIN \(String(format: "%.0f%%", tennisVM.winPercentage))")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.4)
                    .foregroundStyle(PepTheme.textTertiary)
            }
        }
    }

    private var sessionTypeSelector: some View {
        VStack(spacing: 14) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach([TennisSessionType.singlesMatch, .doublesMatch, .hittingSession, .soloRally, .ballMachine], id: \.id) { type in
                        Button {
                            tennisVM.selectedSessionType = type
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 14))
                                Text(type.rawValue)
                                    .font(.system(size: 8, weight: .semibold))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(tennisVM.selectedSessionType == type ? .black : PepTheme.textSecondary)
                            .frame(width: 72)
                            .padding(.vertical, 10)
                            .background(tennisVM.selectedSessionType == type ? accentColor : PepTheme.elevated.opacity(0.5))
                            .clipShape(.rect(cornerRadius: 10))
                        }
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)

            HStack(spacing: 8) {
                if tennisVM.selectedSessionType.isMatch {
                    Button {
                        tennisVM.startLiveMatch()
                        tennisVM.showLiveScorer = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14))
                            Text("Live Score")
                                .font(.subheadline.weight(.bold))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(accentColor)
                        .clipShape(.rect(cornerRadius: 14))
                    }
                    .buttonStyle(.scalePrimary)
                }

                Button {
                    tennisVM.showMatchLog = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                        Text("Log \(tennisVM.selectedSessionType.isMatch ? "Match" : "Session")")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(tennisVM.selectedSessionType.isMatch ? accentColor : .black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(tennisVM.selectedSessionType.isMatch ? accentColor.opacity(0.15) : accentColor)
                    .clipShape(.rect(cornerRadius: 14))
                }
                .buttonStyle(.scalePrimary)
            }
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

    private var recentMatchesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Recent Matches")
                Spacer()
                Text("\(tennisVM.gameMatches.count) total")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }

            if tennisVM.matches.isEmpty {
                noDataPlaceholder("No matches logged yet")
            } else {
                ForEach(tennisVM.matches.prefix(5)) { match in
                    Button {
                        tennisVM.selectedMatch = match
                        tennisVM.showMatchDetail = true
                    } label: {
                        recentMatchRow(match)
                    }
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private func recentMatchRow(_ match: TennisMatch) -> some View {
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
                    Text(match.sessionType.isMatch ? (match.opponentName.isEmpty ? match.sessionType.rawValue : "vs \(match.opponentName)") : match.sessionType.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    if !match.sets.isEmpty {
                        Text(match.scoreDisplay)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(match.result?.color ?? PepTheme.textSecondary)
                    }
                }
                Text(match.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(.system(size: 10))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            if match.sessionType.isMatch {
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(match.stats.aces) aces")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(accentColor)
                    Text(String(format: "%.0f%% 1st", match.stats.firstServePercentage))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            } else {
                Text("\(match.durationMinutes)m")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
        }
        .padding(.vertical, 4)
    }

    private var serveStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Serve Stats")
                Spacer()
            }

            if tennisVM.totalMatchesPlayed == 0 {
                noDataPlaceholder("Log matches to see serve stats")
            } else {
                HStack(spacing: 8) {
                    serveRing(label: "1st Srv%", value: tennisVM.averageFirstServePercentage, color: accentColor)
                    serveRing(label: "Aces/M", value: tennisVM.averageAcesPerMatch * 10, displayValue: String(format: "%.1f", tennisVM.averageAcesPerMatch), color: .green)
                    serveRing(label: "DF/M", value: max(100 - tennisVM.averageDoubleFaultsPerMatch * 20, 0), displayValue: String(format: "%.1f", tennisVM.averageDoubleFaultsPerMatch), color: .red)
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private func serveRing(label: String, value: Double, displayValue: String? = nil, color: Color) -> some View {
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
                Text(displayValue ?? String(format: "%.0f", value))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var winnerErrorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(PepTheme.amber)
                HeadlineText(text: "Winners vs Errors")
                Spacer()
            }

            if tennisVM.totalMatchesPlayed == 0 {
                noDataPlaceholder("Play matches to see stats")
            } else {
                HStack(spacing: 16) {
                    VStack(spacing: 6) {
                        Text("\(tennisVM.totalWinners)")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(.green)
                        Text("Winners")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)

                    ZStack {
                        Circle()
                            .fill(PepTheme.elevated)
                            .frame(width: 50, height: 50)
                        let ratio = tennisVM.totalUnforcedErrors > 0 ? Double(tennisVM.totalWinners) / Double(tennisVM.totalUnforcedErrors) : 0
                        Text(String(format: "%.1f", ratio))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(ratio >= 1.0 ? .green : .orange)
                    }

                    VStack(spacing: 6) {
                        Text("\(tennisVM.totalUnforcedErrors)")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(.red)
                        Text("UE")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                let totalW = tennisVM.totalWinners
                let totalUE = tennisVM.totalUnforcedErrors
                let total = max(totalW + totalUE, 1)
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.green)
                            .frame(width: geo.size.width * CGFloat(totalW) / CGFloat(total))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.red)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private var formChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Performance Form")
                Spacer()
            }

            let data = tennisVM.formData
            if data.count < 2 {
                noDataPlaceholder("Need 2+ matches for form chart")
            } else {
                GeometryReader { geo in
                    let width = geo.size.width
                    let height: CGFloat = 80
                    let stepX = width / CGFloat(max(data.count - 1, 1))

                    ZStack(alignment: .topLeading) {
                        Path { path in
                            for (i, point) in data.enumerated() {
                                let x = CGFloat(i) * stepX
                                let y = height - CGFloat(Double(point.rating) / 10.0) * height
                                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                        }
                        .stroke(accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                        Path { path in
                            for (i, point) in data.enumerated() {
                                let x = CGFloat(i) * stepX
                                let y = height - CGFloat(Double(point.rating) / 10.0) * height
                                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                            if let last = data.indices.last {
                                path.addLine(to: CGPoint(x: CGFloat(last) * stepX, y: height))
                                path.addLine(to: CGPoint(x: 0, y: height))
                                path.closeSubpath()
                            }
                        }
                        .fill(LinearGradient(colors: [accentColor.opacity(0.2), accentColor.opacity(0)], startPoint: .top, endPoint: .bottom))

                        ForEach(Array(data.enumerated()), id: \.offset) { i, point in
                            let x = CGFloat(i) * stepX
                            let y = height - CGFloat(Double(point.rating) / 10.0) * height
                            Circle()
                                .fill(accentColor)
                                .frame(width: 6, height: 6)
                                .position(x: x, y: y)
                        }
                    }
                    .frame(height: height)
                }
                .frame(height: 80)

                HStack {
                    Text("Last \(data.count) matches")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                    if let first = data.first, let last = data.last {
                        let diff = last.rating - first.rating
                        HStack(spacing: 3) {
                            Image(systemName: diff >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 9))
                            Text("\(diff >= 0 ? "+" : "")\(diff)")
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

    private var headToHeadCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(PepTheme.violet)
                HeadlineText(text: "Head-to-Head")
                Spacer()
            }

            let records = tennisVM.headToHeadRecords
            if records.isEmpty {
                noDataPlaceholder("Log matches with opponent names")
            } else {
                ForEach(records.prefix(5), id: \.opponent) { record in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(PepTheme.violet.opacity(0.12))
                                .frame(width: 36, height: 36)
                            Text(String(record.opponent.prefix(1)))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(PepTheme.violet)
                        }

                        Text(record.opponent)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)

                        Spacer()

                        HStack(spacing: 4) {
                            Text("\(record.wins)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.green)
                            Text("-")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(PepTheme.textSecondary)
                            Text("\(record.losses)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.red)
                        }
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
                    LinearGradient(colors: [PepTheme.violet.opacity(0.12), PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    private var shotDistributionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Shot Distribution")
                Spacer()
            }

            let dist = tennisVM.shotDistribution
            let totalShots = dist.reduce(0) { $0 + $1.count }

            if totalShots == 0 {
                noDataPlaceholder("Track shots to see distribution")
            } else {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(dist, id: \.type) { item in
                            if item.count > 0 {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(item.color)
                                    .frame(width: geo.size.width * CGFloat(item.count) / CGFloat(totalShots))
                            }
                        }
                    }
                }
                .frame(height: 12)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(dist, id: \.type) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(item.color)
                                .frame(width: 8, height: 8)
                            Text(item.type)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(PepTheme.textSecondary)
                            Spacer()
                            Text("\(item.count)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(PepTheme.textPrimary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private var drillLibraryButton: some View {
        Button {
            tennisVM.showDrillLibrary = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "figure.tennis")
                    .font(.title3)
                    .foregroundStyle(accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Drill Library")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("\(TennisDrillLibrary.all.count) drills across \(TennisDrillCategory.allCases.count) categories")
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

    private var workoutBuilderButton: some View {
        Button {
            tennisVM.showWorkoutBuilder = true
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
                    Text("Create Practice Session")
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
