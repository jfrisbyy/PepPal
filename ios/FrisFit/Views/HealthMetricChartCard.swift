import SwiftUI
import Charts

enum HealthMetricFormat {
    case integer, decimal1, decimal2
}

enum HealthChartKind {
    case bar, line
}

struct HealthMetricChartCard: View {
    let title: String
    let icon: String
    let color: Color
    let series: [HealthSeriesPoint]
    let unit: String
    let format: HealthMetricFormat
    let chartKind: HealthChartKind

    @State private var selectedPoint: HealthSeriesPoint? = nil

    var body: some View {
        let nonZero = series.filter { $0.value > 0 }
        let latest = nonZero.last?.value ?? 0
        let avg: Double = nonZero.isEmpty ? 0 : nonZero.reduce(0) { $0 + $1.value } / Double(nonZero.count)
        let total: Double = series.reduce(0) { $0 + $1.value }
        let high = series.map(\.value).max() ?? 0
        let low = nonZero.map(\.value).min() ?? 0

        VStack(alignment: .leading, spacing: 12) {
            header
            headline(latest: selectedPoint?.value ?? latest, isSelected: selectedPoint != nil)
            chartArea(avg: avg)
            pills(avg: avg, high: high, low: low, total: total)
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [color.opacity(0.15), color.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 26, height: 26)
                .background(color.opacity(0.15))
                .clipShape(.rect(cornerRadius: 8))
            Text(title)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
            Spacer()
            Text(unit)
                .font(.caption2)
                .foregroundStyle(PepTheme.textSecondary)
        }
    }

    private func headline(latest: Double, isSelected: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(HealthMetricChartCard.formatValue(latest, format: format))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
                .contentTransition(.numericText())
            if isSelected, let sp = selectedPoint {
                Text(sp.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(.caption)
                    .foregroundStyle(color)
                    .transition(.opacity)
            } else {
                Text("Latest")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    @ViewBuilder
    private func chartArea(avg: Double) -> some View {
        if series.isEmpty {
            Text("No data in this period.")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 80)
        } else {
            Chart {
                chartBody(avg: avg)
                if let sp = selectedPoint {
                    RuleMark(x: .value("Selected", sp.date, unit: .day))
                        .foregroundStyle(color.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    PointMark(x: .value("Selected", sp.date, unit: .day), y: .value("v", sp.value))
                        .foregroundStyle(color)
                        .symbolSize(80)
                }
            }
            .frame(height: 160)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(PepTheme.textSecondary.opacity(0.08))
                    AxisValueLabel().font(.caption2)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .font(.caption2)
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(.rect)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { v in
                                    handleScrub(location: v.location, proxy: proxy, geo: geo)
                                }
                                .onEnded { _ in
                                    withAnimation(.easeOut(duration: 0.25)) { selectedPoint = nil }
                                }
                        )
                }
            }
        }
    }

    private func handleScrub(location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) {
        let origin = geo[proxy.plotAreaFrame].origin
        let x = location.x - origin.x
        guard let date: Date = proxy.value(atX: x) else { return }
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        let nearest = series.min { a, b in
            abs(calendar.startOfDay(for: a.date).timeIntervalSince(targetDay))
                < abs(calendar.startOfDay(for: b.date).timeIntervalSince(targetDay))
        }
        if let nearest, selectedPoint?.id != nearest.id {
            selectedPoint = nearest
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    @ChartContentBuilder
    private func chartBody(avg: Double) -> some ChartContent {
        let _ = avg
        switch chartKind {
        case .bar:
            ForEach(series) { point in
                BarMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value(title, point.value)
                )
                .foregroundStyle(LinearGradient(
                    colors: [color, color.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .cornerRadius(3)
            }
        case .line:
            ForEach(series) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value(title, point.value)
                )
                .foregroundStyle(color)
                .interpolationMethod(.monotone)
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value(title, point.value)
                )
                .foregroundStyle(LinearGradient(
                    colors: [color.opacity(0.3), color.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .interpolationMethod(.monotone)
            }
            if avg > 0 {
                RuleMark(y: .value("Avg", avg))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
    }

    @ViewBuilder
    private func pills(avg: Double, high: Double, low: Double, total: Double) -> some View {
        HStack(spacing: 10) {
            HealthStatPill(label: "Avg", value: HealthMetricChartCard.formatValue(avg, format: format), unit: unit)
            HealthStatPill(label: "High", value: HealthMetricChartCard.formatValue(high, format: format), unit: unit)
            HealthStatPill(label: "Low", value: HealthMetricChartCard.formatValue(low, format: format), unit: unit)
            if chartKind == .bar {
                HealthStatPill(label: "Total", value: HealthMetricChartCard.formatValue(total, format: format), unit: unit)
            }
        }
    }

    static func formatValue(_ v: Double, format: HealthMetricFormat) -> String {
        guard v.isFinite else { return "--" }
        switch format {
        case .integer:
            if v >= 1000 { return String(format: "%.1fk", v / 1000) }
            return String(format: "%.0f", v)
        case .decimal1:
            return String(format: "%.1f", v)
        case .decimal2:
            return String(format: "%.2f", v)
        }
    }
}

struct HealthStatPill: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(PepTheme.elevated.opacity(0.5))
        .clipShape(.rect(cornerRadius: 10))
    }
}

struct HealthPeriodPicker: View {
    @Binding var period: HealthDetailPeriod

    var body: some View {
        Picker("Period", selection: $period) {
            ForEach(HealthDetailPeriod.allCases) { p in
                Text(p.rawValue).tag(p)
            }
        }
        .pickerStyle(.segmented)
    }
}
