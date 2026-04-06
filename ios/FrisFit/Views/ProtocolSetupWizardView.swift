import SwiftUI

struct ProtocolSetupWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep: Int = 0
    @State private var selectedGoal: ProtocolGoal?
    @State private var protocolName: String = ""
    @State private var selectedCompounds: [WizardCompound] = []
    @State private var cycleWeeks: Int = 8
    @State private var loadingWeeks: Int = 1
    @State private var maintenanceWeeks: Int = 5
    @State private var taperingWeeks: Int = 1
    @State private var offCycleWeeks: Int = 4
    let onComplete: (PeptideProtocol) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar

                ScrollView {
                    VStack(spacing: 20) {
                        switch currentStep {
                        case 0: goalStep
                        case 1: compoundStep
                        case 2: scheduleStep
                        case 3: reviewStep
                        default: EmptyView()
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)

                bottomBar
            }
            .background(PepTheme.background.ignoresSafeArea())
            .navigationTitle("New Protocol")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { step in
                RoundedRectangle(cornerRadius: 2)
                    .fill(step <= currentStep ? PepTheme.teal : PepTheme.elevated)
                    .frame(height: 4)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's your goal?")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)

            Text("This helps us suggest compounds and protocol structures")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)

            VStack(spacing: 10) {
                ForEach(ProtocolGoal.allCases) { goal in
                    let isSelected = selectedGoal == goal
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedGoal = goal
                        }
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(goal.color.opacity(isSelected ? 0.2 : 0.1))
                                    .frame(width: 48, height: 48)

                                Image(systemName: goal.icon)
                                    .font(.title3)
                                    .foregroundStyle(goal.color)
                            }

                            Text(goal.rawValue)
                                .font(.system(.body, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(PepTheme.teal)
                            }
                        }
                        .padding(14)
                        .background(PepTheme.cardSurface.overlay(isSelected ? PepTheme.teal.opacity(0.05) : Color.clear))
                        .clipShape(.rect(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(isSelected ? PepTheme.teal : PepTheme.glassBorderTop, lineWidth: isSelected ? 1.5 : 0.5)
                        )
                    }
                    .sensoryFeedback(.selection, trigger: selectedGoal)
                }
            }

            Button {
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                    Text("Not sure yet? Explore our research library")
                        .font(.system(.subheadline, weight: .medium))
                }
                .foregroundStyle(PepTheme.teal)
            }
            .padding(.top, 8)
        }
        .padding(.top, 8)
    }

    private var compoundStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Compounds")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)

            Text("Choose the compounds for your protocol")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)

            let suggested = suggestedCompounds
            if !suggested.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggested for \(selectedGoal?.rawValue ?? "your goal")")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.teal)

                    ForEach(suggested) { compound in
                        compoundRow(compound)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("All Compounds")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)

                ForEach(CompoundDatabase.all) { compound in
                    if !suggested.contains(where: { $0.id == compound.id }) {
                        compoundRow(compound)
                    }
                }
            }

            if !selectedCompounds.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected (\(selectedCompounds.count))")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.teal)

                    ForEach(selectedCompounds) { wc in
                        HStack(spacing: 10) {
                            Text(wc.name)
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)

                            Spacer()

                            TextField("mcg", text: Binding(
                                get: { wc.doseText },
                                set: { newVal in
                                    if let idx = selectedCompounds.firstIndex(where: { $0.id == wc.id }) {
                                        selectedCompounds[idx].doseText = newVal
                                    }
                                }
                            ))
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(PepTheme.elevated)
                            .clipShape(.rect(cornerRadius: 8))

                            Text("mcg")
                                .font(.caption)
                                .foregroundStyle(PepTheme.textSecondary)

                            Button {
                                selectedCompounds.removeAll { $0.id == wc.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                        }
                        .padding(10)
                        .background(PepTheme.teal.opacity(0.05))
                        .clipShape(.rect(cornerRadius: 10))
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    private func compoundRow(_ compound: CompoundProfile) -> some View {
        let isAdded = selectedCompounds.contains { $0.name == compound.name }
        return Button {
            if isAdded {
                selectedCompounds.removeAll { $0.name == compound.name }
            } else {
                selectedCompounds.append(WizardCompound(name: compound.name))
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: compound.iconName)
                    .font(.subheadline)
                    .foregroundStyle(compound.categories.first?.color ?? PepTheme.teal)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(compound.name)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(compound.peptideType)
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary)
                }

                Spacer()

                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isAdded ? PepTheme.teal : PepTheme.textSecondary)
            }
            .padding(10)
            .background(isAdded ? PepTheme.teal.opacity(0.05) : Color.clear)
            .clipShape(.rect(cornerRadius: 10))
        }
        .sensoryFeedback(.impact(weight: .light), trigger: isAdded)
    }

    private var scheduleStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cycle Schedule")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Protocol Name")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                TextField("e.g. BPC-157 Recovery", text: $protocolName)
                    .font(.body)
                    .foregroundStyle(PepTheme.textPrimary)
                    .padding(12)
                    .background(PepTheme.elevated)
                    .clipShape(.rect(cornerRadius: 12))
            }

            VStack(spacing: 12) {
                phaseStepper(label: "Loading Phase", value: $loadingWeeks, color: CyclePhase.loading.color, range: 0...4)
                phaseStepper(label: "Maintenance Phase", value: $maintenanceWeeks, color: CyclePhase.maintenance.color, range: 1...20)
                phaseStepper(label: "Tapering Phase", value: $taperingWeeks, color: CyclePhase.tapering.color, range: 0...4)
                phaseStepper(label: "Off-Cycle", value: $offCycleWeeks, color: CyclePhase.offCycle.color, range: 0...12)
            }

            phaseTimeline
        }
        .padding(.top, 8)
    }

    private func phaseStepper(label: String, value: Binding<Int>, color: Color, range: ClosedRange<Int>) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(PepTheme.textPrimary)

            Spacer()

            HStack(spacing: 12) {
                Button {
                    if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(PepTheme.textSecondary)
                }

                Text("\(value.wrappedValue)w")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .frame(width: 32)

                Button {
                    if value.wrappedValue < range.upperBound { value.wrappedValue += 1 }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(PepTheme.teal)
                }
            }
        }
        .padding(12)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 12))
    }

    private var phaseTimeline: some View {
        let total = max(1, loadingWeeks + maintenanceWeeks + taperingWeeks + offCycleWeeks)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Timeline Preview")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)

            GeometryReader { geo in
                HStack(spacing: 2) {
                    if loadingWeeks > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(CyclePhase.loading.color)
                            .frame(width: geo.size.width * CGFloat(loadingWeeks) / CGFloat(total))
                    }
                    if maintenanceWeeks > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(CyclePhase.maintenance.color)
                            .frame(width: geo.size.width * CGFloat(maintenanceWeeks) / CGFloat(total))
                    }
                    if taperingWeeks > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(CyclePhase.tapering.color)
                            .frame(width: geo.size.width * CGFloat(taperingWeeks) / CGFloat(total))
                    }
                    if offCycleWeeks > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(CyclePhase.offCycle.color)
                            .frame(width: geo.size.width * CGFloat(offCycleWeeks) / CGFloat(total))
                    }
                }
            }
            .frame(height: 12)

            Text("\(total) weeks total")
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
    }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Review Protocol")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)

            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(protocolName.isEmpty ? "My Protocol" : protocolName)
                            .font(.system(.headline, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Spacer()
                        if let goal = selectedGoal {
                            HStack(spacing: 4) {
                                Image(systemName: goal.icon)
                                    .font(.system(size: 11))
                                Text(goal.rawValue)
                                    .font(.system(.caption, weight: .semibold))
                            }
                            .foregroundStyle(goal.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(goal.color.opacity(0.12))
                            .clipShape(.capsule)
                        }
                    }

                    Divider().overlay(PepTheme.separatorColor)

                    ForEach(selectedCompounds) { wc in
                        HStack {
                            Image(systemName: "pill.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(PepTheme.teal)
                            Text(wc.name)
                                .font(.system(.subheadline, weight: .medium))
                                .foregroundStyle(PepTheme.textPrimary)
                            Spacer()
                            Text("\(wc.doseText.isEmpty ? "—" : wc.doseText) mcg")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }

                    Divider().overlay(PepTheme.separatorColor)

                    let total = loadingWeeks + maintenanceWeeks + taperingWeeks + offCycleWeeks
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Total Duration")
                                .font(.caption2)
                                .foregroundStyle(PepTheme.textSecondary)
                            Text("\(total) weeks")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(PepTheme.textPrimary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Compounds")
                                .font(.caption2)
                                .foregroundStyle(PepTheme.textSecondary)
                            Text("\(selectedCompounds.count)")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(PepTheme.textPrimary)
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "figure.run")
                    .foregroundStyle(PepTheme.teal)
                Text("PepPal also includes a full training suite — want to set up your workout profile?")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(12)
            .background(PepTheme.teal.opacity(0.06))
            .clipShape(.rect(cornerRadius: 12))
        }
        .padding(.top, 8)
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider().overlay(PepTheme.separatorColor)

            HStack(spacing: 12) {
                if currentStep > 0 {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            currentStep -= 1
                        }
                    } label: {
                        Text("Back")
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(PepTheme.elevated)
                            .clipShape(.rect(cornerRadius: 12))
                    }
                }

                Button {
                    if currentStep < 3 {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            currentStep += 1
                        }
                    } else {
                        completeSetup()
                    }
                } label: {
                    Text(currentStep == 3 ? "Start Protocol" : "Continue")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(PepTheme.invertedText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canContinue ? PepTheme.teal : PepTheme.elevated, in: .rect(cornerRadius: 12))
                }
                .disabled(!canContinue)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(PepTheme.cardSurface)
        }
    }

    private var canContinue: Bool {
        switch currentStep {
        case 0: return selectedGoal != nil
        case 1: return !selectedCompounds.isEmpty
        case 2: return true
        case 3: return true
        default: return false
        }
    }

    private var suggestedCompounds: [CompoundProfile] {
        guard let goal = selectedGoal else { return [] }
        let category: PeptideCategory
        switch goal {
        case .weightLoss: category = .weightLoss
        case .muscleGrowth: category = .muscleGrowth
        case .healing: category = .healing
        case .cognitive: category = .cognitive
        case .tanning: category = .tanning
        case .custom: return []
        }
        return CompoundDatabase.compounds(for: category)
    }

    private func completeSetup() {
        let compounds = selectedCompounds.map { wc in
            ProtocolCompound(
                compoundName: wc.name,
                doseMcg: Double(wc.doseText) ?? 250
            )
        }

        let total = loadingWeeks + maintenanceWeeks + taperingWeeks + offCycleWeeks
        let proto = PeptideProtocol(
            name: protocolName.isEmpty ? "My Protocol" : protocolName,
            goal: selectedGoal ?? .custom,
            compounds: compounds,
            totalWeeks: total,
            loadingWeeks: loadingWeeks,
            maintenanceWeeks: maintenanceWeeks,
            taperingWeeks: taperingWeeks,
            offCycleWeeks: offCycleWeeks
        )
        onComplete(proto)
        dismiss()
    }
}

struct WizardCompound: Identifiable {
    let id = UUID()
    let name: String
    var doseText: String = "250"
}
