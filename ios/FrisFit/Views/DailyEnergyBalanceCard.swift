import SwiftUI

struct DailyEnergyBalanceCard: View {
    @Bindable var viewModel: EnergyBalanceViewModel
    var onLogActivity: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                        SubheadText(text: "Daily Energy Balance")
                    }
                    Spacer()
                    Button {
                        onLogActivity()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                            Text("Log Activity")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(PepTheme.teal)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(PepTheme.teal.opacity(0.12))
                        .clipShape(.capsule)
                    }
                }

                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(PepTheme.teal)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } else {
                    energyGauge

                    HStack(spacing: 0) {
                        energyStat(
                            icon: "bolt.heart.fill",
                            label: "BMR",
                            value: "\(viewModel.bmr)",
                            color: PepTheme.violet
                        )
                        Spacer()
                        energyStat(
                            icon: "figure.run",
                            label: "Activity",
                            value: "\(viewModel.activityCalories)",
                            color: .orange
                        )
                        Spacer()
                        energyStat(
                            icon: "fork.knife",
                            label: "Intake",
                            value: "\(viewModel.caloriesConsumed)",
                            color: PepTheme.teal
                        )
                    }

                    HStack(spacing: 8) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(viewModel.isGoalAligned ? .green : .orange)
                                .frame(width: 6, height: 6)
                            Text(viewModel.balanceLabel)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(viewModel.isGoalAligned ? .green : .orange)
                        }
                        if viewModel.activityCount > 0 {
                            Text("·")
                                .foregroundStyle(PepTheme.textSecondary)
                            Text("\(viewModel.activityCount) \(viewModel.activityCount == 1 ? "activity" : "activities") tracked")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.top, 2)
                }
            }
        }
        .onAppear {
            viewModel.loadData()
        }
    }

    private var energyGauge: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(viewModel.totalBurn)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("cal burned")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                Text("\(viewModel.caloriesConsumed)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("eaten")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            GeometryReader { geo in
                let width = geo.size.width
                let burnWidth = width
                let intakeRatio = viewModel.totalBurn > 0 ? min(Double(viewModel.caloriesConsumed) / Double(viewModel.totalBurn), 1.5) : 0
                let intakeWidth = width * intakeRatio

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(PepTheme.elevated)
                        .frame(width: burnWidth, height: 12)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: viewModel.isGoalAligned
                                    ? [.green.opacity(0.8), .green]
                                    : [.orange.opacity(0.8), .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(intakeWidth, 4), height: 12)
                }
            }
            .frame(height: 12)
        }
    }

    private func energyStat(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(PepTheme.textPrimary)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
