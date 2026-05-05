import SwiftUI
import Charts

struct StepDetailView: View {
    @State private var viewModel = StepDetailViewModel()
    @State private var animateProgress: Bool = false
    @State private var selectedDate: Date? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                editorialHeader
                heroPanel
                periodSelector

                EditorialSectionHeader(
                    eyebrow: "01 \u{2014} Trends",
                    title: chartTitle,
                    meta: chartSubtitle.uppercased()
                )
                chartCard

                EditorialSectionHeader(
                    eyebrow: "02 \u{2014} Stats",
                    title: nil,
                    meta: periodLongLabel.uppercased()
                )
                statsGrid

                if viewModel.selectedPeriod == .day {
                    EditorialSectionHeader(eyebrow: "03 \u{2014} Hourly", title: "When you moved")
                    hourlyBreakdownCard
                }

                EditorialSectionHeader(eyebrow: recentSectionEyebrow, title: recentSectionTitle)
                recentBreakdownCard
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadData()
            withAnimation(.spring(response: 0.85, dampingFraction: 0.75)) {
                animateProgress = true
            }
            viewModel.healthKit.startLiveStepStreaming()
        }
        .onDisappear { viewModel.healthKit.stopLiveStepStreaming() }
        .refreshable { await viewModel.refreshSteps() }
    }

    // MARK: - Editorial header

    private var editorialHeader: some View {
        EditorialHeader(eyebrow: headerEyebrow, title: "Steps")
            .padding(.top, 8)
    }

    private var headerEyebrow: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE \u{00b7} MMM d"
        return f.string(from: Date())
    }

    // MARK: - Hero

    private var heroPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("TODAY")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(2.4)
                        .foregroundStyle(PepTheme.teal)

                    Text(formattedNumber(viewModel.todaySteps))
                        .font(.system(size: 56, weight: .semibold, design: .serif))
                        .kerning(-1.5)
                        .foregroundStyle(PepTheme.textPrimary)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Text("of \(formattedNumber(viewModel.stepGoal)) goal \u{00b7} \(Int(viewModel.todayProgress * 100))%")
                        .font(.system(.caption, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Spacer(minLength: 0)
                heroRing
            }

            Rectangle()
                .fill(LinearGradient(colors: [PepTheme.teal.opacity(0.5), PepTheme.teal.opacity(0)], startPoint: .leading, endPoint: .trailing))
                .frame(height: 0.75)

            HStack(spacing: 0) {
                heroMetric(label: "Distance", value: String(format: "%.2f", viewModel.distanceMiles), unit: "mi")
                Divider().overlay(PepTheme.separatorColor).frame(height: 30)
                heroMetric(label: "Floors", value: "\(viewModel.todayFlights)", unit: "climbed")
                Divider().overlay(PepTheme.separatorColor).frame(height: 30)
                heroMetric(label: "Active", value: "\(Int(viewModel.healthKit.activeCalories))", unit: "cal")
            }
        }
        .padding(20)
        .background(
            ZStack {
                PepTheme.cardSurface
                LinearGradient(
                    colors: [PepTheme.teal.opacity(0.10), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(.rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    LinearGradient(colors: [PepTheme.teal.opacity(0.28), PepTheme.teal.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.6
                )
        )
        .overlay(alignment: .topLeading) {
            Rectangle()
                .fill(PepTheme.teal)
                .frame(width: 2, height: 44)
                .padding(.top, 20)
        }
        .shadow(color: PepTheme.teal.opacity(0.12), radius: 16, x: 0, y: 6)
    }

    private var heroRing: some View {
        ZStack {
            Circle()
                .stroke(PepTheme.elevated, lineWidth: 8)
                .frame(width: 96, height: 96)

            Circle()
                .trim(from: 0, to: animateProgress ? viewModel.todayProgress : 0)
                .stroke(
                    AngularGradient(
                        colors: [PepTheme.teal, PepTheme.tealDeep, PepTheme.teal],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 96, height: 96)
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PepTheme.teal)
                Text("\(Int(viewModel.todayProgress * 100))%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
                    .contentTransition(.numericText())
            }
        }
    }

    private func heroMetric(label: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.6)
                .foregroundStyle(PepTheme.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Period selector

    private var periodSelector: some View {
        HStack(spacing: 4) {
            ForEach(StepTimePeriod.allCases) { period in
                let isOn = viewModel.selectedPeriod == period
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        viewModel.selectedPeriod = period
                        selectedDate = nil
                    }
                } label: {
                    Text(periodTitle(period))
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1.6)
                        .foregroundStyle(isOn ? PepTheme.invertedText : PepTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            ZStack {
                                if isOn {
                                    LinearGradient(colors: [PepTheme.teal, PepTheme.tealDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
                                }
                            }
                        )
                        .clipShape(.capsule)
                }
                .sensoryFeedback(.selection, trigger: viewModel.selectedPeriod)
            }
        }
        .padding(4)
        .background(PepTheme.elevated)
        .clipShape(.capsule)
        .overlay(Capsule().strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5))
    }

    private func periodTitle(_ p: StepTimePeriod) -> String {
        switch p {
        case .day: return "DAY"
        case .week: return "WEEK"
        case .month: return "MONTH"
        case .sixMonths: return "6 MOS"
        case .year: return "YEAR"
        }
    }

    private var periodLongLabel: String {
        switch viewModel.selectedPeriod {
        case .day: return "Today"
        case .week: return "Past 7 days"
        case .month: return "Past 30 days"
        case .sixMonths: return "Past 26 weeks"
        case .year: return "Past 12 months"
        }
    }

    // MARK: - Chart card

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                if let info = selectionInfo {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(info.title.uppercased())
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(1.8)
                            .foregroundStyle(PepTheme.teal)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(formattedNumber(info.value))
                                .font(.system(size: 28, weight: .semibold, design: .serif))
                                .foregroundStyle(PepTheme.textPrimary)
                                .contentTransition(.numericText())
                            Text("steps")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        if let sub = info.subtitle {
                            Text(sub)
                                .font(.system(.caption2, design: .serif))
                                .italic()
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AVERAGE")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(1.8)
                            .foregroundStyle(PepTheme.textTertiary)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(formattedNumber(viewModel.averageSteps))
                                .font(.system(size: 28, weight: .semibold, design: .serif))
                                .foregroundStyle(PepTheme.textPrimary)
                                .contentTransition(.numericText())
                            Text("steps/day")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        Text("Tap any bar to inspect")
                            .font(.system(.caption2, design: .serif))
                            .italic()
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
                Spacer()
            }

            chartView
                .frame(height: 200)
        }
        .padding(18)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
        .sensoryFeedback(.selection, trigger: selectedDate)
        .onChange(of: viewModel.selectedPeriod) { _, _ in selectedDate = nil }
    }

    // MARK: - Chart

    private var chartPoints: [ChartPoint] {
        switch viewModel.selectedPeriod {
        case .day:
            let cal = Calendar.current
            let today = cal.startOfDay(for: Date())
            return viewModel.hourlySteps.map { item in
                let date = cal.date(byAdding: .hour, value: item.hour, to: today) ?? today
                return ChartPoint(date: date, value: item.steps, kind: .hour(item.hour))
            }
        case .week:
            return viewModel.dailySteps.suffix(7).map {
                ChartPoint(date: $0.date, value: $0.steps, kind: .day($0.date))
            }
        case .month:
            return viewModel.dailySteps.suffix(30).map {
                ChartPoint(date: $0.date, value: $0.steps, kind: .day($0.date))
            }
        case .sixMonths:
            return viewModel.weeklySteps.map {
                ChartPoint(date: $0.weekStart, value: $0.steps, kind: .week($0.weekStart))
            }
        case .year:
            return viewModel.monthlySteps.map {
                ChartPoint(date: $0.monthStart, value: $0.steps, kind: .month($0.monthStart))
            }
        }
    }

    private var goalReference: Int? {
        switch viewModel.selectedPeriod {
        case .day, .week, .month: return viewModel.stepGoal
        default: return nil
        }
    }

    @ViewBuilder
    private var chartView: some View {
        let points = chartPoints
        if points.isEmpty {
            emptyChart
        } else {
            Chart {
                ForEach(points) { p in
                    BarMark(
                        x: .value("Date", p.date, unit: chartUnit),
                        y: .value("Steps", p.value)
                    )
                    .cornerRadius(4)
                    .foregroundStyle(barGradient(for: p.value, max: points.map(\.value).max() ?? 1))
                    .opacity(selectedDate == nil || isSelected(p) ? 1.0 : 0.35)
                }

                if let goal = goalReference, viewModel.selectedPeriod != .day {
                    RuleMark(y: .value("Goal", goal))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .foregroundStyle(PepTheme.teal.opacity(0.55))
                        .annotation(position: .top, alignment: .leading) {
                            Text("GOAL")
                                .font(.system(size: 8, weight: .heavy))
                                .tracking(1.4)
                                .foregroundStyle(PepTheme.teal)
                                .padding(.leading, 2)
                        }
                }

                if let sel = selectedDate, let p = nearestPoint(to: sel, in: points) {
                    RuleMark(x: .value("Selected", p.date, unit: chartUnit))
                        .foregroundStyle(PepTheme.teal.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            SpatialTapGesture()
                                .onEnded { value in
                                    guard let plotFrame = proxy.plotFrame else { return }
                                    let origin = geo[plotFrame].origin
                                    let location = CGPoint(
                                        x: value.location.x - origin.x,
                                        y: value.location.y - origin.y
                                    )
                                    if let date: Date = proxy.value(atX: location.x) {
                                        if let nearest = nearestPoint(to: date, in: points) {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                                if let current = selectedDate, isSelected(nearest), Calendar.current.isDate(current, equalTo: nearest.date, toGranularity: .second) {
                                                    selectedDate = nil
                                                } else {
                                                    selectedDate = nearest.date
                                                }
                                            }
                                        }
                                    }
                                }
                        )
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(PepTheme.textSecondary.opacity(0.08))
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text(compactInt(v))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(PepTheme.textTertiary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: xAxisCount)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(xAxisLabel(for: date))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(PepTheme.textTertiary)
                        }
                    }
                }
            }
        }
    }

    private var emptyChart: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 28))
                .foregroundStyle(PepTheme.textTertiary)
            Text("No data for this period")
                .font(.system(.subheadline, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var chartUnit: Calendar.Component {
        switch viewModel.selectedPeriod {
        case .day: return .hour
        case .week, .month: return .day
        case .sixMonths: return .weekOfYear
        case .year: return .month
        }
    }

    private var xAxisCount: Int {
        switch viewModel.selectedPeriod {
        case .day: return 5
        case .week: return 7
        case .month: return 5
        case .sixMonths: return 5
        case .year: return 6
        }
    }

    private func xAxisLabel(for date: Date) -> String {
        let f = DateFormatter()
        switch viewModel.selectedPeriod {
        case .day: f.dateFormat = "ha"
        case .week: f.dateFormat = "EEE"
        case .month: f.dateFormat = "MMM d"
        case .sixMonths: f.dateFormat = "MMM"
        case .year: f.dateFormat = "MMM"
        }
        return f.string(from: date)
    }

    private func barGradient(for value: Int, max: Int) -> LinearGradient {
        let intensity = max > 0 ? Double(value) / Double(max) : 0
        return LinearGradient(
            colors: [
                PepTheme.teal.opacity(0.55 + intensity * 0.45),
                PepTheme.tealDeep.opacity(0.4 + intensity * 0.35)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func isSelected(_ p: ChartPoint) -> Bool {
        guard let sel = selectedDate else { return false }
        let cal = Calendar.current
        switch viewModel.selectedPeriod {
        case .day: return cal.component(.hour, from: p.date) == cal.component(.hour, from: sel)
        case .week, .month: return cal.isDate(p.date, inSameDayAs: sel)
        case .sixMonths:
            return cal.dateComponents([.year, .weekOfYear], from: p.date) == cal.dateComponents([.year, .weekOfYear], from: sel)
        case .year:
            return cal.dateComponents([.year, .month], from: p.date) == cal.dateComponents([.year, .month], from: sel)
        }
    }

    private func nearestPoint(to date: Date, in points: [ChartPoint]) -> ChartPoint? {
        points.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }

    private struct SelectionInfo {
        let title: String
        let value: Int
        let subtitle: String?
    }

    private var selectionInfo: SelectionInfo? {
        guard let sel = selectedDate else { return nil }
        let points = chartPoints
        guard let p = nearestPoint(to: sel, in: points) else { return nil }
        let f = DateFormatter()
        switch p.kind {
        case .hour(let h):
            let pct = viewModel.todaySteps > 0 ? Double(p.value) / Double(viewModel.todaySteps) * 100 : 0
            return SelectionInfo(
                title: hourRange(h),
                value: p.value,
                subtitle: p.value > 0 ? String(format: "%.1f%% of today", pct) : "Quiet hour"
            )
        case .day(let date):
            f.dateFormat = "EEEE, MMM d"
            let goal = viewModel.stepGoal
            let sub = p.value >= goal ? "Goal reached \u{2728}" : "\(formattedNumber(max(goal - p.value, 0))) to goal"
            return SelectionInfo(title: f.string(from: date), value: p.value, subtitle: sub)
        case .week(let start):
            let cal = Calendar.current
            let end = cal.date(byAdding: .day, value: 6, to: start) ?? start
            f.dateFormat = "MMM d"
            return SelectionInfo(
                title: "Week of \(f.string(from: start)) \u{2013} \(f.string(from: end))",
                value: p.value,
                subtitle: "\(formattedNumber(p.value / 7)) avg/day"
            )
        case .month(let m):
            f.dateFormat = "MMMM yyyy"
            let cal = Calendar.current
            let days = cal.range(of: .day, in: .month, for: m)?.count ?? 30
            return SelectionInfo(
                title: f.string(from: m),
                value: p.value,
                subtitle: "\(formattedNumber(p.value / days)) avg/day"
            )
        }
    }

    private var chartTitle: String {
        switch viewModel.selectedPeriod {
        case .day: return "Today by hour"
        case .week: return "Last 7 days"
        case .month: return "Last 30 days"
        case .sixMonths: return "Last 6 months"
        case .year: return "Last 12 months"
        }
    }

    private var chartSubtitle: String {
        "Avg \(formattedNumber(viewModel.averageSteps))/day"
    }

    // MARK: - Stats grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            statTile(eyebrow: "Average", value: formattedNumber(viewModel.averageSteps), unit: "steps/day", icon: "chart.line.uptrend.xyaxis", accent: PepTheme.teal)
            statTile(eyebrow: "Total", value: compactInt(viewModel.totalStepsInPeriod), unit: "steps", icon: "sum", accent: PepTheme.violet)
            statTile(eyebrow: "Best", value: formattedNumber(viewModel.maxStepsInPeriod), unit: bestUnit, icon: "arrow.up.right", accent: PepTheme.success)
            statTile(eyebrow: "Lowest", value: formattedNumber(viewModel.minStepsInPeriod), unit: bestUnit, icon: "arrow.down.right", accent: PepTheme.amber)
        }
    }

    private var bestUnit: String {
        switch viewModel.selectedPeriod {
        case .day: return "in an hour"
        case .week, .month: return "in a day"
        case .sixMonths: return "in a week"
        case .year: return "in a month"
        }
    }

    private func statTile(eyebrow: String, value: String, unit: String, icon: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(eyebrow.uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1.8)
                    .foregroundStyle(accent)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accent.opacity(0.7))
            }

            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(unit)
                .font(.system(.caption2, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(colors: [accent.opacity(0.2), accent.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.6
                )
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(accent)
                .frame(width: 2)
                .padding(.vertical, 14)
        }
    }

    // MARK: - Hourly breakdown

    private var hourlyBreakdownCard: some View {
        let active = viewModel.hourlySteps.filter { $0.steps > 0 }
        let top = Array(active.sorted { $0.steps > $1.steps }.prefix(5))
        let maxV = top.map(\.steps).max() ?? 1

        return VStack(alignment: .leading, spacing: 14) {
            if top.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "moon.stars")
                            .font(.title3)
                            .foregroundStyle(PepTheme.textTertiary)
                        Text("Nothing logged yet today")
                            .font(.system(.subheadline, design: .serif))
                            .italic()
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
            } else {
                ForEach(Array(top.enumerated()), id: \.element.id) { idx, hour in
                    HStack(spacing: 12) {
                        Text(String(format: "%02d", idx + 1))
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .tracking(1.2)
                            .foregroundStyle(PepTheme.teal)
                            .frame(width: 22, alignment: .leading)

                        Text(hour.hourLabel.uppercased())
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .tracking(1.2)
                            .foregroundStyle(PepTheme.textSecondary)
                            .frame(width: 44, alignment: .leading)

                        GeometryReader { geo in
                            let ratio = CGFloat(hour.steps) / CGFloat(max(maxV, 1))
                            ZStack(alignment: .leading) {
                                Capsule().fill(PepTheme.elevated)
                                Capsule()
                                    .fill(LinearGradient(colors: [PepTheme.teal, PepTheme.tealDeep], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: max(geo.size.width * ratio, 6))
                            }
                        }
                        .frame(height: 8)

                        Text(formattedNumber(hour.steps))
                            .font(.system(.caption, design: .serif, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                            .frame(width: 56, alignment: .trailing)
                    }
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5))
    }

    // MARK: - Recent breakdown (adapts to selected period)

    private struct RecentRow: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let value: Int
        let goal: Int?
    }

    private var recentSectionEyebrow: String {
        switch viewModel.selectedPeriod {
        case .day: return "04 \u{2014} This Week"
        case .week: return "03 \u{2014} Recent Days"
        case .month: return "03 \u{2014} Recent Weeks"
        case .sixMonths: return "03 \u{2014} Recent Weeks"
        case .year: return "03 \u{2014} Recent Months"
        }
    }

    private var recentSectionTitle: String? { nil }

    private var recentRows: [RecentRow] {
        let cal = Calendar.current
        switch viewModel.selectedPeriod {
        case .day, .week:
            let recent = Array(viewModel.dailySteps.suffix(7).reversed())
            return recent.map { day in
                RecentRow(
                    title: dayLabel(for: day.date),
                    subtitle: day.dateLabel.uppercased(),
                    value: day.steps,
                    goal: viewModel.stepGoal
                )
            }
        case .month:
            // Group last 30 days into weeks
            let days = viewModel.dailySteps.suffix(30)
            let grouped = Dictionary(grouping: days) { day -> Date in
                cal.dateInterval(of: .weekOfYear, for: day.date)?.start ?? day.date
            }
            let weeks = grouped.keys.sorted(by: >).prefix(5)
            return weeks.map { weekStart -> RecentRow in
                let items = grouped[weekStart] ?? []
                let total = items.reduce(0) { $0 + $1.steps }
                let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
                let f = DateFormatter()
                f.dateFormat = "MMM d"
                return RecentRow(
                    title: weekTitle(for: weekStart),
                    subtitle: "\(f.string(from: weekStart)) \u{2013} \(f.string(from: weekEnd))".uppercased(),
                    value: total,
                    goal: viewModel.stepGoal * 7
                )
            }
        case .sixMonths:
            let recent = Array(viewModel.weeklySteps.suffix(8).reversed())
            return recent.map { week in
                let weekEnd = cal.date(byAdding: .day, value: 6, to: week.weekStart) ?? week.weekStart
                let f = DateFormatter()
                f.dateFormat = "MMM d"
                return RecentRow(
                    title: weekTitle(for: week.weekStart),
                    subtitle: "\(f.string(from: week.weekStart)) \u{2013} \(f.string(from: weekEnd))".uppercased(),
                    value: week.steps,
                    goal: viewModel.stepGoal * 7
                )
            }
        case .year:
            let recent = Array(viewModel.monthlySteps.suffix(12).reversed())
            return recent.map { month in
                let days = cal.range(of: .day, in: .month, for: month.monthStart)?.count ?? 30
                return RecentRow(
                    title: month.fullLabel,
                    subtitle: "\(formattedNumber(month.steps / max(days, 1))) AVG/DAY",
                    value: month.steps,
                    goal: viewModel.stepGoal * days
                )
            }
        }
    }

    private var recentValueUnit: String {
        switch viewModel.selectedPeriod {
        case .day, .week: return "steps"
        case .month, .sixMonths: return "steps/week"
        case .year: return "steps/month"
        }
    }

    private var recentBreakdownCard: some View {
        let rows = recentRows
        let maxV = max(rows.map(\.value).max() ?? 1, rows.compactMap(\.goal).max() ?? 1)

        return VStack(alignment: .leading, spacing: 14) {
            if rows.isEmpty {
                Text("No history available yet")
                    .font(.system(.subheadline, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title)
                                .font(.system(size: 14, weight: .semibold, design: .serif))
                                .foregroundStyle(PepTheme.textPrimary)
                                .lineLimit(1)
                            Text(row.subtitle)
                                .font(.system(size: 9, weight: .heavy))
                                .tracking(1.4)
                                .foregroundStyle(PepTheme.textTertiary)
                                .lineLimit(1)
                        }
                        .frame(width: 110, alignment: .leading)

                        GeometryReader { geo in
                            let ratio = min(CGFloat(row.value) / CGFloat(max(maxV, 1)), 1.0)
                            let met = (row.goal.map { row.value >= $0 } ?? false)
                            ZStack(alignment: .leading) {
                                Capsule().fill(PepTheme.elevated)
                                Capsule()
                                    .fill(
                                        met
                                        ? LinearGradient(colors: [PepTheme.success, PepTheme.success.opacity(0.6)], startPoint: .leading, endPoint: .trailing)
                                        : LinearGradient(colors: [PepTheme.teal, PepTheme.tealDeep], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .frame(width: max(geo.size.width * ratio, 6))
                            }
                        }
                        .frame(height: 10)

                        HStack(spacing: 2) {
                            if let g = row.goal, row.value >= g {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(PepTheme.success)
                            }
                            Text(compactInt(row.value))
                                .font(.system(.caption, design: .serif, weight: .semibold))
                                .foregroundStyle((row.goal.map { row.value >= $0 } ?? false) ? PepTheme.success : PepTheme.textPrimary)
                        }
                        .frame(width: 70, alignment: .trailing)
                    }

                    if idx != rows.indices.last {
                        Rectangle()
                            .fill(PepTheme.separatorColor)
                            .frame(height: 0.5)
                    }
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5))
    }

    private func weekTitle(for weekStart: Date) -> String {
        let cal = Calendar.current
        let now = Date()
        if let interval = cal.dateInterval(of: .weekOfYear, for: now), interval.start == weekStart {
            return "This Week"
        }
        if let lastWeek = cal.date(byAdding: .weekOfYear, value: -1, to: now),
           let interval = cal.dateInterval(of: .weekOfYear, for: lastWeek), interval.start == weekStart {
            return "Last Week"
        }
        let weeksAgo = cal.dateComponents([.weekOfYear], from: weekStart, to: now).weekOfYear ?? 0
        if weeksAgo > 0 { return "\(weeksAgo) weeks ago" }
        let f = DateFormatter()
        f.dateFormat = "'Week of' MMM d"
        return f.string(from: weekStart)
    }

    // MARK: - Helpers

    private func formattedNumber(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func compactInt(_ value: Int) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM", Double(value) / 1_000_000) }
        if value >= 10_000 { return String(format: "%.1fK", Double(value) / 1_000) }
        if value >= 1_000 { return String(format: "%.2fK", Double(value) / 1_000) }
        return formattedNumber(value)
    }

    private func dayLabel(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: date)
    }

    private func hourRange(_ hour: Int) -> String {
        func label(_ h: Int) -> String {
            let h24 = ((h % 24) + 24) % 24
            let ampm = h24 < 12 ? "AM" : "PM"
            let h12 = h24 % 12 == 0 ? 12 : h24 % 12
            return "\(h12)\(ampm)"
        }
        return "\(label(hour)) \u{2013} \(label(hour + 1))"
    }
}

// MARK: - Chart point

private struct ChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Int
    let kind: Kind

    enum Kind {
        case hour(Int)
        case day(Date)
        case week(Date)
        case month(Date)
    }
}

protocol StepChartable {
    var chartSteps: Int { get }
}

extension DailyStepData: StepChartable {
    var chartSteps: Int { steps }
}
