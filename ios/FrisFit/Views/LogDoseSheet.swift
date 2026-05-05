import SwiftUI

struct LogDoseSheet: View {
    @Bindable var viewModel: ProtocolDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showGuided: Bool = false
    @State private var selectedVial: Vial? = nil
    @State private var showOverrideConfirm: Bool = false
    @State private var inventory = VialInventoryStore.shared

    private var availableVials: [Vial] {
        inventory.vials.filter { $0.compoundName == viewModel.newDoseCompound }
    }

    private var doseMcg: Double {
        let display = Double(viewModel.newDoseMcg) ?? 0
        return CompoundUnitHelper.toMcg(display, for: viewModel.newDoseCompound)
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
                VStack(spacing: 20) {
                    MedicalDisclaimerBanner(compact: true)
                        .padding(.horizontal)

                    guidedToggle
                        .padding(.horizontal)

                    if viewModel.protocolData.compounds.count > 1 {
                        compoundPicker
                            .padding(.horizontal)
                    }

                    doseField
                        .padding(.horizontal)

                    if !availableVials.isEmpty {
                        vialPicker
                            .padding(.horizontal)
                    }

                    sitePicker
                        .padding(.horizontal)

                    notesField
                        .padding(.horizontal)

                    if hasWarnings {
                        warningsSection
                            .padding(.horizontal)
                    }

                    Button {
                        if hasWarnings {
                            showOverrideConfirm = true
                        } else {
                            commit()
                        }
                    } label: {
                        Text("Log Dose")
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(PepTheme.invertedText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(PepTheme.teal, in: .rect(cornerRadius: 12))
                    }
                    .buttonStyle(.scalePrimary)
                    .disabled(viewModel.newDoseMcg.isEmpty)
                    .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .navigationTitle("Log Dose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
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
        }
    }

    private var guidedToggle: some View {
        Button {
            showGuided = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [PepTheme.teal, PepTheme.blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 38, height: 38)
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Guided Injection")
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Step-by-step with safety checks and timers")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(12)
            .background(PepTheme.elevated)
            .clipShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var compoundPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Compound")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)

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
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(isSelected ? PepTheme.invertedText : PepTheme.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(isSelected ? PepTheme.teal : PepTheme.elevated)
                                .clipShape(.capsule)
                        }
                    }
                }
            }
            .contentMargins(.horizontal, 0)
        }
    }

    private var doseField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Dose Amount")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)

            HStack {
                TextField("Dose", text: $viewModel.newDoseMcg)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .keyboardType(.decimalPad)
                Text(CompoundUnitHelper.unit(for: viewModel.newDoseCompound).rawValue)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(14)
            .background(PepTheme.elevated)
            .clipShape(.rect(cornerRadius: 12))

            if let hint = CompoundUnitHelper.typicalRangeHint(for: viewModel.newDoseCompound) {
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
    }

    private var vialPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Draw From Vial")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        selectedVial = nil
                    } label: {
                        Text("None")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(selectedVial == nil ? PepTheme.invertedText : PepTheme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedVial == nil ? PepTheme.teal : PepTheme.elevated)
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
                                    .font(.system(.caption, weight: .semibold))
                            }
                            .foregroundStyle(isSel ? PepTheme.invertedText : PepTheme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isSel ? PepTheme.teal : PepTheme.elevated)
                            .clipShape(.capsule)
                        }
                    }
                }
            }
            .contentMargins(.horizontal, 0)
        }
    }

    private var sitePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Injection Site")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)

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
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(isSelected ? PepTheme.invertedText : (isOverused ? PepTheme.textSecondary : PepTheme.textPrimary))
                            if isOverused && !isSelected {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isSelected ? PepTheme.teal : PepTheme.elevated.opacity(isOverused ? 0.5 : 1.0))
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
                    .font(.system(size: 12))
                    .foregroundStyle(PepTheme.teal)
                Text("Suggested: \(viewModel.suggestedNextSite.rawValue)")
                    .font(.system(.caption2, weight: .medium))
                    .foregroundStyle(PepTheme.teal)
            }
            .padding(.top, 4)
        }
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notes (Optional)")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)

            TextField("e.g., felt slight warmth at site...", text: $viewModel.newDoseNotes, axis: .vertical)
                .font(.subheadline)
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(3...5)
                .padding(12)
                .background(PepTheme.elevated)
                .clipShape(.rect(cornerRadius: 12))
        }
    }

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
            Text(text).font(.caption).foregroundStyle(PepTheme.textPrimary)
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
        // Single path: viewModel.logDose() goes through DoseLogger which deducts vial inventory once.
        viewModel.logDose(vial: selectedVial)
    }
}
