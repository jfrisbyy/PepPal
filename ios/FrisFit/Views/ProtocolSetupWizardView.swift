import SwiftUI

nonisolated enum ExperienceLevel: String, CaseIterable, Identifiable, Sendable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .beginner: return "leaf.fill"
        case .intermediate: return "flame.fill"
        case .advanced: return "bolt.fill"
        }
    }

    var color: Color {
        switch self {
        case .beginner: return .green
        case .intermediate: return PepTheme.amber
        case .advanced: return .orange
        }
    }

    var description: String {
        switch self {
        case .beginner: return "New to peptides — I want guidance and safety-first defaults"
        case .intermediate: return "Some experience — comfortable adjusting doses and schedules"
        case .advanced: return "Experienced user — show me all options and let me customize"
        }
    }

    var tierKey: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }
}

nonisolated struct ProtocolTemplate: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let subtitle: String
    let goal: ProtocolGoal
    let icon: String
    let compounds: [TemplateCompound]
    let totalWeeks: Int
    let loadingWeeks: Int
    let maintenanceWeeks: Int
    let taperingWeeks: Int
    let offCycleWeeks: Int
    let experienceLevel: ExperienceLevel
}

nonisolated struct TemplateCompound: Sendable {
    let name: String
    let doseMcg: Double
    let frequency: String
    let route: InjectionRoute
    let timeOfDay: String
}

struct WizardCompound: Identifiable {
    let id = UUID()
    let name: String
    var doseText: String = "250"
    var frequency: String = "Daily"
    var injectionRoute: InjectionRoute = .subcutaneous
    var timeOfDay: String = "Morning"

    var profile: CompoundProfile? {
        CompoundDatabase.all.first { $0.name == name }
    }
}

struct ProtocolSetupWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep: Int = 0
    @State private var experienceLevel: ExperienceLevel?
    @State private var selectedGoal: ProtocolGoal?
    @State private var protocolName: String = ""
    @State private var selectedCompounds: [WizardCompound] = []
    @State private var cycleWeeks: Int = 8
    @State private var loadingWeeks: Int = 1
    @State private var maintenanceWeeks: Int = 5
    @State private var taperingWeeks: Int = 1
    @State private var offCycleWeeks: Int = 4
    @State private var showTemplates: Bool = false
    @State private var searchText: String = ""
    @State private var showCycleConflict: Bool = false
    @State private var expandedTooltip: String?
    let onComplete: (PeptideProtocol) -> Void

    private let stepCount = 6

    private var templates: [ProtocolTemplate] {
        [
            ProtocolTemplate(
                name: "BPC-157 Standard Recovery",
                subtitle: "8 weeks, 250mcg subcutaneous daily",
                goal: .healing,
                icon: "cross.case.fill",
                compounds: [TemplateCompound(name: "BPC-157", doseMcg: 250, frequency: "1x daily", route: .subcutaneous, timeOfDay: "Morning")],
                totalWeeks: 8, loadingWeeks: 0, maintenanceWeeks: 8, taperingWeeks: 0, offCycleWeeks: 4,
                experienceLevel: .beginner
            ),
            ProtocolTemplate(
                name: "Wolverine Stack",
                subtitle: "BPC-157 + TB-500, 8 weeks",
                goal: .healing,
                icon: "bandage.fill",
                compounds: [
                    TemplateCompound(name: "BPC-157", doseMcg: 250, frequency: "2x daily", route: .subcutaneous, timeOfDay: "Morning"),
                    TemplateCompound(name: "TB-500", doseMcg: 2000, frequency: "2x weekly", route: .subcutaneous, timeOfDay: "Morning")
                ],
                totalWeeks: 12, loadingWeeks: 4, maintenanceWeeks: 4, taperingWeeks: 0, offCycleWeeks: 4,
                experienceLevel: .intermediate
            ),
            ProtocolTemplate(
                name: "GH Optimization Stack",
                subtitle: "CJC-1295 + Ipamorelin, 12 weeks",
                goal: .muscleGrowth,
                icon: "figure.strengthtraining.traditional",
                compounds: [
                    TemplateCompound(name: "CJC-1295", doseMcg: 100, frequency: "1x daily", route: .subcutaneous, timeOfDay: "Pre-bed"),
                    TemplateCompound(name: "Ipamorelin", doseMcg: 100, frequency: "1x daily", route: .subcutaneous, timeOfDay: "Pre-bed")
                ],
                totalWeeks: 16, loadingWeeks: 0, maintenanceWeeks: 12, taperingWeeks: 0, offCycleWeeks: 4,
                experienceLevel: .beginner
            ),
            ProtocolTemplate(
                name: "Semaglutide Weight Loss",
                subtitle: "Slow titration, ongoing",
                goal: .weightLoss,
                icon: "scalemass.fill",
                compounds: [TemplateCompound(name: "Semaglutide", doseMcg: 250, frequency: "1x weekly", route: .subcutaneous, timeOfDay: "Morning")],
                totalWeeks: 16, loadingWeeks: 4, maintenanceWeeks: 12, taperingWeeks: 0, offCycleWeeks: 0,
                experienceLevel: .beginner
            ),
            ProtocolTemplate(
                name: "Cognitive Focus Stack",
                subtitle: "Semax + Selank, 30 days",
                goal: .cognitive,
                icon: "brain.head.profile",
                compounds: [
                    TemplateCompound(name: "Semax", doseMcg: 200, frequency: "1x daily", route: .nasal, timeOfDay: "Morning"),
                    TemplateCompound(name: "Selank", doseMcg: 200, frequency: "1x daily", route: .nasal, timeOfDay: "Morning")
                ],
                totalWeeks: 8, loadingWeeks: 0, maintenanceWeeks: 4, taperingWeeks: 0, offCycleWeeks: 4,
                experienceLevel: .beginner
            ),
            ProtocolTemplate(
                name: "Visceral Fat Blaster",
                subtitle: "Tesamorelin, 12 weeks",
                goal: .weightLoss,
                icon: "flame.fill",
                compounds: [TemplateCompound(name: "Tesamorelin", doseMcg: 1000, frequency: "1x daily", route: .subcutaneous, timeOfDay: "Morning")],
                totalWeeks: 16, loadingWeeks: 0, maintenanceWeeks: 12, taperingWeeks: 0, offCycleWeeks: 4,
                experienceLevel: .intermediate
            ),
            ProtocolTemplate(
                name: "Skin Rejuvenation",
                subtitle: "GHK-Cu, 4 weeks on / 4 weeks off",
                goal: .tanning,
                icon: "sparkles",
                compounds: [TemplateCompound(name: "GHK-Cu", doseMcg: 1000, frequency: "1x daily", route: .subcutaneous, timeOfDay: "Any time")],
                totalWeeks: 8, loadingWeeks: 0, maintenanceWeeks: 4, taperingWeeks: 0, offCycleWeeks: 4,
                experienceLevel: .intermediate
            ),
        ]
    }

    private var filteredTemplates: [ProtocolTemplate] {
        var result = templates
        if let goal = selectedGoal {
            result = result.filter { $0.goal == goal }
        }
        if let level = experienceLevel {
            result = result.filter { $0.experienceLevel.rawValue <= level.rawValue || $0.experienceLevel == .beginner }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar

                ScrollView {
                    VStack(spacing: 20) {
                        switch currentStep {
                        case 0: experienceStep
                        case 1: goalStep
                        case 2: compoundStep
                        case 3: dosingStep
                        case 4: scheduleStep
                        case 5: reviewStep
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
            .sheet(isPresented: $showTemplates) {
                templateSheet
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(0..<stepCount, id: \.self) { step in
                RoundedRectangle(cornerRadius: 2)
                    .fill(step <= currentStep ? PepTheme.teal : PepTheme.elevated)
                    .frame(height: 4)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Step 0: Experience Level

    private var experienceStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's your experience level?")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)

            Text("This personalizes dosing defaults, educational content, and compound suggestions")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)

            VStack(spacing: 10) {
                ForEach(ExperienceLevel.allCases) { level in
                    let isSelected = experienceLevel == level
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            experienceLevel = level
                        }
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(level.color.opacity(isSelected ? 0.2 : 0.1))
                                    .frame(width: 48, height: 48)
                                Image(systemName: level.icon)
                                    .font(.title3)
                                    .foregroundStyle(level.color)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(level.rawValue)
                                    .font(.system(.body, weight: .semibold))
                                    .foregroundStyle(PepTheme.textPrimary)
                                Text(level.description)
                                    .font(.caption)
                                    .foregroundStyle(PepTheme.textSecondary)
                                    .lineLimit(2)
                            }

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
                    .sensoryFeedback(.selection, trigger: experienceLevel)
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Step 1: Goal + Templates

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's your goal?")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)

            Text("This helps us suggest compounds and protocol structures")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)

            Button {
                showTemplates = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "bolt.heart.fill")
                        .font(.title3)
                        .foregroundStyle(PepTheme.teal)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quick Start from Template")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("One-tap prebuilt protocols for common goals")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .padding(14)
                .background(
                    LinearGradient(colors: [PepTheme.teal.opacity(0.08), PepTheme.teal.opacity(0.03)], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(.rect(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(PepTheme.teal.opacity(0.3), lineWidth: 1)
                )
            }
            .sensoryFeedback(.impact(weight: .light), trigger: showTemplates)

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
        }
        .padding(.top, 8)
    }

    // MARK: - Step 2: Compound Selection (Enhanced)

    private var compoundStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Compounds")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)

            Text("Choose the compounds for your protocol")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)

            if experienceLevel == .beginner {
                beginnerTipBanner(
                    icon: "lightbulb.fill",
                    text: "As a beginner, we've highlighted the safest and most well-researched compounds. Look for the \(Image(systemName: "leaf.fill")) icon."
                )
            }

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(PepTheme.textSecondary)
                TextField("Search compounds...", text: $searchText)
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textPrimary)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
            }
            .padding(10)
            .background(PepTheme.elevated)
            .clipShape(.rect(cornerRadius: 10))

            let suggested = suggestedCompounds
            let allFiltered = filteredCompounds

            if !suggested.isEmpty && searchText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggested for \(selectedGoal?.rawValue ?? "your goal")")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.teal)

                    ForEach(suggested) { compound in
                        enhancedCompoundRow(compound)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(searchText.isEmpty ? "All Compounds" : "Results")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)

                ForEach(allFiltered) { compound in
                    if searchText.isEmpty && suggested.contains(where: { $0.id == compound.id }) {
                        EmptyView()
                    } else {
                        enhancedCompoundRow(compound)
                    }
                }

                if allFiltered.isEmpty {
                    Text("No compounds match your search")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                }
            }

            if !selectedCompounds.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected (\(selectedCompounds.count))")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.teal)

                    ForEach(selectedCompounds) { wc in
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(PepTheme.teal)
                            Text(wc.name)
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                            Spacer()
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

    private func enhancedCompoundRow(_ compound: CompoundProfile) -> some View {
        let isAdded = selectedCompounds.contains { $0.name == compound.name }
        let isBeginnerSafe = compound.tieredDosing.contains { $0.tier == "Beginner" }

        return Button {
            if isAdded {
                selectedCompounds.removeAll { $0.name == compound.name }
            } else {
                var wc = WizardCompound(name: compound.name)
                if let level = experienceLevel,
                   let tiered = compound.tieredDosing.first(where: { $0.tier == level.tierKey }) {
                    wc.doseText = tiered.dose.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
                    wc.frequency = tiered.frequency
                }
                let route = InjectionRoute.allCases.first { compound.keyFacts.administrationRoute.localizedCaseInsensitiveContains($0.rawValue) } ?? .subcutaneous
                wc.injectionRoute = route
                if let tiered = compound.tieredDosing.first(where: { $0.tier == (experienceLevel?.tierKey ?? "Beginner") }) {
                    wc.timeOfDay = tiered.timingNotes
                }
                selectedCompounds.append(wc)
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill((compound.categories.first?.color ?? PepTheme.teal).opacity(0.12))
                            .frame(width: 38, height: 38)
                        Image(systemName: compound.iconName)
                            .font(.system(size: 15))
                            .foregroundStyle(compound.categories.first?.color ?? PepTheme.teal)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(compound.name)
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                            if experienceLevel == .beginner && isBeginnerSafe {
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.green)
                            }
                            if compound.isWADAProhibited {
                                Text("WADA")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.red)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(.red.opacity(0.12))
                                    .clipShape(.capsule)
                            }
                        }
                        Text(compound.peptideType)
                            .font(.caption2)
                            .foregroundStyle(PepTheme.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(PepTheme.amber)
                            Text(String(format: "%.1f", compound.averageRating))
                                .font(.system(.caption2, design: .rounded, weight: .semibold))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        Text("\(compound.communityUsers) users")
                            .font(.system(size: 9))
                            .foregroundStyle(PepTheme.textSecondary)
                    }

                    Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(isAdded ? PepTheme.teal : PepTheme.textSecondary)
                }

                if !compound.primaryUseCases.isEmpty {
                    Text(compound.primaryUseCases.prefix(2).joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary)
                        .lineLimit(1)
                }

                if !compound.stackPartners.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.system(size: 8))
                            .foregroundStyle(PepTheme.violet)
                        Text("Stacks with: \(compound.stackPartners.prefix(3).joined(separator: ", "))")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(PepTheme.violet.opacity(0.8))
                    }
                }
            }
            .padding(12)
            .background(isAdded ? PepTheme.teal.opacity(0.05) : PepTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isAdded ? PepTheme.teal.opacity(0.4) : PepTheme.glassBorderTop, lineWidth: isAdded ? 1 : 0.5)
            )
        }
        .sensoryFeedback(.impact(weight: .light), trigger: isAdded)
    }

    // MARK: - Step 3: Dosing Configuration

    private var dosingStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Configure Dosing")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)

            Text("Set dose, frequency, and route for each compound")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)

            if experienceLevel == .beginner {
                beginnerTipBanner(
                    icon: "info.circle.fill",
                    text: "Doses are pre-filled based on beginner-safe recommendations. Adjust only if your prescriber advises differently."
                )
            }

            ForEach(Array(selectedCompounds.enumerated()), id: \.element.id) { index, wc in
                dosingCard(for: wc, at: index)
            }
        }
        .padding(.top, 8)
    }

    private func dosingCard(for wc: WizardCompound, at index: Int) -> some View {
        let profile = wc.profile

        return GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: profile?.iconName ?? "pill.fill")
                        .font(.subheadline)
                        .foregroundStyle(profile?.categories.first?.color ?? PepTheme.teal)
                    Text(wc.name)
                        .font(.system(.headline, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                    if let kf = profile?.keyFacts {
                        Text(kf.typicalDoseRange)
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(PepTheme.elevated)
                            .clipShape(.capsule)
                    }
                }

                if let profile, !profile.tieredDosing.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TIERED DOSING")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(PepTheme.textSecondary)
                        ForEach(profile.tieredDosing) { tier in
                            let isCurrentTier = tier.tier == (experienceLevel?.tierKey ?? "")
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(isCurrentTier ? PepTheme.teal : PepTheme.elevated)
                                    .frame(width: 6, height: 6)
                                Text(tier.tier)
                                    .font(.system(.caption2, weight: isCurrentTier ? .bold : .regular))
                                    .foregroundStyle(isCurrentTier ? PepTheme.teal : PepTheme.textSecondary)
                                Text("— \(tier.dose), \(tier.frequency)")
                                    .font(.caption2)
                                    .foregroundStyle(isCurrentTier ? PepTheme.textPrimary : PepTheme.textSecondary)
                                Spacer()
                            }
                        }
                    }
                    .padding(10)
                    .background(PepTheme.elevated.opacity(0.5))
                    .clipShape(.rect(cornerRadius: 8))
                }

                VStack(spacing: 12) {
                    HStack {
                        Text("Dose")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("Dose", text: Binding(
                                get: { selectedCompounds[safe: index]?.doseText ?? "" },
                                set: { newVal in
                                    if index < selectedCompounds.count {
                                        selectedCompounds[index].doseText = newVal
                                    }
                                }
                            ))
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 70)
                            Text("mcg")
                                .font(.caption)
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(PepTheme.elevated)
                        .clipShape(.rect(cornerRadius: 8))
                    }

                    HStack {
                        Text("Frequency")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { selectedCompounds[safe: index]?.frequency ?? "Daily" },
                            set: { newVal in
                                if index < selectedCompounds.count {
                                    selectedCompounds[index].frequency = newVal
                                }
                            }
                        )) {
                            Text("1x daily").tag("1x daily")
                            Text("2x daily").tag("2x daily")
                            Text("3x daily").tag("3x daily")
                            Text("1x weekly").tag("1x weekly")
                            Text("2x weekly").tag("2x weekly")
                            Text("3x weekly").tag("3x weekly")
                            Text("As needed").tag("As needed")
                        }
                        .pickerStyle(.menu)
                        .tint(PepTheme.teal)
                    }

                    HStack {
                        Text("Route")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { selectedCompounds[safe: index]?.injectionRoute ?? .subcutaneous },
                            set: { newVal in
                                if index < selectedCompounds.count {
                                    selectedCompounds[index].injectionRoute = newVal
                                }
                            }
                        )) {
                            ForEach(InjectionRoute.allCases, id: \.self) { route in
                                Text(route.rawValue).tag(route)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(PepTheme.teal)
                    }

                    HStack {
                        Text("Time of Day")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { selectedCompounds[safe: index]?.timeOfDay ?? "Morning" },
                            set: { newVal in
                                if index < selectedCompounds.count {
                                    selectedCompounds[index].timeOfDay = newVal
                                }
                            }
                        )) {
                            Text("Morning").tag("Morning")
                            Text("Pre-bed").tag("Pre-bed")
                            Text("Pre-workout").tag("Pre-workout")
                            Text("Post-workout").tag("Post-workout")
                            Text("Any time").tag("Any time")
                            Text("Pre-meal").tag("Pre-meal")
                        }
                        .pickerStyle(.menu)
                        .tint(PepTheme.teal)
                    }
                }

                if let profile, let guide = Optional(profile.reconstitutionGuide), guide.reconstitutionMath != "N/A — taken orally" && guide.reconstitutionMath != "N/A" {
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 6) {
                            reconRow("Vial Size", guide.typicalVialSize)
                            reconRow("Diluent", guide.diluent)
                            reconRow("Math", guide.reconstitutionMath)
                            reconRow("Storage", guide.storageReconstituted)
                            if !guide.handlingNotes.isEmpty {
                                reconRow("Notes", guide.handlingNotes)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "flask.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(PepTheme.blue)
                            Text("Reconstitution Guide")
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(PepTheme.blue)
                        }
                    }
                    .tint(PepTheme.blue)
                }
            }
        }
    }

    private func reconRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(PepTheme.textSecondary)
            Text(value)
                .font(.caption)
                .foregroundStyle(PepTheme.textPrimary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Step 4: Schedule (Compound-Aware)

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

            if let conflict = cycleConflictMessage {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(PepTheme.amber)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cycle Length Conflict")
                            .font(.system(.caption, weight: .bold))
                            .foregroundStyle(PepTheme.amber)
                        Text(conflict)
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                        Button {
                            alignToLongestCycle()
                        } label: {
                            Text("Align to longest cycle")
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(PepTheme.teal)
                        }
                    }
                }
                .padding(12)
                .background(PepTheme.amber.opacity(0.08))
                .clipShape(.rect(cornerRadius: 12))
            }

            VStack(spacing: 12) {
                phaseStepperWithTooltip(
                    label: "Loading Phase", value: $loadingWeeks,
                    color: CyclePhase.loading.color, range: 0...4,
                    tooltip: "A ramp-up period where the body saturates with the compound. Some compounds (like TB-500) require loading to reach therapeutic levels."
                )
                phaseStepperWithTooltip(
                    label: "Maintenance Phase", value: $maintenanceWeeks,
                    color: CyclePhase.maintenance.color, range: 1...20,
                    tooltip: "The core phase where the compound is at full effect. Most therapeutic benefits occur here."
                )
                phaseStepperWithTooltip(
                    label: "Tapering Phase", value: $taperingWeeks,
                    color: CyclePhase.tapering.color, range: 0...4,
                    tooltip: "Gradually reducing the dose to ease off the compound. Helps the body adjust and reduces potential rebound effects."
                )
                phaseStepperWithTooltip(
                    label: "Off-Cycle", value: $offCycleWeeks,
                    color: CyclePhase.offCycle.color, range: 0...12,
                    tooltip: "A rest period between cycles to prevent desensitization and give the body a break. Duration depends on the compound."
                )
            }

            if !selectedCompounds.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("COMPOUND CYCLE DATA")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary)
                    ForEach(selectedCompounds) { wc in
                        if let profile = wc.profile {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(profile.categories.first?.color ?? PepTheme.teal)
                                    .frame(width: 6, height: 6)
                                Text(wc.name)
                                    .font(.system(.caption, weight: .semibold))
                                    .foregroundStyle(PepTheme.textPrimary)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(profile.cycleLength)
                                        .font(.caption2)
                                        .foregroundStyle(PepTheme.textSecondary)
                                    Text(profile.onOffCycling)
                                        .font(.system(size: 9))
                                        .foregroundStyle(PepTheme.textSecondary)
                                }
                            }
                            .padding(8)
                            .background(PepTheme.elevated.opacity(0.5))
                            .clipShape(.rect(cornerRadius: 8))
                        }
                    }
                }
            }

            phaseTimeline
        }
        .padding(.top, 8)
        .onAppear { autoPopulateSchedule() }
    }

    private func phaseStepperWithTooltip(label: String, value: Binding<Int>, color: Color, range: ClosedRange<Int>, tooltip: String) -> some View {
        VStack(spacing: 6) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                Text(label)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(PepTheme.textPrimary)

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        expandedTooltip = expandedTooltip == label ? nil : label
                    }
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(PepTheme.textSecondary)
                }

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

            if expandedTooltip == label {
                Text(tooltip)
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                    .padding(10)
                    .background(PepTheme.elevated)
                    .clipShape(.rect(cornerRadius: 8))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
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

    // MARK: - Step 5: Comprehensive Review

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

                    if let level = experienceLevel {
                        HStack(spacing: 4) {
                            Image(systemName: level.icon)
                                .font(.system(size: 10))
                            Text(level.rawValue)
                                .font(.system(.caption2, weight: .medium))
                        }
                        .foregroundStyle(level.color)
                    }

                    Divider().overlay(PepTheme.separatorColor)

                    ForEach(selectedCompounds) { wc in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: wc.profile?.iconName ?? "pill.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(PepTheme.teal)
                                Text(wc.name)
                                    .font(.system(.subheadline, weight: .semibold))
                                    .foregroundStyle(PepTheme.textPrimary)
                                Spacer()
                            }
                            HStack(spacing: 16) {
                                reviewDetail("Dose", "\(wc.doseText) mcg")
                                reviewDetail("Freq", wc.frequency)
                                reviewDetail("Route", wc.injectionRoute.rawValue)
                            }
                            Text("Timing: \(wc.timeOfDay)")
                                .font(.caption2)
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        .padding(10)
                        .background(PepTheme.elevated.opacity(0.5))
                        .clipShape(.rect(cornerRadius: 10))
                    }

                    Divider().overlay(PepTheme.separatorColor)

                    let total = loadingWeeks + maintenanceWeeks + taperingWeeks + offCycleWeeks
                    HStack(spacing: 16) {
                        reviewStat("Duration", "\(total) weeks")
                        reviewStat("Compounds", "\(selectedCompounds.count)")
                        reviewStat("Loading", loadingWeeks > 0 ? "\(loadingWeeks)w" : "None")
                        reviewStat("Off-Cycle", offCycleWeeks > 0 ? "\(offCycleWeeks)w" : "None")
                    }
                }
            }

            calendarPreview

            warningsSection

            reconstitutionSection
        }
        .padding(.top, 8)
    }

    private func reviewDetail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(PepTheme.textSecondary)
            Text(value)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
        }
    }

    private func reviewStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(PepTheme.textSecondary)
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
        }
    }

    private var calendarPreview: some View {
        let total = loadingWeeks + maintenanceWeeks + taperingWeeks + offCycleWeeks
        let weeksToShow = min(total, 8)

        return GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(PepTheme.teal)
                    Text("Schedule Preview")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                    Text("First \(weeksToShow) weeks")
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary)
                }

                ForEach(0..<weeksToShow, id: \.self) { week in
                    let phase = phaseForWeek(week + 1)
                    HStack(spacing: 8) {
                        Text("W\(week + 1)")
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.textSecondary)
                            .frame(width: 24)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(phase.color)
                            .frame(width: 3, height: 24)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(phase.rawValue)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(phase.color)
                            if phase != .offCycle {
                                Text(selectedCompounds.map { "\($0.name) \($0.doseText)mcg" }.joined(separator: " + "))
                                    .font(.system(size: 8))
                                    .foregroundStyle(PepTheme.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()

                        if phase != .offCycle {
                            let dailyDoses = selectedCompounds.filter { dosesPerWeek(frequency: $0.frequency) > 0 }
                            Text("\(dailyDoses.count > 0 ? "\(totalInjectionsPerWeek) inj/wk" : "")")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private var warningsSection: some View {
        let warnings = collectWarnings()
        guard !warnings.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "exclamationmark.shield.fill")
                            .foregroundStyle(PepTheme.amber)
                        Text("Important Warnings")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                    }

                    ForEach(Array(warnings.enumerated()), id: \.offset) { _, warning in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: warning.icon)
                                .font(.system(size: 10))
                                .foregroundStyle(warning.color)
                                .frame(width: 14)
                            Text(warning.text)
                                .font(.caption)
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                }
            }
        )
    }

    private var reconstitutionSection: some View {
        let compoundsWithRecon = selectedCompounds.compactMap { wc -> (WizardCompound, ReconstitutionGuide)? in
            guard let profile = wc.profile else { return nil }
            let guide = profile.reconstitutionGuide
            guard guide.reconstitutionMath != "N/A — taken orally" && guide.reconstitutionMath != "N/A" else { return nil }
            return (wc, guide)
        }
        guard !compoundsWithRecon.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "flask.fill")
                            .foregroundStyle(PepTheme.blue)
                        Text("Reconstitution Instructions")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                    }

                    ForEach(compoundsWithRecon, id: \.0.id) { wc, guide in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(wc.name)
                                .font(.system(.caption, weight: .bold))
                                .foregroundStyle(PepTheme.textPrimary)
                            Text(guide.reconstitutionMath)
                                .font(.caption2)
                                .foregroundStyle(PepTheme.textSecondary)
                            Text("Storage: \(guide.storageReconstituted)")
                                .font(.system(size: 9))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        .padding(8)
                        .background(PepTheme.elevated.opacity(0.5))
                        .clipShape(.rect(cornerRadius: 8))
                    }
                }
            }
        )
    }

    // MARK: - Template Sheet

    private var templateSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(filteredTemplates) { template in
                        Button {
                            applyTemplate(template)
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(template.goal.color.opacity(0.12))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: template.icon)
                                        .font(.title3)
                                        .foregroundStyle(template.goal.color)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(template.name)
                                        .font(.system(.subheadline, weight: .semibold))
                                        .foregroundStyle(PepTheme.textPrimary)
                                    Text(template.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(PepTheme.textSecondary)
                                    HStack(spacing: 4) {
                                        Image(systemName: template.experienceLevel.icon)
                                            .font(.system(size: 8))
                                        Text(template.experienceLevel.rawValue)
                                            .font(.system(size: 9, weight: .medium))
                                    }
                                    .foregroundStyle(template.experienceLevel.color)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                            .padding(14)
                            .background(PepTheme.cardSurface)
                            .clipShape(.rect(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                            )
                        }
                    }
                }
                .padding()
            }
            .background(PepTheme.background.ignoresSafeArea())
            .navigationTitle("Quick Start Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showTemplates = false }
                        .foregroundStyle(PepTheme.teal)
                }
            }
        }
    }

    // MARK: - Bottom Bar

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
                    if currentStep < stepCount - 1 {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            currentStep += 1
                        }
                    } else {
                        completeSetup()
                    }
                } label: {
                    Text(currentStep == stepCount - 1 ? "Start Protocol" : "Continue")
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

    // MARK: - Helpers

    private var canContinue: Bool {
        switch currentStep {
        case 0: return experienceLevel != nil
        case 1: return selectedGoal != nil
        case 2: return !selectedCompounds.isEmpty
        case 3: return selectedCompounds.allSatisfy { !$0.doseText.isEmpty }
        case 4: return true
        case 5: return true
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
        var compounds = CompoundDatabase.compounds(for: category)
        if experienceLevel == .beginner {
            compounds = compounds.filter { $0.tieredDosing.contains { $0.tier == "Beginner" } }
        }
        return compounds
    }

    private var filteredCompounds: [CompoundProfile] {
        if searchText.isEmpty {
            return CompoundDatabase.all
        }
        return CompoundDatabase.all.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.peptideType.localizedCaseInsensitiveContains(searchText) ||
            $0.categories.contains { $0.rawValue.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private var cycleConflictMessage: String? {
        let profiles = selectedCompounds.compactMap { $0.profile }
        guard profiles.count > 1 else { return nil }
        let lengths = profiles.compactMap { extractWeeks(from: $0.cycleLength) }
        guard let minLen = lengths.min(), let maxLen = lengths.max(), minLen != maxLen else { return nil }

        let names = zip(selectedCompounds, profiles).compactMap { wc, profile -> String? in
            guard let weeks = extractWeeks(from: profile.cycleLength) else { return nil }
            return "\(wc.name) recommends \(weeks) weeks"
        }
        return names.joined(separator: ", ") + " — align to the longer?"
    }

    private var totalInjectionsPerWeek: Int {
        selectedCompounds.reduce(0) { $0 + dosesPerWeek(frequency: $1.frequency) }
    }

    private func dosesPerWeek(frequency: String) -> Int {
        let lower = frequency.lowercased()
        if lower.contains("3x daily") { return 21 }
        if lower.contains("2x daily") { return 14 }
        if lower.contains("1x daily") || lower == "daily" { return 7 }
        if lower.contains("3x weekly") { return 3 }
        if lower.contains("2x weekly") { return 2 }
        if lower.contains("1x weekly") || lower == "weekly" { return 1 }
        return 0
    }

    private func extractWeeks(from cycleLength: String) -> Int? {
        let pattern = #"(\d+)\s*(?:-\d+)?\s*weeks?"#
        guard let range = cycleLength.range(of: pattern, options: .regularExpression) else { return nil }
        let match = String(cycleLength[range])
        guard let num = match.components(separatedBy: CharacterSet.decimalDigits.inverted).first(where: { !$0.isEmpty }),
              let weeks = Int(num) else { return nil }
        return weeks
    }

    private func phaseForWeek(_ week: Int) -> CyclePhase {
        if week <= loadingWeeks { return .loading }
        if week <= loadingWeeks + maintenanceWeeks { return .maintenance }
        if week <= loadingWeeks + maintenanceWeeks + taperingWeeks { return .tapering }
        return .offCycle
    }

    private func autoPopulateSchedule() {
        let profiles = selectedCompounds.compactMap { $0.profile }
        guard !profiles.isEmpty else { return }

        let hasLoading = profiles.contains { $0.loadingProtocol.lowercased().contains("yes") }
        if hasLoading {
            loadingWeeks = max(loadingWeeks, 4)
        }

        if let maxCycle = profiles.compactMap({ extractWeeks(from: $0.cycleLength) }).max() {
            let activeWeeks = maxCycle
            maintenanceWeeks = max(1, activeWeeks - loadingWeeks - taperingWeeks)
        }
    }

    private func alignToLongestCycle() {
        let profiles = selectedCompounds.compactMap { $0.profile }
        if let maxCycle = profiles.compactMap({ extractWeeks(from: $0.cycleLength) }).max() {
            let activeWeeks = maxCycle
            maintenanceWeeks = max(1, activeWeeks - loadingWeeks - taperingWeeks)
        }
    }

    private func applyTemplate(_ template: ProtocolTemplate) {
        selectedGoal = template.goal
        protocolName = template.name
        loadingWeeks = template.loadingWeeks
        maintenanceWeeks = template.maintenanceWeeks
        taperingWeeks = template.taperingWeeks
        offCycleWeeks = template.offCycleWeeks

        selectedCompounds = template.compounds.map { tc in
            var wc = WizardCompound(name: tc.name)
            wc.doseText = String(Int(tc.doseMcg))
            wc.frequency = tc.frequency
            wc.injectionRoute = tc.route
            wc.timeOfDay = tc.timeOfDay
            return wc
        }

        showTemplates = false
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            currentStep = 5
        }
    }

    private func beginnerTipBanner(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.green)
            Text(text)
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .padding(12)
        .background(.green.opacity(0.06))
        .clipShape(.rect(cornerRadius: 12))
    }

    nonisolated struct ReviewWarning: Sendable {
        let icon: String
        let text: String
        let color: Color
    }

    private func collectWarnings() -> [ReviewWarning] {
        var warnings: [ReviewWarning] = []

        for wc in selectedCompounds {
            guard let profile = wc.profile else { continue }

            if profile.isWADAProhibited {
                warnings.append(ReviewWarning(
                    icon: "exclamationmark.triangle.fill",
                    text: "\(wc.name) is prohibited by WADA (\(profile.wadaCategory))",
                    color: .red
                ))
            }

            if let effects = Optional(profile.detailedSideEffects), !effects.common.isEmpty {
                warnings.append(ReviewWarning(
                    icon: "heart.text.clipboard",
                    text: "\(wc.name) common side effects: \(effects.common.prefix(3).joined(separator: ", "))",
                    color: PepTheme.amber
                ))
            }

            if !profile.detailedSideEffects.contraindications.isEmpty {
                warnings.append(ReviewWarning(
                    icon: "nosign",
                    text: "\(wc.name) contraindicated: \(profile.detailedSideEffects.contraindications.joined(separator: ", "))",
                    color: .red
                ))
            }
        }

        return warnings
    }

    private func completeSetup() {
        let compounds = selectedCompounds.map { wc in
            ProtocolCompound(
                compoundName: wc.name,
                doseMcg: Double(wc.doseText) ?? 250,
                frequency: wc.frequency,
                injectionRoute: wc.injectionRoute
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

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
