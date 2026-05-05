import SwiftUI
import Charts

struct BiomarkerDetailView: View {
    let biomarker: Biomarker
    let entries: [BloodworkEntry]
    let personalizedRange: PersonalizedRange

    private var series: [(date: Date, value: Double)] {
        entries.compactMap { entry in
            guard let r = entry.results.first(where: { $0.biomarker == biomarker }) else { return nil }
            return (entry.date, r.value)
        }.sorted { $0.date < $1.date }
    }

    private var alert: BiomarkerTrendAlert? {
        BloodworkRangeService.trendAlert(for: biomarker, values: series, range: personalizedRange)
    }

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let alert {
                    trendAlertBanner(alert)
                }
                summaryCard
                chartCard
                historyCard
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .navigationTitle(biomarker.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func trendAlertBanner(_ alert: BiomarkerTrendAlert) -> some View {
        let color: Color = {
            switch alert.severity {
            case .critical: return .red
            case .warning: return .orange
            case .info: return PepTheme.amber
            }
        }()
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: alert.severity == .critical ? "exclamationmark.triangle.fill" : "chart.line.uptrend.xyaxis")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.15))
                .clipShape(.rect(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
                Text("\(biomarker.rawValue) \(alert.direction.rawValue.lowercased())")
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(alert.message)
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(color.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(color.opacity(0.3), lineWidth: 1)
        )
        .clipShape(.rect(cornerRadius: 12))
    }

    private var summaryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: biomarker.category.icon)
                        .foregroundStyle(biomarker.category.color)
                    Text(biomarker.category.rawValue)
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                    Text("Range: \(formatValue(personalizedRange.low))–\(formatValue(personalizedRange.high)) \(biomarker.unit)")
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary)
                }

                if let last = series.last {
                    let status = BloodworkRangeService.status(last.value, range: personalizedRange)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(formatValue(last.value))
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .foregroundStyle(status.color)
                        Text(biomarker.unit)
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                        Spacer()
                        Text(status.rawValue)
                            .font(.system(.caption, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(status.color)
                            .clipShape(.capsule)
                    }
                    Text("Latest \(dateFormatter.string(from: last.date))")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }

    private var chartCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("History")
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)

                if series.count >= 2 {
                    Chart {
                        RectangleMark(
                            yStart: .value("Low", personalizedRange.low),
                            yEnd: .value("High", personalizedRange.high)
                        )
                        .foregroundStyle(.green.opacity(0.08))

                        ForEach(Array(series.enumerated()), id: \.offset) { _, point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Value", point.value)
                            )
                            .foregroundStyle(PepTheme.teal)
                            .interpolationMethod(.monotone)
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Value", point.value)
                            )
                            .foregroundStyle(BloodworkRangeService.status(point.value, range: personalizedRange).color)
                        }
                    }
                    .frame(height: 180)
                } else {
                    Text("Log more entries to see a trend.")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 80)
                }
            }
        }
    }

    private var historyCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("All Readings")
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                ForEach(Array(series.reversed().enumerated()), id: \.offset) { _, point in
                    let status = BloodworkRangeService.status(point.value, range: personalizedRange)
                    HStack {
                        Text(dateFormatter.string(from: point.date))
                            .font(.caption)
                            .foregroundStyle(PepTheme.textPrimary)
                        Spacer()
                        Text("\(formatValue(point.value)) \(biomarker.unit)")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(status.color)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func formatValue(_ v: Double) -> String {
        if v.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", v)
        }
        return String(format: "%.1f", v)
    }
}
