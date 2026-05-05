import SwiftUI

struct ActivityView: View {
    @Bindable var viewModel: EnergyBalanceViewModel
    var aiInsight: String? = nil
    @State private var showLogActivity: Bool = false

    private let stepsColor = Color(red: 0.38, green: 0.82, blue: 0.55)
    private let exerciseColor = Color.orange

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                heroRingCard
                if let insight = aiInsight {
                    AIInsightStrip(content: insight, color: .orange)
                }
                breakdownCard
                balanceCard
                trendCard
                if !viewModel.unifiedActivities.isEmpty {
                    activitiesCard
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
            .padding(.top, 4)
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showLogActivity = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                }
            }
        }
        .sheet(isPresented: $showLogActivity) {
            LogActivitySheet()
                .presentationDetents([.large])
        }
        .onChange(of: showLogActivity) { _, isShowing in
            if !isShowing {
                Task { await viewModel.refresh() }
            }
        }
        .onAppear { viewModel.loadData() }
    }

    // MARK: - Hero Ring

    private var heroRingCard: some View {
        GlassCard(accent: .orange, size: .hero) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("MOVE")
                                .font(.system(.caption2, weight: .heavy))
                                .tracking(3.5)
                                .foregroundStyle(.orange)
                            Rectangle()
                                .fill(PepTheme.shimmerHighlight)
                                .frame(width: 22, height: 1)
                        }
                        Text("Today's Burn")
                            .font(.system(size: 26, weight: .bold, design: .serif))
                            .foregroundStyle(PepTheme.textPrimary)
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.12))
                            .frame(width: 38, height: 38)
                        Image(systemName: "flame.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                }

                HStack(alignment: .center, spacing: 22) {
                    HeroMoveRing(
                        stepsCalories: viewModel.stepsCalories,
                        exerciseCalories: viewModel.exerciseCalories,
                        goal: viewModel.activeGoal,
                        stepsColor: stepsColor,
                        exerciseColor: exerciseColor
                    )
                    .frame(width: 150, height: 150)

                    VStack(alignment: .leading, spacing: 10) {
                        legendRow(color: stepsColor, label: "Steps", value: formattedSteps(viewModel.stepsToday), trailing: viewModel.stepsCalories > 0 ? "\(viewModel.stepsCalories) cal" : nil)
                        legendRow(color: exerciseColor, label: "Exercise", value: "\(viewModel.exerciseCalories)", trailing: "cal")
                        legendRow(color: PepTheme.violet, label: "Resting", value: "\(viewModel.restingBurn)", trailing: "cal")

                        HStack(spacing: 5) {
                            Image(systemName: viewModel.isActiveGoalMet ? "checkmark.circle.fill" : "target")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(viewModel.isActiveGoalMet ? .green : .orange)
                            Text("Goal \(viewModel.activeGoal)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                        }
                        .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let source = viewModel.activitySourceDescription {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.hasWatchData ? "applewatch" : "square.and.pencil")
                            .font(.system(size: 11))
                            .foregroundStyle(viewModel.hasWatchData ? .green : PepTheme.textSecondary)
                        Text(source)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                        Spacer()
                    }
                }

                logActivityButton
            }
        }
    }

    private func legendRow(color: Color, label: String, value: String, trailing: String?) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
            Spacer(minLength: 6)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(PepTheme.textPrimary)
            if let trailing {
                Text(trailing)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
            }
        }
    }

    private var logActivityButton: some View {
        Button {
            showLogActivity = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text("Log Activity")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.orange.gradient)
            .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Breakdown

    private var breakdownCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                editorialSubtitle(eyebrow: "BREAKDOWN", title: "Energy Sources")

                HStack(spacing: 10) {
                    breakdownTile(
                        icon: "figure.walk",
                        label: "Steps",
                        value: viewModel.stepsCalories,
                        subtitle: formattedSteps(viewModel.stepsToday) + " steps",
                        color: stepsColor,
                        dimmed: !viewModel.hasWatchData && viewModel.stepsToday == 0
                    )
                    breakdownTile(
                        icon: "figure.run",
                        label: "Exercise",
                        value: viewModel.exerciseCalories,
                        subtitle: viewModel.unifiedActivities.isEmpty ? "no activity" : "\(viewModel.unifiedActivities.count) logged",
                        color: exerciseColor,
                        dimmed: false
                    )
                    breakdownTile(
                        icon: "bolt.heart.fill",
                        label: "Resting",
                        value: viewModel.restingBurn,
                        subtitle: "BMR · NEAT",
                        color: PepTheme.violet,
                        dimmed: false
                    )
                }

                if viewModel.tefCalories > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(PepTheme.amber.opacity(0.85))
                        Text("~\(viewModel.tefCalories) cal digestion (TEF)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.85))
                        Spacer()
                    }
                }
            }
        }
    }

    private func breakdownTile(icon: String, label: String, value: Int, subtitle: String, color: Color, dimmed: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Text("\(value)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(PepTheme.textPrimary)
            Text(subtitle)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(color.opacity(dimmed ? 0.04 : 0.10))
        .clipShape(.rect(cornerRadius: 12))
        .opacity(dimmed ? 0.6 : 1)
    }

    // MARK: - Balance

    private var balanceCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                editorialSubtitle(eyebrow: "BALANCE", title: "Eaten vs. Burned")

                GeometryReader { geo in
                    let width = geo.size.width
                    let intakeRatio = viewModel.totalBurn > 0
                        ? min(Double(viewModel.caloriesConsumed) / Double(viewModel.totalBurn), 1.5)
                        : 0
                    let intakeWidth = width * intakeRatio

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(PepTheme.elevated)
                            .frame(width: width, height: 8)
                        Capsule()
                            .fill(viewModel.isGoalAligned ? Color.green.opacity(0.85) : Color.orange.opacity(0.85))
                            .frame(width: max(intakeWidth, 6), height: 8)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: intakeWidth)

                        if viewModel.totalBurn > 0, intakeRatio < 1.5 {
                            Circle()
                                .fill(PepTheme.textPrimary.opacity(0.4))
                                .frame(width: 7, height: 7)
                                .offset(x: width - 4)
                        }
                    }
                }
                .frame(height: 10)

                HStack(spacing: 14) {
                    balanceStat(label: "Eaten", value: "\(viewModel.caloriesConsumed)", icon: "fork.knife", color: PepTheme.amber)
                    Rectangle().fill(PepTheme.textSecondary.opacity(0.15)).frame(width: 1, height: 22)
                    balanceStat(label: "Burned", value: "\(viewModel.totalBurn)", icon: "flame.fill", color: .orange)
                    Rectangle().fill(PepTheme.textSecondary.opacity(0.15)).frame(width: 1, height: 22)
                    balanceStat(
                        label: viewModel.isDeficit ? "Deficit" : "Surplus",
                        value: "\(abs(viewModel.balance))",
                        icon: viewModel.isDeficit ? "arrow.down.circle.fill" : "arrow.up.circle.fill",
                        color: viewModel.isGoalAligned ? .green : .orange
                    )
                }

                if let hint = goalHint {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "target")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.orange)
                            .padding(.top, 1)
                        Text(hint)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 10))
                }
            }
        }
    }

    private func balanceStat(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(PepTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var goalHint: String? {
        if let needed = viewModel.additionalActiveCaloriesNeeded {
            return "To hit your deficit: burn \(needed) more active or eat \(needed) less."
        }
        if let headroom = viewModel.additionalFoodAllowed,
           viewModel.targetBalanceDelta ?? 0 < 0 {
            return "You've earned \(headroom) cal of headroom — on track for your deficit."
        }
        return nil
    }

    // MARK: - Trend

    private var trendCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    editorialSubtitle(eyebrow: "TRENDS", title: "7-Day Activity")
                    Spacer()
                    if viewModel.weeklyAvgBurn > 0 {
                        Text("avg \(viewModel.weeklyAvgBurn)")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.orange.opacity(0.12))
                            .clipShape(.capsule)
                    }
                }

                if viewModel.weeklyTrend.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 22))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                        Text("Not enough data yet")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    MiniBarChart(data: viewModel.weeklyTrend, barColor: .orange, height: 90)
                }
            }
        }
    }

    // MARK: - Activities List

    private var activitiesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                editorialSubtitle(eyebrow: "TODAY", title: "Activities")

                VStack(spacing: 8) {
                    ForEach(viewModel.unifiedActivities) { activity in
                        unifiedActivityRow(activity)
                    }
                }
            }
        }
    }

    private func unifiedActivityRow(_ activity: UnifiedActivity) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: activityIcon(forSport: activity.sport))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(activity.sport)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(1)
                    if activity.source == .appleWatch {
                        Image(systemName: "applewatch")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.green)
                    }
                }
                Text("\(activity.durationMinutes) min")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            if activity.calories > 0 {
                Text("\(activity.calories)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
                +
                Text(" cal")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(PepTheme.elevated.opacity(0.5))
        .clipShape(.rect(cornerRadius: 10))
    }

    // MARK: - Helpers

    private func editorialSubtitle(eyebrow: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(eyebrow)
                    .font(.system(.caption2, weight: .heavy))
                    .tracking(3)
                    .foregroundStyle(.orange)
                Rectangle()
                    .fill(PepTheme.shimmerHighlight)
                    .frame(width: 16, height: 1)
            }
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
        }
    }

    private func formattedSteps(_ steps: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
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

// MARK: - Hero Move Ring

private struct HeroMoveRing: View {
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
                .stroke(PepTheme.elevated, lineWidth: 16)

            Circle()
                .trim(from: 0, to: stepsFraction)
                .stroke(
                    LinearGradient(
                        colors: [stepsColor.opacity(0.7), stepsColor],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: stepsColor.opacity(0.35), radius: 8)
                .animation(.spring(response: 0.7, dampingFraction: 0.85), value: stepsFraction)

            Circle()
                .trim(from: stepsFraction, to: stepsFraction + exerciseFraction)
                .stroke(
                    LinearGradient(
                        colors: [exerciseColor.opacity(0.7), exerciseColor],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: exerciseColor.opacity(0.35), radius: 8)
                .animation(.spring(response: 0.7, dampingFraction: 0.85), value: exerciseFraction)

            VStack(spacing: 0) {
                Text("\(total)")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
                    .contentTransition(.numericText())
                Text("ACTIVE CAL")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1.5)
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
    }
}
