import SwiftUI

struct BasketballDashboardView: View {
    @Bindable var bbVM: BasketballViewModel
    let accentColor: Color
    var firstName: String = ""

    var body: some View {
        VStack(spacing: 18) {
            heroCard
            primaryLogButton
            hoopStreakCard
            weeklyFocusCard
            goalsCard
            SportCoachCard(sport: .basketball, accent: accentColor)
            recentRunsCard
            drillProgressCard
            practicePlansCard
            settingsRow

            if bbVM.seriousMode {
                seriousModeSection
            }
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        PepSportCard(accent: accentColor) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("BASKETBALL")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.0)
                        .foregroundStyle(accentColor.opacity(0.9))
                    Spacer()
                    if bbVM.currentStreak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                            Text("\(bbVM.currentStreak) DAY")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.4)
                        }
                        .foregroundStyle(BasketballPalette.courtAmber)
                    }
                }

                Text(greetingTitle)
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .kerning(-0.5)
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(2)

                Text(bbVM.heroLine(firstName: firstName))
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
                    heroStat(value: "\(bbVM.thisWeekSessions)", label: "RUNS")
                    statDivider
                    heroStat(value: "\(bbVM.thisWeekMinutes)", label: "MIN")
                    statDivider
                    heroStat(value: "\(bbVM.currentStreak)", label: "STREAK")
                    statDivider
                    heroStat(value: "\(weekCalories)", label: "KCAL")
                }
            }
        }
    }

    private var greetingTitle: String {
        let name = firstName.trimmingCharacters(in: .whitespaces)
        if name.isEmpty { return "Welcome back." }
        return "Welcome back, \(name)."
    }

    private var weekCalories: Int {
        bbVM.thisWeekGames.reduce(0) { $0 + $1.caloriesBurned }
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
        EditorialPrimaryButton("Log a Run", icon: "basketball.fill", accent: accentColor) {
            bbVM.showRunLog = true
        }
    }

    // MARK: - Hoop Streak

    private var hoopStreakCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "01 — Hoop Streak",
                title: "Consistency",
                accent: accentColor,
                trailing: AnyView(
                    Text("\(bbVM.thisWeekSessions) THIS WEEK")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textSecondary)
                )
            )

            heatmapGrid
        }
        .editorialCard(accent: accentColor)
    }

    private var heatmapGrid: some View {
        let data = bbVM.heatmapData
        let cols = 12
        let rows = 7
        return VStack(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(0..<cols, id: \.self) { col in
                    VStack(spacing: 4) {
                        ForEach(0..<rows, id: \.self) { row in
                            let idx = col * rows + row
                            let count = idx < data.count ? data[idx].count : 0
                            RoundedRectangle(cornerRadius: 3)
                                .fill(heatColor(for: count))
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Text("12 WEEKS")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.3)
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                HStack(spacing: 4) {
                    ForEach(0..<4, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(heatColor(for: i))
                            .frame(width: 10, height: 10)
                    }
                }
                Text("MORE")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.3)
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
    }

    private func heatColor(for count: Int) -> Color {
        switch count {
        case 0: PepTheme.elevated.opacity(0.5)
        case 1: accentColor.opacity(0.35)
        case 2: accentColor.opacity(0.65)
        default: accentColor
        }
    }

    // MARK: - Weekly Focus

    private var weeklyFocusCard: some View {
        Button {
            bbVM.showWeeklyFocus = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                EditorialSectionHeading(
                    kicker: "02 — This Week",
                    title: "Focus",
                    accent: BasketballPalette.courtAmber
                )

                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(BasketballPalette.courtAmber.opacity(0.12))
                            .frame(width: 52, height: 52)
                        Image(systemName: bbVM.weeklyFocus.icon)
                            .font(.system(size: 22))
                            .foregroundStyle(BasketballPalette.courtAmber)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(bbVM.weeklyFocus.rawValue)
                            .font(.system(size: 17, weight: .semibold, design: .serif))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text(bbVM.weeklyFocus.blurb)
                            .font(.system(size: 11, design: .serif))
                            .italic()
                            .foregroundStyle(PepTheme.textSecondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            .editorialCard(accent: BasketballPalette.courtAmber)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Goals

    private var goalsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "03 — Personal",
                title: "Goals",
                accent: accentColor,
                trailing: AnyView(
                    Button {
                        bbVM.showGoalsEditor = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 10))
                            Text("EDIT")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.4)
                        }
                        .foregroundStyle(PepTheme.textSecondary)
                    }
                )
            )

            if bbVM.goals.isEmpty {
                Button {
                    bbVM.showGoalsEditor = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(accentColor)
                        Text("Set your first goal")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(bbVM.goals) { goal in
                        goalRing(goal)
                    }
                }
            }
        }
        .editorialCard(accent: accentColor)
    }

    private func goalRing(_ goal: BasketballGoal) -> some View {
        let progress = bbVM.progress(for: goal)
        let value = bbVM.currentValue(for: goal.type)
        let isHit = progress >= 1.0
        return VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(PepTheme.elevated, lineWidth: 6)
                    .frame(width: 64, height: 64)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(goal.type.color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.85), value: progress)
                Image(systemName: isHit ? "checkmark" : goal.type.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(goal.type.color)
            }
            VStack(spacing: 2) {
                Text("\(value) / \(goal.target)")
                    .font(.system(.subheadline, design: .serif, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .contentTransition(.numericText())
                Text(goal.type.rawValue.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.0)
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Recent Runs

    private var recentRunsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "04 — Recent",
                title: "Runs",
                accent: accentColor,
                trailing: AnyView(
                    Text("\(bbVM.games.count) TOTAL")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textSecondary)
                )
            )

            if bbVM.games.isEmpty {
                emptyRunsPlaceholder
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(bbVM.games.prefix(5).enumerated()), id: \.element.id) { idx, game in
                        Button {
                            bbVM.selectedGame = game
                            bbVM.showRunDetail = true
                        } label: {
                            recentRunRow(game)
                        }
                        .buttonStyle(.plain)
                        if idx < min(bbVM.games.count, 5) - 1 {
                            Rectangle()
                                .fill(PepTheme.glassBorderTop.opacity(0.5))
                                .frame(height: 0.5)
                        }
                    }
                }
            }
        }
        .editorialCard(accent: accentColor)
    }

    private var emptyRunsPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "basketball")
                .font(.system(size: 28))
                .foregroundStyle(accentColor.opacity(0.4))
            Text("No runs yet")
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
            Text("Log your first session and we'll start telling your hoop story.")
                .font(.system(size: 11, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    private func recentRunRow(_ game: BasketballGame) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: game.sessionType.icon)
                    .font(.system(size: 15))
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(game.sessionType.casualVerb)
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(1)
                    if !game.location.isEmpty {
                        Text("·")
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                        Text(game.location)
                            .font(.system(size: 11))
                            .foregroundStyle(PepTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
                HStack(spacing: 6) {
                    Text(relativeDate(game.date))
                    Text("·")
                    Text("\(game.durationMinutes)m")
                    if !game.partners.isEmpty {
                        Text("·")
                        HStack(spacing: 2) {
                            Image(systemName: "person.2.fill").font(.system(size: 8))
                            Text("\(game.partners.count)")
                        }
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                vibeChip(game.vibeRating)
                Text("\(game.caloriesBurned) kcal")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
        }
        .padding(.vertical, 10)
    }

    private func vibeChip(_ rating: Int) -> some View {
        let color: Color = rating >= 8 ? .green : rating >= 5 ? BasketballPalette.courtAmber : .orange
        let label: String = rating >= 8 ? "Felt great" : rating >= 5 ? "Solid" : "Off day"
        return Text(label.uppercased())
            .font(.system(size: 8, weight: .bold))
            .tracking(1.0)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Drill Progress

    private var drillProgressCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "05 — Mastery",
                title: "Drill Progress",
                accent: accentColor,
                trailing: AnyView(
                    Button {
                        bbVM.showDrillLibrary = true
                    } label: {
                        Text("ALL")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                )
            )

            let touched = bbVM.drillsTouched
            if touched.isEmpty {
                Button {
                    bbVM.showDrillLibrary = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "figure.basketball")
                            .font(.system(size: 14))
                            .foregroundStyle(accentColor)
                        Text("Try a drill from the library")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(accentColor)
                    }
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(touched.prefix(8), id: \.drill.slug) { item in
                            drillProgressTile(drill: item.drill, count: item.count)
                        }
                    }
                }
                .contentMargins(.horizontal, 0)
                .scrollIndicators(.hidden)
            }
        }
        .editorialCard(accent: accentColor)
    }

    private func drillProgressTile(drill: BasketballDrill, count: Int) -> some View {
        let mastery = DrillMastery.forSessionCount(count)
        return Button {
            bbVM.selectedDrill = drill
            bbVM.showDrillDetail = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: drill.category.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(drill.category.color)
                    Spacer()
                    Text(mastery.rawValue.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1.0)
                        .foregroundStyle(mastery.color)
                }
                Text(drill.name)
                    .font(.system(size: 12, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                masteryBar(mastery: mastery)
                Text("\(count) session\(count == 1 ? "" : "s")")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(12)
            .frame(width: 130, height: 130, alignment: .topLeading)
            .background(PepTheme.elevated.opacity(0.5))
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(mastery.color.opacity(0.25), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func masteryBar(mastery: DrillMastery) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(PepTheme.elevated)
                Capsule()
                    .fill(mastery.color)
                    .frame(width: geo.size.width * mastery.progress)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Practice Plans

    private var practicePlansCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "06 — Practice",
                title: "Plans & Templates",
                accent: accentColor,
                trailing: AnyView(
                    Button {
                        bbVM.showPracticePlanBuilder = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(accentColor)
                    }
                )
            )

            if !bbVM.practicePlans.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(bbVM.practicePlans.prefix(3).enumerated()), id: \.element.id) { idx, plan in
                        Button {
                            bbVM.runningPlan = plan
                        } label: {
                            planRow(plan, isTemplate: false)
                        }
                        .buttonStyle(.plain)
                        if idx < min(bbVM.practicePlans.count, 3) - 1 {
                            Rectangle().fill(PepTheme.glassBorderTop.opacity(0.5)).frame(height: 0.5)
                        }
                    }
                }
                Rectangle().fill(PepTheme.glassBorderTop.opacity(0.5)).frame(height: 0.5)
                    .padding(.vertical, 4)
            }

            Text("FEATURED TEMPLATES")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(PepTheme.textSecondary)

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(BasketballPlanTemplates.all) { template in
                        templateTile(template)
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)
        }
        .editorialCard(accent: accentColor)
    }

    private func planRow(_ plan: PracticePlan, isTemplate: Bool) -> some View {
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
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("\(plan.drills.count) drills · \(plan.totalDuration) min")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            Image(systemName: "play.circle.fill")
                .font(.title3)
                .foregroundStyle(accentColor)
        }
        .padding(.vertical, 10)
    }

    private func templateTile(_ template: PracticePlan) -> some View {
        Button {
            bbVM.runningPlan = template
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "list.clipboard.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(accentColor)
                    Spacer()
                    Text("\(template.totalDuration)m")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Text(template.name)
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)
                Text(template.templateBlurb)
                    .font(.system(size: 10, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Text("\(template.drills.count) DRILLS")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(accentColor)
            }
            .padding(12)
            .frame(width: 180, height: 130, alignment: .topLeading)
            .background(PepTheme.elevated.opacity(0.5))
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(accentColor.opacity(0.25), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Settings row

    private var settingsRow: some View {
        Button {
            bbVM.showSettings = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 12))
                    .foregroundStyle(PepTheme.textSecondary)
                Text("Basketball Settings")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                if bbVM.seriousMode {
                    Text("· SERIOUS MODE")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(accentColor)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Serious mode (only shown when toggle on)

    private var seriousModeSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("SERIOUS MODE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.8)
                    .foregroundStyle(accentColor)
                Rectangle()
                    .fill(LinearGradient(colors: [accentColor.opacity(0.4), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 0.5)
            }
            .padding(.top, 8)

            shootingSplitsCard
            seasonAveragesCard
            shotChartPreviewCard
            pointsTrendCard
            confidenceInsightCard

            Button {
                bbVM.showGameLog = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet.clipboard.fill")
                    Text("Full Box Score Logger")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(accentColor.opacity(0.1))
                .clipShape(.rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(accentColor.opacity(0.25), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var shootingSplitsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Shooting", title: "Splits", accent: accentColor)
            if bbVM.totalGamesPlayed == 0 {
                noDataPlaceholder("Log box scores to see your splits")
            } else {
                HStack(spacing: 8) {
                    shootingRing(label: "FG%", value: bbVM.overallFGPercentage, color: accentColor)
                    shootingRing(label: "3PT%", value: bbVM.overall3PTPercentage, color: .green)
                    shootingRing(label: "FT%", value: bbVM.overallFTPercentage, color: BasketballPalette.courtAmber)
                }
            }
        }
        .editorialCard(accent: accentColor)
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

    private var seasonAveragesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(
                kicker: "Season",
                title: "Averages",
                accent: BasketballPalette.courtAmber,
                trailing: AnyView(
                    Text("\(bbVM.totalGamesPlayed) GAMES")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textSecondary)
                )
            )

            if bbVM.totalGamesPlayed == 0 {
                noDataPlaceholder("Play games to see averages")
            } else {
                let games = bbVM.games.filter { $0.sessionType.isGame }
                let avgSteals = games.isEmpty ? 0 : Double(games.reduce(0) { $0 + $1.stats.steals }) / Double(games.count)
                let avgBlocks = games.isEmpty ? 0 : Double(games.reduce(0) { $0 + $1.stats.blocks }) / Double(games.count)
                let avgTO = games.isEmpty ? 0 : Double(games.reduce(0) { $0 + $1.stats.turnovers }) / Double(games.count)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    avgStatCell(value: String(format: "%.1f", bbVM.averagePoints), label: "PTS", color: accentColor)
                    avgStatCell(value: String(format: "%.1f", bbVM.averageRebounds), label: "REB", color: .green)
                    avgStatCell(value: String(format: "%.1f", bbVM.averageAssists), label: "AST", color: .blue)
                    avgStatCell(value: String(format: "%.1f", avgSteals), label: "STL", color: BasketballPalette.courtAmber)
                    avgStatCell(value: String(format: "%.1f", avgBlocks), label: "BLK", color: .red)
                    avgStatCell(value: String(format: "%.1f", avgTO), label: "TO", color: PepTheme.textSecondary)
                }
            }
        }
        .editorialCard(accent: BasketballPalette.courtAmber)
    }

    private func avgStatCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(.title3, design: .serif, weight: .semibold))
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

    private var shotChartPreviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(
                kicker: "Map",
                title: "Shot Chart",
                accent: accentColor,
                trailing: AnyView(
                    Button {
                        bbVM.showShotChart = true
                    } label: {
                        Text("OPEN")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(accentColor)
                    }
                )
            )

            if bbVM.allShotChartEntries.isEmpty {
                noDataPlaceholder("Chart shots in the logger to see your map")
            } else {
                miniShotChart
            }
        }
        .editorialCard(accent: accentColor)
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
                        .foregroundStyle(stats.percentage >= 50 ? .green : stats.percentage >= 35 ? BasketballPalette.courtAmber : .red)
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
                path.addArc(center: CGPoint(x: centerX, y: height), radius: radius, startAngle: .degrees(160), endAngle: .degrees(20), clockwise: true)
            }
            .stroke(PepTheme.elevated.opacity(0.4), lineWidth: 1)
        }
    }

    private var pointsTrendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Trend", title: "Scoring", accent: accentColor)

            let data = bbVM.pointsTrendData
            if data.count < 2 {
                noDataPlaceholder("Need 2+ games for the trend")
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
            }
        }
        .editorialCard(accent: accentColor)
    }

    private var confidenceInsightCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Mental", title: "Confidence vs FG%", accent: PepTheme.violet)

            let data = bbVM.confidenceCorrelation
            if data.count < 3 {
                noDataPlaceholder("Need 3+ box scores for insights")
            } else {
                let highConf = data.filter { $0.confidence >= 7 }
                let lowConf = data.filter { $0.confidence < 7 }
                let highAvg = highConf.isEmpty ? 0 : highConf.reduce(0.0) { $0 + $1.fgPct } / Double(highConf.count)
                let lowAvg = lowConf.isEmpty ? 0 : lowConf.reduce(0.0) { $0 + $1.fgPct } / Double(lowConf.count)

                HStack(spacing: 16) {
                    confidenceCol(label: "HIGH", pct: highAvg, color: .green)
                    Rectangle().fill(PepTheme.elevated).frame(width: 1, height: 50)
                    confidenceCol(label: "LOW", pct: lowAvg, color: .orange)
                }
            }
        }
        .editorialCard(accent: PepTheme.violet)
    }

    private func confidenceCol(label: String, pct: Double, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
            Text(String(format: "%.0f%%", pct))
                .font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(color)
            Text("FG%")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func noDataPlaceholder(_ message: String) -> some View {
        HStack {
            Spacer()
            Text(message)
                .font(.system(size: 12, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
            Spacer()
        }
        .padding(.vertical, 16)
    }
}
