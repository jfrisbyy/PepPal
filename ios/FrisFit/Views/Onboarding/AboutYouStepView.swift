import SwiftUI

struct AboutYouStepView: View {
    @Bindable var state: OnboardingState
    let onContinue: () -> Void

    @State private var dobDraft: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var hasSetDOB: Bool = false

    @State private var heightCmDraft: Double = 175
    @State private var heightFeet: Int = 5
    @State private var heightInches: Int = 9

    @State private var weightText: String = ""
    @State private var bodyFatText: String = ""
    @State private var neckText: String = ""
    @State private var waistText: String = ""
    @State private var hipText: String = ""

    @State private var showAdvanced: Bool = false
    @State private var fieldError: String?

    private var minDate: Date { Calendar.current.date(byAdding: .year, value: -110, to: Date()) ?? Date() }
    private var maxDate: Date { Date() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                unitToggleCard
                firstNameCard
                dobCard
                sexCard
                heightCard
                weightCard
                bodyFatCard
                advancedSection
                activityCard

                if let fieldError {
                    Text(fieldError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: 8)

                continueButton
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { hydrateFromState() }
        .onChange(of: state.unitSystem) { _, _ in syncHeightDraftsFromCm() }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle()
                    .fill(PepTheme.teal.opacity(0.16))
                    .frame(width: 56, height: 56)
                Image(systemName: "person.text.rectangle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(PepTheme.teal)
            }
            Text("A bit about you")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text("This stays private. We use it to compute your starting calorie, macro, water, and step targets.")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var unitToggleCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "ruler")
                .font(.subheadline)
                .foregroundStyle(PepTheme.teal)
            Text("Units")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
            Spacer()
            Picker("Units", selection: $state.unitSystem) {
                ForEach(UnitSystem.allCases, id: \.self) { sys in
                    Text(sys.label).tag(sys)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
            .onChange(of: state.unitSystem) { _, newValue in
                UnitSystemStore.save(newValue)
                UISelectionFeedbackGenerator().selectionChanged()
            }
        }
        .padding(14)
        .background(PepTheme.cardSurface.opacity(0.7))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.glassBorderBottom, lineWidth: 0.5)
        )
    }

    private var firstNameCard: some View {
        fieldCard(title: "First name", icon: "person.fill") {
            TextField("Your first name", text: $state.firstName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(true)
                .padding(12)
                .background(PepTheme.elevated.opacity(0.6))
                .clipShape(.rect(cornerRadius: 10))
                .foregroundStyle(PepTheme.textPrimary)
        }
    }

    private var dobCard: some View {
        fieldCard(title: "Date of birth", icon: "calendar") {
            DatePicker("Date of birth", selection: $dobDraft, in: minDate...maxDate, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .onChange(of: dobDraft) { _, newValue in
                    hasSetDOB = true
                    state.dateOfBirth = newValue
                }
        }
    }

    private var sexCard: some View {
        fieldCard(title: "Biological sex", icon: "figure.dress.line.vertical.figure") {
            HStack(spacing: 10) {
                ForEach(BiologicalSex.allCases) { sex in
                    sexButton(sex)
                }
            }
        }
    }

    private var heightCard: some View {
        fieldCard(title: "Height", icon: "ruler.fill") {
            if state.unitSystem == .metric {
                HStack {
                    Slider(value: $heightCmDraft, in: 120...230, step: 1)
                        .tint(PepTheme.teal)
                        .onChange(of: heightCmDraft) { _, v in
                            state.heightCm = v
                        }
                    Text("\(Int(heightCmDraft)) cm")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .frame(width: 64, alignment: .trailing)
                }
            } else {
                HStack(spacing: 12) {
                    pickerColumn(title: "ft", value: $heightFeet, range: 3...7)
                    pickerColumn(title: "in", value: $heightInches, range: 0...11)
                }
                .onChange(of: heightFeet) { _, _ in syncCmFromImperial() }
                .onChange(of: heightInches) { _, _ in syncCmFromImperial() }
            }
        }
    }

    private var weightCard: some View {
        fieldCard(title: "Current weight", icon: "scalemass.fill") {
            HStack {
                TextField(state.unitSystem == .metric ? "e.g. 75" : "e.g. 165", text: $weightText)
                    .keyboardType(.decimalPad)
                    .padding(12)
                    .background(PepTheme.elevated.opacity(0.6))
                    .clipShape(.rect(cornerRadius: 10))
                    .foregroundStyle(PepTheme.textPrimary)
                    .onChange(of: weightText) { _, _ in syncWeightFromText() }
                Text(state.unitSystem.weightUnitLabel)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .frame(width: 36, alignment: .leading)
            }
        }
    }

    private var bodyFatCard: some View {
        fieldCard(title: "Body fat % (optional)", icon: "percent") {
            HStack {
                TextField("e.g. 18", text: $bodyFatText)
                    .keyboardType(.decimalPad)
                    .padding(12)
                    .background(PepTheme.elevated.opacity(0.6))
                    .clipShape(.rect(cornerRadius: 10))
                    .foregroundStyle(PepTheme.textPrimary)
                    .onChange(of: bodyFatText) { _, _ in syncBodyFatFromText() }
                Text("%")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .frame(width: 36, alignment: .leading)
            }
        }
    }

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    showAdvanced.toggle()
                }
                UISelectionFeedbackGenerator().selectionChanged()
            } label: {
                HStack {
                    Image(systemName: "tape.measure")
                        .foregroundStyle(PepTheme.teal)
                    Text("Tape-measure body fat (optional)")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                    Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                        .font(.footnote)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .padding(14)
                .background(PepTheme.cardSurface.opacity(0.7))
                .clipShape(.rect(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(PepTheme.glassBorderBottom, lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)

            if showAdvanced {
                VStack(spacing: 10) {
                    Text("US Navy method. Fill all three for an estimate; takes precedence over the % above.")
                        .font(.footnote)
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    measurementRow(label: "Neck", text: $neckText, sample: state.unitSystem == .metric ? "38" : "15")
                    measurementRow(label: "Waist", text: $waistText, sample: state.unitSystem == .metric ? "82" : "32")
                    if state.biologicalSex == .female {
                        measurementRow(label: "Hip", text: $hipText, sample: state.unitSystem == .metric ? "95" : "37")
                    }

                    if let bf = state.bodyFatPercent, !bodyFatText.isEmpty == false || derivedNavyBF() != nil {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(PepTheme.teal)
                            Text("Estimated body fat: \(String(format: "%.1f", bf))%")
                                .font(.system(.footnote, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(14)
                .background(PepTheme.cardSurface.opacity(0.5))
                .clipShape(.rect(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(PepTheme.glassBorderBottom, lineWidth: 0.5)
                )
                .onChange(of: neckText) { _, _ in syncNavyBodyFat() }
                .onChange(of: waistText) { _, _ in syncNavyBodyFat() }
                .onChange(of: hipText) { _, _ in syncNavyBodyFat() }
            }
        }
    }

    private var activityCard: some View {
        fieldCard(title: "Activity baseline", icon: "figure.walk.motion") {
            VStack(spacing: 8) {
                ForEach(onboardingActivityOptions, id: \.0) { item in
                    activityButton(level: item.0, title: item.1, detail: item.2)
                }
            }
        }
    }

    private var continueButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            if !hasSetDOB { state.dateOfBirth = dobDraft }
            commitAndAdvance()
        } label: {
            Text("Continue")
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(state.canAdvance(from: .aboutYou) ? PepTheme.teal : PepTheme.elevated)
                .clipShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(!state.canAdvance(from: .aboutYou))
        .animation(.easeInOut(duration: 0.2), value: state.canAdvance(from: .aboutYou))
    }

    // MARK: - Helpers

    private var onboardingActivityOptions: [(ActivityLevel, String, String)] {
        [
            (.sedentary, "Sedentary", "Desk job, little to no exercise"),
            (.light, "Lightly active", "Light walks or 1–3 workouts per week"),
            (.moderate, "Active", "4–5 workouts per week, mostly on your feet"),
            (.active, "Very active", "Daily training or physically demanding job")
        ]
    }

    private func activityButton(level: ActivityLevel, title: String, detail: String) -> some View {
        let isSelected = state.activityLevel == level
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                state.activityLevel = level
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? PepTheme.teal : PepTheme.textSecondary.opacity(0.5))
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(PepTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? PepTheme.teal.opacity(0.14) : PepTheme.elevated.opacity(0.6))
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? PepTheme.teal.opacity(0.5) : PepTheme.glassBorderBottom, lineWidth: isSelected ? 1.2 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func sexButton(_ sex: BiologicalSex) -> some View {
        let isSelected = state.biologicalSex == sex
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                state.biologicalSex = sex
            }
            UISelectionFeedbackGenerator().selectionChanged()
            syncNavyBodyFat()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? PepTheme.teal : PepTheme.textSecondary.opacity(0.5))
                    .contentTransition(.symbolEffect(.replace))
                Text(sex.displayName)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? PepTheme.teal.opacity(0.14) : PepTheme.elevated.opacity(0.6))
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? PepTheme.teal.opacity(0.5) : PepTheme.glassBorderBottom, lineWidth: isSelected ? 1.2 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func fieldCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
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
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.glassBorderBottom, lineWidth: 0.5)
        )
    }

    private func pickerColumn(title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
            Picker(title, selection: value) {
                ForEach(range, id: \.self) { v in
                    Text("\(v)").tag(v)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)
            .clipped()
        }
        .frame(maxWidth: .infinity)
        .background(PepTheme.elevated.opacity(0.4))
        .clipShape(.rect(cornerRadius: 10))
    }

    private func measurementRow(label: String, text: Binding<String>, sample: String) -> some View {
        HStack {
            Text(label)
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(PepTheme.textPrimary)
                .frame(width: 56, alignment: .leading)
            TextField("e.g. \(sample)", text: text)
                .keyboardType(.decimalPad)
                .padding(10)
                .background(PepTheme.elevated.opacity(0.6))
                .clipShape(.rect(cornerRadius: 8))
                .foregroundStyle(PepTheme.textPrimary)
            Text(state.unitSystem.lengthUnitLabel)
                .font(.footnote)
                .foregroundStyle(PepTheme.textSecondary)
                .frame(width: 28, alignment: .leading)
        }
    }

    // MARK: - Sync / parsing

    private func hydrateFromState() {
        if let existing = state.dateOfBirth {
            dobDraft = existing
            hasSetDOB = true
        }
        if state.heightCm == nil { state.heightCm = heightCmDraft } else {
            heightCmDraft = state.heightCm ?? 175
        }
        let fi = UnitConversion.cmToFeetInches(heightCmDraft)
        heightFeet = fi.feet
        heightInches = fi.inches

        if let kg = state.weightKg {
            let display = state.unitSystem == .metric ? kg : UnitConversion.kgToPounds(kg)
            weightText = String(format: "%.1f", display)
        }
        if let bf = state.bodyFatPercent {
            bodyFatText = String(format: "%.1f", bf)
        }
    }

    private func syncHeightDraftsFromCm() {
        if state.unitSystem == .imperial {
            let fi = UnitConversion.cmToFeetInches(heightCmDraft)
            heightFeet = fi.feet
            heightInches = fi.inches
        }
        // Reformat weight display
        if let kg = state.weightKg {
            let display = state.unitSystem == .metric ? kg : UnitConversion.kgToPounds(kg)
            weightText = String(format: "%.1f", display)
        }
    }

    private func syncCmFromImperial() {
        let cm = UnitConversion.feetInchesToCm(feet: heightFeet, inches: heightInches)
        heightCmDraft = cm
        state.heightCm = cm
    }

    private func syncWeightFromText() {
        let cleaned = weightText.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), value > 0 else {
            state.weightKg = nil
            return
        }
        let kg = state.unitSystem == .metric ? value : UnitConversion.poundsToKg(value)
        state.weightKg = kg
    }

    private func syncBodyFatFromText() {
        let cleaned = bodyFatText.replacingOccurrences(of: ",", with: ".")
        if let value = Double(cleaned), value > 0 {
            state.bodyFatPercent = value
        } else if bodyFatText.isEmpty {
            state.bodyFatPercent = nil
        }
    }

    private func parsedLengthCm(_ text: String) -> Double? {
        let cleaned = text.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), value > 0 else { return nil }
        return state.unitSystem == .metric ? value : UnitConversion.inchesToCm(value)
    }

    private func derivedNavyBF() -> Double? {
        guard let sex = state.biologicalSex,
              let h = state.heightCm,
              let neck = parsedLengthCm(neckText),
              let waist = parsedLengthCm(waistText) else { return nil }
        let hip = parsedLengthCm(hipText)
        return BodyComposition.usNavyBodyFat(
            sex: sex,
            heightCm: h,
            neckCm: neck,
            waistCm: waist,
            hipCm: hip
        )
    }

    private func syncNavyBodyFat() {
        state.neckCm = parsedLengthCm(neckText)
        state.waistCm = parsedLengthCm(waistText)
        state.hipCm = parsedLengthCm(hipText)
        if let bf = derivedNavyBF() {
            state.bodyFatPercent = bf
            bodyFatText = String(format: "%.1f", bf)
        }
    }

    // MARK: - Validation + commit

    private func validate() -> String? {
        let trimmedName = state.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty { return "Please enter your first name." }
        if state.dateOfBirth == nil { return "Please pick your date of birth." }
        if state.biologicalSex == nil { return "Please choose your biological sex." }
        guard let h = state.heightCm, (120.0...230.0).contains(h) else {
            return "Height must be between 120–230 cm (3'11\"–7'7\")."
        }
        guard let w = state.weightKg, (30.0...250.0).contains(w) else {
            return "Weight must be between 30–250 kg (66–551 lb)."
        }
        if let bf = state.bodyFatPercent, !(3.0...60.0).contains(bf) {
            return "Body fat must be between 3–60%."
        }
        if state.activityLevel == nil { return "Please pick your activity baseline." }
        return nil
    }

    private func commitAndAdvance() {
        if let err = validate() {
            withAnimation { fieldError = err }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        fieldError = nil
        computeDerivedTargets()
        onContinue()
    }

    private func computeDerivedTargets() {
        guard let dob = state.dateOfBirth,
              let sex = state.biologicalSex,
              let h = state.heightCm,
              let w = state.weightKg,
              let activity = state.activityLevel else { return }

        let age = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0
        guard age > 0 else { return }

        let bmr: Double
        if let bf = state.bodyFatPercent, (3.0...60.0).contains(bf) {
            bmr = BodyComposition.katchMcArdleBMR(weightKg: w, bodyFatPercent: bf)
        } else {
            bmr = BMRCalculator.calculate(weightKg: w, heightCm: h, age: age, sex: sex)
        }
        let tdee = bmr * activity.multiplier

        state.bmrKcal = bmr
        state.tdeeKcal = tdee

        let macros = AdaptiveMacroService.compute(MacroGoalInputs(
            weightKg: w,
            heightCm: h,
            ageYears: age,
            biologicalSex: sex.rawValue,
            activity: activity,
            goal: .maintain
        ))
        state.starterMacros = macros
        state.dailyWaterMl = BodyComposition.dailyWaterMl(weightKg: w, activity: activity)
        state.dailyStepFloor = BodyComposition.dailyStepFloor(activity: activity)
    }
}
