import SwiftUI

struct DailyActivityCard: View {
    @Bindable var viewModel: EnergyBalanceViewModel
    var aiInsight: String? = nil
    var onLogActivity: () -> Void
    @State private var isExpanded: Bool = false

    private let stepsColor = Color(red: 0.38, green: 0.82, blue: 0.55)
    private let exerciseColor = Color.orange

    var body: some View {
        GlassCard(accent: .orange) {
            VStack(alignment: .leading, spacing: 0) {
                collapsedContent

                if isExpanded {
                    expandedContent
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                isExpanded.toggle()
            }
        }
        .sensoryFeedback(.selection, trigger: isExpanded)
        .onAppear {
            viewModel.loadData()
        }
    }

    // MARK: - Collapsed

    private var collapsedContent: some View {
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
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                    .contentTransition(.symbolEffect(.replace))
            }

            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView().tint(PepTheme.teal)
                    Spacer()
                }
                .padding(.vertical, 24)
            } else {
                ringAndContext
                balanceBar
            }
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

                if let needed = viewModel.additionalActiveCaloriesNeeded {
                    Text("Need \(needed) more to hit deficit")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.orange.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                } else if let headroom = viewModel.additionalFoodAllowed,
                          viewModel.targetBalanceDelta ?? 0 < 0 {
                    Text("\(headroom) cal headroom to eat")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.green.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
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

    // MARK: - Expanded

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider().overlay(PepTheme.shimmerHighlight)
                .padding(.top, 12)

            if let insight = aiInsight {
                AIInsightStrip(content: insight, color: .orange)
            }

            if let line = MorningBriefService.shared.buildLines().training {
                BriefLineRow(line: line, icon: "figure.strengthtraining.traditional")
            }

            breakdownTiles

            if viewModel.tefCalories > 0 {
                HStack(spacing: 6) {
                    Text("~\(viewModel.tefCalories) cal digestion (TEF)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.8))
                    Spacer()
                }
            }

            if let hint = goalHint {
                goalHintCard(hint)
            }

            if let source = viewModel.activitySourceDescription {
                sourceAttributionRow(source)
            }

            logActivityButton

            if !viewModel.weeklyTrend.isEmpty {
                weeklyTrendSection
            }

            if !viewModel.unifiedActivities.isEmpty {
                recentActivitiesSection
            }
        }
    }

    private var breakdownTiles: some View {
        HStack(spacing: 8) {
            stepsBreakdownTile
            breakdownTile(
                icon: "figure.run",
                label: "Exercise",
                value: viewModel.exerciseCalories,
                color: exerciseColor,
                dimmed: false
            )
            breakdownTile(
                icon: "bolt.heart.fill",
                label: "Resting",
                value: viewModel.restingBurn,
                color: PepTheme.violet,
                dimmed: false
            )
        }
    }

    private var stepsBreakdownTile: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(stepsColor)
                Text("Steps")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Text(formattedSteps(viewModel.stepsToday))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(PepTheme.textPrimary)
            Text(viewModel.stepsCalories > 0 ? "\(viewModel.stepsCalories) cal" : "steps")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(stepsColor.opacity(viewModel.hasWatchData ? 0.08 : 0.04))
        .clipShape(.rect(cornerRadius: 10))
        .opacity(viewModel.hasWatchData ? 1 : 0.6)
    }

    private func formattedSteps(_ steps: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
    }

    private func breakdownTile(icon: String, label: String, value: Int, color: Color, dimmed: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Text("\(value)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(PepTheme.textPrimary)
            Text("cal")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(color.opacity(dimmed ? 0.04 : 0.08))
        .clipShape(.rect(cornerRadius: 10))
        .opacity(dimmed ? 0.6 : 1)
    }

    private var goalHint: String? {
        if let needed = viewModel.additionalActiveCaloriesNeeded {
            let foodToReduce = needed
            return "To hit your deficit: burn \(needed) more active or eat \(foodToReduce) less."
        }
        if let headroom = viewModel.additionalFoodAllowed,
           viewModel.targetBalanceDelta ?? 0 < 0 {
            return "You've earned \(headroom) cal of headroom — on track for your deficit."
        }
        return nil
    }

    private func goalHintCard(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "target")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(10)
        .background(Color.orange.opacity(0.08))
        .clipShape(.rect(cornerRadius: 10))
    }

    private func sourceAttributionRow(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: viewModel.hasWatchData ? "applewatch" : "square.and.pencil")
                .font(.system(size: 11))
                .foregroundStyle(viewModel.hasWatchData ? .green : PepTheme.textSecondary)
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
    }

    private var weeklyTrendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("7-Day Activity Trend")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                if viewModel.weeklyAvgBurn > 0 {
                    Text("avg \(viewModel.weeklyAvgBurn) cal")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.orange.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.orange.opacity(0.1))
                        .clipShape(.capsule)
                }
            }

            MiniBarChart(data: viewModel.weeklyTrend, barColor: .orange, height: 60)
        }
        .padding(.top, 4)
    }

    private var logActivityButton: some View {
        Button {
            onLogActivity()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text("Log Activity")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(.orange.gradient)
            .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var recentActivitiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's Activities")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)

            ForEach(viewModel.unifiedActivities.prefix(5)) { activity in
                unifiedActivityRow(activity)
            }
        }
    }

    private func unifiedActivityRow(_ activity: UnifiedActivity) -> some View {
        HStack(spacing: 10) {
            Image(systemName: activityIcon(forSport: activity.sport))
                .font(.system(size: 12))
                .foregroundStyle(.orange)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(activity.sport)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(1)
                    if activity.source == .appleWatch {
                        Image(systemName: "applewatch")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.green)
                    }
                }
                Text("\(activity.durationMinutes) min")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
            }

            Spacer()

            if activity.calories > 0 {
                Text("\(activity.calories) cal")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(PepTheme.elevated.opacity(0.5))
        .clipShape(.rect(cornerRadius: 8))
    }

    private func activityIcon(forSport sport: String) -> String {
        switch sport.lowercased() {
        case "walking": return "figure.walk"
        case "running": return "figure.run"
        case "cycling": return "figure.outdoor.cycle"
        case "swimming": return "figure.pool.swim"
        case "hiking": return "figure.hiking"
        case "yoga": return "figure.yoga"
        case "hiit": return "bolt.heart.fill"
        case "rowing": return "figure.rowing"
        case "elliptical": return "figure.elliptical"
        case "jump rope": return "figure.jumprope"
        case "stair climbing": return "figure.stairs"
        case "boxing": return "figure.boxing"
        case "martial arts": return "figure.martial.arts"
        case "pilates": return "figure.pilates"
        case "rock climbing": return "figure.climbing"
        case "basketball": return "basketball.fill"
        case "soccer": return "soccerball"
        case "tennis": return "tennis.racket"
        case "football": return "football.fill"
        case "baseball": return "baseball.fill"
        case "dancing": return "figure.dance"
        case "stretching": return "figure.flexibility"
        case "strength": return "figure.strengthtraining.traditional"
        case "cardio": return "figure.mixed.cardio"
        default: return "flame.fill"
        }
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
