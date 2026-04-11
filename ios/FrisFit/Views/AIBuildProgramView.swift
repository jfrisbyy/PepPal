import SwiftUI

struct AIBuildProgramView: View {
    @Bindable var viewModel: TrainViewModel
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

    private let goals = ["Hypertrophy (Muscle Growth)", "Strength", "Recomp (Lose Fat + Build Muscle)", "General Fitness", "Athletic Performance", "Powerlifting"]
    private let equipmentOptions = ["Barbell", "Dumbbell", "Cable", "Machine", "Bodyweight", "Kettlebell", "Band"]
    private let experienceLevels = ["Beginner", "Intermediate", "Advanced"]
    private let sessionLengths = [30, 45, 60, 75, 90]

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
            .background(PepTheme.background.ignoresSafeArea())
            .navigationTitle("AI Program Builder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
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
                stepHeader(
                    icon: "target",
                    title: "What's your goal?",
                    subtitle: "This shapes your entire program — exercise selection, rep ranges, and volume."
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
                    title: "A few more details",
                    subtitle: "Optional — but the more the AI knows, the better your program."
                )

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

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Include Peptide Protocol Context")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                        Spacer()
                        Toggle("", isOn: $includePeptideContext)
                            .labelsHidden()
                            .tint(PepTheme.violet)
                    }

                    if includePeptideContext {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11))
                                .foregroundStyle(PepTheme.violet)
                            Text("The AI will factor in your active peptide protocol to customize exercise selection and volume.")
                                .font(.system(size: 11))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        .padding(10)
                        .background(PepTheme.violet.opacity(0.06))
                        .clipShape(.rect(cornerRadius: 8))
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

                Text("The AI is designing a personalized program\nbased on your inputs...")
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
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.green)

                        Text(program.name)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(PepTheme.textPrimary)

                        Text("\(program.days.count) days · \(program.days.reduce(0) { $0 + $1.exercises.count }) exercises")
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .padding(.top, 16)

                    ForEach(Array(program.days.enumerated()), id: \.element.id) { index, day in
                        aiResultDayCard(day, dayIndex: index)
                    }

                    VStack(spacing: 10) {
                        Button {
                            viewModel.activateTemplateProgram(program, startDayOffset: 0)
                            dismiss()
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
                        } label: {
                            Text("Regenerate")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PepTheme.violet)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
    }

    private func aiResultDayCard(_ day: ProgramDay, dayIndex: Int) -> some View {
        let isExpanded = expandedDayId == day.id

        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                expandedDayId = isExpanded ? nil : day.id
            }
        } label: {
            VStack(spacing: 0) {
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
                        Text("\(day.exercises.count) exercises")
                            .font(.system(size: 11))
                            .foregroundStyle(PepTheme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(14)

                if isExpanded {
                    VStack(spacing: 6) {
                        ForEach(day.exercises) { exercise in
                            HStack(spacing: 10) {
                                Image(systemName: exercise.primaryMuscle.icon)
                                    .font(.system(size: 10))
                                    .foregroundStyle(PepTheme.violet.opacity(0.6))
                                    .frame(width: 24, height: 24)
                                    .background(PepTheme.violet.opacity(0.08))
                                    .clipShape(Circle())

                                Text(exercise.exerciseName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(PepTheme.textPrimary)
                                    .lineLimit(1)

                                Spacer()

                                Text("\(exercise.targetSets)×\(exercise.targetRepsMin)-\(exercise.targetRepsMax)")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
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
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isExpanded)
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
                    if currentStep == 3 {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13))
                    }
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

    private func getPeptideContext() -> String {
        guard includePeptideContext else { return "" }
        let protocolKey = "savedActiveProtocol"
        guard let data = UserDefaults.standard.data(forKey: protocolKey) else { return "" }
        guard let protocolInfo = try? JSONDecoder().decode(SavedProtocolInfo.self, from: data) else { return "" }
        return protocolInfo.summary
    }

    private func generateProgram() {
        isGenerating = true
        errorMessage = nil

        let request = AIProgramRequest(
            goal: selectedGoal,
            daysPerWeek: daysPerWeek,
            equipment: Array(selectedEquipment),
            experience: experience,
            injuries: injuries,
            peptideProtocol: getPeptideContext(),
            sessionLength: sessionLength,
            preferences: preferences
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
