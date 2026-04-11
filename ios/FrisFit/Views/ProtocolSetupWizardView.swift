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

nonisolated enum ProtocolPath: String, Sendable {
    case newProtocol = "new"
    case existingProtocol = "existing"
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
    var doseUnit: String = "mcg"
    var frequency: String = "Daily"
    var injectionRoute: InjectionRoute = .subcutaneous
    var timeOfDay: String = "Morning"

    var profile: CompoundProfile? {
        CompoundDatabase.all.first { $0.name == name }
    }

    var protocolDefault: ProtocolDefault? {
        ProtocolDefaultsDatabase.defaults(for: name)
    }

    func isDefaultDose(for level: ExperienceLevel) -> Bool {
        guard let pd = protocolDefault else { return false }
        let range = pd.doseRange(for: level)
        return doseText == range.defaultDoseText
    }
}

nonisolated enum StartDateShortcut: String, CaseIterable, Identifiable, Sendable {
    case thisWeek = "This week"
    case oneToTwoWeeks = "1–2 weeks ago"
    case aboutAMonth = "About a month ago"
    case twoToThreeMonths = "2–3 months ago"
    case threeMonthsPlus = "3+ months ago"
    case pickExact = "Pick exact date"

    var id: String { rawValue }

    var approximateDate: Date? {
        let cal = Calendar.current
        switch self {
        case .thisWeek: return cal.date(byAdding: .day, value: -3, to: Date())
        case .oneToTwoWeeks: return cal.date(byAdding: .day, value: -10, to: Date())
        case .aboutAMonth: return cal.date(byAdding: .weekOfYear, value: -4, to: Date())
        case .twoToThreeMonths: return cal.date(byAdding: .month, value: -2, to: Date()) // ~10 weeks
        case .threeMonthsPlus: return cal.date(byAdding: .month, value: -4, to: Date())
        case .pickExact: return nil
        }
    }

    var icon: String {
        switch self {
        case .thisWeek: return "calendar.badge.clock"
        case .oneToTwoWeeks: return "calendar"
        case .aboutAMonth: return "calendar.badge.minus"
        case .twoToThreeMonths: return "clock.arrow.circlepath"
        case .threeMonthsPlus: return "clock.badge.checkmark"
        case .pickExact: return "calendar.day.timeline.left"
        }
    }
}

struct ProtocolSetupWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var protocolPath: ProtocolPath?
    @State private var currentStep: Int = 0
    @State private var experienceLevel: ExperienceLevel? = .intermediate
    @State private var selectedGoal: ProtocolGoal?
    @State private var protocolName: String = ""
    @State private var selectedCompounds: [WizardCompound] = []
    @State private var startDate: Date = Date()
    @State private var hasPlannedEndDate: Bool = false
    @State private var endDate: Date = Calendar.current.date(byAdding: .weekOfYear, value: 8, to: Date()) ?? Date()
    @State private var durationWeeks: Int = 8
    @State private var showAdvancedCycle: Bool = false
    @State private var loadingWeeks: Int = 0
    @State private var maintenanceWeeks: Int = 4
    @State private var taperingWeeks: Int = 0
    @State private var offCycleWeeks: Int = 0
    @State private var selectedStartShortcut: StartDateShortcut?
    @State private var showExactDatePicker: Bool = false
    @State private var showTemplates: Bool = false
    @State private var searchText: String = ""
    @State private var expandedTooltip: String?
    let onComplete: (PeptideProtocol) -> Void

    private var steps: [String] {
        if protocolPath == nil {
            return ["Choose Path"]
        }
        return ["Goal", "Compounds", "Dosing", "Schedule", "Review"]
    }

    private var stepCount: Int { steps.count }

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
        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if protocolPath != nil {
                    progressBar
                }

                ScrollView {
                    VStack(spacing: 20) {
                        if protocolPath == nil {
                            pathSelectionStep
                        } else {
                            switch currentStep {
                            case 0: goalStep
                            case 1: compoundStep
                            case 2: dosingStep
                            case 3: scheduleStep
                            case 4: reviewStep
                            default: EmptyView()
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)

                if protocolPath != nil {
                    bottomBar
                }
            }
            .background(PepTheme.background.ignoresSafeArea())
            .navigationTitle(protocolPath == nil ? "New Protocol" : (protocolPath == .existingProtocol ? "Log Current Protocol" : "New Protocol"))
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

    // MARK: - Step 0: Choose Path

    private var pathSelectionStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("How would you like to start?")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Choose based on where you are in your journey")
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    protocolPath = .newProtocol
                }
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(colors: [PepTheme.teal.opacity(0.2), PepTheme.teal.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 56, height: 56)
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(PepTheme.teal)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Start a New Protocol")
                            .font(.system(.headline, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("I'm about to begin something new")
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .padding(16)
                .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
                .clipShape(.rect(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(colors: [PepTheme.teal.opacity(0.3), PepTheme.teal.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                )
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: protocolPath)

            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    protocolPath = .existingProtocol
                }
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(colors: [PepTheme.blue.opacity(0.2), PepTheme.blue.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 56, height: 56)
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title2)
                            .foregroundStyle(PepTheme.blue)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Log a Current Protocol")
                            .font(.system(.headline, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("I'm already taking something and want to track it")
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .padding(16)
                .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
                .clipShape(.rect(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(colors: [PepTheme.blue.opacity(0.3), PepTheme.blue.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                )
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: protocolPath)
        }
        .padding(.top, 12)
    }

    // MARK: - Step 1: Goal

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
                ForEach(ProtocolGoal.allCases.filter { $0 != .custom }) { goal in
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

    // MARK: - Step 2: Compound Selection

    private var compoundStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Compounds")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)

            Text("Choose the compounds for your protocol")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)

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
                let level = experienceLevel ?? .intermediate

                if let pd = ProtocolDefaultsDatabase.defaults(for: compound.name) {
                    let range = pd.doseRange(for: level)
                    wc.doseText = range.defaultDoseText
                    wc.doseUnit = range.unit
                    let routeStr = pd.route.lowercased()
                    if routeStr.contains("oral") {
                        wc.injectionRoute = .oral
                    } else if routeStr.contains("nasal") {
                        wc.injectionRoute = .nasal
                    } else if routeStr.contains("intramuscular") {
                        wc.injectionRoute = .intramuscular
                    } else {
                        wc.injectionRoute = .subcutaneous
                    }
                } else if let tiered = compound.tieredDosing.first(where: { $0.tier == level.tierKey }) {
                    wc.doseText = tiered.dose.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
                    wc.frequency = tiered.frequency
                    let route = InjectionRoute.allCases.first { compound.keyFacts.administrationRoute.localizedCaseInsensitiveContains($0.rawValue) } ?? .subcutaneous
                    wc.injectionRoute = route
                } else {
                    let route = InjectionRoute.allCases.first { compound.keyFacts.administrationRoute.localizedCaseInsensitiveContains($0.rawValue) } ?? .subcutaneous
                    wc.injectionRoute = route
                }

                if let tiered = compound.tieredDosing.first(where: { $0.tier == level.tierKey }) {
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
                            if isBeginnerSafe {
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

    // MARK: - Step 3: Dosing

    private var dosingStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Configure Dosing")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)

            Text("Set dose, frequency, and route for each compound")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("EXPERIENCE LEVEL")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary)

                Picker("", selection: Binding(
                    get: { experienceLevel ?? .intermediate },
                    set: { newLevel in
                        let oldLevel = experienceLevel
                        experienceLevel = newLevel
                        if oldLevel != newLevel {
                            applyDefaultDoses(for: newLevel)
                        }
                    }
                )) {
                    ForEach(ExperienceLevel.allCases) { level in
                        HStack(spacing: 4) {
                            Image(systemName: level.icon)
                            Text(level.rawValue)
                        }
                        .tag(level)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(12)
            .background(PepTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
            )

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
        let pd = wc.protocolDefault
        let currentLevel = experienceLevel ?? .intermediate

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
                    if let pd {
                        Text(pd.route)
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(PepTheme.elevated)
                            .clipShape(.capsule)
                    } else if let kf = profile?.keyFacts {
                        Text(kf.typicalDoseRange)
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(PepTheme.elevated)
                            .clipShape(.capsule)
                    }
                }

                if let pd {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("RECOMMENDED DOSES")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(PepTheme.textSecondary)
                        ForEach(ExperienceLevel.allCases) { level in
                            let range = pd.doseRange(for: level)
                            let isCurrentLevel = level == currentLevel
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(isCurrentLevel ? level.color : PepTheme.elevated)
                                    .frame(width: 6, height: 6)
                                Text(level.rawValue)
                                    .font(.system(.caption2, weight: isCurrentLevel ? .bold : .regular))
                                    .foregroundStyle(isCurrentLevel ? level.color : PepTheme.textSecondary)
                                Text("— \(range.displayString)")
                                    .font(.caption2)
                                    .foregroundStyle(isCurrentLevel ? PepTheme.textPrimary : PepTheme.textSecondary)
                                Spacer()
                                if isCurrentLevel {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(level.color)
                                }
                            }
                        }

                        if !pd.defaultFrequency.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 9))
                                    .foregroundStyle(PepTheme.textSecondary)
                                Text(pd.defaultFrequency)
                                    .font(.system(size: 9))
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                            .padding(.top, 2)
                        }
                        if !pd.defaultCycle.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 9))
                                    .foregroundStyle(PepTheme.textSecondary)
                                Text("Cycle: \(pd.defaultCycle)")
                                    .font(.system(size: 9))
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(PepTheme.elevated.opacity(0.5))
                    .clipShape(.rect(cornerRadius: 8))
                } else if let profile, !profile.tieredDosing.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TIERED DOSING")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(PepTheme.textSecondary)
                        ForEach(profile.tieredDosing) { tier in
                            let isCurrentTier = tier.tier == currentLevel.tierKey
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
                    VStack(spacing: 4) {
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
                                Text(wc.doseUnit)
                                    .font(.caption)
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(PepTheme.elevated)
                            .clipShape(.rect(cornerRadius: 8))
                        }

                        if wc.isDefaultDose(for: currentLevel) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.green)
                                Text("Recommended starting dose")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.green.opacity(0.8))
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
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

    // MARK: - Step 4: Schedule

    private var scheduleStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            if protocolPath == .existingProtocol {
                existingProtocolSchedule
            } else {
                newProtocolSchedule
            }
        }
        .padding(.top, 8)
    }

    private var newProtocolSchedule: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Schedule")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Protocol Name")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                TextField("e.g. Semaglutide Protocol", text: $protocolName)
                    .font(.body)
                    .foregroundStyle(PepTheme.textPrimary)
                    .padding(12)
                    .background(PepTheme.elevated)
                    .clipShape(.rect(cornerRadius: 12))
            }
            .onAppear {
                if protocolName.isEmpty {
                    let names = selectedCompounds.map(\.name)
                    protocolName = names.count == 1 ? "\(names[0]) Protocol" : names.joined(separator: " + ")
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Start Date")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                DatePicker("", selection: $startDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .tint(PepTheme.teal)
                    .labelsHidden()
                    .padding(12)
                    .background(PepTheme.elevated)
                    .clipShape(.rect(cornerRadius: 12))
            }

            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $hasPlannedEndDate.animation(.spring(response: 0.35))) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Do you have a planned end date?")
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("Leave off for open-ended protocols")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
                .tint(PepTheme.teal)

                if hasPlannedEndDate {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Duration")
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(PepTheme.textSecondary)
                            Stepper("\(durationWeeks) weeks", value: $durationWeeks, in: 1...52)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                        }
                    }
                    .padding(12)
                    .background(PepTheme.elevated)
                    .clipShape(.rect(cornerRadius: 12))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(14)
            .background(PepTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
            )

            advancedCyclePlanningSection
        }
    }

    private var existingProtocolSchedule: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("When did you start?")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)

            Text("Select approximately when you began this protocol")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Protocol Name")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                TextField("e.g. Semaglutide Protocol", text: $protocolName)
                    .font(.body)
                    .foregroundStyle(PepTheme.textPrimary)
                    .padding(12)
                    .background(PepTheme.elevated)
                    .clipShape(.rect(cornerRadius: 12))
            }
            .onAppear {
                if protocolName.isEmpty {
                    let names = selectedCompounds.map(\.name)
                    protocolName = names.count == 1 ? "\(names[0]) Protocol" : names.joined(separator: " + ")
                }
            }

            VStack(spacing: 8) {
                ForEach(StartDateShortcut.allCases) { shortcut in
                    let isSelected = selectedStartShortcut == shortcut
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedStartShortcut = shortcut
                            if shortcut == .pickExact {
                                showExactDatePicker = true
                            } else if let date = shortcut.approximateDate {
                                startDate = date
                                showExactDatePicker = false
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: shortcut.icon)
                                .font(.system(size: 15))
                                .foregroundStyle(isSelected ? PepTheme.teal : PepTheme.textSecondary)
                                .frame(width: 24)
                            Text(shortcut.rawValue)
                                .font(.system(.subheadline, weight: .medium))
                                .foregroundStyle(PepTheme.textPrimary)
                            Spacer()
                            if isSelected && shortcut != .pickExact {
                                Text(startDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.system(.caption, design: .rounded, weight: .semibold))
                                    .foregroundStyle(PepTheme.teal)
                            }
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(PepTheme.teal)
                            }
                        }
                        .padding(12)
                        .background(isSelected ? PepTheme.teal.opacity(0.05) : PepTheme.cardSurface)
                        .clipShape(.rect(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(isSelected ? PepTheme.teal : PepTheme.glassBorderTop, lineWidth: isSelected ? 1.5 : 0.5)
                        )
                    }
                    .sensoryFeedback(.selection, trigger: selectedStartShortcut)
                }
            }

            if showExactDatePicker {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Pick your start date")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                    DatePicker("", selection: $startDate, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(PepTheme.teal)
                }
                .padding(12)
                .background(PepTheme.cardSurface)
                .clipShape(.rect(cornerRadius: 14))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $hasPlannedEndDate.animation(.spring(response: 0.35))) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Do you have a planned end date?")
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("Leave off for open-ended protocols")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
                .tint(PepTheme.teal)

                if hasPlannedEndDate {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Duration")
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(PepTheme.textSecondary)
                            Stepper("\(durationWeeks) weeks", value: $durationWeeks, in: 1...52)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                        }
                    }
                    .padding(12)
                    .background(PepTheme.elevated)
                    .clipShape(.rect(cornerRadius: 12))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(14)
            .background(PepTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
            )

            advancedCyclePlanningSection
        }
    }

    private var advancedCyclePlanningSection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showAdvancedCycle.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "gearshape.2.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(PepTheme.textSecondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Advanced: Define Cycle Phases")
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("Useful for planned cycles with distinct dosing phases")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .rotationEffect(.degrees(showAdvancedCycle ? 180 : 0))
                }
                .padding(14)
                .background(PepTheme.cardSurface)
                .clipShape(.rect(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                )
            }
            .sensoryFeedback(.selection, trigger: showAdvancedCycle)

            if showAdvancedCycle {
                VStack(spacing: 12) {
                    phaseStepperWithTooltip(
                        label: "Loading Phase", value: $loadingWeeks,
                        color: CyclePhase.loading.color, range: 0...4,
                        tooltip: "A ramp-up period where the body saturates with the compound."
                    )
                    phaseStepperWithTooltip(
                        label: "Maintenance Phase", value: $maintenanceWeeks,
                        color: CyclePhase.maintenance.color, range: 0...20,
                        tooltip: "The core phase where the compound is at full effect."
                    )
                    phaseStepperWithTooltip(
                        label: "Tapering Phase", value: $taperingWeeks,
                        color: CyclePhase.tapering.color, range: 0...4,
                        tooltip: "Gradually reducing the dose to ease off the compound."
                    )
                    phaseStepperWithTooltip(
                        label: "Off-Cycle", value: $offCycleWeeks,
                        color: CyclePhase.offCycle.color, range: 0...12,
                        tooltip: "A rest period between cycles to prevent desensitization."
                    )

                    phaseTimeline
                }
                .padding(14)
                .background(PepTheme.elevated.opacity(0.3))
                .clipShape(.rect(cornerRadius: 14))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
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

    // MARK: - Step 5: Review

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

                    if protocolPath == .existingProtocol {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 12))
                                .foregroundStyle(PepTheme.blue)
                            Text("Logging existing protocol")
                                .font(.system(.caption, weight: .medium))
                                .foregroundStyle(PepTheme.blue)
                        }
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
                                reviewDetail("Dose", "\(wc.doseText) \(wc.doseUnit)")
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

                    HStack(spacing: 16) {
                        reviewStat("Started", startDate.formatted(date: .abbreviated, time: .omitted))
                        if hasPlannedEndDate {
                            reviewStat("Duration", "\(durationWeeks) weeks")
                        } else {
                            reviewStat("Duration", "Ongoing")
                        }
                        reviewStat("Compounds", "\(selectedCompounds.count)")
                    }

                    if protocolPath == .existingProtocol {
                        let currentWeek = max(1, (Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0) / 7 + 1)
                        HStack(spacing: 6) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 12))
                                .foregroundStyle(PepTheme.teal)
                            Text("Currently in Week \(currentWeek)")
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(PepTheme.teal)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PepTheme.teal.opacity(0.06))
                        .clipShape(.rect(cornerRadius: 10))
                    }

                    if showAdvancedCycle && (loadingWeeks > 0 || taperingWeeks > 0 || offCycleWeeks > 0) {
                        HStack(spacing: 12) {
                            if loadingWeeks > 0 { reviewStat("Loading", "\(loadingWeeks)w") }
                            if maintenanceWeeks > 0 { reviewStat("Maintenance", "\(maintenanceWeeks)w") }
                            if taperingWeeks > 0 { reviewStat("Tapering", "\(taperingWeeks)w") }
                            if offCycleWeeks > 0 { reviewStat("Off-Cycle", "\(offCycleWeeks)w") }
                        }
                    }
                }
            }

            if hasPlannedEndDate || showAdvancedCycle {
                calendarPreview
            }

            warningsSection
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
        let total: Int = {
            if showAdvancedCycle {
                return loadingWeeks + maintenanceWeeks + taperingWeeks + offCycleWeeks
            }
            return hasPlannedEndDate ? durationWeeks : 0
        }()
        guard total > 0 else { return AnyView(EmptyView()) }

        let weeksToShow = min(total, 8)
        return AnyView(
            GlassCard {
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
                                    Text(selectedCompounds.map { "\($0.name) \($0.doseText)\($0.doseUnit)" }.joined(separator: " + "))
                                        .font(.system(size: 8))
                                        .foregroundStyle(PepTheme.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                        }
                    }
                }
            }
        )
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
                } else {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            protocolPath = nil
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
                    Text(continueButtonTitle)
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

    private var continueButtonTitle: String {
        if currentStep == stepCount - 1 {
            return protocolPath == .existingProtocol ? "Save Protocol" : "Start Protocol"
        }
        return "Continue"
    }

    // MARK: - Helpers

    private var canContinue: Bool {
        switch currentStep {
        case 0: return selectedGoal != nil
        case 1: return !selectedCompounds.isEmpty
        case 2: return selectedCompounds.allSatisfy { !$0.doseText.isEmpty }
        case 3:
            if protocolPath == .existingProtocol {
                return selectedStartShortcut != nil
            }
            return true
        case 4: return true
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
        case .general, .custom: return []
        }
        return CompoundDatabase.compounds(for: category)
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

    private func phaseForWeek(_ week: Int) -> CyclePhase {
        if showAdvancedCycle {
            if loadingWeeks > 0 && week <= loadingWeeks { return .loading }
            if week <= loadingWeeks + maintenanceWeeks { return .maintenance }
            if taperingWeeks > 0 && week <= loadingWeeks + maintenanceWeeks + taperingWeeks { return .tapering }
            if offCycleWeeks > 0 { return .offCycle }
            return .maintenance
        }
        return .maintenance
    }

    private func applyDefaultDoses(for level: ExperienceLevel) {
        for i in selectedCompounds.indices {
            if let pd = ProtocolDefaultsDatabase.defaults(for: selectedCompounds[i].name) {
                let range = pd.doseRange(for: level)
                selectedCompounds[i].doseText = range.defaultDoseText
                selectedCompounds[i].doseUnit = range.unit
            } else if let profile = selectedCompounds[i].profile,
                      let tiered = profile.tieredDosing.first(where: { $0.tier == level.tierKey }) {
                selectedCompounds[i].doseText = tiered.dose.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
                selectedCompounds[i].frequency = tiered.frequency
            }
        }
    }

    private func applyTemplate(_ template: ProtocolTemplate) {
        selectedGoal = template.goal
        protocolName = template.name
        loadingWeeks = template.loadingWeeks
        maintenanceWeeks = template.maintenanceWeeks
        taperingWeeks = template.taperingWeeks
        offCycleWeeks = template.offCycleWeeks
        hasPlannedEndDate = true
        durationWeeks = template.totalWeeks
        if template.loadingWeeks > 0 || template.taperingWeeks > 0 || template.offCycleWeeks > 0 {
            showAdvancedCycle = true
        }

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
            currentStep = 4
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

        let finalTotalWeeks: Int? = {
            if hasPlannedEndDate { return durationWeeks }
            if showAdvancedCycle {
                let total = loadingWeeks + maintenanceWeeks + taperingWeeks + offCycleWeeks
                return total > 0 ? total : nil
            }
            return nil
        }()

        let finalLoading: Int? = showAdvancedCycle && loadingWeeks > 0 ? loadingWeeks : nil
        let finalMaintenance: Int? = showAdvancedCycle && maintenanceWeeks > 0 ? maintenanceWeeks : nil
        let finalTapering: Int? = showAdvancedCycle && taperingWeeks > 0 ? taperingWeeks : nil
        let finalOffCycle: Int? = showAdvancedCycle && offCycleWeeks > 0 ? offCycleWeeks : nil

        let proto = PeptideProtocol(
            name: protocolName.isEmpty ? "My Protocol" : protocolName,
            goal: selectedGoal ?? .general,
            compounds: compounds,
            startDate: startDate,
            totalWeeks: finalTotalWeeks,
            loadingWeeks: finalLoading,
            maintenanceWeeks: finalMaintenance,
            taperingWeeks: finalTapering,
            offCycleWeeks: finalOffCycle,
            isExistingProtocol: protocolPath == .existingProtocol
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
