import SwiftUI

struct DailyNutritionCard: View {
    @Bindable var viewModel: EnergyBalanceViewModel
    var aiInsight: String? = nil
    var onTapNutrition: () -> Void

    var body: some View {
        Button {
            onTapNutrition()
        } label: {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "fork.knife")
                                .font(.subheadline)
                                .foregroundStyle(PepTheme.amber)
                            Text("Nutrition")
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                    }

                    if let insight = aiInsight {
                        AIInsightStrip(content: insight, color: PepTheme.amber)
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
                        calorieRow

                        calorieProgressBar

                        macroGrid

                        Divider().overlay(PepTheme.shimmerHighlight)

                        macroSummaryRow
                    }
                }
            }
        }
        .buttonStyle(.scale)
    }

    private var calorieRow: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(viewModel.caloriesConsumed)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("cal")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()
            let target = viewModel.dailyCalorieTarget
            if target > 0 {
                let remaining = target - viewModel.caloriesConsumed
                HStack(spacing: 3) {
                    Text(remaining >= 0 ? "\(remaining) left" : "\(abs(remaining)) over")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(remaining >= 0 ? PepTheme.teal : .orange)
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

    private var macroGrid: some View {
        HStack(spacing: 12) {
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

    private func macroRing(label: String, current: Double, target: Int, progress: Double, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(PepTheme.elevated, lineWidth: 5)
                    .frame(width: 44, height: 44)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
            }

            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                Text("\(Int(current))g")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("/ \(target)g")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var macroSummaryRow: some View {
        HStack(spacing: 12) {
            let totalGrams = viewModel.proteinConsumed + viewModel.carbsConsumed + viewModel.fatConsumed
            let proteinPct = totalGrams > 0 ? Int((viewModel.proteinConsumed / totalGrams) * 100) : 0
            let carbsPct = totalGrams > 0 ? Int((viewModel.carbsConsumed / totalGrams) * 100) : 0
            let fatPct = totalGrams > 0 ? 100 - proteinPct - carbsPct : 0

            macroLabel(name: "P", pct: proteinPct, color: PepTheme.amber)
            macroLabel(name: "C", pct: carbsPct, color: PepTheme.teal)
            macroLabel(name: "F", pct: fatPct, color: PepTheme.violet)

            Spacer()

            let totalCalFromMacros = Int(viewModel.proteinConsumed * 4 + viewModel.carbsConsumed * 4 + viewModel.fatConsumed * 9)
            if totalCalFromMacros > 0 {
                Text("\(totalCalFromMacros) cal from macros")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
    }

    private func macroLabel(name: String, pct: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(name) \(pct)%")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
        }
    }
}
