import SwiftUI

struct DailyActivityCard: View {
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
                        Text("Activity")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                    }
                    Spacer()
                    Button {
                        onLogActivity()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                            Text("Log")
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
                    caloriesBurnedHeader

                    HStack(spacing: 0) {
                        activityStat(
                            icon: "bolt.heart.fill",
                            label: "BMR",
                            value: "\(viewModel.bmr)",
                            color: PepTheme.violet
                        )
                        activityStatDivider
                        activityStat(
                            icon: "figure.run",
                            label: "Exercise",
                            value: "\(viewModel.activityCalories)",
                            color: .orange
                        )
                        activityStatDivider
                        activityStat(
                            icon: "flame.fill",
                            label: "Total Burn",
                            value: "\(viewModel.totalBurn)",
                            color: Color(red: 1, green: 0.35, blue: 0.35)
                        )
                    }

                    energyBalanceBar

                    balanceStatusRow
                }
            }
        }
        .onAppear {
            viewModel.loadData()
        }
    }

    private var caloriesBurnedHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(viewModel.totalBurn)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("cal burned")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()
            if viewModel.activityCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                    Text("\(viewModel.activityCount) \(viewModel.activityCount == 1 ? "activity" : "activities")")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(PepTheme.teal)
            }
        }
    }

    private var activityStatDivider: some View {
        Rectangle()
            .fill(PepTheme.shimmerHighlight)
            .frame(width: 1, height: 40)
    }

    private func activityStat(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(PepTheme.textPrimary)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var energyBalanceBar: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let intakeRatio = viewModel.totalBurn > 0 ? min(Double(viewModel.caloriesConsumed) / Double(viewModel.totalBurn), 1.5) : 0
            let intakeWidth = width * intakeRatio

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(PepTheme.elevated)
                    .frame(width: width, height: 10)

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
                    .frame(width: max(intakeWidth, 4), height: 10)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: intakeWidth)

                if viewModel.totalBurn > 0 {
                    Rectangle()
                        .fill(PepTheme.textPrimary.opacity(0.5))
                        .frame(width: 2, height: 16)
                        .offset(x: width - 1)
                }
            }
        }
        .frame(height: 16)
        .padding(.top, 2)
    }

    private var balanceStatusRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Circle()
                    .fill(viewModel.isGoalAligned ? .green : .orange)
                    .frame(width: 6, height: 6)
                Text(viewModel.balanceLabel)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(viewModel.isGoalAligned ? .green : .orange)
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 10))
                Text("\(viewModel.caloriesConsumed) eaten")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(PepTheme.textSecondary)
        }
    }
}
