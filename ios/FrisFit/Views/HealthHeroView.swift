import SwiftUI
import Charts

struct HealthHeroView: View {
    @Bindable var viewModel: HealthDetailViewModel
    let onConnectTap: () -> Void

    @State private var animateIn: Bool = false

    var body: some View {
        VStack(spacing: 14) {
            topRow
            vitalsStrip
        }
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.75)) {
                animateIn = true
            }
        }
    }

    private var topRow: some View {
        HStack(spacing: 14) {
            recoveryOrb
                .frame(maxWidth: .infinity)
            ringsCard
                .frame(maxWidth: .infinity)
        }
    }

    private var recoveryOrb: some View {
        let hk = viewModel.healthKit
        let score = hk.recoveryScore ?? 0
        let tint: Color = score >= 75 ? .green : (score >= 55 ? PepTheme.amber : .red)
        let label: String = {
            if hk.recoveryScore == nil { return "Connect for recovery" }
            if score >= 75 { return "Primed — push today" }
            if score >= 55 { return "Moderate — steady" }
            return "Low — prioritize rest"
        }()

        return VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [tint.opacity(0.35), tint.opacity(0.02)],
                            center: .center,
                            startRadius: 2,
                            endRadius: 70
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 8)

                Circle()
                    .stroke(tint.opacity(0.18), lineWidth: 8)
                    .frame(width: 96, height: 96)

                Circle()
                    .trim(from: 0, to: animateIn ? CGFloat(score) / 100 : 0)
                    .stroke(
                        AngularGradient(colors: [tint.opacity(0.7), tint, tint.opacity(0.7)], center: .center),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 96, height: 96)

                VStack(spacing: 0) {
                    Text(hk.recoveryScore != nil ? "\(score)" : "—")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(PepTheme.textPrimary)
                        .contentTransition(.numericText())
                    Text("RECOVERY")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1.2)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            Text(label)
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(tint)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 170)
        .padding(.vertical, 14)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    LinearGradient(colors: [tint.opacity(0.3), tint.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    private var ringsCard: some View {
        let hk = viewModel.healthKit
        let movePct = min(hk.activeCalories / Double(max(viewModel.activeEnergyGoal, 1)), 1.0)
        let exPct = min(hk.exerciseMinutes / Double(max(viewModel.exerciseGoal, 1)), 1.0)
        let standPct = min(Double(hk.standHours) / Double(max(viewModel.standGoal, 1)), 1.0)

        return VStack(spacing: 8) {
            ZStack {
                TripleRing(
                    move: animateIn ? movePct : 0,
                    exercise: animateIn ? exPct : 0,
                    stand: animateIn ? standPct : 0
                )
                .frame(width: 110, height: 110)
            }
            HStack(spacing: 6) {
                ringLegend("Move", value: "\(Int(hk.activeCalories))", unit: "cal", color: .red)
                ringLegend("Ex", value: "\(Int(hk.exerciseMinutes))", unit: "m", color: .green)
                ringLegend("Stand", value: "\(hk.standHours)", unit: "h", color: PepTheme.teal)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 170)
        .padding(.vertical, 14)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    LinearGradient(colors: [PepTheme.teal.opacity(0.25), PepTheme.violet.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    private func ringLegend(_ label: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(unit)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    private var vitalsStrip: some View {
        HStack(spacing: 8) {
            vitalPill(
                icon: "figure.walk",
                label: "Steps",
                value: formatInt(viewModel.healthKit.steps),
                series: viewModel.stepsSeries,
                deltaPct: viewModel.stepsTrend.deltaPct,
                higherBetter: true,
                color: PepTheme.teal
            )
            vitalPill(
                icon: "heart.fill",
                label: "RHR",
                value: viewModel.healthKit.restingHeartRate.map { "\(Int($0))" } ?? "—",
                series: viewModel.restingHRSeries,
                deltaPct: viewModel.rhrTrend.deltaPct,
                higherBetter: false,
                color: .red
            )
            vitalPill(
                icon: "waveform.path.ecg",
                label: "HRV",
                value: viewModel.healthKit.hrv.map { "\(Int($0))" } ?? "—",
                series: viewModel.hrvSeries,
                deltaPct: viewModel.hrvTrend.deltaPct,
                higherBetter: true,
                color: .pink
            )
            vitalPill(
                icon: "bed.double.fill",
                label: "Sleep",
                value: viewModel.healthKit.sleepHours > 0 ? String(format: "%.1fh", viewModel.healthKit.sleepHours) : "—",
                series: viewModel.sleepSeries,
                deltaPct: viewModel.sleepTrend.deltaPct,
                higherBetter: true,
                color: PepTheme.violet
            )
        }
    }

    private func vitalPill(icon: String, label: String, value: String, series: [HealthSeriesPoint], deltaPct: Double?, higherBetter: Bool, color: Color) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.6)
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer(minLength: 0)
            }

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(value)
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 0)
            }

            miniSparkline(series: series, color: color)
                .frame(height: 18)

            if let d = deltaPct {
                deltaChip(d, higherBetter: higherBetter)
            } else {
                Text("—")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(color.opacity(0.2), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func miniSparkline(series: [HealthSeriesPoint], color: Color) -> some View {
        let tail = Array(series.suffix(7))
        if tail.count < 2 {
            Rectangle().fill(color.opacity(0.1)).frame(maxWidth: .infinity)
        } else {
            Chart(tail) { p in
                LineMark(x: .value("i", p.date), y: .value("v", p.value))
                    .foregroundStyle(color)
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
                AreaMark(x: .value("i", p.date), y: .value("v", p.value))
                    .foregroundStyle(LinearGradient(colors: [color.opacity(0.25), color.opacity(0)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartPlotStyle { $0.background(.clear) }
        }
    }

    private func deltaChip(_ pct: Double, higherBetter: Bool) -> some View {
        let positive = higherBetter ? pct >= 0 : pct <= 0
        let color: Color = positive ? .green : .red
        let symbol = pct >= 0 ? "arrow.up" : "arrow.down"
        return HStack(spacing: 2) {
            Image(systemName: symbol)
                .font(.system(size: 8, weight: .heavy))
            Text("\(String(format: "%.0f", abs(pct)))%")
                .font(.system(size: 9, weight: .heavy, design: .rounded))
            Spacer(minLength: 0)
        }
        .foregroundStyle(color)
    }

    private func formatInt(_ n: Int) -> String {
        if n >= 10_000 { return String(format: "%.1fk", Double(n) / 1000) }
        let f = NumberFormatter(); f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

struct TripleRing: View {
    let move: Double
    let exercise: Double
    let stand: Double

    var body: some View {
        ZStack {
            ring(progress: move, color: .red, lineWidth: 10, inset: 0)
            ring(progress: exercise, color: .green, lineWidth: 10, inset: 14)
            ring(progress: stand, color: PepTheme.teal, lineWidth: 10, inset: 28)
        }
    }

    private func ring(progress: Double, color: Color, lineWidth: CGFloat, inset: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                .stroke(
                    AngularGradient(colors: [color.opacity(0.7), color, color.opacity(0.8)], center: .center),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 1.0, dampingFraction: 0.8), value: progress)
        }
        .padding(inset)
    }
}
