import SwiftUI

struct DailyActivityCard: View {
    @Bindable var viewModel: EnergyBalanceViewModel
    var aiInsight: String? = nil
    var onLogActivity: () -> Void
    @State private var isExpanded: Bool = false

    var body: some View {
        GlassCard {
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

    private var collapsedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                    ProgressView()
                        .tint(PepTheme.teal)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                caloriesBurnedHeader
                energyBalanceBar
                balanceStatusRow
            }
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider().overlay(PepTheme.shimmerHighlight)
                .padding(.top, 12)

            if let insight = aiInsight {
                AIInsightStrip(content: insight, color: .orange)
            }

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

            logActivityButton

            if !viewModel.todaysActivities.isEmpty {
                recentActivitiesSection
            }
        }
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

            ForEach(Array(viewModel.todaysActivities.prefix(5).enumerated()), id: \.element.id) { _, activity in
                recentActivityRow(activity)
            }
        }
    }

    private func recentActivityRow(_ activity: EnergyActivityLog) -> some View {
        HStack(spacing: 10) {
            Image(systemName: activityIcon(for: activity.activity_type))
                .font(.system(size: 12))
                .foregroundStyle(.orange)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(activity.sport ?? activity.activity_type.capitalized)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)

                if let dur = activity.duration_minutes {
                    Text("\(dur) min")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                }
            }

            Spacer()

            if let cal = activity.calories_burned {
                Text("\(cal) cal")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(PepTheme.elevated.opacity(0.5))
        .clipShape(.rect(cornerRadius: 8))
    }

    private func activityIcon(for type: String) -> String {
        switch type.lowercased() {
        case "workout", "strength": return "figure.strengthtraining.traditional"
        case "cardio", "running": return "figure.run"
        case "walking": return "figure.walk"
        case "cycling": return "figure.outdoor.cycle"
        case "swimming": return "figure.pool.swim"
        default: return "flame.fill"
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
