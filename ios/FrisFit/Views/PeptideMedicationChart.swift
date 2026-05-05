import SwiftUI
import Charts

/// Pharmacokinetic medication-level chart powered by the Bateman model.
/// - Solid past curve, dotted future projection.
/// - "Now" marker.
/// - Optional comparison overlay with a second compound.
/// - Drag-to-scrub readout.
struct PeptideMedicationChart: View {
    let primary: PKSeries
    var comparison: PKSeries? = nil
    var range: PKChartRange = .sevenDay
    var height: CGFloat = 240

    @State private var scrubTime: Date? = nil

    private var now: Date { Date() }
    private var allSamples: [PKSamplePoint] { primary.samples }
    private var maxY: Double {
        let primaryMax = primary.samples.map(\.mg).max() ?? 0
        let compMax = comparison?.samples.map(\.mg).max() ?? 0
        return max(0.05, max(primaryMax, compMax) * 1.15)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            chart
                .frame(height: height)
            scrubReadout
        }
    }

    // MARK: - Chart

    private var chart: some View {
        Chart {
            // Primary past (solid line + gradient area)
            ForEach(primary.samples.filter { !$0.isFuture }) { p in
                LineMark(
                    x: .value("Time", p.time),
                    y: .value("mg", p.mg),
                    series: .value("series", "primary-past")
                )
                .foregroundStyle(primary.color)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.4))

                AreaMark(
                    x: .value("Time", p.time),
                    yStart: .value("zero", 0),
                    yEnd: .value("mg", p.mg),
                    series: .value("series", "primary-area")
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [primary.color.opacity(0.35), primary.color.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }

            // Primary future (dotted projection)
            ForEach(primary.samples.filter { $0.isFuture }) { p in
                LineMark(
                    x: .value("Time", p.time),
                    y: .value("mg", p.mg),
                    series: .value("series", "primary-future")
                )
                .foregroundStyle(primary.color.opacity(0.85))
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [3, 4]))
            }

            // Comparison line
            if let comp = comparison {
                ForEach(comp.samples.filter { !$0.isFuture }) { p in
                    LineMark(
                        x: .value("Time", p.time),
                        y: .value("mg", p.mg),
                        series: .value("series", "compare-past")
                    )
                    .foregroundStyle(comp.color)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 1.8))
                }
                ForEach(comp.samples.filter { $0.isFuture }) { p in
                    LineMark(
                        x: .value("Time", p.time),
                        y: .value("mg", p.mg),
                        series: .value("series", "compare-future")
                    )
                    .foregroundStyle(comp.color.opacity(0.85))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 1.6, dash: [2, 4]))
                }
            }

            // Now marker
            RuleMark(x: .value("Now", now))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .annotation(position: .top, alignment: .center) {
                    Text("Now")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(PepTheme.background)
                        .clipShape(.capsule)
                }

            // Dose markers (tiny dots at each dose time)
            ForEach(primary.doses, id: \.time) { d in
                PointMark(
                    x: .value("Dose", d.time),
                    y: .value("mg", interpolate(at: d.time, samples: primary.samples))
                )
                .foregroundStyle(primary.color)
                .symbolSize(28)
            }

            // Scrub indicator
            if let st = scrubTime {
                RuleMark(x: .value("Scrub", st))
                    .foregroundStyle(primary.color.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                PointMark(
                    x: .value("Scrub", st),
                    y: .value("mg", interpolate(at: st, samples: primary.samples))
                )
                .foregroundStyle(primary.color)
                .symbolSize(80)
            }
        }
        .chartYScale(domain: 0...maxY)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(PepTheme.textSecondary.opacity(0.12))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(formatMg(v))
                            .font(.system(size: 10))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(PepTheme.textSecondary.opacity(0.08))
                AxisValueLabel {
                    if let d = value.as(Date.self) {
                        Text(formatDate(d))
                            .font(.system(size: 10))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(.rect)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard let plotFrame = proxy.plotFrame else { return }
                                let frame = geo[plotFrame]
                                let x = value.location.x - frame.minX
                                if let date: Date = proxy.value(atX: x) {
                                    if let first = primary.samples.first?.time,
                                       let last = primary.samples.last?.time,
                                       date >= first && date <= last {
                                        scrubTime = date
                                    }
                                }
                            }
                            .onEnded { _ in
                                scrubTime = nil
                            }
                    )
            }
        }
    }

    // MARK: - Scrub readout

    @ViewBuilder
    private var scrubReadout: some View {
        if let st = scrubTime {
            let mg = interpolate(at: st, samples: primary.samples)
            HStack(spacing: 8) {
                Circle()
                    .fill(primary.color)
                    .frame(width: 8, height: 8)
                Text(formatMg(mg))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(st.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(PepTheme.elevated.opacity(0.6))
            .clipShape(.rect(cornerRadius: 8))
            .sensoryFeedback(.selection, trigger: st)
        }
    }

    // MARK: - Helpers

    private func interpolate(at t: Date, samples: [PKSamplePoint]) -> Double {
        guard !samples.isEmpty else { return 0 }
        if t <= samples.first!.time { return samples.first!.mg }
        if t >= samples.last!.time { return samples.last!.mg }
        for i in 1..<samples.count {
            let a = samples[i - 1], b = samples[i]
            if t >= a.time && t <= b.time {
                let span = b.time.timeIntervalSince(a.time)
                let frac = span > 0 ? t.timeIntervalSince(a.time) / span : 0
                return a.mg + (b.mg - a.mg) * frac
            }
        }
        return samples.last!.mg
    }

    private func formatMg(_ mg: Double) -> String {
        if mg >= 1 { return String(format: "%.2f mg", mg) }
        if mg >= 0.01 { return String(format: "%.2f mg", mg) }
        let mcg = mg * 1000
        return String(format: "%.0f mcg", mcg)
    }

    private func formatDate(_ d: Date) -> String {
        let cal = Calendar.current
        if range == .sevenDay {
            return d.formatted(.dateTime.month(.defaultDigits).day())
        }
        let _ = cal
        return d.formatted(.dateTime.month(.defaultDigits).day())
    }
}

/// A single named series of dose-driven samples.
struct PKSeries: Sendable {
    let compoundName: String
    let color: Color
    let samples: [PKSamplePoint]
    let doses: [PKDose]
    let halfLifeLabel: String
}
