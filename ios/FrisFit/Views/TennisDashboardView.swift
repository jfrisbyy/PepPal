import SwiftUI

struct TennisDashboardView: View {
    @Bindable var tennisVM: TennisViewModel
    let accentColor: Color

    var body: some View {
        VStack(spacing: 18) {
            heroCard
            primaryActionRow
            sessionTypePicker
            serveCard
            winnersErrorsCard
            formChartCard
            recentMatchesCard
            headToHeadCard
            shotDistributionCard
            workoutBuilderCard
            drillLibraryCard
            settingsRow
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        PepSportCard(accent: accentColor) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("TENNIS")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.0)
                        .foregroundStyle(accentColor.opacity(0.9))
                    Spacer()
                    if tennisVM.totalMatchesPlayed > 0 {
                        Text(String(format: "%.0f%% WIN", tennisVM.winPercentage))
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(tennisVM.winPercentage >= 50 ? .green : .orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background((tennisVM.winPercentage >= 50 ? Color.green : Color.orange).opacity(0.12))
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
                    heroStat(value: "\(tennisVM.thisWeekSessions)", label: "THIS WEEK")
                    statDivider
                    heroStat(value: "\(tennisVM.totalAces)", label: "ACES")
                    statDivider
                    heroStat(value: String(format: "%.1f", tennisVM.averageWinners), label: "WIN/M")
                    statDivider
                    heroStat(value: "\(tennisVM.totalMatchesPlayed)", label: "MATCHES")
                }
            }
        }
    }

    private var heroTitle: String {
        let sessions = tennisVM.thisWeekSessions
        if sessions == 0 { return "Pick up the racket." }
        if let recent = tennisVM.matches.first, recent.result == .win { return "Riding the win." }
        if tennisVM.thisWeekMatches.contains(where: { $0.result == .win }) { return "Stacking wins." }
        if sessions >= 3 { return "On the court." }
        return "Find your rhythm."
    }

    private var heroLine: String {
        let sessions = tennisVM.thisWeekSessions
        if sessions == 0 {
            return "No sessions this week — even a 30-minute hit keeps the strings warm."
        }
        if tennisVM.totalMatchesPlayed > 0 && tennisVM.averageFirstServePercentage > 0 && tennisVM.averageFirstServePercentage < 55 {
            return "First serve is dipping — a serve-only block could move the dial fast."
        }
        let matches = tennisVM.thisWeekMatches.filter { $0.sessionType.isMatch }.count
        if matches >= 2 {
            return "\(matches) matches in the week — show the legs you trained."
        }
        if tennisVM.totalUnforcedErrors > 0 && tennisVM.totalWinners >= tennisVM.totalUnforcedErrors {
            return "Winners outpacing errors — keep playing big."
        }
        return "\(sessions) session\(sessions == 1 ? "" : "s") logged this week — keep the touch sharp."
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

    // MARK: - Primary action

    private var primaryActionRow: some View {
        HStack(spacing: 10) {
            if tennisVM.selectedSessionType.isMatch {
                Button {
                    tennisVM.startLiveMatch()
                    tennisVM.showLiveScorer = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Live Score")
                            .font(.system(size: 14, weight: .semibold, design: .serif))
                            .tracking(0.3)
                    }
                    .foregroundStyle(accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(accentColor.opacity(0.14))
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(accentColor.opacity(0.35), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.scale)
            }

            EditorialPrimaryButton(
                tennisVM.selectedSessionType.isMatch ? "Log a Match" : "Log a Session",
                icon: "tennis.racket",
                accent: accentColor
            ) {
                tennisVM.showMatchLog = true
            }
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
                    Text(tennisVM.selectedSessionType.rawValue.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(accentColor)
                )
            )

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(TennisSessionType.allCases) { type in
                        Button {
                            tennisVM.selectedSessionType = type
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 14))
                                Text(type.rawValue)
                                    .font(.system(size: 9, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .foregroundStyle(tennisVM.selectedSessionType == type ? .black : PepTheme.textSecondary)
                            .frame(width: 78)
                            .padding(.vertical, 10)
                            .background(tennisVM.selectedSessionType == type ? accentColor : PepTheme.elevated.opacity(0.5))
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

    // MARK: - Serve

    private var serveCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "02 — Serve",
                title: "Hold Serve",
                accent: accentColor,
                trailing: tennisVM.totalMatchesPlayed > 0 ? AnyView(
                    Text(String(format: "%.0f%% 1ST", tennisVM.averageFirstServePercentage))
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(accentColor)
                ) : nil
            )

            if tennisVM.totalMatchesPlayed == 0 {
                editorialEmpty(icon: "arrow.up.right", message: "Log a match to surface your serve picture.")
            } else {
                HStack(spacing: 10) {
                    serveRing(label: "1st Srv", value: tennisVM.averageFirstServePercentage, color: accentColor)
                    serveRing(label: "Aces / M", value: min(tennisVM.averageAcesPerMatch * 10, 100), displayValue: String(format: "%.1f", tennisVM.averageAcesPerMatch), color: .green)
                    serveRing(label: "DF / M", value: max(100 - tennisVM.averageDoubleFaultsPerMatch * 20, 0), displayValue: String(format: "%.1f", tennisVM.averageDoubleFaultsPerMatch), color: .red)
                }

                Text(serveInsight)
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .editorialCard(accent: accentColor)
    }

    private var serveInsight: String {
        let pct = tennisVM.averageFirstServePercentage
        if pct == 0 { return "Track first-serve makes to start the trend." }
        if pct >= 65 { return "First serve is locked in — free points all match." }
        if pct >= 55 { return "Serve is steady — push for one more ace per match." }
        return "First serve dipping — slow the toss and find rhythm."
    }

    private func serveRing(label: String, value: Double, displayValue: String? = nil, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(PepTheme.elevated.opacity(0.6), lineWidth: 6)
                    .frame(width: 60, height: 60)
                Circle()
                    .trim(from: 0, to: min(value / 100, 1.0))
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                Text(displayValue ?? String(format: "%.0f", value))
                    .font(.system(size: 14, weight: .bold, design: .serif))
                    .foregroundStyle(color)
            }
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Winners vs errors

    private var winnersErrorsCard: some View {
        let totalW = tennisVM.totalWinners
        let totalUE = tennisVM.totalUnforcedErrors
        let total = max(totalW + totalUE, 1)
        let ratio = totalUE > 0 ? Double(totalW) / Double(totalUE) : Double(totalW)
        return VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "03 — Rally",
                title: "Winners vs Errors",
                accent: PepTheme.amber,
                trailing: tennisVM.totalMatchesPlayed > 0 ? AnyView(
                    Text(String(format: "%.2f W/UE", ratio))
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(ratio >= 1.0 ? .green : .orange)
                ) : nil
            )

            if tennisVM.totalMatchesPlayed == 0 {
                editorialEmpty(icon: "chart.bar.fill", message: "Log winners and errors to see the balance.")
            } else {
                HStack(spacing: 0) {
                    winnerErrorCol(value: "\(totalW)", label: "WINNERS", color: .green)
                    statDivider
                    winnerErrorCol(value: String(format: "%.2f", ratio), label: "RATIO", color: ratio >= 1.0 ? .green : .orange)
                    statDivider
                    winnerErrorCol(value: "\(totalUE)", label: "UE", color: .red)
                }

                GeometryReader { geo in
                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(geo.size.width * CGFloat(totalW) / CGFloat(total), 4))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(colors: [.red.opacity(0.85), .red.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                    }
                }
                .frame(height: 8)

                Text(winnersErrorsInsight(ratio: ratio))
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .editorialCard(accent: PepTheme.amber)
    }

    private func winnerErrorCol(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func winnersErrorsInsight(ratio: Double) -> String {
        if ratio >= 1.5 { return "Cleanest tennis you've played — keep the patterns." }
        if ratio >= 1.0 { return "Slight edge to the winners — convert one more loose point per set." }
        if ratio >= 0.7 { return "UEs creeping up — add margin and let opponents miss first." }
        return "Errors outpacing winners — slow it down and rebuild the rally first."
    }

    // MARK: - Form chart

    private var formChartCard: some View {
        let data = tennisVM.formData
        return VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "04 — Form",
                title: "Last \(data.count > 0 ? "\(data.count) " : "")Matches",
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
                kicker: "05 — Recent",
                title: "Match Log",
                accent: accentColor,
                trailing: AnyView(
                    Text("\(tennisVM.matches.count) TOTAL")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textSecondary)
                )
            )

            if tennisVM.matches.isEmpty {
                editorialEmpty(icon: "tennis.racket", message: "No matches yet — your first log starts the story.")
            } else {
                VStack(spacing: 10) {
                    ForEach(tennisVM.matches.prefix(5)) { match in
                        Button {
                            tennisVM.selectedMatch = match
                            tennisVM.showMatchDetail = true
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

    private func recentMatchRow(_ match: TennisMatch) -> some View {
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
                    Text(match.sessionType.isMatch && !match.opponentName.isEmpty ? "vs \(match.opponentName)" : match.sessionType.rawValue)
                        .font(.system(size: 13, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(1)
                    if !match.sets.isEmpty {
                        Text(match.scoreDisplay)
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
                if match.sessionType.isMatch {
                    HStack(spacing: 4) {
                        if match.stats.aces > 0 {
                            statChip(text: "\(match.stats.aces) ACE", color: accentColor)
                        }
                        if match.stats.winners > 0 {
                            statChip(text: "\(match.stats.winners)W", color: .green)
                        }
                        if match.stats.aces == 0 && match.stats.winners == 0 {
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
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: - Head to head

    @ViewBuilder
    private var headToHeadCard: some View {
        let records = tennisVM.headToHeadRecords
        if !records.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                EditorialSectionHeading(
                    kicker: "06 — Rivalries",
                    title: "Head-to-Head",
                    accent: PepTheme.violet,
                    trailing: AnyView(
                        Text("\(records.count) OPPS")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(PepTheme.textSecondary)
                    )
                )

                VStack(spacing: 10) {
                    ForEach(records.prefix(5), id: \.opponent) { record in
                        h2hRow(record)
                    }
                }
            }
            .editorialCard(accent: PepTheme.violet)
        }
    }

    private func h2hRow(_ record: (opponent: String, wins: Int, losses: Int)) -> some View {
        let total = max(record.wins + record.losses, 1)
        let winShare = CGFloat(record.wins) / CGFloat(total)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(PepTheme.violet.opacity(0.14))
                        .frame(width: 32, height: 32)
                    Text(String(record.opponent.prefix(1)))
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .foregroundStyle(PepTheme.violet)
                }
                Text(record.opponent)
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                HStack(spacing: 4) {
                    Text("\(record.wins)")
                        .font(.system(size: 13, weight: .bold, design: .serif))
                        .foregroundStyle(.green)
                    Text("–")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary)
                    Text("\(record.losses)")
                        .font(.system(size: 13, weight: .bold, design: .serif))
                        .foregroundStyle(.red)
                }
            }
            GeometryReader { geo in
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.green.opacity(0.85))
                        .frame(width: max(geo.size.width * winShare, 2))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.red.opacity(0.6))
                }
            }
            .frame(height: 4)
        }
    }

    // MARK: - Shot distribution

    @ViewBuilder
    private var shotDistributionCard: some View {
        let dist = tennisVM.shotDistribution
        let totalShots = dist.reduce(0) { $0 + $1.count }
        if totalShots > 0 {
            VStack(alignment: .leading, spacing: 14) {
                EditorialSectionHeading(
                    kicker: "07 — Shots",
                    title: "Shot Distribution",
                    accent: accentColor
                )

                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(dist, id: \.type) { item in
                            if item.count > 0 {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(LinearGradient(colors: [item.color, item.color.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                                    .frame(width: geo.size.width * CGFloat(item.count) / CGFloat(totalShots))
                            }
                        }
                    }
                }
                .frame(height: 12)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 8) {
                    ForEach(dist, id: \.type) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(item.color)
                                .frame(width: 8, height: 8)
                            Text(item.type)
                                .font(.system(size: 11, weight: .medium, design: .serif))
                                .foregroundStyle(PepTheme.textSecondary)
                            Spacer()
                            Text("\(item.count)")
                                .font(.system(size: 12, weight: .semibold, design: .serif))
                                .foregroundStyle(PepTheme.textPrimary)
                        }
                    }
                }
            }
            .editorialCard(accent: accentColor)
        }
    }

    // MARK: - Builder + library

    private var workoutBuilderCard: some View {
        Button {
            tennisVM.showWorkoutBuilder = true
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
                    Text("Build a practice session")
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("\(tennisVM.savedTennisSessions.count) saved · stack drills into a session")
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
            tennisVM.showDrillLibrary = true
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
                    Text("\(TennisDrillLibrary.all.count) drills · \(TennisDrillCategory.allCases.count) categories · tap any drill for the full breakdown")
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
            tennisVM.showSettings = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                Text("TENNIS SETTINGS")
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
