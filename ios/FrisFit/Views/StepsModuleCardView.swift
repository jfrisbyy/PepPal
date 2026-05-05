import SwiftUI

struct StepsModuleCardView: View {
    let healthKit: HealthKitService
    @Binding var showStepDetail: Bool

    var body: some View {
        Button {
            showStepDetail = true
        } label: {
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    stepsInfo
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                        StepProgressRing(steps: healthKit.steps)
                    }
                }
                StepHourlyMiniChart()
                    .padding(.top, 12)
            }
            .padding(16)
            .background(
                PepTheme.teal.opacity(0.06)
                    .overlay(PepTheme.cardSurface.opacity(0.88))
                    .overlay(PepTheme.cardOverlay)
            )
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: [PepTheme.teal.opacity(0.2), PepTheme.teal.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: PepTheme.teal.opacity(0.1), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.scale)
        .navigationDestination(isPresented: $showStepDetail) {
            StepDetailView()
        }
    }

    private var stepsInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "figure.walk")
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.teal)
                SubheadText(text: "Steps")
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(Self.formattedStepsNumber(healthKit.steps))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
                    .contentTransition(.numericText())
            }

            Text("\(String(format: "%.1f", healthKit.distanceMiles)) mi \u{00b7} \(healthKit.flightsClimbed) floors")
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
    }

    static func formattedStepsNumber(_ steps: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
    }
}

struct StepProgressRing: View {
    let steps: Int

    var body: some View {
        let goal = max(UserDefaults.standard.integer(forKey: "step_goal"), 10000)
        let progress = min(Double(steps) / Double(goal == 0 ? 10000 : goal), 1.0)

        ZStack {
            Circle()
                .stroke(PepTheme.elevated, lineWidth: 5)
                .frame(width: 48, height: 48)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    PepTheme.teal,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .frame(width: 48, height: 48)
                .rotationEffect(.degrees(-90))

            Text("\(Int(progress * 100))%")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(PepTheme.teal)
        }
    }
}

struct StepHourlyMiniChart: View {
    var body: some View {
        GeometryReader { geo in
            let currentHour = Calendar.current.component(.hour, from: Date())
            let hours = (0...max(currentHour, 1))
            let barCount = max(hours.count, 1)
            let spacing: CGFloat = 1.5
            let barWidth = max((geo.size.width - spacing * CGFloat(barCount - 1)) / CGFloat(barCount), 2)

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(Array(hours), id: \.self) { hour in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(PepTheme.teal.opacity(0.4))
                        .frame(width: barWidth, height: max(3, 28 * Self.miniChartRatio(for: hour)))
                }
            }
        }
        .frame(height: 28)
    }

    private static func miniChartRatio(for hour: Int) -> CGFloat {
        let typicalDistribution: [CGFloat] = [
            0.02, 0.01, 0.01, 0.01, 0.02, 0.03, 0.05, 0.08,
            0.10, 0.08, 0.07, 0.06, 0.08, 0.06, 0.05, 0.06,
            0.07, 0.08, 0.06, 0.04, 0.03, 0.02, 0.01, 0.01
        ]
        guard hour < typicalDistribution.count else { return 0.02 }
        let maxRatio = typicalDistribution.max() ?? 0.1
        return typicalDistribution[hour] / maxRatio
    }
}
