import SwiftUI

struct GoalsStepView: View {
    @Bindable var state: OnboardingState
    let onContinue: () -> Void

    @State private var screen: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            screenHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch screen {
                    case 0: PrimaryGoalScreen(state: state)
                    case 1: TargetMetricScreen(state: state)
                    case 2: TrainingContextScreen(state: state)
                    case 3: NutritionContextScreen(state: state)
                    default: SmartDefaultsReviewScreen(state: state)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)

            footer
        }
        .onChange(of: screen) { _, newValue in
            if newValue == 4 { recomputeDefaults() }
        }
    }

    private var screenHeader: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { idx in
                    Capsule()
                        .fill(idx <= screen ? PepTheme.teal : PepTheme.elevated.opacity(0.7))
                        .frame(height: 3)
                        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: screen)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)

            Text(currentTitle)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
        }
        .padding(.bottom, 4)
    }

    private var currentTitle: String {
        switch screen {
        case 0: "GOAL  •  1 of 5"
        case 1: "TARGET  •  2 of 5"
        case 2: "TRAINING  •  3 of 5"
        case 3: "NUTRITION  •  4 of 5"
        default: "SUGGESTED PLAN  •  5 of 5"
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if screen > 0 {
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        screen -= 1
                    }
                } label: {
                    Text("Back")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(PepTheme.elevated.opacity(0.7))
                        .clipShape(.rect(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }

            Button {
                advance()
            } label: {
                Text(screen == 4 ? "Looks right" : "Continue")
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canAdvance ? PepTheme.teal : PepTheme.elevated)
                    .clipShape(.rect(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(!canAdvance)
            .animation(.easeInOut(duration: 0.2), value: canAdvance)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .padding(.top, 8)
    }

    private var canAdvance: Bool {
        switch screen {
        case 0: return state.primaryGoal != nil
        default: return true
        }
    }

    private func advance() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if screen == 4 {
            onContinue()
            return
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            screen += 1
        }
    }

    private func recomputeDefaults() {
        guard let goal = state.primaryGoal,
              let tdee = state.tdeeKcal,
              let weightKg = state.weightKg else { return }
        let waterMl = state.dailyWaterMl ?? 2500
        let stepFloor = state.dailyStepFloor ?? 8000
        state.goalDefaults = GoalDefaultsCalculator.compute(
            tdee: tdee,
            weightKg: weightKg,
            goal: goal,
            proteinPerKgOverride: state.proteinPerKgOverride,
            waterMl: waterMl,
            stepFloor: stepFloor
        )
    }
}

// MARK: - Screen 1: Primary Goal

private struct PrimaryGoalScreen: View {
    @Bindable var state: OnboardingState
    @State private var addingSecondary: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle().fill(PepTheme.teal.opacity(0.16)).frame(width: 56, height: 56)
                    Image(systemName: "target")
                        .font(.system(size: 26))
                        .foregroundStyle(PepTheme.teal)
                }
                Text("What are you working toward?")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Pick the one that matters most. You can add a secondary goal below.")
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                ForEach(PrimaryGoal.allCases) { goal in
                    GoalCard(
                        goal: goal,
                        isSelected: state.primaryGoal == goal,
                        accentLabel: "PRIMARY"
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            state.primaryGoal = goal
                            if state.secondaryGoal == goal { state.secondaryGoal = nil }
                        }
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                }
            }

            if state.primaryGoal != nil {
                if addingSecondary || state.secondaryGoal != nil {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Secondary goal")
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                            Spacer()
                            if state.secondaryGoal != nil {
                                Button {
                                    withAnimation { state.secondaryGoal = nil }
                                } label: {
                                    Text("Remove").font(.footnote).foregroundStyle(PepTheme.textSecondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        VStack(spacing: 8) {
                            ForEach(PrimaryGoal.allCases.filter { $0 != state.primaryGoal }) { goal in
                                CompactGoalRow(
                                    goal: goal,
                                    isSelected: state.secondaryGoal == goal
                                ) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                        state.secondaryGoal = (state.secondaryGoal == goal) ? nil : goal
                                    }
                                    UISelectionFeedbackGenerator().selectionChanged()
                                }
                            }
                        }
                    }
                } else {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            addingSecondary = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill").foregroundStyle(PepTheme.teal)
                            Text("Add a secondary goal")
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                            Spacer()
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(PepTheme.cardSurface.opacity(0.6))
                        .clipShape(.rect(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(PepTheme.glassBorderBottom, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct GoalCard: View {
    let goal: PrimaryGoal
    let isSelected: Bool
    let accentLabel: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? goal.accent.opacity(0.22) : PepTheme.elevated.opacity(0.6))
                        .frame(width: 48, height: 48)
                    Image(systemName: goal.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isSelected ? goal.accent : PepTheme.textSecondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(goal.title)
                            .font(.system(.headline, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                        if isSelected, let accentLabel {
                            Text(accentLabel)
                                .font(.system(size: 9, weight: .heavy))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(goal.accent.opacity(0.2))
                                .foregroundStyle(goal.accent)
                                .clipShape(Capsule())
                        }
                    }
                    Text(goal.subtitle)
                        .font(.footnote)
                        .foregroundStyle(PepTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? goal.accent : PepTheme.textSecondary.opacity(0.4))
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(14)
            .background(PepTheme.cardSurface.opacity(isSelected ? 0.95 : 0.65))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isSelected ? goal.accent.opacity(0.55) : PepTheme.glassBorderBottom,
                        lineWidth: isSelected ? 1.4 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct CompactGoalRow: View {
    let goal: PrimaryGoal
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: goal.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? goal.accent : PepTheme.textSecondary)
                    .frame(width: 22)
                Text(goal.title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? goal.accent : PepTheme.textSecondary.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isSelected ? goal.accent.opacity(0.12) : PepTheme.elevated.opacity(0.55))
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? goal.accent.opacity(0.45) : PepTheme.glassBorderBottom, lineWidth: isSelected ? 1.0 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Screen 2: Target Metric

private struct TargetMetricScreen: View {
    @Bindable var state: OnboardingState
    @State private var weightText: String = ""
    @State private var bfText: String = ""
    @State private var perfText: String = ""
    @State private var hasTargetDate: Bool = false
    @State private var dateDraft: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()

    private var goal: PrimaryGoal { state.primaryGoal ?? .longevity }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HeaderBlock(
                icon: "flag.checkered",
                title: "Set a target",
                subtitle: "We'll calibrate your plan around this. You can adjust it any time."
            )

            switch goal.targetMetricKind {
            case .bodyWeight:
                weightTargetCard
            case .performance:
                performanceTargetCard
            case .none:
                noTargetCard
            }

            targetDateCard
        }
        .onAppear { hydrate() }
    }

    private var weightTargetCard: some View {
        FieldCard(title: "Target weight", icon: "scalemass.fill") {
            VStack(spacing: 12) {
                HStack {
                    TextField(state.unitSystem == .metric ? "e.g. 72" : "e.g. 160", text: $weightText)
                        .keyboardType(.decimalPad)
                        .padding(12)
                        .background(PepTheme.elevated.opacity(0.6))
                        .clipShape(.rect(cornerRadius: 10))
                        .foregroundStyle(PepTheme.textPrimary)
                        .onChange(of: weightText) { _, _ in syncTargetWeight() }
                    Text(state.unitSystem.weightUnitLabel)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 36, alignment: .leading)
                }
                if let current = currentWeightDisplay, let target = targetDisplay {
                    DeltaIndicator(current: current, target: target, unit: state.unitSystem.weightUnitLabel, isLossGood: goal == .fatLoss)
                }
                if goal == .recomposition {
                    HStack {
                        TextField("Optional target body fat %", text: $bfText)
                            .keyboardType(.decimalPad)
                            .padding(12)
                            .background(PepTheme.elevated.opacity(0.6))
                            .clipShape(.rect(cornerRadius: 10))
                            .foregroundStyle(PepTheme.textPrimary)
                            .onChange(of: bfText) { _, _ in
                                state.targetBodyFatPercent = Double(bfText.replacingOccurrences(of: ",", with: "."))
                            }
                        Text("%")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                            .frame(width: 36, alignment: .leading)
                    }
                }
            }
        }
    }

    private var performanceTargetCard: some View {
        FieldCard(title: "Target performance metric", icon: "bolt.fill") {
            TextField("e.g. 5K under 22:00, 1.5x BW deadlift", text: $perfText, axis: .vertical)
                .lineLimit(2...4)
                .padding(12)
                .background(PepTheme.elevated.opacity(0.6))
                .clipShape(.rect(cornerRadius: 10))
                .foregroundStyle(PepTheme.textPrimary)
                .onChange(of: perfText) { _, _ in state.targetPerformanceMetric = perfText }
        }
    }

    private var noTargetCard: some View {
        FieldCard(title: "How we'll track this", icon: "chart.line.uptrend.xyaxis") {
            Text(goal == .longevity
                 ? "We'll watch biomarkers, sleep, HRV, and consistency. Optional target weight below."
                 : "We'll track recovery progress against your baseline. Optional target weight below.")
                .font(.footnote)
                .foregroundStyle(PepTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)

            HStack {
                TextField(state.unitSystem == .metric ? "Optional target weight" : "Optional target weight", text: $weightText)
                    .keyboardType(.decimalPad)
                    .padding(12)
                    .background(PepTheme.elevated.opacity(0.6))
                    .clipShape(.rect(cornerRadius: 10))
                    .foregroundStyle(PepTheme.textPrimary)
                    .onChange(of: weightText) { _, _ in syncTargetWeight() }
                Text(state.unitSystem.weightUnitLabel)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .frame(width: 36, alignment: .leading)
            }
        }
    }

    private var targetDateCard: some View {
        FieldCard(title: "Target date (optional)", icon: "calendar.badge.clock") {
            VStack(spacing: 10) {
                Toggle(isOn: $hasTargetDate) {
                    Text(hasTargetDate ? "I have a date in mind" : "No date yet")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(PepTheme.textPrimary)
                }
                .tint(PepTheme.teal)
                .onChange(of: hasTargetDate) { _, newValue in
                    state.targetDate = newValue ? dateDraft : nil
                }

                if hasTargetDate {
                    DatePicker("Target", selection: $dateDraft, in: Date()..., displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .tint(PepTheme.teal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onChange(of: dateDraft) { _, newValue in state.targetDate = newValue }
                }
            }
        }
    }

    private var currentWeightDisplay: Double? {
        guard let kg = state.weightKg else { return nil }
        return state.unitSystem == .metric ? kg : UnitConversion.kgToPounds(kg)
    }

    private var targetDisplay: Double? {
        guard let kg = state.targetWeightKg else { return nil }
        return state.unitSystem == .metric ? kg : UnitConversion.kgToPounds(kg)
    }

    private func syncTargetWeight() {
        let cleaned = weightText.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), value > 0 else {
            state.targetWeightKg = nil
            return
        }
        let kg = state.unitSystem == .metric ? value : UnitConversion.poundsToKg(value)
        state.targetWeightKg = kg
    }

    private func hydrate() {
        if let kg = state.targetWeightKg {
            let display = state.unitSystem == .metric ? kg : UnitConversion.kgToPounds(kg)
            weightText = String(format: "%.1f", display)
        }
        if let bf = state.targetBodyFatPercent { bfText = String(format: "%.1f", bf) }
        perfText = state.targetPerformanceMetric
        if let date = state.targetDate {
            hasTargetDate = true
            dateDraft = date
        }
    }
}

private struct DeltaIndicator: View {
    let current: Double
    let target: Double
    let unit: String
    let isLossGood: Bool

    var body: some View {
        let delta = target - current
        let abs = Swift.abs(delta)
        let isPositive = delta >= 0
        let label = isPositive ? "Gain \(String(format: "%.1f", abs)) \(unit)" : "Lose \(String(format: "%.1f", abs)) \(unit)"
        let goodDirection = (isLossGood && delta < 0) || (!isLossGood && delta > 0)
        let color: Color = abs < 0.05 ? PepTheme.textSecondary : (goodDirection ? PepTheme.teal : PepTheme.amber)

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Current")
                    .font(.caption2).foregroundStyle(PepTheme.textSecondary)
                Text("\(String(format: "%.1f", current)) \(unit)")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            ZStack {
                Capsule().fill(PepTheme.elevated.opacity(0.6)).frame(height: 6)
                GeometryReader { geo in
                    Capsule()
                        .fill(color)
                        .frame(width: max(8, min(geo.size.width, geo.size.width * 0.05 + CGFloat(abs) * 6)), height: 6)
                }
                .frame(height: 6)
            }
            VStack(alignment: .trailing, spacing: 2) {
                Text(label)
                    .font(.caption2).foregroundStyle(color)
                Text("\(String(format: "%.1f", target)) \(unit)")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
            }
        }
        .padding(10)
        .background(PepTheme.elevated.opacity(0.4))
        .clipShape(.rect(cornerRadius: 10))
    }
}

// MARK: - Screen 3: Training Context

private struct TrainingContextScreen: View {
    @Bindable var state: OnboardingState
    @State private var sessionsValue: Double = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HeaderBlock(
                icon: "figure.strengthtraining.traditional",
                title: "How you train",
                subtitle: "We'll match your starter program to this."
            )

            FieldCard(title: "Sessions per week", icon: "calendar") {
                VStack(spacing: 10) {
                    HStack {
                        Slider(value: $sessionsValue, in: 0...7, step: 1)
                            .tint(PepTheme.teal)
                            .onChange(of: sessionsValue) { _, v in
                                state.sessionsPerWeek = Int(v)
                            }
                        Text("\(Int(sessionsValue))")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                            .frame(width: 36, alignment: .trailing)
                    }
                    Text(sessionsCopy)
                        .font(.footnote)
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            FieldCard(title: "Modality", icon: "figure.cross.training") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
                    ForEach(TrainingModality.allCases) { mod in
                        ChipToggle(
                            label: mod.label,
                            icon: mod.icon,
                            isOn: state.trainingModalities.contains(mod)
                        ) {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                if state.trainingModalities.contains(mod) {
                                    state.trainingModalities.remove(mod)
                                } else {
                                    state.trainingModalities.insert(mod)
                                }
                            }
                            UISelectionFeedbackGenerator().selectionChanged()
                        }
                    }
                }
            }

            FieldCard(title: "Experience", icon: "chart.line.uptrend.xyaxis") {
                HStack(spacing: 8) {
                    ForEach(TrainingExperience.allCases) { level in
                        SegmentButton(
                            label: level.label,
                            isOn: state.experienceLevel == level
                        ) {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                state.experienceLevel = level
                            }
                            UISelectionFeedbackGenerator().selectionChanged()
                        }
                    }
                }
            }

            FieldCard(title: "Current program", icon: "list.bullet.rectangle") {
                VStack(spacing: 10) {
                    TextField("e.g. 5/3/1, PPL, unstructured", text: $state.currentProgramName)
                        .padding(12)
                        .background(PepTheme.elevated.opacity(0.6))
                        .clipShape(.rect(cornerRadius: 10))
                        .foregroundStyle(PepTheme.textPrimary)
                        .autocorrectionDisabled()
                    HStack(spacing: 8) {
                        ForEach(["Unstructured", "PPL", "Upper/Lower", "Full body"], id: \.self) { suggestion in
                            Button {
                                state.currentProgramName = suggestion
                                UISelectionFeedbackGenerator().selectionChanged()
                            } label: {
                                Text(suggestion)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(PepTheme.elevated.opacity(0.7))
                                    .foregroundStyle(PepTheme.textPrimary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            FieldCard(title: "Injury history", icon: "bandage") {
                VStack(spacing: 10) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                        ForEach(InjuryArea.allCases) { area in
                            ChipToggle(
                                label: area.label,
                                icon: area.icon,
                                isOn: state.injuries.contains(area)
                            ) {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                    if state.injuries.contains(area) {
                                        state.injuries.remove(area)
                                    } else {
                                        state.injuries.insert(area)
                                    }
                                }
                                UISelectionFeedbackGenerator().selectionChanged()
                            }
                        }
                    }
                    if state.injuries.contains(.other) {
                        TextField("Tell us a bit more", text: $state.otherInjuryNote, axis: .vertical)
                            .lineLimit(2...4)
                            .padding(12)
                            .background(PepTheme.elevated.opacity(0.6))
                            .clipShape(.rect(cornerRadius: 10))
                            .foregroundStyle(PepTheme.textPrimary)
                    }
                }
            }
        }
        .onAppear { sessionsValue = Double(state.sessionsPerWeek) }
    }

    private var sessionsCopy: String {
        switch state.sessionsPerWeek {
        case 0: return "Resting this block — that's totally fine."
        case 1...2: return "Light cadence."
        case 3...4: return "Solid, sustainable cadence."
        case 5...6: return "High frequency — recovery becomes the limiter."
        default: return "Daily — make sure deloads are scheduled."
        }
    }
}

// MARK: - Screen 4: Nutrition Context

private struct NutritionContextScreen: View {
    @Bindable var state: OnboardingState
    @State private var allergyDraft: String = ""
    @State private var restrictionDraft: String = ""
    @State private var letAppSuggestProtein: Bool = true
    @State private var proteinPerKgText: String = ""

    private let commonAllergies = ["Peanuts", "Tree nuts", "Dairy", "Eggs", "Shellfish", "Soy", "Gluten", "Fish"]
    private let commonRestrictions = ["No pork", "No beef", "No alcohol", "Halal", "Kosher", "Low FODMAP"]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HeaderBlock(
                icon: "fork.knife",
                title: "How you eat",
                subtitle: "We'll respect this when generating meal suggestions and macro splits."
            )

            FieldCard(title: "Diet style", icon: "leaf.fill") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                    ForEach(DietStyle.allCases) { style in
                        ChipToggle(
                            label: style.label,
                            icon: nil,
                            isOn: state.dietStyle == style
                        ) {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                state.dietStyle = style
                            }
                            UISelectionFeedbackGenerator().selectionChanged()
                        }
                    }
                }
            }

            FieldCard(title: "Tracking experience", icon: "chart.bar.doc.horizontal") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
                    ForEach(PriorTracker.allCases) { tracker in
                        ChipToggle(
                            label: tracker.label,
                            icon: nil,
                            isOn: state.priorTracker == tracker
                        ) {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                state.priorTracker = tracker
                            }
                            UISelectionFeedbackGenerator().selectionChanged()
                        }
                    }
                }
            }

            FieldCard(title: "Protein floor", icon: "circle.hexagongrid.fill") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(isOn: $letAppSuggestProtein) {
                        Text("Let EPTI suggest")
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundStyle(PepTheme.textPrimary)
                    }
                    .tint(PepTheme.teal)
                    .onChange(of: letAppSuggestProtein) { _, on in
                        if on {
                            state.proteinPerKgOverride = nil
                            proteinPerKgText = ""
                        }
                    }

                    if !letAppSuggestProtein {
                        HStack {
                            TextField("e.g. 1.8", text: $proteinPerKgText)
                                .keyboardType(.decimalPad)
                                .padding(12)
                                .background(PepTheme.elevated.opacity(0.6))
                                .clipShape(.rect(cornerRadius: 10))
                                .foregroundStyle(PepTheme.textPrimary)
                                .onChange(of: proteinPerKgText) { _, _ in
                                    state.proteinPerKgOverride = Double(proteinPerKgText.replacingOccurrences(of: ",", with: "."))
                                }
                            Text("g/kg")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(PepTheme.textSecondary)
                                .frame(width: 50, alignment: .leading)
                        }
                    } else {
                        Text(suggestedProteinCopy)
                            .font(.footnote)
                            .foregroundStyle(PepTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            FieldCard(title: "Allergies", icon: "exclamationmark.shield") {
                VStack(spacing: 10) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                        ForEach(commonAllergies, id: \.self) { tag in
                            ChipToggle(label: tag, icon: nil, isOn: state.allergies.contains(tag)) {
                                toggleAllergy(tag)
                            }
                        }
                    }
                    HStack {
                        TextField("Add another", text: $allergyDraft)
                            .padding(10)
                            .background(PepTheme.elevated.opacity(0.6))
                            .clipShape(.rect(cornerRadius: 10))
                            .foregroundStyle(PepTheme.textPrimary)
                        Button {
                            addCustomAllergy(allergyDraft)
                            allergyDraft = ""
                        } label: {
                            Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundStyle(PepTheme.teal)
                        }
                        .buttonStyle(.plain)
                        .disabled(allergyDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }

            FieldCard(title: "Restrictions", icon: "hand.raised") {
                VStack(spacing: 10) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                        ForEach(commonRestrictions, id: \.self) { tag in
                            ChipToggle(label: tag, icon: nil, isOn: state.restrictions.contains(tag)) {
                                toggleRestriction(tag)
                            }
                        }
                    }
                    HStack {
                        TextField("Add another", text: $restrictionDraft)
                            .padding(10)
                            .background(PepTheme.elevated.opacity(0.6))
                            .clipShape(.rect(cornerRadius: 10))
                            .foregroundStyle(PepTheme.textPrimary)
                        Button {
                            addCustomRestriction(restrictionDraft)
                            restrictionDraft = ""
                        } label: {
                            Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundStyle(PepTheme.teal)
                        }
                        .buttonStyle(.plain)
                        .disabled(restrictionDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .onAppear {
            letAppSuggestProtein = state.proteinPerKgOverride == nil
            if let v = state.proteinPerKgOverride {
                proteinPerKgText = String(format: "%.2f", v)
            }
        }
    }

    private var suggestedProteinCopy: String {
        let goalIsMuscle = state.primaryGoal == .muscleGain
        let value = goalIsMuscle ? "2.2 g/kg" : "1.6 g/kg"
        let why = goalIsMuscle
            ? "You're growing — we use 2.2 g/kg of bodyweight to support hypertrophy."
            : "We default to 1.6 g/kg of bodyweight; goals like fat loss or recomp may push this higher."
        return "Suggested: \(value). \(why)"
    }

    private func toggleAllergy(_ tag: String) {
        if state.allergies.contains(tag) { state.allergies.remove(tag) } else { state.allergies.insert(tag) }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func toggleRestriction(_ tag: String) {
        if state.restrictions.contains(tag) { state.restrictions.remove(tag) } else { state.restrictions.insert(tag) }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func addCustomAllergy(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        state.allergies.insert(trimmed)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func addCustomRestriction(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        state.restrictions.insert(trimmed)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - Screen 5: Smart Defaults Review

private struct SmartDefaultsReviewScreen: View {
    @Bindable var state: OnboardingState
    @State private var caloriesText: String = ""
    @State private var proteinText: String = ""
    @State private var carbsText: String = ""
    @State private var fatText: String = ""
    @State private var waterText: String = ""
    @State private var stepsText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HeaderBlock(
                icon: "wand.and.stars",
                title: "Here's what we suggest",
                subtitle: "Based on what you told us — adjust anything that does not feel right."
            )

            summaryCard

            VStack(spacing: 12) {
                NumberRow(title: "Calories", icon: "flame.fill", text: $caloriesText, suffix: "kcal", color: PepTheme.amber) { commit() }
                NumberRow(title: "Protein", icon: "circle.hexagongrid.fill", text: $proteinText, suffix: "g", color: PepTheme.teal) { commit() }
                NumberRow(title: "Carbs", icon: "leaf", text: $carbsText, suffix: "g", color: PepTheme.blue) { commit() }
                NumberRow(title: "Fat", icon: "drop.fill", text: $fatText, suffix: "g", color: PepTheme.violet) { commit() }
                NumberRow(title: "Water", icon: "drop.halffull", text: $waterText, suffix: state.unitSystem == .metric ? "ml" : "fl oz", color: PepTheme.blue) { commitWater() }
                NumberRow(title: "Step floor", icon: "figure.walk", text: $stepsText, suffix: "steps", color: PepTheme.teal) { commitSteps() }
            }
        }
        .onAppear { hydrate() }
    }

    private var summaryCard: some View {
        let goal = state.primaryGoal ?? .longevity
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(goal.accent.opacity(0.18)).frame(width: 44, height: 44)
                Image(systemName: goal.icon).foregroundStyle(goal.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(goal.title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                if let bmr = state.bmrKcal, let tdee = state.tdeeKcal {
                    Text("BMR \(Int(bmr)) • TDEE \(Int(tdee)) kcal")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.cardSurface.opacity(0.7))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14).strokeBorder(PepTheme.glassBorderBottom, lineWidth: 0.5)
        )
    }

    private func hydrate() {
        let defaults = state.goalDefaults
        caloriesText = String(defaults?.calories ?? 0)
        proteinText = String(defaults?.proteinG ?? 0)
        carbsText = String(defaults?.carbsG ?? 0)
        fatText = String(defaults?.fatG ?? 0)
        let waterMl = defaults?.waterMl ?? state.dailyWaterMl ?? 2500
        if state.unitSystem == .metric {
            waterText = String(waterMl)
        } else {
            waterText = String(Int((Double(waterMl) / 29.5735).rounded()))
        }
        stepsText = String(defaults?.stepFloor ?? state.dailyStepFloor ?? 8000)
    }

    private func commit() {
        var current = state.goalDefaults ?? GoalSmartDefaults(calories: 0, proteinG: 0, carbsG: 0, fatG: 0, waterMl: state.dailyWaterMl ?? 2500, stepFloor: state.dailyStepFloor ?? 8000)
        current.calories = Int(caloriesText) ?? current.calories
        current.proteinG = Int(proteinText) ?? current.proteinG
        current.carbsG = Int(carbsText) ?? current.carbsG
        current.fatG = Int(fatText) ?? current.fatG
        state.goalDefaults = current
    }

    private func commitWater() {
        guard let v = Int(waterText) else { return }
        var current = state.goalDefaults ?? GoalSmartDefaults(calories: 0, proteinG: 0, carbsG: 0, fatG: 0, waterMl: 0, stepFloor: state.dailyStepFloor ?? 8000)
        current.waterMl = state.unitSystem == .metric ? v : Int(Double(v) * 29.5735)
        state.goalDefaults = current
        state.dailyWaterMl = current.waterMl
    }

    private func commitSteps() {
        guard let v = Int(stepsText) else { return }
        var current = state.goalDefaults ?? GoalSmartDefaults(calories: 0, proteinG: 0, carbsG: 0, fatG: 0, waterMl: state.dailyWaterMl ?? 2500, stepFloor: 0)
        current.stepFloor = v
        state.goalDefaults = current
        state.dailyStepFloor = v
    }
}

// MARK: - Shared building blocks

private struct HeaderBlock: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle().fill(PepTheme.teal.opacity(0.16)).frame(width: 56, height: 56)
                Image(systemName: icon).font(.system(size: 26)).foregroundStyle(PepTheme.teal)
            }
            Text(title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct FieldCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.teal)
                Text(title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.cardSurface.opacity(0.7))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16).strokeBorder(PepTheme.glassBorderBottom, lineWidth: 0.5)
        )
    }
}

private struct ChipToggle: View {
    let label: String
    let icon: String?
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(label)
                    .font(.system(.footnote, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isOn ? PepTheme.teal : PepTheme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(isOn ? PepTheme.teal.opacity(0.14) : PepTheme.elevated.opacity(0.7))
            .clipShape(.rect(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isOn ? PepTheme.teal.opacity(0.5) : PepTheme.glassBorderBottom, lineWidth: isOn ? 1.0 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SegmentButton: View {
    let label: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(isOn ? .white : PepTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isOn ? PepTheme.teal : PepTheme.elevated.opacity(0.7))
                .clipShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

private struct NumberRow: View {
    let title: String
    let icon: String
    @Binding var text: String
    let suffix: String
    let color: Color
    let onCommit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.18)).frame(width: 36, height: 36)
                Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(color)
            }
            Text(title)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .frame(width: 90, alignment: .leading)
            TextField("", text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .padding(10)
                .background(PepTheme.elevated.opacity(0.6))
                .clipShape(.rect(cornerRadius: 10))
                .foregroundStyle(PepTheme.textPrimary)
                .onSubmit(onCommit)
                .onChange(of: text) { _, _ in onCommit() }
            Text(suffix)
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
                .frame(width: 50, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(PepTheme.cardSurface.opacity(0.7))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14).strokeBorder(PepTheme.glassBorderBottom, lineWidth: 0.5)
        )
    }
}
