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
    @State private var isComposing: Bool = false
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
    @State private var composingPhraseIndex: Int = 0
    @State private var composingProgress: Double = 0

    struct AISwapTarget: Equatable {
        let dayId: UUID
        let exerciseIndex: Int
    }

    private let goals = ["Hypertrophy (Muscle Growth)", "Strength", "Recomp (Lose Fat + Build Muscle)", "General Fitness", "Athletic Performance", "Powerlifting", "Muscle Preservation (Deficit)", "Maintenance (Minimal Volume)"]
    private let equipmentOptions = ["Barbell", "Dumbbell", "Cable", "Machine", "Bodyweight", "Kettlebell", "Band"]
    private let experienceLevels = ["Beginner", "Intermediate", "Advanced"]
    private let sessionLengths = [30, 45, 60, 75, 90]

    private let chapters: [String] = [
        "CHAPTER ONE · INTENT",
        "CHAPTER TWO · CADENCE",
        "CHAPTER THREE · INSTRUMENTS",
        "CHAPTER FOUR · REFINEMENTS"
    ]

    private let composingPhrases: [String] = [
        "Considering your protocol.",
        "Sequencing your week.",
        "Selecting your movements.",
        "Balancing volume and recovery.",
        "Drafting the final pages."
    ]

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
                if generatedProgram == nil && !isComposing {
                    chapterIndicator
                }

                if generatedProgram != nil {
                    resultView
                } else if isComposing {
                    composingView
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

                if generatedProgram == nil && !isComposing {
                    bottomBar
                }
            }
            .appBackground()
            .navigationTitle("Design Your Program")
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

    // MARK: - Chapter Indicator

    private var chapterIndicator: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                ForEach(0..<4) { step in
                    HStack(spacing: 6) {
                        Text(String(format: "%02d", step + 1))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .tracking(1.2)
                            .foregroundStyle(step == currentStep ? PepTheme.textPrimary : (step < currentStep ? PepTheme.textSecondary : PepTheme.textTertiary))

                        if step < 3 {
                            Rectangle()
                                .fill(step < currentStep ? PepTheme.textSecondary.opacity(0.5) : PepTheme.textTertiary.opacity(0.25))
                                .frame(height: 0.5)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)

            Rectangle()
                .fill(PepTheme.textPrimary.opacity(0.08))
                .frame(height: 0.5)
        }
    }

    // MARK: - Step 1: Goal

    private var goalStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let suggestion = preSelectedSuggestion {
                    suggestionBanner(suggestion)
                } else if hasUserContext {
                    personalizedBanner
                }

                editorialHeader(
                    chapter: chapters[0],
                    title: "What's the intent?",
                    subtitle: hasUserContext
                        ? "Pre-selected from your profile. Adjust if it no longer fits."
                        : "This shapes the whole program — selection, rep ranges, and weekly volume."
                )

                VStack(spacing: 8) {
                    ForEach(goals, id: \.self) { goal in
                        editorialChoice(
                            label: goal,
                            isSelected: selectedGoal == goal
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedGoal = goal
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
    }

    private func suggestionBanner(_ suggestion: SmartProgramSuggestion) -> some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(suggestion.gradient.first ?? PepTheme.violet)
                .frame(width: 2)
                .frame(height: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text("PRESET")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(PepTheme.textTertiary)
                Text(suggestion.title)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
            }

            Spacer()
        }
        .padding(.vertical, 10)
    }

    private var personalizedBanner: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(PepTheme.violet.opacity(0.6))
                .frame(width: 2)
                .frame(height: 24)

            Text("Personalized from your profile")
                .font(.system(size: 12, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)

            Spacer()
        }
    }

    // MARK: - Step 2: Schedule

    private var scheduleStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                editorialHeader(
                    chapter: chapters[1],
                    title: "How often will you train?",
                    subtitle: "Choose a rhythm you can keep. Consistency beats ambition."
                )

                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("Days per week")
                    HStack(spacing: 6) {
                        ForEach(2...6, id: \.self) { day in
                            editorialPill(text: "\(day)", isSelected: daysPerWeek == day) {
                                withAnimation(.spring(response: 0.3)) { daysPerWeek = day }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("Session length")
                    HStack(spacing: 6) {
                        ForEach(sessionLengths, id: \.self) { length in
                            editorialPill(text: "\(length) min", isSelected: sessionLength == length) {
                                withAnimation(.spring(response: 0.3)) { sessionLength = length }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Step 3: Equipment

    private var equipmentStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                editorialHeader(
                    chapter: chapters[2],
                    title: "What instruments do you have?",
                    subtitle: "Only what you select will appear in your sessions."
                )

                VStack(spacing: 8) {
                    ForEach(equipmentOptions, id: \.self) { equip in
                        let isSelected = selectedEquipment.contains(equip)
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                if isSelected {
                                    selectedEquipment.remove(equip)
                                } else {
                                    selectedEquipment.insert(equip)
                                }
                            }
                        } label: {
                            HStack(spacing: 14) {
                                radioMark(isSelected: isSelected)

                                Text(equip)
                                    .font(.system(size: 16, design: .serif))
                                    .foregroundStyle(PepTheme.textPrimary)

                                Spacer()

                                Image(systemName: Equipment(rawValue: equip)?.icon ?? "questionmark")
                                    .font(.system(size: 13))
                                    .foregroundStyle(PepTheme.textTertiary)
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 4)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(PepTheme.textPrimary.opacity(0.08))
                                    .frame(height: 0.5)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Step 4: Details

    private var detailsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                editorialHeader(
                    chapter: chapters[3],
                    title: "Final refinements.",
                    subtitle: hasUserContext
                        ? "Your profile is already accounted for. Add anything else that matters."
                        : "Optional notes — the more we know, the more tailored the result."
                )

                if hasUserContext {
                    profileSummaryCard
                }

                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("Experience")
                    HStack(spacing: 6) {
                        ForEach(experienceLevels, id: \.self) { level in
                            editorialPill(text: level, isSelected: experience == level) {
                                withAnimation(.spring(response: 0.3)) { experience = level }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("Injuries or limitations")
                    editorialField(
                        text: $injuries,
                        placeholder: "e.g., Bad left shoulder, lower back issues"
                    )
                }

                if activeProtocol != nil {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            sectionLabel("Factor in active protocol")
                            Spacer()
                            Toggle("", isOn: $includePeptideContext)
                                .labelsHidden()
                                .tint(PepTheme.violet)
                                .scaleEffect(0.85)
                        }
                        if includePeptideContext {
                            Text("Your protocol, phase, and compounds will inform exercise selection and volume.")
                                .font(.system(size: 12, design: .serif))
                                .italic()
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("Anything else")
                    editorialField(
                        text: $preferences,
                        placeholder: "e.g., Prefer supersets, more arm work, hate leg press"
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
    }

    private var profileSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(PepTheme.violet.opacity(0.7))
                    .frame(width: 2, height: 12)
                Text("PERSONALIZED FROM YOUR PROFILE")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                if let proto = activeProtocol {
                    summaryLine("\(proto.name) · \(proto.currentPhase.rawValue) · Week \(proto.currentWeek)")
                    let compoundNames = proto.compounds.map { $0.compoundName }.joined(separator: ", ")
                    if !compoundNames.isEmpty {
                        summaryLine(compoundNames)
                    }
                }

                if let goal = bodyGoal {
                    summaryLine("Goal — \(goal.rawValue)")
                }

                if let cw = currentWeight, cw > 0 {
                    let weightText = targetWeight != nil && targetWeight! > 0
                        ? "\(String(format: "%.0f", cw)) → \(String(format: "%.0f", targetWeight!)) lbs"
                        : "\(String(format: "%.0f", cw)) lbs"
                    summaryLine(weightText)
                }

                summaryLine("\(totalWorkouts) total sessions · \(viewModel.workoutsCompletedThisWeek)/wk recent")
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.cardSurface.opacity(0.5))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(PepTheme.violet.opacity(0.5))
                .frame(width: 1.5)
        }
    }

    private func summaryLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, design: .serif))
            .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
            .lineLimit(2)
    }

    // MARK: - Composing

    private var composingView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 22) {
                Text("COMPOSING")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.4)
                    .foregroundStyle(PepTheme.textTertiary)

                Text("Composing your plan.")
                    .font(.system(size: 30, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text(composingPhrases[composingPhraseIndex % composingPhrases.count])
                    .font(.system(size: 14, design: .serif))
                    .foregroundStyle(PepTheme.textSecondary)
                    .id(composingPhraseIndex)
                    .transition(.opacity)

                progressLine
                    .padding(.horizontal, 60)
                    .padding(.top, 8)
            }

            if let error = errorMessage {
                VStack(spacing: 14) {
                    Rectangle()
                        .fill(PepTheme.textPrimary.opacity(0.08))
                        .frame(width: 60, height: 0.5)
                        .padding(.top, 28)
                    Text(error)
                        .font(.system(size: 12, design: .serif))
                        .italic()
                        .foregroundStyle(.red.opacity(0.85))
                        .multilineTextAlignment(.center)
                    Button("Try again") {
                        errorMessage = nil
                        composeProgram()
                    }
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                    .underline()
                }
                .padding(.horizontal, 40)
                .padding(.top, 12)
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear { startComposingAnimation() }
    }

    private var progressLine: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(PepTheme.textPrimary.opacity(0.08))
                    .frame(height: 1)
                Rectangle()
                    .fill(PepTheme.textPrimary.opacity(0.6))
                    .frame(width: geo.size.width * composingProgress, height: 1)
            }
        }
        .frame(height: 1)
    }

    private func startComposingAnimation() {
        composingPhraseIndex = 0
        composingProgress = 0
        withAnimation(.easeInOut(duration: 0.4)) {
            composingProgress = 0.15
        }
        Task {
            for _ in 0..<composingPhrases.count {
                try? await Task.sleep(for: .seconds(1.6))
                guard isComposing else { return }
                withAnimation(.easeInOut(duration: 0.4)) {
                    composingPhraseIndex += 1
                    composingProgress = min(0.92, composingProgress + 0.18)
                }
            }
        }
    }

    // MARK: - Result

    private var resultView: some View {
        ScrollView {
            if let program = generatedProgram {
                VStack(spacing: 22) {
                    resultHeader(program: program)
                    weeklyScheduleOverview(program: program)

                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel("The sessions")
                        VStack(spacing: 10) {
                            ForEach(Array(program.days.enumerated()), id: \.element.id) { index, _ in
                                editableDayCard(dayIndex: index)
                            }
                        }
                    }

                    actionButtons
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
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
        VStack(spacing: 14) {
            Text("YOUR PROGRAM")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.4)
                .foregroundStyle(PepTheme.textTertiary)

            Button {
                renameProgramText = program.name
                showRenameProgram = true
            } label: {
                HStack(spacing: 8) {
                    Text(program.name)
                        .font(.system(size: 32, weight: .regular, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                        .multilineTextAlignment(.center)
                        .kerning(-0.4)
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                        .foregroundStyle(PepTheme.textTertiary)
                }
            }
            .buttonStyle(.plain)

            let scheduled = program.days.filter { $0.scheduledWeekday != nil }.count
            let totalEx = program.days.reduce(0) { $0 + $1.exercises.count }
            Text("\(program.days.count) days · \(totalEx) movements · \(scheduled) of \(program.days.count) placed")
                .font(.system(size: 12, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)

            Rectangle()
                .fill(PepTheme.textPrimary.opacity(0.12))
                .frame(width: 40, height: 0.5)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func weeklyScheduleOverview(program: TrainingProgram) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("The week")

            HStack(spacing: 0) {
                ForEach(ProgramWeekday.allCases) { weekday in
                    let dayAtWeekday = program.days.first { $0.scheduledWeekday == weekday.rawValue }
                    VStack(spacing: 6) {
                        Text(weekday.singleLetter)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(dayAtWeekday != nil ? PepTheme.textPrimary : PepTheme.textTertiary)

                        Rectangle()
                            .fill(dayAtWeekday != nil ? PepTheme.violet.opacity(0.7) : PepTheme.textTertiary.opacity(0.2))
                            .frame(width: 18, height: 1)

                        Text(dayAtWeekday?.name ?? "Rest")
                            .font(.system(size: 10, design: .serif))
                            .italic()
                            .foregroundStyle(dayAtWeekday != nil ? PepTheme.textPrimary.opacity(0.85) : PepTheme.textTertiary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
            .padding(.vertical, 4)
            .background(
                Rectangle()
                    .fill(PepTheme.textPrimary.opacity(0.06))
                    .frame(height: 0.5),
                alignment: .top
            )
            .background(
                Rectangle()
                    .fill(PepTheme.textPrimary.opacity(0.06))
                    .frame(height: 0.5),
                alignment: .bottom
            )

            let unscheduled = program.days.filter { $0.scheduledWeekday == nil }.count
            if unscheduled > 0 {
                Text("\(unscheduled) session\(unscheduled == 1 ? "" : "s") not yet placed.")
                    .font(.system(size: 11, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.amber)
            }
        }
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
                    HStack(alignment: .top, spacing: 14) {
                        Text(romanNumeral(dayIndex + 1))
                            .font(.system(size: 18, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(PepTheme.textTertiary)
                            .frame(width: 28, alignment: .leading)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(day.name)
                                .font(.system(size: 18, weight: .regular, design: .serif))
                                .foregroundStyle(PepTheme.textPrimary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            HStack(spacing: 8) {
                                Text("\(day.exercises.count) movements")
                                    .font(.system(size: 11, design: .serif))
                                    .italic()
                                    .foregroundStyle(PepTheme.textSecondary)
                                if let wd = day.scheduledWeekday, let weekday = ProgramWeekday(rawValue: wd) {
                                    Text("·")
                                        .font(.system(size: 11))
                                        .foregroundStyle(PepTheme.textTertiary)
                                    Text(weekday.shortLabel)
                                        .font(.system(size: 11, weight: .medium))
                                        .tracking(0.6)
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
                                Label("Add Movement", systemImage: "plus")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(PepTheme.textTertiary)
                                .frame(width: 28, height: 28)
                        }

                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(PepTheme.textTertiary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(spacing: 14) {
                        Rectangle()
                            .fill(PepTheme.textPrimary.opacity(0.06))
                            .frame(height: 0.5)
                            .padding(.horizontal, 16)

                        weekdayPicker(dayIndex: dayIndex)
                            .padding(.horizontal, 16)

                        VStack(spacing: 0) {
                            ForEach(Array(day.exercises.enumerated()), id: \.element.id) { exIdx, exercise in
                                editableExerciseRow(dayIndex: dayIndex, exerciseIndex: exIdx, exercise: exercise)
                            }
                        }
                        .padding(.horizontal, 16)

                        Button {
                            pickerDayId = day.id
                            swapTarget = nil
                            showExercisePicker = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11))
                                Text("Add movement")
                                    .font(.system(size: 13, design: .serif))
                                    .italic()
                            }
                            .foregroundStyle(PepTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .overlay(
                                Rectangle()
                                    .strokeBorder(PepTheme.textPrimary.opacity(0.15), lineWidth: 0.5)
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(PepTheme.cardSurface.opacity(0.4))
            .overlay(
                Rectangle()
                    .strokeBorder(PepTheme.textPrimary.opacity(0.08), lineWidth: 0.5)
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
                Text("PLACE ON")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(PepTheme.textTertiary)
                HStack(spacing: 4) {
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
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .tracking(0.6)
                                    .foregroundStyle(isSelected ? PepTheme.textPrimary : PepTheme.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 32)
                                    .overlay(
                                        Rectangle()
                                            .strokeBorder(
                                                isSelected ? PepTheme.violet.opacity(0.7) : PepTheme.textPrimary.opacity(0.1),
                                                lineWidth: isSelected ? 1 : 0.5
                                            )
                                    )
                                if sharedCount > 0 {
                                    Circle()
                                        .fill(PepTheme.amber)
                                        .frame(width: 5, height: 5)
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
                HStack(spacing: 12) {
                    Text(String(format: "%02d", exerciseIndex + 1))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(PepTheme.textTertiary)
                        .frame(width: 22, alignment: .leading)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(exercise.exerciseName)
                            .font(.system(size: 14, design: .serif))
                            .foregroundStyle(PepTheme.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text("\(exercise.targetSets) × \(exercise.targetRepsMin)–\(exercise.targetRepsMax) · \(exercise.restSeconds)s rest")
                            .font(.system(size: 10, design: .serif))
                            .italic()
                            .foregroundStyle(PepTheme.textSecondary)
                    }

                    Spacer(minLength: 6)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                        .foregroundStyle(PepTheme.textTertiary)
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(PepTheme.textPrimary.opacity(0.06))
                    .frame(height: 0.5)
            }

            if isExpanded {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        exerciseStepper(label: "Sets", value: exercise.targetSets, range: 1...10) { new in
                            updateExercise(dayIndex: dayIndex, exerciseIndex: exerciseIndex) { $0.targetSets = new }
                        }
                        exerciseStepper(label: "Min reps", value: exercise.targetRepsMin, range: 1...50) { new in
                            updateExercise(dayIndex: dayIndex, exerciseIndex: exerciseIndex) {
                                $0.targetRepsMin = new
                                if $0.targetRepsMax < new { $0.targetRepsMax = new }
                            }
                        }
                        exerciseStepper(label: "Max reps", value: exercise.targetRepsMax, range: 1...50) { new in
                            updateExercise(dayIndex: dayIndex, exerciseIndex: exerciseIndex) {
                                $0.targetRepsMax = new
                                if $0.targetRepsMin > new { $0.targetRepsMin = new }
                            }
                        }
                    }

                    HStack {
                        Text("Rest")
                            .font(.system(size: 11, design: .serif))
                            .italic()
                            .foregroundStyle(PepTheme.textSecondary)
                        Spacer()
                        HStack(spacing: 8) {
                            Button {
                                updateExercise(dayIndex: dayIndex, exerciseIndex: exerciseIndex) {
                                    if $0.restSeconds > 15 { $0.restSeconds -= 15 }
                                }
                            } label: {
                                Image(systemName: "minus")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(PepTheme.textSecondary)
                                    .frame(width: 24, height: 24)
                                    .overlay(Rectangle().strokeBorder(PepTheme.textPrimary.opacity(0.12), lineWidth: 0.5))
                            }
                            Text("\(exercise.restSeconds)s")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(PepTheme.textPrimary)
                                .frame(width: 44)
                            Button {
                                updateExercise(dayIndex: dayIndex, exerciseIndex: exerciseIndex) {
                                    if $0.restSeconds < 300 { $0.restSeconds += 15 }
                                }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(PepTheme.textSecondary)
                                    .frame(width: 24, height: 24)
                                    .overlay(Rectangle().strokeBorder(PepTheme.textPrimary.opacity(0.12), lineWidth: 0.5))
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
                            Text("Swap")
                                .font(.system(size: 12, design: .serif))
                                .italic()
                                .foregroundStyle(PepTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .overlay(Rectangle().strokeBorder(PepTheme.textPrimary.opacity(0.15), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)

                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                removeExercise(dayIndex: dayIndex, exerciseIndex: exerciseIndex)
                            }
                        } label: {
                            Text("Remove")
                                .font(.system(size: 12, design: .serif))
                                .italic()
                                .foregroundStyle(.red.opacity(0.85))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .overlay(Rectangle().strokeBorder(Color.red.opacity(0.25), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 12)
            }
        }
    }

    private func exerciseStepper(label: String, value: Int, range: ClosedRange<Int>, onChange: @escaping (Int) -> Void) -> some View {
        VStack(spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(PepTheme.textTertiary)
            HStack(spacing: 4) {
                Button {
                    if value > range.lowerBound { onChange(value - 1) }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 22, height: 22)
                        .overlay(Rectangle().strokeBorder(PepTheme.textPrimary.opacity(0.12), lineWidth: 0.5))
                }
                Text("\(value)")
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                    .frame(minWidth: 24)
                Button {
                    if value < range.upperBound { onChange(value + 1) }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 22, height: 22)
                        .overlay(Rectangle().strokeBorder(PepTheme.textPrimary.opacity(0.12), lineWidth: 0.5))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(PepTheme.cardSurface.opacity(0.5))
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
        VStack(spacing: 14) {
            Button {
                guard let program = generatedProgram else { return }
                viewModel.activateTemplateProgram(program, startDayOffset: 0)
                dismiss()
                NotificationCenter.default.post(name: .switchToHomeTab, object: nil)
            } label: {
                Text("Begin Program")
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .tracking(0.4)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(PepTheme.teal)
            }
            .buttonStyle(.scalePrimary)

            Button {
                generatedProgram = nil
                isComposing = false
                errorMessage = nil
                expandedDayId = nil
                expandedExerciseId = nil
            } label: {
                Text("Refine")
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .underline()
                    .padding(.vertical, 8)
            }
        }
        .padding(.top, 6)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button {
                    withAnimation { currentStep -= 1 }
                } label: {
                    Text("Back")
                        .font(.system(size: 14, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(maxWidth: 80)
                        .padding(.vertical, 16)
                }
            }

            Spacer()

            Button {
                if currentStep < 3 {
                    withAnimation { currentStep += 1 }
                } else {
                    composeProgram()
                }
            } label: {
                HStack(spacing: 10) {
                    Text(currentStep == 3 ? "Compose Program" : "Continue")
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .tracking(0.4)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(canProceed ? PepTheme.textPrimary : PepTheme.textTertiary)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .overlay(
                    Rectangle()
                        .strokeBorder(canProceed ? PepTheme.textPrimary.opacity(0.4) : PepTheme.textPrimary.opacity(0.12), lineWidth: 0.5)
                )
            }
            .disabled(!canProceed)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .overlay(alignment: .top) {
            Rectangle().fill(PepTheme.textPrimary.opacity(0.08)).frame(height: 0.5)
        }
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

    // MARK: - Editorial helpers

    private func editorialHeader(chapter: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(chapter)
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.4)
                .foregroundStyle(PepTheme.textTertiary)

            Text(title)
                .font(.system(size: 30, weight: .regular, design: .serif))
                .kerning(-0.4)
                .foregroundStyle(PepTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.system(size: 14, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(PepTheme.textPrimary.opacity(0.12))
                .frame(width: 32, height: 0.5)
                .padding(.top, 4)
        }
        .padding(.bottom, 6)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.8)
            .foregroundStyle(PepTheme.textTertiary)
    }

    private func editorialChoice(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                radioMark(isSelected: isSelected)
                Text(label)
                    .font(.system(size: 16, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 4)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(PepTheme.textPrimary.opacity(0.08))
                    .frame(height: 0.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func radioMark(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .strokeBorder(isSelected ? PepTheme.violet.opacity(0.8) : PepTheme.textPrimary.opacity(0.25), lineWidth: 0.8)
                .frame(width: 16, height: 16)
            if isSelected {
                Circle()
                    .fill(PepTheme.violet)
                    .frame(width: 8, height: 8)
            }
        }
    }

    private func editorialPill(text: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 13, design: .serif))
                .foregroundStyle(isSelected ? PepTheme.textPrimary : PepTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .overlay(
                    Rectangle()
                        .strokeBorder(
                            isSelected ? PepTheme.violet.opacity(0.7) : PepTheme.textPrimary.opacity(0.12),
                            lineWidth: isSelected ? 1 : 0.5
                        )
                )
                .background(isSelected ? PepTheme.violet.opacity(0.05) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private func editorialField(text: Binding<String>, placeholder: String) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 15, design: .serif))
            .foregroundStyle(PepTheme.textPrimary)
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(PepTheme.textPrimary.opacity(0.18))
                    .frame(height: 0.5)
            }
    }

    private func romanNumeral(_ n: Int) -> String {
        let romans: [(Int, String)] = [
            (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")
        ]
        var num = n
        var result = ""
        for (val, sym) in romans {
            while num >= val {
                result += sym
                num -= val
            }
        }
        return result.isEmpty ? "\(n)" : result
    }

    // MARK: - Compose

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

    private func composeProgram() {
        isComposing = true
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
                withAnimation(.easeInOut(duration: 0.4)) {
                    composingProgress = 1.0
                }
                try? await Task.sleep(for: .milliseconds(220))
                generatedProgram = program
                isComposing = false
            } catch {
                errorMessage = error.localizedDescription
                isComposing = false
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
