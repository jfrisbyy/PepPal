import SwiftUI

struct AIBuildProgramView: View {
    @Bindable var viewModel: TrainViewModel
    var activeProtocol: PeptideProtocol? = nil
    var bodyGoal: FitnessGoalType? = nil
    var currentWeight: Double? = nil
    var targetWeight: Double? = nil
    var totalWorkouts: Int = 0
    var preSelectedSuggestion: SmartProgramSuggestion? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var currentStep: Int = 0
    @State private var selectedGoal: String = ""
    @State private var daysPerWeek: Int = 4
    @State private var selectedEquipment: Set<String> = ["Barbell", "Dumbbell", "Cable", "Machine"]
    @State private var experience: String = "Intermediate"
    @State private var injuries: String = ""
    @State private var sessionLength: Int = 60
    @State private var preferences: String = ""
    @State private var includePeptideContext: Bool = true
    @State private var isGenerating: Bool = false
    @State private var generatedProgram: TrainingProgram? = nil
    @State private var errorMessage: String? = nil
    @State private var expandedDayId: UUID? = nil
    @State private var hasAutoFilled: Bool = false
    @State private var expandedExerciseId: UUID? = nil
    @State private var showExercisePicker: Bool = false
    @State private var pickerDayId: UUID? = nil
    @State private var swapTarget: AISwapTarget? = nil
    @State private var renameDayId: UUID? = nil
    @State private var renameDayText: String = ""
    @State private var showRenameDay: Bool = false
    @State private var showRenameProgram: Bool = false
    @State private var renameProgramText: String = ""

    struct AISwapTarget: Equatable {
        let dayId: UUID
        let exerciseIndex: Int
    }

    private let goals = ["Hypertrophy (Muscle Growth)", "Strength", "Recomp (Lose Fat + Build Muscle)", "General Fitness", "Athletic Performance", "Powerlifting", "Muscle Preservation (Deficit)", "Maintenance (Minimal Volume)"]
    private let equipmentOptions = ["Barbell", "Dumbbell", "Cable", "Machine", "Bodyweight", "Kettlebell", "Band"]
    private let experienceLevels = ["Beginner", "Intermediate", "Advanced"]
    private let sessionLengths = [30, 45, 60, 75, 90]

    private var hasUserContext: Bool {
        activeProtocol != nil || bodyGoal != nil
    }

    private var userContextSummary: String {
        SmartProgramEngine.buildUserContextSummary(
            activeProtocol: activeProtocol,
            bodyGoal: bodyGoal,
            currentWeight: currentWeight,
            targetWeight: targetWeight,
            workoutsThisWeek: viewModel.workoutsCompletedThisWeek,
            totalWorkouts: totalWorkouts
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stepIndicator

                if generatedProgram != nil {
                    resultView
                } else if isGenerating {
                    generatingView
                } else {
                    TabView(selection: $currentStep) {
                        goalStep.tag(0)
                        scheduleStep.tag(1)
                        equipmentStep.tag(2)
                        detailsStep.tag(3)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
                }

                if generatedProgram == nil && !isGenerating {
                    bottomBar
                }
            }
            .appBackground()
            .navigationTitle(preSelectedSuggestion != nil ? "Smart Program Builder" : "AI Program Builder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            .onAppear {
                if !hasAutoFilled {
                    autoFillFromContext()
                    hasAutoFilled = true
                }
            }
        }
    }

    private func autoFillFromContext() {
        if let suggestion = preSelectedSuggestion {
            switch suggestion.strategy {
            case .cutPreservation:
                selectedGoal = "Muscle Preservation (Deficit)"
                daysPerWeek = 4
                sessionLength = 60
            case .aggressiveGain, .highFrequencyHypertrophy:
                selectedGoal = "Hypertrophy (Muscle Growth)"
                daysPerWeek = 5
                sessionLength = 75
            case .recompFocus:
                selectedGoal = "Recomp (Lose Fat + Build Muscle)"
                daysPerWeek = 4
                sessionLength = 60
            case .maintenanceLift, .minimalistEfficient:
                selectedGoal = "Maintenance (Minimal Volume)"
                daysPerWeek = 3
                sessionLength = 45
            case .healingAdapted:
                selectedGoal = "General Fitness"
                daysPerWeek = 3
                sessionLength = 45
            case .strengthFoundation:
                selectedGoal = "Strength"
                daysPerWeek = 4
                sessionLength = 60
            case .peptideOptimized:
                selectedGoal = "Hypertrophy (Muscle Growth)"
                daysPerWeek = 4
                sessionLength = 60
            }
            return
        }

        if let goal = bodyGoal {
            switch goal {
            case .weightLoss, .cutting:
                selectedGoal = "Muscle Preservation (Deficit)"
                daysPerWeek = 4
            case .weightGain, .bulking:
                selectedGoal = "Hypertrophy (Muscle Growth)"
                daysPerWeek = 5
            case .recomp:
                selectedGoal = "Recomp (Lose Fat + Build Muscle)"
                daysPerWeek = 4
            case .maintain:
                selectedGoal = "Maintenance (Minimal Volume)"
                daysPerWeek = 3
            }
        }

        if totalWorkouts == 0 {
            experience = "Beginner"
        } else if totalWorkouts > 100 {
            experience = "Advanced"
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<4) { step in
                Capsule()
                    .fill(step <= currentStep ? PepTheme.violet : PepTheme.elevated)
                    .frame(height: 3)
                    .animation(.spring(duration: 0.3), value: currentStep)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Step 1: Goal

    private var goalStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let suggestion = preSelectedSuggestion {
                    suggestionBanner(suggestion)
                } else if hasUserContext {
                    autoFilledBanner
                }

                stepHeader(
                    icon: "target",
                    title: "What's your goal?",
                    subtitle: hasUserContext
                        ? "Pre-selected based on your data — change it if you want."
                        : "This shapes your entire program — exercise selection, rep ranges, and volume."
                )

                VStack(spacing: 10) {
                    ForEach(goals, id: \.self) { goal in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                selectedGoal = goal
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selectedGoal == goal ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 18))
                                    .foregroundStyle(selectedGoal == goal ? PepTheme.violet : PepTheme.textSecondary)

                                Text(goal)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(PepTheme.textPrimary)

                                Spacer()
                            }
                            .padding(14)
                            .background(selectedGoal == goal ? PepTheme.violet.opacity(0.08) : PepTheme.cardSurface)
                            .clipShape(.rect(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(
                                        selectedGoal == goal ? PepTheme.violet.opacity(0.3) : PepTheme.glassBorderTop,
                                        lineWidth: selectedGoal == goal ? 1 : 0.5
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
        }
    }

    private func suggestionBanner(_ suggestion: SmartProgramSuggestion) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(colors: suggestion.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 32, height: 32)

                Image(systemName: suggestion.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Settings pre-configured for this strategy")
                    .font(.system(size: 10))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            if let badge = suggestion.badge {
                Text(badge)
                    .font(.system(size: 7, weight: .black))
                    .foregroundStyle(suggestion.badgeColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(suggestion.badgeColor.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(PepTheme.violet.opacity(0.05))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(PepTheme.violet.opacity(0.15), lineWidth: 0.5)
        )
    }

    private var autoFilledBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 12))
                .foregroundStyle(PepTheme.violet)
            Text("Auto-filled from your profile & protocol data")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
            Spacer()
        }
        .padding(10)
        .background(PepTheme.violet.opacity(0.05))
        .clipShape(.rect(cornerRadius: 10))
    }

    // MARK: - Step 2: Schedule

    private var scheduleStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                stepHeader(
                    icon: "calendar",
                    title: "How many days can you train?",
                    subtitle: "Be realistic — consistency beats ambition."
                )

                VStack(spacing: 16) {
                    HStack(spacing: 0) {
                        ForEach(2...6, id: \.self) { day in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    daysPerWeek = day
                                }
                            } label: {
                                Text("\(day)")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(daysPerWeek == day ? .black : PepTheme.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(daysPerWeek == day ? PepTheme.violet : PepTheme.elevated)
                                    .clipShape(.rect(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                    .background(PepTheme.cardSurface)
                    .clipShape(.rect(cornerRadius: 14))

                    HStack(spacing: 12) {
                        Image(systemName: "clock")
                            .foregroundStyle(PepTheme.violet)
                        Text("Session length")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(PepTheme.textPrimary)
                        Spacer()
                    }

                    HStack(spacing: 0) {
                        ForEach(sessionLengths, id: \.self) { length in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    sessionLength = length
                                }
                            } label: {
                                Text("\(length)m")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(sessionLength == length ? .black : PepTheme.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(sessionLength == length ? PepTheme.violet : PepTheme.elevated)
                                    .clipShape(.rect(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                    .background(PepTheme.cardSurface)
                    .clipShape(.rect(cornerRadius: 14))
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
        }
    }

    // MARK: - Step 3: Equipment

    private var equipmentStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                stepHeader(
                    icon: "dumbbell.fill",
                    title: "What equipment do you have?",
                    subtitle: "Select all that apply. The AI will only use exercises matching your setup."
                )

                VStack(spacing: 8) {
                    ForEach(equipmentOptions, id: \.self) { equip in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                if selectedEquipment.contains(equip) {
                                    selectedEquipment.remove(equip)
                                } else {
                                    selectedEquipment.insert(equip)
                                }
                            }
                        } label: {
                            let isSelected = selectedEquipment.contains(equip)
                            HStack(spacing: 12) {
                                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 18))
                                    .foregroundStyle(isSelected ? PepTheme.violet : PepTheme.textSecondary)

                                Text(equip)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(PepTheme.textPrimary)

                                Spacer()

                                Image(systemName: Equipment(rawValue: equip)?.icon ?? "questionmark")
                                    .font(.system(size: 14))
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                            .padding(14)
                            .background(isSelected ? PepTheme.violet.opacity(0.06) : PepTheme.cardSurface)
                            .clipShape(.rect(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(
                                        isSelected ? PepTheme.violet.opacity(0.2) : PepTheme.glassBorderTop,
                                        lineWidth: isSelected ? 0.8 : 0.5
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
        }
    }

    // MARK: - Step 4: Details

    private var detailsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                stepHeader(
                    icon: "person.text.rectangle",
                    title: "Review & Fine-Tune",
                    subtitle: hasUserContext
                        ? "Your data is already loaded. Add anything else the AI should know."
                        : "Optional — but the more the AI knows, the better your program."
                )

                if hasUserContext {
                    userDataCard
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Experience Level")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PepTheme.textSecondary)

                    HStack(spacing: 0) {
                        ForEach(experienceLevels, id: \.self) { level in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    experience = level
                                }
                            } label: {
                                Text(level)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(experience == level ? .black : PepTheme.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(experience == level ? PepTheme.violet : PepTheme.elevated)
                                    .clipShape(.rect(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                    .background(PepTheme.cardSurface)
                    .clipShape(.rect(cornerRadius: 14))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Injuries or Limitations")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PepTheme.textSecondary)

                    TextField("e.g., Bad left shoulder, lower back issues", text: $injuries)
                        .font(.subheadline)
                        .padding(14)
                        .background(PepTheme.cardSurface)
                        .clipShape(.rect(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                        )
                }

                if activeProtocol != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Include Protocol Context")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PepTheme.textSecondary)
                            Spacer()
                            Toggle("", isOn: $includePeptideContext)
                                .labelsHidden()
                                .tint(PepTheme.violet)
                        }

                        if includePeptideContext {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(PepTheme.violet.opacity(0.7))
                                Text("The AI will factor in your active protocol, phase, and compounds to customize the program.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                            .padding(10)
                            .background(PepTheme.violet.opacity(0.06))
                            .clipShape(.rect(cornerRadius: 8))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Anything Else?")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PepTheme.textSecondary)

                    TextField("e.g., Prefer supersets, hate leg press, want more arm work", text: $preferences)
                        .font(.subheadline)
                        .padding(14)
                        .background(PepTheme.cardSurface)
                        .clipShape(.rect(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                        )
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }

    private var userDataCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 12))
                    .foregroundStyle(.green)
                Text("Your Data — Sending to AI")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                if let proto = activeProtocol {
                    dataRow(icon: "syringe.fill", color: proto.goal.color,
                            text: "\(proto.name) · \(proto.currentPhase.rawValue) · Week \(proto.currentWeek)")
                    let compoundNames = proto.compounds.map { $0.compoundName }.joined(separator: ", ")
                    if !compoundNames.isEmpty {
                        dataRow(icon: "pill.fill", color: PepTheme.textSecondary, text: compoundNames)
                    }
                }

                if let goal = bodyGoal {
                    dataRow(icon: goal.icon, color: goal.color, text: "Goal: \(goal.rawValue)")
                }

                if let cw = currentWeight, cw > 0 {
                    let weightText = targetWeight != nil && targetWeight! > 0
                        ? "\(String(format: "%.0f", cw)) → \(String(format: "%.0f", targetWeight!)) lbs"
                        : "\(String(format: "%.0f", cw)) lbs"
                    dataRow(icon: "scalemass", color: PepTheme.teal, text: weightText)
                }

                dataRow(icon: "figure.run", color: PepTheme.blue,
                        text: "\(totalWorkouts) total sessions · \(viewModel.workoutsCompletedThisWeek)/wk avg")
            }
        }
        .padding(12)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
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

    private func dataRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(color)
                .frame(width: 14)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(PepTheme.textSecondary)
                .lineLimit(1)
        }
    }

    // MARK: - Generating

    private var generatingView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(PepTheme.violet.opacity(0.08))
                    .frame(width: 120, height: 120)

                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundStyle(PepTheme.violet)
                    .symbolEffect(.variableColor.iterative.dimInactiveLayers, options: .repeating)
            }

            VStack(spacing: 8) {
                Text("Building Your Program")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(PepTheme.textPrimary)

                Text(hasUserContext
                    ? "Analyzing your protocol, goals, and history\nto build the perfect program..."
                    : "The AI is designing a personalized program\nbased on your inputs...")
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let error = errorMessage {
                VStack(spacing: 12) {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)

                    Button("Try Again") {
                        errorMessage = nil
                        generateProgram()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PepTheme.violet)
                }
                .padding(.horizontal, 32)
            }

            Spacer()
        }
    }

    // MARK: - Result

    private var resultView: some View {
        ScrollView {
            if let program = generatedProgram {
                VStack(spacing: 16) {
                    resultHeader(program: program)
                    weeklyScheduleOverview(program: program)

                    ForEach(Array(program.days.enumerated()), id: \.element.id) { index, _ in
                        editableDayCard(dayIndex: index)
                    }

                    actionButtons
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showExercisePicker) {
            exercisePickerSheet
        }
        .alert("Rename Day", isPresented: $showRenameDay) {
            TextField("Day name", text: $renameDayText)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                let trimmed = renameDayText.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty, let dayId = renameDayId,
                      var prog = generatedProgram,
                      let idx = prog.days.firstIndex(where: { $0.id == dayId }) else { return }
                prog.days[idx].name = trimmed
                generatedProgram = prog
            }
        }
        .alert("Rename Program", isPresented: $showRenameProgram) {
            TextField("Program name", text: $renameProgramText)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                let trimmed = renameProgramText.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty, var prog = generatedProgram else { return }
                prog.name = trimmed
                generatedProgram = prog
            }
        }
    }

    private func resultHeader(program: TrainingProgram) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.green)
                Text("Program Generated")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.green)
                    .tracking(0.8)
            }

            Button {
                renameProgramText = program.name
                showRenameProgram = true
            } label: {
                HStack(spacing: 6) {
                    Text(program.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .multilineTextAlignment(.center)
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 14) {
                statPill(value: "\(program.days.count)", label: "Days", icon: "calendar")
                statPill(value: "\(program.days.reduce(0) { $0 + $1.exercises.count })", label: "Exercises", icon: "dumbbell")
                let scheduled = program.days.filter { $0.scheduledWeekday != nil }.count
                statPill(value: "\(scheduled)/\(program.days.count)", label: "Scheduled", icon: "checkmark.circle")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private func statPill(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(PepTheme.violet.opacity(0.7))
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(PepTheme.elevated.opacity(0.5))
        .clipShape(.rect(cornerRadius: 10))
    }

    private func weeklyScheduleOverview(program: TrainingProgram) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 12))
                    .foregroundStyle(PepTheme.violet)
                Text("WEEKLY SCHEDULE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .tracking(1)
                Spacer()
            }

            HStack(spacing: 4) {
                ForEach(ProgramWeekday.allCases) { weekday in
                    let dayAtWeekday = program.days.first { $0.scheduledWeekday == weekday.rawValue }
                    VStack(spacing: 4) {
                        Text(weekday.singleLetter)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(dayAtWeekday != nil ? PepTheme.violet : PepTheme.textSecondary)
                        Circle()
                            .fill(dayAtWeekday != nil ? PepTheme.violet : PepTheme.elevated)
                            .frame(width: 6, height: 6)
                        Text(dayAtWeekday?.name ?? "Rest")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(dayAtWeekday != nil ? PepTheme.textPrimary : PepTheme.textSecondary.opacity(0.6))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(dayAtWeekday != nil ? PepTheme.violet.opacity(0.08) : Color.clear)
                    .clipShape(.rect(cornerRadius: 8))
                }
            }

            let unscheduled = program.days.filter { $0.scheduledWeekday == nil }.count
            if unscheduled > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(PepTheme.amber)
                    Text("\(unscheduled) workout\(unscheduled == 1 ? "" : "s") not yet scheduled")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PepTheme.amber)
                    Spacer()
                }
                .padding(8)
                .background(PepTheme.amber.opacity(0.08))
                .clipShape(.rect(cornerRadius: 8))
            }
        }
        .padding(14)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private func editableDayCard(dayIndex: Int) -> some View {
        guard let prog = generatedProgram, dayIndex < prog.days.count else {
            return AnyView(EmptyView())
        }
        let day = prog.days[dayIndex]
        let isExpanded = expandedDayId == day.id

        return AnyView(
            VStack(spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        expandedDayId = isExpanded ? nil : day.id
                    }
                } label: {
                    HStack(spacing: 12) {
                        Text("\(dayIndex + 1)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(PepTheme.violet)
                            .frame(width: 28, height: 28)
                            .background(PepTheme.violet.opacity(0.12))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(day.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                                .lineLimit(2)
                            HStack(spacing: 6) {
                                Text("\(day.exercises.count) exercises")
                                    .font(.system(size: 11))
                                    .foregroundStyle(PepTheme.textSecondary)
                                if let wd = day.scheduledWeekday, let weekday = ProgramWeekday(rawValue: wd) {
                                    Text("·")
                                        .font(.system(size: 11))
                                        .foregroundStyle(PepTheme.textSecondary)
                                    HStack(spacing: 2) {
                                        Image(systemName: "calendar")
                                            .font(.system(size: 9))
                                        Text(weekday.shortLabel)
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    .foregroundStyle(PepTheme.violet)
                                }
                            }
                        }

                        Spacer()

                        Menu {
                            Button {
                                renameDayId = day.id
                                renameDayText = day.name
                                showRenameDay = true
                            } label: {
                                Label("Rename Day", systemImage: "pencil")
                            }
                            Button {
                                pickerDayId = day.id
                                swapTarget = nil
                                showExercisePicker = true
                            } label: {
                                Label("Add Exercise", systemImage: "plus")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(PepTheme.textSecondary)
                                .frame(width: 28, height: 28)
                                .background(PepTheme.elevated)
                                .clipShape(Circle())
                        }

                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .padding(14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(spacing: 12) {
                        weekdayPicker(dayIndex: dayIndex)

                        VStack(spacing: 8) {
                            ForEach(Array(day.exercises.enumerated()), id: \.element.id) { exIdx, exercise in
                                editableExerciseRow(dayIndex: dayIndex, exerciseIndex: exIdx, exercise: exercise)
                            }
                        }

                        Button {
                            pickerDayId = day.id
                            swapTarget = nil
                            showExercisePicker = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 13))
                                Text("Add Exercise")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(PepTheme.violet)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(PepTheme.violet.opacity(0.08))
                            .clipShape(.rect(cornerRadius: 10))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
            )
        )
    }

    private func weekdayPicker(dayIndex: Int) -> some View {
        guard let prog = generatedProgram, dayIndex < prog.days.count else {
            return AnyView(EmptyView())
        }
        let selected = prog.days[dayIndex].scheduledWeekday

        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text("SCHEDULED ON")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.8))
                    .tracking(0.8)
                HStack(spacing: 5) {
                    ForEach(ProgramWeekday.allCases) { weekday in
                        let isSelected = selected == weekday.rawValue
                        let sharedCount = prog.days.enumerated().filter { i, d in
                            i != dayIndex && d.scheduledWeekday == weekday.rawValue
                        }.count
                        Button {
                            withAnimation(.spring(duration: 0.2)) {
                                setWeekday(weekday.rawValue, forDayAt: dayIndex)
                            }
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Text(weekday.singleLetter)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(isSelected ? .black : PepTheme.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 34)
                                    .background(isSelected ? PepTheme.violet : PepTheme.elevated)
                                    .clipShape(.rect(cornerRadius: 8))
                                if sharedCount > 0 {
                                    Circle()
                                        .fill(PepTheme.amber)
                                        .frame(width: 6, height: 6)
                                        .offset(x: -3, y: 3)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        )
    }

    private func editableExerciseRow(dayIndex: Int, exerciseIndex: Int, exercise: ProgramExercise) -> some View {
        let isExpanded = expandedExerciseId == exercise.id

        return VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    expandedExerciseId = isExpanded ? nil : exercise.id
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: exercise.primaryMuscle.icon)
                        .font(.system(size: 11))
                        .foregroundStyle(PepTheme.violet.opacity(0.7))
                        .frame(width: 26, height: 26)
                        .background(PepTheme.violet.opacity(0.1))
                        .clipShape(.rect(cornerRadius: 7))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.exerciseName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text("\(exercise.targetSets) × \(exercise.targetRepsMin)-\(exercise.targetRepsMax) · \(exercise.restSeconds)s rest")
                            .font(.system(size: 10))
                            .foregroundStyle(PepTheme.textSecondary)
                    }

                    Spacer(minLength: 6)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .padding(10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        exerciseStepper(label: "Sets", value: exercise.targetSets, range: 1...10) { new in
                            updateExercise(dayIndex: dayIndex, exerciseIndex: exerciseIndex) { $0.targetSets = new }
                        }
                        exerciseStepper(label: "Min", value: exercise.targetRepsMin, range: 1...50) { new in
                            updateExercise(dayIndex: dayIndex, exerciseIndex: exerciseIndex) {
                                $0.targetRepsMin = new
                                if $0.targetRepsMax < new { $0.targetRepsMax = new }
                            }
                        }
                        exerciseStepper(label: "Max", value: exercise.targetRepsMax, range: 1...50) { new in
                            updateExercise(dayIndex: dayIndex, exerciseIndex: exerciseIndex) {
                                $0.targetRepsMax = new
                                if $0.targetRepsMin > new { $0.targetRepsMin = new }
                            }
                        }
                    }

                    HStack {
                        Text("Rest")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                        Spacer()
                        HStack(spacing: 6) {
                            Button {
                                updateExercise(dayIndex: dayIndex, exerciseIndex: exerciseIndex) {
                                    if $0.restSeconds > 15 { $0.restSeconds -= 15 }
                                }
                            } label: {
                                Image(systemName: "minus")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(PepTheme.textSecondary)
                                    .frame(width: 26, height: 26)
                                    .background(PepTheme.elevated)
                                    .clipShape(Circle())
                            }
                            Text("\(exercise.restSeconds)s")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(PepTheme.textPrimary)
                                .frame(width: 44)
                            Button {
                                updateExercise(dayIndex: dayIndex, exerciseIndex: exerciseIndex) {
                                    if $0.restSeconds < 300 { $0.restSeconds += 15 }
                                }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(PepTheme.textSecondary)
                                    .frame(width: 26, height: 26)
                                    .background(PepTheme.elevated)
                                    .clipShape(Circle())
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        Button {
                            guard let prog = generatedProgram else { return }
                            let dayId = prog.days[dayIndex].id
                            pickerDayId = dayId
                            swapTarget = AISwapTarget(dayId: dayId, exerciseIndex: exerciseIndex)
                            showExercisePicker = true
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.triangle.swap")
                                    .font(.system(size: 10))
                                Text("Swap")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(PepTheme.violet)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(PepTheme.violet.opacity(0.1))
                            .clipShape(.rect(cornerRadius: 8))
                        }

                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                removeExercise(dayIndex: dayIndex, exerciseIndex: exerciseIndex)
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "trash")
                                    .font(.system(size: 10))
                                Text("Remove")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(.red.opacity(0.9))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.08))
                            .clipShape(.rect(cornerRadius: 8))
                        }
                    }
                }
                .padding(10)
                .background(PepTheme.elevated.opacity(0.4))
            }
        }
        .background(PepTheme.elevated.opacity(0.25))
        .clipShape(.rect(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(PepTheme.glassBorderTop.opacity(0.5), lineWidth: 0.5)
        )
    }

    private func exerciseStepper(label: String, value: Int, range: ClosedRange<Int>, onChange: @escaping (Int) -> Void) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
            HStack(spacing: 2) {
                Button {
                    if value > range.lowerBound { onChange(value - 1) }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 22, height: 22)
                        .background(PepTheme.elevated)
                        .clipShape(Circle())
                }
                Text("\(value)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
                    .frame(minWidth: 24)
                Button {
                    if value < range.upperBound { onChange(value + 1) }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 22, height: 22)
                        .background(PepTheme.elevated)
                        .clipShape(Circle())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 8))
    }

    private var exercisePickerSheet: some View {
        ExercisePickerView(swapSource: currentSwapSource) { selected in
            applyPickerSelection(selected)
        }
    }

    private var currentSwapSource: Exercise? {
        guard let target = swapTarget,
              let prog = generatedProgram,
              let dIdx = prog.days.firstIndex(where: { $0.id == target.dayId }),
              target.exerciseIndex < prog.days[dIdx].exercises.count else { return nil }
        let pe = prog.days[dIdx].exercises[target.exerciseIndex]
        return ExerciseLibrary.all.first { $0.id == pe.exerciseId }
    }

    private func applyPickerSelection(_ exercises: [Exercise]) {
        guard var prog = generatedProgram else { return }
        if let target = swapTarget,
           let dIdx = prog.days.firstIndex(where: { $0.id == target.dayId }),
           let first = exercises.first,
           target.exerciseIndex < prog.days[dIdx].exercises.count {
            let old = prog.days[dIdx].exercises[target.exerciseIndex]
            prog.days[dIdx].exercises[target.exerciseIndex] = ProgramExercise(
                exercise: first,
                targetSets: old.targetSets,
                targetRepsMin: old.targetRepsMin,
                targetRepsMax: old.targetRepsMax,
                restSeconds: old.restSeconds
            )
        } else if let dayId = pickerDayId,
                  let dIdx = prog.days.firstIndex(where: { $0.id == dayId }) {
            for ex in exercises {
                prog.days[dIdx].exercises.append(ProgramExercise(exercise: ex))
            }
        }
        generatedProgram = prog
        swapTarget = nil
        pickerDayId = nil
    }

    private func setWeekday(_ weekday: Int, forDayAt index: Int) {
        guard var prog = generatedProgram, index < prog.days.count else { return }
        if prog.days[index].scheduledWeekday == weekday {
            prog.days[index].scheduledWeekday = nil
        } else {
            prog.days[index].scheduledWeekday = weekday
        }
        generatedProgram = prog
    }

    private func updateExercise(dayIndex: Int, exerciseIndex: Int, _ mutate: (inout ProgramExercise) -> Void) {
        guard var prog = generatedProgram, dayIndex < prog.days.count,
              exerciseIndex < prog.days[dayIndex].exercises.count else { return }
        mutate(&prog.days[dayIndex].exercises[exerciseIndex])
        generatedProgram = prog
    }

    private func removeExercise(dayIndex: Int, exerciseIndex: Int) {
        guard var prog = generatedProgram, dayIndex < prog.days.count,
              exerciseIndex < prog.days[dayIndex].exercises.count else { return }
        prog.days[dayIndex].exercises.remove(at: exerciseIndex)
        generatedProgram = prog
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                guard let program = generatedProgram else { return }
                viewModel.activateTemplateProgram(program, startDayOffset: 0)
                dismiss()
                NotificationCenter.default.post(name: .switchToHomeTab, object: nil)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14))
                    Text("Start This Program")
                        .font(.headline)
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(PepTheme.teal)
                .clipShape(.rect(cornerRadius: 14))
            }
            .buttonStyle(.scalePrimary)

            Button {
                generatedProgram = nil
                isGenerating = false
                errorMessage = nil
                expandedDayId = nil
                expandedExerciseId = nil
            } label: {
                Text("Regenerate")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PepTheme.violet)
                    .padding(.vertical, 8)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button {
                    withAnimation { currentStep -= 1 }
                } label: {
                    Text("Back")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PepTheme.elevated)
                        .clipShape(.rect(cornerRadius: 12))
                }
            }

            Button {
                if currentStep < 3 {
                    withAnimation { currentStep += 1 }
                } else {
                    generateProgram()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(currentStep == 3 ? "Generate Program" : "Continue")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canProceed ? PepTheme.violet : PepTheme.violet.opacity(0.3))
                .clipShape(.rect(cornerRadius: 12))
            }
            .disabled(!canProceed)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            PepTheme.cardSurface
                .overlay(alignment: .top) {
                    Rectangle().fill(PepTheme.glassBorderTop).frame(height: 0.5)
                }
        )
    }

    private var canProceed: Bool {
        switch currentStep {
        case 0: !selectedGoal.isEmpty
        case 1: true
        case 2: !selectedEquipment.isEmpty
        case 3: true
        default: true
        }
    }

    private func stepHeader(icon: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(PepTheme.violet)
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func buildProtocolContext() -> String {
        guard includePeptideContext, let proto = activeProtocol else {
            guard includePeptideContext else { return "" }
            let protocolKey = "savedActiveProtocol"
            guard let data = UserDefaults.standard.data(forKey: protocolKey) else { return "" }
            guard let protocolInfo = try? JSONDecoder().decode(SavedProtocolInfo.self, from: data) else { return "" }
            return protocolInfo.summary
        }
        let compoundDetails = proto.compounds.map { "\($0.compoundName) \($0.doseMcg)mcg \($0.frequency) (\($0.injectionRoute.rawValue))" }.joined(separator: "; ")
        var parts = ["\(proto.name) — Goal: \(proto.goal.rawValue), Phase: \(proto.currentPhase.rawValue), Week \(proto.currentWeek)"]
        if let tw = proto.totalWeeks {
            parts.append("of \(tw)")
        }
        parts.append("Compounds: \(compoundDetails)")
        return parts.joined(separator: " | ")
    }

    private func generateProgram() {
        isGenerating = true
        errorMessage = nil

        var enrichedPreferences = preferences
        if let suggestion = preSelectedSuggestion {
            enrichedPreferences = [suggestion.aiPromptContext, preferences].filter { !$0.isEmpty }.joined(separator: "\n\n")
        }

        let request = AIProgramRequest(
            goal: selectedGoal,
            daysPerWeek: daysPerWeek,
            equipment: Array(selectedEquipment),
            experience: experience,
            injuries: injuries,
            peptideProtocol: buildProtocolContext(),
            sessionLength: sessionLength,
            preferences: enrichedPreferences,
            userContext: userContextSummary
        )

        Task {
            do {
                let program = try await AIProgramService.shared.generateProgram(request)
                generatedProgram = program
                isGenerating = false
            } catch {
                errorMessage = error.localizedDescription
                isGenerating = false
            }
        }
    }
}

nonisolated struct SavedProtocolInfo: Codable, Sendable {
    let name: String
    let goal: String
    let compounds: [String]

    var summary: String {
        let compoundList = compounds.joined(separator: ", ")
        return "\(name) (\(goal)) — compounds: \(compoundList)"
    }
}
