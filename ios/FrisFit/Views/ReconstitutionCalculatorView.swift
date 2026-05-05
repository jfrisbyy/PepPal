import SwiftUI

nonisolated enum SyringeSpec: String, CaseIterable, Identifiable, Sendable {
    case u100_03 = "0.3 mL (U-100)"
    case u100_05 = "0.5 mL (U-100)"
    case u100_10 = "1.0 mL (U-100)"
    case u40_10 = "1.0 mL (U-40)"

    var id: String { rawValue }

    /// Total capacity in mL
    var capacityMl: Double {
        switch self {
        case .u100_03: return 0.3
        case .u100_05: return 0.5
        case .u100_10, .u40_10: return 1.0
        }
    }

    /// Units per mL on the barrel
    var unitsPerMl: Double {
        switch self {
        case .u100_03, .u100_05, .u100_10: return 100
        case .u40_10: return 40
        }
    }

    /// Total unit markings on the barrel
    var totalUnits: Double { capacityMl * unitsPerMl }

    /// Major tick interval
    var majorTick: Double {
        switch self {
        case .u100_03: return 5
        case .u100_05: return 10
        case .u100_10: return 10
        case .u40_10: return 10
        }
    }

    /// Minor tick interval
    var minorTick: Double {
        switch self {
        case .u100_03: return 1
        case .u100_05: return 2
        case .u100_10: return 2
        case .u40_10: return 2
        }
    }

    var short: String {
        switch self {
        case .u100_03: return "0.3 mL"
        case .u100_05: return "0.5 mL"
        case .u100_10: return "1 mL"
        case .u40_10: return "U-40"
        }
    }

    /// Short hint shown under each picker option (what you probably have).
    var commonLabel: String {
        switch self {
        case .u100_03: return "Insulin (slim)"
        case .u100_05: return "Insulin (std)"
        case .u100_10: return "Insulin (large)"
        case .u40_10: return "Pet / vet insulin"
        }
    }

    /// One-liner shown beneath the picker explaining the pick.
    var guidanceText: String {
        switch self {
        case .u100_03: return "0.3 mL U-100 — ideal for small peptide doses under 30 units. Finest tick marks, easiest to read."
        case .u100_05: return "0.5 mL U-100 — the most common insulin syringe you’ll find at pharmacies in the US. Good all-rounder."
        case .u100_10: return "1 mL U-100 — use when a single dose exceeds 50 units (e.g. 2 mg tirzepatide in a 1 mL recon)."
        case .u40_10: return "1 mL U-40 — mostly for veterinary insulin. Only use if your vial or pen is labeled U-40. Do NOT mix with U-100 scale."
        }
    }
}

struct SyringeGuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Which syringe do I have?")
                            .font(.system(.title3, weight: .bold))
                        Text("A quick guide to picking the right one from the pharmacy.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    guideCard(
                        title: "0.3 mL Insulin (U-100)",
                        subtitle: "BD Ultra-Fine, ReliOn 31g 5/16\" — slim barrel, 30 units max",
                        bullets: [
                            "Best for low-volume peptide doses (BPC-157, TB-500, Tesamorelin at 0.1–0.2 mL).",
                            "Tick marks every 1 unit — most accurate small draws.",
                            "Usually labeled “30 unit” or “0.3 cc” on the wrapper."
                        ],
                        color: PepTheme.teal
                    )

                    guideCard(
                        title: "0.5 mL Insulin (U-100)",
                        subtitle: "Most common pharmacy pick — 50 units max",
                        bullets: [
                            "What GLP-1 users typically end up with (Semaglutide, Tirzepatide up to ~50 units).",
                            "Tick marks every 2 units.",
                            "Labeled “50 unit” or “1/2 cc”."
                        ],
                        color: PepTheme.blue
                    )

                    guideCard(
                        title: "1.0 mL Insulin (U-100)",
                        subtitle: "100 units max — needed for high-volume draws",
                        bullets: [
                            "Use when one dose is more than 50 units (e.g. 2 mg Tirzepatide reconstituted into 1 mL).",
                            "Also useful to split into two separate shots instead of doing two injections.",
                            "Labeled “100 unit” or “1 cc”."
                        ],
                        color: PepTheme.violet
                    )

                    guideCard(
                        title: "U-40 (veterinary)",
                        subtitle: "Rare — only for U-40 labeled vials",
                        bullets: [
                            "Used with pet insulin (Vetsulin, Caninsulin). Do NOT use for U-100 peptide math.",
                            "Tick marks are the same numbers but each unit = 2.5x the volume of a U-100 unit.",
                            "If you’re unsure — you almost certainly don’t have a U-40 syringe."
                        ],
                        color: PepTheme.amber
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Quick rule of thumb", systemImage: "lightbulb.fill")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(PepTheme.amber)
                        Text("If your box says “insulin syringe U-100” and shows a number like 30 / 50 / 100 — that number is the total units it can hold. Match it to the 0.3 / 0.5 / 1.0 mL option above.")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textPrimary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PepTheme.amber.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 14))
                }
                .padding(20)
            }
            .appBackground()
            .navigationTitle("Syringe Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PepTheme.teal)
                }
            }
        }
    }

    private func guideCard(title: String, subtitle: String, bullets: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.18))
                        .frame(width: 36, height: 36)
                    Image(systemName: "syringe.fill")
                        .foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(bullets, id: \.self) { b in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(color)
                            .frame(width: 5, height: 5)
                            .padding(.top, 6)
                        Text(b)
                            .font(.caption)
                            .foregroundStyle(PepTheme.textPrimary)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.elevated)
        .clipShape(.rect(cornerRadius: 14))
    }
}

enum ReconMode: String, CaseIterable {
    case forward = "Solve for Units"
    case reverse = "Solve for Water"
}

struct ReconstitutionCalculatorView: View {
    @Environment(\.dismiss) private var dismiss

    // Optional compound preselection (from protocol detail or scan)
    let initialCompound: String?
    let initialVialSizeMg: Double?

    init(initialCompound: String? = nil, initialVialSizeMg: Double? = nil) {
        self.initialCompound = initialCompound
        self.initialVialSizeMg = initialVialSizeMg
    }

    @State private var mode: ReconMode = .forward
    @State private var selectedCompound: CompoundProfile? = nil
    @State private var peptideAmountMg: String = ""
    @State private var waterVolumeMl: String = ""
    @State private var desiredDoseInput: String = ""
    @State private var desiredUnits: String = ""
    @State private var syringe: SyringeSpec = .u100_05
    @State private var showSaveSheet: Bool = false
    @State private var saveName: String = ""
    @State private var saveConfirmation: String? = nil
    @State private var presetSearch: String = ""
    @State private var showSyringeInfo: Bool = false

    @State private var inventory = VialInventoryStore.shared
    @State private var showScanner: Bool = false
    @State private var showDrawGuide: Bool = false

    private var peptideMg: Double? { Double(peptideAmountMg) }
    private var waterMl: Double? { Double(waterVolumeMl) }
    private var doseUnit: CompoundUnit {
        if let c = selectedCompound { return CompoundUnitHelper.unit(for: c.name) }
        return .mcg
    }
    private var doseMcg: Double? {
        guard let raw = Double(desiredDoseInput) else { return nil }
        return doseUnit == .mg ? raw * 1000 : raw
    }
    private var targetUnits: Double? { Double(desiredUnits) }

    // Forward: compute concentration & draw
    private var concentrationMcgPerMl: Double? {
        guard let mg = peptideMg, let ml = waterMl, mg > 0, ml > 0 else { return nil }
        return (mg * 1000) / ml
    }

    private var mlToInject: Double? {
        guard let conc = concentrationMcgPerMl, let dose = doseMcg, conc > 0, dose > 0 else { return nil }
        return dose / conc
    }

    /// Units to draw on the SELECTED syringe
    private var unitsToDraw: Double? {
        guard let ml = mlToInject else { return nil }
        return ml * syringe.unitsPerMl
    }

    // Reverse: compute required water volume given desired units on selected syringe
    private var reverseWaterMl: Double? {
        guard let mg = peptideMg, mg > 0,
              let dose = doseMcg, dose > 0,
              let units = targetUnits, units > 0 else { return nil }
        let mlPerDose = units / syringe.unitsPerMl
        // concentration mcg/mL = dose / mlPerDose → water = mg*1000 / conc
        let conc = dose / mlPerDose
        guard conc > 0 else { return nil }
        return (mg * 1000) / conc
    }

    private var effectiveWaterMl: Double? {
        mode == .forward ? waterMl : reverseWaterMl
    }

    private var effectiveUnits: Double? {
        mode == .forward ? unitsToDraw : targetUnits
    }

    private var dosesPerVial: Int? {
        guard let mg = peptideMg, let dose = doseMcg, dose > 0 else { return nil }
        return Int((mg * 1000) / dose)
    }

    private var effectiveMlPerDose: Double? {
        if mode == .forward { return mlToInject }
        if let units = targetUnits { return units / syringe.unitsPerMl }
        return nil
    }

    private var hasResults: Bool {
        effectiveUnits != nil && effectiveWaterMl != nil
    }

    // MARK: - Warnings

    private var warnings: [String] {
        var w: [String] = []
        if let units = effectiveUnits {
            if units < 2 {
                w.append("Draw under 2 units is hard to measure accurately — try a smaller vial or higher dose.")
            }
            if units > syringe.totalUnits {
                w.append("Draw exceeds \(syringe.short) capacity (\(Int(syringe.totalUnits)) units). Pick a larger syringe or split the dose.")
            }
        }
        if let compound = selectedCompound, let dose = doseMcg {
            if let range = parseDoseRange(compound.keyFacts.typicalDoseRange) {
                if dose < range.lower * 0.5 {
                    w.append("Dose is well below the typical range for \(compound.name). Double-check your numbers.")
                } else if dose > range.upper * 1.5 {
                    w.append("Dose is well above the typical range for \(compound.name). Double-check your numbers.")
                }
            }
        }
        return w
    }

    private func parseDoseRange(_ s: String) -> (lower: Double, upper: Double)? {
        let numbers = s.matches(of: /\d+(?:\.\d+)?/).compactMap { Double($0.output) }
        guard numbers.count >= 2 else { return nil }
        let isMg = s.lowercased().contains("mg") && !s.lowercased().contains("mcg")
        let factor = isMg ? 1000.0 : 1.0
        return (numbers[0] * factor, numbers[1] * factor)
    }

    var body: some View {
        if PeptideAccessManager.shared.shouldShowTrackAEmptyState {
            NavigationStack {
                TrackAEmptyStateView(
                    surface: .reconstitution,
                    icon: "drop.degreesign",
                    title: "Reconstitution, made simple",
                    blurb: "Reconstitution is mixing a freeze-dried peptide with bacteriostatic water so you can dose it accurately. EPTI does the math — try the demo below."
                ) {
                    reconDemoCard
                }
                .navigationTitle("Reconstitution")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") { dismiss() }
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
            }
            .preferredColorScheme(.dark)
        } else {
            calculatorBody
        }
    }

    /// Tiny non-persisted demo card so Track A users can feel the calculator's value.
    @ViewBuilder
    private var reconDemoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Try it")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
            VStack(alignment: .leading, spacing: 6) {
                demoRow(label: "Vial size", value: "5 mg")
                demoRow(label: "Bacteriostatic water", value: "2 mL")
                demoRow(label: "Concentration", value: "2,500 mcg / mL")
            }
            Divider().background(PepTheme.textSecondary.opacity(0.2))
            VStack(alignment: .leading, spacing: 6) {
                demoRow(label: "Desired dose", value: "250 mcg")
                demoRow(label: "Draw on a 0.5 mL U-100 syringe", value: "10 units", emphasized: true)
            }
            Text("Activate peptide tracking to save presets, link to your vials, and get warnings on out-of-range doses.")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
                .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.cardSurface.opacity(0.6))
        .clipShape(.rect(cornerRadius: 18))
    }

    private func demoRow(label: String, value: String, emphasized: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.footnote)
                .foregroundStyle(PepTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(.footnote, weight: emphasized ? .bold : .semibold))
                .foregroundStyle(emphasized ? PepTheme.teal : PepTheme.textPrimary)
        }
    }

    @ViewBuilder
    private var calculatorBody: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    headerCard
                    presetPicker
                    modeToggle
                    syringePicker
                    inputSection

                    if hasResults {
                        resultSection
                            .transition(.opacity.combined(with: .move(edge: .bottom)))

                        syringeVisual
                            .transition(.opacity.combined(with: .move(edge: .bottom)))

                        if !warnings.isEmpty {
                            warningSection
                                .transition(.opacity)
                        }

                        actionsRow
                    }

                    disclaimerBanner
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: hasResults)
                .animation(.spring(response: 0.3, dampingFraction: 0.85), value: mode)
                .animation(.spring(response: 0.3, dampingFraction: 0.85), value: syringe)
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .navigationTitle("Reconstitution")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PepTheme.teal)
                }
            }
            .sheet(isPresented: $showSaveSheet) { saveVialSheet }
            .fullScreenCover(isPresented: $showScanner) {
                VialScannerView { scan, _ in
                    applyScan(scan)
                }
            }
            .onChange(of: selectedCompound?.id) { _, _ in
                if let c = selectedCompound,
                   let dose = Double(desiredDoseInput),
                   CompoundUnitHelper.unit(for: c.name) == .mg,
                   dose > 100 {
                    desiredDoseInput = formatNum(dose / 1000)
                }
            }
            .onAppear {
                if let name = initialCompound, selectedCompound == nil {
                    if let profile = CompoundDatabase.all.first(where: { $0.name == name }) {
                        applyPreset(profile)
                    }
                }
                if let mg = initialVialSizeMg, mg > 0 {
                    peptideAmountMg = formatNum(mg)
                }
            }
        }
    }

    // MARK: - Sections

    private var headerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: [PepTheme.teal, PepTheme.blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 52, height: 52)
                Image(systemName: "function")
                    .font(.title3)
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Dose Calculator")
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(mode == .forward ? "Figure out your draw from vial + water" : "Figure out water needed for a preferred draw")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()
            Button { showScanner = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 12, weight: .bold))
                    Text("Scan Vial")
                        .font(.system(.caption, weight: .bold))
                }
                .foregroundStyle(PepTheme.invertedText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(PepTheme.teal, in: .capsule)
            }
        }
        .padding(.top, 8)
    }

    private func applyScan(_ scan: ScannedVialLabel) {
        if scan.isDiluent {
            if let ml = scan.diluentVolumeMl, ml > 0 {
                waterVolumeMl = formatNum(ml)
            }
            return
        }
        if !scan.compoundName.isEmpty,
           let profile = CompoundDatabase.all.first(where: { $0.name == scan.compoundName }) {
            applyPreset(profile)
        } else if !scan.compoundName.isEmpty {
            selectedCompound = nil
        }
        if let mg = scan.vialSizeMg, mg > 0 {
            peptideAmountMg = formatNum(mg)
        }
    }

    private var presetPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("COMPOUND PRESET")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                if let c = selectedCompound {
                    Text(CompoundUnitHelper.unit(for: c.name) == .mg ? "doses in mg" : "doses in mcg")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PepTheme.teal)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(PepTheme.textSecondary)
                TextField("Search compounds", text: $presetSearch)
                    .font(.system(.subheadline))
                    .foregroundStyle(PepTheme.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !presetSearch.isEmpty {
                    Button {
                        presetSearch = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(PepTheme.elevated)
            .clipShape(.capsule)

            if presetCompounds.isEmpty {
                Text("No compounds match “\(presetSearch)”")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chipButton(title: "None", isSelected: selectedCompound == nil, icon: "xmark") {
                            selectedCompound = nil
                        }
                        ForEach(presetCompounds, id: \.id) { profile in
                            chipButton(
                                title: profile.name,
                                isSelected: selectedCompound?.id == profile.id,
                                icon: profile.iconName
                            ) {
                                applyPreset(profile)
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                }
                .contentMargins(.horizontal, 0)
            }
        }
    }

    private var allPresetCompounds: [CompoundProfile] {
        CompoundDatabase.all.filter { $0.reconstitutionGuide.typicalVialSize != "—" && !$0.reconstitutionGuide.reconstitutionMath.contains("N/A") }
    }

    private var presetCompounds: [CompoundProfile] {
        let q = presetSearch.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return allPresetCompounds }
        return allPresetCompounds.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    private func chipButton(title: String, isSelected: Bool, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(.caption, weight: .semibold))
            }
            .foregroundStyle(isSelected ? PepTheme.invertedText : PepTheme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? PepTheme.teal : PepTheme.elevated)
            .clipShape(.capsule)
        }
    }

    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach(ReconMode.allCases, id: \.self) { m in
                Button {
                    withAnimation { mode = m }
                } label: {
                    Text(m.rawValue)
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(mode == m ? PepTheme.invertedText : PepTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(mode == m ? PepTheme.teal : Color.clear)
                        .clipShape(.capsule)
                }
            }
        }
        .padding(4)
        .background(PepTheme.elevated)
        .clipShape(.capsule)
    }

    private var syringePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SYRINGE")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                Button {
                    showSyringeInfo = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Which do I have?")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(PepTheme.teal)
                }
            }

            HStack(spacing: 8) {
                ForEach(SyringeSpec.allCases) { s in
                    Button {
                        syringe = s
                    } label: {
                        VStack(spacing: 3) {
                            Text(s.short)
                                .font(.system(.caption, weight: .bold))
                            Text(s.commonLabel)
                                .font(.system(size: 9, weight: .medium))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(syringe == s ? PepTheme.invertedText : PepTheme.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .padding(.vertical, 10)
                        .background(syringe == s ? PepTheme.teal : PepTheme.elevated)
                        .clipShape(.rect(cornerRadius: 10))
                    }
                }
            }

            Text(syringe.guidanceText)
                .font(.caption2)
                .foregroundStyle(PepTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
        }
        .sheet(isPresented: $showSyringeInfo) {
            SyringeGuideSheet()
                .presentationDetents([.medium, .large])
        }
    }

    private var inputSection: some View {
        VStack(spacing: 10) {
            calcInput(
                label: "Peptide Amount (Vial Size)",
                placeholder: "5",
                unit: "mg",
                text: $peptideAmountMg,
                icon: "pill.fill",
                color: PepTheme.teal
            )

            if mode == .forward {
                calcInput(
                    label: "BAC Water Volume",
                    placeholder: "2",
                    unit: "mL",
                    text: $waterVolumeMl,
                    icon: "drop.fill",
                    color: PepTheme.blue
                )
            }

            calcInput(
                label: "Desired Dose",
                placeholder: doseUnit == .mg ? "5" : "250",
                unit: doseUnit.rawValue,
                text: $desiredDoseInput,
                icon: "syringe.fill",
                color: .orange
            )

            if mode == .reverse {
                calcInput(
                    label: "Preferred Units per Dose",
                    placeholder: "20",
                    unit: "units",
                    text: $desiredUnits,
                    icon: "ruler.fill",
                    color: PepTheme.violet
                )
            }
        }
    }

    private func calcInput(label: String, placeholder: String, unit: String, text: Binding<String>, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            HStack(spacing: 8) {
                TextField(placeholder, text: text)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .keyboardType(.decimalPad)
                Text(unit)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(PepTheme.elevated)
            .clipShape(.rect(cornerRadius: 12))
        }
    }

    private var resultSection: some View {
        GlassCard {
            VStack(spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text("Recipe")
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                    if let profile = selectedCompound {
                        Text(profile.name)
                            .font(.system(.caption2, weight: .semibold))
                            .foregroundStyle(PepTheme.teal)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(PepTheme.teal.opacity(0.12))
                            .clipShape(.capsule)
                    }
                }

                if let water = effectiveWaterMl {
                    resultRow(label: mode == .reverse ? "Add Water" : "Water Added", value: String(format: "%.2f mL", water), icon: "drop.fill", color: PepTheme.blue)
                }
                if let conc = concentrationMcgPerMl, mode == .forward {
                    resultRow(label: "Concentration", value: String(format: "%.0f mcg/mL", conc), icon: "flask.fill", color: PepTheme.teal)
                }
                if let units = effectiveUnits {
                    resultRow(label: "Draw to", value: String(format: "%.1f units", units), icon: "syringe.fill", color: .orange, highlight: true)
                }
                if let ml = effectiveMlPerDose {
                    resultRow(label: "Volume per Dose", value: String(format: "%.3f mL", ml), icon: "eyedropper.halffull", color: PepTheme.violet)
                }
                if let doses = dosesPerVial {
                    resultRow(label: "Doses per Vial", value: "\(doses) doses", icon: "number", color: PepTheme.amber)
                }

                if let profile = selectedCompound {
                    Divider().overlay(PepTheme.separatorColor)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "thermometer.medium")
                                .font(.system(size: 11))
                                .foregroundStyle(PepTheme.textSecondary)
                            Text("Storage after mixing")
                                .font(.system(size: 10, weight: .heavy))
                                .tracking(1.0)
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        Text(profile.reconstitutionGuide.storageReconstituted)
                            .font(.caption)
                            .foregroundStyle(PepTheme.textPrimary)

                        let budDays = ReconHelper.defaultBUDDays(for: profile.name)
                        Text("Beyond-Use Date: ~\(budDays) days from mixing")
                            .font(.caption2)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
            }
        }
    }

    private func resultRow(label: String, value: String, icon: String, color: Color, highlight: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 28)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(highlight ? .title3 : .subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(highlight ? color : PepTheme.textPrimary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Syringe Visual

    private var syringeVisual: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: "syringe.fill")
                        .foregroundStyle(.orange)
                    Text("\(syringe.rawValue) — draw to the highlighted mark")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                }

                SyringeBarrelView(syringe: syringe, units: effectiveUnits ?? 0)
                    .frame(height: 84)
            }
        }
    }

    private var warningSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(warnings, id: \.self) { msg in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(PepTheme.amber)
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                }
                .padding(12)
                .background(PepTheme.amber.opacity(0.1))
                .clipShape(.rect(cornerRadius: 12))
            }
        }
    }

    private var actionsRow: some View {
        HStack(spacing: 10) {
            Button {
                saveName = selectedCompound?.name ?? ""
                showSaveSheet = true
            } label: {
                Label("Save as Vial", systemImage: "tray.and.arrow.down.fill")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.invertedText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(PepTheme.teal, in: .rect(cornerRadius: 12))
            }

            Button {
                showDrawGuide = true
            } label: {
                Label("Draw Guide", systemImage: "scope")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(PepTheme.elevated, in: .rect(cornerRadius: 12))
            }
            .disabled(concentrationMcgPerMl == nil || doseMcg == nil)

            ShareLink(item: shareText) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .frame(width: 48, height: 44)
                    .background(PepTheme.elevated, in: .rect(cornerRadius: 12))
            }
        }
        .sheet(isPresented: $showDrawGuide) {
            if let conc = concentrationMcgPerMl, let dose = doseMcg, conc > 0 {
                SyringeDrawGuideView(
                    compoundName: selectedCompound?.name ?? "Your Peptide",
                    doseMcg: dose,
                    concentrationMcgPerMl: conc,
                    syringe: syringe
                )
            }
        }
    }

    private var shareText: String {
        var lines: [String] = ["EPTI Reconstitution Recipe"]
        if let c = selectedCompound { lines.append("Compound: \(c.name)") }
        if let mg = peptideMg { lines.append("Vial: \(formatNum(mg)) mg") }
        if let w = effectiveWaterMl { lines.append("Water: \(String(format: "%.2f", w)) mL") }
        if let d = doseMcg {
            let name = selectedCompound?.name ?? ""
            lines.append("Dose: \(CompoundUnitHelper.displayDose(d, for: name))")
        }
        if let u = effectiveUnits { lines.append("Draw: \(String(format: "%.1f", u)) units on \(syringe.short)") }
        if let n = dosesPerVial { lines.append("Doses/vial: \(n)") }
        return lines.joined(separator: "\n")
    }

    private func formatNum(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(format: "%.2g", d)
    }

    private var disclaimerBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.title3)
                .foregroundStyle(PepTheme.amber)
            Text("Educational tool only. Always verify with a qualified healthcare professional.")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
                .lineSpacing(2)
        }
        .padding(12)
        .background(PepTheme.amber.opacity(0.08))
        .clipShape(.rect(cornerRadius: 12))
    }

    // MARK: - Save Vial

    private var saveVialSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nickname (e.g. 'Fridge BPC vial')", text: $saveName)
                } header: { Text("Vial") }

                Section {
                    if let mg = peptideMg { Text("Vial size: \(formatNum(mg)) mg") }
                    if let w = effectiveWaterMl { Text("Water: \(String(format: "%.2f", w)) mL") }
                    if let d = doseMcg {
                        let name = selectedCompound?.name ?? ""
                        Text("Dose: \(CompoundUnitHelper.displayDose(d, for: name))")
                    }
                    if let n = dosesPerVial { Text("Doses: \(n)") }
                } header: { Text("Summary") } footer: {
                    Text("This vial will be added to your inventory with a BUD countdown.")
                }

                if let message = saveConfirmation {
                    Section {
                        Label(message, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Save to Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showSaveSheet = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveVial() }
                        .disabled(peptideMg == nil || effectiveWaterMl == nil || doseMcg == nil)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func saveVial() {
        guard let mg = peptideMg, let water = effectiveWaterMl, let dose = doseMcg else { return }
        let compoundName = selectedCompound?.name ?? (saveName.isEmpty ? "Custom Vial" : saveName)
        let budDays = selectedCompound.map { ReconHelper.defaultBUDDays(for: $0.name) } ?? 30
        let vial = Vial(
            compoundName: compoundName,
            vialSizeMg: mg,
            diluentMl: water,
            reconstitutedOn: Date(),
            storage: .fridge,
            lotNumber: "",
            vialNumber: "",
            expirationDate: nil,
            typicalDoseMcg: dose,
            mcgUsed: 0,
            budDays: budDays
        )
        inventory.add(vial)
        saveConfirmation = "Added to inventory"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showSaveSheet = false
            saveConfirmation = nil
        }
    }

    // MARK: - Preset application

    private func applyPreset(_ profile: CompoundProfile) {
        selectedCompound = profile
        let math = profile.reconstitutionGuide.reconstitutionMath
        let vialSize = profile.reconstitutionGuide.typicalVialSize

        if let mg = extractFirstMg(from: vialSize) ?? extractFirstMg(from: math) {
            peptideAmountMg = formatNum(mg)
        }
        if let ml = extractFirstMl(from: math) {
            waterVolumeMl = formatNum(ml)
        }
        // Default dose from typical range lower bound
        if let dose = parseDoseRange(profile.keyFacts.typicalDoseRange)?.lower {
            let unit = CompoundUnitHelper.unit(for: profile.name)
            if unit == .mg {
                let mg = dose / 1000
                desiredDoseInput = formatNum(mg)
            } else {
                desiredDoseInput = String(Int(dose))
            }
        }
    }

    private func extractFirstMg(from s: String) -> Double? {
        let pattern = #"(\d+(?:\.\d+)?)\s*mg"#
        guard let range = s.range(of: pattern, options: .regularExpression) else { return nil }
        let substr = s[range]
        let num = substr.matches(of: /\d+(?:\.\d+)?/).first
        return num.flatMap { Double($0.output) }
    }

    private func extractFirstMl(from s: String) -> Double? {
        let pattern = #"(\d+(?:\.\d+)?)\s*mL"#
        guard let range = s.range(of: pattern, options: .regularExpression) else { return nil }
        let substr = s[range]
        let num = substr.matches(of: /\d+(?:\.\d+)?/).first
        return num.flatMap { Double($0.output) }
    }
}

// MARK: - Syringe Barrel

struct SyringeBarrelView: View {
    let syringe: SyringeSpec
    let units: Double

    var body: some View {
        GeometryReader { geo in
            let barrelPadding: CGFloat = 16
            let availableWidth = geo.size.width - barrelPadding * 2
            let barrelHeight: CGFloat = 36
            let unitsClamped = max(0, min(units, syringe.totalUnits))
            let fillFraction = CGFloat(unitsClamped / syringe.totalUnits)

            ZStack(alignment: .leading) {
                // Plunger (left) + Needle (right)
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(PepTheme.textSecondary.opacity(0.4))
                        .frame(width: 8, height: barrelHeight + 8)

                    ZStack(alignment: .leading) {
                        // Barrel background
                        RoundedRectangle(cornerRadius: 6)
                            .fill(PepTheme.elevated)
                            .frame(width: availableWidth, height: barrelHeight)

                        // Fill (clear liquid)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(colors: [PepTheme.teal.opacity(0.85), PepTheme.blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(width: max(2, availableWidth * fillFraction), height: barrelHeight)

                        // Ticks
                        TicksView(syringe: syringe, width: availableWidth, height: barrelHeight)

                        // Draw marker
                        Rectangle()
                            .fill(.white)
                            .frame(width: 2, height: barrelHeight + 14)
                            .offset(x: availableWidth * fillFraction - 1, y: 0)
                            .shadow(color: .white.opacity(0.6), radius: 3)
                    }

                    // Needle
                    Rectangle()
                        .fill(PepTheme.textSecondary.opacity(0.6))
                        .frame(width: 22, height: 2)
                }

                // Unit label above marker
                if units > 0 {
                    let xPos = barrelPadding + 8 + availableWidth * fillFraction
                    Text("\(String(format: "%.1f", unitsClamped)) u")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(PepTheme.teal, in: .capsule)
                        .position(x: min(max(xPos, 28), geo.size.width - 28), y: -6)
                }

                // Axis labels below
                axisLabels(width: availableWidth)
                    .offset(x: barrelPadding + 8, y: barrelHeight / 2 + 22)
            }
        }
    }

    private func axisLabels(width: CGFloat) -> some View {
        let totalUnits = syringe.totalUnits
        let major = syringe.majorTick
        let count = Int(totalUnits / major)
        return ZStack(alignment: .leading) {
            ForEach(0...count, id: \.self) { i in
                let u = Double(i) * major
                let frac = CGFloat(u / totalUnits)
                Text("\(Int(u))")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(PepTheme.textSecondary)
                    .position(x: width * frac, y: 0)
            }
        }
        .frame(width: width, height: 12)
    }
}

struct TicksView: View {
    let syringe: SyringeSpec
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Canvas { context, size in
            let totalUnits = syringe.totalUnits
            var u: Double = 0
            while u <= totalUnits + 0.0001 {
                let x = CGFloat(u / totalUnits) * size.width
                let isMajor = u.truncatingRemainder(dividingBy: syringe.majorTick) < 0.0001
                let tickH: CGFloat = isMajor ? size.height * 0.85 : size.height * 0.45
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height / 2 - tickH / 2))
                path.addLine(to: CGPoint(x: x, y: size.height / 2 + tickH / 2))
                context.stroke(path, with: .color(.white.opacity(isMajor ? 0.45 : 0.22)), lineWidth: isMajor ? 1.2 : 0.7)
                u += syringe.minorTick
            }
        }
        .frame(width: width, height: height)
    }
}
