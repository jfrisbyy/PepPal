import SwiftUI

struct BodyGoalSectionView: View {
    @Bindable var viewModel: BodyGoalViewModel
    var aiInsight: String? = nil

    var body: some View {
        VStack(spacing: 8) {
            if let insight = aiInsight {
                AIInsightStrip(content: insight, color: .green)
                    .padding(.horizontal, 2)
            }
            if let line = MorningBriefService.shared.buildLines().bodyGoal {
                BriefLineRow(line: line, icon: "scalemass.fill")
                    .padding(.horizontal, 2)
            }

            Button {
                viewModel.showFullDetail = true
            } label: {
                GlassCard(accent: viewModel.currentGoal.color) {
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
                                    .foregroundStyle(PepTheme.textPrimary)
                                Text(viewModel.currentGoal.subtitle)
                                    .font(.system(.caption2, weight: .medium))
                                    .foregroundStyle(PepTheme.textSecondary)
                            }

                            Spacer()

                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(PepTheme.teal)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                        }

                        if viewModel.currentWeight > 0 {
                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(String(format: "%.1f", viewModel.currentWeight))
                                        .font(.system(.title2, design: .rounded, weight: .bold))
                                        .foregroundStyle(PepTheme.textPrimary)
                                    Text("Current lbs")
                                        .font(.system(.caption2, weight: .medium))
                                        .foregroundStyle(PepTheme.textSecondary)
                                }

                                Rectangle()
                                    .fill(PepTheme.shimmerHighlight)
                                    .frame(width: 1, height: 30)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(String(format: "%.1f", viewModel.targetWeight))
                                        .font(.system(.title2, design: .rounded, weight: .bold))
                                        .foregroundStyle(viewModel.currentGoal.color)
                                    Text("Goal lbs")
                                        .font(.system(.caption2, weight: .medium))
                                        .foregroundStyle(PepTheme.textSecondary)
                                }

                                Rectangle()
                                    .fill(PepTheme.shimmerHighlight)
                                    .frame(width: 1, height: 30)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 2) {
                                        Image(systemName: viewModel.weeklyChange <= 0 ? "arrow.down.right" : "arrow.up.right")
                                            .font(.system(size: 10, weight: .bold))
                                        Text(String(format: "%.1f", abs(viewModel.weeklyChange)))
                                            .font(.system(.title3, design: .rounded, weight: .bold))
                                    }
                                    .foregroundStyle(
                                        viewModel.currentGoal.isLosing
                                        ? (viewModel.weeklyChange <= 0 ? Color(red: 76/255, green: 217/255, blue: 100/255) : Color(red: 255/255, green: 107/255, blue: 107/255))
                                        : (viewModel.weeklyChange >= 0 ? Color(red: 76/255, green: 217/255, blue: 100/255) : Color(red: 255/255, green: 107/255, blue: 107/255))
                                    )
                                    Text("This week")
                                        .font(.system(.caption2, weight: .medium))
                                        .foregroundStyle(PepTheme.textSecondary)
                                }
                            }

                            goalProgressBar
                        } else if !viewModel.isLoading {
                            HStack(spacing: 8) {
                                Image(systemName: "scalemass")
                                    .font(.caption)
                                    .foregroundStyle(PepTheme.textSecondary)
                                Text("Tap to log your first weigh-in")
                                    .font(.caption)
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                        }

                        if let days = viewModel.daysSinceLastWeighIn, days >= 3 {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(PepTheme.amber)
                                Text("Last weigh-in was \(days) days ago")
                                    .font(.system(.caption2, weight: .medium))
                                    .foregroundStyle(PepTheme.amber)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(PepTheme.amber.opacity(0.1))
                            .clipShape(.capsule)
                        }
                    }
                }
            }
            .buttonStyle(.scale)
            .sensoryFeedback(.selection, trigger: viewModel.showFullDetail)
        }
        .onAppear {
            viewModel.loadData()
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
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                Text("\(Int(viewModel.progressToGoal * 100))%")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(viewModel.currentGoal.color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(PepTheme.elevated)
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
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Track your progress consistently")
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(.top, 8)

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Weight (lbs)")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                    TextField("e.g. 185.0", text: $viewModel.newWeighInValue)
                        .keyboardType(.decimalPad)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .padding(14)
                        .background(PepTheme.elevated)
                        .clipShape(.rect(cornerRadius: 12))
                        .focused($weightFocused)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Note (optional)")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                    TextField("Morning, post-workout, etc.", text: $viewModel.newWeighInNote)
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textPrimary)
                        .padding(14)
                        .background(PepTheme.elevated)
                        .clipShape(.rect(cornerRadius: 12))
                }
            }

            if let lastEntry = viewModel.weightEntries.last {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                    Text("Last weigh-in: \(String(format: "%.1f", lastEntry.weight)) lbs on \(lastEntry.date.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }

            Button {
                viewModel.logWeighIn()
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isSaving {
                        ProgressView()
                            .tint(PepTheme.invertedText)
                    }
                    Text("Save Weigh-In")
                        .font(.system(.body, weight: .semibold))
                }
                .foregroundStyle(PepTheme.invertedText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(PepTheme.teal, in: .rect(cornerRadius: 12))
            }
            .buttonStyle(.scale)
            .disabled(viewModel.newWeighInValue.isEmpty || viewModel.isSaving)
            .opacity(viewModel.newWeighInValue.isEmpty ? 0.5 : 1)

            Spacer()
        }
        .padding(.horizontal, 20)
        .appBackground()
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
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("All measurements in inches")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .padding(.top, 8)

                if let lastMeasurement = viewModel.measurements.last {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(PepTheme.textSecondary)
                        Text("Last measured: \(lastMeasurement.date.formatted(.dateTime.month(.abbreviated).day().year()))")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }

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
                    HStack(spacing: 8) {
                        if viewModel.isSaving {
                            ProgressView()
                                .tint(PepTheme.invertedText)
                        }
                        Text("Save Measurements")
                            .font(.system(.body, weight: .semibold))
                    }
                    .foregroundStyle(PepTheme.invertedText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(PepTheme.teal, in: .rect(cornerRadius: 12))
                }
                .buttonStyle(.scale)
                .disabled(viewModel.isSaving)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .appBackground()
    }

    private func measurementField(label: String, value: Binding<String>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(PepTheme.textSecondary)
                Text(label)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            TextField("—", text: value)
                .keyboardType(.decimalPad)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .padding(12)
                .background(PepTheme.elevated)
                .clipShape(.rect(cornerRadius: 10))
        }
    }
}

// MARK: - Goal Picker Sheet

struct GoalPickerSheet: View {
    @Bindable var viewModel: BodyGoalViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedGoal: FitnessGoalType = .weightLoss
    @State private var showDetails: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("Set Your Goal")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Choose a goal type and set your target")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .padding(.top, 8)

                VStack(spacing: 8) {
                    ForEach(FitnessGoalType.allCases) { goal in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedGoal = goal
                                showDetails = true
                            }
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
                                        .foregroundStyle(PepTheme.textPrimary)
                                    Text(goal.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(PepTheme.textSecondary)
                                }

                                Spacer()

                                if selectedGoal == goal {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(goal.color)
                                }
                            }
                            .padding(12)
                            .background(
                                selectedGoal == goal
                                ? goal.color.opacity(0.08)
                                : PepTheme.elevated.opacity(0.5)
                            )
                            .clipShape(.rect(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(
                                        selectedGoal == goal ? goal.color.opacity(0.3) : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if showDetails {
                    goalDetailsSection
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Button {
                    viewModel.currentGoal = selectedGoal
                    viewModel.saveGoal()
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isSaving {
                            ProgressView()
                                .tint(PepTheme.invertedText)
                        }
                        Text("Save Goal")
                            .font(.system(.body, weight: .semibold))
                    }
                    .foregroundStyle(PepTheme.invertedText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(selectedGoal.color, in: .rect(cornerRadius: 12))
                }
                .buttonStyle(.scale)
                .disabled(viewModel.isSaving)
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .presentationContentInteraction(.scrolls)
        .appBackground()
        .onAppear {
            selectedGoal = viewModel.currentGoal
            showDetails = true
        }
    }

    private var goalDetailsSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Target Weight (lbs)")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                TextField("e.g. 175.0", text: $viewModel.goalTargetWeightText)
                    .keyboardType(.decimalPad)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .padding(14)
                    .background(PepTheme.elevated)
                    .clipShape(.rect(cornerRadius: 12))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Target Date")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                DatePicker("", selection: $viewModel.targetDate, in: Date()..., displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(selectedGoal.color)
                    .padding(10)
                    .background(PepTheme.elevated)
                    .clipShape(.rect(cornerRadius: 12))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Weekly Rate (lbs/week)")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                TextField("e.g. 1.0", text: $viewModel.goalWeeklyRateText)
                    .keyboardType(.decimalPad)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .padding(14)
                    .background(PepTheme.elevated)
                    .clipShape(.rect(cornerRadius: 12))

                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                    Text(rateRecommendation)
                        .font(.system(.caption2, weight: .medium))
                }
                .foregroundStyle(PepTheme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Height (cm)")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                HStack {
                    Text(String(format: "%.0f cm", viewModel.heightCm))
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                    Text(heightInFeetInches)
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Slider(value: $viewModel.heightCm, in: 120...220, step: 1)
                    .tint(selectedGoal.color)
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private var rateRecommendation: String {
        if selectedGoal.isLosing {
            return "Recommended: 0.5-1.0 lbs/week for sustainable fat loss"
        } else if selectedGoal.isGaining {
            return "Recommended: 0.25-0.5 lbs/week for lean muscle gain"
        } else {
            return "Set a rate to track maintenance consistency"
        }
    }

    private var heightInFeetInches: String {
        let totalInches = viewModel.heightCm / 2.54
        let feet = Int(totalInches / 12)
        let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
        return "\(feet)'\(inches)\""
    }
}
