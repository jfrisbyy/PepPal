import SwiftUI

struct DailyNutritionCard: View {
    @Bindable var viewModel: EnergyBalanceViewModel
    var onLogMeal: () -> Void
    var onTapNutrition: () -> Void

    var body: some View {
        Button {
            onTapNutrition()
        } label: {
            GlassCard(accent: PepTheme.amber) {
                VStack(alignment: .leading, spacing: 14) {
                    editorialHeader

                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                                .tint(PepTheme.amber)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    } else {
                        calorieRow
                        calorieProgressBar
                        compactMacroRow
                        quickLogButton
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: viewModel.caloriesConsumed)
    }

    private var editorialHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("FUEL")
                        .font(.system(.caption2, weight: .heavy))
                        .tracking(3.5)
                        .foregroundStyle(PepTheme.amber)
                    Rectangle()
                        .fill(PepTheme.shimmerHighlight)
                        .frame(width: 16, height: 1)
                }
                Text("Nutrition")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            Spacer()
            ZStack {
                Circle()
                    .fill(PepTheme.amber.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: "fork.knife")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PepTheme.amber)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
        }
    }

    private var calorieRow: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(viewModel.caloriesConsumed)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
                    .contentTransition(.numericText())
                Text("cal")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()
            let target = viewModel.dailyCalorieTarget
            if target > 0 {
                let remaining = target - viewModel.caloriesConsumed
                VStack(alignment: .trailing, spacing: 2) {
                    Text(remaining >= 0 ? "\(remaining)" : "\(abs(remaining))")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(remaining >= 0 ? PepTheme.teal : .orange)
                    Text(remaining >= 0 ? "left" : "over")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1.5)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.65))
                }
            }
        }
    }

    private var calorieProgressBar: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let target = max(viewModel.dailyCalorieTarget, 1)
            let progress = min(Double(viewModel.caloriesConsumed) / Double(target), 1.5)
            let barWidth = width * progress

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(PepTheme.elevated)
                    .frame(width: width, height: 8)

                RoundedRectangle(cornerRadius: 5)
                    .fill(
                        LinearGradient(
                            colors: [PepTheme.amber.opacity(0.7), PepTheme.amber],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(barWidth, 4), height: 8)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: barWidth)
            }
        }
        .frame(height: 8)
    }

    private var compactMacroRow: some View {
        HStack(spacing: 14) {
            compactMacro(label: "P", value: Int(viewModel.proteinConsumed), target: viewModel.proteinTarget, color: PepTheme.amber)
            Rectangle()
                .fill(PepTheme.textSecondary.opacity(0.15))
                .frame(width: 1, height: 14)
            compactMacro(label: "C", value: Int(viewModel.carbsConsumed), target: viewModel.carbsTarget, color: PepTheme.teal)
            Rectangle()
                .fill(PepTheme.textSecondary.opacity(0.15))
                .frame(width: 1, height: 14)
            compactMacro(label: "F", value: Int(viewModel.fatConsumed), target: viewModel.fatTarget, color: PepTheme.violet)
            Spacer()
        }
    }

    private func compactMacro(label: String, value: Int, target: Int, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 10, weight: .heavy))
                .tracking(1)
                .foregroundStyle(PepTheme.textSecondary)
            Text("\(value)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(PepTheme.textPrimary)
            Text("/ \(target)g")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
        }
    }

    private var quickLogButton: some View {
        Button {
            onLogMeal()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                Text("Quick Log")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(0.3)
                Spacer()
                Image(systemName: "fork.knife")
                    .font(.system(size: 11, weight: .semibold))
                    .opacity(0.7)
            }
            .foregroundStyle(.white)
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .background(
                LinearGradient(
                    colors: [PepTheme.amber, PepTheme.amber.opacity(0.85)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
