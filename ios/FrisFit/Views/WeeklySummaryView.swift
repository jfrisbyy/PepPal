import SwiftUI

struct WeeklySummaryView: View {
    let summary: WeeklySummaryData
    let bodyGoalViewModel: BodyGoalViewModel
    var selectedWeekStart: Date = Date()
    var weekSchedule: [(dayLabel: String, programDay: ProgramDay?, isToday: Bool)] = []
    var programName: String? = nil

    var body: some View {
        VStack(spacing: 20) {
            editorialHeader
            heroSummaryCard
            if programName != nil {
                weeklyProgramCard
            }
            consistencyCard
            weightProgressCard
            exerciseChartCard
            activeMinutesCard
            caloriesBurnedCard
            nutritionChartCard
            stepsChartCard
            sleepCard
            weeklyStatsGrid
        }
    }

    // MARK: - Editorial header

    private var editorialHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("THE WEEK IN REVIEW")
                .font(.system(.caption2, design: .rounded, weight: .heavy))
                .tracking(2.4)
                .foregroundStyle(PepTheme.teal)
            Text(weekDateRange)
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
        if summary.totalWorkouts >= summary.workoutGoal && summary.workoutGoal > 0 {
            return "You hit your training target — \(summary.totalWorkouts) sessions across \(summary.daysWithFood) tracked days."
        }
        if summary.avgSteps > 0 {
            return "Averaging \(formattedNumber(summary.avgSteps)) steps with \(summary.totalWorkouts) sessions logged this week."
        }
        if summary.daysWithFood > 0 {
            return "Tracked nutrition on \(summary.daysWithFood) of 7 days. Add HealthKit access to unlock activity trends."
        }
        return nil
    }

    // MARK: - Hero overview

    private var heroSummaryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("This week")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                        Text("\(summary.totalWorkouts)")
                            .font(.system(size: 44, weight: .heavy, design: .rounded))
                            .foregroundStyle(PepTheme.textPrimary)
                            .contentTransition(.numericText())
                        Text("workouts completed")
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    Spacer()
                    workoutGoalRing
                }

                Divider().overlay(PepTheme.shimmerHighlight)

                HStack(spacing: 0) {
                    overviewStat(value: formattedNumber(summary.totalCaloriesBurned), label: "Cal Burned", icon: "flame.fill", color: .orange)
                    overviewDivider
                    overviewStat(value: "\(summary.totalExerciseMinutes)", label: "Active Min", icon: "timer", color: PepTheme.amber)
                    overviewDivider
                    overviewStat(value: formattedNumber(summary.totalSteps), label: "Steps", icon: "figure.walk", color: .green)
                }
            }
        }
    }

    private var workoutGoalRing: some View {
        let progress = summary.workoutGoal > 0
            ? min(Double(summary.totalWorkouts) / Double(summary.workoutGoal), 1.0)
            : 0
        return ZStack {
            Circle()
                .stroke(PepTheme.teal.opacity(0.15), lineWidth: 6)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(colors: [PepTheme.teal, PepTheme.amber], startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(summary.totalWorkouts)")
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("of \(max(summary.workoutGoal, 1))")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .frame(width: 70, height: 70)
    }

    // MARK: - Consistency

    private var consistencyCard: some View {
        let dayHasData: [Bool] = summary.dailyWorkouts.enumerated().map { idx, point in
            point.value > 0
                || summary.dailyCalories[safe: idx]?.value ?? 0 > 0
                || summary.dailySteps[safe: idx]?.value ?? 0 > 1000
        }
        let activeCount = dayHasData.filter { $0 }.count
        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.teal)
                    SubheadText(text: "Consistency")
                    Spacer()
                    Text("\(activeCount)/7 days")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.teal)
                }

                HStack(spacing: 6) {
                    ForEach(Array(zip(summary.dailyWorkouts.indices, summary.dailyWorkouts)), id: \.0) { idx, point in
                        VStack(spacing: 6) {
                            Circle()
                                .fill(dayHasData[idx] ? PepTheme.teal : PepTheme.cardSurface)
                                .frame(width: 10, height: 10)
                                .overlay(
                                    Circle().strokeBorder(PepTheme.teal.opacity(0.4), lineWidth: dayHasData[idx] ? 0 : 1)
                                )
                            Text(point.label)
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private var weightProgressCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "scalemass.fill")
                        .font(.subheadline)
                        .foregroundStyle(weightChangeColor)
                    SubheadText(text: "Weight Progress")
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

                if summary.dailyWeight.contains(where: { $0.value > 0 }) {
                    MiniLineChart(data: summary.dailyWeight, lineColor: weightChangeColor, height: 60)
                }

                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start")
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                        Text(String(format: "%.1f", summary.weightStart))
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("lbs")
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }

                    VStack(spacing: 4) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current")
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                        Text(String(format: "%.1f", summary.weightEnd))
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.teal)
                        Text("lbs")
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Goal")
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                        Text(String(format: "%.0f", bodyGoalViewModel.targetWeight))
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.amber)
                        Text("lbs")
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
            }
        }
    }

    private var exerciseChartCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.teal)
                    SubheadText(text: "Workouts")
                    Spacer()
                    Text("\(summary.totalWorkouts) total")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(PepTheme.teal)
                }

                MiniBarChart(data: summary.dailyWorkouts, barColor: PepTheme.teal, height: 80)
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
                    Text("\(summary.totalExerciseMinutes) min total")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(PepTheme.amber)
                }

                MiniBarChart(data: summary.dailyExerciseMinutes, barColor: PepTheme.amber, height: 60)
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

                MiniBarChart(data: summary.dailyCaloriesBurned, barColor: .orange, height: 60)
            }
        }
    }

    private var nutritionChartCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "fork.knife")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.amber)
                    SubheadText(text: "Nutrition")
                    Spacer()
                    Text("avg \(summary.avgCaloriesConsumed) cal/day")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(PepTheme.amber)
                }

                MiniBarChart(data: summary.dailyCalories, barColor: PepTheme.amber, height: 80)

                if summary.calorieGoal > 0 {
                    HStack {
                        Text("Target \(formattedNumber(summary.calorieGoal)) cal/day")
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                        Spacer()
                        Text("Tracked \(summary.daysWithFood)/7 days")
                            .font(.system(.caption2, design: .rounded, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }

                Divider().overlay(PepTheme.shimmerHighlight)

                HStack {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(PepTheme.violet)
                    Text("Protein")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                    Text("avg \(summary.avgProtein)g/day")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(PepTheme.violet)
                }

                MiniBarChart(data: summary.dailyProtein, barColor: PepTheme.violet, height: 60)
                if summary.proteinGoal > 0 {
                    HStack {
                        Text("Target \(summary.proteinGoal)g")
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                        Spacer()
                    }
                }
            }
        }
    }

    private var stepsChartCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "figure.walk")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                    SubheadText(text: "Steps")
                    Spacer()
                    Text("avg \(formattedNumber(summary.avgSteps))/day")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.green)
                }

                MiniBarChart(data: summary.dailySteps, barColor: .green, height: 80)

                let goalDays = summary.dailySteps.filter { Int($0.value) >= summary.stepGoal }.count
                HStack {
                    Text("Goal \(formattedNumber(summary.stepGoal))/day")
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                    Text("\(goalDays)/7 days hit")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(.green)
                }
            }
        }
    }

    private var sleepCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "bed.double.fill")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.violet)
                    SubheadText(text: "Sleep")
                    Spacer()
                    Text(String(format: "avg %.1f hrs/night", summary.avgSleepHours))
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(PepTheme.violet)
                }

                MiniBarChart(data: summary.dailySleep, barColor: PepTheme.violet, height: 60)

                if summary.daysWithSleep > 0 {
                    HStack {
                        Text("Tracked \(summary.daysWithSleep)/7 nights")
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                        Spacer()
                    }
                }
            }
        }
    }

    private var weeklyStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            summaryStatCard(icon: "bed.double.fill", value: String(format: "%.1f hrs", summary.avgSleepHours), label: "Avg Sleep", color: PepTheme.violet)
            summaryStatCard(icon: "figure.walk", value: formattedNumber(summary.totalSteps), label: "Total Steps", color: .green)
            summaryStatCard(icon: "flame.fill", value: formattedNumber(summary.totalCaloriesBurned), label: "Calories Burned", color: .orange)
            summaryStatCard(icon: "clock.fill", value: "\(summary.totalExerciseMinutes) min", label: "Active Time", color: PepTheme.amber)
        }
    }

    // MARK: - Program Schedule

    private var weeklyProgramCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.teal)
                    SubheadText(text: "Training Schedule")
                    Spacer()
                    if let name = programName {
                        Text(name)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(PepTheme.teal)
                            .lineLimit(1)
                    }
                }

                VStack(spacing: 6) {
                    ForEach(Array(weekSchedule.enumerated()), id: \.offset) { _, entry in
                        HStack(spacing: 12) {
                            Text(entry.dayLabel)
                                .font(.system(.caption, design: .rounded, weight: entry.isToday ? .bold : .medium))
                                .foregroundStyle(entry.isToday ? PepTheme.teal : PepTheme.textSecondary)
                                .frame(width: 36, alignment: .leading)

                            if let day = entry.programDay {
                                HStack(spacing: 6) {
                                    Image(systemName: day.timeOfDay?.icon ?? "dumbbell.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(entry.isToday ? PepTheme.teal : PepTheme.textPrimary.opacity(0.7))
                                    Text(day.name)
                                        .font(.system(.subheadline, weight: entry.isToday ? .semibold : .regular))
                                        .foregroundStyle(entry.isToday ? PepTheme.textPrimary : PepTheme.textPrimary.opacity(0.85))
                                    if let tod = day.timeOfDay {
                                        Text(tod.shortLabel)
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(PepTheme.amber)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(PepTheme.amber.opacity(0.15))
                                            .clipShape(Capsule())
                                    }
                                }

                                Spacer()

                                Text("\(day.exercises.count) exercises")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(PepTheme.textSecondary)
                            } else {
                                HStack(spacing: 6) {
                                    Image(systemName: "bed.double.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                                    Text("Rest Day")
                                        .font(.system(.subheadline, weight: .regular))
                                        .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
                                }
                                Spacer()
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            entry.isToday
                                ? PepTheme.teal.opacity(0.08)
                                : Color.clear
                        )
                        .clipShape(.rect(cornerRadius: 8))
                    }
                }

                let trainingDays = weekSchedule.filter { $0.programDay != nil }.count
                let restDays = 7 - trainingDays
                HStack(spacing: 16) {
                    Label("\(trainingDays) training days", systemImage: "figure.strengthtraining.traditional")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(PepTheme.teal)
                    Label("\(restDays) rest", systemImage: "moon.fill")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - Helpers

    private var weekDateRange: String {
        let cal = Calendar.current
        guard let weekEnd = cal.date(byAdding: .day, value: 6, to: selectedWeekStart) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: selectedWeekStart)) – \(formatter.string(from: weekEnd))"
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

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
