import SwiftUI

struct StepDetailView: View {
    @State private var viewModel = StepDetailViewModel()
    @State private var animateProgress: Bool = false
    @State private var selectedBarID: UUID? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                todayHeroCard
                periodSelector
                chartSection
                statsGrid
                if viewModel.selectedPeriod == .day {
                    todayBreakdownSection
                }
                recentDaysSection
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .navigationTitle("Steps")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadData()
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animateProgress = true
            }
            viewModel.healthKit.startLiveStepStreaming()
        }
        .onDisappear {
            viewModel.healthKit.stopLiveStepStreaming()
        }
        .refreshable {
            await viewModel.refreshSteps()
        }
    }

    // MARK: - Hero Card

    private var todayHeroCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(PepTheme.elevated, lineWidth: 14)
                    .frame(width: 160, height: 160)

                Circle()
                    .trim(from: 0, to: animateProgress ? viewModel.todayProgress : 0)
                    .stroke(
                        LinearGradient(
                            colors: [PepTheme.teal, PepTheme.teal.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 20))
                        .foregroundStyle(PepTheme.teal)

                    Text(formattedNumber(viewModel.todaySteps))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(PepTheme.textPrimary)
                        .contentTransition(.numericText())

                    Text("of \(formattedNumber(viewModel.stepGoal)) goal")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }

            HStack(spacing: 24) {
                todayMetric(
                    icon: "mappin.and.ellipse",
                    value: String(format: "%.2f", viewModel.distanceMiles),
                    unit: "mi",
                    color: .green
                )
                todayMetric(
                    icon: "arrow.up.right",
                    value: "\(viewModel.todayFlights)",
                    unit: "flights",
                    color: PepTheme.amber
                )
                todayMetric(
                    icon: "flame.fill",
                    value: "\(Int(viewModel.healthKit.activeCalories))",
                    unit: "cal",
                    color: .orange
                )
            }
        }
        .padding(20)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    LinearGradient(
                        colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
    }

    private func todayMetric(icon: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text(unit)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Period Selector

    private var periodSelector: some View {
        HStack(spacing: 2) {
            ForEach(StepTimePeriod.allCases) { period in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        viewModel.selectedPeriod = period
                    }
                } label: {
                    Text(period.rawValue)
                        .font(.system(size: 13, weight: viewModel.selectedPeriod == period ? .bold : .medium))
                        .foregroundStyle(viewModel.selectedPeriod == period ? PepTheme.invertedText : PepTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(viewModel.selectedPeriod == period ? PepTheme.teal : Color.clear)
                        .clipShape(.capsule)
                }
                .sensoryFeedback(.selection, trigger: viewModel.selectedPeriod)
                .simultaneousGesture(TapGesture().onEnded { selectedBarID = nil })
            }
        }
        .padding(3)
        .background(PepTheme.elevated)
        .clipShape(.capsule)
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(chartTitle)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                    Text(chartSubtitle)
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .top) {
                        chartBars(width: geo.size.width)
                        if let info = selectedInfo(totalWidth: geo.size.width) {
                            selectionCallout(info: info)
                                .offset(x: info.calloutX, y: 0)
                                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedBarID = nil
                        }
                    }
                }
                .frame(height: 170)
            }
        }
        .sensoryFeedback(.selection, trigger: selectedBarID)
        .onChange(of: viewModel.selectedPeriod) { _, _ in
            selectedBarID = nil
        }
    }

    private struct BarSelectionInfo {
        let title: String
        let subtitle: String?
        let value: Int
        let calloutX: CGFloat
        let calloutWidth: CGFloat
    }

    private func selectedInfo(totalWidth: CGFloat) -> BarSelectionInfo? {
        guard let id = selectedBarID else { return nil }
        let calloutWidth: CGFloat = 150
        switch viewModel.selectedPeriod {
        case .day:
            guard let idx = viewModel.hourlySteps.firstIndex(where: { $0.id == id }) else { return nil }
            let item = viewModel.hourlySteps[idx]
            let count = max(viewModel.hourlySteps.count, 1)
            let x = (totalWidth / CGFloat(count)) * (CGFloat(idx) + 0.5)
            let dayTotal = max(viewModel.todaySteps, 1)
            let pct = Double(item.steps) / Double(dayTotal) * 100
            return BarSelectionInfo(
                title: hourRangeLabel(hour: item.hour),
                subtitle: item.steps > 0 ? String(format: "%.1f%% of today", pct) : nil,
                value: item.steps,
                calloutX: clampX(x, totalWidth: totalWidth, calloutWidth: calloutWidth),
                calloutWidth: calloutWidth
            )
        case .week:
            let data = Array(viewModel.dailySteps.suffix(7))
            guard let idx = data.firstIndex(where: { $0.id == id }) else { return nil }
            let item = data[idx]
            let count = max(data.count, 1)
            let x = (totalWidth / CGFloat(count)) * (CGFloat(idx) + 0.5)
            return BarSelectionInfo(
                title: fullDateLabel(item.date),
                subtitle: item.steps >= viewModel.stepGoal ? "Goal reached" : "Goal \(formattedNumber(viewModel.stepGoal))",
                value: item.steps,
                calloutX: clampX(x, totalWidth: totalWidth, calloutWidth: calloutWidth),
                calloutWidth: calloutWidth
            )
        case .month:
            let data = Array(viewModel.dailySteps.suffix(30))
            guard let idx = data.firstIndex(where: { $0.id == id }) else { return nil }
            let item = data[idx]
            let count = max(data.count, 1)
            let x = (totalWidth / CGFloat(count)) * (CGFloat(idx) + 0.5)
            return BarSelectionInfo(
                title: fullDateLabel(item.date),
                subtitle: nil,
                value: item.steps,
                calloutX: clampX(x, totalWidth: totalWidth, calloutWidth: calloutWidth),
                calloutWidth: calloutWidth
            )
        case .sixMonths:
            let data = viewModel.weeklySteps
            guard let idx = data.firstIndex(where: { $0.id == id }) else { return nil }
            let item = data[idx]
            let count = max(data.count, 1)
            let x = (totalWidth / CGFloat(count)) * (CGFloat(idx) + 0.5)
            return BarSelectionInfo(
                title: weekRangeLabel(start: item.weekStart),
                subtitle: "Week total",
                value: item.steps,
                calloutX: clampX(x, totalWidth: totalWidth, calloutWidth: calloutWidth),
                calloutWidth: calloutWidth
            )
        case .year:
            let data = viewModel.monthlySteps
            guard let idx = data.firstIndex(where: { $0.id == id }) else { return nil }
            let item = data[idx]
            let count = max(data.count, 1)
            let x = (totalWidth / CGFloat(count)) * (CGFloat(idx) + 0.5)
            return BarSelectionInfo(
                title: item.fullLabel,
                subtitle: "Month total",
                value: item.steps,
                calloutX: clampX(x, totalWidth: totalWidth, calloutWidth: calloutWidth),
                calloutWidth: calloutWidth
            )
        }
    }

    private func clampX(_ x: CGFloat, totalWidth: CGFloat, calloutWidth: CGFloat) -> CGFloat {
        let half = calloutWidth / 2
        return min(max(x - half, 0), max(totalWidth - calloutWidth, 0))
    }

    private func selectionCallout(info: BarSelectionInfo) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(info.title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
                .lineLimit(1)
            Text(formattedNumber(info.value))
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
                .contentTransition(.numericText())
            Text(info.subtitle ?? "steps")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: info.calloutWidth, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(PepTheme.elevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(PepTheme.teal.opacity(0.4), lineWidth: 0.8)
                )
                .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
        )
    }

    private func hourRangeLabel(hour: Int) -> String {
        func hLabel(_ h: Int) -> String {
            let hour24 = ((h % 24) + 24) % 24
            let ampm = hour24 < 12 ? "AM" : "PM"
            let h12 = hour24 % 12 == 0 ? 12 : hour24 % 12
            return "\(h12) \(ampm)"
        }
        return "\(hLabel(hour)) – \(hLabel(hour + 1))"
    }

    private func fullDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

    private func weekRangeLabel(start: Date) -> String {
        let cal = Calendar.current
        let end = cal.date(byAdding: .day, value: 6, to: start) ?? start
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "\(f.string(from: start)) – \(f.string(from: end))"
    }

    private var chartTitle: String {
        switch viewModel.selectedPeriod {
        case .day: return "Today by Hour"
        case .week: return "Last 7 Days"
        case .month: return "Last 30 Days"
        case .sixMonths: return "Last 6 Months"
        case .year: return "Last 12 Months"
        }
    }

    private var chartSubtitle: String {
        "Avg \(formattedNumber(viewModel.averageSteps))/day"
    }

    @ViewBuilder
    private func chartBars(width: CGFloat) -> some View {
        switch viewModel.selectedPeriod {
        case .day:
            hourlyChart(width: width)
        case .week:
            dailyChart(data: Array(viewModel.dailySteps.suffix(7)), width: width, labelKey: \.shortLabel)
        case .month:
            dailyChart(data: Array(viewModel.dailySteps.suffix(30)), width: width, labelKey: nil)
        case .sixMonths:
            weeklyChart(width: width)
        case .year:
            monthlyChart(width: width)
        }
    }

    private func hourlyChart(width: CGFloat) -> some View {
        let data = viewModel.hourlySteps
        let maxVal = max(data.map(\.steps).max() ?? 1, 1)
        let barCount = max(data.count, 1)
        let spacing: CGFloat = 1
        let barWidth = max((width - spacing * CGFloat(barCount - 1)) / CGFloat(barCount), 2)

        return HStack(alignment: .bottom, spacing: spacing) {
            ForEach(data) { item in
                tappableBar(id: item.id, cornerRadius: 2, width: barWidth, height: max(barHeight(value: item.steps, maxValue: maxVal, height: 120), 2), value: item.steps, maxVal: maxVal, label: item.hour % 6 == 0 ? item.hourLabel : nil, labelSize: 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dailyChart<T: Identifiable>(data: [T], width: CGFloat, labelKey: KeyPath<T, String>?) -> some View where T: StepChartable, T.ID == UUID {
        let maxVal = max(data.map(\.chartSteps).max() ?? 1, 1)
        let barCount = max(data.count, 1)
        let spacing: CGFloat = data.count <= 7 ? 6 : 2
        let barWidth = max((width - spacing * CGFloat(barCount - 1)) / CGFloat(barCount), 3)
        let radius: CGFloat = data.count <= 7 ? 4 : 2

        return HStack(alignment: .bottom, spacing: spacing) {
            ForEach(data) { item in
                let label: String? = labelKey.map { item[keyPath: $0] }
                tappableBar(id: item.id, cornerRadius: radius, width: barWidth, height: max(barHeight(value: item.chartSteps, maxValue: maxVal, height: 110), 2), value: item.chartSteps, maxVal: maxVal, label: label, labelSize: 9)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func weeklyChart(width: CGFloat) -> some View {
        let data = viewModel.weeklySteps
        let maxVal = max(data.map(\.steps).max() ?? 1, 1)
        let barCount = max(data.count, 1)
        let spacing: CGFloat = 4
        let barWidth = max((width - spacing * CGFloat(barCount - 1)) / CGFloat(barCount), 4)

        return HStack(alignment: .bottom, spacing: spacing) {
            ForEach(Array(data.enumerated()), id: \.element.id) { idx, item in
                let showLabel = idx % 4 == 0
                tappableBar(id: item.id, cornerRadius: 3, width: barWidth, height: max(barHeight(value: item.steps, maxValue: maxVal, height: 110), 2), value: item.steps, maxVal: maxVal, label: showLabel ? item.label : nil, labelSize: 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func monthlyChart(width: CGFloat) -> some View {
        let data = viewModel.monthlySteps
        let maxVal = max(data.map(\.steps).max() ?? 1, 1)
        let barCount = max(data.count, 1)
        let spacing: CGFloat = 6
        let barWidth = max((width - spacing * CGFloat(barCount - 1)) / CGFloat(barCount), 6)

        return HStack(alignment: .bottom, spacing: spacing) {
            ForEach(data) { item in
                tappableBar(id: item.id, cornerRadius: 4, width: barWidth, height: max(barHeight(value: item.steps, maxValue: maxVal, height: 110), 2), value: item.steps, maxVal: maxVal, label: item.label, labelSize: 9)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func tappableBar(id: UUID, cornerRadius: CGFloat, width: CGFloat, height: CGFloat, value: Int, maxVal: Int, label: String?, labelSize: CGFloat) -> some View {
        let isSelected = selectedBarID == id
        let isDimmed = selectedBarID != nil && !isSelected
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(isSelected ? selectedBarFill() : barFill(for: value, max: maxVal))
                .frame(width: width, height: height)
                .opacity(isDimmed ? 0.35 : 1.0)
                .shadow(color: isSelected ? PepTheme.teal.opacity(0.6) : .clear, radius: isSelected ? 6 : 0)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: max(width + 4, 12))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedBarID = isSelected ? nil : id
                            }
                        }
                }

            if let label {
                Text(label)
                    .font(.system(size: labelSize, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
    }

    private func selectedBarFill() -> LinearGradient {
        LinearGradient(
            colors: [PepTheme.teal, PepTheme.teal.opacity(0.85)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func barHeight(value: Int, maxValue: Int, height: CGFloat) -> CGFloat {
        guard maxValue > 0 else { return 2 }
        return CGFloat(value) / CGFloat(maxValue) * height
    }

    private func barFill(for value: Int, max maxVal: Int) -> LinearGradient {
        let intensity = maxVal > 0 ? Double(value) / Double(maxVal) : 0
        return LinearGradient(
            colors: [
                PepTheme.teal.opacity(0.4 + intensity * 0.6),
                PepTheme.teal.opacity(0.2 + intensity * 0.4)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(
                title: "Average",
                value: formattedNumber(viewModel.averageSteps),
                subtitle: "steps/day",
                icon: "chart.line.uptrend.xyaxis",
                color: PepTheme.teal
            )
            statCard(
                title: "Total",
                value: formattedCompact(viewModel.totalStepsInPeriod),
                subtitle: "steps",
                icon: "sum",
                color: PepTheme.violet
            )
            statCard(
                title: "Best",
                value: formattedNumber(viewModel.maxStepsInPeriod),
                subtitle: periodUnitLabel,
                icon: "arrow.up",
                color: .green
            )
            statCard(
                title: "Lowest",
                value: formattedNumber(viewModel.minStepsInPeriod),
                subtitle: periodUnitLabel,
                icon: "arrow.down",
                color: PepTheme.amber
            )
        }
    }

    private var periodUnitLabel: String {
        switch viewModel.selectedPeriod {
        case .day: return "in an hour"
        case .week, .month: return "in a day"
        case .sixMonths: return "in a week"
        case .year: return "in a month"
        }
    }

    private func statCard(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(subtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    // MARK: - Today Breakdown

    private var todayBreakdownSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "clock.fill")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.teal)
                    SubheadText(text: "Hourly Breakdown")
                }

                let activeHours = viewModel.hourlySteps.filter { $0.steps > 0 }

                if activeHours.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "figure.walk")
                                .font(.title2)
                                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                            Text("No step data yet today")
                                .font(.subheadline)
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        .padding(.vertical, 12)
                        Spacer()
                    }
                } else {
                    let top5 = activeHours.sorted { $0.steps > $1.steps }.prefix(5)
                    ForEach(Array(top5)) { hour in
                        HStack(spacing: 12) {
                            Text(hour.hourLabel)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(PepTheme.textSecondary)
                                .frame(width: 44, alignment: .leading)

                            GeometryReader { geo in
                                let maxSteps = top5.map(\.steps).max() ?? 1
                                let ratio = CGFloat(hour.steps) / CGFloat(max(maxSteps, 1))
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(PepTheme.teal.opacity(0.3 + Double(ratio) * 0.5))
                                    .frame(width: geo.size.width * ratio)
                            }
                            .frame(height: 20)

                            Text(formattedNumber(hour.steps))
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .foregroundStyle(PepTheme.textPrimary)
                                .frame(width: 50, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Recent Days

    private var recentDaysSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.teal)
                    SubheadText(text: "Recent Days")
                }

                let recent = viewModel.dailySteps.suffix(7).reversed()

                if recent.isEmpty {
                    HStack {
                        Spacer()
                        Text("No historical data available")
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textSecondary)
                            .padding(.vertical, 12)
                        Spacer()
                    }
                } else {
                    ForEach(Array(recent)) { day in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dayLabel(for: day.date))
                                    .font(.system(.subheadline, weight: .semibold))
                                    .foregroundStyle(PepTheme.textPrimary)
                                Text(day.dateLabel)
                                    .font(.system(.caption2, weight: .medium))
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                            .frame(width: 80, alignment: .leading)

                            GeometryReader { geo in
                                let maxSteps = max(viewModel.stepGoal, viewModel.dailySteps.suffix(7).map(\.steps).max() ?? 1)
                                let ratio = min(CGFloat(day.steps) / CGFloat(max(maxSteps, 1)), 1.0)
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(PepTheme.elevated)

                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(day.steps >= viewModel.stepGoal
                                            ? LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                                            : LinearGradient(colors: [PepTheme.teal, PepTheme.teal.opacity(0.6)], startPoint: .leading, endPoint: .trailing)
                                        )
                                        .frame(width: geo.size.width * ratio)
                                }
                            }
                            .frame(height: 22)

                            Text(formattedNumber(day.steps))
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .foregroundStyle(day.steps >= viewModel.stepGoal ? .green : PepTheme.textPrimary)
                                .frame(width: 50, alignment: .trailing)
                        }

                        if day.id != recent.last?.id {
                            Divider().overlay(PepTheme.shimmerHighlight)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func formattedNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func formattedCompact(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 10_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return formattedNumber(value)
    }

    private func dayLabel(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}

protocol StepChartable {
    var chartSteps: Int { get }
}

extension DailyStepData: StepChartable {
    var chartSteps: Int { steps }
}
