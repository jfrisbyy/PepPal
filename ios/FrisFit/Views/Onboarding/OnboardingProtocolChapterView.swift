import SwiftUI
import UIKit

struct OnboardingProtocolChapterView: View {
    @Bindable var state: OnboardingState
    let onComplete: () -> Void

    @State private var subStep: Int = 0
    @State private var draftCompounds: [ProtocolCompound] = []
    @State private var showAddCompound: Bool = false
    @State private var showScanner: Bool = false
    @State private var skippedCycles: Bool = false
    @State private var preferredSites: Set<InjectionSite> = InjectionSitePreferenceStore.shared.preferredSites
    @State private var reminderStyle: ReminderStyle = ReminderManager.shared.reminderStyle
    @State private var morningBriefTime: Date = ReminderManager.shared.morningBriefTime
    @State private var doseReminderTime: Date = ReminderManager.shared.doseReminderTime
    @State private var isSaving: Bool = false

    @State private var inventoryStore = VialInventoryStore.shared
    @State private var showDowngradeConfirm: Bool = false

    private let totalSubSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            subStepIndicator
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .padding(.bottom, 12)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            footer
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .sheet(isPresented: $showAddCompound) {
            AddProtocolCompoundSheet { compound in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    draftCompounds.append(compound)
                    skippedCycles = false
                }
            }
        }
        .sheet(isPresented: $showScanner) {
            VialScannerView { scan, _ in
                handleScan(scan)
            }
        }
        .alert("Switch to Track B?", isPresented: $showDowngradeConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Switch") { downgradeToTrackB() }
        } message: {
            Text("You'll skip protocol setup and land on the curious-tracker experience. You can reactivate peptide tracking any time from a peptide surface or Settings.")
        }
    }

    // MARK: - Sub-step indicator

    private var subStepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSubSteps, id: \.self) { idx in
                Capsule()
                    .fill(idx <= subStep ? PepTheme.teal : PepTheme.elevated)
                    .frame(height: 4)
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: subStep)
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch subStep {
        case 0: activeProtocolScreen
        case 1: vialInventoryScreen
        case 2: siteRotationScreen
        default: reminderStyleScreen
        }
    }

    // MARK: - Screen 1: Active protocol

    private var activeProtocolScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                screenHeader(
                    title: "Your active protocol",
                    subtitle: "Add the compounds you're currently running. You can always edit this later from your protocol page."
                )

                if draftCompounds.isEmpty && !skippedCycles {
                    emptyCompoundsCard
                } else if skippedCycles {
                    betweenCyclesCard
                } else {
                    VStack(spacing: 10) {
                        ForEach(draftCompounds) { compound in
                            compoundRow(compound)
                        }
                    }
                }

                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    showAddCompound = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Add compound")
                            .font(.system(.headline, weight: .semibold))
                    }
                    .foregroundStyle(PepTheme.teal)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(PepTheme.teal.opacity(0.12))
                    .clipShape(.rect(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                if draftCompounds.isEmpty {
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            skippedCycles.toggle()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: skippedCycles ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18))
                                .foregroundStyle(skippedCycles ? PepTheme.teal : PepTheme.textSecondary.opacity(0.5))
                            Text("Skip — I'm between cycles")
                                .font(.system(.subheadline, weight: .medium))
                                .foregroundStyle(PepTheme.textPrimary)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(PepTheme.cardSurface.opacity(0.6))
                        .clipShape(.rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }

                if !pastCycleSummaries.isEmpty {
                    pastCyclesSection
                }

                downgradeFooter
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
    }

    private var downgradeFooter: some View {
        VStack(spacing: 6) {
            Rectangle()
                .fill(PepTheme.glassBorderBottom)
                .frame(height: 0.5)
                .padding(.vertical, 6)
            Button {
                UISelectionFeedbackGenerator().selectionChanged()
                showDowngradeConfirm = true
            } label: {
                Text("Not actually on a protocol — switch to Track B")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(PepTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    private func downgradeToTrackB() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        state.personaTrack = .B
        PeptideAccessManager.shared.setPersonaTrack(.B)
        PeptideAnalytics.onboardingChapterAbandoned(chapter: "protocol", reason: "downgrade_to_b")
        onComplete()
    }

    private var emptyCompoundsCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "syringe")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(PepTheme.teal.opacity(0.6))
            Text("No compounds added yet")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
            Text("Tap below to add your first compound or skip if you're not currently running a protocol.")
                .font(.footnote)
                .foregroundStyle(PepTheme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 18)
        .background(PepTheme.cardSurface.opacity(0.6))
        .clipShape(.rect(cornerRadius: 16))
    }

    private var betweenCyclesCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(PepTheme.amber)
            VStack(alignment: .leading, spacing: 2) {
                Text("Between cycles")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("We'll skip protocol setup. Add a cycle anytime from the protocol tab.")
                    .font(.footnote)
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(14)
        .background(PepTheme.amber.opacity(0.10))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.amber.opacity(0.25), lineWidth: 0.8)
        )
    }

    private func compoundRow(_ compound: ProtocolCompound) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(PepTheme.teal.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: "syringe.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PepTheme.teal)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(compound.compoundName)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(compoundSummary(compound))
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    draftCompounds.removeAll { $0.id == compound.id }
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(PepTheme.cardSurface.opacity(0.85))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func compoundSummary(_ compound: ProtocolCompound) -> String {
        let dose = CompoundUnitHelper.displayDoseShort(compound.doseMcg, for: compound.compoundName)
        let weeks = (state.dateOfBirth != nil) ? "" : ""
        _ = weeks
        return "\(dose) • \(compound.frequency)"
    }

    private var pastCycleSummaries: [JourneyEvent] {
        JourneyEventService.shared.events.filter {
            $0.lane == .compounds && ($0.payload?.endDate != nil || $0.durationDays == nil)
        }.prefix(3).map { $0 }
    }

    private var pastCyclesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Past cycles from your journey")
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
                .padding(.top, 8)

            ForEach(pastCycleSummaries, id: \.id) { event in
                HStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 14))
                        .foregroundStyle(PepTheme.textSecondary)
                    Text(event.title)
                        .font(.system(.footnote, weight: .medium))
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                    if let payload = event.payload, let amount = payload.doseAmount {
                        Text("\(Int(amount)) \(payload.doseUnit ?? "")")
                            .font(.caption2)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(PepTheme.elevated.opacity(0.5))
                .clipShape(.rect(cornerRadius: 10))
            }
        }
    }

    // MARK: - Screen 2: Vial inventory

    private var vialInventoryScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                screenHeader(
                    title: "Scan your vials",
                    subtitle: "Scan your vials now to populate your inventory and link them to your protocol. Or skip and add later."
                )

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showScanner = true
                } label: {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(PepTheme.teal.opacity(0.15))
                                .frame(width: 80, height: 80)
                            Image(systemName: "viewfinder")
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundStyle(PepTheme.teal)
                        }
                        Text("Open scanner")
                            .font(.system(.headline, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("Multi-angle capture, AI reads the label.")
                            .font(.footnote)
                            .foregroundStyle(PepTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .padding(.horizontal, 18)
                    .background(PepTheme.cardSurface.opacity(0.85))
                    .clipShape(.rect(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(PepTheme.teal.opacity(0.3), lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)

                if !inventoryStore.vials.isEmpty {
                    inventoryListSection
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
    }

    private var inventoryListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("In your inventory")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                Text("\(inventoryStore.vials.count)")
                    .font(.system(.footnote, weight: .bold))
                    .foregroundStyle(PepTheme.teal)
            }

            ForEach(inventoryStore.vials) { vial in
                HStack(spacing: 10) {
                    Image(systemName: "testtube.2")
                        .font(.system(size: 16))
                        .foregroundStyle(vial.statusColor)
                        .frame(width: 32, height: 32)
                        .background(vial.statusColor.opacity(0.15))
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vial.compoundName)
                            .font(.system(.footnote, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("\(Int(vial.vialSizeMg)) mg • \(vial.statusLabel)")
                            .font(.caption2)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(PepTheme.elevated.opacity(0.5))
                .clipShape(.rect(cornerRadius: 10))
            }
        }
    }

    // MARK: - Screen 3: Site rotation

    private var siteRotationScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                screenHeader(
                    title: "Where do you prefer to inject?",
                    subtitle: "Pick the sites you'd like to rotate through. We'll suggest the next site based on what you've used recently."
                )

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(InjectionSite.allCases) { site in
                        siteChip(site)
                    }
                }

                if preferredSites.isEmpty {
                    Text("Select at least one to enable smart site rotation.")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
    }

    private func siteChip(_ site: InjectionSite) -> some View {
        let isSelected = preferredSites.contains(site)
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                if isSelected {
                    preferredSites.remove(site)
                } else {
                    preferredSites.insert(site)
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? PepTheme.teal : PepTheme.textSecondary.opacity(0.4))
                Text(site.rawValue)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
            .background(isSelected ? PepTheme.teal.opacity(0.15) : PepTheme.cardSurface.opacity(0.85))
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? PepTheme.teal.opacity(0.5) : PepTheme.elevated, lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Screen 4: Reminder style

    private var reminderStyleScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                screenHeader(
                    title: "How should we remind you?",
                    subtitle: "Pick a tone for nudges. You can always change this in Settings."
                )

                VStack(spacing: 10) {
                    ForEach(ReminderStyle.allCases, id: \.self) { style in
                        reminderStyleCard(style)
                    }
                }

                if reminderStyle != .off {
                    timesCard
                        .padding(.top, 4)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
    }

    private func reminderStyleCard(_ style: ReminderStyle) -> some View {
        let isSelected = reminderStyle == style
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                reminderStyle = style
            }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? PepTheme.teal.opacity(0.18) : PepTheme.elevated.opacity(0.6))
                        .frame(width: 44, height: 44)
                    Image(systemName: style.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isSelected ? PepTheme.teal : PepTheme.textSecondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(style.title)
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(style.subtitle)
                        .font(.footnote)
                        .foregroundStyle(PepTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? PepTheme.teal : PepTheme.textSecondary.opacity(0.4))
            }
            .padding(14)
            .background(PepTheme.cardSurface.opacity(isSelected ? 0.95 : 0.65))
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        isSelected ? PepTheme.teal.opacity(0.5) : PepTheme.glassBorderBottom,
                        lineWidth: isSelected ? 1.2 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var timesCard: some View {
        VStack(spacing: 0) {
            DatePicker(
                "Morning brief",
                selection: $morningBriefTime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.compact)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)

            Rectangle().fill(PepTheme.glassBorderBottom).frame(height: 0.5)

            DatePicker(
                "Dose reminders",
                selection: $doseReminderTime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.compact)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
        }
        .background(PepTheme.cardSurface.opacity(0.85))
        .clipShape(.rect(cornerRadius: 14))
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            if subStep > 0 {
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        subStep -= 1
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .frame(width: 56, height: 54)
                        .background(PepTheme.elevated.opacity(0.7))
                        .clipShape(.rect(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }

            Button {
                advance()
            } label: {
                HStack(spacing: 8) {
                    if isSaving {
                        ProgressView().tint(.white)
                    }
                    Text(primaryCTAText)
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(primaryCTAEnabled ? PepTheme.teal : PepTheme.elevated)
                .clipShape(.rect(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(!primaryCTAEnabled || isSaving)
        }
    }

    private var primaryCTAText: String {
        switch subStep {
        case 0: return draftCompounds.isEmpty && skippedCycles ? "Continue" : (draftCompounds.isEmpty ? "Skip" : "Continue")
        case 1: return inventoryStore.vials.isEmpty ? "Skip" : "Continue"
        case 2: return preferredSites.isEmpty ? "Skip" : "Continue"
        default: return "Finish setup"
        }
    }

    private var primaryCTAEnabled: Bool {
        switch subStep {
        case 0: return !draftCompounds.isEmpty || skippedCycles || true
        default: return true
        }
    }

    private func advance() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if subStep < totalSubSteps - 1 {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                subStep += 1
            }
        } else {
            commit()
        }
    }

    // MARK: - Helpers

    private func screenHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func handleScan(_ scan: ScannedVialLabel) {
        guard !scan.compoundName.isEmpty, let mg = scan.vialSizeMg, mg > 0 else { return }
        let vial = Vial(
            compoundName: scan.compoundName,
            vialSizeMg: mg,
            lotNumber: scan.lotNumber,
            vialNumber: scan.vialNumber,
            expirationDate: scan.expirationDate,
            typicalDoseMcg: 250,
            budDays: ReconHelper.defaultBUDDays(for: scan.compoundName),
            labelImageFilename: scan.labelImageFilename
        )
        inventoryStore.add(vial)
    }

    private func commit() {
        isSaving = true
        let compounds = draftCompounds
        let sites = preferredSites
        let style = reminderStyle
        let brief = morningBriefTime
        let doseTime = doseReminderTime

        InjectionSitePreferenceStore.shared.preferredSites = sites
        ReminderManager.shared.reminderStyle = style
        ReminderManager.shared.morningBriefTime = brief
        ReminderManager.shared.doseReminderTime = doseTime
        if !compounds.isEmpty {
            ReminderManager.shared.updateActiveProtocolCompounds(compounds)
        }

        OnboardingMemorySeeder.seedProtocol(compounds: compounds, preferredSites: sites)
        Task {
            await OnboardingManager.persistProtocolChapter(
                compounds: compounds,
                preferredSites: sites,
                reminderStyle: style,
                morningBriefTime: brief,
                doseReminderTime: doseTime,
                personaTrack: state.personaTrack ?? .C
            )
            await MainActor.run {
                isSaving = false
                onComplete()
            }
        }
    }
}

// MARK: - Add compound sheet

private struct AddProtocolCompoundSheet: View {
    let onAdd: (ProtocolCompound) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var compoundName: String = ""
    @State private var doseAmountText: String = ""
    @State private var doseUnit: DoseUnit = .mcg
    @State private var frequency: FrequencyOption = .daily
    @State private var customFrequency: String = ""
    @State private var selectedDays: Set<Int> = []
    @State private var startDate: Date = Date()
    @State private var plannedWeeks: Int = 12
    @State private var showSuggestions: Bool = false

    private enum DoseUnit: String, CaseIterable, Identifiable {
        case mg, mcg, IU
        var id: String { rawValue }
    }

    private enum FrequencyOption: String, CaseIterable, Identifiable {
        case daily = "Daily"
        case eod = "Every other day"
        case weekly = "Weekly"
        case twiceWeekly = "Twice weekly"
        case custom = "Custom"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Compound") {
                    TextField("e.g. Semaglutide", text: $compoundName)
                        .textInputAutocapitalization(.words)
                        .onChange(of: compoundName) { _, newValue in
                            showSuggestions = !newValue.isEmpty && filteredSuggestions.count > 0
                        }

                    if showSuggestions {
                        ForEach(filteredSuggestions.prefix(4), id: \.name) { profile in
                            Button {
                                compoundName = profile.name
                                showSuggestions = false
                            } label: {
                                HStack {
                                    Image(systemName: profile.iconName)
                                        .foregroundStyle(PepTheme.teal)
                                    Text(profile.name)
                                        .foregroundStyle(PepTheme.textPrimary)
                                    Spacer()
                                    Text(profile.peptideType)
                                        .font(.caption)
                                        .foregroundStyle(PepTheme.textSecondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Dose") {
                    HStack {
                        TextField("Amount", text: $doseAmountText)
                            .keyboardType(.decimalPad)
                        Picker("Unit", selection: $doseUnit) {
                            ForEach(DoseUnit.allCases) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 160)
                    }
                }

                Section("Frequency") {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(FrequencyOption.allCases) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                    .pickerStyle(.menu)

                    if frequency == .custom {
                        TextField("Describe schedule", text: $customFrequency)
                    }

                    if frequency == .weekly || frequency == .twiceWeekly {
                        dayPicker
                    }
                }

                Section("Schedule") {
                    DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                    Stepper(value: $plannedWeeks, in: 1...52) {
                        HStack {
                            Text("Cycle length")
                            Spacer()
                            Text("\(plannedWeeks) weeks")
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                }
            }
            .navigationTitle("Add Compound")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addCompound()
                    }
                    .disabled(compoundName.trimmingCharacters(in: .whitespaces).isEmpty
                              || (Double(doseAmountText) ?? 0) <= 0)
                }
            }
        }
    }

    private var filteredSuggestions: [CompoundProfile] {
        let q = compoundName.lowercased()
        return CompoundDatabase.all.filter { $0.name.lowercased().contains(q) }
    }

    private var dayPicker: some View {
        let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]
        return HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { idx in
                Button {
                    if selectedDays.contains(idx) {
                        selectedDays.remove(idx)
                    } else {
                        selectedDays.insert(idx)
                    }
                } label: {
                    Text(dayLabels[idx])
                        .font(.system(.footnote, weight: .bold))
                        .foregroundStyle(selectedDays.contains(idx) ? .white : PepTheme.textPrimary)
                        .frame(width: 32, height: 32)
                        .background(selectedDays.contains(idx) ? PepTheme.teal : PepTheme.elevated)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func addCompound() {
        let amount = Double(doseAmountText) ?? 0
        let mcg: Double
        switch doseUnit {
        case .mg: mcg = amount * 1000
        case .mcg: mcg = amount
        case .IU: mcg = amount
        }
        let freqText: String
        switch frequency {
        case .custom: freqText = customFrequency.isEmpty ? "Custom" : customFrequency
        default: freqText = frequency.rawValue
        }
        let compound = ProtocolCompound(
            compoundName: compoundName.trimmingCharacters(in: .whitespaces),
            doseMcg: mcg,
            frequency: freqText,
            timeOfDay: Date()
        )
        onAdd(compound)
        dismiss()
    }
}
