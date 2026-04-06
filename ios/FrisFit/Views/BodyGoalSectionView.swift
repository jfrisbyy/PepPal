import SwiftUI

struct BodyGoalSectionView: View {
    @Bindable var viewModel: BodyGoalViewModel

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                    viewModel.isExpanded.toggle()
                }
            } label: {
                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(viewModel.currentGoal.color.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: viewModel.currentGoal.icon)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(viewModel.currentGoal.color)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.currentGoal.rawValue)
                                    .font(.system(.subheadline, weight: .bold))
                                    .foregroundStyle(FrisTheme.textPrimary)
                                Text(viewModel.currentGoal.subtitle)
                                    .font(.system(.caption2, weight: .medium))
                                    .foregroundStyle(FrisTheme.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(FrisTheme.textSecondary)
                                .rotationEffect(.degrees(viewModel.isExpanded ? 180 : 0))
                        }

                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(format: "%.1f", viewModel.currentWeight))
                                    .font(.system(.title2, design: .rounded, weight: .bold))
                                    .foregroundStyle(FrisTheme.textPrimary)
                                Text("Current lbs")
                                    .font(.system(.caption2, weight: .medium))
                                    .foregroundStyle(FrisTheme.textSecondary)
                            }

                            Rectangle()
                                .fill(FrisTheme.shimmerHighlight)
                                .frame(width: 1, height: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(format: "%.1f", viewModel.targetWeight))
                                    .font(.system(.title2, design: .rounded, weight: .bold))
                                    .foregroundStyle(viewModel.currentGoal.color)
                                Text("Goal lbs")
                                    .font(.system(.caption2, weight: .medium))
                                    .foregroundStyle(FrisTheme.textSecondary)
                            }

                            Rectangle()
                                .fill(FrisTheme.shimmerHighlight)
                                .frame(width: 1, height: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 2) {
                                    Image(systemName: viewModel.weeklyChange <= 0 ? "arrow.down.right" : "arrow.up.right")
                                        .font(.system(size: 10, weight: .bold))
                                    Text(String(format: "%.1f", abs(viewModel.weeklyChange)))
                                        .font(.system(.title3, design: .rounded, weight: .bold))
                                }
                                .foregroundStyle(
                                    (viewModel.currentGoal == .weightLoss || viewModel.currentGoal == .cutting)
                                    ? (viewModel.weeklyChange <= 0 ? Color(red: 76/255, green: 217/255, blue: 100/255) : Color(red: 255/255, green: 107/255, blue: 107/255))
                                    : (viewModel.weeklyChange >= 0 ? Color(red: 76/255, green: 217/255, blue: 100/255) : Color(red: 255/255, green: 107/255, blue: 107/255))
                                )
                                Text("This week")
                                    .font(.system(.caption2, weight: .medium))
                                    .foregroundStyle(FrisTheme.textSecondary)
                            }
                        }

                        goalProgressBar
                    }
                }
            }
            .buttonStyle(.scale)
            .sensoryFeedback(.selection, trigger: viewModel.isExpanded)

            if viewModel.isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .sheet(isPresented: $viewModel.showWeighInSheet) {
            WeighInSheet(viewModel: viewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $viewModel.showMeasurementSheet) {
            MeasurementSheet(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $viewModel.showGoalPicker) {
            GoalPickerSheet(viewModel: viewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .navigationDestination(isPresented: $viewModel.showFullDetail) {
            BodyGoalDetailView(viewModel: viewModel)
        }
    }

    private var goalProgressBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(String(format: "%.1f lbs to go", viewModel.remainingToGoal))
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(FrisTheme.textSecondary)
                Spacer()
                Text("\(Int(viewModel.progressToGoal * 100))%")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(viewModel.currentGoal.color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(FrisTheme.elevated)
                        .frame(height: 6)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [viewModel.currentGoal.color.opacity(0.7), viewModel.currentGoal.color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * viewModel.progressToGoal, height: 6)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.progressToGoal)
                }
            }
            .frame(height: 6)
        }
    }

    private var expandedContent: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                expandedActionButton(icon: "scalemass.fill", label: "Log Weight", color: FrisTheme.cyan) {
                    viewModel.showWeighInSheet = true
                }
                expandedActionButton(icon: "ruler.fill", label: "Measurements", color: FrisTheme.amber) {
                    viewModel.showMeasurementSheet = true
                }
            }

            HStack(spacing: 10) {
                expandedActionButton(icon: "target", label: "Change Goal", color: viewModel.currentGoal.color) {
                    viewModel.showGoalPicker = true
                }
                expandedActionButton(icon: "chart.line.uptrend.xyaxis", label: "Full Details", color: FrisTheme.violet) {
                    viewModel.showFullDetail = true
                }
            }

            bmiCard
        }
        .padding(.top, -6)
        .padding(.horizontal, 2)
    }

    private func expandedActionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(FrisTheme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(FrisTheme.textSecondary.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(FrisTheme.glassBorderTop, lineWidth: 0.5)
            )
        }
        .buttonStyle(.scale)
    }

    private var bmiCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(FrisTheme.elevated, lineWidth: 4)
                    .frame(width: 44, height: 44)
                Circle()
                    .trim(from: 0, to: min(viewModel.bmi.value / 40.0, 1.0))
                    .stroke(viewModel.bmi.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
                Text(String(format: "%.1f", viewModel.bmi.value))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(viewModel.bmi.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("BMI")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(FrisTheme.textPrimary)
                Text(viewModel.bmi.category)
                    .font(.system(.caption2, weight: .medium))
                    .foregroundStyle(viewModel.bmi.color)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f lbs total", abs(viewModel.totalChange)))
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(viewModel.totalChange <= 0 ? Color(red: 76/255, green: 217/255, blue: 100/255) : FrisTheme.textPrimary)
                Text("since start")
                    .font(.system(.caption2, weight: .medium))
                    .foregroundStyle(FrisTheme.textSecondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(FrisTheme.glassBorderTop, lineWidth: 0.5)
        )
    }
}

// MARK: - Weigh In Sheet

struct WeighInSheet: View {
    @Bindable var viewModel: BodyGoalViewModel
    @FocusState private var weightFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 4) {
                Text("Log Weigh-In")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(FrisTheme.textPrimary)
                Text("Track your progress consistently")
                    .font(.subheadline)
                    .foregroundStyle(FrisTheme.textSecondary)
            }
            .padding(.top, 8)

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Weight (lbs)")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(FrisTheme.textSecondary)
                    TextField("e.g. 185.0", text: $viewModel.newWeighInValue)
                        .keyboardType(.decimalPad)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(FrisTheme.textPrimary)
                        .padding(14)
                        .background(FrisTheme.elevated)
                        .clipShape(.rect(cornerRadius: 12))
                        .focused($weightFocused)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Note (optional)")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(FrisTheme.textSecondary)
                    TextField("Morning, post-workout, etc.", text: $viewModel.newWeighInNote)
                        .font(.subheadline)
                        .foregroundStyle(FrisTheme.textPrimary)
                        .padding(14)
                        .background(FrisTheme.elevated)
                        .clipShape(.rect(cornerRadius: 12))
                }
            }

            if let lastEntry = viewModel.weightEntries.last {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundStyle(FrisTheme.textSecondary)
                    Text("Last weigh-in: \(String(format: "%.1f", lastEntry.weight)) lbs")
                        .font(.caption)
                        .foregroundStyle(FrisTheme.textSecondary)
                }
            }

            Button {
                viewModel.logWeighIn()
            } label: {
                Text("Save Weigh-In")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(FrisTheme.invertedText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(FrisTheme.cyan, in: .rect(cornerRadius: 12))
            }
            .buttonStyle(.scale)
            .disabled(viewModel.newWeighInValue.isEmpty)
            .opacity(viewModel.newWeighInValue.isEmpty ? 0.5 : 1)

            Spacer()
        }
        .padding(.horizontal, 20)
        .background(FrisTheme.background.ignoresSafeArea())
        .onAppear { weightFocused = true }
    }
}

// MARK: - Measurement Sheet

struct MeasurementSheet: View {
    @Bindable var viewModel: BodyGoalViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("Body Measurements")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(FrisTheme.textPrimary)
                    Text("All measurements in inches")
                        .font(.subheadline)
                        .foregroundStyle(FrisTheme.textSecondary)
                }
                .padding(.top, 8)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    measurementField(label: "Chest", value: $viewModel.newChest, icon: "figure.arms.open")
                    measurementField(label: "Waist", value: $viewModel.newWaist, icon: "figure.stand")
                    measurementField(label: "Hips", value: $viewModel.newHips, icon: "figure.walk")
                    measurementField(label: "Neck", value: $viewModel.newNeck, icon: "person.bust")
                    measurementField(label: "Left Bicep", value: $viewModel.newBicepLeft, icon: "figure.strengthtraining.traditional")
                    measurementField(label: "Right Bicep", value: $viewModel.newBicepRight, icon: "figure.strengthtraining.traditional")
                    measurementField(label: "Left Thigh", value: $viewModel.newThighLeft, icon: "figure.run")
                    measurementField(label: "Right Thigh", value: $viewModel.newThighRight, icon: "figure.run")
                }

                Button {
                    viewModel.logMeasurement()
                } label: {
                    Text("Save Measurements")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(FrisTheme.invertedText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(FrisTheme.cyan, in: .rect(cornerRadius: 12))
                }
                .buttonStyle(.scale)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(FrisTheme.background.ignoresSafeArea())
    }

    private func measurementField(label: String, value: Binding<String>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(FrisTheme.textSecondary)
                Text(label)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(FrisTheme.textSecondary)
            }
            TextField("—", text: value)
                .keyboardType(.decimalPad)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(FrisTheme.textPrimary)
                .padding(12)
                .background(FrisTheme.elevated)
                .clipShape(.rect(cornerRadius: 10))
        }
    }
}

// MARK: - Goal Picker Sheet

struct GoalPickerSheet: View {
    @Bindable var viewModel: BodyGoalViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("Your Goal")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(FrisTheme.textPrimary)
                Text("What are you working towards?")
                    .font(.subheadline)
                    .foregroundStyle(FrisTheme.textSecondary)
            }
            .padding(.top, 8)

            VStack(spacing: 8) {
                ForEach(FitnessGoalType.allCases) { goal in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.currentGoal = goal
                        }
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(goal.color.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Image(systemName: goal.icon)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(goal.color)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(goal.rawValue)
                                    .font(.system(.subheadline, weight: .semibold))
                                    .foregroundStyle(FrisTheme.textPrimary)
                                Text(goal.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(FrisTheme.textSecondary)
                            }

                            Spacer()

                            if viewModel.currentGoal == goal {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(goal.color)
                            }
                        }
                        .padding(12)
                        .background(
                            viewModel.currentGoal == goal
                            ? goal.color.opacity(0.08)
                            : FrisTheme.elevated.opacity(0.5)
                        )
                        .clipShape(.rect(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    viewModel.currentGoal == goal ? goal.color.opacity(0.3) : Color.clear,
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .background(FrisTheme.background.ignoresSafeArea())
    }
}
