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
    @State private var alreadyReconstituted: Bool? = nil
    @State private var existingBacWaterMl: String = ""
    @State private var chosenSuggestedMl: Double? = nil
    @State private var commonMlOptions: [Double] = [1, 2, 3, 5]
    @State private var frequency: ReminderFrequency = .daily
    @State private var reminderTime: Date = AddVialFlowView.defaultMorningTime()

    // Discover flow
    @State private var pickedGoal: DiscoverGoal?

    @State private var showVialScanner: Bool = false
    @State private var showWhyThisAmount: Bool = false
    @State private var frequencyManuallySet: Bool = false
    @FocusState private var focusedField: AddVialField?

    static func defaultMorningTime() -> Date {
        let cal = Calendar.current
        return cal.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    }

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
        case .iu: return v // IU treated as mg-equivalent for now (HCG etc.)
        }
    }

    /// Typical single dose in mcg from defaults / compound DB.
    private var typicalDoseMcg: Double {
        if let pd = protocolDefault {
            let mid = pd.intermediate.midpoint
            return pd.intermediate.unit == "mg" ? mid * 1000 : mid
        }
        return 250
    }

    /// Suggested BAC water volume that gives the cleanest whole-unit dosing on a U-100 0.5 mL syringe.
    private var suggestedReconMl: Double {
        guard let mg = vialSizeMg, mg > 0 else { return 2 }
        let totalMcg = mg * 1000
        // Try common volumes; pick one that gives target dose volume close to a multiple of 5 units (0.05 mL).
        let candidates: [Double] = [1, 2, 3, 5]
        let dose = max(typicalDoseMcg, 1)
        let scored = candidates.map { ml -> (Double, Double) in
            let concentration = totalMcg / ml // mcg/mL
            let drawMl = dose / concentration
            let drawUnits = drawMl * 100
            // prefer 10-50 units, multiples of 5
            let inRange = drawUnits >= 8 && drawUnits <= 60 ? 0.0 : 4.0
            let snap = abs(drawUnits - (drawUnits / 5).rounded() * 5)
            return (ml, inRange + snap)
        }
        return scored.min { $0.1 < $1.1 }?.0 ?? 2
    }

    private var reconstitutedMl: Double? {
        if alreadyReconstituted == true {
            return Double(existingBacWaterMl.replacingOccurrences(of: ",", with: "."))
        }
        if alreadyReconstituted == false {
            return chosenSuggestedMl ?? suggestedReconMl
        }
        return nil
    }

    private var concentrationMcgPerMl: Double? {
        guard let mg = vialSizeMg, let ml = reconstitutedMl, ml > 0 else { return nil }
        return mg * 1000 / ml
    }

    private var pickedSyringe: SyringeSpec {
        guard let conc = concentrationMcgPerMl else { return .u100_05 }
        let drawMl = typicalDoseMcg / conc
        if drawMl > 0.5 { return .u100_10 }
        if drawMl > 0.3 { return .u100_05 }
        return .u100_03
    }

    private var canContinue: Bool {
        guard pickedCompound != nil, vialSizeMg != nil else { return false }
        if !needsReconstitution { return true }
        if alreadyReconstituted == nil { return false }
        if alreadyReconstituted == true {
            return (Double(existingBacWaterMl) ?? 0) > 0
        }
        return true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    switch entry {
                    case .chooser:
                        chooserView
                    case .vial:
                        vialFlowView
                    case .discover:
                        discoverFlowView
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 120)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: entry)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: pickedCompound)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: vialSizeMg != nil)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: alreadyReconstituted)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: pickedGoal?.id)
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .navigationTitle(navTitle)
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
                    .foregroundStyle(PepTheme.textSecondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if entry == .vial {
                    saveBar
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PepTheme.teal)
                }
            }
            .fullScreenCover(isPresented: $showVialScanner) {
                VialScannerView { scan, _ in
                    applyScanned(scan)
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
        case .chooser: return "Add to Inventory"
        case .vial: return "Add a Vial"
        case .discover: return pickedGoal == nil ? "Find Your Peptide" : pickedGoal!.title
        }
    }

    // MARK: - Chooser

    private var chooserView: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Let's get you set up")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Pick the option that fits where you are right now.")
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(.top, 8)

            chooserCard(
                title: "Add a vial",
                subtitle: "I have a peptide in hand and want to set it up",
                icon: "testtube.2",
                color: PepTheme.teal
            ) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    entry = .vial
                }
            }

            chooserCard(
                title: "I don't have one yet",
                subtitle: "Help me figure out what fits my goals",
                icon: "sparkle.magnifyingglass",
                color: PepTheme.violet
            ) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    entry = .discover
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(PepTheme.textSecondary)
                Text("You can always scan a label instead — we'll auto-fill what we can read.")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PepTheme.elevated.opacity(0.5))
            .clipShape(.rect(cornerRadius: 12))
        }
    }

    private func chooserCard(title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(color.opacity(0.18))
                        .frame(width: 56, height: 56)
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PepTheme.cardSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(color.opacity(0.25), lineWidth: 1)
            )
            .clipShape(.rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .medium), trigger: entry)
    }

    // MARK: - Vial flow

    private var vialFlowView: some View {
        VStack(spacing: 18) {
            stepCompoundCard
            if pickedCompound != nil {
                stepVialSizeCard
            }
            if vialSizeMg != nil && needsReconstitution {
                stepReconCard
            }
            if vialSizeMg != nil && (alreadyReconstituted != nil || !needsReconstitution) {
                if reconstitutedMl != nil {
                    drawGuideCard
                }
                stepFrequencyCard
            }
        }
    }

    // Step 1 — peptide name
    private var stepCompoundCard: some View {
        FlowCard(stepNumber: 1, title: "Peptide", subtitle: "Type to search the compound database") {
            VStack(alignment: .leading, spacing: 10) {
                if let picked = pickedCompound {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(PepTheme.teal)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(picked)
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .foregroundStyle(PepTheme.textPrimary)
                            if let route = protocolDefault?.route ?? compoundProfile?.keyFacts.administrationRoute {
                                Text(route)
                                    .font(.caption)
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
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .focused($focusedField, equals: .compoundQuery)
                    }
                    .padding(12)
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
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(PepTheme.textPrimary)
                                            Text(profile.peptideType)
                                                .font(.caption2)
                                                .foregroundStyle(PepTheme.textSecondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 8)
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

                    Button {
                        showVialScanner = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "camera.viewfinder")
                            Text("Scan label instead")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(PepTheme.teal)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(PepTheme.teal.opacity(0.12))
                        .clipShape(.rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
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
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    TextField("e.g. 5", text: $vialSizeText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .vialSize)
                        .padding(12)
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
                            .font(.caption)
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
        FlowCard(stepNumber: 3, title: "Reconstitution", subtitle: "Has it already been mixed with BAC water?") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    reconChip(title: "Already mixed", isSelected: alreadyReconstituted == true) {
                        alreadyReconstituted = true
                    }
                    reconChip(title: "Not yet", isSelected: alreadyReconstituted == false) {
                        alreadyReconstituted = false
                    }
                }

                if alreadyReconstituted == true {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("BAC water added (mL)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                        TextField("e.g. 2", text: $existingBacWaterMl)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .bacWater)
                            .padding(12)
                            .background(PepTheme.elevated.opacity(0.6))
                            .clipShape(.rect(cornerRadius: 12))
                    }
                }

                if alreadyReconstituted == false {
                    suggestionPanel
                }
            }
        }
    }

    private func reconChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? PepTheme.background : PepTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? PepTheme.teal : PepTheme.elevated.opacity(0.6))
                .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    private var suggestionPanel: some View {
        let recommended = suggestedReconMl
        let chosen = chosenSuggestedMl ?? recommended
        let blurb = suggestionBlurb(for: recommended)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "drop.fill")
                    .foregroundStyle(PepTheme.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("We recommend \(formatMl(recommended)) of BAC water")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(blurb)
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                    if chosen != recommended {
                        Text("You picked \(formatMl(chosen)) — that works too.")
                            .font(.caption2)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.8))
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PepTheme.blue.opacity(0.12))
            .clipShape(.rect(cornerRadius: 12))

            HStack(spacing: 8) {
                ForEach(commonMlOptions, id: \.self) { ml in
                    Button {
                        chosenSuggestedMl = ml
                    } label: {
                        VStack(spacing: 2) {
                            Text(formatMl(ml))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(chosen == ml ? PepTheme.background : PepTheme.textPrimary)
                            if ml == recommended {
                                Text("recommended")
                                    .font(.system(size: 8, weight: .bold))
                                    .tracking(0.5)
                                    .foregroundStyle(chosen == ml ? PepTheme.background.opacity(0.85) : PepTheme.teal)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(chosen == ml ? PepTheme.teal : PepTheme.elevated.opacity(0.6))
                        .clipShape(.rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                withAnimation { showWhyThisAmount.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showWhyThisAmount ? "chevron.down" : "chevron.right")
                        .font(.caption2.weight(.bold))
                    Text("Why this amount?")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(PepTheme.textSecondary)
            }
            .buttonStyle(.plain)

            if showWhyThisAmount {
                Text("Picking the right amount of BAC water means each dose lands on a clean, easy-to-read mark on your insulin syringe. We pick the volume that keeps your typical dose in the 10–50 unit range — easy to draw, hard to misread.")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PepTheme.elevated.opacity(0.5))
                    .clipShape(.rect(cornerRadius: 10))
            }
        }
    }

    private func suggestionBlurb(for ml: Double) -> String {
        guard let mg = vialSizeMg else { return "Easy whole-unit dosing." }
        let conc = mg * 1000 / ml
        let drawMl = typicalDoseMcg / conc
        let drawUnits = drawMl * 100
        let cleanUnits = (drawUnits / 5).rounded() * 5
        let usingClean = abs(cleanUnits - drawUnits) < 0.6
        let unitsDisp = usingClean ? Int(cleanUnits) : Int(drawUnits.rounded())
        let doseDisp = displayDose(typicalDoseMcg)
        return "≈ \(unitsDisp) units per \(doseDisp) dose on a 0.5 mL insulin syringe."
    }

    // Inline draw guide
    private var drawGuideCard: some View {
        FlowCard(stepNumber: nil, title: "Your draw mark", subtitle: "Where to pull the plunger for each dose") {
            inlineSyringeVisual
        }
    }

    private var inlineSyringeVisual: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let conc = concentrationMcgPerMl {
                HStack(spacing: 14) {
                    miniStat("DOSE", displayDose(typicalDoseMcg))
                    miniStat("DRAW TO", "\(formatUnits(typicalDoseMcg / conc * pickedSyringe.unitsPerMl)) u", highlight: true)
                    miniStat("SYRINGE", pickedSyringe.short)
                }
                inlineSyringe(conc: conc)
                Text("Each major tick = \(formatUnits(pickedSyringe.majorTick)) u • minor = \(formatUnits(pickedSyringe.minorTick)) u")
                    .font(.caption2)
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
    }

    private func miniStat(_ label: String, _ value: String, highlight: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .heavy))
                .tracking(1)
                .foregroundStyle(PepTheme.textSecondary)
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(highlight ? PepTheme.teal : PepTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inlineSyringe(conc: Double) -> some View {
        let drawMl = typicalDoseMcg / conc
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

    // Step 4 — frequency
    private var stepFrequencyCard: some View {
        FlowCard(stepNumber: needsReconstitution ? 4 : 3, title: "Reminder schedule", subtitle: "How often do you plan to dose? Just for reminders.") {
            VStack(alignment: .leading, spacing: 12) {
                if let rec = recommendedFrequency, let raw = protocolDefault?.defaultFrequency {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(PepTheme.amber)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Recommended: \(rec.rawValue)")
                                .font(.caption.weight(.bold))
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
                        } label: {
                            VStack(spacing: 2) {
                                Text(f.rawValue)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(frequency == f ? PepTheme.background : PepTheme.textPrimary)
                                if recommendedFrequency == f {
                                    Text("recommended")
                                        .font(.system(size: 8, weight: .bold))
                                        .tracking(0.5)
                                        .foregroundStyle(frequency == f ? PepTheme.background.opacity(0.85) : PepTheme.teal)
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
                        .font(.caption.weight(.semibold))
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
                Text("Save vial & schedule reminders")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canContinue ? PepTheme.teal : PepTheme.elevated)
                    .clipShape(.rect(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(!canContinue)
            .sensoryFeedback(.success, trigger: canContinue)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Discover

    private var discoverFlowView: some View {
        VStack(spacing: 16) {
            if pickedGoal == nil {
                discoverGoalPicker
            } else if let goal = pickedGoal {
                discoverGoalDetail(goal)
            }
        }
    }

    private var discoverGoalPicker: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What's your goal?")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text("We'll show peptides commonly used for that goal.")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(discoverGoals) { goal in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            pickedGoal = goal
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            ZStack {
                                Circle().fill(goal.color.opacity(0.18)).frame(width: 40, height: 40)
                                Image(systemName: goal.icon)
                                    .foregroundStyle(goal.color)
                            }
                            Text(goal.title)
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(PepTheme.textPrimary)
                            Text(goal.blurb)
                                .font(.caption2)
                                .foregroundStyle(PepTheme.textSecondary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
                        .background(PepTheme.cardSurface)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(goal.color.opacity(0.25), lineWidth: 1))
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
            VStack(alignment: .leading, spacing: 6) {
                Text(goal.title)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(goal.blurb)
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textSecondary)
            }

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
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(profile.peptideType)
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Spacer()
            }
            Text(profile.overview)
                .font(.caption)
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
                    .foregroundStyle(PepTheme.background)
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
        alreadyReconstituted = nil
        existingBacWaterMl = ""
        chosenSuggestedMl = nil
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
    }

    /// Maps the protocol default's freeform frequency string to a ReminderFrequency chip.
    private var recommendedFrequency: ReminderFrequency? {
        guard let raw = protocolDefault?.defaultFrequency.lowercased() else { return nil }
        // Order matters — check most specific first.
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

    private func applyScanned(_ scan: ScannedVialLabel) {
        if !scan.compoundName.isEmpty {
            pickedCompound = scan.compoundName
            compoundQuery = scan.compoundName
            syncDefaultsForCompound()
        }
        if let mg = scan.vialSizeMg {
            vialSizeText = formatVialNumber(mg)
            vialSizeUnit = .mg
        }
        if scan.reconstitutedOn != nil {
            alreadyReconstituted = true
        }
        if let dml = scan.diluentVolumeMl {
            existingBacWaterMl = formatVialNumber(dml)
        }
        entry = .vial
    }

    private func save() {
        guard let name = pickedCompound, let mg = vialSizeMg else { return }

        // 1. Add the vial to inventory
        let vial = Vial(
            compoundName: name,
            vialSizeMg: mg,
            diluentMl: needsReconstitution ? reconstitutedMl : nil,
            reconstitutedOn: alreadyReconstituted == true ? Date() : nil,
            storage: .fridge,
            typicalDoseMcg: typicalDoseMcg,
            budDays: ReconHelper.defaultBUDDays(for: name)
        )
        VialInventoryStore.shared.add(vial)

        // 2. Build a lightweight protocol so the home protocol section reflects it
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
            doseMcg: typicalDoseMcg,
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

    private func displayDose(_ mcg: Double) -> String {
        if mcg >= 1000 {
            let mg = mcg / 1000
            return mg == mg.rounded() ? "\(Int(mg)) mg" : String(format: "%.2f mg", mg)
        }
        return "\(Int(mcg)) mcg"
    }
}

// MARK: - Reusable card

private struct FlowCard<Content: View>: View {
    let stepNumber: Int?
    let title: String
    let subtitle: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                if let n = stepNumber {
                    ZStack {
                        Circle().fill(PepTheme.teal.opacity(0.18)).frame(width: 26, height: 26)
                        Text("\(n)")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(PepTheme.teal)
                    }
                } else {
                    Image(systemName: "syringe.fill")
                        .foregroundStyle(PepTheme.teal)
                        .frame(width: 26, height: 26)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
                Spacer()
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 18))
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}
