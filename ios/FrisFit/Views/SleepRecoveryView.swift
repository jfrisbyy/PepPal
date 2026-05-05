import SwiftUI
import Charts

struct SleepRecoveryView: View {
    @State private var service = SleepRecoveryService.shared
    @State private var hasRequested: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if service.isLoading && service.recentNights.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if service.recentNights.isEmpty {
                    emptyState
                } else {
                    summary
                    if let correlation = service.correlation {
                        correlationCard(correlation)
                    }
                    sleepChart
                    stagesBreakdown
                    if !service.recoveryReadings.isEmpty {
                        recoveryCard
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .navigationTitle("Sleep & Recovery")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !hasRequested {
                hasRequested = true
                _ = await service.authorize()
                await service.loadRecent()
            } else {
                await service.loadRecent()
            }
        }
        .refreshable { await service.loadRecent() }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bed.double.fill")
                .font(.system(size: 40))
                .foregroundStyle(PepTheme.violet.opacity(0.6))
            Text("No Sleep Data")
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text("Allow HealthKit access and wear a watch that tracks sleep to see nights here.")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(.top, 60)
    }

    private var summary: some View {
        HStack(spacing: 10) {
            stat(value: String(format: "%.1fh", service.averageSleep7d), label: "7d Avg Sleep", color: PepTheme.violet)
            if let hrv = service.averageHRV7d {
                stat(value: String(format: "%.0fms", hrv), label: "7d Avg HRV", color: PepTheme.teal)
            }
            if let lastRhr = service.recoveryReadings.compactMap(\.restingHR).first {
                stat(value: "\(Int(lastRhr))", label: "Resting HR", color: PepTheme.blue)
            }
        }
    }

    private func stat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 12))
    }

    private var sleepChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sleep Hours")
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Chart {
                ForEach(service.recentNights.prefix(14).reversed()) { night in
                    BarMark(
                        x: .value("Date", night.date, unit: .day),
                        y: .value("Hours", night.totalHours)
                    )
                    .foregroundStyle(LinearGradient(colors: [PepTheme.violet, PepTheme.violet.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                    .cornerRadius(4)
                }
                RuleMark(y: .value("Goal", 8))
                    .foregroundStyle(PepTheme.teal.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .frame(height: 160)
            .chartYScale(domain: 0...10)
        }
        .padding(14)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 12))
    }

    private var stagesBreakdown: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Last Night Stages")
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)

            if let last = service.recentNights.first {
                VStack(spacing: 6) {
                    stageRow("Deep", hours: last.deepHours, color: PepTheme.violet)
                    stageRow("REM", hours: last.remHours, color: PepTheme.blue)
                    stageRow("Core", hours: last.coreHours, color: PepTheme.teal)
                    if last.awakeHours > 0 {
                        stageRow("Awake", hours: last.awakeHours, color: PepTheme.amber)
                    }
                }
            }
        }
        .padding(14)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 12))
    }

    private func stageRow(_ label: String, hours: Double, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
            Spacer()
            Text(formatHours(hours))
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(color)
        }
    }

    private var recoveryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HRV Trend")
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)

            Chart {
                ForEach(service.recoveryReadings.prefix(14).reversed()) { reading in
                    if let hrv = reading.hrv {
                        LineMark(
                            x: .value("Date", reading.date, unit: .day),
                            y: .value("HRV", hrv)
                        )
                        .foregroundStyle(PepTheme.teal)
                        .interpolationMethod(.monotone)
                        PointMark(
                            x: .value("Date", reading.date, unit: .day),
                            y: .value("HRV", hrv)
                        )
                        .foregroundStyle(PepTheme.teal)
                    }
                }
            }
            .frame(height: 140)
        }
        .padding(14)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 12))
    }

    private func correlationCard(_ c: TrainingSleepCorrelation) -> some View {
        let color: Color = {
            switch c.severity {
            case .good: return .green
            case .watch: return PepTheme.amber
            case .warn: return .red
            }
        }()
        let icon: String = {
            switch c.severity {
            case .good: return "checkmark.seal.fill"
            case .watch: return "exclamationmark.circle.fill"
            case .warn: return "exclamationmark.triangle.fill"
            }
        }()
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
                Text("Training vs Recovery")
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
            }
            HStack(spacing: 12) {
                miniStat(value: "\(c.weeklySessions)", label: "Sessions / 7d")
                miniStat(value: formatVolume(c.weeklyVolume), label: "Volume")
                miniStat(value: String(format: "%.1fh", c.averageSleepHours), label: "Avg Sleep")
            }
            Text(c.insight)
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(color.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(color.opacity(0.3), lineWidth: 1)
        )
        .clipShape(.rect(cornerRadius: 12))
    }

    private func miniStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(PepTheme.cardSurface.opacity(0.6))
        .clipShape(.rect(cornerRadius: 8))
    }

    private func formatVolume(_ v: Int) -> String {
        if v >= 1000 { return String(format: "%.1fk", Double(v) / 1000.0) }
        return "\(v)"
    }

    private func formatHours(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }
}
