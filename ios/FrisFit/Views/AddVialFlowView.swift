import SwiftUI

// MARK: - Entry-level state

private enum AddVialEntry: Equatable {
    case chooser
    case vial
    case discover
}

private enum VialSizeUnit: String, CaseIterable, Identifiable {
    case mg, mcg, iu = "IU"
    var id: String { rawValue }
    var label: String { rawValue }
}

private enum AddVialField: Hashable {
    case compoundQuery
    case vialSize
    case bacWater
    case startingDose
}

private enum ReminderFrequency: String, CaseIterable, Identifiable {
    case daily = "Daily"
    case twiceDaily = "Twice daily"
    case everyOther = "Every other day"
    case twiceWeekly = "2× weekly"
    case weekly = "Weekly"
    case asNeeded = "As needed"

    var id: String { rawValue }

    var protocolFrequency: String {
        switch self {
        case .daily: return "Daily"
        case .twiceDaily: return "2x daily"
        case .everyOther: return "Every other day"
        case .twiceWeekly: return "2x weekly"
        case .weekly: return "1x weekly"
        case .asNeeded: return "As needed"
        }
    }

    /// Approximate doses per week for vial-duration math.
    var dosesPerWeek: Double {
        switch self {
        case .daily: return 7
        case .twiceDaily: return 14
        case .everyOther: return 3.5
        case .twiceWeekly: return 2
        case .weekly: return 1
        case .asNeeded: return 1.5
        }
    }
}

private enum DoseStrategy: String, CaseIterable, Identifiable {
    case maintain = "Maintain"
    case titrateUp = "Titrate up"
    case titrateDown = "Titrate down"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .maintain: return "equal"
        case .titrateUp: return "arrow.up.right"
        case .titrateDown: return "arrow.down.right"
        }
    }

    var blurb: String {
        switch self {
        case .maintain: return "Hold a steady dose week to week."
        case .titrateUp: return "Step the dose up gradually."
        case .titrateDown: return "Taper the dose down gradually."
        }
    }
}

// MARK: - Discover seed data

private struct DiscoverGoal: Identifiable {
    let id: String
    let title: String
    let icon: String
    let color: Color
    let blurb: String
    let categories: [PeptideCategory]
    let suggestedNames: [String]
}

private let discoverGoals: [DiscoverGoal] = [
    DiscoverGoal(
        id: "weightLoss",
        title: "Weight loss",
        icon: "scalemass.fill",
        color: .green,
        blurb: "GLP-1s and metabolic peptides for appetite, fat loss, and body composition.",
        categories: [.weightLoss],
        suggestedNames: ["Semaglutide", "Tirzepatide", "Retatrutide", "Tesamorelin", "Cagrilintide", "AOD-9604"]
    ),
    DiscoverGoal(
        id: "muscle",
        title: "Muscle & GH",
        icon: "figure.strengthtraining.traditional",
        color: PepTheme.teal,
        blurb: "Growth hormone secretagogues and lean-mass support.",
        categories: [.muscleGrowth, .igfVariants],
        suggestedNames: ["Ipamorelin", "CJC-1295 (No DAC)", "CJC-1295 (With DAC)", "Sermorelin", "MK-677", "Tesamorelin"]
    ),
    DiscoverGoal(
        id: "healing",
        title: "Healing & recovery",
        icon: "cross.case.fill",
        color: PepTheme.blue,
        blurb: "Repair, recovery and inflammation support — joints, gut, soft tissue.",
        categories: [.healing],
        suggestedNames: ["BPC-157", "TB-500", "GHK-Cu", "KPV", "Thymosin Alpha-1", "LL-37"]
    ),
    DiscoverGoal(
        id: "cognitive",
        title: "Cognitive",
        icon: "brain.head.profile",
        color: PepTheme.violet,
        blurb: "Focus, neuroprotection and mood support.",
        categories: [.cognitive],
        suggestedNames: ["Semax", "Selank", "Cerebrolysin", "Dihexa", "Cortagen"]
    ),
    DiscoverGoal(
        id: "skin",
        title: "Skin & tanning",
        icon: "sun.max.fill",
        color: .orange,
        blurb: "Cosmetic peptides for tanning, skin and hair.",
        categories: [.tanning, .antiAging],
        suggestedNames: ["Melanotan II", "Melanotan I", "GHK-Cu", "Epitalon"]
    ),
    DiscoverGoal(
        id: "wellness",
        title: "General wellness",
        icon: "leaf.fill",
        color: PepTheme.amber,
        blurb: "Anti-aging, longevity and broad-spectrum support peptides.",
        categories: [.antiAging, .niche],
        suggestedNames: ["Epitalon", "Thymalin", "MOTS-c", "Humanin", "SS-31"]
    )
]

// MARK: - Main view

struct AddVialFlowView: View {
    @Environment(\.dismiss) private var dismiss

    let initialCompound: String?
    let onComplete: (PeptideProtocol) -> Void

    init(initialCompound: String? = nil, onComplete: @escaping (PeptideProtocol) -> Void) {
        self.initialCompound = initialCompound
        self.onComplete = onComplete
    }

    @State private var entry: AddVialEntry = .chooser

    // Vial flow
    @State private var compoundQuery: String = ""
    @State private var pickedCompound: String?
    @State private var vialSizeText: String = ""
    @State private var vialSizeUnit: VialSizeUnit = .mg
    @State private var bacWaterMl: String = ""
    @State private var chosenSuggestedMl: Double? = nil
    @State private var commonMlOptions: [Double] = [1, 2, 3, 5]

    // Starting dose & strategy
    @State private var startingDoseText: String = ""
    @State private var startingDoseUnit: VialSizeUnit = .mcg
    @State private var strategy: DoseStrategy? = nil
    @State private var titrationSteps: [TitrationScheduleStep] = []
    @State private var titrationLoading: Bool = false
    @State private var titrationError: String? = nil
    @State private var aiNote: String = ""

    @State private var frequency: ReminderFrequency = .daily
    @State private var reminderTime: Date = AddVialFlowView.defaultMorningTime()

    // Discover flow
    @State private var pickedGoal: DiscoverGoal?

    @State private var frequencyManuallySet: Bool = false
    @State private var startingDoseManuallySet: Bool = false
    @State private var showBacDetails: Bool = false
    @State private var pickedSyringeManual: SyringeSpec? = nil
    @FocusState private var focusedField: AddVialField?

    static func defaultMorningTime() -> Date {
        let cal = Calendar.current
        return cal.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    }

    // MARK: - Derived

    private var compoundProfile: CompoundProfile? {
        guard let pickedCompound else { return nil }
        return CompoundDatabase.all.first { $0.name == pickedCompound }
    }

    private var protocolDefault: ProtocolDefault? {
        guard let pickedCompound else { return nil }
        return ProtocolDefaultsDatabase.defaults(for: pickedCompound)
    }

    private var needsReconstitution: Bool {
        let route = (protocolDefault?.route ?? compoundProfile?.keyFacts.administrationRoute ?? "Subcutaneous").lowercased()
        if route.contains("oral") || route.contains("nasal") || route.contains("topical") {
            return false
        }
        return true
    }

    private var vialSizeMg: Double? {
        guard let v = Double(vialSizeText.replacingOccurrences(of: ",", with: ".")), v > 0 else { return nil }
        switch vialSizeUnit {
        case .mg: return v
        case .mcg: return v / 1000.0
        case .iu: return v
        }
    }

    /// User-entered BAC water volume. Required before any unit/dose math is shown.
    private var reconstitutedMl: Double? {
        if !needsReconstitution { return nil }
        if let n = Double(bacWaterMl.replacingOccurrences(of: ",", with: ".")), n > 0 {
            return n
        }
        return nil
    }

    private var concentrationMcgPerMl: Double? {
        guard let mg = vialSizeMg, let ml = reconstitutedMl, ml > 0 else { return nil }
        return mg * 1000 / ml
    }

    /// Starting dose in mcg, parsed from the user's input.
    private var startingDoseMcg: Double? {
        guard let v = Double(startingDoseText.replacingOccurrences(of: ",", with: ".")), v > 0 else { return nil }
        switch startingDoseUnit {
        case .mg: return v * 1000
        case .mcg: return v
        case .iu: return v
        }
    }

    /// Default starting dose for the picked compound (in mcg) when nothing's typed yet.
    private var defaultStartingDoseMcg: Double {
        if let pd = protocolDefault {
            let val = pd.beginner.low
            return pd.beginner.unit == "mg" ? val * 1000 : val
        }
        return 250
    }

    /// Suggested BAC water volume that gives clean whole-unit dosing on a U-100 0.5 mL syringe.
    private var suggestedReconMl: Double {
        guard let mg = vialSizeMg, mg > 0 else { return 2 }
        let totalMcg = mg * 1000
        let candidates: [Double] = [1, 2, 3, 5]
        let dose = max(startingDoseMcg ?? defaultStartingDoseMcg, 1)
        let scored = candidates.map { ml -> (Double, Double) in
            let concentration = totalMcg / ml
            let drawMl = dose / concentration
            let drawUnits = drawMl * 100
            let inRange = drawUnits >= 8 && drawUnits <= 60 ? 0.0 : 4.0
            let snap = abs(drawUnits - (drawUnits / 5).rounded() * 5)
            return (ml, inRange + snap)
        }
        return scored.min { $0.1 < $1.1 }?.0 ?? 2
    }

    private var recommendedSyringe: SyringeSpec {
        guard let conc = concentrationMcgPerMl, let dose = startingDoseMcg ?? Optional(defaultStartingDoseMcg) else { return .u100_05 }
        let drawMl = dose / conc
        if drawMl > 0.5 { return .u100_10 }
        if drawMl > 0.3 { return .u100_05 }
        return .u100_03
    }

    private var pickedSyringe: SyringeSpec {
        pickedSyringeManual ?? recommendedSyringe
    }

    private var unitsPerDose: Double? {
        guard let conc = concentrationMcgPerMl, let dose = startingDoseMcg else { return nil }
        return (dose / conc) * pickedSyringe.unitsPerMl
    }

    /// Walks the titration plan (or starting dose if no plan) at the picked frequency,
    /// respecting the vial's actual mcg capacity. Returns the real number of doses and
    /// weeks the vial can deliver.
    private var vialUsage: (doses: Int, weeks: Double)? {
        guard let mg = vialSizeMg, mg > 0 else { return nil }
        let totalMcg = mg * 1000.0
        let dpw = max(frequency.dosesPerWeek, 0.01)
        var remaining = totalMcg
        var doses = 0

        let steps = titrationSteps
            .sorted { $0.week < $1.week }
            .filter { $0.doseMcg > 0 }

        if steps.isEmpty {
            guard let dose = startingDoseMcg, dose > 0 else { return nil }
            let count = Int(floor(remaining / dose))
            return (count, Double(count) / dpw)
        }

        for (i, step) in steps.enumerated() {
            let isLast = i + 1 >= steps.count
            let plannedDoses: Double
            if isLast {
                plannedDoses = .greatestFiniteMagnitude
            } else {
                let weekSpan = max(steps[i + 1].week - step.week, 0)
                plannedDoses = Double(weekSpan) * dpw
            }
            let canAfford = floor(remaining / step.doseMcg)
            if canAfford <= 0 { break }
            let take = min(plannedDoses, canAfford)
            // floor for whole doses, but allow last step to keep fractional weeks aligned
            let wholeTake = Int(take.rounded(.down))
            if wholeTake <= 0 { break }
            doses += wholeTake
            remaining -= Double(wholeTake) * step.doseMcg
            if Double(wholeTake) < plannedDoses { break }
        }
        return (doses, Double(doses) / dpw)
    }

    private var dosesPerVial: Int? { vialUsage?.doses }
    private var weeksPerVial: Double? { vialUsage?.weeks }

    /// Max weeks the vial can support if user stays at the starting dose at the chosen frequency.
    /// Used to constrain the AI titration plan length.
    private var weeksBudgetAtStartingDose: Double? {
        guard let mg = vialSizeMg, let dose = startingDoseMcg, dose > 0 else { return nil }
        let totalDoses = floor((mg * 1000) / dose)
        return totalDoses / max(frequency.dosesPerWeek, 0.01)
    }

    private var canContinue: Bool {
        guard pickedCompound != nil, vialSizeMg != nil else { return false }
        if needsReconstitution && reconstitutedMl == nil { return false }
        if startingDoseMcg == nil { return false }
        return true
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    switch entry {
                    case .chooser:
                        chooserView
                    case .vial:
                        vialFlowView
                    case .discover:
                        discoverFlowView
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 140)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: entry)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: pickedCompound)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: vialSizeMg != nil)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: reconstitutedMl != nil)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: startingDoseMcg != nil)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: strategy)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: pickedGoal?.id)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .appBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(entry == .chooser ? "Cancel" : "Back") {
                        if entry == .chooser {
                            dismiss()
                        } else {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                entry = .chooser
                                resetVialFlow()
                                pickedGoal = nil
                            }
                        }
                    }
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundStyle(PepTheme.textSecondary)
                }
                ToolbarItem(placement: .principal) {
                    Text(navTitle)
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        dismissKeyboard()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                            Text("Done")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(PepTheme.teal)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if entry == .vial {
                    saveBar
                }
            }
            .onAppear {
                if let initial = initialCompound, !initial.isEmpty, pickedCompound == nil {
                    pickedCompound = initial
                    compoundQuery = initial
                    entry = .vial
                    syncDefaultsForCompound()
                }
            }
        }
    }

    private var navTitle: String {
        switch entry {
        case .chooser: return "Inventory"
        case .vial: return "Add a Vial"
        case .discover: return pickedGoal == nil ? "Discover" : (pickedGoal?.title ?? "Discover")
        }
    }

    // MARK: - Editorial header

    private func editorialHeader(eyebrow: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow)
                .font(.system(size: 11, weight: .semibold))
                .tracking(2.5)
                .textCase(.uppercase)
                .foregroundStyle(PepTheme.teal)
            Text(title)
                .font(.system(size: 32, weight: .semibold, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.system(size: 15, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(height: 1)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Chooser

    private var chooserView: some View {
        VStack(alignment: .leading, spacing: 24) {
            editorialHeader(
                eyebrow: "Vol. I — Setup",
                title: "Build your protocol with intention.",
                subtitle: "Whether the vial is on your counter or still on your wishlist, we'll meet you there."
            )

            VStack(spacing: 14) {
                chooserCard(
                    title: "Add a vial",
                    subtitle: "I have a peptide in hand and want to set it up.",
                    icon: "testtube.2",
                    color: PepTheme.teal
                ) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        entry = .vial
                    }
                }

                chooserCard(
                    title: "I don't have one yet",
                    subtitle: "Help me find what fits my goals.",
                    icon: "sparkle.magnifyingglass",
                    color: PepTheme.violet
                ) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        entry = .discover
                    }
                }
            }
        }
    }

    private func chooserCard(title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(color.opacity(0.14))
                        .frame(width: 56, height: 56)
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 19, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 13, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PepTheme.cardSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(color.opacity(0.18), lineWidth: 1)
            )
            .clipShape(.rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .medium), trigger: entry)
    }

    // MARK: - Vial flow

    private var vialFlowView: some View {
        VStack(spacing: 22) {
            editorialHeader(
                eyebrow: "Chapter \(currentChapter) of 4",
                title: vialHeaderTitle,
                subtitle: vialHeaderSubtitle
            )

            stepCompoundCard
            if pickedCompound != nil {
                stepVialSizeCard
            }
            if vialSizeMg != nil && needsReconstitution {
                stepReconCard
            }
            if vialSizeMg != nil && (reconstitutedMl != nil || !needsReconstitution) {
                stepStartingDoseCard
            }
            if startingDoseMcg != nil && reconstitutedMl != nil {
                doseCalculatorCard
            }
            if startingDoseMcg != nil {
                stepFrequencyCard
                strategyCard
                if strategy != nil && (strategy != .maintain || !titrationSteps.isEmpty) {
                    titrationCard
                }
                vialDurationCard
            }
        }
    }

    private var currentChapter: Int {
        if startingDoseMcg != nil { return 4 }
        if reconstitutedMl != nil || (!needsReconstitution && vialSizeMg != nil) { return 3 }
        if vialSizeMg != nil { return 2 }
        return 1
    }

    private var vialHeaderTitle: String {
        switch currentChapter {
        case 1: return "Tell us what's in the vial."
        case 2: return needsReconstitution ? "How will you reconstitute?" : "How often will you take it?"
        case 3: return "Pick your starting dose."
        default: return "Confirm your schedule."
        }
    }

    private var vialHeaderSubtitle: String {
        switch currentChapter {
        case 1: return "We'll source recommendations from there."
        case 2: return needsReconstitution ? "BAC water volume drives every dose calculation that follows." : "We'll set up reminders that fit your week."
        case 3: return "We'll suggest a titration plan you can edit in line."
        default: return "Last review before we hand it back to you."
        }
    }

    // Step 1 — peptide name
    private var stepCompoundCard: some View {
        FlowCard(stepNumber: 1, title: "Peptide", subtitle: "Type to search the compound database") {
            VStack(alignment: .leading, spacing: 12) {
                if let picked = pickedCompound {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(PepTheme.teal)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(picked)
                                .font(.system(size: 19, weight: .semibold, design: .serif))
                                .foregroundStyle(PepTheme.textPrimary)
                            if let route = protocolDefault?.route ?? compoundProfile?.keyFacts.administrationRoute {
                                Text(route)
                                    .font(.system(size: 12, design: .serif))
                                    .italic()
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                        }
                        Spacer()
                        Button("Change") {
                            withAnimation { clearCompound() }
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PepTheme.teal)
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(PepTheme.textSecondary)
                        TextField("e.g. BPC-157, Semaglutide…", text: $compoundQuery)
                            .font(.system(size: 16, design: .serif))
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .focused($focusedField, equals: .compoundQuery)
                    }
                    .padding(14)
                    .background(PepTheme.elevated.opacity(0.6))
                    .clipShape(.rect(cornerRadius: 12))

                    if !filteredCompounds.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(filteredCompounds, id: \.id) { profile in
                                Button {
                                    pickCompound(profile.name)
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: profile.iconName.isEmpty ? "pill.fill" : profile.iconName)
                                            .foregroundStyle(PepTheme.teal)
                                            .frame(width: 24)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(profile.name)
                                                .font(.system(size: 15, weight: .semibold, design: .serif))
                                                .foregroundStyle(PepTheme.textPrimary)
                                            Text(profile.peptideType)
                                                .font(.caption2)
                                                .foregroundStyle(PepTheme.textSecondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 12)
                                    .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                                if profile.id != filteredCompounds.last?.id {
                                    Divider().background(PepTheme.separatorColor)
                                }
                            }
                        }
                        .background(PepTheme.elevated.opacity(0.4))
                        .clipShape(.rect(cornerRadius: 12))
                    }
                }
            }
        }
    }

    private var filteredCompounds: [CompoundProfile] {
        let q = compoundQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        return Array(
            CompoundDatabase.all
                .filter { $0.name.localizedCaseInsensitiveContains(q) }
                .prefix(6)
        )
    }

    // Step 2 — vial size
    private var stepVialSizeCard: some View {
        FlowCard(stepNumber: 2, title: "Vial size", subtitle: "How much peptide is in the vial?") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    TextField("e.g. 5", text: $vialSizeText)
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .vialSize)
                        .padding(14)
                        .background(PepTheme.elevated.opacity(0.6))
                        .clipShape(.rect(cornerRadius: 12))
                        .frame(maxWidth: .infinity)

                    Picker("Unit", selection: $vialSizeUnit) {
                        ForEach(VialSizeUnit.allCases) { u in
                            Text(u.label).tag(u)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }

                if let suggestion = suggestedSizeText {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(PepTheme.amber)
                        Text(suggestion)
                            .font(.system(size: 12, design: .serif))
                            .italic()
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
            }
        }
    }

    private var suggestedSizeText: String? {
        if let typical = compoundProfile?.reconstitutionGuide.typicalVialSize, typical != "—" {
            return "Common vial: \(typical)"
        }
        return nil
    }

    // Step 3 — reconstitution
    private var stepReconCard: some View {
        FlowCard(stepNumber: 3, title: "Reconstitution", subtitle: "How much BAC water are you adding?") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(PepTheme.blue)
                    TextField("e.g. 2", text: $bacWaterMl)
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .bacWater)
                    Text("mL")
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .padding(14)
                .background(PepTheme.elevated.opacity(0.6))
                .clipShape(.rect(cornerRadius: 12))

                Text("Pick a quick suggestion")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(PepTheme.textSecondary)

                HStack(spacing: 8) {
                    ForEach(commonMlOptions, id: \.self) { ml in
                        Button {
                            bacWaterMl = formatVialNumber(ml)
                            chosenSuggestedMl = ml
                            focusedField = nil
                        } label: {
                            VStack(spacing: 2) {
                                Text(formatMl(ml))
                                    .font(.system(size: 13, weight: .semibold, design: .serif))
                                    .foregroundStyle(isMlSelected(ml) ? PepTheme.invertedText : PepTheme.textPrimary)
                                if ml == suggestedReconMl {
                                    Text("recommended")
                                        .font(.system(size: 8, weight: .bold))
                                        .tracking(0.5)
                                        .foregroundStyle(isMlSelected(ml) ? PepTheme.invertedText.opacity(0.85) : PepTheme.teal)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isMlSelected(ml) ? PepTheme.teal : PepTheme.elevated.opacity(0.6))
                            .clipShape(.rect(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }

                bacExplanationBlock

                if reconstitutedMl == nil {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(PepTheme.amber)
                        Text("Your dose calculator unlocks the moment we know your BAC volume.")
                            .font(.system(size: 12, design: .serif))
                            .italic()
                            .foregroundStyle(PepTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // BAC water explanation — brief reasoning + expandable implications
    private var bacExplanationBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PepTheme.teal)
                    .padding(.top, 2)
                Text(bacBriefReason)
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showBacDetails.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Text(showBacDetails ? "Hide details" : "What if I use a different volume?")
                        .font(.system(size: 12, weight: .semibold, design: .serif))
                    Image(systemName: showBacDetails ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(PepTheme.teal)
            }
            .buttonStyle(.plain)

            if showBacDetails {
                VStack(alignment: .leading, spacing: 8) {
                    bacImplicationRow(
                        title: "Less water (more concentrated)",
                        body: bacLessText,
                        icon: "arrow.down.right.circle.fill",
                        color: PepTheme.amber
                    )
                    bacImplicationRow(
                        title: "More water (more diluted)",
                        body: bacMoreText,
                        icon: "arrow.up.right.circle.fill",
                        color: PepTheme.blue
                    )
                    Text("All three options deliver the same medicine — only the volume per unit on the syringe changes.")
                        .font(.system(size: 11, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary)
                        .padding(.top, 2)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PepTheme.elevated.opacity(0.5))
                .clipShape(.rect(cornerRadius: 10))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func bacImplicationRow(title: String, body: String, icon: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: 14, weight: .semibold))
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(body)
                    .font(.system(size: 12, design: .serif))
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var bacBriefReason: String {
        let suggested = suggestedReconMl
        guard let mg = vialSizeMg, mg > 0 else {
            return "We pick a BAC volume that lands your dose on a clean, easy-to-read mark on a U-100 syringe."
        }
        let dose = startingDoseMcg ?? defaultStartingDoseMcg
        let conc = (mg * 1000) / suggested
        let drawUnits = (dose / conc) * 100
        return "At \(formatMl(suggested)), each dose draws to roughly \(formatUnits(drawUnits)) units on a U-100 syringe — easy to read and hard to mis-measure."
    }

    private var bacLessText: String {
        guard let mg = vialSizeMg, mg > 0 else {
            return "More peptide per mL means a tiny draw — small movements of the plunger can change your dose noticeably."
        }
        let lessMl = max(suggestedReconMl - 1, 0.5)
        let dose = startingDoseMcg ?? defaultStartingDoseMcg
        let drawUnits = (dose / ((mg * 1000) / lessMl)) * 100
        return "At \(formatMl(lessMl)), the same dose would draw to ~\(formatUnits(drawUnits)) units. Smaller draws are easier to over- or under-dose by a tick."
    }

    private var bacMoreText: String {
        guard let mg = vialSizeMg, mg > 0 else {
            return "More water means a larger draw, which is easier to read but may exceed the capacity of a 0.5 mL syringe."
        }
        let moreMl = suggestedReconMl + 1
        let dose = startingDoseMcg ?? defaultStartingDoseMcg
        let drawUnits = (dose / ((mg * 1000) / moreMl)) * 100
        let warn = drawUnits > 50 ? " That may exceed a standard 0.5 mL syringe and require a larger one." : ""
        return "At \(formatMl(moreMl)), the same dose would draw to ~\(formatUnits(drawUnits)) units. Larger draws are forgiving on precision but use more BAC water.\(warn)"
    }

    private func isMlSelected(_ ml: Double) -> Bool {
        guard let entered = Double(bacWaterMl.replacingOccurrences(of: ",", with: ".")) else { return false }
        return abs(entered - ml) < 0.01
    }

    // Step 4 — starting dose
    private var stepStartingDoseCard: some View {
        FlowCard(stepNumber: needsReconstitution ? 4 : 3, title: "Starting dose", subtitle: "What's your first prescribed dose?") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    TextField(defaultDosePlaceholder, text: $startingDoseText)
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .startingDose)
                        .padding(14)
                        .background(PepTheme.elevated.opacity(0.6))
                        .clipShape(.rect(cornerRadius: 12))
                        .frame(maxWidth: .infinity)
                        .onChange(of: startingDoseText) { _, _ in
                            startingDoseManuallySet = true
                        }

                    Picker("Unit", selection: $startingDoseUnit) {
                        ForEach(VialSizeUnit.allCases) { u in
                            Text(u.label).tag(u)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                    .onChange(of: startingDoseUnit) { _, _ in
                        // Titration row display follows starting-dose unit; no data change needed.
                    }
                }

                if let pd = protocolDefault {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(PepTheme.teal)
                        Text("Beginner range: \(pd.beginner.displayString)")
                            .font(.system(size: 12, design: .serif))
                            .italic()
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }

                if let warning = doseWarning {
                    doseWarningCallout(warning)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    // MARK: - Dose warning

    private struct DoseWarning {
        enum Severity { case caution, danger }
        let title: String
        let detail: String
        let severity: Severity
    }

    /// Compares the user's starting dose against the compound's dosing zones,
    /// and surfaces the *specific* side effects for that peptide (pulled from
    /// the discovery database) instead of generic clinical-trial language.
    private var doseWarning: DoseWarning? {
        guard let pd = protocolDefault, let dose = startingDoseMcg else { return nil }
        let isRed = dose >= pd.redZone.low
        let isYellow = !isRed && dose >= pd.yellowZone.low
        guard isRed || isYellow else { return nil }

        let name = pd.compoundName
        let effects = peptideSpecificSideEffects(for: name)
        let effectsText: String = {
            if effects.isEmpty { return "" }
            return " Common side effects of \(name) include \(effects.joined(separator: ", "))."
        }()

        if isRed {
            return DoseWarning(
                title: "Increased risk of side effects at this dose",
                detail: "This dose is well above the typical starting range for \(name) and meaningfully increases the likelihood and severity of side effects.\(effectsText)",
                severity: .danger
            )
        }
        return DoseWarning(
            title: "Higher chance of side effects at this dose",
            detail: "This is above the conservative starting range for \(name) and may increase the chance of side effects.\(effectsText)",
            severity: .caution
        )
    }

    /// Pulls the peptide-specific side effects from the discovery database
    /// (CompoundDatabase). Prefers `detailedSideEffects.common`, falls back to
    /// the flat `sideEffects` list. Returned lowercased for natural sentence flow.
    private func peptideSpecificSideEffects(for compoundName: String) -> [String] {
        guard let profile = CompoundDatabase.all.first(where: { $0.name == compoundName }) else { return [] }
        let common = profile.detailedSideEffects.common
        let source = !common.isEmpty ? common : profile.sideEffects
        return source.prefix(5).map { $0.lowercased() }
    }

    private func doseWarningCallout(_ w: DoseWarning) -> some View {
        let color: Color = w.severity == .danger ? .red : PepTheme.amber
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: w.severity == .danger ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(color)
                .font(.system(size: 14, weight: .semibold))
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(w.title)
                    .font(.system(size: 12, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(w.detail)
                    .font(.system(size: 11, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.35), lineWidth: 0.6)
        )
        .clipShape(.rect(cornerRadius: 10))
    }

    private func dismissKeyboard() {
        focusedField = nil
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }

    private var defaultDosePlaceholder: String {
        formatVialNumber(displayDoseValue(defaultStartingDoseMcg, in: startingDoseUnit))
    }

    // Dose calculator (only when BAC water + dose entered)
    private var doseCalculatorCard: some View {
        FlowCard(stepNumber: nil, iconName: "syringe.fill", title: "Per-dose draw", subtitle: "Where to pull the plunger for each dose") {
            inlineSyringeVisual
        }
    }

    private var inlineSyringeVisual: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let conc = concentrationMcgPerMl, let dose = startingDoseMcg {
                HStack(spacing: 14) {
                    miniStat("DOSE", displayDose(dose))
                    miniStat("DRAW TO", "\(formatUnits(dose / conc * pickedSyringe.unitsPerMl)) u", highlight: true)
                    miniStat("SYRINGE", pickedSyringe.short)
                }
                inlineSyringe(conc: conc, dose: dose)
                Text("Each major tick = \(formatUnits(pickedSyringe.majorTick)) u • minor = \(formatUnits(pickedSyringe.minorTick)) u")
                    .font(.caption2)
                    .foregroundStyle(PepTheme.textSecondary)

                syringePicker
            }
        }
    }

    private var syringePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Needle / syringe")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(PepTheme.textSecondary)

            VStack(spacing: 6) {
                ForEach(SyringeSpec.allCases) { spec in
                    Button {
                        pickedSyringeManual = spec
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: pickedSyringe == spec ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(pickedSyringe == spec ? PepTheme.teal : PepTheme.textTertiary)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(spec.rawValue)
                                        .font(.system(size: 13, weight: .semibold, design: .serif))
                                        .foregroundStyle(PepTheme.textPrimary)
                                    if recommendedSyringe == spec {
                                        Text("most common")
                                            .font(.system(size: 8, weight: .bold))
                                            .tracking(0.5)
                                            .textCase(.uppercase)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(PepTheme.teal.opacity(0.15))
                                            .foregroundStyle(PepTheme.teal)
                                            .clipShape(.capsule)
                                    }
                                }
                                Text(spec.commonLabel)
                                    .font(.system(size: 11, design: .serif))
                                    .italic()
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(pickedSyringe == spec ? PepTheme.teal.opacity(0.08) : PepTheme.elevated.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(pickedSyringe == spec ? PepTheme.teal.opacity(0.4) : PepTheme.separatorColor, lineWidth: 1)
                        )
                        .clipShape(.rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(pickedSyringe.guidanceText)
                .font(.system(size: 11, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func miniStat(_ label: String, _ value: String, highlight: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .heavy))
                .tracking(1)
                .foregroundStyle(PepTheme.textSecondary)
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .serif))
                .foregroundStyle(highlight ? PepTheme.teal : PepTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inlineSyringe(conc: Double, dose: Double) -> some View {
        let drawMl = dose / conc
        let drawUnits = drawMl * pickedSyringe.unitsPerMl
        let frac = min(1.0, max(0.04, drawUnits / pickedSyringe.totalUnits))
        return GeometryReader { geo in
            let width = geo.size.width
            let fillWidth = width * CGFloat(frac)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(PepTheme.elevated)
                    .frame(height: 50)
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(colors: [PepTheme.teal.opacity(0.85), PepTheme.blue.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: fillWidth, height: 50)
                Canvas { ctx, size in
                    let count = Int(pickedSyringe.totalUnits / pickedSyringe.minorTick)
                    for i in 0...count {
                        let unit = Double(i) * pickedSyringe.minorTick
                        let x = CGFloat(unit / pickedSyringe.totalUnits) * size.width
                        let isMajor = unit.truncatingRemainder(dividingBy: pickedSyringe.majorTick) == 0
                        let h: CGFloat = isMajor ? 12 : 6
                        let rect = CGRect(x: x, y: 0, width: 1, height: h)
                        ctx.fill(Path(rect), with: .color(.white.opacity(isMajor ? 0.85 : 0.5)))
                    }
                }
                .frame(height: 50)
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 3, height: 70)
                    .shadow(color: PepTheme.teal.opacity(0.6), radius: 6)
                    .offset(x: fillWidth - 1.5, y: -10)
            }
        }
        .frame(height: 60)
    }

    // Strategy card
    private var strategyCard: some View {
        FlowCard(stepNumber: nil, iconName: "chart.line.uptrend.xyaxis", title: "Dose strategy", subtitle: "How do you want this protocol to evolve?") {
            VStack(spacing: 10) {
                ForEach(DoseStrategy.allCases) { s in
                    let isSelected = strategy == s
                    Button {
                        strategy = s
                        Task { await regenerateTitrationIfNeeded() }
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill((isSelected ? PepTheme.teal : PepTheme.elevated).opacity(isSelected ? 0.18 : 0.6))
                                    .frame(width: 36, height: 36)
                                Image(systemName: s.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(isSelected ? PepTheme.teal : PepTheme.textSecondary)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.rawValue)
                                    .font(.system(size: 15, weight: .semibold, design: .serif))
                                    .foregroundStyle(PepTheme.textPrimary)
                                Text(s.blurb)
                                    .font(.system(size: 12, design: .serif))
                                    .italic()
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isSelected ? PepTheme.teal : PepTheme.textTertiary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(isSelected ? PepTheme.teal.opacity(0.08) : PepTheme.elevated.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? PepTheme.teal.opacity(0.4) : PepTheme.separatorColor, lineWidth: 1)
                        )
                        .clipShape(.rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: strategy)
                }
            }
        }
    }

    // Titration card (AI-generated, inline editable)
    private var titrationCard: some View {
        FlowCard(stepNumber: nil, iconName: "list.number", title: "Titration plan", subtitle: titrationSubtitle) {
            VStack(alignment: .leading, spacing: 12) {
                if titrationLoading {
                    HStack(spacing: 10) {
                        ProgressView().tint(PepTheme.teal)
                        Text("Drafting your schedule…")
                            .font(.system(size: 13, design: .serif))
                            .italic()
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                } else if let err = titrationError {
                    Text(err)
                        .font(.system(size: 12, design: .serif))
                        .foregroundStyle(PepTheme.amber)
                } else if titrationSteps.isEmpty {
                    Button {
                        Task { await regenerateTitrationIfNeeded(force: true) }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                            Text("Suggest a schedule")
                                .font(.system(size: 13, weight: .semibold, design: .serif))
                        }
                        .foregroundStyle(PepTheme.teal)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(PepTheme.teal.opacity(0.12))
                        .clipShape(.rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                } else {
                    if let capacityWeeks = vialUsage?.weeks,
                       let lastWeek = titrationSteps.map(\.week).max(),
                       Double(lastWeek) > capacityWeeks + 0.5 {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(PepTheme.amber)
                                .font(.system(size: 12))
                            Text("Heads up — this vial likely runs out around week \(formatWeeks(capacityWeeks)). You'll need a new vial to reach week \(lastWeek).")
                                .font(.system(size: 11, design: .serif))
                                .italic()
                                .foregroundStyle(PepTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PepTheme.amber.opacity(0.10))
                        .clipShape(.rect(cornerRadius: 8))
                    } else if let extra = extraWeeksAfterLastStep, extra >= 1 {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(PepTheme.teal)
                                .font(.system(size: 12))
                            Text("Vial still has roughly \(formatWeeks(extra)) more weeks at your final dose after week \(titrationSteps.map(\.week).max() ?? 0).")
                                .font(.system(size: 11, design: .serif))
                                .italic()
                                .foregroundStyle(PepTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            Button("Extend") { extendFinalStep() }
                                .font(.system(size: 11, weight: .semibold, design: .serif))
                                .foregroundStyle(PepTheme.teal)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PepTheme.teal.opacity(0.08))
                        .clipShape(.rect(cornerRadius: 8))
                    }

                    ForEach($titrationSteps) { $step in
                        titrationRow(step: $step)
                    }

                    HStack(spacing: 10) {
                        Button {
                            addTitrationStep()
                        } label: {
                            Label("Add step", systemImage: "plus")
                                .font(.system(size: 12, weight: .semibold, design: .serif))
                                .foregroundStyle(PepTheme.teal)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button {
                            Task { await regenerateTitrationIfNeeded(force: true) }
                        } label: {
                            Label("Regenerate", systemImage: "arrow.clockwise")
                                .font(.system(size: 12, weight: .semibold, design: .serif))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }

                    if !aiNote.isEmpty {
                        Text(aiNote)
                            .font(.system(size: 12, design: .serif))
                            .italic()
                            .foregroundStyle(PepTheme.textSecondary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(PepTheme.elevated.opacity(0.5))
                            .clipShape(.rect(cornerRadius: 10))
                    }
                }
            }
        }
    }

    private var titrationSubtitle: String {
        switch strategy {
        case .maintain: return "Steady-state plan — edit any week as needed."
        case .titrateUp: return "Stepping up over time — edit any week as needed."
        case .titrateDown: return "Tapering down over time — edit any week as needed."
        case .none: return "Pick a strategy to see your plan."
        }
    }

    private func titrationRow(step: Binding<TitrationScheduleStep>) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("WEEK")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(PepTheme.textSecondary)
                TextField("1", value: step.week, format: .number)
                    .keyboardType(.numberPad)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                    .frame(width: 44)
            }
            Divider().frame(height: 30).background(PepTheme.separatorColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("DOSE")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(PepTheme.textSecondary)
                HStack(spacing: 4) {
                    TextField("0", value: doseInDisplayUnit(step), format: .number)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.teal)
                        .frame(width: 70)
                    Text(startingDoseUnit.label)
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            Spacer()
            Button {
                if let idx = titrationSteps.firstIndex(where: { $0.id == step.id }) {
                    titrationSteps.remove(at: idx)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(PepTheme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(PepTheme.elevated.opacity(0.5))
        .clipShape(.rect(cornerRadius: 10))
    }

    // Vial duration summary
    private var vialDurationCard: some View {
        FlowCard(stepNumber: nil, iconName: "hourglass", title: "How long this vial lasts", subtitle: "Based on your starting dose & frequency") {
            HStack(spacing: 18) {
                durationStat(
                    value: weeksPerVial.map { formatWeeks($0) } ?? "—",
                    label: "weeks"
                )
                Divider().frame(height: 44).background(PepTheme.separatorColor)
                durationStat(
                    value: dosesPerVial.map { "\($0)" } ?? "—",
                    label: "doses"
                )
                Divider().frame(height: 44).background(PepTheme.separatorColor)
                if let units = unitsPerDose {
                    durationStat(value: "\(formatUnits(units))", label: "units / dose")
                } else {
                    durationStat(value: "—", label: "units / dose")
                }
            }
        }
    }

    private func durationStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(PepTheme.teal)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Reminder schedule (now positioned BEFORE titration so the plan honors the cadence)
    private var stepFrequencyCard: some View {
        FlowCard(stepNumber: nil, iconName: "bell.fill", title: "Reminder schedule", subtitle: "How often do you plan to dose? Titration honors this cadence.") {
            VStack(alignment: .leading, spacing: 12) {
                if let rec = recommendedFrequency, let raw = protocolDefault?.defaultFrequency {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(PepTheme.amber)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Recommended: \(rec.rawValue)")
                                .font(.system(size: 12, weight: .semibold, design: .serif))
                                .foregroundStyle(PepTheme.textPrimary)
                            Text(raw)
                                .font(.caption2)
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PepTheme.amber.opacity(0.10))
                    .clipShape(.rect(cornerRadius: 10))
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(ReminderFrequency.allCases) { f in
                        Button {
                            frequency = f
                            frequencyManuallySet = true
                            // Re-fetch titration so its length matches the new cadence/budget.
                            Task { await regenerateTitrationIfNeeded() }
                        } label: {
                            VStack(spacing: 2) {
                                Text(f.rawValue)
                                    .font(.system(size: 12, weight: .semibold, design: .serif))
                                    .foregroundStyle(frequency == f ? PepTheme.invertedText : PepTheme.textPrimary)
                                if recommendedFrequency == f {
                                    Text("recommended")
                                        .font(.system(size: 8, weight: .bold))
                                        .tracking(0.5)
                                        .foregroundStyle(frequency == f ? PepTheme.invertedText.opacity(0.85) : PepTheme.teal)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(frequency == f ? PepTheme.teal : PepTheme.elevated.opacity(0.6))
                            .clipShape(.rect(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    Text("Reminder time")
                        .font(.system(size: 12, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                    DatePicker("", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
            }
        }
    }

    // MARK: - Save bar

    private var saveBar: some View {
        VStack(spacing: 0) {
            Divider().background(PepTheme.separatorColor)
            Button {
                save()
            } label: {
                Text("Save vial & schedule")
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.invertedText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canContinue ? PepTheme.teal : PepTheme.elevated)
                    .clipShape(.rect(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(!canContinue)
            .sensoryFeedback(.success, trigger: canContinue)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 10)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Discover

    private var discoverFlowView: some View {
        VStack(spacing: 18) {
            if pickedGoal == nil {
                discoverGoalPicker
            } else if let goal = pickedGoal {
                discoverGoalDetail(goal)
            }
        }
    }

    private var discoverGoalPicker: some View {
        VStack(alignment: .leading, spacing: 18) {
            editorialHeader(
                eyebrow: "Discovery",
                title: "What's the goal?",
                subtitle: "We'll show you peptides commonly used for that aim."
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(discoverGoals) { goal in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            pickedGoal = goal
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            ZStack {
                                Circle().fill(goal.color.opacity(0.18)).frame(width: 40, height: 40)
                                Image(systemName: goal.icon)
                                    .foregroundStyle(goal.color)
                            }
                            Text(goal.title)
                                .font(.system(size: 16, weight: .semibold, design: .serif))
                                .foregroundStyle(PepTheme.textPrimary)
                            Text(goal.blurb)
                                .font(.system(size: 12, design: .serif))
                                .italic()
                                .foregroundStyle(PepTheme.textSecondary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
                        .background(PepTheme.cardSurface)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(goal.color.opacity(0.20), lineWidth: 1))
                        .clipShape(.rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.impact(weight: .light), trigger: pickedGoal?.id)
                }
            }
        }
    }

    private func discoverGoalDetail(_ goal: DiscoverGoal) -> some View {
        let matches = goal.suggestedNames.compactMap { name in
            CompoundDatabase.all.first { $0.name == name }
        }
        return VStack(alignment: .leading, spacing: 14) {
            editorialHeader(eyebrow: "Discovery", title: goal.title, subtitle: goal.blurb)

            VStack(spacing: 10) {
                ForEach(matches, id: \.id) { profile in
                    discoverPeptideRow(profile, accent: goal.color)
                }
            }
        }
    }

    private func discoverPeptideRow(_ profile: CompoundProfile, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(accent.opacity(0.18)).frame(width: 38, height: 38)
                    Image(systemName: profile.iconName.isEmpty ? "pill.fill" : profile.iconName)
                        .foregroundStyle(accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(profile.peptideType)
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Spacer()
            }
            Text(profile.overview)
                .font(.system(size: 13, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
                .lineLimit(3)
            HStack(spacing: 8) {
                NavigationLink {
                    CompoundDetailView(compound: profile)
                } label: {
                    Text("Learn more")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(PepTheme.elevated.opacity(0.6))
                        .clipShape(.capsule)
                }
                Button {
                    pickedGoal = nil
                    pickedCompound = profile.name
                    compoundQuery = profile.name
                    syncDefaultsForCompound()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        entry = .vial
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add this vial")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PepTheme.invertedText)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(accent)
                    .clipShape(.capsule)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func pickCompound(_ name: String) {
        pickedCompound = name
        compoundQuery = name
        syncDefaultsForCompound()
    }

    private func clearCompound() {
        pickedCompound = nil
        compoundQuery = ""
        vialSizeText = ""
        bacWaterMl = ""
        chosenSuggestedMl = nil
        startingDoseText = ""
        startingDoseManuallySet = false
        titrationSteps = []
        aiNote = ""
        titrationError = nil
    }

    private func resetVialFlow() {
        clearCompound()
    }

    private func syncDefaultsForCompound() {
        if let typical = compoundProfile?.reconstitutionGuide.typicalVialSize,
           let n = ReconHelper.parseFirstNumber(typical) {
            vialSizeText = formatVialNumber(n)
            if typical.lowercased().contains("mcg") { vialSizeUnit = .mcg }
            else if typical.lowercased().contains("iu") { vialSizeUnit = .iu }
            else { vialSizeUnit = .mg }
        }
        if !frequencyManuallySet, let rec = recommendedFrequency {
            frequency = rec
        }
        if !startingDoseManuallySet, let pd = protocolDefault {
            // Default to beginner low; choose unit close to the value's natural scale.
            let val = pd.beginner.low
            if pd.beginner.unit == "mg" {
                startingDoseUnit = val < 0.1 ? .mcg : .mg
                startingDoseText = startingDoseUnit == .mcg
                    ? formatVialNumber(val * 1000)
                    : formatVialNumber(val)
            } else {
                startingDoseUnit = .mcg
                startingDoseText = formatVialNumber(val)
            }
            startingDoseManuallySet = false // keep auto-fillable until they edit
        }
    }

    /// Maps the protocol default's freeform frequency string to a ReminderFrequency chip.
    private var recommendedFrequency: ReminderFrequency? {
        guard let raw = protocolDefault?.defaultFrequency.lowercased() else { return nil }
        if raw.contains("2x daily") || raw.contains("2× daily") || raw.contains("twice daily") || raw.contains("1-2x daily") || raw.contains("1-3x daily") {
            return .twiceDaily
        }
        if raw.contains("every other") || raw.contains("eod") {
            return .everyOther
        }
        if raw.contains("2-3x weekly") || raw.contains("2x weekly") || raw.contains("twice weekly") {
            return .twiceWeekly
        }
        if raw.contains("weekly") || raw.contains("1x week") {
            return .weekly
        }
        if raw.contains("as needed") || raw.contains("prn") {
            return .asNeeded
        }
        if raw.contains("daily") || raw.contains("once nightly") || raw.contains("nightly") || raw.contains("once daily") {
            return .daily
        }
        return nil
    }

    // MARK: - AI titration

    private func regenerateTitrationIfNeeded(force: Bool = false) async {
        guard let compound = pickedCompound, let dose = startingDoseMcg, let strategy = strategy else { return }
        if strategy == .maintain {
            // Show every individual week the vial can support so users can edit week-by-week.
            await MainActor.run {
                titrationSteps = makeMaintenanceWeeks(dose: dose)
                aiNote = ""
                titrationError = nil
            }
            return
        }
        await MainActor.run {
            titrationLoading = true
            titrationError = nil
        }
        do {
            let result = try await fetchAITitration(
                compound: compound,
                startingDoseMcg: dose,
                strategy: strategy,
                frequency: frequency
            )
            await MainActor.run {
                titrationSteps = expandStepsToWeekly(result.steps)
                aiNote = result.note
                titrationLoading = false
            }
        } catch {
            await MainActor.run {
                titrationError = "Couldn't reach the suggester. You can still add steps manually."
                titrationLoading = false
                if titrationSteps.isEmpty {
                    titrationSteps = [TitrationScheduleStep(week: 1, doseMcg: dose, label: "Start")]
                }
            }
        }
    }

    private struct AITitrationResult {
        let steps: [TitrationScheduleStep]
        let note: String
    }

    private func fetchAITitration(
        compound: String,
        startingDoseMcg: Double,
        strategy: DoseStrategy,
        frequency: ReminderFrequency
    ) async throws -> AITitrationResult {
        let budget = weeksBudgetAtStartingDose ?? 0
        let budgetText = budget > 0 ? "This vial supports about \(Int(budget.rounded(.down))) weeks at the starting dose & frequency. Do NOT plan beyond what the vial can supply — fewer steps is fine." : ""
        let userUnit = startingDoseUnit.label
        let system = """
        You are a careful peptide protocol assistant. Output ONLY valid JSON.
        Schema: { "steps": [{ "week": int, "doseMcg": number, "label": string }], "note": string }
        Use mcg for doseMcg (1 mg = 1000 mcg). Provide 2–6 steps that fit inside the vial's supply.
        Honor the strategy strictly: maintain = flat, titrateUp = ascending, titrateDown = descending.
        Keep doses within commonly used clinical ranges for the compound.
        IMPORTANT: When you write the human-readable "note", express every dose using the unit "\(userUnit)" — never mix units, never reference mcg if the user picked mg, and vice versa. Convert as needed before writing the note.
        """
        let user = """
        Compound: \(compound)
        Starting dose: \(startingDoseMcg) mcg (display unit for note: \(userUnit))
        Strategy: \(strategy.rawValue)
        Dosing frequency: \(frequency.rawValue)
        \(budgetText)
        Return JSON only, no prose. The "note" field must use \(userUnit) for any dose values it mentions.
        """
        let raw = try await OpenRouterClient.shared.chat(
            tier: .fast,
            systemPrompt: system,
            userPrompt: user,
            maxTokens: 600,
            temperature: 0.4
        )
        let cleaned = OpenRouterClient.extractJSON(raw)
        guard let data = cleaned.data(using: .utf8) else {
            throw OpenRouterError.invalidResponse
        }
        struct DTO: Decodable {
            struct Step: Decodable { let week: Int; let doseMcg: Double; let label: String? }
            let steps: [Step]
            let note: String?
        }
        let dto = try JSONDecoder().decode(DTO.self, from: data)
        let raw_steps = dto.steps.map {
            TitrationScheduleStep(week: $0.week, doseMcg: $0.doseMcg, label: $0.label ?? "")
        }
        let clamped = clampTitrationToVial(raw_steps)
        return AITitrationResult(steps: clamped, note: dto.note ?? "")
    }

    /// Drops trailing steps that the vial can't actually supply, so the plan stays honest.
    private func clampTitrationToVial(_ steps: [TitrationScheduleStep]) -> [TitrationScheduleStep] {
        guard let mg = vialSizeMg, mg > 0 else { return steps }
        let dpw = max(frequency.dosesPerWeek, 0.01)
        var remaining = mg * 1000.0
        var kept: [TitrationScheduleStep] = []
        let sorted = steps.sorted { $0.week < $1.week }
        for (i, step) in sorted.enumerated() {
            guard step.doseMcg > 0 else { continue }
            let canAfford = floor(remaining / step.doseMcg)
            if canAfford <= 0 { break }
            kept.append(step)
            let isLast = i + 1 >= sorted.count
            let plannedDoses: Double = isLast
                ? .greatestFiniteMagnitude
                : Double(max(sorted[i + 1].week - step.week, 0)) * dpw
            let take = min(plannedDoses, canAfford)
            remaining -= take * step.doseMcg
            if take < plannedDoses { break }
        }
        return kept.isEmpty ? Array(sorted.prefix(1)) : kept
    }

    /// Generates per-week rows at a flat dose, capped to the vial's actual capacity.
    private func makeMaintenanceWeeks(dose: Double) -> [TitrationScheduleStep] {
        let budget = weeksBudgetAtStartingDose ?? 4
        let count = max(1, min(Int(budget.rounded(.down)), 26))
        return (1...count).map { week in
            TitrationScheduleStep(
                week: week,
                doseMcg: dose,
                label: week == 1 ? "Maintenance" : ""
            )
        }
    }

    /// Expands a sparse plan (e.g. weeks 1, 4, 8) into per-week rows so every week
    /// is visible and editable. Intermediate weeks inherit the prior step's dose.
    private func expandStepsToWeekly(_ sparse: [TitrationScheduleStep]) -> [TitrationScheduleStep] {
        let sorted = sparse.sorted { $0.week < $1.week }
        guard !sorted.isEmpty else { return [] }
        var result: [TitrationScheduleStep] = []
        for (i, step) in sorted.enumerated() {
            let endWeek: Int
            if i + 1 < sorted.count {
                endWeek = max(step.week, sorted[i + 1].week - 1)
            } else {
                endWeek = step.week
            }
            for w in step.week...endWeek {
                result.append(
                    TitrationScheduleStep(
                        week: w,
                        doseMcg: step.doseMcg,
                        label: w == step.week ? step.label : ""
                    )
                )
            }
        }
        return result
    }

    private func addTitrationStep() {
        let lastWeek = titrationSteps.map(\.week).max() ?? 0
        let lastDose = titrationSteps.last?.doseMcg ?? (startingDoseMcg ?? 0)
        let nextDose: Double = {
            switch strategy {
            case .maintain, .none: return lastDose
            case .titrateUp: return lastDose * 1.5
            case .titrateDown: return max(lastDose * 0.66, 0)
            }
        }()
        titrationSteps.append(TitrationScheduleStep(week: lastWeek + 4, doseMcg: nextDose, label: ""))
    }

    /// Weeks the vial can still cover at the final titration dose AFTER the last step's natural week.
    /// Used to surface "+ extend" suggestions and the auto-extend nudge.
    private var extraWeeksAfterLastStep: Double? {
        guard let mg = vialSizeMg, mg > 0,
              let last = titrationSteps.sorted(by: { $0.week < $1.week }).last,
              last.doseMcg > 0 else { return nil }
        let totalMcg = mg * 1000.0
        let dpw = max(frequency.dosesPerWeek, 0.01)

        // Count consumption strictly UP TO the last step's start week.
        var remaining = totalMcg
        let sorted = titrationSteps.sorted { $0.week < $1.week }
        for (i, step) in sorted.enumerated() where i + 1 < sorted.count {
            let weekSpan = max(sorted[i + 1].week - step.week, 0)
            let plannedDoses = Double(weekSpan) * dpw
            let take = min(plannedDoses, floor(remaining / max(step.doseMcg, 0.0001)))
            remaining -= take * step.doseMcg
            if remaining <= 0 { return 0 }
        }
        let extraDoses = floor(remaining / last.doseMcg)
        guard extraDoses > 0 else { return 0 }
        return Double(extraDoses) / dpw
    }

    /// Bumps the last step's natural "end" by adding a follow-up step at the same dose,
    /// using whatever extra capacity the vial still has.
    private func extendFinalStep() {
        guard let extra = extraWeeksAfterLastStep, extra >= 1,
              let last = titrationSteps.sorted(by: { $0.week < $1.week }).last else { return }
        let endWeek = last.week + Int(extra.rounded(.down))
        // Add a marker step at the final-dose end so the duration card and warning math align.
        titrationSteps.append(
            TitrationScheduleStep(week: endWeek, doseMcg: last.doseMcg, label: "Vial end")
        )
    }

    // MARK: - Save

    private func save() {
        guard let name = pickedCompound, let mg = vialSizeMg, let dose = startingDoseMcg else { return }

        // 1. Add the vial to inventory
        let vial = Vial(
            compoundName: name,
            vialSizeMg: mg,
            diluentMl: needsReconstitution ? reconstitutedMl : nil,
            reconstitutedOn: needsReconstitution ? Date() : nil,
            storage: .fridge,
            typicalDoseMcg: dose,
            budDays: ReconHelper.defaultBUDDays(for: name)
        )
        VialInventoryStore.shared.add(vial)

        // 2. Build a protocol that captures starting dose + reconstitution
        let route: InjectionRoute = {
            let r = (protocolDefault?.route ?? compoundProfile?.keyFacts.administrationRoute ?? "Subcutaneous").lowercased()
            if r.contains("oral") { return .oral }
            if r.contains("nasal") { return .nasal }
            if r.contains("topical") { return .topical }
            if r.contains("intramuscular") { return .intramuscular }
            return .subcutaneous
        }()

        let compound = ProtocolCompound(
            compoundName: name,
            doseMcg: dose,
            frequency: frequency.protocolFrequency,
            timeOfDay: reminderTime,
            injectionRoute: route,
            reconstitutionVolume: reconstitutedMl,
            vialSizeMg: mg
        )

        let goal = inferGoal(for: name)
        let proto = PeptideProtocol(
            name: "\(name) Protocol",
            goal: goal,
            compounds: [compound],
            startDate: Date(),
            totalWeeks: nil,
            loadingWeeks: nil,
            maintenanceWeeks: nil,
            taperingWeeks: nil,
            offCycleWeeks: nil,
            isActive: true,
            isExistingProtocol: false
        )

        // 3. Persist titration schedule locally if it's a real plan
        if titrationSteps.count >= 1 && (strategy != nil) && (strategy != .maintain || titrationSteps.count > 1) {
            let cal = Calendar.current
            let comps = cal.dateComponents([.hour, .minute], from: reminderTime)
            let schedule = TitrationSchedule(
                protocolId: proto.id,
                compoundName: name,
                startDate: Date(),
                steps: titrationSteps,
                remindersEnabled: true,
                reminderHour: comps.hour ?? 9,
                reminderMinute: comps.minute ?? 0,
                autoAdvanceDose: true
            )
            TitrationScheduleStore.shared.save(schedule)
        }

        onComplete(proto)
        dismiss()
    }

    private func inferGoal(for name: String) -> ProtocolGoal {
        guard let profile = compoundProfile else { return .general }
        if profile.categories.contains(.weightLoss) { return .weightLoss }
        if profile.categories.contains(.muscleGrowth) || profile.categories.contains(.igfVariants) { return .muscleGrowth }
        if profile.categories.contains(.healing) { return .healing }
        if profile.categories.contains(.cognitive) { return .cognitive }
        if profile.categories.contains(.tanning) { return .tanning }
        return .general
    }

    // MARK: - Formatting

    private func formatMl(_ ml: Double) -> String {
        if ml == ml.rounded() { return "\(Int(ml)) mL" }
        return String(format: "%.1f mL", ml)
    }

    private func formatUnits(_ u: Double) -> String {
        if u == u.rounded() { return "\(Int(u))" }
        return String(format: "%.1f", u)
    }

    private func formatVialNumber(_ n: Double) -> String {
        if n == n.rounded() { return String(Int(n)) }
        return String(format: "%.2f", n)
    }

    private func formatWeeks(_ w: Double) -> String {
        if w >= 10 { return String(Int(w.rounded())) }
        return String(format: "%.1f", w)
    }

    private func displayDose(_ mcg: Double) -> String {
        if mcg >= 1000 {
            let mg = mcg / 1000
            return mg == mg.rounded() ? "\(Int(mg)) mg" : String(format: "%.2f mg", mg)
        }
        return "\(Int(mcg)) mcg"
    }

    private func displayDoseValue(_ mcg: Double, in unit: VialSizeUnit) -> Double {
        switch unit {
        case .mg: return mcg / 1000
        case .mcg, .iu: return mcg
        }
    }

    /// Two-way binding so the titration row edits the dose in whatever unit
    /// the user picked for the starting dose, while we keep storing mcg internally.
    private func doseInDisplayUnit(_ step: Binding<TitrationScheduleStep>) -> Binding<Double> {
        Binding(
            get: {
                switch startingDoseUnit {
                case .mg: return step.wrappedValue.doseMcg / 1000
                case .mcg, .iu: return step.wrappedValue.doseMcg
                }
            },
            set: { newValue in
                switch startingDoseUnit {
                case .mg: step.wrappedValue.doseMcg = newValue * 1000
                case .mcg, .iu: step.wrappedValue.doseMcg = newValue
                }
            }
        )
    }
}

// MARK: - Reusable card

private struct FlowCard<Content: View>: View {
    let stepNumber: Int?
    let iconName: String?
    let title: String
    let subtitle: String?
    @ViewBuilder var content: Content

    init(stepNumber: Int?, iconName: String? = nil, title: String, subtitle: String?, @ViewBuilder content: () -> Content) {
        self.stepNumber = stepNumber
        self.iconName = iconName
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                if let n = stepNumber {
                    ZStack {
                        Circle().fill(PepTheme.teal.opacity(0.14)).frame(width: 30, height: 30)
                        Text("\(n)")
                            .font(.system(size: 13, weight: .heavy, design: .serif))
                            .foregroundStyle(PepTheme.teal)
                    }
                } else {
                    Image(systemName: iconName ?? "circle.fill")
                        .foregroundStyle(PepTheme.teal)
                        .frame(width: 30, height: 30)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12, design: .serif))
                            .italic()
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
                Spacer()
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.cardSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(PepTheme.separatorColor, lineWidth: 0.5)
        )
        .clipShape(.rect(cornerRadius: 20))
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}
