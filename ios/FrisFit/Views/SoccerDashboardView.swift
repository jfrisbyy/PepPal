import SwiftUI

struct SoccerDashboardView: View {
    @Bindable var soccerVM: SoccerViewModel
    let accentColor: Color

    var body: some View {
        VStack(spacing: 18) {
            heroCard
            primaryLogButton
            sessionTypePicker
            positionDashboardCard
            formChartCard
            recentMatchesCard
            seasonStatsCard
            movementStatsCard
            workoutBuilderCard
            drillLibraryCard
            settingsRow
        }
    }

    // MARK: - Hero (Editorial)

    private var heroCard: some View {
        PepSportCard(accent: accentColor) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("SOCCER")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.0)
                        .foregroundStyle(accentColor.opacity(0.9))
                    Spacer()
                    if soccerVM.totalGamesPlayed > 0 {
                        Text(String(format: "%.0f%% WIN", soccerVM.winPercentage))
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(soccerVM.winPercentage >= 50 ? .green : .orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background((soccerVM.winPercentage >= 50 ? Color.green : Color.orange).opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                Text(heroTitle)
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .kerning(-0.5)
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(2)

                Text(heroLine)
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                LinearGradient(
                    colors: [PepTheme.textPrimary.opacity(0.16), PepTheme.textPrimary.opacity(0)],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 0.5)

                HStack(spacing: 0) {
                    heroStat(value: "\(soccerVM.thisWeekSessions)", label: "THIS WEEK")
                    statDivider
                    heroStat(value: "\(soccerVM.totalGoalContributions)", label: "G+A")
                    statDivider
                    heroStat(value: String(format: "%.1f", soccerVM.averageRating), label: "AVG RATING")
                    statDivider
                    heroStat(value: "\(soccerVM.totalGamesPlayed)", label: "MATCHES")
                }
            }
        }
    }

    private var heroTitle: String {
        let runs = soccerVM.thisWeekSessions
        if runs == 0 { return "Lace 'em up." }
        if runs == 1 { return "On the pitch." }
        if soccerVM.thisWeekMatches.contains(where: { $0.result == .win }) { return "Stacking wins." }
        return "In the rhythm."
    }

    private var heroLine: String {
        let runs = soccerVM.thisWeekSessions
        if runs == 0 {
            return "No sessions this week — even a 20-minute kickabout starts the streak."
        }
        if soccerVM.totalGoalContributions == 0 && soccerVM.totalGamesPlayed > 0 {
            return "Sharpen the final ball — the chances are coming."
        }
        let games = soccerVM.thisWeekMatches.filter { $0.sessionType.isGame }.count
        if games >= 2 {
            return "\(games) matches in the week — show the legs you trained."
        }
        return "\(runs) session\(runs == 1 ? "" : "s") logged this week — keep the touch sharp."
    }

    private var statDivider: some View {
        Rectangle()
            .fill(PepTheme.shimmerHighlight)
            .frame(width: 0.5, height: 28)
    }

    private func heroStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Primary CTA

    private var primaryLogButton: some View {
        EditorialPrimaryButton(
            soccerVM.selectedSessionType.isGame ? "Log a Match" : "Log a Session",
            icon: "soccerball.inverse",
            accent: accentColor
        ) {
            soccerVM.showGameLog = true
        }
    }

    // MARK: - Session type picker

    private var sessionTypePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(
                kicker: "01 — Session",
                title: "Pick the work",
                accent: accentColor,
                trailing: AnyView(
                    Text(soccerVM.selectedSessionType.rawValue.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(accentColor)
                )
            )

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
                                    .font(.system(size: 9, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .foregroundStyle(soccerVM.selectedSessionType == type ? .black : PepTheme.textSecondary)
                            .frame(width: 78)
                            .padding(.vertical, 10)
                            .background(soccerVM.selectedSessionType == type ? accentColor : PepTheme.elevated.opacity(0.5))
                            .clipShape(.rect(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)
        }
        .editorialCard(accent: accentColor)
    }

    // MARK: - Position Dashboard

    private var positionDashboardCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "02 — Position",
                title: soccerVM.primaryPosition.rawValue,
                accent: accentColor,
                trailing: AnyView(
                    Button {
                        soccerVM.showSettings = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(soccerVM.primaryPosition.shortName)
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.2)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(accentColor.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                )
            )

            if soccerVM.totalGamesPlayed == 0 {
                editorialEmpty(icon: soccerVM.primaryPosition.icon, message: "Log a match to surface stats tailored to your role.")
            } else {
                HStack(spacing: 0) {
                    ForEach(Array(soccerVM.positionDashboardStats.enumerated()), id: \.offset) { idx, stat in
                        VStack(spacing: 4) {
                            Text(stat.value)
                                .font(.system(.title3, design: .serif, weight: .semibold))
                                .foregroundStyle(stat.color)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text(stat.label.uppercased())
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(1.2)
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)

                        if idx < soccerVM.positionDashboardStats.count - 1 {
                            statDivider
                        }
                    }
                }

                Text(positionInsight)
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .editorialCard(accent: accentColor)
    }

    private var positionInsight: String {
        if soccerVM.primaryPosition.isAttacker || soccerVM.primaryPosition == .attackingMid {
            return "Stay greedy in the box — clinical finishing wins matches."
        }
        if soccerVM.primaryPosition.isDefender {
            return "Reading the play matters more than reaching for the ball."
        }
        if soccerVM.primaryPosition == .goalkeeper {
            return "Communication is your superpower — talk early, talk loud."
        }
        return "The midfield engine — set the tempo, recycle possession."
    }

    // MARK: - Form chart

    private var formChartCard: some View {
        let data = soccerVM.formData
        return VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "03 — Form",
                title: "Last 10 Matches",
                accent: accentColor,
                trailing: data.count >= 2 ? AnyView(
                    Text(String(format: "%.1f AVG", data.reduce(0.0) { $0 + Double($1.rating) } / Double(data.count)))
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.amber)
                ) : nil
            )

            if data.count < 2 {
                editorialEmpty(icon: "chart.line.uptrend.xyaxis", message: "Need 2+ matches to show form.")
            } else {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(data.enumerated()), id: \.offset) { _, entry in
                        VStack(spacing: 4) {
                            Text("\(entry.rating)")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(ratingColor(entry.rating))

                            RoundedRectangle(cornerRadius: 4)
                                .fill(LinearGradient(
                                    colors: [ratingColor(entry.rating), ratingColor(entry.rating).opacity(0.6)],
                                    startPoint: .top, endPoint: .bottom
                                ))
                                .frame(height: max(CGFloat(entry.rating) / 10.0 * 70, 4))

                            Text(dayLabel(entry.date))
                                .font(.system(size: 8, weight: .medium))
                                .tracking(0.6)
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 100)

                Text(formInsight(data))
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .editorialCard(accent: accentColor)
    }

    private func formInsight(_ data: [(date: Date, rating: Int)]) -> String {
        guard data.count >= 3 else { return "Trend is taking shape." }
        let recent = data.suffix(3).map(\.rating).reduce(0, +) / 3
        let prior = data.prefix(max(1, data.count - 3)).map(\.rating).reduce(0, +) / max(1, data.count - 3)
        if recent > prior + 1 { return "Form is climbing — the work is showing." }
        if recent < prior - 1 { return "Dip in form — a recovery week might reset the legs." }
        return "Steady form across the last block."
    }

    // MARK: - Recent matches

    private var recentMatchesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "04 — Recent",
                title: "Match Log",
                accent: accentColor,
                trailing: AnyView(
                    Text("\(soccerVM.matches.count) TOTAL")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textSecondary)
                )
            )

            if soccerVM.matches.isEmpty {
                editorialEmpty(icon: "soccerball", message: "No matches yet — your first log starts the story.")
            } else {
                VStack(spacing: 10) {
                    ForEach(soccerVM.matches.prefix(5)) { match in
                        Button {
                            soccerVM.selectedMatch = match
                            soccerVM.showMatchDetail = true
                        } label: {
                            recentMatchRow(match)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .editorialCard(accent: accentColor)
    }

    private func recentMatchRow(_ match: SoccerMatch) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((match.result?.color ?? accentColor).opacity(0.14))
                    .frame(width: 44, height: 44)
                if let result = match.result {
                    Text(result.rawValue)
                        .font(.system(size: 17, weight: .black, design: .serif))
                        .foregroundStyle(result.color)
                } else {
                    Image(systemName: match.sessionType.icon)
                        .font(.system(size: 17))
                        .foregroundStyle(accentColor)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(match.sessionType.rawValue)
                        .font(.system(size: 13, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(match.position.shortName)
                        .font(.system(size: 8, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(accentColor.opacity(0.12))
                        .clipShape(Capsule())
                    if let ts = match.teamScore, let os = match.opponentScore {
                        Text("\(ts)–\(os)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(match.result?.color ?? PepTheme.textSecondary)
                    }
                }
                Text(match.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(.system(size: 10, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                if match.sessionType.isGame {
                    HStack(spacing: 4) {
                        if match.stats.goals > 0 {
                            statChip(text: "\(match.stats.goals)G", color: accentColor)
                        }
                        if match.stats.assists > 0 {
                            statChip(text: "\(match.stats.assists)A", color: .blue)
                        }
                        if match.stats.goals == 0 && match.stats.assists == 0 {
                            Text("\(match.performanceRating)/10")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                } else {
                    Text("\(match.durationMinutes)m")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
        }
        .padding(.vertical, 4)
    }

    private func statChip(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: - Season stats

    private var seasonStatsCard: some View {
        let gm = soccerVM.gameMatches
        return VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "05 — Season",
                title: "By the Numbers",
                accent: PepTheme.amber,
                trailing: AnyView(
                    Text("\(soccerVM.totalGamesPlayed) GP")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textSecondary)
                )
            )

            if gm.isEmpty {
                editorialEmpty(icon: "chart.bar.fill", message: "Log matches to build the season ledger.")
            } else {
                let avgKeyPasses = Double(gm.reduce(0) { $0 + $1.stats.keyPasses }) / Double(gm.count)
                let avgTackles = Double(gm.reduce(0) { $0 + $1.stats.tacklesWon }) / Double(gm.count)
                let avgInterceptions = Double(gm.reduce(0) { $0 + $1.stats.interceptions }) / Double(gm.count)
                let totalYellows = gm.reduce(0) { $0 + $1.stats.yellowCards }
                let totalReds = gm.reduce(0) { $0 + $1.stats.redCards }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    seasonStatCell(value: "\(soccerVM.totalGoals)", label: "Goals", color: accentColor)
                    seasonStatCell(value: "\(soccerVM.totalAssists)", label: "Assists", color: .blue)
                    seasonStatCell(value: String(format: "%.1f", avgKeyPasses), label: "Key Pass", color: .cyan)
                    seasonStatCell(value: String(format: "%.1f", avgTackles), label: "Tackles", color: .red)
                    seasonStatCell(value: String(format: "%.1f", avgInterceptions), label: "INT", color: .orange)
                    seasonStatCell(value: "\(totalYellows)Y \(totalReds)R", label: "Cards", color: PepTheme.amber)
                }

                HStack(spacing: 10) {
                    recordChip(label: "W", count: soccerVM.totalWins, color: .green)
                    recordChip(label: "D", count: soccerVM.totalDraws, color: .orange)
                    recordChip(label: "L", count: soccerVM.totalLosses, color: .red)
                }
            }
        }
        .editorialCard(accent: PepTheme.amber)
    }

    private func recordChip(label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(color)
            Text("\(count)")
                .font(.system(size: 12, weight: .bold, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 8))
    }

    private func seasonStatCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
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
        .padding(.vertical, 10)
        .background(color.opacity(0.06))
        .clipShape(.rect(cornerRadius: 10))
    }

    // MARK: - Movement

    @ViewBuilder
    private var movementStatsCard: some View {
        let matchesWithDist = soccerVM.matches.filter { $0.distanceKm > 0 }
        if !matchesWithDist.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                EditorialSectionHeading(
                    kicker: "06 — Engine",
                    title: "Movement",
                    accent: accentColor
                )

                let totalDist = matchesWithDist.reduce(0.0) { $0 + $1.distanceKm }
                let avgSprints = matchesWithDist.reduce(0) { $0 + $1.sprintCount } / matchesWithDist.count
                let topSpeed = matchesWithDist.map(\.topSpeedKmh).max() ?? 0

                HStack(spacing: 0) {
                    movementCol(value: String(format: "%.1f", soccerVM.averageDistance), unit: "km", label: "AVG DIST", color: accentColor)
                    statDivider
                    movementCol(value: "\(avgSprints)", unit: "", label: "AVG SPRINT", color: .orange)
                    statDivider
                    movementCol(value: String(format: "%.1f", topSpeed), unit: "km/h", label: "TOP SPEED", color: .red)
                }

                Text(String(format: "%.1f km total covered across %d matches.", totalDist, matchesWithDist.count))
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .editorialCard(accent: accentColor)
        }
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

    // MARK: - Workout builder + drill library

    private var workoutBuilderCard: some View {
        Button {
            soccerVM.showWorkoutBuilder = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.14))
                        .frame(width: 40, height: 40)
                    Image(systemName: "plus.rectangle.on.folder")
                        .font(.system(size: 16))
                        .foregroundStyle(accentColor)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Build a training session")
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("\(soccerVM.savedSoccerSessions.count) saved · drag drills into a circuit")
                        .font(.system(size: 11, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .editorialCard(accent: accentColor)
    }

    private var drillLibraryCard: some View {
        Button {
            soccerVM.showDrillLibrary = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.14))
                        .frame(width: 40, height: 40)
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(accentColor)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Drill Library")
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("\(SoccerDrillLibrary.all.count) drills · \(SoccerDrillCategory.allCases.count) categories · tap any drill for the full breakdown")
                        .font(.system(size: 11, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .editorialCard(accent: accentColor)
    }

    private var settingsRow: some View {
        Button {
            soccerVM.showSettings = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                Text("SOCCER SETTINGS")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.6)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(PepTheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(PepTheme.elevated.opacity(0.4))
            .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

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
        return formatter.string(from: date).uppercased()
    }

    private func editorialEmpty(icon: String, message: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                Text(message)
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 14)
            Spacer()
        }
    }
}
