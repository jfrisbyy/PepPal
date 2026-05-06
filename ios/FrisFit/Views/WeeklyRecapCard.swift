import SwiftUI

struct WeeklyRecapCard: View {
    let recap: WeeklyRecapSummary
    var onTap: () -> Void = {}

    @State private var shimmerPhase: CGFloat = -1

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 14) {
                header
                headlineRow
                deltaRow
                footer
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .clipShape(.rect(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(LinearGradient(
                        colors: [PepTheme.amber.opacity(0.5), PepTheme.violet.opacity(0.4), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ), lineWidth: 1)
            )
            .overlay(shimmer.allowsHitTesting(false))
            .clipShape(.rect(cornerRadius: 22))
        }
        .buttonStyle(.scale)
        .onAppear {
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                shimmerPhase = 2
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(PepTheme.amber)
            Text("Weekly recap")
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.4)
                .foregroundStyle(PepTheme.amber)
                .textCase(.uppercase)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
        }
    }

    private var headlineRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(recap.workouts)")
                .font(.system(size: 56, weight: .heavy, design: .rounded))
                .foregroundStyle(PepTheme.textPrimary)
                .contentTransition(.numericText())
            VStack(alignment: .leading, spacing: 2) {
                Text(recap.workouts == 1 ? "workout" : "workouts")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("last week")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()
        }
    }

    private var deltaRow: some View {
        HStack(spacing: 10) {
            deltaChip(title: "Workouts", current: recap.workouts, delta: recap.workoutsDelta)
            if recap.volumeKg > 0 {
                deltaChip(title: "Volume", current: recap.volumeKg / 1000, delta: recap.volumeDelta / 1000, unit: "t")
            } else if recap.steps > 0 {
                deltaChip(title: "Steps", current: recap.steps / 1000, delta: recap.stepsDelta / 1000, unit: "k")
            }
        }
    }

    private func deltaChip(title: String, current: Int, delta: Int, unit: String = "") -> some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(PepTheme.textSecondary)
                Text("\(current)\(unit)")
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            Spacer(minLength: 0)
            deltaPill(delta)
        }
        .padding(10)
        .background(PepTheme.elevated.opacity(0.6), in: .rect(cornerRadius: 12))
    }

    private func deltaPill(_ delta: Int) -> some View {
        let positive = delta >= 0
        let icon = positive ? "arrow.up.right" : "arrow.down.right"
        let color: Color = delta == 0 ? PepTheme.textSecondary : (positive ? .green : .red)
        return HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(delta == 0 ? "—" : "\(positive ? "+" : "")\(delta)")
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.12), in: Capsule())
    }

    @ViewBuilder
    private var footer: some View {
        if let pr = recap.latestPR, !pr.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "trophy.fill").foregroundStyle(PepTheme.amber)
                Text("Top PR: \(pr)")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)
            }
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    PepTheme.cardSurface,
                    PepTheme.amber.opacity(0.08),
                    PepTheme.violet.opacity(0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [PepTheme.amber.opacity(0.18), .clear],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 220
            )
        }
    }

    private var shimmer: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [.clear, Color.white.opacity(0.06), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: geo.size.width * 0.4)
            .offset(x: shimmerPhase * geo.size.width)
        }
    }
}

struct WeeklyRecapDetailView: View {
    let recap: WeeklyRecapSummary

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                WeeklyRecapCard(recap: recap)
                    .padding(.horizontal)

                statsGrid

                if let pr = recap.latestPR, !pr.isEmpty {
                    prCard(pr)
                        .padding(.horizontal)
                }

                Color.clear.frame(height: 80)
            }
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .navigationTitle("Weekly Recap")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            statTile(icon: "dumbbell.fill", color: PepTheme.violet, label: "Workouts", value: "\(recap.workouts)", delta: recap.workoutsDelta)
            statTile(icon: "chart.bar.fill", color: PepTheme.teal, label: "Volume", value: "\(recap.volumeKg)kg", delta: recap.volumeDelta)
            statTile(icon: "figure.walk", color: PepTheme.teal, label: "Steps", value: formatThousands(recap.steps), delta: recap.stepsDelta)
            statTile(icon: "bolt.fill", color: .orange, label: "Calories", value: "\(recap.calories)", delta: nil)
            statTile(icon: "drop.fill", color: PepTheme.blue, label: "Water", value: "\(recap.waterMl / 1000)L", delta: nil)
        }
        .padding(.horizontal)
    }

    private func statTile(icon: String, color: Color, label: String, value: String, delta: Int?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                Circle().fill(color.opacity(0.14)).frame(width: 32, height: 32)
                Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(color)
            }
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(PepTheme.textSecondary)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(PepTheme.textPrimary)
            if let delta, delta != 0 {
                Text("\(delta > 0 ? "+" : "")\(delta) vs last")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(delta > 0 ? .green : .red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(PepTheme.cardSurface, in: .rect(cornerRadius: 16))
    }

    private func prCard(_ pr: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 22))
                .foregroundStyle(PepTheme.amber)
            VStack(alignment: .leading, spacing: 2) {
                Text("Top PR last week")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                Text(pr)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            Spacer()
        }
        .padding(16)
        .background(PepTheme.cardSurface, in: .rect(cornerRadius: 16))
    }

    private func formatThousands(_ n: Int) -> String {
        if n >= 1000 { return String(format: "%.1fk", Double(n) / 1000) }
        return "\(n)"
    }
}
