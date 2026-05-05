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
    var doseText: String = ""
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

    init(name: String) {
        self.name = name
        let unit = CompoundUnitHelper.unit(for: name)
        self.doseUnit = unit.rawValue
        self.doseText = CompoundUnitHelper.defaultDoseText(for: name)

        if let pd = ProtocolDefaultsDatabase.defaults(for: name) {
            let routeStr = pd.route.lowercased()
            if routeStr.contains("oral") {
                self.injectionRoute = .oral
            } else if routeStr.contains("nasal") {
                self.injectionRoute = .nasal
            } else if routeStr.contains("intramuscular") {
                self.injectionRoute = .intramuscular
            } else {
                self.injectionRoute = .subcutaneous
            }
            if pd.defaultFrequency.lowercased().contains("weekly") {
                if pd.defaultFrequency.contains("2x") || pd.defaultFrequency.contains("twice") {
                    self.frequency = "2x weekly"
                } else {
                    self.frequency = "1x weekly"
                }
            } else if pd.defaultFrequency.contains("2x") || pd.defaultFrequency.contains("twice") {
                self.frequency = "2x daily"
            } else if pd.defaultFrequency.contains("3x") {
                self.frequency = "3x daily"
            } else if pd.defaultFrequency.lowercased().contains("as needed") {
                self.frequency = "As needed"
            } else {
                self.frequency = "1x daily"
            }
        } else if let profile = CompoundDatabase.all.first(where: { $0.name == name }) {
            let route = InjectionRoute.allCases.first { profile.keyFacts.administrationRoute.localizedCaseInsensitiveContains($0.rawValue) } ?? .subcutaneous
            self.injectionRoute = route
            if let tiered = profile.tieredDosing.first(where: { $0.tier == "Intermediate" }) ?? profile.tieredDosing.first {
                self.timeOfDay = tiered.timingNotes
                if tiered.frequency.lowercased().contains("weekly") {
                    self.frequency = tiered.frequency.contains("2") ? "2x weekly" : "1x weekly"
                } else if tiered.frequency.contains("2") {
                    self.frequency = "2x daily"
                } else if tiered.frequency.contains("3") {
                    self.frequency = "3x daily"
                } else {
                    self.frequency = "1x daily"
                }
            }
        }
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
        case .twoToThreeMonths: return cal.date(byAdding: .month, value: -2, to: Date())
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
    @State private var showPastDoseSheet: Bool = false
    @State private var savedProtocol: PeptideProtocol?
    @State private var showVialScanner: Bool = false
    @State private var showTitrationTemplates: Bool = false
    let initialCompound: String?
    let onComplete: (PeptideProtocol) -> Void

    init(initialCompound: String? = nil, onComplete: @escaping (PeptideProtocol) -> Void) {
        self.initialCompound = initialCompound
        self.onComplete = onComplete
    }

    private var isExistingPath: Bool {
        protocolPath == .existingProtocol
    }

    private var steps: [String] {
        if protocolPath == nil {
            return ["Choose Path"]
        }
        if isExistingPath {
            return ["Compounds", "Dosing", "Schedule", "Review"]
        }
        return ["Goal", "Compounds", "Dosing", "Schedule", "Review"]
    }

    private var stepCount: Int { steps.count }

    private var templates: [ProtocolTemplate] {
        [
            ProtocolTemplate(
                name: "BPC-157 Standard Recovery",
                subtitle: "8 weeks, 250 mcg subcutaneous daily",
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
                subtitle: "Slow titration, 0.25 mg weekly",
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
                subtitle: "Tesamorelin, 1 mg daily",
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
                icon: "face.smiling",
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
                        MedicalDisclaimerBanner(compact: true)
                        if protocolPath == nil {
                            pathSelectionStep
                        } else {
                            currentStepView
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
            .appBackground()
            .navigationTitle(protocolPath == nil ? "New Protocol" : (isExistingPath ? "Log Current Protocol" : "New Protocol"))
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
            .fullScreenCover(isPresented: $showVialScanner) {
                VialScannerView { scan, _ in
                    applyScannedVial(scan)
                }
            }
            .sheet(isPresented: $showTitrationTemplates) {
                TitrationTemplatePickerView(
                    onSelectTemplate: { template in
                        applyTitrationTemplate(template)
                    },
                    onBuildCustom: {}
                )
            }
            .onAppear {
                if let name = initialCompound,
                   !name.isEmpty,
                   selectedCompounds.isEmpty,
                   protocolPath == nil {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        protocolPath = .newProtocol
                        selectedCompounds = [WizardCompound(name: name)]
                        currentStep = 1
                    }
                }
            }
            .sheet(isPresented: $showPastDoseSheet) {
                if let proto = savedProtocol {
                    PastDoseLoggingSheet(protocolData: proto) { savedProto in
                        onComplete(savedProto)
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var currentStepView: some View {
        if isExistingPath {
            switch currentStep {
            case 0: compoundStep
            case 1: dosingStep
            case 2: scheduleStep
            case 3: reviewStep
            default: EmptyView()
            }
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

    // MARK: - Path Selection

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
                pathCard(
                    title: "Start a New Protocol",
                    subtitle: "I'm about to begin something new",
                    icon: "plus.circle.fill",
                    color: PepTheme.teal
                )
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: protocolPath)

            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    protocolPath = .existingProtocol
                }
            } label: {
                pathCard(
                    title: "Log a Current Protocol",
                    subtitle: "I'm already taking something and want to track it",
                    icon: "clock.arrow.circlepath",
                    color: PepTheme.blue
                )
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: protocolPath)

            Button {
                showTitrationTemplates = true
            } label: {
                pathCard(
                    title: "Guided Titration",
                    subtitle: "Prebuilt dose ladders for Retatrutide, Tirzepatide, Semaglutide",
                    icon: "chart.line.uptrend.xyaxis",
                    color: PepTheme.amber
                )
            }
            .sensoryFeedback(.impact(weight: .light), trigger: showTitrationTemplates)

            Button {
                showVialScanner = true
            } label: {
                pathCard(
                    title: "Scan a Vial",
                    subtitle: "Snap the label and auto-fill the compound",
                    icon: "viewfinder",
                    color: PepTheme.violet
                )
            }
            .sensoryFeedback(.impact(weight: .light), trigger: showVialScanner)
        }
        .padding(.top, 12)
    }

    private func pathCard(title: String, subtitle: String, icon: String, color: Color) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(colors: [color.opacity(0.2), color.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 56, height: 56)
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.headline, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(subtitle)
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
                    LinearGradient(colors: [color.opacity(0.3), color.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Goal Step (New Protocol only)

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's your goal?")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)

            Text("Optional — helps suggest compounds")
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
                            selectedGoal = isSelected ? nil : goal
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

    // MARK: - Compound Selection

    private var compoundStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isExistingPath ? "What are you taking?" : "Select Compounds")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)

            Text(isExistingPath ? "Choose the compounds in your current protocol" : "Choose the compounds for your protocol")
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

            if !suggested.isEmpty && searchText.isEmpty && !isExistingPath {
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
                    if searchText.isEmpty && !isExistingPath && suggested.contains(where: { $0.id == compound.id }) {
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
                let wc = WizardCompound(name: compound.name)
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

                    Text("\(compound.communityUsers) users")
                        .font(.system(size: 9))
                        .foregroundStyle(PepTheme.textSecondary)

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

    // MARK: - Dosing

    private var dosingStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isExistingPath ? "Current Dosing" : "Configure Dosing")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)

            Text(isExistingPath ? "Enter your current dose for each compound" : "Set dose, frequency, and route for each compound")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)

            ForEach(Array(selectedCompounds.enumerated()), id: \.element.id) { index, wc in
                dosingCard(for: wc, at: index)
            }
        }
        .padding(.top, 8)
    }

    private func dosingCard(for wc: WizardCompound, at index: Int) -> some View {
        let profile = wc.profile
        let unitLabel = CompoundUnitHelper.unit(for: wc.name).rawValue

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
                    Text(unitLabel)
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.teal)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(PepTheme.teal.opacity(0.1))
                        .clipShape(.capsule)
                }

                if !isExistingPath, let hint = CompoundUnitHelper.typicalRangeHint(for: wc.name) {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(PepTheme.blue)
                        Text(hint)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .padding(8)
                    .background(PepTheme.blue.opacity(0.05))
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
                            .frame(width: 80)
                            Text(unitLabel)
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
                            get: { selectedCompounds[safe: index]?.frequency ?? "1x daily" },
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
                            Text("EOD").tag("EOD")
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

                if !isExistingPath, let profile, let guide = Optional(profile.reconstitutionGuide), guide.reconstitutionMath != "N/A — taken orally" && guide.reconstitutionMath != "N/A" {
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

    // MARK: - Schedule

    private var scheduleStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isExistingPath {
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

            endDateToggle

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

            endDateToggle

            advancedCyclePlanningSection
        }
    }

    private var endDateToggle: some View {
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

    // MARK: - Review

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

                    if isExistingPath {
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

                    if isExistingPath {
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
                                    Text(selectedCompounds.map { "\($0.name) \($0.doseText) \($0.doseUnit)" }.joined(separator: " + "))
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
            .appBackground()
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
            return isExistingPath ? "Save Protocol" : "Start Protocol"
        }
        return "Continue"
    }

    // MARK: - Helpers

    private var canContinue: Bool {
        if isExistingPath {
            switch currentStep {
            case 0: return !selectedCompounds.isEmpty
            case 1: return selectedCompounds.allSatisfy { !$0.doseText.isEmpty }
            case 2: return selectedStartShortcut != nil
            case 3: return true
            default: return false
            }
        } else {
            switch currentStep {
            case 0: return true
            case 1: return !selectedCompounds.isEmpty
            case 2: return selectedCompounds.allSatisfy { !$0.doseText.isEmpty }
            case 3: return true
            case 4: return true
            default: return false
            }
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

    private func applyScannedVial(_ scan: ScannedVialLabel) {
        guard !scan.compoundName.isEmpty else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            protocolPath = .newProtocol
            if !selectedCompounds.contains(where: { $0.name == scan.compoundName }) {
                selectedCompounds.append(WizardCompound(name: scan.compoundName))
            }
            currentStep = 1
        }
    }

    private func applyTitrationTemplate(_ template: TitrationTemplate) {
        selectedGoal = .weightLoss
        protocolName = template.name
        let totalWeeks = (template.steps.last?.week ?? 4) + 4
        durationWeeks = totalWeeks
        hasPlannedEndDate = true
        loadingWeeks = template.steps.count
        maintenanceWeeks = max(4, totalWeeks - template.steps.count)
        taperingWeeks = 0
        offCycleWeeks = 0

        var wc = WizardCompound(name: template.compound)
        wc.frequency = "1x weekly"
        wc.injectionRoute = .subcutaneous
        wc.timeOfDay = "Morning"
        let startMcg = template.steps.first?.doseMcg ?? 0
        let unit = CompoundUnitHelper.unit(for: template.compound)
        if unit == .mg {
            let mg = startMcg / 1000
            wc.doseText = mg == mg.rounded() ? String(Int(mg)) : String(format: "%.2f", mg)
            wc.doseUnit = "mg"
        } else {
            wc.doseText = String(Int(startMcg))
            wc.doseUnit = "mcg"
        }
        selectedCompounds = [wc]

        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            protocolPath = .newProtocol
            currentStep = stepCount - 1
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
            let displayValue = CompoundUnitHelper.fromMcg(tc.doseMcg, for: tc.name)
            wc.doseText = CompoundUnitHelper.unit(for: tc.name) == .mg ?
                (displayValue == displayValue.rounded() && displayValue >= 1 ? String(Int(displayValue)) : String(format: "%.2g", displayValue)) :
                String(Int(tc.doseMcg))
            wc.frequency = tc.frequency
            wc.injectionRoute = tc.route
            wc.timeOfDay = tc.timeOfDay
            return wc
        }

        showTemplates = false
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            currentStep = stepCount - 1
        }
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
            let mcgValue = CompoundUnitHelper.toMcg(Double(wc.doseText) ?? 0, for: wc.name)
            return ProtocolCompound(
                compoundName: wc.name,
                doseMcg: mcgValue,
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
            isExistingProtocol: isExistingPath
        )

        if isExistingPath {
            savedProtocol = proto
            showPastDoseSheet = true
        } else {
            onComplete(proto)
            dismiss()
        }
    }
}

// MARK: - Past Dose Logging Sheet

struct PastDoseLoggingSheet: View {
    let protocolData: PeptideProtocol
    let onSave: (PeptideProtocol) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var pastDoses: [PastDoseEntry] = []
    @State private var isSaving: Bool = false
    @State private var saveError: String?

    private let protocolService = ProtocolService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Log Past Doses")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("Add any previous doses you want to track. You can skip this and add them later.")
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(Array(pastDoses.enumerated()), id: \.element.id) { index, entry in
                        pastDoseRow(entry: entry, index: index)
                    }

                    Button {
                        let firstCompound = protocolData.compounds.first
                        pastDoses.append(PastDoseEntry(
                            compoundName: firstCompound?.compoundName ?? "",
                            doseText: "",
                            date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                        ))
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                            Text("Add Past Dose")
                                .font(.system(.subheadline, weight: .semibold))
                        }
                        .foregroundStyle(PepTheme.teal)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(PepTheme.teal.opacity(0.08))
                        .clipShape(.rect(cornerRadius: 12))
                    }

                    VStack(spacing: 10) {
                        Button {
                            savePastDosesAndComplete()
                        } label: {
                            Text(pastDoses.isEmpty ? "Skip & Save Protocol" : "Save Protocol & Doses")
                                .font(.system(.body, weight: .bold))
                                .foregroundStyle(PepTheme.invertedText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(PepTheme.teal, in: .rect(cornerRadius: 12))
                        }
                        .disabled(isSaving)

                        if !pastDoses.isEmpty {
                            Button {
                                saveProtocolAndComplete(withDoses: false)
                            } label: {
                                Text("Skip Past Doses")
                                    .font(.system(.subheadline, weight: .medium))
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                            .disabled(isSaving)
                        }

                        if let saveError {
                            Text(saveError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .navigationTitle("Past Doses")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func pastDoseRow(entry: PastDoseEntry, index: Int) -> some View {
        let unit = CompoundUnitHelper.unit(for: entry.compoundName).rawValue

        return VStack(spacing: 10) {
            if protocolData.compounds.count > 1 {
                HStack {
                    Text("Compound")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { pastDoses[safe: index]?.compoundName ?? "" },
                        set: { val in if index < pastDoses.count { pastDoses[index].compoundName = val } }
                    )) {
                        ForEach(protocolData.compounds) { c in
                            Text(c.compoundName).tag(c.compoundName)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(PepTheme.teal)
                }
            }

            HStack {
                Text("Dose")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                HStack(spacing: 4) {
                    TextField("Dose", text: Binding(
                        get: { pastDoses[safe: index]?.doseText ?? "" },
                        set: { val in if index < pastDoses.count { pastDoses[index].doseText = val } }
                    ))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .frame(width: 70)
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(PepTheme.elevated)
                .clipShape(.rect(cornerRadius: 8))
            }

            HStack {
                Text("Date")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                DatePicker("", selection: Binding(
                    get: { pastDoses[safe: index]?.date ?? Date() },
                    set: { val in if index < pastDoses.count { pastDoses[index].date = val } }
                ), in: ...Date(), displayedComponents: [.date])
                .labelsHidden()
                .tint(PepTheme.teal)
            }

            HStack {
                Spacer()
                Button {
                    pastDoses.remove(at: index)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                        Text("Remove")
                            .font(.caption)
                    }
                    .foregroundStyle(.red.opacity(0.8))
                }
            }
        }
        .padding(14)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private func savePastDosesAndComplete() {
        saveProtocolAndComplete(withDoses: true)
    }

    private func saveProtocolAndComplete(withDoses: Bool) {
        isSaving = true
        saveError = nil
        Task {
            do {
                let saved = try await protocolService.createProtocol(protocolData)
                guard let protocolId = saved.supabaseId else {
                    onSave(saved)
                    dismiss()
                    return
                }

                if withDoses {
                    let validDoses = pastDoses.filter { !$0.doseText.isEmpty && Double($0.doseText) != nil }
                    for dose in validDoses {
                        let mcgValue = CompoundUnitHelper.toMcg(Double(dose.doseText) ?? 0, for: dose.compoundName)
                        _ = try await protocolService.logDose(
                            protocolId: protocolId,
                            compoundName: dose.compoundName,
                            doseMcg: mcgValue,
                            injectionSite: .leftAbdomen,
                            notes: "",
                            loggedAt: dose.date
                        )
                    }
                }

                onSave(saved)
                dismiss()
            } catch {
                isSaving = false
                saveError = error.localizedDescription
            }
        }
    }
}

struct PastDoseEntry: Identifiable {
    let id = UUID()
    var compoundName: String
    var doseText: String
    var date: Date
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
