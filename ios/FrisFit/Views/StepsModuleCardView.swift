import SwiftUI

struct StepsModuleCardView: View {
    let healthKit: HealthKitService
    let stepsCalories: Int
    @Binding var showStepDetail: Bool
    @State private var animateProgress: Bool = false

    private var goal: Int {
        let stored = UserDefaults.standard.integer(forKey: "step_goal")
        return stored > 0 ? stored : 10000
    }

    private var progress: Double {
        min(Double(healthKit.steps) / Double(max(goal, 1)), 1.0)
    }

    var body: some View {
        Button {
            showStepDetail = true
        } label: {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TODAY")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(2.4)
                            .foregroundStyle(PepTheme.teal)

                        Text(Self.formattedStepsNumber(healthKit.steps))
                            .font(.system(size: 48, weight: .semibold, design: .serif))
                            .kerning(-1.2)
                            .foregroundStyle(PepTheme.textPrimary)
                            .contentTransition(.numericText())
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)

                        Text("of \(Self.formattedStepsNumber(goal)) goal \u{00b7} \(Int(progress * 100))%")
                            .font(.system(.caption, design: .serif))
                            .italic()
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    Spacer(minLength: 0)
                    heroRing
                }

                Rectangle()
                    .fill(LinearGradient(colors: [PepTheme.teal.opacity(0.5), PepTheme.teal.opacity(0)], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 0.75)

                HStack(spacing: 0) {
                    heroMetric(label: "Distance", value: String(format: "%.2f", healthKit.distanceMiles), unit: "mi")
                    Divider().overlay(PepTheme.separatorColor).frame(height: 30)
                    heroMetric(label: "Floors", value: "\(healthKit.flightsClimbed)", unit: "climbed")
                    Divider().overlay(PepTheme.separatorColor).frame(height: 30)
                    heroMetric(label: "Active", value: "\(stepsCalories)", unit: "cal")
                }
            }
            .padding(20)
            .background(
                ZStack {
                    PepTheme.cardSurface
                    LinearGradient(
                        colors: [PepTheme.teal.opacity(0.10), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .clipShape(.rect(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        LinearGradient(colors: [PepTheme.teal.opacity(0.28), PepTheme.teal.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 0.6
                    )
            )
            .overlay(alignment: .topLeading) {
                Rectangle()
                    .fill(PepTheme.teal)
                    .frame(width: 2, height: 44)
                    .padding(.top, 20)
            }
            .shadow(color: PepTheme.teal.opacity(0.12), radius: 16, x: 0, y: 6)
        }
        .buttonStyle(.scale)
        .onAppear {
            withAnimation(.spring(response: 0.85, dampingFraction: 0.75)) {
                animateProgress = true
            }
        }
        .navigationDestination(isPresented: $showStepDetail) {
            StepDetailView(stepsCaloriesOverride: stepsCalories)
        }
    }

    private var heroRing: some View {
        ZStack {
            Circle()
                .stroke(PepTheme.elevated, lineWidth: 8)
                .frame(width: 84, height: 84)

            Circle()
                .trim(from: 0, to: animateProgress ? progress : 0)
                .stroke(
                    AngularGradient(
                        colors: [PepTheme.teal, PepTheme.tealDeep, PepTheme.teal],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 84, height: 84)
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PepTheme.teal)
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
                    .contentTransition(.numericText())
            }
        }
    }

    private func heroMetric(label: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.6)
                .foregroundStyle(PepTheme.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
