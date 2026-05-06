import SwiftUI

struct PickleballDashboardView: View {
    @Bindable var pickleVM: PickleballViewModel
    let accentColor: Color

    var body: some View {
        VStack(spacing: 18) {
            heroCard
            primaryActionRow
            sessionTypePicker
            kitchenCard
            serveReturnCard
            duprCard
            formChartCard
            recentMatchesCard
            partnersCard
            rivalsCard
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
                    Text("PICKLEBALL")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.0)
                        .foregroundStyle(accentColor.opacity(0.95))
                    Spacer()
                    if pickleVM.totalMatchesPlayed > 0 {
                        Text(String(format: "%.0f%% WIN", pickleVM.winPercentage))
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(pickleVM.winPercentage >= 50 ? .green : .orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background((pickleVM.winPercentage >= 50 ? Color.green : Color.orange).opacity(0.12))
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
                    heroStat(value: "\(pickleVM.thisWeekSessions)", label: "THIS WEEK")
                    statDivider
                    heroStat(value: "\(pickleVM.totalWinners)", label: "WINNERS")
                    statDivider
                    heroStat(value: String(format: "%.1f", pickleVM.averageWinnerErrorRatio), label: "W:E")
                    statDivider
                    heroStat(value: "\(pickleVM.totalMatchesPlayed)", label: "MATCHES")
                }
            }
        }
    }

    private var heroTitle: String {
        let sessions = pickleVM.thisWeekSessions
        if sessions == 0 { return "Grab the paddle." }
        if let recent = pickleVM.matches.first, recent.result == .win { return "Riding the streak." }
        if pickleVM.thisWeekMatches.contains(where: { $0.result == .win }) { return "Stacking dubs." }
        if sessions >= 4 { return "Living at the kitchen." }
        return "Find the soft game."
    }

    private var heroLine: String {
        let sessions = pickleVM.thisWeekSessions
        if sessions == 0 {
            return "Quiet week — even a 30-minute dink session keeps the touch alive."
        }
        let drop = pickleVM.averageThirdShotDropPercentage
        if drop >= 0.75 {
            return String(format: "Drop landing %.0f%% — you're owning the third shot.", drop * 100)
        }
        if pickleVM.totalMatchesPlayed >= 2 && drop > 0 && drop < 0.45 {
            return "Drop sitting under 45% — a focused drop block could move the dial fast."
        }
        let matches = pickleVM.thisWeekMatches.filter { $0.sessionType.isMatch }.count
        if matches >= 2 {
            return "\(matches) matches in the week — show the legs you trained."
        }
        return "\(sessions) session\(sessions == 1 ? "" : "s") logged — keep the touch sharp."
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
        EditorialPrimaryButton(
            pickleVM.selectedSessionType.isMatch ? "Log a Match" : "Log a Session",
            icon: "figure.pickleball",
            accent: accentColor
        ) {
            pickleVM.showMatchLog = true
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
                    Text(pickleVM.selectedSessionType.rawValue.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(accentColor)
                )
            )

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(PickleballSessionType.allCases) { type in
                        Button {
                            pickleVM.selectedSessionType = type
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 14))
                                Text(type.rawValue)
                                    .font(.system(size: 9, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .foregroundStyle(pickleVM.selectedSessionType == type ? .black : PepTheme.textSecondary)
                            .frame(width: 82)
                            .padding(.vertical, 10)
                            .background(pickleVM.selectedSessionType == type ? accentColor : PepTheme.elevated.opacity(0.5))
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

    // MARK: - Kitchen card (Dink + Drop game)

    private var kitchenCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "02 — Kitchen",
                title: "Soft Game",
                accent: accentColor,
                trailing: pickleVM.totalMatchesPlayed > 0 ? AnyView(
                    Text(String(format: "%.0f%% DROP", pickleVM.averageThirdShotDropPercentage * 100))
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(accentColor)
                ) : nil
            )

            if pickleVM.totalMatchesPlayed == 0 {
                editorialEmpty(icon: "circle.dotted", message: "Log a match to surface your soft-game profile.")
            } else {
                HStack(spacing: 10) {
                    ringStat(
                        label: "DROP%",
                        value: pickleVM.averageThirdShotDropPercentage * 100,
                        displayValue: String(format: "%.0f%%", pickleVM.averageThirdShotDropPercentage * 100),
                        color: accentColor
                    )
                    ringStat(
                        label: "DINK%",
                        value: pickleVM.averageDinkWinPercentage * 100,
                        displayValue: String(format: "%.0f%%", pickleVM.averageDinkWinPercentage * 100),
                        color: .green
                    )
                    ringStat(
                        label: "W:E",
                        value: min(pickleVM.averageWinnerErrorRatio * 50, 100),
                        displayValue: String(format: "%.2f", pickleVM.averageWinnerErrorRatio),
                        color: PepTheme.amber
                    )
                }

                Text(kitchenInsight)
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .editorialCard(accent: accentColor)
    }

    private var kitchenInsight: String {
        let drop = pickleVM.averageThirdShotDropPercentage
        let dink = pickleVM.averageDinkWinPercentage
        if drop == 0 && dink == 0 { return "Track drops and dinks to see your kitchen story." }
        if drop >= 0.75 && dink >= 0.6 { return "Soft game elite — opponents are forced to attack into your reset." }
        if drop >= 0.6 { return "Drop is reliable. Stay patient at the line — wait for the high ball." }
        if dink >= 0.6 { return "Dink wins lead, drop lags — work the third shot under pressure." }
        return "Sharpen the kitchen — every clean drop earns you the line."
    }

    private func ringStat(label: String, value: Double, displayValue: String, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(PepTheme.elevated.opacity(0.6), lineWidth: 6)
                    .frame(width: 60, height: 60)
                Circle()
                    .trim(from: 0, to: max(0, min(value / 100, 1.0)))
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                Text(displayValue)
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 4)
            }
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Serve & Return card

    private var serveReturnCard: some View {
        let aces = pickleVM.totalAces
        let avgAces = pickleVM.totalMatchesPlayed > 0 ? Double(aces) / Double(pickleVM.totalMatchesPlayed) : 0
        let firstServe = pickleVM.averageFirstServePercentage
        return VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "03 — Serve & Return",
                title: "Setup Game",
                accent: PepTheme.amber,
                trailing: pickleVM.totalMatchesPlayed > 0 ? AnyView(
                    Text(String(format: "%.0f%% 1ST", firstServe * 100))
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.amber)
                ) : nil
            )

            if pickleVM.totalMatchesPlayed == 0 {
                editorialEmpty(icon: "scope", message: "Log serve and return data to see the breakdown.")
            } else {
                HStack(spacing: 0) {
                    columnStat(value: "\(aces)", label: "ACES", color: PepTheme.amber)
                    statDivider
                    columnStat(value: String(format: "%.1f", avgAces), label: "ACES/M", color: accentColor)
                    statDivider
                    columnStat(
                        value: String(format: "%.0f%%", firstServe * 100),
                        label: "1ST IN",
                        color: firstServe >= 0.75 ? .green : (firstServe >= 0.6 ? .orange : .red)
                    )
                }

                Text(serveInsight(avgAces: avgAces, firstServe: firstServe))
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .editorialCard(accent: PepTheme.amber)
    }

    private func serveInsight(avgAces: Double, firstServe: Double) -> String {
        if firstServe >= 0.85 { return "Serves landing — pin returners with depth and you control the rally." }
        if avgAces >= 1.5 { return "Aces stacking — the spin mix is paying off." }
        if firstServe > 0 && firstServe < 0.6 { return "First-serve % low — slow down, reset to a deep, safe serve." }
        return "Serve consistent — small gains compound across a session." 
    }

    private func columnStat(value: String, label: String, color: Color) -> some View {
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

    // MARK: - DUPR card

    @ViewBuilder
    private var duprCard: some View {
        if pickleVM.dupr > 0 || pickleVM.totalMatchesPlayed > 0 {
            VStack(alignment: .leading, spacing: 14) {
                EditorialSectionHeading(
                    kicker: "04 — Rating",
                    title: "DUPR Trajectory",
                    accent: PepTheme.violet,
                    trailing: pickleVM.dupr > 0 ? AnyView(
                        Text(String(format: "%.2f", pickleVM.dupr))
                            .font(.system(size: 11, weight: .bold, design: .serif))
                            .foregroundStyle(PepTheme.violet)
                    ) : nil
                )

                if pickleVM.dupr <= 0 {
                    editorialEmpty(icon: "chart.line.uptrend.xyaxis", message: "Add your DUPR in settings to track rating moves.")
                } else {
                    let recentDuprs = Array(pickleVM.gameMatches
                        .compactMap { $0.dupr }
                        .suffix(8))
                    if recentDuprs.count < 2 {
                        Text("Log a few rated matches and we'll plot the trend here.")
                            .font(.system(size: 12, design: .serif))
                            .italic()
                            .foregroundStyle(PepTheme.textSecondary)
                    } else {
                        let minVal = recentDuprs.min() ?? 0
                        let maxVal = recentDuprs.max() ?? 1
                        let range = max(maxVal - minVal, 0.1)
                        HStack(alignment: .bottom, spacing: 8) {
                            ForEach(Array(recentDuprs.enumerated()), id: \.offset) { _, value in
                                let normalized = (value - minVal) / range
                                VStack(spacing: 4) {
                                    Text(String(format: "%.2f", value))
                                        .font(.system(size: 8, weight: .bold, design: .rounded))
                                        .foregroundStyle(PepTheme.violet)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(LinearGradient(
                                            colors: [PepTheme.violet, PepTheme.violet.opacity(0.5)],
                                            startPoint: .top, endPoint: .bottom
                                        ))
                                        .frame(height: max(CGFloat(normalized) * 60 + 8, 8))
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(height: 90)

                        Text(duprInsight(recentDuprs))
                            .font(.system(size: 12, design: .serif))
                            .italic()
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
            }
            .editorialCard(accent: PepTheme.violet)
        }
    }

    private func duprInsight(_ values: [Double]) -> String {
        guard let first = values.first, let last = values.last else { return "Rating taking shape." }
        let delta = last - first
        if delta >= 0.10 { return String(format: "+%.2f trend over your last %d matches — climbing.", delta, values.count) }
        if delta <= -0.10 { return String(format: "%.2f trend over %d — focus on the soft game to reset.", delta, values.count) }
        return "Holding rating — push for tougher opponents to break through."
    }

    // MARK: - Form chart

    private var formChartCard: some View {
        let data = pickleVM.formData
        return VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "05 — Form",
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
                kicker: "06 — Recent",
                title: "Match Log",
                accent: accentColor,
                trailing: AnyView(
                    Text("\(pickleVM.matches.count) TOTAL")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textSecondary)
                )
            )

            if pickleVM.matches.isEmpty {
                editorialEmpty(icon: "figure.pickleball", message: "No matches yet — your first log starts the story.")
            } else {
                VStack(spacing: 10) {
                    ForEach(pickleVM.matches.prefix(5)) { match in
                        Button {
                            pickleVM.selectedMatch = match
                            pickleVM.showMatchDetail = true
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

    private func recentMatchRow(_ match: PickleballMatch) -> some View {
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
                    if !match.games.isEmpty {
                        Text("\(match.gamesWon)-\(match.gamesLost)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(match.result?.color ?? PepTheme.textSecondary)
                    }
                }
                HStack(spacing: 6) {
                    Text(match.format.shortName.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1.0)
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(accentColor.opacity(0.12))
                        .clipShape(Capsule())
                    Text(match.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.system(size: 10, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                if match.stats.winners > 0 {
                    statChip(text: "\(match.stats.winners)W", color: accentColor)
                }
                if match.stats.aces > 0 {
                    statChip(text: "\(match.stats.aces) ACE", color: PepTheme.amber)
                }
                if match.stats.winners == 0 && match.stats.aces == 0 {
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

    // MARK: - Partners

    @ViewBuilder
    private var partnersCard: some View {
        let partners = pickleVM.partners
        if !partners.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                EditorialSectionHeading(
                    kicker: "07 — Crew",
                    title: "Partners",
                    accent: PepTheme.amber,
                    trailing: AnyView(
                        Text("\(partners.count) PARTNERS")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(PepTheme.textSecondary)
                    )
                )

                VStack(spacing: 10) {
                    ForEach(partners.prefix(5), id: \.name) { record in
                        partnerRow(record)
                    }
                }
            }
            .editorialCard(accent: PepTheme.amber)
        }
    }

    private func partnerRow(_ record: (name: String, sessions: Int, wins: Int)) -> some View {
        let winRate = record.sessions > 0 ? Double(record.wins) / Double(record.sessions) : 0
        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(PepTheme.amber.opacity(0.14))
                    .frame(width: 32, height: 32)
                Text(String(record.name.prefix(1)))
                    .font(.system(size: 14, weight: .bold, design: .serif))
                    .foregroundStyle(PepTheme.amber)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(record.name)
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("\(record.sessions) session\(record.sessions == 1 ? "" : "s")")
                    .font(.system(size: 10, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()
            Text(String(format: "%.0f%%", winRate * 100))
                .font(.system(size: 13, weight: .bold, design: .serif))
                .foregroundStyle(winRate >= 0.5 ? .green : .orange)
        }
    }

    // MARK: - Rivals

    @ViewBuilder
    private var rivalsCard: some View {
        let records = pickleVM.rivals
        if !records.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                EditorialSectionHeading(
                    kicker: "08 — Rivalries",
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
                        rivalRow(record)
                    }
                }
            }
            .editorialCard(accent: PepTheme.violet)
        }
    }

    private func rivalRow(_ record: (opponent: String, wins: Int, losses: Int)) -> some View {
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

    // MARK: - Builder + library + settings

    private var workoutBuilderCard: some View {
        Button {
            pickleVM.showWorkoutBuilder = true
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
                    Text("\(pickleVM.savedSessions.count) saved · stack drills into a session")
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
            pickleVM.showDrillLibrary = true
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
                    Text("\(PickleballDrillLibrary.all.count) drills · \(PickleballDrillCategory.allCases.count) categories · tap any drill for the breakdown")
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
            pickleVM.showSettings = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                Text("PICKLEBALL SETTINGS")
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
