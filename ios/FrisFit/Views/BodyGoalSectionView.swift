import SwiftUI

struct BodyGoalSectionView: View {
    @Bindable var viewModel: BodyGoalViewModel

    var body: some View {
        VStack(spacing: 8) {
            if let line = MorningBriefService.shared.buildLines().bodyGoal {
                BriefLineRow(line: line, icon: "scalemass.fill")
                    .padding(.horizontal, 2)
            }

            Button {
                viewModel.showFullDetail = true
            } label: {
                GlassCard(accent: viewModel.currentGoal.color) {
                    VStack(alignment: .leading, spacing: 16) {
                        editorialHeader

                        Rectangle()
                            .fill(PepTheme.shimmerHighlight)
                            .frame(height: 0.5)

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

    private var editorialHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("BODY")
                        .font(.system(.caption2, weight: .heavy))
                        .tracking(3.5)
                        .foregroundStyle(viewModel.currentGoal.color)
                    Rectangle()
                        .fill(PepTheme.shimmerHighlight)
                        .frame(width: 16, height: 1)
                }
                Text(viewModel.currentGoal.rawValue)
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(viewModel.currentGoal.subtitle)
                    .font(.system(.caption, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()
            ZStack {
                Circle()
                    .fill(viewModel.currentGoal.color.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: viewModel.currentGoal.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(viewModel.currentGoal.color)
            }
            if viewModel.isLoading {
                ProgressView()
                    .tint(PepTheme.teal)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.45))
            }
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
    @State private var showSavedConfirmation: Bool = false
    @State private var saveErrorVisible: Bool = false
    @State private var wasSaving: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                editorialHeader

                goalChoiceSection

                if showDetails {
                    goalDetailsSection
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if saveErrorVisible, let err = viewModel.errorMessage {
                    errorBanner(err)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                saveButton
                    .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .presentationContentInteraction(.scrolls)
        .appBackground()
        .overlay(alignment: .top) {
            if showSavedConfirmation {
                savedToast
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .sensoryFeedback(.success, trigger: showSavedConfirmation)
        .sensoryFeedback(.error, trigger: saveErrorVisible)
        .onAppear {
            selectedGoal = viewModel.currentGoal
            showDetails = true
        }
        .onChange(of: viewModel.isSaving) { oldValue, newValue in
            if oldValue == true && newValue == false {
                if viewModel.errorMessage == nil {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                        showSavedConfirmation = true
                    }
                    Task {
                        try? await Task.sleep(for: .seconds(1.6))
                        withAnimation(.easeOut(duration: 0.3)) {
                            showSavedConfirmation = false
                        }
                    }
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        saveErrorVisible = true
                    }
                }
            }
        }
    }

    // MARK: Editorial Header

    private var editorialHeader: some View {
        VStack(spacing: 14) {
            Text("DEFINE")
                .font(.system(.caption2, weight: .heavy))
                .tracking(4)
                .foregroundStyle(selectedGoal.color)

            Text("Set Your Goal")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .multilineTextAlignment(.center)

            Rectangle()
                .fill(PepTheme.shimmerHighlight)
                .frame(width: 40, height: 1)

            Text("A clear target turns intention into momentum. Choose your direction, then dial in the details.")
                .font(.system(.subheadline, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 12)
        }
        .padding(.top, 4)
    }

    // MARK: Goal Selection

    private var goalChoiceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("01", title: "Direction")

            VStack(spacing: 10) {
                ForEach(FitnessGoalType.allCases) { goal in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedGoal = goal
                            showDetails = true
                        }
                    } label: {
                        goalRow(goal)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: selectedGoal)
                }
            }
        }
    }

    private func goalRow(_ goal: FitnessGoalType) -> some View {
        let isSelected = selectedGoal == goal
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(goal.color.opacity(isSelected ? 0.22 : 0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: goal.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(goal.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(goal.rawValue)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(goal.subtitle)
                    .font(.system(.caption, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(goal.color)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Image(systemName: "circle")
                    .font(.title3)
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.3))
            }
        }
        .padding(14)
        .background(
            isSelected
            ? goal.color.opacity(0.08)
            : PepTheme.cardSurface.opacity(0.5)
        )
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    isSelected ? goal.color.opacity(0.35) : PepTheme.glassBorderTop.opacity(0.5),
                    lineWidth: isSelected ? 1 : 0.5
                )
        )
    }

    private func sectionLabel(_ number: String, title: String) -> some View {
        HStack(spacing: 10) {
            Text(number)
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(selectedGoal.color)
            Rectangle()
                .fill(PepTheme.shimmerHighlight)
                .frame(width: 18, height: 1)
            Text(title.uppercased())
                .font(.system(.caption, weight: .heavy))
                .tracking(2)
                .foregroundStyle(PepTheme.textPrimary)
            Spacer()
        }
    }

    // MARK: Save Button

    private var saveButton: some View {
        Button {
            saveErrorVisible = false
            viewModel.errorMessage = nil
            viewModel.currentGoal = selectedGoal
            viewModel.saveGoal()
        } label: {
            HStack(spacing: 10) {
                if viewModel.isSaving {
                    ProgressView()
                        .tint(PepTheme.invertedText)
                } else if showSavedConfirmation {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                }
                Text(showSavedConfirmation ? "Goal Saved" : (viewModel.isSaving ? "Saving…" : "Save Goal"))
                    .font(.system(.body, weight: .semibold))
                    .tracking(0.5)
            }
            .foregroundStyle(PepTheme.invertedText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [selectedGoal.color, selectedGoal.color.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: .rect(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
            )
            .shadow(color: selectedGoal.color.opacity(0.35), radius: 16, y: 6)
        }
        .buttonStyle(.scale)
        .disabled(viewModel.isSaving)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showSavedConfirmation)
    }

    // MARK: Toast & Error

    private var savedToast: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(selectedGoal.color.opacity(0.2))
                    .frame(width: 28, height: 28)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(selectedGoal.color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Goal Saved")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Your target is locked in")
                    .font(.system(.caption2, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(selectedGoal.color.opacity(0.35), lineWidth: 0.75)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 18, y: 8)
        .padding(.horizontal, 24)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(red: 255/255, green: 107/255, blue: 107/255))
            VStack(alignment: .leading, spacing: 2) {
                Text("Couldn't save")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
            Button {
                withAnimation { saveErrorVisible = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .padding(12)
        .background(Color(red: 255/255, green: 107/255, blue: 107/255).opacity(0.1))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(red: 255/255, green: 107/255, blue: 107/255).opacity(0.3), lineWidth: 0.5)
        )
    }

    private var goalDetailsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionLabel("02", title: "Calibrate")

            VStack(spacing: 16) {
                editorialField(label: "Target Weight", suffix: "lbs") {
                    TextField("e.g. 175.0", text: $viewModel.goalTargetWeightText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                }

                editorialField(label: "Target Date", suffix: nil) {
                    DatePicker("", selection: $viewModel.targetDate, in: Date()..., displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(selectedGoal.color)
                }

                editorialField(label: "Weekly Rate", suffix: "lbs/wk") {
                    TextField("e.g. 1.0", text: $viewModel.goalWeeklyRateText)
                        .keyboardType(.decimalPad)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                }

                HStack(spacing: 6) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 9))
                    Text(rateRecommendation)
                        .font(.system(.caption2, design: .serif))
                        .italic()
                }
                .foregroundStyle(PepTheme.textSecondary)
                .padding(.horizontal, 4)

                editorialField(label: "Height", suffix: heightInFeetInches) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(String(format: "%.0f cm", viewModel.heightCm))
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Slider(value: $viewModel.heightCm, in: 120...220, step: 1)
                            .tint(selectedGoal.color)
                    }
                }
            }
            .padding(18)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
            )
        }
    }

    private func editorialField<Content: View>(label: String, suffix: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label.uppercased())
                    .font(.system(.caption2, weight: .heavy))
                    .tracking(1.8)
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                if let suffix {
                    Text(suffix)
                        .font(.system(.caption2, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                }
            }
            content()
            Rectangle()
                .fill(PepTheme.shimmerHighlight)
                .frame(height: 0.5)
        }
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
