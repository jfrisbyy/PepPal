import SwiftUI
import Charts

/// Side-by-side comparison of two or more cycles with overlaid trend charts and
/// protocol phase overlays. Lives at its own destination so the floating chrome
/// system can capture it cleanly for marketing.
struct CycleComparisonView: View {
    let cycles: [PeptideProtocol]

    @State private var selectedMetric: CycleMetric = .weight
    @State private var alignment: AxisAlignment = .cycleWeek
    @State private var weightEntries: [WeightEntry] = []
    @State private var sleepLogs: [ManualSleepLog] = []
    @State private var bloodwork: [BloodworkEntry] = []
    @State private var workouts: [WorkoutHistoryDetail] = []
    @State private var isLoading: Bool = true
    @State private var scrubFraction: Double? = nil

    @Environment(\.dismiss) private var dismiss

    enum AxisAlignment: String, CaseIterable, Identifiable {
        case cycleWeek = "Cycle Week"
        case calendar = "Calendar"
        var id: String { rawValue }
        var short: String { self == .cycleWeek ? "By week" : "By date" }
        var icon: String { self == .cycleWeek ? "ruler" : "calendar" }
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                editorialHeader
                metricStrip
                heroChartCard
                comparisonCards
                insightsCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)
            .padding(.bottom, 60)
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) {
            floatingBackButton
                .padding(.top, 6)
                .padding(.leading, 14)
        }
        .overlay(alignment: .topTrailing) {
            alignmentToggle
                .padding(.top, 6)
                .padding(.trailing, 14)
        }
        .task { await loadAll() }
    }

    // MARK: Header

    private var editorialHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("CYCLE COMPARISON")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.2)
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                Text("\(cycles.count) cycles · \(selectedMetric.shortLabel)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(PepTheme.textTertiary)
            }
            Text(headlineTitle)
                .font(.system(.title, design: .serif, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            LinearGradient(
                colors: [
                    PepTheme.textPrimary.opacity(0.18),
                    PepTheme.textPrimary.opacity(0.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 0.5)

            HStack(spacing: 10) {
                ForEach(Array(orderedCycles.enumerated()), id: \.element.id) { idx, cycle in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(cycleColor(idx))
                            .frame(width: 8, height: 8)
                        Text(cycle.name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
        }
    }

    private var headlineTitle: String {
        let names = orderedCycles.map(\.name)
        if names.count == 2 {
            return "\(names[0]) vs \(names[1])"
        }
        return names.joined(separator: " · ")
    }

    // MARK: Metric strip

    private var metricStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CycleMetric.allCases) { metric in
                    metricPill(metric)
                }
            }
            .padding(.vertical, 4)
        }
        .contentMargins(.horizontal, 0)
    }

    private func metricPill(_ metric: CycleMetric) -> some View {
        let isOn = selectedMetric == metric
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                selectedMetric = metric
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: metric.icon)
                    .font(.system(size: 10, weight: .bold))
                Text(metric.label)
                    .font(.system(.caption, weight: .bold))
            }
            .foregroundStyle(isOn ? .white : metric.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isOn ? metric.color : metric.color.opacity(0.12))
            )
            .overlay(
                Capsule()
                    .strokeBorder(metric.color.opacity(isOn ? 0 : 0.25), lineWidth: 0.6)
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selectedMetric)
    }

    // MARK: Hero chart card

    private var heroChartCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(selectedMetric.label.uppercased())
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(1.6)
                            .foregroundStyle(PepTheme.textSecondary)
                        Text(selectedMetric.tagline)
                            .font(.system(.subheadline, design: .serif))
                            .italic()
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    Spacer()
                    Text(alignment == .cycleWeek ? "Aligned by Week 1" : "Calendar dates")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.0)
                        .foregroundStyle(PepTheme.textTertiary)
                }

                trendChart
                    .frame(height: 220)
                    .animation(.spring(response: 0.55, dampingFraction: 0.85), value: selectedMetric)
                    .animation(.spring(response: 0.55, dampingFraction: 0.85), value: alignment)

                phaseLegend
            }
        }
    }

    @ViewBuilder
    private var trendChart: some View {
        let plotted = plottedSeries
        if plotted.allSatisfy(\.points.isEmpty) {
            emptyChartHint
        } else {
            Chart {
                // Phase bands - one set per cycle layered with low opacity
                ForEach(Array(orderedCycles.enumerated()), id: \.element.id) { idx, cycle in
                    let bands = phaseBands(for: cycle, idx: idx)
                    ForEach(bands) { band in
                        RectangleMark(
                            xStart: .value("start", band.startX),
                            xEnd: .value("end", band.endX),
                            yStart: .value("y0", 0.0),
                            yEnd: .value("y1", 1.0)
                        )
                        .foregroundStyle(band.phase.color.opacity(0.07))
                    }
                }

                // Dose-change & phase markers
                ForEach(Array(orderedCycles.enumerated()), id: \.element.id) { idx, cycle in
                    let marks = transitionMarks(for: cycle, idx: idx)
                    ForEach(marks) { m in
                        RuleMark(x: .value("tick", m.x))
                            .foregroundStyle(cycleColor(idx).opacity(0.35))
                            .lineStyle(StrokeStyle(lineWidth: 0.6, dash: [2, 3]))
                    }
                }

                // Cycle line/area per series
                ForEach(plotted) { series in
                    ForEach(series.points) { p in
                        LineMark(
                            x: .value("x", p.x),
                            y: .value("y", p.normalized)
                        )
                        .foregroundStyle(series.color)
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round))
                    }
                    .symbol {
                        Circle()
                            .fill(series.color)
                            .frame(width: 4, height: 4)
                    }
                    .symbolSize(20)
                }

                if let scrubFraction {
                    RuleMark(x: .value("scrub", scrubFraction))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                }
            }
            .chartYScale(domain: -0.05...1.08)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisValueLabel {
                        if let d = value.as(Double.self) {
                            Text(xAxisLabel(for: d))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(PepTheme.textTertiary)
                        }
                    }
                    AxisGridLine()
                        .foregroundStyle(PepTheme.elevated.opacity(0.3))
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(.rect)
                        .gesture(
                            DragGesture(minimumDistance: 4)
                                .onChanged { value in
                                    let plotFrame = geo[proxy.plotAreaFrame]
                                    let x = max(0, min(plotFrame.width, value.location.x - plotFrame.minX))
                                    if let frac: Double = proxy.value(atX: x) {
                                        scrubFraction = frac
                                    }
                                }
                                .onEnded { _ in
                                    withAnimation(.easeOut(duration: 0.25)) { scrubFraction = nil }
                                }
                        )
                }
            }
            .overlay(alignment: .topLeading) {
                if let scrubFraction {
                    scrubReadout(at: scrubFraction)
                        .padding(.top, 6)
                        .padding(.leading, 10)
                }
            }
        }
    }

    private var emptyChartHint: some View {
        VStack(spacing: 8) {
            Image(systemName: selectedMetric.icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(selectedMetric.color.opacity(0.6))
            Text("No \(selectedMetric.label.lowercased()) data yet")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
            Text("Log a few entries during your cycles and they'll plot here.")
                .font(.caption)
                .foregroundStyle(PepTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
    }

    private var phaseLegend: some View {
        HStack(spacing: 14) {
            ForEach(CyclePhase.allCases, id: \.self) { phase in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(phase.color.opacity(0.55))
                        .frame(width: 14, height: 4)
                    Text(phase.rawValue)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            Spacer()
        }
    }

    // MARK: Comparison cards

    private var comparisonCards: some View {
        VStack(spacing: 10) {
            ForEach(Array(orderedCycles.enumerated()), id: \.element.id) { idx, cycle in
                comparisonCard(idx: idx, cycle: cycle)
            }
        }
    }

    private func comparisonCard(idx: Int, cycle: PeptideProtocol) -> some View {
        let color = cycleColor(idx)
        let stats = cycleStats(cycle)
        return GlassCard(accent: color) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Circle().fill(color).frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(cycle.name)
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                            .lineLimit(1)
                        Text(cycleDateRange(cycle))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(PepTheme.textTertiary)
                    }
                    Spacer()
                    if cycle.isActive {
                        Text("ACTIVE")
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(0.8)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(color, in: .capsule)
                    }
                }

                Text(stats.headline)
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)

                Text(stats.takeaway)
                    .font(.system(.subheadline))
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineLimit(3)

                HStack(spacing: 14) {
                    statCell("Adherence", value: "\(stats.adherencePct)%")
                    statDivider
                    statCell("Doses", value: "\(stats.totalDoses)")
                    statDivider
                    statCell("Side fx", value: "\(stats.sideEffectCount)")
                    statDivider
                    statCell("Weeks", value: "\(stats.weeksRun)")
                }
            }
        }
    }

    private func statCell(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(PepTheme.textPrimary)
            Text(label.uppercased())
                .font(.system(size: 8, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(PepTheme.textTertiary)
        }
    }

    private var statDivider: some View {
        Rectangle()
            .fill(PepTheme.textPrimary.opacity(0.08))
            .frame(width: 0.5, height: 24)
    }

    // MARK: Insights

    private var insightsCard: some View {
        GlassCard(accent: PepTheme.teal) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PepTheme.teal)
                    Text("THE TAKEAWAY")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.6)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Text(narrativeInsight)
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineSpacing(2)
            }
        }
    }

    // MARK: Floating chrome

    private var floatingBackButton: some View {
        Button { dismiss() } label: {
            ZStack {
                Circle()
                    .fill(PepTheme.cardSurface)
                    .frame(width: 36, height: 36)
                    .overlay(Circle().strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.6))
                    .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
            }
        }
        .buttonStyle(.plain)
    }

    private var alignmentToggle: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                alignment = alignment == .cycleWeek ? .calendar : .cycleWeek
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: alignment.icon)
                    .font(.system(size: 11, weight: .bold))
                Text(alignment.short)
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(PepTheme.textPrimary)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(PepTheme.cardSurface)
                    .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
            )
            .overlay(Capsule().strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.6))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: alignment)
    }

    // MARK: Data loading

    private func loadAll() async {
        isLoading = true
        defer { isLoading = false }

        // Weights: lean on BodyGoalViewModel since it already handles the demo+real path.
        let bg = BodyGoalViewModel()
        await bg.refresh()
        weightEntries = bg.weightEntries

        // Bloodwork & sleep: from real services if user is authenticated;
        // demo personas already populated singletons elsewhere — but for our
        // own compare view we go straight to the source so we get the same
        // dataset whether the user is logged in or running a demo persona.
        if let userId = try? AuthService.shared.currentUserId() {
            // Bloodwork
            if let supaEntries = try? await BloodworkService.shared.fetchEntries(userId: userId) {
                var loaded: [BloodworkEntry] = []
                for entry in supaEntries {
                    let entryId = entry.id ?? ""
                    let results = (try? await BloodworkService.shared.fetchBiomarkerResults(entryId: entryId)) ?? []
                    loaded.append(BloodworkService.shared.toBloodworkEntry(entry, results: results))
                }
                bloodwork = loaded
            }
            // Sleep
            if let rows = try? await ManualSleepLogService.shared.fetch(userId: userId, days: 365) {
                var out: [ManualSleepLog] = []
                for r in rows {
                    guard let nightDate = ManualSleepLogService.parseNight(r.night) else { continue }
                    out.append(ManualSleepLog(
                        night: nightDate,
                        bedtime: ManualSleepLogService.parseDateTime(r.bedtime),
                        wakeTime: ManualSleepLogService.parseDateTime(r.wake_time),
                        hours: r.hours,
                        quality: r.quality,
                        notes: r.notes,
                        supabaseId: r.id
                    ))
                }
                sleepLogs = out
            }
        }
    }

    // MARK: Ordering & colors

    /// Orders by start date so "Cycle 1" appears first.
    private var orderedCycles: [PeptideProtocol] {
        cycles.sorted { $0.startDate < $1.startDate }
    }

    private static let palette: [Color] = [
        PepTheme.teal, PepTheme.violet, PepTheme.amber, PepTheme.blue, PepTheme.coral
    ]

    private func cycleColor(_ idx: Int) -> Color {
        Self.palette[idx % Self.palette.count]
    }

    // MARK: Plotted series

    private struct PlottedPoint: Identifiable {
        let id = UUID()
        let x: Double         // either 0...1 (cycleWeek normalized) or epoch seconds (calendar)
        let normalized: Double // 0...1
    }

    private struct PlottedSeries: Identifiable {
        let id: UUID
        let color: Color
        let points: [PlottedPoint]
        let rawMin: Double
        let rawMax: Double
    }

    private var plottedSeries: [PlottedSeries] {
        let raw = orderedCycles.enumerated().map { idx, cycle in
            (idx, cycle, rawPoints(for: cycle))
        }
        // Find global min/max so all cycles share a vertical scale per metric.
        let allValues = raw.flatMap { $0.2.map(\.1) }
        let globalMin = allValues.min() ?? 0
        let globalMax = allValues.max() ?? 1
        let span = max(0.0001, globalMax - globalMin)

        return raw.map { idx, cycle, points in
            let mapped: [PlottedPoint] = points.map { (date, value) in
                let xValue: Double = {
                    switch alignment {
                    case .cycleWeek:
                        let totalWeeks = Double(max(1, cycle.effectiveTotalWeeks))
                        let weeks = date.timeIntervalSince(cycle.startDate) / (7 * 86400)
                        return min(1.05, max(-0.02, weeks / totalWeeks))
                    case .calendar:
                        return date.timeIntervalSinceReferenceDate
                    }
                }()
                let norm = (value - globalMin) / span
                return PlottedPoint(x: xValue, normalized: norm)
            }
            return PlottedSeries(id: cycle.id, color: cycleColor(idx), points: mapped, rawMin: globalMin, rawMax: globalMax)
        }
    }

    /// Returns raw (date, value) pairs for the selected metric, scoped to the
    /// cycle's lifespan.
    private func rawPoints(for cycle: PeptideProtocol) -> [(Date, Double)] {
        let end = cycle.isActive ? Date() : cycle.startDate.addingTimeInterval(Double(cycle.effectiveTotalWeeks) * 7 * 86400)
        let inRange: (Date) -> Bool = { d in d >= cycle.startDate && d <= end }

        switch selectedMetric {
        case .weight:
            return weightEntries
                .filter { inRange($0.date) }
                .sorted { $0.date < $1.date }
                .map { ($0.date, $0.weight) }

        case .igf1:
            return biomarkerSeries(for: .igf1, cycle: cycle, in: inRange)

        case .glucose:
            return biomarkerSeries(for: .fastingGlucose, cycle: cycle, in: inRange)

        case .sideEffects:
            // Weekly count of side effects within cycle.
            let cal = Calendar.current
            let weeks = cycle.effectiveTotalWeeks
            var out: [(Date, Double)] = []
            for w in 0...weeks {
                guard let weekStart = cal.date(byAdding: .day, value: w * 7, to: cycle.startDate),
                      let weekEnd = cal.date(byAdding: .day, value: (w + 1) * 7, to: cycle.startDate) else { continue }
                if weekStart > end { break }
                let count = cycle.sideEffectLog.filter { $0.timestamp >= weekStart && $0.timestamp < weekEnd }.count
                out.append((weekStart, Double(count)))
            }
            return out

        case .sleep:
            return sleepLogs
                .filter { inRange($0.night) }
                .sorted { $0.night < $1.night }
                .map { ($0.night, $0.hours) }

        case .volume:
            // Weekly sum of training volume (lbs).
            let cal = Calendar.current
            let weeks = cycle.effectiveTotalWeeks
            var out: [(Date, Double)] = []
            for w in 0...weeks {
                guard let weekStart = cal.date(byAdding: .day, value: w * 7, to: cycle.startDate),
                      let weekEnd = cal.date(byAdding: .day, value: (w + 1) * 7, to: cycle.startDate) else { continue }
                if weekStart > end { break }
                let v = workouts
                    .filter { $0.date >= weekStart && $0.date < weekEnd }
                    .reduce(0) { $0 + $1.totalVolume }
                if v > 0 {
                    out.append((weekStart, Double(v)))
                }
            }
            return out

        case .cumulativeDose:
            // Running sum of dose mcg per logged (non-skipped) entry.
            let sorted = cycle.doseLog
                .filter { !$0.wasSkipped && inRange($0.timestamp) }
                .sorted { $0.timestamp < $1.timestamp }
            var running = 0.0
            return sorted.map { entry in
                running += entry.doseMcg
                return (entry.timestamp, running)
            }
        }
    }

    private func biomarkerSeries(for marker: Biomarker, cycle: PeptideProtocol, in inRange: (Date) -> Bool) -> [(Date, Double)] {
        bloodwork
            .filter { inRange($0.date) }
            .compactMap { entry -> (Date, Double)? in
                guard let res = entry.results.first(where: { $0.biomarker == marker }) else { return nil }
                return (entry.date, res.value)
            }
            .sorted { $0.0 < $1.0 }
    }

    // MARK: Phase bands & transition marks

    private struct PhaseBand: Identifiable {
        let id = UUID()
        let phase: CyclePhase
        let startX: Double
        let endX: Double
    }

    private struct TransitionMark: Identifiable {
        let id = UUID()
        let x: Double
    }

    private func phaseBands(for cycle: PeptideProtocol, idx: Int) -> [PhaseBand] {
        guard cycle.hasPhases else { return [] }
        let total = Double(max(1, cycle.effectiveTotalWeeks))
        let lw = Double(cycle.loadingWeeks ?? 0)
        let mw = Double(cycle.maintenanceWeeks ?? 0)
        let tw = Double(cycle.taperingWeeks ?? 0)
        let ow = Double(cycle.offCycleWeeks ?? 0)

        var bands: [PhaseBand] = []
        var cursor: Double = 0

        func add(_ weeks: Double, _ phase: CyclePhase) {
            guard weeks > 0 else { return }
            let start = cursor
            cursor += weeks
            let s = projectX(weeks: start, total: total, cycle: cycle)
            let e = projectX(weeks: cursor, total: total, cycle: cycle)
            bands.append(PhaseBand(phase: phase, startX: s, endX: e))
        }
        add(lw, .loading)
        add(mw, .maintenance)
        add(tw, .tapering)
        add(ow, .offCycle)
        return bands
    }

    private func transitionMarks(for cycle: PeptideProtocol, idx: Int) -> [TransitionMark] {
        var marks: [TransitionMark] = []
        let total = Double(max(1, cycle.effectiveTotalWeeks))
        let phaseWeeks: [Double] = [
            Double(cycle.loadingWeeks ?? 0),
            Double(cycle.maintenanceWeeks ?? 0),
            Double(cycle.taperingWeeks ?? 0)
        ]
        var running: Double = 0
        for w in phaseWeeks where w > 0 {
            running += w
            marks.append(TransitionMark(x: projectX(weeks: running, total: total, cycle: cycle)))
        }
        // Dose-change marks (when a logged dose differs from the previous one).
        let sortedDoses = cycle.doseLog
            .filter { !$0.wasSkipped }
            .sorted { $0.timestamp < $1.timestamp }
        var lastByCompound: [String: Double] = [:]
        for dose in sortedDoses {
            if let last = lastByCompound[dose.compoundName], abs(last - dose.doseMcg) > 0.01 {
                let weeksIn = dose.timestamp.timeIntervalSince(cycle.startDate) / (7 * 86400)
                marks.append(TransitionMark(x: projectX(weeks: weeksIn, total: total, cycle: cycle)))
            }
            lastByCompound[dose.compoundName] = dose.doseMcg
        }
        return marks
    }

    private func projectX(weeks: Double, total: Double, cycle: PeptideProtocol) -> Double {
        switch alignment {
        case .cycleWeek:
            return min(1.05, max(0, weeks / total))
        case .calendar:
            return cycle.startDate.addingTimeInterval(weeks * 7 * 86400).timeIntervalSinceReferenceDate
        }
    }

    // MARK: X axis labels

    private func xAxisLabel(for x: Double) -> String {
        switch alignment {
        case .cycleWeek:
            let totalAvg = orderedCycles.map { Double($0.effectiveTotalWeeks) }.reduce(0, +) / Double(max(1, orderedCycles.count))
            let week = Int((x * totalAvg).rounded())
            return "W\(max(0, week))"
        case .calendar:
            let date = Date(timeIntervalSinceReferenceDate: x)
            let f = DateFormatter()
            f.dateFormat = "MMM yy"
            return f.string(from: date)
        }
    }

    // MARK: Scrub readout

    private func scrubReadout(at fraction: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(scrubTitle(at: fraction))
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(PepTheme.textPrimary)
            ForEach(Array(plottedSeries.enumerated()), id: \.element.id) { idx, series in
                if let value = nearestRaw(in: series, x: fraction, cycle: orderedCycles[idx]) {
                    HStack(spacing: 5) {
                        Circle().fill(series.color).frame(width: 6, height: 6)
                        Text(formatValue(value))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(PepTheme.textPrimary)
                    }
                }
            }
        }
        .padding(8)
        .background(PepTheme.background.opacity(0.92), in: .rect(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private func scrubTitle(at fraction: Double) -> String {
        switch alignment {
        case .cycleWeek:
            let totalAvg = orderedCycles.map { Double($0.effectiveTotalWeeks) }.reduce(0, +) / Double(max(1, orderedCycles.count))
            return "Week \(Int((fraction * totalAvg).rounded()))"
        case .calendar:
            let f = DateFormatter()
            f.dateStyle = .medium
            return f.string(from: Date(timeIntervalSinceReferenceDate: fraction))
        }
    }

    private func nearestRaw(in series: PlottedSeries, x: Double, cycle: PeptideProtocol) -> Double? {
        guard let nearest = series.points.min(by: { abs($0.x - x) < abs($1.x - x) }) else { return nil }
        let span = max(0.0001, series.rawMax - series.rawMin)
        return series.rawMin + nearest.normalized * span
    }

    private func formatValue(_ value: Double) -> String {
        switch selectedMetric {
        case .weight: return String(format: "%.1f lb", value)
        case .igf1: return String(format: "%.0f ng/mL", value)
        case .glucose: return String(format: "%.0f mg/dL", value)
        case .sideEffects: return "\(Int(value)) /wk"
        case .sleep: return String(format: "%.1fh", value)
        case .volume: return "\(Int(value / 1000))k lb"
        case .cumulativeDose:
            if value >= 1000 { return String(format: "%.1f mg", value / 1000) }
            return String(format: "%.0f mcg", value)
        }
    }

    // MARK: Per-cycle stats

    private struct CycleStats {
        let headline: String
        let takeaway: String
        let adherencePct: Int
        let totalDoses: Int
        let sideEffectCount: Int
        let weeksRun: Int
    }

    private func cycleStats(_ cycle: PeptideProtocol) -> CycleStats {
        let logged = cycle.doseLog.filter { !$0.wasSkipped }
        let scheduled = cycle.doseLog.count
        let adherence = scheduled > 0 ? Int(Double(logged.count) / Double(scheduled) * 100) : 0
        let weeksRun = max(1, cycle.currentDay / 7)

        let raw = rawPoints(for: cycle)
        let metricLabel = selectedMetric.label

        let headline: String
        let takeaway: String
        if let first = raw.first?.1, let last = raw.last?.1, !raw.isEmpty {
            let delta = last - first
            let pct = first != 0 ? (delta / abs(first)) * 100 : 0
            let arrow = delta >= 0 ? "↑" : "↓"
            switch selectedMetric {
            case .weight:
                headline = String(format: "%@ %.1f lb", arrow, abs(delta))
                takeaway = "From \(String(format: "%.1f", first)) to \(String(format: "%.1f", last)) over \(raw.count) weigh-ins."
            case .igf1, .glucose:
                headline = String(format: "%@ %.0f %@ (%@%.0f%%)", arrow, abs(delta), selectedMetric.unitLabel, delta >= 0 ? "+" : "-", abs(pct))
                takeaway = "\(metricLabel) trended from \(Int(first)) to \(Int(last)) \(selectedMetric.unitLabel)."
            case .sideEffects:
                let total = cycle.sideEffectLog.count
                headline = "\(total) side effect\(total == 1 ? "" : "s")"
                takeaway = total == 0 ? "Clean cycle — no side effects logged." : "Peaked at \(Int(raw.map(\.1).max() ?? 0))/week."
            case .sleep:
                let avg = raw.reduce(0.0) { $0 + $1.1 } / Double(raw.count)
                headline = String(format: "%.1fh avg sleep", avg)
                takeaway = "Across \(raw.count) tracked nights during this cycle."
            case .volume:
                let total = raw.reduce(0.0) { $0 + $1.1 } / 1000
                headline = "\(Int(total))k lb total"
                takeaway = "Cumulative training volume logged within this cycle."
            case .cumulativeDose:
                let total = raw.last?.1 ?? 0
                let display: String = total >= 1000 ? String(format: "%.1f mg", total / 1000) : String(format: "%.0f mcg", total)
                headline = "\(display) delivered"
                takeaway = "\(logged.count) doses across \(weeksRun) week\(weeksRun == 1 ? "" : "s")."
            }
        } else {
            headline = "No \(metricLabel.lowercased()) data"
            takeaway = "Nothing logged for this metric during this cycle."
        }

        return CycleStats(
            headline: headline,
            takeaway: takeaway,
            adherencePct: adherence,
            totalDoses: logged.count,
            sideEffectCount: cycle.sideEffectLog.count,
            weeksRun: weeksRun
        )
    }

    private func cycleDateRange(_ cycle: PeptideProtocol) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        let start = f.string(from: cycle.startDate)
        if cycle.isActive { return "\(start) → now" }
        let end = cycle.startDate.addingTimeInterval(Double(cycle.effectiveTotalWeeks) * 7 * 86400)
        return "\(start) → \(f.string(from: end))"
    }

    // MARK: Narrative insight

    private var narrativeInsight: String {
        guard orderedCycles.count >= 2 else {
            return "Add a second cycle from Protocol History to compare side by side."
        }
        let statsList = orderedCycles.map { cycleStats($0) }
        guard let first = statsList.first, let last = statsList.last else { return "" }

        let metric = selectedMetric.label.lowercased()
        let firstName = orderedCycles.first?.name ?? "Cycle 1"
        let lastName = orderedCycles.last?.name ?? "Cycle 2"

        // Compare side-effect load and adherence as the universal signal.
        let sideFxDelta = last.sideEffectCount - first.sideEffectCount
        let adhDelta = last.adherencePct - first.adherencePct

        var pieces: [String] = []
        pieces.append("\(lastName) shows \(metric) trends overlaid against \(firstName).")
        if adhDelta >= 5 {
            pieces.append("Adherence is up \(adhDelta) points — your cadence is sharper this time.")
        } else if adhDelta <= -5 {
            pieces.append("Adherence is down \(abs(adhDelta)) points — worth a look.")
        }
        if sideFxDelta <= -2 {
            pieces.append("Side-effect entries dropped by \(abs(sideFxDelta)) — body's tolerating this cycle better.")
        } else if sideFxDelta >= 2 {
            pieces.append("Side-effect entries are up \(sideFxDelta) — consider revisiting dose or timing.")
        }
        return pieces.joined(separator: " ")
    }
}

// MARK: - Metric enum

nonisolated enum CycleMetric: String, CaseIterable, Identifiable, Sendable {
    case weight
    case igf1
    case glucose
    case sideEffects
    case sleep
    case volume
    case cumulativeDose

    var id: String { rawValue }

    var label: String {
        switch self {
        case .weight: return "Weight"
        case .igf1: return "IGF-1"
        case .glucose: return "Glucose"
        case .sideEffects: return "Side Effects"
        case .sleep: return "Sleep"
        case .volume: return "Volume"
        case .cumulativeDose: return "Cumulative Dose"
        }
    }

    var shortLabel: String {
        switch self {
        case .cumulativeDose: return "cum. dose"
        default: return label.lowercased()
        }
    }

    var icon: String {
        switch self {
        case .weight: return "scalemass.fill"
        case .igf1: return "waveform.path.ecg"
        case .glucose: return "drop.fill"
        case .sideEffects: return "exclamationmark.triangle.fill"
        case .sleep: return "bed.double.fill"
        case .volume: return "dumbbell.fill"
        case .cumulativeDose: return "syringe.fill"
        }
    }

    var color: Color {
        switch self {
        case .weight: return PepTheme.blue
        case .igf1: return PepTheme.teal
        case .glucose: return PepTheme.amber
        case .sideEffects: return PepTheme.coral
        case .sleep: return PepTheme.violet
        case .volume: return PepTheme.coral
        case .cumulativeDose: return PepTheme.teal
        }
    }

    var unitLabel: String {
        switch self {
        case .weight: return "lb"
        case .igf1: return "ng/mL"
        case .glucose: return "mg/dL"
        case .sideEffects: return "/wk"
        case .sleep: return "h"
        case .volume: return "lb"
        case .cumulativeDose: return "mcg"
        }
    }

    var tagline: String {
        switch self {
        case .weight: return "Body weight aligned across cycles."
        case .igf1: return "Hormonal response, side-by-side."
        case .glucose: return "Insulin sensitivity over time."
        case .sideEffects: return "Weekly side-effect frequency."
        case .sleep: return "Sleep duration during each cycle."
        case .volume: return "Weekly training volume."
        case .cumulativeDose: return "Running total of dose delivered."
        }
    }
}
