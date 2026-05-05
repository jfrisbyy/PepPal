import SwiftUI

struct WaterIntakeCard: View {
    @State private var viewModel = WaterViewModel.shared
    @State private var selectedDate: Date = Date()
    @State private var showGoalSheet: Bool = false
    @State private var animatedProgress: Double = 0

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "drop.fill")
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.blue)
                        Text("Water")
                            .font(.system(.headline, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                    }

                    Spacer()

                    Button {
                        showGoalSheet = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }

                HStack(alignment: .center, spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(PepTheme.elevated, lineWidth: 10)
                            .frame(width: 78, height: 78)
                        Circle()
                            .trim(from: 0, to: animatedProgress)
                            .stroke(
                                LinearGradient(
                                    colors: [PepTheme.blue.opacity(0.6), PepTheme.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 78, height: 78)

                        VStack(spacing: 0) {
                            Text("\(Int(Double(viewModel.totalMl(for: selectedDate)) / 29.5735))")
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .foregroundStyle(PepTheme.textPrimary)
                            Text("oz")
                                .font(.system(.caption2, weight: .medium))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(viewModel.totalMl(for: selectedDate))ml / \(viewModel.dailyGoalMl)ml")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)

                        let remaining = max(0, viewModel.dailyGoalMl - viewModel.totalMl(for: selectedDate))
                        Text(remaining > 0 ? "\(remaining)ml to goal" : "Goal met!")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)

                        if !viewModel.entries(for: selectedDate).isEmpty {
                            Text("\(viewModel.entries(for: selectedDate).count) logs today")
                                .font(.caption2)
                                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                        }
                    }
                    Spacer()
                }

                HStack(spacing: 8) {
                    ForEach(WaterPreset.allCases) { preset in
                        Button {
                            viewModel.add(amountMl: preset.rawValue)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: preset.icon)
                                    .font(.system(size: 14))
                                Text("\(preset.oz)oz")
                                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                            }
                            .foregroundStyle(PepTheme.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(PepTheme.blue.opacity(0.12))
                            .clipShape(.rect(cornerRadius: 10))
                        }
                        .sensoryFeedback(.impact(weight: .light), trigger: viewModel.totalMl(for: selectedDate))
                    }
                }

                if !viewModel.entries(for: selectedDate).isEmpty {
                    VStack(spacing: 4) {
                        ForEach(viewModel.entries(for: selectedDate).reversed().prefix(3)) { entry in
                            HStack {
                                Image(systemName: "drop.fill")
                                    .font(.caption2)
                                    .foregroundStyle(PepTheme.blue.opacity(0.7))
                                Text("\(entry.amountMl)ml")
                                    .font(.caption)
                                    .foregroundStyle(PepTheme.textPrimary)
                                Text("·")
                                    .foregroundStyle(PepTheme.textSecondary)
                                Text(entry.loggedAt, style: .time)
                                    .font(.caption2)
                                    .foregroundStyle(PepTheme.textSecondary)
                                Spacer()
                                Button {
                                    viewModel.remove(entry)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            animateProgress()
        }
        .onChange(of: viewModel.totalMl(for: selectedDate)) { _, _ in
            animateProgress()
        }
        .task {
            if AuthService.shared.authState == .signedIn {
                await viewModel.load(date: selectedDate)
                animateProgress()
            }
        }
        .sheet(isPresented: $showGoalSheet) {
            WaterGoalSheet(viewModel: viewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private func animateProgress() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            animatedProgress = viewModel.progress(for: selectedDate)
        }
    }
}

struct WaterGoalSheet: View {
    @Bindable var viewModel: WaterViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var goalMl: Double = 2500

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(.largeTitle)
                        .foregroundStyle(PepTheme.blue)
                    Text("Daily Water Goal")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                }

                VStack(spacing: 6) {
                    Text("\(Int(goalMl))ml")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(PepTheme.blue)
                    Text("\(Int(goalMl / 29.5735)) oz")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textSecondary)
                }

                Slider(value: $goalMl, in: 1000...5000, step: 100)
                    .tint(PepTheme.blue)
                    .padding(.horizontal)

                HStack(spacing: 8) {
                    ForEach([2000, 2500, 3000, 3500], id: \.self) { preset in
                        Button {
                            goalMl = Double(preset)
                        } label: {
                            Text("\(preset)ml")
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(PepTheme.elevated)
                                .clipShape(.rect(cornerRadius: 8))
                        }
                    }
                }

                Spacer()

                Button {
                    viewModel.setGoal(Int(goalMl))
                    dismiss()
                } label: {
                    Text("Save")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PepTheme.blue, in: .rect(cornerRadius: 12))
                }
            }
            .padding(20)
            .appBackground()
            .onAppear { goalMl = Double(viewModel.dailyGoalMl) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }
}
