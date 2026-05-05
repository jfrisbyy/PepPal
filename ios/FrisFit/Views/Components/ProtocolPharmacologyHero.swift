import SwiftUI

/// Editorial pharmacology hero for ProtocolDetailView — bottle, current level,
/// PK chart, half-life facts, and refill action. Mirrors the old standalone
/// PeptidePharmacologyDetailView so both entry points show the same page.
struct ProtocolPharmacologyHero: View {
    let protocolData: PeptideProtocol
    @Binding var focusedCompoundName: String
    var onDoseTapped: ((PKDose, String) -> Void)? = nil

    @State private var range: PKChartRange = .sevenDay
    @State private var compareCompound: String? = nil
    @State private var showInfoSheet: Bool = false
    @State private var showRefillSheet: Bool = false
    @State private var showReconCalc: Bool = false
    @State private var showVialInventory: Bool = false
    @State private var inventory = VialInventoryStore.shared

    private var compound: ProtocolCompound? {
        protocolData.compounds.first(where: { $0.compoundName == focusedCompoundName })
            ?? protocolData.compounds.first
    }

    private var profile: PKProfile {
        PeptidePharmacology.profile(for: compound?.compoundName ?? focusedCompoundName)
    }
    private var doses: [PKDose] {
        guard let compound else { return [] }
        return PKSampleBuilder.dosesFromLog(protocolData.doseLog, compoundName: compound.compoundName)
    }
    private var primarySeries: PKSeries {
        let samples = PKSampleBuilder.samples(doses: doses, profile: profile, range: range)
        return PKSeries(
            compoundName: compound?.compoundName ?? focusedCompoundName,
            color: profile.color,
            samples: samples,
            doses: doses,
            halfLifeLabel: profile.halfLifeLabel
        )
    }
    private var compareSeries: PKSeries? {
        guard let name = compareCompound,
              let comp = protocolData.compounds.first(where: { $0.compoundName == name }) else {
            return nil
        }
        let p = PeptidePharmacology.profile(for: comp.compoundName)
        let dlist = PKSampleBuilder.dosesFromLog(protocolData.doseLog, compoundName: comp.compoundName)
        let samples = PKSampleBuilder.samples(doses: dlist, profile: p, range: range)
        return PKSeries(
            compoundName: comp.compoundName,
            color: p.color,
            samples: samples,
            doses: dlist,
            halfLifeLabel: p.halfLifeLabel
        )
    }

    private var currentLevelMg: Double {
        PeptidePharmacology.levelMg(at: Date(), doses: doses, ka: profile.ka, ke: profile.ke)
    }

    private var activeVial: Vial? {
        guard let compound else { return nil }
        return inventory.activeVials(for: compound.compoundName).first
    }
    private var fillFraction: Double {
        if let v = activeVial { return v.fillFraction }
        guard let compound, let vialMg = compound.vialSizeMg, vialMg > 0 else { return 1 }
        let usedMcg = protocolData.doseLog
            .filter { $0.compoundName == compound.compoundName && !$0.wasSkipped }
            .reduce(0.0) { $0 + $1.doseMcg }
        return max(0, min(1, 1 - (usedMcg / 1000.0) / vialMg))
    }
    private var mgRemaining: Double {
        if let v = activeVial { return v.mcgRemaining / 1000.0 }
        guard let compound, let vialMg = compound.vialSizeMg else { return 0 }
        return vialMg * fillFraction
    }
    private var dosesRemaining: Int {
        if let v = activeVial { return v.dosesRemaining }
        let dose = (compound?.doseMcg ?? 0) > 0 ? (compound?.doseMcg ?? 250) : 250
        return Int((mgRemaining * 1000) / dose)
    }
    private var supplyForecast: SupplyForecast? {
        guard let compound else { return nil }
        return SupplyForecastService.forecast(for: compound, in: protocolData)
    }

    var body: some View {
        VStack(spacing: 14) {
            if protocolData.compounds.count > 1 {
                compoundSwitcher
            }
            heroCard
            rangeSelector
            chartCard
            if protocolData.compounds.count > 1 {
                comparePicker
            }
            halfLifeFactsRow
            if let v = activeVial {
                vialMetadataCard(v)
            }
        }
        .sheet(isPresented: $showInfoSheet) {
            PKInfoSheet(profile: profile)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showRefillSheet) {
            RefillActionSheet(
                compoundName: compound?.compoundName ?? focusedCompoundName,
                vialSizeMg: compound?.vialSizeMg,
                onOpenInventory: {
                    showRefillSheet = false
                    showVialInventory = true
                },
                onOpenReconCalc: {
                    showRefillSheet = false
                    showReconCalc = true
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showVialInventory) {
            NavigationStack { VialInventoryView() }
        }
        .sheet(isPresented: $showReconCalc) {
            ReconstitutionCalculatorView(
                initialCompound: compound?.compoundName,
                initialVialSizeMg: compound?.vialSizeMg
            )
        }
    }

    // MARK: - Compound switcher

    private var compoundSwitcher: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(protocolData.compounds) { c in
                    let selected = c.compoundName == focusedCompoundName
                    let color = PeptidePharmacology.accentColor(for: c.compoundName)
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                            focusedCompoundName = c.compoundName
                            if compareCompound == c.compoundName { compareCompound = nil }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Circle().fill(color).frame(width: 7, height: 7)
                            Text(c.compoundName)
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(selected ? .white : PepTheme.textPrimary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(selected ? color : PepTheme.elevated.opacity(0.6))
                        .clipShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: focusedCompoundName)
                }
            }
        }
        .contentMargins(.horizontal, 0)
    }

    // MARK: - Hero card

    private var heroCard: some View {
        HStack(spacing: 16) {
            PeptideBottleView(
                fillFraction: fillFraction,
                liquidColor: profile.color,
                compactHeight: 180
            )
            .frame(width: 110)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(compound?.compoundName ?? focusedCompoundName)
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    Button { showInfoSheet = true } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(profile.color)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text("Half-life · \(profile.halfLifeLabel)")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                }
                .foregroundStyle(PepTheme.textSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Current level")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Text(formatMg(currentLevelMg))
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                        .foregroundStyle(profile.color)
                        .contentTransition(.numericText())
                }
                .padding(.top, 2)

                supplySummary
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [profile.color.opacity(0.10), PepTheme.cardSurface.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(.rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(profile.color.opacity(0.20), lineWidth: 0.8)
        )
    }

    @ViewBuilder
    private var supplySummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(formatMg(mgRemaining))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("·")
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                Text("\(Int(round(fillFraction * 100)))% full")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(profile.color)
            }
            HStack(spacing: 6) {
                Text("\(dosesRemaining) doses")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                if let f = supplyForecast, f.daysRemaining < 999 {
                    Text("· \(f.daysRemaining)d left")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            Button {
                showRefillSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11, weight: .bold))
                    Text("Refill")
                        .font(.system(.caption, weight: .bold))
                }
                .foregroundStyle(profile.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(profile.color.opacity(0.14))
                .clipShape(.capsule)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    // MARK: - Range selector

    private var rangeSelector: some View {
        HStack(spacing: 0) {
            ForEach(PKChartRange.allCases) { r in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        range = r
                    }
                } label: {
                    Text(r.rawValue)
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(range == r ? .white : PepTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(range == r ? profile.color : Color.clear)
                        .clipShape(.capsule)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: range)
            }
        }
        .padding(3)
        .background(PepTheme.elevated.opacity(0.6))
        .clipShape(.capsule)
    }

    // MARK: - Chart card

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("MEDICATION LEVEL")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .tracking(0.8)
                Spacer()
                Text(profile.compoundName)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(profile.color)
            }
            PeptideMedicationChart(
                primary: primarySeries,
                comparison: compareSeries,
                range: range,
                height: 220,
                onDoseTapped: { dose in
                    let name = compound?.compoundName ?? focusedCompoundName
                    onDoseTapped?(dose, name)
                }
            )
            if doses.isEmpty {
                Text("Log a dose to see your medication-level curve.")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                    .padding(.top, 4)
            }
        }
        .padding(14)
        .background(PepTheme.cardSurface.opacity(0.6))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    // MARK: - Compare picker

    private var comparePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("COMPARE WITH")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .tracking(0.8)
                Spacer()
                if compareCompound != nil {
                    Button("Clear") { compareCompound = nil }
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(protocolData.compounds.filter { $0.compoundName != focusedCompoundName }) { other in
                        let selected = compareCompound == other.compoundName
                        let otherColor = PeptidePharmacology.accentColor(for: other.compoundName)
                        Button {
                            compareCompound = selected ? nil : other.compoundName
                        } label: {
                            HStack(spacing: 6) {
                                Circle().fill(otherColor).frame(width: 7, height: 7)
                                Text(other.compoundName)
                                    .font(.system(.caption, weight: .semibold))
                                    .foregroundStyle(selected ? .white : PepTheme.textPrimary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selected ? otherColor : PepTheme.elevated.opacity(0.6))
                            .clipShape(.capsule)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .contentMargins(.horizontal, 0)
        }
    }

    // MARK: - Half-life facts row

    private var halfLifeFactsRow: some View {
        HStack(spacing: 10) {
            factTile(label: "Half-life", value: profile.halfLifeLabel, icon: "clock.fill")
            factTile(label: "Doses logged", value: "\(doses.count)", icon: "syringe.fill")
            factTile(label: "Peak today", value: peakTodayLabel(), icon: "chart.line.uptrend.xyaxis")
        }
    }

    private func factTile(label: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(profile.color)
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(PepTheme.elevated.opacity(0.5))
        .clipShape(.rect(cornerRadius: 12))
    }

    private func peakTodayLabel() -> String {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? Date()
        let samples = primarySeries.samples.filter { $0.time >= start && $0.time <= end }
        let peak = samples.map(\.mg).max() ?? 0
        return formatMg(peak)
    }

    private func vialMetadataCard(_ v: Vial) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ACTIVE VIAL")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(PepTheme.textSecondary)
                .tracking(0.8)
            HStack {
                metaCol(label: "Strength", value: "\(formatNum(v.vialSizeMg)) mg")
                metaCol(label: "Status", value: v.statusLabel)
                metaCol(label: "Storage", value: v.storage.rawValue)
            }
        }
        .padding(14)
        .background(PepTheme.cardSurface.opacity(0.6))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private func metaCol(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatMg(_ mg: Double) -> String {
        if mg >= 1 { return String(format: "%.2f mg", mg) }
        if mg >= 0.005 { return String(format: "%.3f mg", mg) }
        let mcg = mg * 1000
        return String(format: "%.0f mcg", mcg)
    }

    private func formatNum(_ x: Double) -> String {
        x == x.rounded() ? String(Int(x)) : String(format: "%.2f", x)
    }
}

// MARK: - Info sheet

struct PKInfoSheet: View {
    let profile: PKProfile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    section(
                        title: "What is the medication-level curve?",
                        body: "It's a model of how much \(profile.compoundName) is in your body over time, based on every dose you've logged. The curve rises after each dose as the peptide is absorbed, then falls as it's eliminated."
                    )
                    section(
                        title: "How is it calculated?",
                        body: "EPTI uses a Bateman one-compartment pharmacokinetic model — the same model clinical pharmacologists use. For each logged dose:\n\nC(t) = (F · D · ka / (ka − ke)) · (e^(−ke·t) − e^(−ka·t))\n\nThe contributions of every dose are summed."
                    )
                    section(
                        title: "Half-life",
                        body: "\(profile.compoundName) has a half-life of \(profile.halfLifeLabel). After each half-life, the level drops by 50%. Elimination rate ke = ln(2) / half-life ≈ \(String(format: "%.3f", profile.ke)) per hour. Absorption rate ka ≈ \(String(format: "%.3f", profile.ka)) per hour."
                    )
                    section(
                        title: "Dotted projection",
                        body: "The dotted future segment assumes you don't dose again. Log additional doses and the curve updates instantly."
                    )
                    section(
                        title: "Important",
                        body: "This is an educational model, not a medical measurement. Real pharmacokinetics vary by individual, injection site, body composition, and many other factors. Don't use this curve to make medical decisions."
                    )
                }
                .padding()
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .navigationTitle("How this works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(profile.color)
                }
            }
        }
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
                .lineSpacing(3)
        }
    }
}

// MARK: - Refill sheet

struct RefillActionSheet: View {
    let compoundName: String
    let vialSizeMg: Double?
    let onOpenInventory: () -> Void
    let onOpenReconCalc: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                row(title: "Open Vial Inventory",
                    subtitle: "Add a new vial or reconstitute an existing one",
                    icon: "testtube.2",
                    color: PepTheme.violet,
                    action: onOpenInventory)
                row(title: "Reconstitution Calculator",
                    subtitle: "Mix BAC water for a fresh \(compoundName) vial",
                    icon: "function",
                    color: PepTheme.blue,
                    action: onOpenReconCalc)
                Spacer()
            }
            .padding()
            .appBackground()
            .navigationTitle("Refill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }

    private func row(title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(color.opacity(0.16)).frame(width: 40, height: 40)
                    Image(systemName: icon).foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(14)
            .background(PepTheme.cardSurface.opacity(0.6))
            .clipShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
