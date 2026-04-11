import SwiftUI

struct DailyEnergyCard: View {
    @Bindable var viewModel: EnergyBalanceViewModel
    var onLogActivity: () -> Void
    var onTapNutrition: () -> Void

    var body: some View {
        Button {
            onTapNutrition()
        } label: {
            VStack(spacing: 0) {
                energyZone
                    .padding(16)

                Rectangle()
                    .fill(PepTheme.shimmerHighlight)
                    .frame(height: 0.5)
                    .padding(.horizontal, 16)

                macroZone
                    .padding(16)
            }
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.scale)
        .onAppear {
            viewModel.loadData()
        }
    }

    // MARK: - Energy Zone (Top)

    private var energyZone: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                    Text("Daily Energy")
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
                energyBalanceRow

                energyProgressBar

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
                        label: "Eaten",
                        value: "\(viewModel.caloriesConsumed)",
                        color: PepTheme.teal
                    )
                }

                balanceStatusRow
            }
        }
    }

    private var energyBalanceRow: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(viewModel.totalBurn)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("burned")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(viewModel.caloriesConsumed)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("eaten")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
    }

    private var energyProgressBar: some View {
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
            }
        }
        .frame(height: 10)
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
            if viewModel.activityCount > 0 {
                Text("·")
                    .foregroundStyle(PepTheme.textSecondary)
                Text("\(viewModel.activityCount) \(viewModel.activityCount == 1 ? "activity" : "activities")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
        }
        .padding(.top, 2)
    }

    private func energyStat(icon: String, label: String, value: String, color: Color) -> some View {
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

    // MARK: - Macro Zone (Bottom)

    private var macroZone: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(PepTheme.teal)
                Text("Macros")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            if !viewModel.isLoading {
                HStack(spacing: 14) {
                    macroRing(
                        label: "Protein",
                        current: viewModel.proteinConsumed,
                        target: viewModel.proteinTarget,
                        progress: viewModel.proteinProgress,
                        color: PepTheme.amber
                    )
                    macroRing(
                        label: "Carbs",
                        current: viewModel.carbsConsumed,
                        target: viewModel.carbsTarget,
                        progress: viewModel.carbsProgress,
                        color: PepTheme.teal
                    )
                    macroRing(
                        label: "Fat",
                        current: viewModel.fatConsumed,
                        target: viewModel.fatTarget,
                        progress: viewModel.fatProgress,
                        color: PepTheme.violet
                    )
                }
            }
        }
    }

    private func macroRing(label: String, current: Double, target: Int, progress: Double, color: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(PepTheme.elevated, lineWidth: 4)
                    .frame(width: 36, height: 36)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                Text("\(Int(progress * 100))")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                Text("\(Int(current))g")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("/ \(target)g")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
    }
}
