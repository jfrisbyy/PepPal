import SwiftUI
import Charts

struct ForecastSection: View {
    @State private var service = ForecastService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if let bundle = service.bundle {
                if let weight = bundle.weight {
                    WeightForecastCard(forecast: weight)
                }
                if let flare = bundle.flare {
                    FlareRiskCard(flare: flare)
                }
                if !bundle.prReadiness.isEmpty {
                    PRReadinessCard(items: bundle.prReadiness)
                }
            } else if service.isGenerating {
                ProgressView().frame(maxWidth: .infinity).padding()
            } else {
                emptyState
            }
        }
        .onAppear {
            service.refreshIfNeeded()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PepTheme.teal)
            Text("FORECAST")
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.8))
            Spacer()
            if let bundle = service.bundle {
                Text(bundle.generatedAt.formatted(.relative(presentation: .numeric)))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
            }
            Button {
                Task { await service.generate() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PepTheme.teal.opacity(0.7))
                    .frame(width: 22, height: 22)
                    .background(PepTheme.teal.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyState: some View {
        Text("Log weigh-ins and workouts consistently for a week to unlock forecasts.")
            .font(.caption)
            .foregroundStyle(PepTheme.textSecondary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PepTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 14))
    }
}

private struct WeightForecastCard: View {
    let forecast: WeightForecast

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Weight trajectory", systemImage: "scalemass.fill")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                Text(String(format: "%.2f lb/wk", forecast.weeklyRate))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(forecast.weeklyRate < 0 ? .green : (forecast.weeklyRate > 0 ? PepTheme.blue : PepTheme.textSecondary))
            }

            Chart {
                RuleMark(y: .value("Current", forecast.currentWeight))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                if forecast.goalWeight > 0 {
                    RuleMark(y: .value("Goal", forecast.goalWeight))
                        .foregroundStyle(PepTheme.teal.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }

                ForEach(forecast.points) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        yStart: .value("Low", point.lowerBound),
                        yEnd: .value("High", point.upperBound)
                    )
                    .foregroundStyle(PepTheme.teal.opacity(0.15))
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Projected", point.projected)
                    )
                    .foregroundStyle(PepTheme.teal)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                }
            }
            .chartYScale(domain: yDomain())
            .frame(height: 130)

            HStack(spacing: 14) {
                statBadge(label: "Current", value: String(format: "%.1f", forecast.currentWeight))
                if forecast.goalWeight > 0 {
                    statBadge(label: "Goal", value: String(format: "%.1f", forecast.goalWeight))
                }
                statBadge(label: "Plateau risk", value: "\(forecast.plateauRiskPercent)%")
                Spacer()
            }

            Text(forecast.reasoning)
                .font(.system(size: 11))
                .foregroundStyle(PepTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private func yDomain() -> ClosedRange<Double> {
        let allValues = forecast.points.flatMap { [$0.lowerBound, $0.upperBound] } + [forecast.currentWeight, forecast.goalWeight].filter { $0 > 0 }
        let minVal = (allValues.min() ?? forecast.currentWeight) - 1
        let maxVal = (allValues.max() ?? forecast.currentWeight) + 1
        return minVal...max(maxVal, minVal + 2)
    }

    private func statBadge(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(PepTheme.textPrimary)
        }
    }
}

private struct FlareRiskCard: View {
    let flare: FlareRisk

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Flare risk", systemImage: "waveform.path.ecg")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                Text(flare.riskLevel.rawValue.capitalized)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(riskColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(riskColor.opacity(0.15))
                    .clipShape(.capsule)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(PepTheme.elevated)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(riskColor)
                        .frame(width: geo.size.width * CGFloat(min(flare.scorePercent, 100)) / 100.0)
                }
            }
            .frame(height: 8)

            Text(flare.reasoning)
                .font(.system(size: 12))
                .foregroundStyle(PepTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if !flare.drivers.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(flare.drivers, id: \.self) { driver in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 4))
                                .foregroundStyle(riskColor.opacity(0.7))
                                .padding(.top, 5)
                            Text(driver)
                                .font(.system(size: 11))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private var riskColor: Color {
        switch flare.riskLevel {
        case .low: return .green
        case .elevated: return PepTheme.amber
        case .high: return .red
        }
    }
}

private struct PRReadinessCard: View {
    let items: [PRReadiness]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("PR readiness", systemImage: "flame.fill")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)

            VStack(spacing: 8) {
                ForEach(items) { item in
                    prRow(item)
                }
            }
        }
        .padding(14)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private func prRow(_ item: PRReadiness) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.exercise)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)
                Spacer()
                Text("\(item.readinessPercent)%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(readinessColor(item.readinessPercent))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(PepTheme.elevated)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(readinessColor(item.readinessPercent))
                        .frame(width: geo.size.width * CGFloat(item.readinessPercent) / 100.0)
                }
            }
            .frame(height: 5)
            Text(item.recommendation)
                .font(.system(size: 11))
                .foregroundStyle(PepTheme.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func readinessColor(_ pct: Int) -> Color {
        if pct >= 75 { return .green }
        if pct >= 50 { return PepTheme.amber }
        return PepTheme.textSecondary
    }
}
