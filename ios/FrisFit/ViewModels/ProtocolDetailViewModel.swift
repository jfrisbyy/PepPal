import SwiftUI

@Observable
final class ProtocolDetailViewModel {
    var protocolData: PeptideProtocol
    var expandedSections: Set<String> = ["doseLog", "timeline"]
    var showLogDoseSheet: Bool = false
    var showSideEffectSheet: Bool = false
    var showAddSupplementSheet: Bool = false
    var showAddNoteSheet: Bool = false
    var showReconCalculator: Bool = false

    var newDoseCompound: String = ""
    var newDoseMcg: String = ""
    var newDoseSite: InjectionSite = .leftAbdomen
    var newDoseNotes: String = ""
    var newDoseRoute: AdministrationRoute = .subcutaneous
    var newDoseNasalSide: NasalSide = .both

    var newEffectName: String = ""
    var newEffectSeverity: Int = 2
    var newEffectNotes: String = ""

    var newSupplementName: String = ""
    var newSupplementDose: String = ""
    var newSupplementFrequency: String = "Daily"

    var newNoteText: String = ""

    var reconPeptideMg: String = ""
    var reconWaterMl: String = ""
    var reconDesiredMcg: String = ""

    var dailyRatings: [DailyRating] = []
    var notes: [ProtocolNote] = []
    var titrationSteps: [TitrationStep] = []
    var recoveryMilestones: [RecoveryMilestone] = []
    var bodyMeasurements: [ProtocolBodyMeasurement] = []

    let commonSideEffects = [
        "Nausea", "Injection Site Redness", "Fatigue", "Headache",
        "Water Retention", "Dizziness", "Appetite Changes",
        "Mood Changes", "Insomnia", "Flushing"
    ]

    init(protocolData: PeptideProtocol) {
        self.protocolData = protocolData
        if let first = protocolData.compounds.first {
            self.newDoseCompound = first.compoundName
            self.newDoseMcg = "\(Int(first.doseMcg))"
        }
        setupTitrationSteps()
        setupRecoveryMilestones()
        setupSampleData()
    }

    func toggleSection(_ section: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            if expandedSections.contains(section) {
                expandedSections.remove(section)
            } else {
                expandedSections.insert(section)
            }
        }
    }

    func isSectionExpanded(_ section: String) -> Bool {
        expandedSections.contains(section)
    }

    // MARK: - Dose Logging

    func logDose() {
        let dose = DoseLogEntry(
            compoundName: newDoseCompound,
            doseMcg: Double(newDoseMcg) ?? 0,
            injectionSite: newDoseSite,
            notes: newDoseNotes
        )
        protocolData.doseLog.insert(dose, at: 0)
        newDoseNotes = ""
        showLogDoseSheet = false
    }

    var sortedDoseLog: [DoseLogEntry] {
        protocolData.doseLog.sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Injection Site Rotation

    func siteRecency(_ site: InjectionSite) -> SiteRecency {
        let logsForSite = protocolData.doseLog.filter { $0.injectionSite == site }
        guard let lastUse = logsForSite.first?.timestamp else { return .unused }
        let daysSince = Calendar.current.dateComponents([.day], from: lastUse, to: Date()).day ?? 0
        if daysSince < 3 { return .overused }
        if daysSince < 7 { return .recentlyUsed }
        return .rotated
    }

    var suggestedNextSite: InjectionSite {
        let sorted = InjectionSite.allCases.sorted { a, b in
            let aLog = protocolData.doseLog.filter { $0.injectionSite == a }.first
            let bLog = protocolData.doseLog.filter { $0.injectionSite == b }.first
            guard let aDate = aLog?.timestamp else { return true }
            guard let bDate = bLog?.timestamp else { return false }
            return aDate < bDate
        }
        return sorted.first ?? .leftAbdomen
    }

    // MARK: - Side Effects

    func logSideEffect() {
        let entry = SideEffectEntry(
            effect: newEffectName,
            severity: newEffectSeverity,
            notes: newEffectNotes
        )
        protocolData.sideEffectLog.insert(entry, at: 0)
        newEffectName = ""
        newEffectSeverity = 2
        newEffectNotes = ""
        showSideEffectSheet = false
    }

    // MARK: - Supplements

    func addSupplement() {
        let entry = SupplementEntry(
            name: newSupplementName,
            dose: newSupplementDose,
            frequency: newSupplementFrequency
        )
        protocolData.supplements.append(entry)
        newSupplementName = ""
        newSupplementDose = ""
        newSupplementFrequency = "Daily"
        showAddSupplementSheet = false
    }

    func removeSupplement(_ entry: SupplementEntry) {
        protocolData.supplements.removeAll { $0.id == entry.id }
    }

    // MARK: - Notes

    func addNote() {
        let note = ProtocolNote(text: newNoteText)
        notes.insert(note, at: 0)
        newNoteText = ""
        showAddNoteSheet = false
    }

    // MARK: - Daily Ratings

    func addRating(category: String, value: Int) {
        let today = Calendar.current.startOfDay(for: Date())
        dailyRatings.removeAll { $0.category == category && Calendar.current.isDate($0.date, inSameDayAs: today) }
        let rating = DailyRating(category: category, value: value)
        dailyRatings.append(rating)
    }

    func todayRating(for category: String) -> Int? {
        let today = Calendar.current.startOfDay(for: Date())
        return dailyRatings.first { $0.category == category && Calendar.current.isDate($0.date, inSameDayAs: today) }?.value
    }

    // MARK: - Reconstitution

    var reconConcentration: Double? {
        guard let mg = Double(reconPeptideMg), let ml = Double(reconWaterMl), mg > 0, ml > 0 else { return nil }
        return (mg * 1000) / ml
    }

    var reconUnits: Double? {
        guard let conc = reconConcentration, let dose = Double(reconDesiredMcg), conc > 0, dose > 0 else { return nil }
        return (dose / conc) * 100
    }

    // MARK: - Cycle Progress

    var cycleProgressFraction: Double {
        let totalDays = max(1, protocolData.totalWeeks * 7)
        return min(Double(protocolData.currentDay) / Double(totalDays), 1.0)
    }

    var currentPhaseProgress: Double {
        let day = protocolData.currentDay
        let phase = protocolData.currentPhase
        let loadDays = protocolData.loadingWeeks * 7
        let mainDays = protocolData.maintenanceWeeks * 7
        let taperDays = protocolData.taperingWeeks * 7

        switch phase {
        case .loading:
            return loadDays > 0 ? Double(day) / Double(loadDays) : 0
        case .maintenance:
            let daysInPhase = day - loadDays
            return mainDays > 0 ? Double(daysInPhase) / Double(mainDays) : 0
        case .tapering:
            let daysInPhase = day - loadDays - mainDays
            return taperDays > 0 ? Double(daysInPhase) / Double(taperDays) : 0
        case .pct, .offCycle:
            let daysInPhase = day - loadDays - mainDays - taperDays
            let offDays = protocolData.offCycleWeeks * 7
            return offDays > 0 ? Double(daysInPhase) / Double(offDays) : 0
        }
    }

    var daysRemainingInPhase: Int {
        let day = protocolData.currentDay
        let loadDays = protocolData.loadingWeeks * 7
        let mainDays = protocolData.maintenanceWeeks * 7
        let taperDays = protocolData.taperingWeeks * 7
        let offDays = protocolData.offCycleWeeks * 7

        switch protocolData.currentPhase {
        case .loading: return max(0, loadDays - day)
        case .maintenance: return max(0, (loadDays + mainDays) - day)
        case .tapering: return max(0, (loadDays + mainDays + taperDays) - day)
        case .pct, .offCycle: return max(0, (loadDays + mainDays + taperDays + offDays) - day)
        }
    }

    // MARK: - Category Helpers

    var isWeightLoss: Bool { protocolData.goal == .weightLoss }
    var isHealing: Bool { protocolData.goal == .healing }
    var isMuscleGrowth: Bool { protocolData.goal == .muscleGrowth }
    var isCognitive: Bool { protocolData.goal == .cognitive }
    var isTanning: Bool { protocolData.goal == .tanning }
    var isCustom: Bool { protocolData.goal == .custom }

    var hasInjectableCompound: Bool {
        protocolData.compounds.contains { $0.injectionRoute == .subcutaneous || $0.injectionRoute == .intramuscular }
    }

    // MARK: - Setup

    private func setupTitrationSteps() {
        guard protocolData.goal == .weightLoss else { return }
        titrationSteps = [
            TitrationStep(weekNumber: 1, doseMcg: 250, label: "Starting Dose", isCompleted: protocolData.currentDay > 7),
            TitrationStep(weekNumber: 2, doseMcg: 500, label: "First Increase", isCompleted: protocolData.currentDay > 14),
            TitrationStep(weekNumber: 4, doseMcg: 1000, label: "Mid Titration", isCompleted: protocolData.currentDay > 28),
            TitrationStep(weekNumber: 6, doseMcg: 1700, label: "Approaching Target", isCompleted: protocolData.currentDay > 42),
            TitrationStep(weekNumber: 8, doseMcg: 2400, label: "Target Dose"),
        ]
    }

    private func setupRecoveryMilestones() {
        guard protocolData.goal == .healing else { return }
        recoveryMilestones = [
            RecoveryMilestone(title: "Reduced pain at rest"),
            RecoveryMilestone(title: "Pain-free walking"),
            RecoveryMilestone(title: "Light training resumed"),
            RecoveryMilestone(title: "Full range of motion"),
            RecoveryMilestone(title: "Return to full activity"),
        ]
    }

    private func setupSampleData() {
        let cal = Calendar.current
        protocolData.doseLog = (0..<5).map { i in
            DoseLogEntry(
                compoundName: protocolData.compounds.first?.compoundName ?? "BPC-157",
                doseMcg: protocolData.compounds.first?.doseMcg ?? 250,
                timestamp: cal.date(byAdding: .day, value: -i, to: Date()) ?? Date(),
                injectionSite: InjectionSite.allCases[i % InjectionSite.allCases.count],
                notes: i == 0 ? "Felt slight warmth at site" : ""
            )
        }

        protocolData.sideEffectLog = [
            SideEffectEntry(timestamp: cal.date(byAdding: .day, value: -1, to: Date()) ?? Date(), effect: "Nausea", severity: 1, notes: "Mild, passed quickly"),
            SideEffectEntry(timestamp: cal.date(byAdding: .day, value: -3, to: Date()) ?? Date(), effect: "Injection Site Redness", severity: 2),
        ]

        notes = [
            ProtocolNote(timestamp: cal.date(byAdding: .day, value: -1, to: Date()) ?? Date(), text: "Energy noticeably higher today. Felt warm 20 min after injection."),
            ProtocolNote(timestamp: cal.date(byAdding: .day, value: -3, to: Date()) ?? Date(), text: "Started feeling improvements in mobility. Less stiffness in the morning."),
        ]

        protocolData.supplements = [
            SupplementEntry(name: "NAC", dose: "600mg", frequency: "Daily"),
            SupplementEntry(name: "Vitamin D3", dose: "5000 IU", frequency: "Daily"),
            SupplementEntry(name: "Magnesium Glycinate", dose: "400mg", frequency: "Nightly"),
        ]
    }

    func toggleMilestone(_ milestone: RecoveryMilestone) {
        guard let idx = recoveryMilestones.firstIndex(where: { $0.id == milestone.id }) else { return }
        recoveryMilestones[idx].isAchieved.toggle()
        recoveryMilestones[idx].achievedDate = recoveryMilestones[idx].isAchieved ? Date() : nil
    }
}

nonisolated enum SiteRecency: Sendable {
    case unused, rotated, recentlyUsed, overused

    var color: Color {
        switch self {
        case .unused: return .gray.opacity(0.3)
        case .rotated: return .green
        case .recentlyUsed: return .yellow
        case .overused: return .red
        }
    }
}
