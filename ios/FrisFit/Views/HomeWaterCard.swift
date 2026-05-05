import SwiftUI

struct HomeWaterCard: View {
    @State private var waterVM = WaterViewModel.shared
    @State private var showWaterDetail: Bool = false
    @State private var animatedProgress: Double = 0

    var body: some View {
        let today = Date()
        let totalMl = waterVM.totalMl(for: today)
        let goal = max(waterVM.dailyGoalMl, 1)
        let progress = min(Double(totalMl) / Double(goal), 1.0)
        let oz = Int(Double(totalMl) / 29.5735)
        let goalOz = Int(Double(goal) / 29.5735)
        let remainingOz = max(0, goalOz - oz)
        let useOz = waterVM.unit == .oz
        let primary = useOz ? oz : totalMl
        let primaryGoal = useOz ? goalOz : goal
        let remaining = useOz ? remainingOz : max(0, goal - totalMl)
        let unitLabel = useOz ? "oz" : "ml"

        GlassCard(accent: PepTheme.blue) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "drop.fill")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.blue)
                    Text("Water")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                    Button {
                        showWaterDetail = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .stroke(PepTheme.elevated, lineWidth: 8)
                            .frame(width: 68, height: 68)
                        Circle()
                            .trim(from: 0, to: animatedProgress)
                            .stroke(
                                LinearGradient(
                                    colors: [PepTheme.blue.opacity(0.6), PepTheme.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 68, height: 68)

                        VStack(spacing: 0) {
                            Text("\(primary)")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(PepTheme.textPrimary)
                            Text(unitLabel)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(primary) / \(primaryGoal) \(unitLabel)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text(remaining > 0 ? "\(remaining) \(unitLabel) to goal" : "Goal met")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(remaining > 0 ? PepTheme.textSecondary : PepTheme.teal)
                        Text(useOz ? "\(totalMl) ml" : "\(oz) oz")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                    }
                    Spacer()
                }

                HStack(spacing: 6) {
                    ForEach(WaterPreset.allCases) { preset in
                        Button {
                            waterVM.add(amountMl: preset.rawValue)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: preset.icon)
                                    .font(.system(size: 11, weight: .semibold))
                                Text("+\(preset.oz)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(PepTheme.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(PepTheme.blue.opacity(0.12))
                            .clipShape(.rect(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.impact(weight: .light), trigger: totalMl)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.4) {
            showWaterDetail = true
        }
        .onAppear { animate(to: progress) }
        .onChange(of: progress) { _, new in animate(to: new) }
        .task {
            if AuthService.shared.authState == .signedIn {
                await waterVM.load(date: today)
                animate(to: min(Double(waterVM.totalMl(for: today)) / Double(max(waterVM.dailyGoalMl, 1)), 1.0))
            }
        }
        .sheet(isPresented: $showWaterDetail) {
            WaterDetailSheet(viewModel: waterVM)
                .presentationDragIndicator(.visible)
        }
    }

    private func animate(to value: Double) {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
            animatedProgress = value
        }
    }
}
