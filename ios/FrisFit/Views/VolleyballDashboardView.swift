import SwiftUI

struct VolleyballDashboardView: View {
    @Bindable var volleyballVM: VolleyballViewModel
    let accentColor: Color

    var body: some View {
        VStack(spacing: 18) {
            heroCard
            primaryActionRow
            sessionTypePicker
            attackCard
            servePassCard
            defenseCard
            formChartCard
            recentMatchesCard
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
                    Text("VOLLEYBALL")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.0)
                        .foregroundStyle(accentColor.opacity(0.9))
                    Spacer()
                    if volleyballVM.totalMatchesPlayed > 0 {
                        Text(String(format: "%.0f%% WIN", volleyballVM.winPercentage))
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(volleyballVM.winPercentage >= 50 ? .green : .orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background((volleyballVM.winPercentage >= 50 ? Color.green : Color.orange).opacity(0.12))
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
                    heroStat(value: "\(volleyballVM.thisWeekSessions)", label: "THIS WEEK")
                    statDivider
                    heroStat(value: "\(volleyballVM.totalKills)", label: "KILLS")
                    statDivider
                    heroStat(value: String(format: "%.1f", volleyballVM.averageKillsPerMatch), label: "K/M")
                    statDivider
                    heroStat(value: "\(volleyballVM.totalMatchesPlayed)", label: "MATCHES")
                }
            }
        }
    }

    private var heroTitle: String {
        let sessions = volleyballVM.thisWeekSessions
        if sessions == 0 { return "Lace up the kneepads." }
        if let recent = volleyballVM.matches.first, recent.result == .win { return "Riding the swing." }
        if volleyballVM.thisWeekMatches.contains(where: { $0.result == .win }) { return "Stacking wins." }
        if sessions >= 3 { return "On the floor." }
        return "Find your tempo."
    }

    private var heroLine: String {
        let sessions = volleyballVM.thisWeekSessions
        if sessions == 0 {
            return "Quiet week — even a 30-minute serve-and-pass session keeps the touch alive."
        }
        if volleyballVM.averageHittingPercentage >= 0.300 {
            return String(format: "Hitting +%.3f across recent matches — premium swing percentage.", volleyballVM.averageHittingPercentage)
        }
        if volleyballVM.totalMatchesPlayed >= 2 && volleyballVM.averageHittingPercentage > 0 && volleyballVM.averageHittingPercentage < 0.150 {
            return "Hit % dipping — a focused hitting block could move the dial fast."
        }
        let matches = volleyballVM.thisWeekMatches.filter { $0.sessionType.isMatch }.count
        if matches >= 2 {
            return "\(matches) matches in the week — show the legs you trained."
        }
        return "\(sessions) session\(sessions == 1 ? "" : "s") logged — keep the swings sharp."
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
            volleyballVM.selectedSessionType.isMatch ? "Log a Match" : "Log a Session",
            icon: "figure.volleyball",
            accent: accentColor
        ) {
            volleyballVM.showMatchLog = true
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
                    Text(volleyballVM.selectedSessionType.rawValue.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(accentColor)
                )
            )

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(VolleyballSessionType.allCases) { type in
                        Button {
                            volleyballVM.selectedSessionType = type
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 14))
                                Text(type.rawValue)
                                    .font(.system(size: 9, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .foregroundStyle(volleyballVM.selectedSessionType == type ? .black : PepTheme.textSecondary)
                            .frame(width: 78)
                            .padding(.vertical, 10)
                            .background(volleyballVM.selectedSessionType == type ? accentColor : PepTheme.elevated.opacity(0.5))
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

    // MARK: - Attack card

    private var attackCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "02 — Attack",
                title: "Swing Profile",
                accent: accentColor,
                trailing: volleyballVM.totalMatchesPlayed > 0 ? AnyView(
                    Text(String(format: "%+.3f HIT", volleyballVM.averageHittingPercentage))
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(accentColor)
                ) : nil
            )

            if volleyballVM.totalMatchesPlayed == 0 {
                editorialEmpty(icon: "bolt.fill", message: "Log a match to surface your hitting picture.")
            } else {
                HStack(spacing: 10) {
                    ringStat(label: "K/M", value: min(volleyballVM.averageKillsPerMatch * 8, 100), displayValue: String(format: "%.1f", volleyballVM.averageKillsPerMatch), color: accentColor)
                    ringStat(label: "Hit%", value: max(0, min((volleyballVM.averageHittingPercentage + 0.2) * 200, 100)), displayValue: String(format: "%+.2f", volleyballVM.averageHittingPercentage), color: .green)
                    ringStat(label: "Kills", value: min(Double(volleyballVM.totalKills) / 2, 100), displayValue: "\(volleyballVM.totalKills)", color: PepTheme.amber)
                }

                Text(attackInsight)
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .editorialCard(accent: accentColor)
    }

    private var attackInsight: String {
        let hit = volleyballVM.averageHittingPercentage
        if hit == 0 { return "Track attempts and kills to get a hitting trend." }
        if hit >= 0.300 { return "Premium hitting — keep selling the cross-court line." }
        if hit >= 0.200 { return "Strong swing percentage — push for one more high-ball kill per set." }
        if hit >= 0.100 { return "Holding ground — clean up tooled blocks and out-of-system swings." }
        return "Hit% under .100 — slow the approach, find the shot before the swing."
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

    // MARK: - Serve & pass card

    private var servePassCard: some View {
        let aces = volleyballVM.totalAces
        let avgAces = volleyballVM.totalMatchesPlayed > 0 ? Double(aces) / Double(volleyballVM.totalMatchesPlayed) : 0
        let pass = volleyballVM.averagePassingRating
        return VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "03 — Serve & Pass",
                title: "Backline",
                accent: PepTheme.amber,
                trailing: volleyballVM.totalMatchesPlayed > 0 ? AnyView(
                    Text(String(format: "%.1f ACES/M", avgAces))
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.amber)
                ) : nil
            )

            if volleyballVM.totalMatchesPlayed == 0 {
                editorialEmpty(icon: "scope", message: "Log serve and pass attempts to see the breakdown.")
            } else {
                HStack(spacing: 0) {
                    columnStat(value: "\(aces)", label: "ACES", color: PepTheme.amber)
                    statDivider
                    columnStat(value: String(format: "%.2f", pass), label: "PASS", color: pass >= 2.0 ? .green : (pass >= 1.5 ? .orange : .red))
                    statDivider
                    columnStat(value: String(format: "%.1f", avgAces), label: "ACES/M", color: accentColor)
                }

                Text(serveInsight(avgAces: avgAces, pass: pass))
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .editorialCard(accent: PepTheme.amber)
    }

    private func serveInsight(avgAces: Double, pass: Double) -> String {
        if pass >= 2.3 { return "Pass rating elite — you're feeding the setter perfectly." }
        if avgAces >= 3 { return "Servers eating — keep stacking pressure points." }
        if pass > 0 && pass < 1.5 { return "Pass rating low — slow down and platform first." }
        return "Backline consistent — small gains compound over a season."
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

    // MARK: - Defense card

    private var defenseCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "04 — Defense",
                title: "Block & Dig",
                accent: PepTheme.violet
            )

            if volleyballVM.totalMatchesPlayed == 0 {
                editorialEmpty(icon: "shield.lefthalf.filled", message: "Track blocks and digs to surface your defensive picture.")
            } else {
                HStack(spacing: 10) {
                    smallStat(label: "Blocks/M", value: String(format: "%.1f", volleyballVM.averageBlocksPerMatch), color: PepTheme.violet)
                    smallStat(label: "Digs/M", value: String(format: "%.1f", volleyballVM.averageDigsPerMatch), color: .blue)
                    smallStat(label: "Total Stops", value: "\(volleyballVM.totalBlocks + volleyballVM.totalDigs)", color: .green)
                }
            }
        }
        .editorialCard(accent: PepTheme.violet)
    }

    private func smallStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
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
        .padding(.vertical, 14)
        .background(color.opacity(0.10))
        .clipShape(.rect(cornerRadius: 12))
    }

    // MARK: - Form chart

    private var formChartCard: some View {
        let data = volleyballVM.formData
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
                    Text("\(volleyballVM.matches.count) TOTAL")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textSecondary)
                )
            )

            if volleyballVM.matches.isEmpty {
                editorialEmpty(icon: "figure.volleyball", message: "No matches yet — your first log starts the story.")
            } else {
                VStack(spacing: 10) {
                    ForEach(volleyballVM.matches.prefix(5)) { match in
                        Button {
                            volleyballVM.selectedMatch = match
                            volleyballVM.showMatchDetail = true
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

    private func recentMatchRow(_ match: VolleyballMatch) -> some View {
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
                        Text("\(match.setsWon)-\(match.setsLost)")
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

            HStack(spacing: 4) {
                if match.stats.kills > 0 {
                    statChip(text: "\(match.stats.kills)K", color: accentColor)
                }
                if match.stats.aces > 0 {
                    statChip(text: "\(match.stats.aces) ACE", color: PepTheme.amber)
                }
                if match.stats.kills == 0 && match.stats.aces == 0 {
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

    // MARK: - Rivals

    @ViewBuilder
    private var rivalsCard: some View {
        let records = volleyballVM.rivals
        if !records.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                EditorialSectionHeading(
                    kicker: "07 — Rivalries",
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
            volleyballVM.showWorkoutBuilder = true
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
                    Text("\(volleyballVM.savedSessions.count) saved · stack drills into a session")
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
            volleyballVM.showDrillLibrary = true
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
                    Text("\(VolleyballDrillLibrary.all.count) drills · \(VolleyballDrillCategory.allCases.count) categories · tap any drill for the breakdown")
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
            volleyballVM.showSettings = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                Text("VOLLEYBALL SETTINGS")
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
