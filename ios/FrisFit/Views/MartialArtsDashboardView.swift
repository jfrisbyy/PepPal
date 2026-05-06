import SwiftUI

struct MartialArtsDashboardView: View {
    @Bindable var maVM: MartialArtsViewModel
    let accentColor: Color

    var body: some View {
        VStack(spacing: 18) {
            heroCard
            primaryActionRow
            disciplinePicker
            streakCard
            outputCard
            grappleCard
            strikingCard
            formChartCard
            recentSessionsCard
            partnersCard
            disciplineMixCard
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
                    Text("MARTIAL ARTS")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.0)
                        .foregroundStyle(accentColor.opacity(0.95))
                    Spacer()
                    if maVM.currentStreak > 0 {
                        Text("\(maVM.currentStreak)-DAY STREAK")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(PepTheme.amber)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(PepTheme.amber.opacity(0.12))
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
                    heroStat(value: "\(maVM.thisWeekSessions.count)", label: "THIS WEEK")
                    statDivider
                    heroStat(value: "\(maVM.totalSessions)", label: "SESSIONS")
                    statDivider
                    heroStat(value: matTimeDisplay, label: "MAT TIME")
                    statDivider
                    heroStat(value: "\(maVM.totalRoundsLogged)", label: "ROUNDS")
                }
            }
        }
    }

    private var matTimeDisplay: String {
        let minutes = maVM.totalMatTime
        if minutes >= 60 {
            return "\(minutes / 60)h"
        }
        return "\(minutes)m"
    }

    private var heroTitle: String {
        let count = maVM.thisWeekSessions.count
        if count == 0 { return "The mat is calling." }
        if count >= 5 { return "Living on the mat." }
        if maVM.currentStreak >= 5 { return "Showing up daily." }
        if let recent = maVM.sessions.first, recent.sessionType.isLive { return "Sharpened in live rounds." }
        return "The work is showing."
    }

    private var heroLine: String {
        let count = maVM.thisWeekSessions.count
        if count == 0 {
            return "Quiet week — even one drilling session resets the technique."
        }
        if maVM.takedownPercentage >= 0.6 && maVM.totalTakedownsAttempted >= 5 {
            return String(format: "Takedowns landing %.0f%% — the entries are dialed.", maVM.takedownPercentage * 100)
        }
        if maVM.subRatio >= 1.5 {
            return String(format: "%.1fx more subs landed than received — your guard is hunting.", maVM.subRatio)
        }
        if maVM.competitionWins > 0 {
            return "\(maVM.competitionWins) competition win\(maVM.competitionWins == 1 ? "" : "s") on record. Keep the rounds honest."
        }
        return "\(count) session\(count == 1 ? "" : "s") logged — sharpen the small details."
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
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Primary action

    private var primaryActionRow: some View {
        EditorialPrimaryButton(
            "Log a Session",
            icon: "figure.martial.arts",
            accent: accentColor
        ) {
            maVM.logDiscipline = maVM.primaryDiscipline
            maVM.showSessionLog = true
        }
    }

    // MARK: - Discipline picker

    private var disciplinePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(
                kicker: "01 — Discipline",
                title: "Your Style",
                accent: accentColor,
                trailing: AnyView(
                    Text("\(maVM.trainedDisciplines.count) TRAINED")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(accentColor)
                )
            )

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(MartialArtsDiscipline.allCases) { discipline in
                        let isSelected = maVM.primaryDiscipline == discipline
                        let isTrained = maVM.trainedDisciplines.contains(discipline)
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                maVM.primaryDiscipline = discipline
                                maVM.logDiscipline = discipline
                                maVM.trainedDisciplines.insert(discipline)
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: discipline.icon)
                                    .font(.system(size: 16))
                                Text(discipline.rawValue)
                                    .font(.system(size: 9, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .foregroundStyle(isSelected ? .black : (isTrained ? discipline.color : PepTheme.textSecondary))
                            .frame(width: 88)
                            .padding(.vertical, 12)
                            .background(isSelected ? discipline.color : (isTrained ? discipline.color.opacity(0.14) : PepTheme.elevated.opacity(0.4)))
                            .clipShape(.rect(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(isSelected ? Color.clear : discipline.color.opacity(isTrained ? 0.32 : 0.0), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)

            Text(maVM.primaryDiscipline.tagline)
                .font(.system(size: 12, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
        }
        .editorialCard(accent: accentColor)
    }

    // MARK: - Streak / heatmap

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "02 — Streak",
                title: "Mat Time",
                accent: PepTheme.amber,
                trailing: AnyView(
                    Text("12 WEEKS")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textSecondary)
                )
            )

            let weeks = maVM.twelveWeekHeatmap
            HStack(alignment: .top, spacing: 4) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: 4) {
                        ForEach(Array(week.enumerated()), id: \.offset) { _, count in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(heatColor(for: count))
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 12) {
                Text("LESS")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                ForEach(0..<5, id: \.self) { idx in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(heatColor(for: idx))
                        .frame(width: 12, height: 12)
                }
                Text("MORE")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                Spacer()
                Text(streakInsight)
                    .font(.system(size: 11, design: .serif))
                    .italic()
                    .foregroundStyle(accentColor)
            }
        }
        .editorialCard(accent: PepTheme.amber)
    }

    private func heatColor(for count: Int) -> Color {
        switch count {
        case 0: PepTheme.elevated.opacity(0.45)
        case 1: accentColor.opacity(0.30)
        case 2: accentColor.opacity(0.55)
        case 3: accentColor.opacity(0.80)
        default: accentColor
        }
    }

    private var streakInsight: String {
        let streak = maVM.currentStreak
        if streak == 0 { return "Today is the day." }
        if streak == 1 { return "Day one — own it." }
        if streak >= 7 { return "\(streak) days straight." }
        return "\(streak) days running."
    }

    // MARK: - Output card (live rounds + competitions)

    private var outputCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "03 — Output",
                title: "Live & Competition",
                accent: accentColor,
                trailing: maVM.competitions.count > 0 ? AnyView(
                    Text(String(format: "%.0f%% WIN", maVM.winPercentage))
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(maVM.winPercentage >= 50 ? .green : .orange)
                ) : nil
            )

            if maVM.totalLiveSessions == 0 && maVM.competitions.isEmpty {
                editorialEmpty(icon: "figure.boxing", message: "Log sparring, rolling, or competition to see your output.")
            } else {
                HStack(spacing: 10) {
                    ringStat(
                        label: "LIVE",
                        value: min(Double(maVM.totalLiveSessions) * 8, 100),
                        displayValue: "\(maVM.totalLiveSessions)",
                        color: accentColor
                    )
                    ringStat(
                        label: "COMP",
                        value: min(Double(maVM.competitions.count) * 20, 100),
                        displayValue: "\(maVM.competitionWins)–\(maVM.competitionLosses)",
                        color: PepTheme.amber
                    )
                    ringStat(
                        label: "ROUNDS",
                        value: min(Double(maVM.totalRoundsLogged) * 2.5, 100),
                        displayValue: "\(maVM.totalRoundsLogged)",
                        color: PepTheme.violet
                    )
                }

                Text(outputInsight)
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .editorialCard(accent: accentColor)
    }

    private var outputInsight: String {
        if maVM.totalLiveSessions == 0 { return "Drilling builds the swing — live rounds prove it works." }
        if maVM.competitionWins >= 3 { return "Multiple competition wins on record — your game travels." }
        if maVM.totalLiveSessions >= 8 { return "Live reps stacking — confidence comes from the mat, not the mirror." }
        return "Mix in another live round soon — pressure-test what you're drilling."
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
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 4)
            }
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Grapple card

    @ViewBuilder
    private var grappleCard: some View {
        let hasGrappling = maVM.totalTakedownsAttempted > 0 || maVM.totalSubmissionsLanded > 0 || maVM.totalSubsReceived > 0
        if hasGrappling {
            VStack(alignment: .leading, spacing: 14) {
                EditorialSectionHeading(
                    kicker: "04 — Grappling",
                    title: "Mat Game",
                    accent: PepTheme.violet,
                    trailing: AnyView(
                        Text(String(format: "%.0f%% TD", maVM.takedownPercentage * 100))
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(PepTheme.violet)
                    )
                )

                HStack(spacing: 0) {
                    columnStat(value: "\(maVM.totalSubmissionsLanded)", label: "SUBS", color: .green)
                    statDivider
                    columnStat(value: "\(maVM.totalSubsReceived)", label: "TAPS", color: .red)
                    statDivider
                    columnStat(
                        value: String(format: "%.1f", maVM.subRatio),
                        label: "RATIO",
                        color: maVM.subRatio >= 1.0 ? .green : PepTheme.amber
                    )
                    statDivider
                    columnStat(
                        value: "\(maVM.totalTakedownsLanded)/\(maVM.totalTakedownsAttempted)",
                        label: "TAKEDOWNS",
                        color: PepTheme.violet
                    )
                }

                Text(grappleInsight)
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .editorialCard(accent: PepTheme.violet)
        }
    }

    private var grappleInsight: String {
        if maVM.subRatio >= 2.0 { return "Subs landing 2x more than taps received — the offense is real." }
        if maVM.subRatio >= 1.0 { return "Net positive on submissions — keep hunting from your A-position." }
        if maVM.totalSubsReceived > maVM.totalSubmissionsLanded {
            return "Tapping more than tapping — drill defense from your worst position."
        }
        return "Track the ratio — submissions tell the truth about your game."
    }

    private func columnStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }

    // MARK: - Striking card

    @ViewBuilder
    private var strikingCard: some View {
        if maVM.totalStrikes > 0 {
            VStack(alignment: .leading, spacing: 14) {
                EditorialSectionHeading(
                    kicker: "05 — Striking",
                    title: "Output",
                    accent: PepTheme.amber,
                    trailing: AnyView(
                        Text(String(format: "%.0f / SESSION", maVM.averageStrikesPerSession))
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(PepTheme.amber)
                    )
                )

                let totals = strikingTotals
                VStack(spacing: 8) {
                    strikeBar(label: "Punches", value: totals.punches, max: totals.max, color: PepTheme.amber)
                    strikeBar(label: "Kicks", value: totals.kicks, max: totals.max, color: accentColor)
                    strikeBar(label: "Knees / Elbows", value: totals.others, max: totals.max, color: PepTheme.violet)
                }

                Text(strikeInsight(totals))
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .editorialCard(accent: PepTheme.amber)
        }
    }

    private var strikingTotals: (punches: Int, kicks: Int, others: Int, max: Int) {
        var punches = 0
        var kicks = 0
        var others = 0
        for s in maVM.sessions {
            punches += s.stats.jabs + s.stats.crosses + s.stats.hooks + s.stats.uppercuts
            kicks += s.stats.lowKicks + s.stats.bodyKicks + s.stats.headKicks
            others += s.stats.knees + s.stats.elbows
        }
        let m = max(punches, max(kicks, max(others, 1)))
        return (punches, kicks, others, m)
    }

    private func strikeBar(label: String, value: Int, max: Int, color: Color) -> some View {
        HStack(spacing: 10) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
                .frame(width: 110, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(PepTheme.elevated.opacity(0.5))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [color, color.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(Double(value) / Double(Swift.max(max, 1))), height: 10)
                }
            }
            .frame(height: 10)
            Text("\(value)")
                .font(.system(size: 12, weight: .bold, design: .serif))
                .foregroundStyle(color)
                .frame(width: 40, alignment: .trailing)
        }
    }

    private func strikeInsight(_ totals: (punches: Int, kicks: Int, others: Int, max: Int)) -> String {
        let total = totals.punches + totals.kicks + totals.others
        guard total > 0 else { return "Track strikes by type to see your habits." }
        let punchPct = Double(totals.punches) / Double(total)
        if punchPct > 0.75 { return "Heavy on hands — start mixing in kicks to open the canvas." }
        if punchPct < 0.35 { return "Kick-heavy striker — but don't forget to set it up with a jab." }
        return "Balanced output — punches set up kicks, kicks set up entries."
    }

    // MARK: - Form chart

    private var formChartCard: some View {
        let data = maVM.formData
        return VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "06 — Form",
                title: "Last \(data.count > 0 ? "\(data.count) " : "")Sessions",
                accent: accentColor,
                trailing: data.count >= 2 ? AnyView(
                    Text(String(format: "%.1f AVG", data.reduce(0.0) { $0 + Double($1.rating) } / Double(data.count)))
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.amber)
                ) : nil
            )

            if data.count < 2 {
                editorialEmpty(icon: "chart.line.uptrend.xyaxis", message: "Need 2+ sessions to chart form.")
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
        if recent < prior - 1 { return "Dip in form — listen to the body, plan a deload week." }
        return "Steady — consistency over peaks."
    }

    // MARK: - Recent sessions

    private var recentSessionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "07 — Recent",
                title: "Session Log",
                accent: accentColor,
                trailing: AnyView(
                    Text("\(maVM.sessions.count) TOTAL")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textSecondary)
                )
            )

            if maVM.sessions.isEmpty {
                editorialEmpty(icon: "figure.martial.arts", message: "No sessions yet — your first log starts the story.")
            } else {
                VStack(spacing: 10) {
                    ForEach(maVM.sessions.prefix(5)) { session in
                        Button {
                            maVM.selectedSession = session
                            maVM.showSessionDetail = true
                        } label: {
                            recentSessionRow(session)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .editorialCard(accent: accentColor)
    }

    private func recentSessionRow(_ session: MartialArtsSession) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(session.discipline.color.opacity(0.16))
                    .frame(width: 44, height: 44)
                Image(systemName: session.sessionType.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(session.discipline.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(session.discipline.rawValue)
                        .font(.system(size: 13, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(1)
                    if let outcome = session.outcome {
                        Text(outcome.rawValue)
                            .font(.system(size: 10, weight: .black, design: .serif))
                            .foregroundStyle(outcome.color)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(outcome.color.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                HStack(spacing: 6) {
                    Text(session.sessionType.rawValue.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1.0)
                        .foregroundStyle(session.discipline.color)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(session.discipline.color.opacity(0.12))
                        .clipShape(Capsule())
                    Text(session.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.system(size: 10, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }

            Spacer()

            Text("\(session.durationMinutes)m")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(PepTheme.textSecondary)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
        }
        .padding(.vertical, 4)
    }

    // MARK: - Partners

    @ViewBuilder
    private var partnersCard: some View {
        let partners = maVM.trainingPartners
        if !partners.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                EditorialSectionHeading(
                    kicker: "08 — Crew",
                    title: "Training Partners",
                    accent: PepTheme.amber,
                    trailing: AnyView(
                        Text("\(partners.count) TRACKED")
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

    private func partnerRow(_ record: (name: String, sessions: Int)) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(PepTheme.amber.opacity(0.14))
                    .frame(width: 32, height: 32)
                Text(String(record.name.prefix(1)))
                    .font(.system(size: 14, weight: .bold, design: .serif))
                    .foregroundStyle(PepTheme.amber)
            }
            Text(record.name)
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
            Spacer()
            Text("\(record.sessions) session\(record.sessions == 1 ? "" : "s")")
                .font(.system(size: 11, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
        }
    }

    // MARK: - Discipline mix

    @ViewBuilder
    private var disciplineMixCard: some View {
        let breakdown = maVM.disciplineBreakdown
        if breakdown.count >= 2 {
            VStack(alignment: .leading, spacing: 14) {
                EditorialSectionHeading(
                    kicker: "09 — Mix",
                    title: "Discipline Split",
                    accent: PepTheme.violet,
                    trailing: AnyView(
                        Text("\(breakdown.count) STYLES")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(PepTheme.textSecondary)
                    )
                )

                let totalMinutes = max(breakdown.reduce(0) { $0 + $1.minutes }, 1)

                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(breakdown, id: \.discipline) { entry in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(entry.discipline.color)
                                .frame(width: geo.size.width * CGFloat(entry.minutes) / CGFloat(totalMinutes))
                        }
                    }
                }
                .frame(height: 10)

                VStack(spacing: 8) {
                    ForEach(breakdown, id: \.discipline) { entry in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(entry.discipline.color)
                                .frame(width: 8, height: 8)
                            Text(entry.discipline.rawValue)
                                .font(.system(size: 12, weight: .semibold, design: .serif))
                                .foregroundStyle(PepTheme.textPrimary)
                            Spacer()
                            Text("\(entry.sessions) · \(entry.minutes)m")
                                .font(.system(size: 11, design: .serif))
                                .italic()
                                .foregroundStyle(PepTheme.textSecondary)
                            Text(String(format: "%.0f%%", Double(entry.minutes) / Double(totalMinutes) * 100))
                                .font(.system(size: 11, weight: .bold, design: .serif))
                                .foregroundStyle(entry.discipline.color)
                                .frame(width: 42, alignment: .trailing)
                        }
                    }
                }
            }
            .editorialCard(accent: PepTheme.violet)
        }
    }

    // MARK: - Builder + library + settings

    private var workoutBuilderCard: some View {
        Button {
            maVM.showWorkoutBuilder = true
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
                    Text("\(maVM.savedSessions.count) saved · stack drills into a session")
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
            maVM.showDrillLibrary = true
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
                    Text("\(MartialArtsDrillLibrary.all.count) drills · \(MartialArtsDiscipline.allCases.count) disciplines · tap any drill for the breakdown")
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
            maVM.showSettings = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                Text("MARTIAL ARTS SETTINGS")
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
