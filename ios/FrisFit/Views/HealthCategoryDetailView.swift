import SwiftUI
import Charts
import HealthKit

enum HealthCategory: String, CaseIterable, Identifiable {
    case activity
    case heart
    case body
    case vitals
    case sleep
    case nutrition

    var id: String { rawValue }

    var title: String {
        switch self {
        case .activity: return "Activity"
        case .heart: return "Heart"
        case .body: return "Body Measurements"
        case .vitals: return "Respiratory & Vitals"
        case .sleep: return "Sleep"
        case .nutrition: return "Nutrition & Mindfulness"
        }
    }

    var icon: String {
        switch self {
        case .activity: return "flame.fill"
        case .heart: return "heart.fill"
        case .body: return "figure.arms.open"
        case .vitals: return "lungs.fill"
        case .sleep: return "bed.double.fill"
        case .nutrition: return "leaf.fill"
        }
    }

    var color: Color {
        switch self {
        case .activity: return .orange
        case .heart: return .red
        case .body: return .orange
        case .vitals: return PepTheme.blue
        case .sleep: return PepTheme.violet
        case .nutrition: return .green
        }
    }
}

struct HealthCategoryRow: View {
    let category: HealthCategory
    let viewModel: HealthDetailViewModel

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: category.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(category.color)
                .frame(width: 44, height: 44)
                .background(category.color.opacity(0.15))
                .clipShape(.rect(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(category.title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
        }
        .padding(14)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(
                        colors: [category.color.opacity(0.15), category.color.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }

    private var summary: String {
        let hk = viewModel.healthKit
        switch category {
        case .activity:
            return "\(hk.steps) steps · \(Int(hk.activeCalories)) cal · \(String(format: "%.1f", hk.distanceMiles)) mi"
        case .heart:
            let hr = hk.heartRate > 0 ? "\(Int(hk.heartRate)) BPM" : "--"
            let rhr = hk.restingHeartRate.map { "RHR \(Int($0))" } ?? "No RHR"
            return "\(hr) · \(rhr)"
        case .body:
            var parts: [String] = []
            if let bf = hk.bodyFatPercentage { parts.append(String(format: "BF %.1f%%", bf)) }
            if let lbm = hk.leanBodyMass { parts.append(String(format: "Lean %.0f lb", lbm)) }
            return parts.isEmpty ? "Weight, BMI, composition" : parts.joined(separator: " · ")
        case .vitals:
            var parts: [String] = []
            if let rr = hk.respiratoryRate { parts.append(String(format: "%.0f br/min", rr)) }
            if let o2 = hk.oxygenSaturation { parts.append(String(format: "%.0f%% SpO₂", o2)) }
            return parts.isEmpty ? "Respiratory rate, blood oxygen" : parts.joined(separator: " · ")
        case .sleep:
            return hk.sleepHours > 0 ? String(format: "%.1f hrs last night", hk.sleepHours) : "Sleep stages & history"
        case .nutrition:
            return "Water, dietary energy, mindfulness"
        }
    }
}

struct HealthCategoryDetailView: View {
    let category: HealthCategory
    @Bindable var viewModel: HealthDetailViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HealthPeriodPicker(period: $viewModel.period)
                sectionContent
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: viewModel.period) {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch category {
        case .activity: ActivitySection(viewModel: viewModel)
        case .heart: HeartSection(viewModel: viewModel)
        case .body: BodySection(viewModel: viewModel)
        case .vitals: VitalsSection(viewModel: viewModel)
        case .sleep: SleepSection(viewModel: viewModel)
        case .nutrition: NutritionSection(viewModel: viewModel)
        }
    }
}

private struct ActivitySection: View {
    let viewModel: HealthDetailViewModel
    var body: some View {
        VStack(spacing: 14) {
            HealthMetricChartCard(title: "Steps", icon: "figure.walk", color: PepTheme.teal, series: viewModel.stepsSeries, unit: "steps", format: .integer, chartKind: .bar)
            HealthMetricChartCard(title: "Active Energy", icon: "flame.fill", color: .orange, series: viewModel.activeCalSeries, unit: "cal", format: .integer, chartKind: .bar)
            HealthMetricChartCard(title: "Resting Energy", icon: "bed.double.fill", color: PepTheme.violet, series: viewModel.restingCalSeries, unit: "cal", format: .integer, chartKind: .bar)
            HealthMetricChartCard(title: "Walking + Running Distance", icon: "figure.run", color: .green, series: viewModel.distanceSeries, unit: "mi", format: .decimal1, chartKind: .line)
            HealthMetricChartCard(title: "Flights Climbed", icon: "figure.stairs", color: PepTheme.amber, series: viewModel.flightsSeries, unit: "floors", format: .integer, chartKind: .bar)
            HealthMetricChartCard(title: "Exercise Minutes", icon: "timer", color: .green, series: viewModel.exerciseSeries, unit: "min", format: .integer, chartKind: .bar)
        }
    }
}

private struct HeartSection: View {
    let viewModel: HealthDetailViewModel
    var body: some View {
        VStack(spacing: 14) {
            HeartRateRangeCard(series: viewModel.heartRateSeries)
            HealthMetricChartCard(title: "Resting Heart Rate", icon: "heart.circle.fill", color: .red, series: viewModel.restingHRSeries, unit: "BPM", format: .integer, chartKind: .line)
            HealthMetricChartCard(title: "Heart Rate Variability", icon: "waveform.path.ecg", color: PepTheme.teal, series: viewModel.hrvSeries, unit: "ms", format: .integer, chartKind: .line)
            HealthMetricChartCard(title: "Walking Heart Rate Avg", icon: "figure.walk.motion", color: .pink, series: viewModel.walkingHRSeries, unit: "BPM", format: .integer, chartKind: .line)
            if !viewModel.vo2MaxSeries.isEmpty {
                HealthMetricChartCard(title: "VO₂ Max", icon: "lungs", color: PepTheme.blue, series: viewModel.vo2MaxSeries, unit: "ml/kg·min", format: .decimal1, chartKind: .line)
            }
        }
    }
}

private struct BodySection: View {
    let viewModel: HealthDetailViewModel
    var body: some View {
        VStack(spacing: 14) {
            if !viewModel.weightSeries.isEmpty {
                HealthMetricChartCard(title: "Weight", icon: "scalemass.fill", color: .orange, series: viewModel.weightSeries, unit: "lb", format: .decimal1, chartKind: .line)
            }
            if !viewModel.bodyFatSeries.isEmpty {
                HealthMetricChartCard(title: "Body Fat", icon: "figure.arms.open", color: .orange, series: viewModel.bodyFatSeries, unit: "%", format: .decimal1, chartKind: .line)
            }
            if !viewModel.leanMassSeries.isEmpty {
                HealthMetricChartCard(title: "Lean Body Mass", icon: "figure.strengthtraining.traditional", color: .green, series: viewModel.leanMassSeries, unit: "lb", format: .decimal1, chartKind: .line)
            }
            if !viewModel.bmiSeries.isEmpty {
                HealthMetricChartCard(title: "Body Mass Index", icon: "chart.bar.fill", color: PepTheme.violet, series: viewModel.bmiSeries, unit: "", format: .decimal1, chartKind: .line)
            }
            if !viewModel.waistSeries.isEmpty {
                HealthMetricChartCard(title: "Waist Circumference", icon: "ruler", color: .indigo, series: viewModel.waistSeries, unit: "in", format: .decimal1, chartKind: .line)
            }
            if viewModel.weightSeries.isEmpty && viewModel.bodyFatSeries.isEmpty && viewModel.leanMassSeries.isEmpty && viewModel.bmiSeries.isEmpty && viewModel.waistSeries.isEmpty {
                HealthEmptyState(message: "No body measurement data yet. Log weight and body composition in Apple Health.")
            }
        }
    }
}

private struct VitalsSection: View {
    let viewModel: HealthDetailViewModel
    var body: some View {
        VStack(spacing: 14) {
            if !viewModel.respiratoryRateSeries.isEmpty {
                HealthMetricChartCard(title: "Respiratory Rate", icon: "wind", color: PepTheme.blue, series: viewModel.respiratoryRateSeries, unit: "br/min", format: .integer, chartKind: .line)
            }
            if !viewModel.oxygenSaturationSeries.isEmpty {
                HealthMetricChartCard(title: "Blood Oxygen", icon: "lungs.fill", color: PepTheme.violet, series: viewModel.oxygenSaturationSeries, unit: "%", format: .decimal1, chartKind: .line)
            }
            if !viewModel.bodyTempSeries.isEmpty {
                HealthMetricChartCard(title: "Body Temperature", icon: "thermometer.medium", color: .red, series: viewModel.bodyTempSeries, unit: "°F", format: .decimal1, chartKind: .line)
            }
            if !viewModel.bloodGlucoseSeries.isEmpty {
                HealthMetricChartCard(title: "Blood Glucose", icon: "drop.fill", color: .pink, series: viewModel.bloodGlucoseSeries, unit: "mg/dL", format: .integer, chartKind: .line)
            }
            if !viewModel.systolicSeries.isEmpty || !viewModel.diastolicSeries.isEmpty {
                BloodPressureCard(systolic: viewModel.systolicSeries, diastolic: viewModel.diastolicSeries)
            }
            if viewModel.respiratoryRateSeries.isEmpty && viewModel.oxygenSaturationSeries.isEmpty && viewModel.bodyTempSeries.isEmpty && viewModel.bloodGlucoseSeries.isEmpty && viewModel.systolicSeries.isEmpty && viewModel.diastolicSeries.isEmpty {
                HealthEmptyState(message: "No vital data yet in this period.")
            }
        }
    }
}

private struct SleepSection: View {
    let viewModel: HealthDetailViewModel
    var body: some View {
        SleepCard(nights: viewModel.sleepNights)
    }
}

private struct NutritionSection: View {
    let viewModel: HealthDetailViewModel
    var body: some View {
        VStack(spacing: 14) {
            if !viewModel.hydrationSeries.isEmpty {
                HealthMetricChartCard(title: "Water Intake", icon: "drop.fill", color: PepTheme.blue, series: viewModel.hydrationSeries, unit: "ml", format: .integer, chartKind: .bar)
            }
            if !viewModel.dietaryEnergySeries.isEmpty {
                HealthMetricChartCard(title: "Dietary Energy", icon: "fork.knife", color: PepTheme.amber, series: viewModel.dietaryEnergySeries, unit: "cal", format: .integer, chartKind: .bar)
            }
            if !viewModel.mindfulSeries.isEmpty {
                HealthMetricChartCard(title: "Mindful Minutes", icon: "brain.head.profile", color: PepTheme.teal, series: viewModel.mindfulSeries, unit: "min", format: .integer, chartKind: .bar)
            }
            if viewModel.hydrationSeries.isEmpty && viewModel.dietaryEnergySeries.isEmpty && viewModel.mindfulSeries.isEmpty {
                HealthEmptyState(message: "No nutrition or mindfulness data yet.")
            }
        }
    }
}

private struct HealthEmptyState: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(PepTheme.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 120)
            .padding(16)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 14))
    }
}

private struct HeartRateRangeCard: View {
    let series: [HealthSeriesPoint]

    var body: some View {
        let avgs = series.map(\.value).filter { $0 > 0 }
        let latest = series.last?.value ?? 0
        let avg = avgs.isEmpty ? 0 : avgs.reduce(0, +) / Double(avgs.count)
        let high = series.map(\.max).max() ?? 0
        let low = series.map(\.min).filter { $0 > 0 }.min() ?? 0

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(width: 26, height: 26)
                    .background(Color.red.opacity(0.15))
                    .clipShape(.rect(cornerRadius: 8))
                Text("Heart Rate")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                Text("BPM").font(.caption2).foregroundStyle(PepTheme.textSecondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(latest > 0 ? String(format: "%.0f", latest) : "--")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Avg")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
            }

            if series.isEmpty {
                Text("No heart-rate data in this period.")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                chartBody.frame(height: 160)
            }

            HStack(spacing: 10) {
                HealthStatPill(label: "Avg", value: String(format: "%.0f", avg), unit: "BPM")
                HealthStatPill(label: "High", value: String(format: "%.0f", high), unit: "BPM")
                HealthStatPill(label: "Low", value: low > 0 ? String(format: "%.0f", low) : "--", unit: "BPM")
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
    }

    private var chartBody: some View {
        Chart {
            ForEach(series) { point in
                if point.max > 0 && point.min > 0 {
                    BarMark(
                        x: .value("Date", point.date, unit: .day),
                        yStart: .value("Low", point.min),
                        yEnd: .value("High", point.max),
                        width: .fixed(4)
                    )
                    .foregroundStyle(LinearGradient(
                        colors: [.red.opacity(0.3), .red],
                        startPoint: .bottom,
                        endPoint: .top
                    ))
                    .cornerRadius(3)
                }
                if point.value > 0 {
                    PointMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Avg", point.value)
                    )
                    .foregroundStyle(.white)
                    .symbolSize(20)
                }
            }
        }
    }
}

private struct BloodPressureCard: View {
    let systolic: [HealthSeriesPoint]
    let diastolic: [HealthSeriesPoint]

    var body: some View {
        let sysLatest = systolic.last?.value ?? 0
        let diaLatest = diastolic.last?.value ?? 0
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.indigo)
                    .frame(width: 26, height: 26)
                    .background(Color.indigo.opacity(0.15))
                    .clipShape(.rect(cornerRadius: 8))
                Text("Blood Pressure")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                Text("mmHg").font(.caption2).foregroundStyle(PepTheme.textSecondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(sysLatest > 0 ? String(format: "%.0f/%.0f", sysLatest, diaLatest) : "--")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Latest")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
            }

            chartBody
                .frame(height: 160)
                .chartForegroundStyleScale([
                    "Systolic": Color.indigo,
                    "Diastolic": PepTheme.blue
                ])
                .chartLegend(position: .bottom, alignment: .center, spacing: 10)
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
    }

    private var chartBody: some View {
        Chart {
            ForEach(systolic) { p in
                LineMark(
                    x: .value("Date", p.date),
                    y: .value("Systolic", p.value),
                    series: .value("Type", "Systolic")
                )
                .foregroundStyle(.indigo)
                .interpolationMethod(.monotone)
            }
            ForEach(diastolic) { p in
                LineMark(
                    x: .value("Date", p.date),
                    y: .value("Diastolic", p.value),
                    series: .value("Type", "Diastolic")
                )
                .foregroundStyle(PepTheme.blue)
                .interpolationMethod(.monotone)
            }
        }
    }
}

private struct SleepCard: View {
    let nights: [(date: Date, asleep: Double, deep: Double, rem: Double, core: Double)]

    var body: some View {
        let totals = nights.map { $0.asleep }
        let avg = totals.isEmpty ? 0 : totals.reduce(0, +) / Double(totals.count)
        let last = nights.last

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "bed.double.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PepTheme.violet)
                    .frame(width: 26, height: 26)
                    .background(PepTheme.violet.opacity(0.15))
                    .clipShape(.rect(cornerRadius: 8))
                Text("Sleep Stages")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                Text("hours").font(.caption2).foregroundStyle(PepTheme.textSecondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(last != nil ? String(format: "%.1f", last!.asleep) : "--")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Last Night")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
            }

            if nights.isEmpty {
                Text("No sleep data in this period.")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                chartBody
                    .chartForegroundStyleScale([
                        "Deep": PepTheme.violet,
                        "REM": PepTheme.blue,
                        "Core": PepTheme.teal
                    ])
                    .chartLegend(position: .bottom, alignment: .center, spacing: 10)
                    .frame(height: 180)
            }

            HStack(spacing: 10) {
                HealthStatPill(label: "Avg", value: String(format: "%.1f", avg), unit: "h")
                if let last {
                    HealthStatPill(label: "Deep", value: String(format: "%.1f", last.deep), unit: "h")
                    HealthStatPill(label: "REM", value: String(format: "%.1f", last.rem), unit: "h")
                    HealthStatPill(label: "Core", value: String(format: "%.1f", last.core), unit: "h")
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
    }

    private var chartBody: some View {
        Chart {
            ForEach(Array(nights.enumerated()), id: \.offset) { _, night in
                BarMark(
                    x: .value("Date", night.date, unit: .day),
                    y: .value("Deep", night.deep),
                    stacking: .standard
                )
                .foregroundStyle(by: .value("Stage", "Deep"))
                BarMark(
                    x: .value("Date", night.date, unit: .day),
                    y: .value("REM", night.rem),
                    stacking: .standard
                )
                .foregroundStyle(by: .value("Stage", "REM"))
                BarMark(
                    x: .value("Date", night.date, unit: .day),
                    y: .value("Core", night.core),
                    stacking: .standard
                )
                .foregroundStyle(by: .value("Stage", "Core"))
            }
            RuleMark(y: .value("Goal", 8))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
    }
}
