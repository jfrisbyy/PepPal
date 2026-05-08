import SwiftUI

struct LogDoseSheet: View {
    @Bindable var viewModel: ProtocolDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showGuided: Bool = false
    @State private var selectedVial: Vial? = nil
    @State private var showOverrideConfirm: Bool = false
    @State private var inventory = VialInventoryStore.shared
    @State private var pulseGlow: Bool = false
    @FocusState private var doseFieldFocused: Bool
    @FocusState private var notesFieldFocused: Bool

    private let accent: Color = PepTheme.teal

    private var availableVials: [Vial] {
        inventory.vials.filter { $0.compoundName == viewModel.newDoseCompound }
    }

    private var doseMcg: Double {
        let display = Double(viewModel.newDoseMcg) ?? 0
        return CompoundUnitHelper.toMcg(display, for: viewModel.newDoseCompound)
    }

    /// Concentration in mcg/mL, derived from the selected vial first,
    /// then falling back to the protocol compound spec.
    private var concentrationMcgPerMl: Double? {
        if let v = selectedVial, let ml = v.diluentMl, ml > 0, v.vialSizeMg > 0 {
            return (v.vialSizeMg * 1000) / ml
        }
        if let c = viewModel.protocolData.compounds.first(where: { $0.compoundName == viewModel.newDoseCompound }),
           let mg = c.vialSizeMg, let ml = c.reconstitutionVolume, mg > 0, ml > 0 {
            return (mg * 1000) / ml
        }
        // Try any vial of this compound that has been reconstituted.
        if let v = availableVials.first(where: { ($0.diluentMl ?? 0) > 0 }),
           let ml = v.diluentMl, ml > 0, v.vialSizeMg > 0 {
            return (v.vialSizeMg * 1000) / ml
        }
        return nil
    }

    private var drawMl: Double? {
        guard let conc = concentrationMcgPerMl, conc > 0, doseMcg > 0 else { return nil }
        return doseMcg / conc
    }

    /// Units on a U-100 0.5 mL syringe (standard insulin syringe).
    private var drawUnits: Double? {
        drawMl.map { $0 * 100 }
    }

    private var doseOutOfRange: Bool {
        guard let hint = CompoundUnitHelper.typicalRangeHint(for: viewModel.newDoseCompound) else { return false }
        let numbers = hint.matches(of: /\d+(?:\.\d+)?/).compactMap { Double($0.output) }
        guard numbers.count >= 2 else { return false }
        let isMg = hint.lowercased().contains("mg") && !hint.lowercased().contains("mcg")
        let factor = isMg ? 1000.0 : 1.0
        let lower = numbers[0] * factor
        let upper = numbers[1] * factor
        return doseMcg < lower * 0.5 || doseMcg > upper * 1.5
    }

    private var siteOverused: Bool {
        viewModel.siteRecency(viewModel.newDoseSite) == .overused
    }

    private var vialExpired: Bool {
        selectedVial?.isExpired ?? false
    }

    private var hasWarnings: Bool {
        doseOutOfRange || siteOverused || vialExpired
    }

    var body: some View {
        if PeptideAccessManager.shared.shouldShowTrackAEmptyState {
            NavigationStack {
                TrackAEmptyStateView(
                    surface: .doseLog,
                    icon: "syringe",
                    title: "Log every dose",
                    blurb: "Tracking peptides? EPTI logs each dose with site rotation, vial linkage, and side-effect capture so the AI can spot patterns."
                )
                .navigationTitle("Log Dose")
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
            doseSheetBody
        }
    }

    @ViewBuilder
    private var doseSheetBody: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    editorialHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 4)

                    MedicalDisclaimerBanner(compact: true)
                        .padding(.horizontal, 20)

                    guidedToggle
                        .padding(.horizontal, 20)

                    if viewModel.protocolData.compounds.count > 1 {
                        compoundSection
                            .padding(.horizontal, 20)
                    }

                    doseSection
                        .padding(.horizontal, 20)

                    drawCalculatorSection
                        .padding(.horizontal, 20)

                    if !availableVials.isEmpty {
                        vialSection
                            .padding(.horizontal, 20)
                    }

                    siteSection
                        .padding(.horizontal, 20)

                    notesSection
                        .padding(.horizontal, 20)

                    if hasWarnings {
                        warningsSection
                            .padding(.horizontal, 20)
                    }

                    EditorialPrimaryButton(
                        "Log Dose",
                        icon: "checkmark.seal.fill",
                        accent: accent
                    ) {
                        if hasWarnings {
                            showOverrideConfirm = true
                        } else {
                            commit()
                        }
                    }
                    .disabled(viewModel.newDoseMcg.isEmpty)
                    .opacity(viewModel.newDoseMcg.isEmpty ? 0.4 : 1.0)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                }
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        doseFieldFocused = false
                        notesFieldFocused = false
                    }
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(accent)
                }
            }
            .fullScreenCover(isPresented: $showGuided) {
                GuidedInjectionView(viewModel: viewModel)
            }
            .confirmationDialog(
                "Continue anyway?",
                isPresented: $showOverrideConfirm,
                titleVisibility: .visible
            ) {
                Button("Log Anyway", role: .destructive) { commit() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(warningsSummary)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    pulseGlow = true
                }
            }
        }
    }

    // MARK: - Header

    private var editorialHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("THE LOG")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(2.0)
                    .foregroundStyle(accent.opacity(0.85))
                Rectangle()
                    .fill(LinearGradient(colors: [accent.opacity(0.4), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 0.5)
            }
            Text("Log a dose")
                .font(.system(size: 32, weight: .semibold, design: .serif))
                .kerning(-0.5)
                .foregroundStyle(PepTheme.textPrimary)
            Text("A precise, calm record — your numbers, your syringe, your story.")
                .font(.system(size: 13, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Guided Toggle

    private var guidedToggle: some View {
        Button {
            showGuided = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [accent, PepTheme.blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 38, height: 38)
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Guided Injection")
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Step-by-step with safety checks and timers")
                        .font(.system(size: 12, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .editorialCard(accent: accent)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Compound

    private var compoundSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "01 — Compound", title: "Which one tonight?", accent: accent)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.protocolData.compounds) { compound in
                        let isSelected = viewModel.newDoseCompound == compound.compoundName
                        Button {
                            viewModel.newDoseCompound = compound.compoundName
                            let displayVal = CompoundUnitHelper.fromMcg(compound.doseMcg, for: compound.compoundName)
                            viewModel.newDoseMcg = displayVal == displayVal.rounded() && displayVal >= 1 ? String(Int(displayVal)) : String(format: "%.2g", displayVal)
                            selectedVial = nil
                        } label: {
                            Text(compound.compoundName)
                                .font(.system(size: 13, weight: .semibold, design: .serif))
                                .foregroundStyle(isSelected ? .black : PepTheme.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(isSelected ? accent : PepTheme.elevated)
                                .clipShape(.capsule)
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
            .contentMargins(.horizontal, 0)
        }
        .editorialCard(accent: accent)
    }

    // MARK: - Dose

    private var doseSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "02 — Dose", title: "Tonight's amount", accent: accent)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TextField("0", text: $viewModel.newDoseMcg)
                    .focused($doseFieldFocused)
                    .font(.system(size: 44, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                    .keyboardType(.decimalPad)
                Text(CompoundUnitHelper.unit(for: viewModel.newDoseCompound).rawValue)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
            }
            .padding(.vertical, 4)

            Rectangle()
                .fill(LinearGradient(colors: [accent.opacity(0.4), .clear], startPoint: .leading, endPoint: .trailing))
                .frame(height: 0.5)

            if let hint = CompoundUnitHelper.typicalRangeHint(for: viewModel.newDoseCompound) {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(PepTheme.textSecondary)
                    Text(hint)
                        .font(.system(size: 12, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
        .editorialCard(accent: accent)
    }

    // MARK: - Draw Calculator

    private var drawCalculatorSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "03 — The Draw",
                title: "Pull to this mark",
                accent: accent
            )

            if let units = drawUnits, let ml = drawMl, doseMcg > 0 {
                drawNumbersRow(units: units, ml: ml)
                syringeVisual(units: units)
                howToReadIt(units: units)
            } else {
                noConcentrationState
            }
        }
        .editorialCard(accent: accent)
    }

    private func drawNumbersRow(units: Double, ml: Double) -> some View {
        HStack(spacing: 0) {
            drawStat(label: "DOSE", value: formatDose(doseMcg), highlight: false)
            drawDivider
            drawStat(label: "DRAW TO", value: "\(formatNum(units)) u", highlight: true)
            drawDivider
            drawStat(label: "VOLUME", value: "\(String(format: "%.2f", ml)) mL", highlight: false)
        }
    }

    private var drawDivider: some View {
        Rectangle()
            .fill(PepTheme.separatorColor)
            .frame(width: 0.5, height: 30)
            .padding(.horizontal, 6)
    }

    private func drawStat(label: String, value: String, highlight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .heavy))
                .tracking(1.4)
                .foregroundStyle(PepTheme.textSecondary)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(highlight ? accent : PepTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func syringeVisual(units: Double) -> some View {
        let capacity: Double = 50 // U-100 0.5 mL syringe (50 units)
        let majorTick: Double = 10
        let minorTick: Double = 1

        return VStack(alignment: .leading, spacing: 8) {
            Text("U-100 INSULIN SYRINGE — 0.5 mL")
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)

            GeometryReader { geo in
                let width = geo.size.width
                let drawFraction = min(1.0, max(0.02, units / capacity))
                let fillWidth = width * CGFloat(drawFraction)
                let labelOffsetX = max(0, min(width - 56, fillWidth - 28))

                ZStack(alignment: .leading) {
                    // barrel background
                    RoundedRectangle(cornerRadius: 10)
                        .fill(PepTheme.elevated)
                        .frame(height: 56)

                    // fluid
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.85), PepTheme.blue.opacity(0.7)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: fillWidth, height: 56)

                    // ticks
                    Canvas { ctx, size in
                        let count = Int(capacity / minorTick)
                        for i in 0...count {
                            let unit = Double(i) * minorTick
                            let x = CGFloat(unit / capacity) * size.width
                            let isMajor = unit.truncatingRemainder(dividingBy: majorTick) == 0
                            let h: CGFloat = isMajor ? 14 : 6
                            let rect = CGRect(x: x, y: 0, width: 0.8, height: h)
                            ctx.fill(Path(rect), with: .color(.white.opacity(isMajor ? 0.85 : 0.4)))
                        }
                    }
                    .frame(height: 56)

                    // draw-to indicator line
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2.5, height: 78)
                        .shadow(color: accent.opacity(pulseGlow ? 0.95 : 0.35), radius: pulseGlow ? 12 : 4)
                        .offset(x: fillWidth - 1.25, y: -11)

                    // floating number plate above the indicator
                    VStack(spacing: 1) {
                        Text(formatNum(units))
                            .font(.system(size: 14, weight: .heavy, design: .serif))
                            .foregroundStyle(.white)
                        Text("units")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(0.5)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accent, in: .rect(cornerRadius: 6))
                    .shadow(color: accent.opacity(0.4), radius: 6, y: 2)
                    .offset(x: labelOffsetX, y: -56)
                }
                // needle on the right edge
                .overlay(alignment: .trailing) {
                    HStack(spacing: 0) {
                        Rectangle().fill(PepTheme.textSecondary.opacity(0.4)).frame(width: 6, height: 4)
                        Rectangle().fill(PepTheme.textSecondary.opacity(0.7)).frame(width: 24, height: 1.5)
                    }
                    .offset(x: 28, y: 0)
                }
            }
            .frame(height: 78)
            .padding(.top, 22)

            // baseline scale
            HStack {
                ForEach([0, 10, 20, 30, 40, 50], id: \.self) { mark in
                    Text("\(mark)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                    if mark != 50 { Spacer() }
                }
            }
            .padding(.trailing, 30)
        }
    }

    private func howToReadIt(units: Double) -> some View {
        let snapped = (units / 1.0).rounded()
        let off = abs(snapped - units)
        return VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(height: 0.5)
                .padding(.vertical, 2)

            if off < 0.05 {
                bullet("Line up the plunger exactly with the **\(formatNum(units))** mark.")
            } else {
                bullet("Closest mark: **\(formatNum(snapped)) u** — split the gap to hit \(formatNum(units)).")
            }
            bullet("Tap the barrel to pop any air bubbles, then re-check the line.")
            if let conc = concentrationMcgPerMl {
                bullet("Concentration: **\(formatConcentration(conc))** — based on your vial.")
            }
        }
    }

    private var noConcentrationState: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "flask.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(accent.opacity(0.8))
                VStack(alignment: .leading, spacing: 4) {
                    Text("No reconstitution data yet")
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Add vial size + diluent on the protocol or vial to see exact units to draw.")
                        .font(.system(size: 12, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(accent.opacity(0.08))
            .clipShape(.rect(cornerRadius: 12))
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(accent)
                .frame(width: 4, height: 4)
                .padding(.top, 7)
            Text(.init(text))
                .font(.system(size: 13, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Vial

    private var vialSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "04 — Vial", title: "Drawn from", accent: accent)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        selectedVial = nil
                    } label: {
                        Text("None")
                            .font(.system(size: 12, weight: .semibold, design: .serif))
                            .foregroundStyle(selectedVial == nil ? .black : PepTheme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedVial == nil ? accent : PepTheme.elevated)
                            .clipShape(.capsule)
                    }
                    ForEach(availableVials) { vial in
                        let isSel = selectedVial?.id == vial.id
                        Button {
                            selectedVial = vial
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(vial.statusColor)
                                    .frame(width: 7, height: 7)
                                Text("\(vial.dosesRemaining) left")
                                    .font(.system(size: 12, weight: .semibold, design: .serif))
                            }
                            .foregroundStyle(isSel ? .black : PepTheme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isSel ? accent : PepTheme.elevated)
                            .clipShape(.capsule)
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
            .contentMargins(.horizontal, 0)
        }
        .editorialCard(accent: accent)
    }

    // MARK: - Site

    private var siteSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "05 — Site", title: "Where it lands", accent: PepTheme.violet)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(InjectionSite.allCases) { site in
                    let isSelected = viewModel.newDoseSite == site
                    let recency = viewModel.siteRecency(site)
                    let isOverused = recency == .overused
                    Button {
                        viewModel.newDoseSite = site
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(recency.color)
                                .frame(width: 8, height: 8)
                            Text(site.shortName)
                                .font(.system(size: 12, weight: .semibold, design: .serif))
                                .foregroundStyle(isSelected ? .black : (isOverused ? PepTheme.textSecondary : PepTheme.textPrimary))
                            if isOverused && !isSelected {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isSelected ? PepTheme.violet : PepTheme.elevated.opacity(isOverused ? 0.5 : 1.0))
                        .clipShape(.rect(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(isOverused && !isSelected ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
                        )
                    }
                    .opacity(isOverused && !isSelected ? 0.6 : 1.0)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(PepTheme.violet)
                Text("Suggested: \(viewModel.suggestedNextSite.rawValue)")
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.violet)
            }
        }
        .editorialCard(accent: PepTheme.violet)
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "06 — Notes", title: "Anything to remember?", accent: PepTheme.amber)

            TextField("e.g., felt a slight warmth at the site…", text: $viewModel.newDoseNotes, axis: .vertical)
                .focused($notesFieldFocused)
                .font(.system(size: 14, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(3...5)
                .padding(12)
                .background(PepTheme.elevated.opacity(0.6))
                .clipShape(.rect(cornerRadius: 10))
        }
        .editorialCard(accent: PepTheme.amber)
    }

    // MARK: - Warnings

    private var warningsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if siteOverused {
                warningRow(color: .red, icon: "exclamationmark.triangle.fill", text: "Site was used in the last 3 days — consider rotating.")
            }
            if doseOutOfRange {
                warningRow(color: PepTheme.amber, icon: "exclamationmark.circle.fill", text: "Dose is outside the typical range for this compound.")
            }
            if vialExpired {
                warningRow(color: .red, icon: "hourglass.bottomhalf.filled", text: "Selected vial is past its Beyond-Use Date.")
            }
        }
    }

    private func warningRow(color: Color, icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(color)
            Text(text)
                .font(.system(size: 13, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
            Spacer()
        }
        .padding(10)
        .background(color.opacity(0.1))
        .clipShape(.rect(cornerRadius: 10))
    }

    private var warningsSummary: String {
        var msgs: [String] = []
        if siteOverused { msgs.append("• Site was used recently") }
        if doseOutOfRange { msgs.append("• Dose is outside typical range") }
        if vialExpired { msgs.append("• Vial is past BUD") }
        return msgs.joined(separator: "\n")
    }

    private func commit() {
        viewModel.logDose(vial: selectedVial)
    }

    // MARK: - Formatters

    private func formatNum(_ d: Double) -> String {
        if abs(d - d.rounded()) < 0.05 { return String(Int(d.rounded())) }
        return String(format: "%.1f", d)
    }

    private func formatDose(_ mcg: Double) -> String {
        if mcg >= 1000 {
            let mg = mcg / 1000
            return mg == mg.rounded() ? "\(Int(mg)) mg" : String(format: "%.2f mg", mg)
        }
        if mcg == mcg.rounded() { return "\(Int(mcg)) mcg" }
        return String(format: "%.1f mcg", mcg)
    }

    private func formatConcentration(_ mcgPerMl: Double) -> String {
        // Show as mg/mL if >= 1000 mcg/mL
        if mcgPerMl >= 1000 {
            let mgPerMl = mcgPerMl / 1000
            return mgPerMl == mgPerMl.rounded() ? "\(Int(mgPerMl)) mg/mL" : String(format: "%.2f mg/mL", mgPerMl)
        }
        return "\(Int(mcgPerMl)) mcg/mL"
    }
}
