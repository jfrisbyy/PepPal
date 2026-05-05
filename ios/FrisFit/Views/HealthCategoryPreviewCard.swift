import SwiftUI
import Charts

struct HealthCategoryPreviewCard: View {
    let category: HealthCategory
    let viewModel: HealthDetailViewModel

    var body: some View {
        HStack(spacing: 12) {
            iconBlock
            VStack(alignment: .leading, spacing: 4) {
                Text(category.title)
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(subtitle)
                    .font(.system(.caption2, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineLimit(1)
                headline
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            preview
                .frame(width: 90, height: 52)

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [category.color.opacity(0.10), category.color.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .background(PepTheme.cardSurface)
        )
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [category.color.opacity(0.28), category.color.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    private var iconBlock: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13)
                .fill(
                    LinearGradient(colors: [category.color.opacity(0.9), category.color.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 44, height: 44)
                .shadow(color: category.color.opacity(0.35), radius: 6, y: 3)
            Image(systemName: category.icon)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private var headline: some View {
        HStack(spacing: 6) {
            Text(headlineValue)
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(PepTheme.textPrimary)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let trend = trendInfo {
                deltaChip(pct: trend.pct, higherBetter: trend.higherBetter)
            }
            if isPB {
                pbRibbon
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        let tail = Array(previewSeries.suffix(7))
        if tail.isEmpty {
            RoundedRectangle(cornerRadius: 10)
                .fill(category.color.opacity(0.08))
        } else if previewKind == .bar {
            Chart(tail) { p in
                BarMark(x: .value("d", p.date, unit: .day), y: .value("v", max(p.value, 0)))
                    .foregroundStyle(LinearGradient(colors: [category.color, category.color.opacity(0.45)], startPoint: .top, endPoint: .bottom))
                    .cornerRadius(2)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartPlotStyle { $0.background(.clear) }
        } else {
            Chart(tail) { p in
                LineMark(x: .value("d", p.date), y: .value("v", p.value))
                    .foregroundStyle(category.color)
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                AreaMark(x: .value("d", p.date), y: .value("v", p.value))
                    .foregroundStyle(LinearGradient(colors: [category.color.opacity(0.3), category.color.opacity(0)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartPlotStyle { $0.background(.clear) }
        }
    }

    private var pbRibbon: some View {
        HStack(spacing: 2) {
            Image(systemName: "trophy.fill").font(.system(size: 8, weight: .bold))
            Text("PB").font(.system(size: 9, weight: .heavy))
        }
        .foregroundStyle(PepTheme.amber)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(PepTheme.amber.opacity(0.18), in: .capsule)
    }

    private func deltaChip(pct: Double, higherBetter: Bool) -> some View {
        let positive = higherBetter ? pct >= 0 : pct <= 0
        let color: Color = positive ? .green : .red
        let symbol = pct >= 0 ? "arrow.up.right" : "arrow.down.right"
        return HStack(spacing: 2) {
            Image(systemName: symbol).font(.system(size: 8, weight: .heavy))
            Text("\(String(format: "%.0f", abs(pct)))%")
                .font(.system(size: 9, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.14), in: .capsule)
    }

    // MARK: - Data mapping

    private enum PreviewKind { case bar, line }

    private var previewKind: PreviewKind {
        switch category {
        case .activity, .nutrition: return .bar
        default: return .line
        }
    }

    private var previewSeries: [HealthSeriesPoint] {
        switch category {
        case .activity: return viewModel.stepsSeries
        case .heart: return viewModel.restingHRSeries
        case .body: return viewModel.weightSeries
        case .vitals: return viewModel.oxygenSaturationSeries.isEmpty ? viewModel.respiratoryRateSeries : viewModel.oxygenSaturationSeries
        case .sleep: return viewModel.sleepSeries
        case .nutrition: return viewModel.hydrationSeries.isEmpty ? viewModel.mindfulSeries : viewModel.hydrationSeries
        }
    }

    private var headlineValue: String {
        let hk = viewModel.healthKit
        switch category {
        case .activity:
            if hk.steps >= 1000 { return String(format: "%.1fk", Double(hk.steps) / 1000) + " steps" }
            return "\(hk.steps) steps"
        case .heart:
            if let rhr = hk.restingHeartRate { return "\(Int(rhr)) RHR" }
            if hk.heartRate > 0 { return "\(Int(hk.heartRate)) BPM" }
            return "—"
        case .body:
            if let w = hk.bodyWeight { return String(format: "%.1f lb", w) }
            return "—"
        case .vitals:
            if let o = hk.oxygenSaturation { return String(format: "%.0f%% O₂", o) }
            if let rr = hk.respiratoryRate { return String(format: "%.0f br/min", rr) }
            return "—"
        case .sleep:
            if hk.sleepHours > 0 { return String(format: "%.1fh sleep", hk.sleepHours) }
            return "—"
        case .nutrition:
            if hk.dietaryWater > 0 { return "\(Int(hk.dietaryWater)) ml" }
            if hk.mindfulMinutesToday > 0 { return "\(Int(hk.mindfulMinutesToday)) mindful" }
            return "—"
        }
    }

    private var subtitle: String {
        let hk = viewModel.healthKit
        switch category {
        case .activity:
            return "\(Int(hk.activeCalories)) cal · \(String(format: "%.1f", hk.distanceMiles)) mi"
        case .heart:
            if let hrv = hk.hrv { return "HRV \(Int(hrv)) ms" }
            return "Heart rate & HRV"
        case .body:
            if let bf = hk.bodyFatPercentage { return String(format: "BF %.1f%%", bf) }
            return "Weight · composition"
        case .vitals:
            return "SpO₂ · Respiratory · BP"
        case .sleep:
            if let last = viewModel.sleepNights.last {
                return String(format: "Deep %.1fh · REM %.1fh", last.deep, last.rem)
            }
            return "Stages & history"
        case .nutrition:
            return "Water · food · mindful"
        }
    }

    private var trendInfo: (pct: Double, higherBetter: Bool)? {
        switch category {
        case .activity:
            if let p = viewModel.stepsTrend.deltaPct { return (p, true) }
        case .heart:
            if let p = viewModel.rhrTrend.deltaPct { return (p, false) }
        case .sleep:
            if let p = viewModel.sleepTrend.deltaPct { return (p, true) }
        default: break
        }
        return nil
    }

    private var isPB: Bool {
        switch category {
        case .activity: return viewModel.stepsTrend.isPersonalBest
        case .heart: return viewModel.hrvTrend.isPersonalBest
        default: return false
        }
    }
}
