import SwiftUI

struct ActiveWorkoutView: View {
    @Bindable var viewModel: ActiveWorkoutViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var sessionManager = WorkoutSessionManager.shared

    var body: some View {
        NavigationStack {
            if viewModel.isCompleted, let summary = viewModel.summary {
                WorkoutSummaryView(
                    summary: summary,
                    exercises: viewModel.exercises,
                    sourceProgramId: viewModel.sourceProgramId
                ) {
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
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        Color.clear.frame(height: 1).id("workout-top")
                        elapsedTimerSection
                        exerciseProgressBar
                        if BuddyWorkoutService.shared.session != nil {
                            BuddyProgressOverlay()
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        if let exercise = viewModel.currentExercise {
                            currentExerciseHeader(exercise)
                            previousBestPill(for: exercise)
                            setLoggingTable(exerciseIndex: viewModel.currentExerciseIndex, exercise: exercise)
                        } else {
                            emptyWorkoutPrompt
                        }
                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.currentExerciseIndex) { _, _ in
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        proxy.scrollTo("workout-top", anchor: .top)
                    }
                }
            }

            floatingActions

            if viewModel.isRestTimerActive {
                VStack {
                    Spacer()
                    RestTimerView(
                        secondsRemaining: viewModel.restSecondsRemaining,
                        totalSeconds: viewModel.restSecondsTotal,
                        didFire: viewModel.restTimerDidFire,
                        nextExerciseName: viewModel.nextExerciseName,
                        onSkip: { viewModel.skipRestTimer() },
                        onAdjust: { viewModel.adjustRestTimer(by: $0) }
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 80)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.isRestTimerActive)
                .allowsHitTesting(viewModel.activeNumberInput == nil)
            }

            if !viewModel.recentPRs.isEmpty {
                VStack {
                    PRToastView(prs: viewModel.recentPRs)
                        .padding(.top, 8)
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .id(viewModel.prToastId)
                    Spacer()
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.prToastId)
                .task(id: viewModel.prToastId) {
                    try? await Task.sleep(for: .seconds(3.5))
                    withAnimation(.easeOut(duration: 0.25)) {
                        viewModel.recentPRs = []
                    }
                }
                .allowsHitTesting(false)
            }

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
        .appBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    viewModel.requestEndWorkout()
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
        .sheet(isPresented: $viewModel.showSwapPicker) {
            SwapExerciseSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showPlateCalculator) {
            PlateCalculatorView(initialWeight: viewModel.plateCalculatorWeight)
        }
        .confirmationDialog(
            "Discard workout?",
            isPresented: $viewModel.showEmptyEndConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard Workout", role: .destructive) {
                viewModel.discardEmptyWorkout()
                dismiss()
            }
            Button("Keep Going", role: .cancel) { }
        } message: {
            Text("You haven't logged any sets yet. This workout won't be saved.")
        }
        .confirmationDialog(
            viewModel.hasIncompleteSets ? "Finish workout early?" : "Finish workout?",
            isPresented: $viewModel.showCompleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Complete Workout") {
                viewModel.finishWorkout()
            }
            Button("Keep Going", role: .cancel) { }
        } message: {
            if viewModel.hasIncompleteSets {
                Text("You still have unlogged sets. Only the sets you've checked off will be saved.")
            } else {
                Text("Save and review your summary?")
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

    @ViewBuilder
    private func previousBestPill(for exercise: WorkoutExercise) -> some View {
        let bestWeight = PRTracker.shared.bestWeight(for: exercise.exercise.id)
        let best1RM = PRTracker.shared.best1RM(for: exercise.exercise.id)
        if bestWeight > 0 || best1RM > 0 {
            HStack(spacing: 14) {
                if bestWeight > 0 {
                    labelPair("Best", "\(viewModel.formatWeight(bestWeight)) lbs")
                }
                if best1RM > 0 {
                    if bestWeight > 0 {
                        Rectangle()
                            .fill(PepTheme.textSecondary.opacity(0.2))
                            .frame(width: 1, height: 14)
                    }
                    labelPair("Est. 1RM", "\(viewModel.formatWeight(best1RM)) lbs")
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(PepTheme.textSecondary.opacity(0.18), lineWidth: 0.5)
            )
        }
    }

    private func labelPair(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.75))
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
        }
    }

    private func currentExerciseHeader(_ exercise: WorkoutExercise) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(String(format: "%02d", viewModel.currentExerciseIndex + 1))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(PepTheme.teal.opacity(0.9))
                        Text("—")
                            .font(.system(size: 10))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.45))
                        Text("EXERCISE \(viewModel.currentExerciseIndex + 1) OF \(viewModel.exercises.count)")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.6)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.85))
                    }

                    Text(exercise.exercise.name)
                        .font(.system(size: 26, weight: .semibold, design: .serif))
                        .kerning(-0.3)
                        .foregroundStyle(PepTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                HStack(spacing: 4) {
                    Button {
                        viewModel.openSwapPicker(for: viewModel.currentExerciseIndex)
                    } label: {
                        Image(systemName: "arrow.triangle.swap")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(PepTheme.textSecondary)
                            .frame(width: 36, height: 36)
                    }

                    Button { viewModel.showExerciseInfo = true } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(PepTheme.textSecondary)
                            .frame(width: 36, height: 36)
                    }
                }
            }

            HStack(spacing: 16) {
                metaTag(exercise.exercise.primaryMuscle.rawValue)
                Rectangle()
                    .fill(PepTheme.textSecondary.opacity(0.2))
                    .frame(width: 1, height: 10)
                metaTag(exercise.exercise.equipment.rawValue)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.glassBorderTop.opacity(0.6), lineWidth: 0.5)
        )
    }

    private func metaTag(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.4)
            .foregroundStyle(PepTheme.textSecondary)
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
            .contextMenu {
                if viewModel.exercises[exerciseIndex].exercise.equipment == .barbell {
                    Button {
                        viewModel.openPlateCalculator(exerciseIndex: exerciseIndex, setIndex: setIndex)
                    } label: {
                        Label("Plate Calculator", systemImage: "scalemass.fill")
                    }
                }
            }

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
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if workoutSet.isCompleted {
                        viewModel.unlogSet(exerciseIndex: exerciseIndex, setIndex: setIndex)
                    } else {
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
            .buttonStyle(.plain)
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

    private var emptyWorkoutPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "plus.rectangle.on.rectangle")
                .font(.system(size: 44))
                .foregroundStyle(PepTheme.teal.opacity(0.7))

            VStack(spacing: 6) {
                Text("Freestyle Workout")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Add exercises as you go. When you're done, you can save it as a routine.")
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                viewModel.showExercisePicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add First Exercise")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(PepTheme.teal)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 30)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private var floatingActions: some View {
        HStack(spacing: 12) {
            if !viewModel.isRestTimerActive {
                Button {
                    viewModel.showExercisePicker = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("ADD EXERCISE")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.6)
                    }
                    .foregroundStyle(PepTheme.textPrimary)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
                    .background(PepTheme.cardSurface)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(PepTheme.textSecondary.opacity(0.25), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
                }
                .buttonStyle(.scale)

                if viewModel.hasAnyLoggedSets {
                    Button {
                        viewModel.showCompleteConfirmation = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                            Text("COMPLETE")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1.6)
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .background(PepTheme.teal)
                        .clipShape(Capsule())
                        .shadow(color: PepTheme.teal.opacity(0.35), radius: 10, y: 4)
                    }
                    .buttonStyle(.scale)
                    .sensoryFeedback(.success, trigger: viewModel.isCompleted)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.hasAnyLoggedSets)
        .padding(.bottom, 20)
        .opacity(viewModel.activeNumberInput == nil ? 1 : 0)
    }

    private func exerciseInfoSheet(_ exercise: Exercise) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("REFERENCE")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(2.0)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.85))

                        Text(exercise.name)
                            .font(.system(size: 32, weight: .semibold, design: .serif))
                            .kerning(-0.4)
                            .foregroundStyle(PepTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        infoMetaRow(exercise: exercise)
                            .padding(.top, 4)
                    }

                    if !exercise.instructions.isEmpty {
                        editorialSection("Instructions", number: "01") {
                            VStack(alignment: .leading, spacing: 14) {
                                ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { index, step in
                                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                                        Text(String(format: "%02d", index + 1))
                                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                                            .frame(width: 22, alignment: .leading)
                                        Text(step)
                                            .font(.system(size: 15, design: .serif))
                                            .lineSpacing(3)
                                            .foregroundStyle(PepTheme.textPrimary.opacity(0.92))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }

                    if !exercise.commonMistakes.isEmpty {
                        editorialSection("Common Mistakes", number: "02") {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(exercise.commonMistakes, id: \.self) { mistake in
                                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                                        Rectangle()
                                            .fill(PepTheme.textSecondary.opacity(0.4))
                                            .frame(width: 8, height: 1)
                                            .offset(y: -4)
                                        Text(mistake)
                                            .font(.system(size: 14))
                                            .lineSpacing(2)
                                            .foregroundStyle(PepTheme.textSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }

                    if !exercise.proTips.isEmpty {
                        editorialSection("Tips", number: "03") {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(exercise.proTips, id: \.self) { tip in
                                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                                        Rectangle()
                                            .fill(PepTheme.textSecondary.opacity(0.4))
                                            .frame(width: 8, height: 1)
                                            .offset(y: -4)
                                        Text(tip)
                                            .font(.system(size: 14))
                                            .lineSpacing(2)
                                            .foregroundStyle(PepTheme.textSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .appBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { viewModel.showExerciseInfo = false }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
    }

    private func infoMetaRow(exercise: Exercise) -> some View {
        HStack(spacing: 0) {
            infoMetaItem(label: "Muscle", value: exercise.primaryMuscle.rawValue)
            divider()
            infoMetaItem(label: "Equipment", value: exercise.equipment.rawValue)
            divider()
            infoMetaItem(label: "Level", value: exercise.difficulty.rawValue)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(PepTheme.textSecondary.opacity(0.2))
                .frame(height: 0.5)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PepTheme.textSecondary.opacity(0.2))
                .frame(height: 0.5)
        }
        .padding(.vertical, 12)
    }

    private func infoMetaItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func divider() -> some View {
        Rectangle()
            .fill(PepTheme.textSecondary.opacity(0.2))
            .frame(width: 0.5, height: 28)
    }

    @ViewBuilder
    private func editorialSection<Content: View>(_ title: String, number: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionEyebrow(title, number: number, accent: PepTheme.teal)
            content()
        }
    }
}
