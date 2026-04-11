import SwiftUI

struct MonthlySummaryView: View {
    let summary: MonthlySummaryData
    let bodyGoalViewModel: BodyGoalViewModel
    var selectedMonthDate: Date = Date()
    var programSummary: (programName: String, daysPerWeek: Int, totalDays: Int, dayNames: [String])? = nil

    var body: some View {
        VStack(spacing: 20) {
            monthOverviewCard
            if programSummary != nil {
                monthlyProgramCard
            }
            weightTrendCard
            workoutTrendCard
            nutritionTrendCard
            stepsTrendCard
            monthlyStatsGrid
        }
    }

    private var monthOverviewCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.teal)
                    SubheadText(text: monthLabel)
                    Spacer()
                    Text("30 days")
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }

                HStack(spacing: 0) {
                    overviewStat(value: "\(summary.totalWorkouts)", label: "Workouts", icon: "figure.strengthtraining.traditional", color: PepTheme.teal)
                    overviewDivider
                    overviewStat(value: formattedNumber(summary.totalCaloriesBurned), label: "Cal Burned", icon: "flame.fill", color: .orange)
                    overviewDivider
                    overviewStat(value: "\(summary.totalExerciseMinutes / 60)h", label: "Active", icon: "timer", color: PepTheme.amber)
                }
            }
        }
    }

    private var weightTrendCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "scalemass.fill")
                        .font(.subheadline)
                        .foregroundStyle(weightChangeColor)
                    SubheadText(text: "Weight Trend")
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: summary.weightChange < 0 ? "arrow.down.right" : (summary.weightChange > 0 ? "arrow.up.right" : "equal"))
                            .font(.system(size: 10, weight: .bold))
                        Text(String(format: "%+.1f lbs", summary.weightChange))
                            .font(.system(.caption, design: .rounded, weight: .bold))
                    }
                    .foregroundStyle(weightChangeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(weightChangeColor.opacity(0.12))
                    .clipShape(.capsule)
                }

                MiniLineChart(data: summary.weeklyWeight, lineColor: weightChangeColor, height: 90)

                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start of Month")
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                        Text(String(format: "%.1f lbs", summary.weightStart))
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Current")
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                        Text(String(format: "%.1f lbs", summary.weightEnd))
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.teal)
                    }
                }
            }
        }
    }

    private var workoutTrendCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.teal)
                    SubheadText(text: "Exercise Frequency")
                    Spacer()
                    Text("\(summary.totalWorkouts) total")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(PepTheme.teal)
                }

                MiniBarChart(data: summary.weeklyWorkouts, barColor: PepTheme.teal, height: 80)

                HStack {
                    Text("Avg \(summary.totalWorkouts / max(summary.weeklyWorkouts.count, 1))/week")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                }
            }
        }
    }

    private var nutritionTrendCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "fork.knife")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.amber)
                    SubheadText(text: "Nutrition Trend")
                    Spacer()
                    Text("avg \(summary.avgCaloriesConsumed) cal/day")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(PepTheme.amber)
                }

                MiniLineChart(data: summary.weeklyCalories, lineColor: PepTheme.amber, height: 80)

                Divider().overlay(PepTheme.shimmerHighlight)

                HStack(spacing: 16) {
                    Label {
                        Text("Avg Protein: \(summary.avgProtein)g/day")
                            .font(.system(.caption, weight: .medium))
                    } icon: {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(PepTheme.violet)

                    Spacer()
                }
            }
        }
    }

    private var stepsTrendCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "figure.walk")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                    SubheadText(text: "Steps Trend")
                    Spacer()
                    Text("avg \(formattedNumber(summary.avgStepsPerDay))/day")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.green)
                }

                MiniLineChart(data: summary.weeklySteps, lineColor: .green, height: 80)
            }
        }
    }

    private var monthlyStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            summaryStatCard(icon: "bed.double.fill", value: String(format: "%.1f hrs", summary.avgSleepHours), label: "Avg Sleep", color: PepTheme.violet)
            summaryStatCard(icon: "figure.walk", value: formattedNumber(summary.avgStepsPerDay), label: "Avg Steps/Day", color: .green)
            summaryStatCard(icon: "flame.fill", value: formattedNumber(summary.totalCaloriesBurned), label: "Total Cal Burned", color: .orange)
            summaryStatCard(icon: "clock.fill", value: "\(summary.totalExerciseMinutes) min", label: "Total Active", color: PepTheme.amber)
        }
    }

    // MARK: - Program Overview

    private var monthlyProgramCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.teal)
                    SubheadText(text: "Training Program")
                    Spacer()
                }

                if let info = programSummary {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 22))
                                .foregroundStyle(PepTheme.teal)
                                .frame(width: 40, height: 40)
                                .background(PepTheme.teal.opacity(0.12))
                                .clipShape(.rect(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(info.programName)
                                    .font(.system(.headline, design: .rounded, weight: .bold))
                                    .foregroundStyle(PepTheme.textPrimary)
                                Text("\(info.daysPerWeek) days/week")
                                    .font(.system(.caption, weight: .medium))
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                            Spacer()
                        }

                        Divider().overlay(PepTheme.shimmerHighlight)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Weekly Split")
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(PepTheme.textSecondary)

                            let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: min(info.dayNames.count, 4))
                            LazyVGrid(columns: columns, spacing: 6) {
                                ForEach(Array(info.dayNames.enumerated()), id: \.offset) { _, name in
                                    Text(name)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(PepTheme.teal)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(PepTheme.teal.opacity(0.08))
                                        .clipShape(.rect(cornerRadius: 8))
                                }
                            }
                        }

                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Image(systemName: "target")
                                    .font(.system(size: 11))
                                Text("~\(info.totalDays) sessions this month")
                                    .font(.system(.caption, weight: .medium))
                            }
                            .foregroundStyle(PepTheme.amber)

                            Spacer()

                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 11))
                                Text("\(summary.totalWorkouts) completed")
                                    .font(.system(.caption, weight: .medium))
                            }
                            .foregroundStyle(PepTheme.teal)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonthDate)
    }

    private var weightChangeColor: Color {
        let goal = bodyGoalViewModel.currentGoal
        if goal == .weightLoss || goal == .cutting {
            return summary.weightChange <= 0 ? Color(red: 76/255, green: 217/255, blue: 100/255) : Color(red: 255/255, green: 107/255, blue: 107/255)
        } else if goal == .weightGain || goal == .bulking {
            return summary.weightChange >= 0 ? Color(red: 76/255, green: 217/255, blue: 100/255) : Color(red: 255/255, green: 107/255, blue: 107/255)
        }
        return PepTheme.teal
    }

    private func overviewStat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var overviewDivider: some View {
        Rectangle()
            .fill(PepTheme.shimmerHighlight)
            .frame(width: 1, height: 44)
    }

    private func summaryStatCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
                Spacer()
            }
            HStack {
                Text(value)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
            }
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
            }
        }
        .padding(14)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(
                        colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 3)
    }

    private func formattedNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}
