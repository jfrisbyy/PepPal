import SwiftUI

struct MonthlySummaryView: View {
    let summary: MonthlySummaryData
    let bodyGoalViewModel: BodyGoalViewModel
    var selectedMonthDate: Date = Date()
    var programSummary: (programName: String, daysPerWeek: Int, totalDays: Int, dayNames: [String])? = nil

    var body: some View {
        VStack(spacing: 20) {
            editorialHeader
            heroSummaryCard
            if programSummary != nil {
                monthlyProgramCard
            }
            highlightsCard
            weightTrendCard
            workoutTrendCard
            activeMinutesCard
            caloriesBurnedCard
            nutritionTrendCard
            stepsTrendCard
            sleepTrendCard
            monthlyStatsGrid
        }
    }

    // MARK: - Editorial header

    private var editorialHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("THE MONTH IN MOTION")
                .font(.system(.caption2, design: .rounded, weight: .heavy))
                .tracking(2.4)
                .foregroundStyle(PepTheme.amber)
            Text(monthLabel)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
            if let lead = leadInsight {
                Text(lead)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var leadInsight: String? {
        if summary.activeDays > 0 {
            let pct = Int(round(Double(summary.activeDays) / Double(max(summary.totalDays, 1)) * 100))
            return "Active on \(summary.activeDays) of \(summary.totalDays) days (\(pct)%) — \(summary.totalWorkouts) workouts logged."
        }
        if summary.avgStepsPerDay > 0 {
            return "Averaging \(formattedNumber(summary.avgStepsPerDay)) steps and \(summary.totalWorkouts) sessions this month."
        }
        return nil
    }

    // MARK: - Hero

    private var heroSummaryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("This month")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                        Text("\(summary.totalWorkouts)")
                            .font(.system(size: 44, weight: .heavy, design: .rounded))
                            .foregroundStyle(PepTheme.textPrimary)
                            .contentTransition(.numericText())
                        Text("total workouts")
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    Spacer()
                    activeDaysRing
                }

                Divider().overlay(PepTheme.shimmerHighlight)

                HStack(spacing: 0) {
                    overviewStat(value: formattedNumber(summary.totalCaloriesBurned), label: "Cal Burned", icon: "flame.fill", color: .orange)
                    overviewDivider
                    overviewStat(value: "\(summary.totalExerciseMinutes / 60)h", label: "Active", icon: "timer", color: PepTheme.amber)
                    overviewDivider
                    overviewStat(value: formattedNumber(summary.avgStepsPerDay), label: "Avg Steps", icon: "figure.walk", color: .green)
                }
            }
        }
    }

    private var activeDaysRing: some View {
        let progress = summary.totalDays > 0
            ? min(Double(summary.activeDays) / Double(summary.totalDays), 1.0)
            : 0
        return ZStack {
            Circle()
                .stroke(PepTheme.amber.opacity(0.15), lineWidth: 6)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(colors: [PepTheme.amber, PepTheme.teal], startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(summary.activeDays)")
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("of \(summary.totalDays)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .frame(width: 70, height: 70)
    }

    // MARK: - Highlights strip

    private var highlightsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.amber)
                    SubheadText(text: "Highlights")
                    Spacer()
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    if let best = summary.bestStepDay {
                        highlightTile(
                            icon: "trophy.fill",
                            color: .orange,
                            value: formattedNumber(best.steps),
                            label: "Best step day · \(formattedDate(best.date))"
                        )
                    } else {
                        highlightTile(icon: "trophy.fill", color: .orange, value: "—", label: "Best step day")
                    }
                    highlightTile(
                        icon: "flame.fill",
                        color: PepTheme.amber,
                        value: "\(summary.bestStepStreak)",
                        label: "Day step-goal streak"
                    )
                    highlightTile(
                        icon: "figure.strengthtraining.traditional",
                        color: PepTheme.teal,
                        value: String(format: "%.1f/wk", Double(summary.totalWorkouts) / Double(max(summary.weeklyWorkouts.count, 1))),
                        label: "Avg workouts/week"
                    )
                    highlightTile(
                        icon: "bed.double.fill",
                        color: PepTheme.violet,
                        value: String(format: "%.1f hrs", summary.avgSleepHours),
                        label: "Avg sleep"
                    )
                }
            }
        }
    }

    private func highlightTile(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.06))
        .clipShape(.rect(cornerRadius: 12))
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
                    Text("Avg \(String(format: "%.1f", Double(summary.totalWorkouts) / Double(max(summary.weeklyWorkouts.count, 1))))/week")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                }
            }
        }
    }

    private var activeMinutesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "timer")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.amber)
                    SubheadText(text: "Active Minutes")
                    Spacer()
                    Text("\(summary.totalExerciseMinutes) min")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(PepTheme.amber)
                }

                MiniBarChart(data: summary.weeklyExerciseMinutes, barColor: PepTheme.amber, height: 70)
            }
        }
    }

    private var caloriesBurnedCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "flame.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                    SubheadText(text: "Calories Burned")
                    Spacer()
                    Text("\(formattedNumber(summary.totalCaloriesBurned)) kcal")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.orange)
                }

                MiniBarChart(data: summary.weeklyCaloriesBurned, barColor: .orange, height: 70)
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

                MiniBarChart(data: summary.weeklySteps, barColor: .green, height: 80)

                HStack {
                    Text("Daily goal \(formattedNumber(summary.stepGoal))")
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                    Text("Best streak: \(summary.bestStepStreak) days")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(.green)
                }
            }
        }
    }

    private var sleepTrendCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "bed.double.fill")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.violet)
                    SubheadText(text: "Sleep Trend")
                    Spacer()
                    Text(String(format: "avg %.1f hrs", summary.avgSleepHours))
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(PepTheme.violet)
                }

                MiniLineChart(data: summary.weeklySleep, lineColor: PepTheme.violet, height: 70)
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

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
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
