import SwiftUI

struct RunningDashboardView: View {
    @Bindable var runVM: RunningViewModel
    let accentColor: Color
    let onStartRun: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            heroCard
            startRunCard
            trainingLoadCard
            nextRunSuggestionCard
            SportCoachCard(sport: .running, accent: accentColor)
            weeklyMileageChart
            paceProgressCard
            racePredictionsCard
            recentRunsList
            shoeRackCard
            personalRecordsCard
            workoutBuilderButton
        }
    }

    // MARK: - Hero (Editorial)

    private var heroCard: some View {
        PepSportCard(accent: accentColor) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("RUNNING")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.0)
                        .foregroundStyle(accentColor.opacity(0.9))
                    Spacer()
                    Button {
                        runVM.showRunSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(PepTheme.elevated.opacity(0.5), in: Circle())
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
                    heroStat(value: String(format: "%.0f", runVM.totalMilesAllTime), label: "MILES")
                    statDivider
                    heroStat(value: "\(runVM.totalRunsAllTime)", label: "RUNS")
                    statDivider
                    heroStat(value: formatPace(runVM.averagePaceAllTime), label: "AVG PACE")
                    statDivider
                    heroStat(value: String(format: "%.1f", runVM.longestRunEver), label: "LONGEST")
                }
            }
        }
    }

    private var heroTitle: String {
        let runs = runVM.thisWeekRuns.count
        if runs == 0 { return "Lace up." }
        if runs == 1 { return "On the road." }
        if runVM.thisWeekMiles >= 25 { return "Stacking miles." }
        return "Finding rhythm."
    }

    private var heroLine: String {
        let runs = runVM.thisWeekRuns.count
        let miles = runVM.thisWeekMiles
        if runs == 0 {
            return "No runs this week — even an easy 2 miles gets the legs moving."
        }
        if runs == 1 {
            return String(format: "One run down — %.1f mi already in the legs.", miles)
        }
        if miles >= 25 {
            return String(format: "%d runs · %.1f mi this week — that's a real block of work.", runs, miles)
        }
        return String(format: "%d runs this week · %.1f mi logged · keep showing up.", runs, miles)
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

    // MARK: - Start Run

    private var startRunCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "01 — Today",
                title: "Lace Up",
                accent: accentColor,
                trailing: AnyView(
                    Text(runVM.selectedRunType.rawValue.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(runVM.selectedRunType.color)
                )
            )

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach([RunType.easyRun, .tempoRun, .intervalSession, .longRun, .recoveryRun, .fartlek, .raceRun], id: \.id) { type in
                        Button {
                            runVM.selectedRunType = type
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 14))
                                Text(type.rawValue)
                                    .font(.system(size: 9, weight: .semibold))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(runVM.selectedRunType == type ? .black : PepTheme.textSecondary)
                            .frame(width: 72)
                            .padding(.vertical, 10)
                            .background(runVM.selectedRunType == type ? type.color : PepTheme.elevated.opacity(0.5))
                            .clipShape(.rect(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)

            HStack(spacing: 10) {
                Toggle(isOn: $runVM.isTreadmillMode) {
                    Label("Treadmill", systemImage: "figure.run.treadmill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .toggleStyle(.switch)
                .tint(accentColor)

                Spacer()

                if !runVM.shoes.filter({ !$0.isRetired }).isEmpty {
                    Menu {
                        Button("No Shoe") { runVM.selectedShoeId = nil }
                        ForEach(runVM.shoes.filter { !$0.isRetired }) { shoe in
                            Button("\(shoe.brand) \(shoe.name)") {
                                runVM.selectedShoeId = shoe.id
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "shoe.fill")
                                .font(.system(size: 10))
                            Text(runVM.selectedShoeId.flatMap { id in runVM.shoes.first { $0.id == id }?.name } ?? "Select Shoe")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(PepTheme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(PepTheme.elevated.opacity(0.5))
                        .clipShape(Capsule())
                    }
                }
            }

            EditorialPrimaryButton("Begin Run", accent: accentColor) {
                onStartRun()
            }
        }
        .editorialCard(accent: accentColor)
    }

    // MARK: - Training Load

    private var trainingLoadCard: some View {
        let history = runVM.weeklyMileageHistory
        let thisWeek = history.last?.totalMiles ?? 0
        let lastWeek = history.dropLast().last?.totalMiles ?? 0
        let pctChange = lastWeek > 0 ? ((thisWeek - lastWeek) / lastWeek) * 100 : 0

        let status: (label: String, color: Color, line: String) = {
            if thisWeek == 0 && lastWeek == 0 {
                return ("FRESH", PepTheme.textSecondary, "Plenty in the tank — pick a route.")
            }
            if thisWeek == 0 {
                return ("RECOVERY", .green, "A rest week — listen to the legs.")
            }
            if pctChange > 30 {
                return ("PUSH", .orange, "Big jump in volume — keep an eye on recovery.")
            }
            if pctChange > 10 {
                return ("BUILD", accentColor, "Climbing volume the right way.")
            }
            if pctChange < -20 {
                return ("EASE", PepTheme.violet, "Lighter week — useful before a hard block.")
            }
            return ("STEADY", .green, "Holding a solid weekly rhythm.")
        }()

        return VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "02 — Load",
                title: "Training Load",
                accent: accentColor,
                trailing: AnyView(
                    Text(status.label)
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(status.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(status.color.opacity(0.12))
                        .clipShape(Capsule())
                )
            )

            HStack(spacing: 0) {
                loadColumn(value: String(format: "%.1f", thisWeek), label: "THIS WEEK", color: accentColor)
                statDivider
                loadColumn(value: String(format: "%.1f", lastWeek), label: "LAST WEEK", color: PepTheme.textSecondary)
                statDivider
                loadColumn(
                    value: pctChange == 0 ? "—" : String(format: "%+.0f%%", pctChange),
                    label: "DELTA",
                    color: pctChange > 30 ? .orange : pctChange > 0 ? .green : pctChange < 0 ? PepTheme.violet : PepTheme.textSecondary
                )
            }

            Text(status.line)
                .font(.system(size: 12, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
        }
        .editorialCard(accent: accentColor)
    }

    private func loadColumn(value: String, label: String, color: Color) -> some View {
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

    // MARK: - Consistency Strip

    private var consistencyCard: some View {
        let days = runVM.todayDailyDistance
        let streak = currentStreak()

        return VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "03 — Streak",
                title: "Consistency",
                accent: accentColor,
                trailing: AnyView(
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(streak > 0 ? .orange : PepTheme.textSecondary.opacity(0.5))
                        Text("\(streak) day\(streak == 1 ? "" : "s")")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(streak > 0 ? .orange : PepTheme.textSecondary)
                    }
                )
            )

            HStack(spacing: 8) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, entry in
                    VStack(spacing: 6) {
                        Text(dayLetter(entry.day))
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1.0)
                            .foregroundStyle(PepTheme.textSecondary)

                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(entry.distance > 0 ? accentColor.opacity(0.18 + min(entry.distance / 12, 0.65)) : PepTheme.elevated.opacity(0.4))
                                .frame(height: 36)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(entry.distance > 0 ? accentColor.opacity(0.4) : Color.clear, lineWidth: 0.5)
                                )

                            if entry.distance > 0 {
                                Text(String(format: "%.0f", entry.distance))
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            } else if Calendar.current.isDateInToday(entry.day) {
                                Circle()
                                    .strokeBorder(PepTheme.textSecondary.opacity(0.5), lineWidth: 1)
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Text(consistencyLine(days: days, streak: streak))
                .font(.system(size: 12, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
        }
        .editorialCard(accent: accentColor)
    }

    private func dayLetter(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEEE"
        return f.string(from: date)
    }

    private func currentStreak() -> Int {
        let cal = Calendar.current
        var streak = 0
        var cursor = cal.startOfDay(for: Date())
        let runDays = Set(runVM.completedRuns.map { cal.startOfDay(for: $0.date) })
        // Today optional — only counts if there's a run; otherwise check from yesterday
        if !runDays.contains(cursor) {
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        while runDays.contains(cursor) {
            streak += 1
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return streak
    }

    private func consistencyLine(days: [(day: Date, distance: Double)], streak: Int) -> String {
        let activeDays = days.filter { $0.distance > 0 }.count
        if activeDays == 0 { return "Empty week — a 20-minute run is enough to start it." }
        if activeDays >= 5 { return "\(activeDays) days active this week — elite frequency." }
        return "\(activeDays) of 7 days active. One more would round it out."
    }

    // MARK: - Next Run Suggestion

    private var nextRunSuggestionCard: some View {
        let suggestion = nextRunSuggestion()

        return VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(
                kicker: "04 — Tomorrow",
                title: "Next Run",
                accent: accentColor,
                trailing: AnyView(
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 11))
                        .foregroundStyle(accentColor.opacity(0.7))
                )
            )

            Button {
                runVM.selectedRunType = suggestion.type
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(suggestion.type.color.opacity(0.14))
                            .frame(width: 48, height: 48)
                        Image(systemName: suggestion.type.icon)
                            .font(.system(size: 18))
                            .foregroundStyle(suggestion.type.color)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(suggestion.type.rawValue)
                            .font(.system(size: 16, weight: .semibold, design: .serif))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text(suggestion.reason)
                            .font(.system(size: 11, design: .serif))
                            .italic()
                            .foregroundStyle(PepTheme.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(suggestion.targetDistance)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(accentColor)
                        Text("TARGET")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .editorialCard(accent: accentColor)
    }

    private struct NextRunSuggestion {
        let type: RunType
        let reason: String
        let targetDistance: String
    }

    private func nextRunSuggestion() -> NextRunSuggestion {
        let recent = runVM.completedRuns.prefix(5).map(\.runType)
        let lastRun = runVM.completedRuns.first

        // After hard work, recover
        if let last = lastRun,
           [RunType.intervalSession, .tempoRun, .raceRun].contains(last.runType) {
            return NextRunSuggestion(
                type: .recoveryRun,
                reason: "Yesterday was hard — float through an easy effort and let it absorb.",
                targetDistance: "3.0 mi"
            )
        }

        // After long run, easy
        if let last = lastRun, last.runType == .longRun {
            return NextRunSuggestion(
                type: .recoveryRun,
                reason: "Long run done — keep tomorrow conversational.",
                targetDistance: "3.5 mi"
            )
        }

        // Mostly easy lately, time for tempo
        let easyCount = recent.filter { $0 == .easyRun || $0 == .recoveryRun }.count
        if easyCount >= 3 {
            return NextRunSuggestion(
                type: .tempoRun,
                reason: "Plenty of aerobic miles in — a comfortable hard tempo will sharpen the engine.",
                targetDistance: "4.0 mi"
            )
        }

        // No long run in last 5
        if !recent.contains(.longRun) && runVM.totalRunsAllTime >= 3 {
            return NextRunSuggestion(
                type: .longRun,
                reason: "It's been a minute since a long one — time to add a slow steady mile or two.",
                targetDistance: "8.0 mi"
            )
        }

        return NextRunSuggestion(
            type: .easyRun,
            reason: "Default to easy — most miles should feel like a conversation pace.",
            targetDistance: "4.0 mi"
        )
    }

    // MARK: - Weekly Mileage

    private var weeklyMileageChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "05 — Volume",
                title: "Weekly Mileage",
                accent: accentColor,
                trailing: AnyView(
                    Text(String(format: "%.1f mi", runVM.thisWeekMiles))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(accentColor)
                )
            )

            let mileageData = runVM.weeklyMileageHistory
            let maxMiles = max(mileageData.map(\.totalMiles).max() ?? 1, 1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(mileageData) { week in
                        VStack(spacing: 4) {
                            Text(String(format: "%.0f", week.totalMiles))
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundStyle(week.totalMiles > 0 ? accentColor : PepTheme.textSecondary.opacity(0.4))

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    week.totalMiles > 0 ?
                                    LinearGradient(colors: [accentColor, accentColor.opacity(0.5)], startPoint: .top, endPoint: .bottom) :
                                    LinearGradient(colors: [PepTheme.elevated, PepTheme.elevated], startPoint: .top, endPoint: .bottom)
                                )
                                .frame(width: 24, height: max(CGFloat(week.totalMiles / maxMiles) * 80, 4))

                            Text(weekLabel(week.weekStart))
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                }
                .frame(height: 110)
            }
            .contentMargins(.horizontal, 4)
        }
        .editorialCard(accent: accentColor)
    }

    // MARK: - Recent Runs

    private var recentRunsList: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "07 — Log",
                title: "Recent Runs",
                accent: accentColor,
                trailing: AnyView(
                    Text("\(runVM.completedRuns.count) total")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                )
            )

            if runVM.completedRuns.isEmpty {
                noDataPlaceholder("No runs logged yet")
            } else {
                ForEach(runVM.completedRuns.prefix(5)) { run in
                    Button {
                        runVM.selectedRun = run
                        runVM.showRunDetail = true
                    } label: {
                        recentRunRow(run)
                    }
                    .buttonStyle(.plain)

                    if run.id != runVM.completedRuns.prefix(5).last?.id {
                        LinearGradient(
                            colors: [PepTheme.textPrimary.opacity(0.08), PepTheme.textPrimary.opacity(0)],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(height: 0.5)
                    }
                }
            }
        }
        .editorialCard(accent: accentColor)
    }

    private func recentRunRow(_ run: CompletedRun) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(run.runType.color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: run.runType.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(run.runType.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(run.runType.rawValue)
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                    if run.isTreadmill {
                        Text("INDOOR")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(1.0)
                            .foregroundStyle(PepTheme.violet)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(PepTheme.violet.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                Text(run.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                    .font(.system(size: 10))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(String(format: "%.2f mi", run.distanceMiles))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(accentColor)
                Text(run.averagePaceFormatted + " /mi")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
        }
        .padding(.vertical, 6)
    }

    // MARK: - Race Predictions

    private var racePredictionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "—",
                title: "Race Predictions",
                accent: PepTheme.amber,
                trailing: AnyView(
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 12))
                        .foregroundStyle(PepTheme.amber)
                )
            )

            let predictions = runVM.racePredictions
            if predictions.isEmpty {
                noDataPlaceholder("Run more to get predictions")
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(predictions) { pred in
                        VStack(spacing: 6) {
                            Text(pred.raceName.uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.4)
                                .foregroundStyle(PepTheme.textSecondary)
                            Text(pred.predictedTimeFormatted)
                                .font(.system(.title3, design: .serif, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(pred.confidence > 0.7 ? .green : pred.confidence > 0.5 ? .yellow : .orange)
                                    .frame(width: 5, height: 5)
                                Text("\(Int(pred.confidence * 100))% confidence")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PepTheme.elevated.opacity(0.5))
                        .clipShape(.rect(cornerRadius: 12))
                    }
                }
            }
        }
        .editorialCard(accent: PepTheme.amber)
    }

    // MARK: - Pace Trend

    private var paceProgressCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "06 — Speed",
                title: "Pace Trend",
                accent: accentColor,
                trailing: AnyView(
                    paceTrendBadge
                )
            )

            let data = runVM.paceOverTimeData
            if data.count < 2 {
                noDataPlaceholder("Need 2+ runs to show trend")
            } else {
                let minPace = (data.map(\.pace).min() ?? 6) - 0.5
                let maxPace = (data.map(\.pace).max() ?? 12) + 0.5
                let range = maxPace - minPace

                GeometryReader { geo in
                    let width = geo.size.width
                    let height: CGFloat = 100
                    let stepX = width / CGFloat(max(data.count - 1, 1))

                    ZStack(alignment: .topLeading) {
                        Path { path in
                            for (i, point) in data.enumerated() {
                                let x = CGFloat(i) * stepX
                                let y = CGFloat((point.pace - minPace) / range) * height
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

                        Path { path in
                            for (i, point) in data.enumerated() {
                                let x = CGFloat(i) * stepX
                                let y = CGFloat((point.pace - minPace) / range) * height
                                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                        }
                        .stroke(accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    }
                    .frame(height: height)
                }
                .frame(height: 100)

                Text("Lower line = faster pace.")
                    .font(.system(size: 10, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .editorialCard(accent: accentColor)
    }

    @ViewBuilder
    private var paceTrendBadge: some View {
        let data = runVM.paceOverTimeData
        if let first = data.first, let last = data.last {
            let diff = first.pace - last.pace
            HStack(spacing: 3) {
                Image(systemName: diff > 0 ? "arrow.down.right" : "arrow.up.right")
                    .font(.system(size: 9))
                Text(String(format: "%+.1f /mi", -diff))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(diff > 0 ? .green : .orange)
        } else {
            EmptyView()
        }
    }

    // MARK: - Shoe Rack

    private var shoeRackCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "—",
                title: "Shoe Rack",
                accent: accentColor,
                trailing: AnyView(
                    Button {
                        runVM.showShoeManager = true
                    } label: {
                        Text("Manage")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(accentColor)
                    }
                )
            )

            let activeShoes = runVM.shoes.filter { !$0.isRetired }
            if activeShoes.isEmpty {
                noDataPlaceholder("Add shoes to track mileage")
            } else {
                ForEach(activeShoes) { shoe in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(shoe.statusColor.opacity(0.12))
                                .frame(width: 38, height: 38)
                            Image(systemName: "shoe.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(shoe.statusColor)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(shoe.brand) \(shoe.name)")
                                .font(.system(size: 13, weight: .semibold, design: .serif))
                                .foregroundStyle(PepTheme.textPrimary)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(PepTheme.elevated)
                                        .frame(height: 4)
                                    Capsule()
                                        .fill(shoe.statusColor)
                                        .frame(width: geo.size.width * shoe.usagePercentage, height: 4)
                                }
                            }
                            .frame(height: 4)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "%.0f mi", shoe.totalMiles))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(shoe.statusColor)
                            Text(String(format: "%.0f mi left", shoe.milesRemaining))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .editorialCard(accent: accentColor)
    }

    // MARK: - Personal Records

    private var personalRecordsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "—",
                title: "Personal Records",
                accent: PepTheme.amber,
                trailing: AnyView(
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(PepTheme.amber)
                )
            )

            if runVM.completedRuns.isEmpty {
                noDataPlaceholder("Start running to set records")
            } else {
                let fastest = runVM.completedRuns.filter { $0.bestPace > 0 }.min(by: { $0.bestPace < $1.bestPace })
                let longest = runVM.completedRuns.max(by: { $0.distanceMiles < $1.distanceMiles })
                let mostElevation = runVM.completedRuns.max(by: { $0.totalElevationGain < $1.totalElevationGain })

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    if let run = fastest {
                        prCell(icon: "bolt.fill", label: "FASTEST", value: run.bestPaceFormatted + "/mi", color: .green)
                    }
                    if let run = longest {
                        prCell(icon: "road.lanes", label: "LONGEST", value: String(format: "%.1f mi", run.distanceMiles), color: accentColor)
                    }
                    if let run = mostElevation {
                        prCell(icon: "mountain.2.fill", label: "MOST CLIMB", value: String(format: "%.0f ft", run.totalElevationGain), color: .orange)
                    }
                }
            }
        }
        .editorialCard(accent: PepTheme.amber)
    }

    private func prCell(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(.system(.subheadline, design: .serif, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 10))
    }

    // MARK: - Workout Builder Button

    private var workoutBuilderButton: some View {
        Button {
            runVM.showWorkoutBuilder = true
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
                    Text("Create Run Workout")
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Build interval, tempo & custom workouts")
                        .font(.system(size: 11, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .editorialCard(accent: accentColor)
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
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(.vertical, 16)
            Spacer()
        }
    }

    private func weekLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    private func formatPace(_ pace: Double) -> String {
        guard pace > 0 else { return "--:--" }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
}
