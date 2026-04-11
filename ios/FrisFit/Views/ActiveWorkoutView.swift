import SwiftUI

struct ActiveWorkoutView: View {
    @Bindable var viewModel: ActiveWorkoutViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var sessionManager = WorkoutSessionManager.shared

    var body: some View {
        NavigationStack {
            if viewModel.isCompleted, let summary = viewModel.summary {
                WorkoutSummaryView(summary: summary) {
                    sessionManager.endSession()
                    dismiss()
                }
            } else {
                workoutContent
            }
        }
    }

    private var workoutContent: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 20) {
                    elapsedTimerSection
                    exerciseProgressBar
                    if viewModel.isRestTimerActive {
                        RestTimerView(
                            secondsRemaining: viewModel.restSecondsRemaining,
                            totalSeconds: viewModel.restSecondsTotal,
                            onSkip: { viewModel.skipRestTimer() }
                        )
                    }
                    if let exercise = viewModel.currentExercise {
                        currentExerciseHeader(exercise)
                        setLoggingTable(exerciseIndex: viewModel.currentExerciseIndex, exercise: exercise)
                    }
                    Spacer().frame(height: 100)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .scrollDismissesKeyboard(.interactively)

            floatingActions

            if viewModel.activeNumberInput != nil {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { viewModel.applyNumberInput() }

                VStack {
                    Spacer()
                    NumberInputView(
                        value: $viewModel.numberInputValue,
                        isWeight: isWeightInput,
                        onDone: { viewModel.applyNumberInput() },
                        onIncrement: { viewModel.incrementInput(by: $0) }
                    )
                }
                .transition(.move(edge: .bottom))
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.activeNumberInput != nil)
            }
        }
        .background(PepTheme.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    viewModel.finishWorkout()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                        Text("End")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(Color.red.opacity(0.9))
                }
            }
            ToolbarItem(placement: .principal) {
                Text(viewModel.workoutName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    sessionManager.minimizeWorkout()
                } label: {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(PepTheme.teal)
                        .symbolRenderingMode(.hierarchical)
                }
            }
        }
        .onChange(of: viewModel.currentExerciseIndex) { _, newValue in
            sessionManager.updateProgress(newValue, total: viewModel.exercises.count)
        }
        .sheet(isPresented: $viewModel.showExerciseInfo) {
            if let exercise = viewModel.currentExercise {
                exerciseInfoSheet(exercise.exercise)
            }
        }
        .sheet(isPresented: $viewModel.showExercisePicker) {
            ExercisePickerView { exercises in
                viewModel.addExercises(exercises)
                viewModel.showExercisePicker = false
            }
        }
    }

    private var isWeightInput: Bool {
        if let field = viewModel.activeNumberInput {
            switch field {
            case .weight: return true
            case .reps: return false
            }
        }
        return true
    }

    private var elapsedTimerSection: some View {
        VStack(spacing: 4) {
            Text(viewModel.formattedElapsedTime)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(PepTheme.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText())

            Text("ELAPSED")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var exerciseProgressBar: some View {
        HStack(spacing: 4) {
            ForEach(Array(viewModel.exercises.enumerated()), id: \.element.id) { index, exercise in
                RoundedRectangle(cornerRadius: 3)
                    .fill(segmentColor(for: index, exercise: exercise))
                    .frame(height: 6)
                    .opacity(segmentOpacity(for: index, exercise: exercise))
                    .animation(
                        index == viewModel.currentExerciseIndex
                            ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                            : .default,
                        value: viewModel.currentExerciseIndex
                    )
            }
        }
        .padding(.horizontal, 4)
    }

    private func segmentColor(for index: Int, exercise: WorkoutExercise) -> Color {
        if exercise.isCompleted { return PepTheme.teal }
        if index == viewModel.currentExerciseIndex { return PepTheme.teal }
        return PepTheme.elevated
    }

    private func segmentOpacity(for index: Int, exercise: WorkoutExercise) -> Double {
        if exercise.isCompleted { return 1.0 }
        if index == viewModel.currentExerciseIndex { return 0.8 }
        return 0.4
    }

    private func currentExerciseHeader(_ exercise: WorkoutExercise) -> some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Exercise \(viewModel.currentExerciseIndex + 1) of \(viewModel.exercises.count)")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(PepTheme.teal.opacity(0.7))

                    Text(exercise.exercise.name)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                }

                Spacer()

                Button { viewModel.showExerciseInfo = true } label: {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundStyle(PepTheme.teal)
                        .frame(width: 44, height: 44)
                }
            }

            HStack(spacing: 12) {
                Label(exercise.exercise.primaryMuscle.rawValue, systemImage: exercise.exercise.primaryMuscle.icon)
                Label(exercise.exercise.equipment.rawValue, systemImage: exercise.exercise.equipment.icon)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(PepTheme.textSecondary)
        }
        .padding(16)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }

    private func setLoggingTable(exerciseIndex: Int, exercise: WorkoutExercise) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("SET")
                    .frame(width: 36, alignment: .leading)
                Spacer()
                Text("WEIGHT")
                    .frame(width: 90, alignment: .center)
                Spacer()
                Text("REPS")
                    .frame(width: 70, alignment: .center)
                Spacer()
                Text("")
                    .frame(width: 44)
            }
            .font(.system(size: 10, weight: .bold))
            .tracking(1)
            .foregroundStyle(PepTheme.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider().background(PepTheme.elevated)

            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { setIndex, workoutSet in
                setRow(exerciseIndex: exerciseIndex, setIndex: setIndex, workoutSet: workoutSet)

                if setIndex < exercise.sets.count - 1 {
                    Divider().background(PepTheme.elevated).padding(.horizontal, 16)
                }
            }

            Button {
                viewModel.addExtraSet(exerciseIndex: exerciseIndex)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                    Text("Add Set")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(PepTheme.teal)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.scale)
            .sensoryFeedback(.impact(weight: .light), trigger: exercise.sets.count)
        }
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }

    private func setRow(exerciseIndex: Int, setIndex: Int, workoutSet: WorkoutSet) -> some View {
        HStack {
            Text("\(setIndex + 1)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(workoutSet.isCompleted ? PepTheme.teal : PepTheme.textPrimary)
                .frame(width: 36, alignment: .leading)

            Spacer()

            Button {
                if !workoutSet.isCompleted {
                    viewModel.openNumberInput(field: .weight(exerciseIndex: exerciseIndex, setIndex: setIndex))
                }
            } label: {
                weightDisplay(workoutSet)
                    .frame(width: 90, height: 40)
                    .background(workoutSet.isCompleted ? PepTheme.teal.opacity(0.08) : PepTheme.elevated)
                    .clipShape(.rect(cornerRadius: 10))
            }
            .disabled(workoutSet.isCompleted)

            Spacer()

            Button {
                if !workoutSet.isCompleted {
                    viewModel.openNumberInput(field: .reps(exerciseIndex: exerciseIndex, setIndex: setIndex))
                }
            } label: {
                repsDisplay(workoutSet)
                    .frame(width: 70, height: 40)
                    .background(workoutSet.isCompleted ? PepTheme.teal.opacity(0.08) : PepTheme.elevated)
                    .clipShape(.rect(cornerRadius: 10))
            }
            .disabled(workoutSet.isCompleted)

            Spacer()

            Button {
                if !workoutSet.isCompleted {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.logSet(exerciseIndex: exerciseIndex, setIndex: setIndex)
                    }
                }
            } label: {
                Image(systemName: workoutSet.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 26))
                    .foregroundStyle(workoutSet.isCompleted ? PepTheme.teal : PepTheme.textSecondary.opacity(0.5))
                    .frame(width: 44, height: 44)
                    .contentTransition(.symbolEffect(.replace))
            }
            .sensoryFeedback(.impact(weight: .heavy), trigger: workoutSet.isCompleted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .opacity(workoutSet.isCompleted ? 0.7 : 1.0)
    }

    private func weightDisplay(_ set: WorkoutSet) -> some View {
        Group {
            if set.weight > 0 {
                Text(viewModel.formatWeight(set.weight))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
            } else if let prev = set.previousWeight {
                Text(viewModel.formatWeight(prev))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary.opacity(0.35))
            } else {
                Text("—")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
            }
        }
    }

    private func repsDisplay(_ set: WorkoutSet) -> some View {
        Group {
            if set.reps > 0 {
                Text("\(set.reps)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
            } else if let prev = set.previousReps {
                Text("\(prev)")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary.opacity(0.35))
            } else {
                Text("—")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
            }
        }
    }

    private var floatingActions: some View {
        HStack(spacing: 12) {
            if !viewModel.isRestTimerActive {
                Button {
                    viewModel.showExercisePicker = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                        Text("Add Exercise")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(PepTheme.teal)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(PepTheme.cardSurface)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(PepTheme.teal.opacity(0.3), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
                }
                .buttonStyle(.scale)
            }
        }
        .padding(.bottom, 20)
        .opacity(viewModel.activeNumberInput == nil ? 1 : 0)
    }

    private func exerciseInfoSheet(_ exercise: Exercise) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(exercise.name)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)

                        HStack(spacing: 12) {
                            Label(exercise.primaryMuscle.rawValue, systemImage: exercise.primaryMuscle.icon)
                            Label(exercise.equipment.rawValue, systemImage: exercise.equipment.icon)
                            Label(exercise.difficulty.rawValue, systemImage: "chart.bar.fill")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                    }

                    if !exercise.instructions.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Instructions")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(PepTheme.textPrimary)

                            ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(PepTheme.teal)
                                        .frame(width: 24, height: 24)
                                        .background(PepTheme.teal.opacity(0.12))
                                        .clipShape(Circle())

                                    Text(step)
                                        .font(.subheadline)
                                        .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                                }
                            }
                        }
                    }

                    if !exercise.commonMistakes.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Common Mistakes")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(PepTheme.textPrimary)

                            ForEach(exercise.commonMistakes, id: \.self) { mistake in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.orange)
                                    Text(mistake)
                                        .font(.subheadline)
                                        .foregroundStyle(PepTheme.textSecondary)
                                }
                            }
                        }
                    }

                    if !exercise.proTips.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(PepTheme.violet)
                                Text("Finn's Pro Tips")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(PepTheme.textPrimary)
                            }

                            ForEach(exercise.proTips, id: \.self) { tip in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "lightbulb.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(PepTheme.violet)
                                    Text(tip)
                                        .font(.subheadline)
                                        .foregroundStyle(PepTheme.textSecondary)
                                }
                            }
                        }
                        .padding(14)
                        .background(PepTheme.violet.opacity(0.06))
                        .clipShape(.rect(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(PepTheme.violet.opacity(0.15), lineWidth: 0.5)
                        )
                    }
                }
                .padding()
                .padding(.bottom, 20)
            }
            .background(PepTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { viewModel.showExerciseInfo = false }
                        .foregroundStyle(PepTheme.teal)
                }
            }
            
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
    }
}
