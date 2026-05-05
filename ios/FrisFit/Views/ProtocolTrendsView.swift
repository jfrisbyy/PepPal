import SwiftUI
import Charts
import HealthKit

struct ProtocolTrendsView: View {
    let protocolData: PeptideProtocol
    @Environment(\.dismiss) private var dismiss
    @State private var healthKit = HealthKitService.shared

    enum TimeRange: String, CaseIterable, Identifiable {
        case week = "7D", month = "1M", quarter = "3M", half = "6M", all = "All"
        var id: String { rawValue }
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .quarter: return 90
            case .half: return 180
            case .all: return 3650
            }
        }
    }

    enum MetricLayer: String, CaseIterable, Identifiable {
        case doses = "Doses"
        case weight = "Weight"
        case hrv = "HRV"
        case rhr = "Resting HR"
        case sleep = "Sleep"
        case sideEffects = "Side effects"

        var id: String { rawValue }
        var color: Color {
            switch self {
            case .doses: return PepTheme.teal
            case .weight: return .blue
            case .hrv: return .pink
            case .rhr: return .red
            case .sleep: return .purple
            case .sideEffects: return PepTheme.amber
            }
        }
        var icon: String {
            switch self {
            case .doses: return "syringe.fill"
            case .weight: return "scalemass.fill"
            case .hrv: return "waveform.path.ecg"
            case .rhr: return "heart.fill"
            case .sleep: return "bed.double.fill"
            case .sideEffects: return "exclamationmark.triangle.fill"
            }
        }
    }

    @State private var range: TimeRange = .month
    @State private var visibleLayers: Set<MetricLayer> = [.doses, .weight, .hrv, .sleep]
    @State private var scrubDate: Date? = nil
    @State private var tappedDose: DoseLogEntry? = nil
    @State private var tappedDosePoint: CGPoint? = nil
    @State private var detailVM: ProtocolDetailViewModel
    @State private var healthWeights: [DatedValue] = []
    @State private var healthHRV: [DatedValue] = []
    @State private var healthRHR: [DatedValue] = []
    @State private var healthSleep: [DatedValue] = []
    @State private var isLoadingHealth: Bool = false

    nonisolated struct DatedValue: Identifiable, Sendable {
        let id: UUID = UUID()
        let date: Date
        let value: Double
    }

    init(protocolData: PeptideProtocol) {
        self.protocolData = protocolData
        _detailVM = State(initialValue: ProtocolDetailViewModel(protocolData: protocolData))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                timeRangeSelector
                layersStrip
                chartCard
                calloutsCard
                exportRow
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .navigationTitle("Trends")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { dismiss() }
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .task { await loadHealthData() }
        .onChange(of: range) { _, _ in Task { await loadHealthData() } }
        .sheet(item: $detailVM.editingDose) { dose in
            EditDoseSheet(viewModel: detailVM, dose: dose)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $detailVM.showSideEffectSheet) {
            LogSideEffectSheet(viewModel: detailVM)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear { detailVM.refreshFromSupabase() }
    }

    // MARK: - Header

    private var headerCard: some View {
        GlassCard(accent: PepTheme.teal) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(PepTheme.teal.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(PepTheme.teal)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(protocolData.name)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(1)
                    Text("\(doseCountInRange) doses · \(protocolData.sideEffectLog.filter { $0.timestamp >= rangeStart }.count) side effects · \(protocolData.currentDay)d in")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Spacer()
            }
        }
    }

    private var timeRangeSelector: some View {
        HStack(spacing: 6) {
            ForEach(TimeRange.allCases) { r in
                Button {
                    withAnimation(.spring(response: 0.3)) { range = r }
                } label: {
                    Text(r.rawValue)
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(range == r ? .white : PepTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(range == r ? PepTheme.teal : PepTheme.elevated.opacity(0.6))
                        .clipShape(.capsule)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var layersStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MetricLayer.allCases) { layer in
                    let isOn = visibleLayers.contains(layer)
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            if isOn { visibleLayers.remove(layer) } else { visibleLayers.insert(layer) }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: layer.icon)
                                .font(.system(size: 10, weight: .bold))
                            Text(layer.rawValue)
                                .font(.system(.caption, weight: .bold))
                        }
                        .foregroundStyle(isOn ? .white : layer.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isOn ? layer.color : layer.color.opacity(0.14))
                        .clipShape(.capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .contentMargins(.horizontal, 0)
    }

    // MARK: - Chart

    private var chartCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("TIMELINE")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.2)
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                    if isLoadingHealth {
                        ProgressView().controlSize(.mini)
                    }
                }
                Chart {
                    if visibleLayers.contains(.weight) {
                        ForEach(clip(healthWeights)) { p in
                            LineMark(x: .value("Date", p.date), y: .value("Weight", normalize(p.value, in: healthWeights)))
                                .foregroundStyle(MetricLayer.weight.color)
                                .interpolationMethod(.monotone)
                        }
                    }
                    if visibleLayers.contains(.hrv) {
                        ForEach(clip(healthHRV)) { p in
                            LineMark(x: .value("Date", p.date), y: .value("HRV", normalize(p.value, in: healthHRV)))
                                .foregroundStyle(MetricLayer.hrv.color)
                                .interpolationMethod(.monotone)
                        }
                    }
                    if visibleLayers.contains(.rhr) {
                        ForEach(clip(healthRHR)) { p in
                            LineMark(x: .value("Date", p.date), y: .value("RHR", normalize(p.value, in: healthRHR, inverse: true)))
                                .foregroundStyle(MetricLayer.rhr.color)
                                .interpolationMethod(.monotone)
                        }
                    }
                    if visibleLayers.contains(.sleep) {
                        ForEach(clip(healthSleep)) { p in
                            AreaMark(x: .value("Date", p.date), y: .value("Sleep", p.value / 10.0))
                                .foregroundStyle(MetricLayer.sleep.color.opacity(0.2))
                                .interpolationMethod(.monotone)
                        }
                    }
                    if visibleLayers.contains(.doses) {
                        ForEach(doseEntriesInRange) { entry in
                            let isTapped = tappedDose?.id == entry.id
                            PointMark(x: .value("Date", entry.timestamp), y: .value("Dose", 0.02))
                                .symbol(.circle)
                                .symbolSize(isTapped ? 140 : 36)
                                .foregroundStyle(MetricLayer.doses.color)
                        }
                    }
                    if visibleLayers.contains(.sideEffects) {
                        ForEach(sideEffectMarks) { d in
                            RuleMark(x: .value("Date", d.date))
                                .foregroundStyle(MetricLayer.sideEffects.color.opacity(0.35))
                                .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [2, 3]))
                        }
                    }

                    if let scrubDate {
                        RuleMark(x: .value("Date", scrubDate))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1))
                    }
                }
                .chartYScale(domain: 0...1.05)
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel()
                            .font(.system(size: 9))
                            .foregroundStyle(PepTheme.textSecondary)
                        AxisGridLine()
                            .foregroundStyle(PepTheme.elevated.opacity(0.4))
                    }
                }
                .frame(height: 180)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle().fill(.clear).contentShape(.rect)
                            .onTapGesture { location in
                                handleChartTap(at: location, proxy: proxy, geo: geo)
                            }
                            .gesture(
                                DragGesture(minimumDistance: 6)
                                    .onChanged { value in
                                        let x = value.location.x - geo[proxy.plotAreaFrame].minX
                                        if let date: Date = proxy.value(atX: x) { scrubDate = date }
                                        tappedDose = nil
                                    }
                                    .onEnded { _ in scrubDate = nil }
                            )
                            .overlay(alignment: .topLeading) {
                                if let dose = tappedDose, let pt = tappedDosePoint {
                                    doseTooltip(for: dose)
                                        .position(x: min(max(pt.x, 90), geo.size.width - 90), y: max(pt.y - 60, 40))
                                }
                            }
                    }
                }

                if let scrubDate, tappedDose == nil {
                    scrubReadout(for: scrubDate)
                }
            }
        }
    }

    private func scrubReadout(for date: Date) -> some View {
        let df = DateFormatter()
        df.dateStyle = .medium
        return VStack(alignment: .leading, spacing: 4) {
            Text(df.string(from: date))
                .font(.system(.caption, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            HStack(spacing: 10) {
                if let w = nearest(healthWeights, date: date), visibleLayers.contains(.weight) {
                    readoutChip("Wt", String(format: "%.1f lb", w), MetricLayer.weight.color)
                }
                if let h = nearest(healthHRV, date: date), visibleLayers.contains(.hrv) {
                    readoutChip("HRV", "\(Int(h))", MetricLayer.hrv.color)
                }
                if let r = nearest(healthRHR, date: date), visibleLayers.contains(.rhr) {
                    readoutChip("RHR", "\(Int(r))", MetricLayer.rhr.color)
                }
                if let s = nearest(healthSleep, date: date), visibleLayers.contains(.sleep) {
                    readoutChip("Sleep", String(format: "%.1fh", s), MetricLayer.sleep.color)
                }
            }
        }
        .padding(8)
        .background(PepTheme.elevated.opacity(0.5))
        .clipShape(.rect(cornerRadius: 8))
    }

    private func readoutChip(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(color)
            Text(value).font(.system(.caption2, design: .rounded, weight: .heavy)).foregroundStyle(PepTheme.textPrimary)
        }
    }

    // MARK: - Callouts

    private var calloutsCard: some View {
        let callouts = generateCallouts()
        return Group {
            if !callouts.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SMART CALLOUTS")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(1.2)
                            .foregroundStyle(PepTheme.textSecondary)
                        ForEach(callouts) { c in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: c.icon)
                                    .foregroundStyle(c.color)
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.title)
                                        .font(.system(.subheadline, weight: .bold))
                                        .foregroundStyle(PepTheme.textPrimary)
                                    Text(c.detail)
                                        .font(.caption)
                                        .foregroundStyle(PepTheme.textSecondary)
                                }
                                Spacer()
                            }
                            if c.id != callouts.last?.id {
                                Rectangle().fill(PepTheme.separatorColor).frame(height: 0.5)
                            }
                        }
                    }
                }
            }
        }
    }

    private var exportRow: some View {
        HStack(spacing: 10) {
            Button {
                exportImage()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share snapshot")
                }
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(PepTheme.teal)
                .clipShape(.rect(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Data

    private var rangeStart: Date {
        Calendar.current.date(byAdding: .day, value: -range.days, to: Date()) ?? Date()
    }

    private var doseCountInRange: Int {
        protocolData.doseLog.filter { !$0.wasSkipped && $0.timestamp >= rangeStart }.count
    }

    private var doseMarks: [DatedValue] {
        doseEntriesInRange.map { DatedValue(date: $0.timestamp, value: $0.doseMcg) }
    }

    private var doseEntriesInRange: [DoseLogEntry] {
        ProtocolDetailViewModel.dedupDoseLogs(detailVM.protocolData.doseLog)
            .filter { !$0.wasSkipped && $0.timestamp >= rangeStart }
    }

    private func handleChartTap(at location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) {
        let plotFrame = geo[proxy.plotAreaFrame]
        let x = location.x - plotFrame.minX
        guard let tapDate: Date = proxy.value(atX: x) else {
            tappedDose = nil
            tappedDosePoint = nil
            return
        }
        let entries = doseEntriesInRange
        guard !entries.isEmpty else { return }
        // Find nearest dose by time, require within ~5% of visible window.
            let windowSeconds = Double(range.days) * 86400
        let threshold = max(windowSeconds * 0.06, 3600)
        let nearest = entries.min { abs($0.timestamp.timeIntervalSince(tapDate)) < abs($1.timestamp.timeIntervalSince(tapDate)) }
        if let nearest, abs(nearest.timestamp.timeIntervalSince(tapDate)) <= threshold {
            if let xPos = proxy.position(forX: nearest.timestamp) {
                tappedDose = nearest
                tappedDosePoint = CGPoint(x: xPos + plotFrame.minX, y: plotFrame.maxY - 8)
                scrubDate = nil
            }
        } else {
            tappedDose = nil
            tappedDosePoint = nil
        }
    }

    @ViewBuilder
    private func doseTooltip(for dose: DoseLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "syringe.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(MetricLayer.doses.color)
                Text("\(CompoundUnitHelper.displayDoseShort(dose.doseMcg, for: dose.compoundName)) \(dose.compoundName)")
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Button {
                    tappedDose = nil
                    tappedDosePoint = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            Text("\(dose.timestamp.formatted(date: .abbreviated, time: .shortened)) · \(dose.injectionSite.shortName)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
            HStack(spacing: 6) {
                Button {
                    detailVM.editingDose = dose
                    tappedDose = nil
                    tappedDosePoint = nil
                } label: {
                    Text("Edit details")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(PepTheme.teal, in: .capsule)
                }
                .buttonStyle(.plain)
                Button {
                    detailVM.logSideEffect(linkedTo: dose)
                    tappedDose = nil
                    tappedDosePoint = nil
                } label: {
                    Text("Log side effect")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(PepTheme.amber, in: .capsule)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(width: 220)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(PepTheme.background)
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
        )
    }

    private var sideEffectMarks: [DatedValue] {
        protocolData.sideEffectLog
            .filter { $0.timestamp >= rangeStart }
            .map { DatedValue(date: $0.timestamp, value: Double($0.severity)) }
    }

    private func clip(_ points: [DatedValue]) -> [DatedValue] {
        points.filter { $0.date >= rangeStart }
    }

    private func normalize(_ value: Double, in series: [DatedValue], inverse: Bool = false) -> Double {
        let clipped = clip(series)
        guard let min = clipped.map(\.value).min(), let max = clipped.map(\.value).max(), max > min else { return 0.5 }
        let n = (value - min) / (max - min)
        return inverse ? (1 - n) : n
    }

    private func nearest(_ series: [DatedValue], date: Date) -> Double? {
        clip(series).min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })?.value
    }

    private func loadHealthData() async {
        guard healthKit.isAuthorized else { return }
        isLoadingHealth = true
        defer { isLoadingHealth = false }
        let end = Date()
        guard let start = Calendar.current.date(byAdding: .day, value: -range.days, to: end) else { return }

        async let w = fetchDaily(.bodyMass, unit: .pound(), start: start, end: end)
        async let h = fetchDaily(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), start: start, end: end)
        async let r = fetchDaily(.restingHeartRate, unit: .count().unitDivided(by: .minute()), start: start, end: end)
        async let s = fetchDailySleep(start: start, end: end)

        let (wV, hV, rV, sV) = await (w, h, r, s)
        healthWeights = wV
        healthHRV = hV
        healthRHR = rV
        healthSleep = sV
    }

    private func fetchDaily(_ id: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async -> [DatedValue] {
        // Sample once per day using existing fetcher: daily average
        let cal = Calendar.current
        var out: [DatedValue] = []
        var day = cal.startOfDay(for: start)
        while day < end {
            let avg = await healthKit.fetchDayAverage(id, unit: unit, date: day)
            if let avg, avg > 0 { out.append(DatedValue(date: day, value: avg)) }
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return out
    }

    private func fetchDailySleep(start: Date, end: Date) async -> [DatedValue] {
        let cal = Calendar.current
        var out: [DatedValue] = []
        var day = cal.startOfDay(for: start)
        while day < end {
            let hours = await healthKit.fetchSleepHours(for: day)
            if hours > 0 { out.append(DatedValue(date: day, value: hours)) }
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return out
    }

    // MARK: - Callouts Engine

    private nonisolated struct Callout: Identifiable {
        let id: UUID = UUID()
        let icon: String
        let color: Color
        let title: String
        let detail: String
    }

    private func generateCallouts() -> [Callout] {
        var out: [Callout] = []
        let doses = protocolData.doseLog.filter { !$0.wasSkipped && $0.timestamp >= rangeStart }
        if doses.count >= 3 {
            out.append(Callout(
                icon: "syringe.fill",
                color: PepTheme.teal,
                title: "\(doses.count) doses logged",
                detail: "Adherence looks strong. Keep rotating injection sites for best absorption."
            ))
        }

        if let first = clip(healthWeights).first, let last = clip(healthWeights).last, first.value - last.value >= 1 {
            let delta = first.value - last.value
            out.append(Callout(
                icon: "arrow.down.right.circle.fill",
                color: .green,
                title: String(format: "Weight down %.1f lb", delta),
                detail: "Since \(formatDate(first.date)). Directionally on track with your protocol goal."
            ))
        }

        let hrvClip = clip(healthHRV)
        if let avgEarly = avg(hrvClip.prefix(hrvClip.count / 2)), let avgLate = avg(hrvClip.suffix(hrvClip.count / 2)), avgLate > avgEarly * 1.05 {
            let pct = Int(((avgLate - avgEarly) / avgEarly) * 100)
            out.append(Callout(
                icon: "waveform.path.ecg",
                color: .pink,
                title: "HRV up \(pct)%",
                detail: "Recovery capacity is trending up over this window — a good sign your nervous system tolerates the protocol."
            ))
        }

        let sideEffectsInRange = protocolData.sideEffectLog.filter { $0.timestamp >= rangeStart }
        if sideEffectsInRange.count >= 3 {
            let avgSev = Double(sideEffectsInRange.reduce(0) { $0 + $1.severity }) / Double(sideEffectsInRange.count)
            out.append(Callout(
                icon: "exclamationmark.triangle.fill",
                color: PepTheme.amber,
                title: "\(sideEffectsInRange.count) side-effect entries",
                detail: String(format: "Average severity %.1f/5. Consider lowering dose or adding taper if trending up.", avgSev)
            ))
        }

        return out
    }

    private func avg(_ arr: some Sequence<DatedValue>) -> Double? {
        let values = arr.map(\.value)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func formatDate(_ d: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        return df.string(from: d)
    }

    private func exportImage() {
        let renderer = ImageRenderer(content:
            chartCard
                .frame(width: 380)
                .padding(20)
                .background(PepTheme.background)
        )
        renderer.scale = UIScreen.main.scale
        if let img = renderer.uiImage {
            let av = UIActivityViewController(activityItems: [img], applicationActivities: nil)
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.keyWindow?.rootViewController?
                .present(av, animated: true)
        }
    }
}
