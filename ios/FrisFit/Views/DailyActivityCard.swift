import SwiftUI

struct DailyActivityCard: View {
    @Bindable var viewModel: EnergyBalanceViewModel
    var onLogActivity: () -> Void
    var onTapActivity: () -> Void

    private let stepsColor = Color(red: 0.38, green: 0.82, blue: 0.55)
    private let exerciseColor = Color.orange

    var body: some View {
        Button {
            onTapActivity()
        } label: {
            GlassCard(accent: .orange) {
                VStack(alignment: .leading, spacing: 14) {
                    editorialHeader

                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView().tint(.orange)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    } else {
                        ringAndContext
                        balanceBar
                        quickLogButton
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: viewModel.activeCaloriesBurned)
        .onAppear {
            viewModel.loadData()
        }
    }

    private var editorialHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("MOVE")
                        .font(.system(.caption2, weight: .heavy))
                        .tracking(3.5)
                        .foregroundStyle(.orange)
                    Rectangle()
                        .fill(PepTheme.shimmerHighlight)
                        .frame(width: 16, height: 1)
                }
                Text("Activity")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: "flame.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.orange)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
        }
    }

    private var ringAndContext: some View {
        HStack(alignment: .center, spacing: 18) {
            SegmentedMoveRing(
                stepsCalories: viewModel.stepsCalories,
                exerciseCalories: viewModel.exerciseCalories,
                goal: viewModel.activeGoal,
                stepsColor: stepsColor,
                exerciseColor: exerciseColor
            )
            .frame(width: 108, height: 108)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: viewModel.isActiveGoalMet ? "checkmark.circle.fill" : "target")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(viewModel.isActiveGoalMet ? .green : PepTheme.textSecondary)
                    Text("Goal \(viewModel.activeGoal) active")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                }

                HStack(spacing: 5) {
                    legendDot(stepsColor)
                    Text("Steps")
                        .font(.system(size: 11))
                        .foregroundStyle(PepTheme.textSecondary)
                    Text(formattedSteps(viewModel.stepsToday))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(PepTheme.textPrimary)
                    if viewModel.stepsCalories > 0 {
                        Text("· \(viewModel.stepsCalories) cal")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                    }
                }

                HStack(spacing: 5) {
                    legendDot(exerciseColor)
                    Text("Exercise")
                        .font(.system(size: 11))
                        .foregroundStyle(PepTheme.textSecondary)
                    Text("\(viewModel.exerciseCalories)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(PepTheme.textPrimary)
                }

                Text("+\(viewModel.restingBurn) resting")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func legendDot(_ color: Color) -> some View {
        Circle().fill(color).frame(width: 6, height: 6)
    }

    private var balanceBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                let width = geo.size.width
                let intakeRatio = viewModel.totalBurn > 0
                    ? min(Double(viewModel.caloriesConsumed) / Double(viewModel.totalBurn), 1.5)
                    : 0
                let intakeWidth = width * intakeRatio

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(PepTheme.elevated)
                        .frame(width: width, height: 4)

                    Capsule()
                        .fill(viewModel.isGoalAligned ? Color.green.opacity(0.85) : Color.orange.opacity(0.85))
                        .frame(width: max(intakeWidth, 4), height: 4)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: intakeWidth)

                    if viewModel.totalBurn > 0, intakeRatio < 1.5 {
                        Circle()
                            .fill(PepTheme.textPrimary.opacity(0.35))
                            .frame(width: 5, height: 5)
                            .offset(x: width - 3)
                    }
                }
            }
            .frame(height: 6)

            HStack(spacing: 6) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 9))
                Text("\(viewModel.caloriesConsumed) eaten")
                    .font(.system(size: 10, weight: .medium))
                Text("·")
                    .font(.system(size: 10))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                Text(viewModel.balanceLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(viewModel.isGoalAligned ? .green : .orange)
                Spacer()
            }
            .foregroundStyle(PepTheme.textSecondary)
        }
        .padding(.top, 4)
    }

    private var quickLogButton: some View {
        Button {
            onLogActivity()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                Text("Quick Log")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(0.3)
                Spacer()
                Image(systemName: "figure.run")
                    .font(.system(size: 11, weight: .semibold))
                    .opacity(0.7)
            }
            .foregroundStyle(.white)
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .background(
                LinearGradient(
                    colors: [.orange, .orange.opacity(0.85)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func formattedSteps(_ steps: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
    }
}

// MARK: - Segmented Move Ring

private struct SegmentedMoveRing: View {
    let stepsCalories: Int
    let exerciseCalories: Int
    let goal: Int
    let stepsColor: Color
    let exerciseColor: Color

    private var total: Int { stepsCalories + exerciseCalories }

    private var stepsFraction: Double {
        guard goal > 0 else { return 0 }
        return min(Double(stepsCalories) / Double(goal), 1.0)
    }

    private var exerciseFraction: Double {
        guard goal > 0 else { return 0 }
        let remaining = max(0, 1.0 - stepsFraction)
        let raw = Double(exerciseCalories) / Double(goal)
        return min(raw, remaining)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(PepTheme.elevated, lineWidth: 12)

            Circle()
                .trim(from: 0, to: stepsFraction)
                .stroke(stepsColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.7, dampingFraction: 0.85), value: stepsFraction)

            Circle()
                .trim(from: stepsFraction, to: stepsFraction + exerciseFraction)
                .stroke(exerciseColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.7, dampingFraction: 0.85), value: exerciseFraction)

            VStack(spacing: 0) {
                Text("\(total)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
                    .contentTransition(.numericText())
                Text("active")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
        }
    }
}
