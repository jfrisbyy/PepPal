import SwiftUI

nonisolated enum ProtocolGoal: String, CaseIterable, Identifiable, Sendable {
    case weightLoss = "Weight Loss"
    case muscleGrowth = "Muscle Growth"
    case healing = "Healing & Recovery"
    case cognitive = "Cognitive Enhancement"
    case tanning = "Tanning & Cosmetic"
    case custom = "Custom"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .weightLoss: return "scalemass.fill"
        case .muscleGrowth: return "figure.strengthtraining.traditional"
        case .healing: return "cross.case.fill"
        case .cognitive: return "brain.head.profile"
        case .tanning: return "sun.max.fill"
        case .custom: return "slider.horizontal.3"
        }
    }

    var color: Color {
        switch self {
        case .weightLoss: return .green
        case .muscleGrowth: return PepTheme.teal
        case .healing: return PepTheme.blue
        case .cognitive: return PepTheme.violet
        case .tanning: return .orange
        case .custom: return PepTheme.textSecondary
        }
    }
}

nonisolated enum CyclePhase: String, CaseIterable, Sendable {
    case loading = "Loading"
    case maintenance = "Maintenance"
    case tapering = "Tapering"
    case pct = "PCT"
    case offCycle = "Off-Cycle"

    var color: Color {
        switch self {
        case .loading: return PepTheme.teal
        case .maintenance: return PepTheme.blue
        case .tapering: return PepTheme.amber
        case .pct: return PepTheme.violet
        case .offCycle: return PepTheme.textSecondary
        }
    }
}

nonisolated enum InjectionRoute: String, CaseIterable, Sendable {
    case subcutaneous = "Subcutaneous"
    case intramuscular = "Intramuscular"
    case oral = "Oral"
    case nasal = "Nasal"
    case topical = "Topical"
}

nonisolated enum InjectionSite: String, CaseIterable, Identifiable, Sendable {
    case leftDeltoid = "Left Deltoid"
    case rightDeltoid = "Right Deltoid"
    case leftAbdomen = "Left Abdomen"
    case rightAbdomen = "Right Abdomen"
    case leftThigh = "Left Thigh"
    case rightThigh = "Right Thigh"
    case leftGlute = "Left Glute"
    case rightGlute = "Right Glute"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .leftDeltoid: return "L Delt"
        case .rightDeltoid: return "R Delt"
        case .leftAbdomen: return "L Abd"
        case .rightAbdomen: return "R Abd"
        case .leftThigh: return "L Thigh"
        case .rightThigh: return "R Thigh"
        case .leftGlute: return "L Glute"
        case .rightGlute: return "R Glute"
        }
    }
}

nonisolated struct ProtocolCompound: Identifiable, Sendable {
    let id: UUID
    var supabaseId: String?
    let compoundName: String
    let doseMcg: Double
    let frequency: String
    let timeOfDay: Date
    let injectionRoute: InjectionRoute
    let reconstitutionVolume: Double?
    let vialSizeMg: Double?
    var vendorName: String?
    var batchNumber: String?
    var manufactureDate: Date?
    var expirationDate: Date?

    init(
        compoundName: String,
        doseMcg: Double,
        frequency: String = "Daily",
        timeOfDay: Date = Date(),
        injectionRoute: InjectionRoute = .subcutaneous,
        reconstitutionVolume: Double? = nil,
        vialSizeMg: Double? = nil,
        vendorName: String? = nil,
        batchNumber: String? = nil,
        manufactureDate: Date? = nil,
        expirationDate: Date? = nil
    ) {
        self.id = UUID()
        self.compoundName = compoundName
        self.doseMcg = doseMcg
        self.frequency = frequency
        self.timeOfDay = timeOfDay
        self.injectionRoute = injectionRoute
        self.reconstitutionVolume = reconstitutionVolume
        self.vialSizeMg = vialSizeMg
        self.vendorName = vendorName
        self.batchNumber = batchNumber
        self.manufactureDate = manufactureDate
        self.expirationDate = expirationDate
    }
}

nonisolated struct PeptideProtocol: Identifiable, Sendable {
    let id: UUID
    var supabaseId: String?
    var name: String
    let goal: ProtocolGoal
    var compounds: [ProtocolCompound]
    let startDate: Date
    let totalWeeks: Int
    let loadingWeeks: Int
    let maintenanceWeeks: Int
    let taperingWeeks: Int
    let offCycleWeeks: Int
    var isActive: Bool
    var doseLog: [DoseLogEntry]
    var sideEffectLog: [SideEffectEntry]
    var supplements: [SupplementEntry]

    init(
        name: String = "My Protocol",
        goal: ProtocolGoal = .custom,
        compounds: [ProtocolCompound] = [],
        startDate: Date = Date(),
        totalWeeks: Int = 8,
        loadingWeeks: Int = 1,
        maintenanceWeeks: Int = 5,
        taperingWeeks: Int = 1,
        offCycleWeeks: Int = 4,
        isActive: Bool = true,
        doseLog: [DoseLogEntry] = [],
        sideEffectLog: [SideEffectEntry] = [],
        supplements: [SupplementEntry] = []
    ) {
        self.id = UUID()
        self.name = name
        self.goal = goal
        self.compounds = compounds
        self.startDate = startDate
        self.totalWeeks = totalWeeks
        self.loadingWeeks = loadingWeeks
        self.maintenanceWeeks = maintenanceWeeks
        self.taperingWeeks = taperingWeeks
        self.offCycleWeeks = offCycleWeeks
        self.isActive = isActive
        self.doseLog = doseLog
        self.sideEffectLog = sideEffectLog
        self.supplements = supplements
    }

    var currentDay: Int {
        max(1, Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 1)
    }

    var currentPhase: CyclePhase {
        let week = (currentDay - 1) / 7 + 1
        if week <= loadingWeeks { return .loading }
        if week <= loadingWeeks + maintenanceWeeks { return .maintenance }
        if week <= loadingWeeks + maintenanceWeeks + taperingWeeks { return .tapering }
        return .offCycle
    }

    var nextDose: ProtocolCompound? {
        compounds.first
    }
}

nonisolated struct DoseLogEntry: Identifiable, Sendable {
    let id: UUID
    var supabaseId: String?
    let compoundName: String
    let doseMcg: Double
    let timestamp: Date
    let injectionSite: InjectionSite
    let notes: String

    init(compoundName: String, doseMcg: Double, timestamp: Date = Date(), injectionSite: InjectionSite = .leftAbdomen, notes: String = "") {
        self.id = UUID()
        self.compoundName = compoundName
        self.doseMcg = doseMcg
        self.timestamp = timestamp
        self.injectionSite = injectionSite
        self.notes = notes
    }
}

nonisolated struct SideEffectEntry: Identifiable, Sendable {
    let id: UUID
    var supabaseId: String?
    let timestamp: Date
    let effect: String
    let severity: Int
    let notes: String

    init(timestamp: Date = Date(), effect: String, severity: Int = 1, notes: String = "") {
        self.id = UUID()
        self.timestamp = timestamp
        self.effect = effect
        self.severity = severity
        self.notes = notes
    }
}

nonisolated struct SupplementEntry: Identifiable, Sendable {
    let id: UUID
    var supabaseId: String?
    var name: String
    var dose: String
    var frequency: String

    init(name: String, dose: String = "", frequency: String = "Daily") {
        self.id = UUID()
        self.name = name
        self.dose = dose
        self.frequency = frequency
    }
}

nonisolated struct TitrationStep: Identifiable, Sendable {
    let id: UUID
    let weekNumber: Int
    let doseMcg: Double
    let label: String
    var isCompleted: Bool

    init(weekNumber: Int, doseMcg: Double, label: String = "", isCompleted: Bool = false) {
        self.id = UUID()
        self.weekNumber = weekNumber
        self.doseMcg = doseMcg
        self.label = label
        self.isCompleted = isCompleted
    }
}

nonisolated struct ProtocolNote: Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    var text: String
    let doseLogId: UUID?

    init(timestamp: Date = Date(), text: String, doseLogId: UUID? = nil) {
        self.id = UUID()
        self.timestamp = timestamp
        self.text = text
        self.doseLogId = doseLogId
    }
}

nonisolated struct DailyRating: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let category: String
    let value: Int
    let label: String

    init(date: Date = Date(), category: String, value: Int, label: String = "") {
        self.id = UUID()
        self.date = date
        self.category = category
        self.value = value
        self.label = label
    }
}

nonisolated struct RecoveryMilestone: Identifiable, Sendable {
    let id: UUID
    let title: String
    var isAchieved: Bool
    var achievedDate: Date?

    init(title: String, isAchieved: Bool = false, achievedDate: Date? = nil) {
        self.id = UUID()
        self.title = title
        self.isAchieved = isAchieved
        self.achievedDate = achievedDate
    }
}

nonisolated struct ProtocolBodyMeasurement: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let area: String
    let value: Double
    let unit: String

    init(date: Date = Date(), area: String, value: Double, unit: String = "in") {
        self.id = UUID()
        self.date = date
        self.area = area
        self.value = value
        self.unit = unit
    }
}

nonisolated enum AdministrationRoute: String, CaseIterable, Sendable {
    case subcutaneous = "Subcutaneous"
    case intramuscular = "Intramuscular"
    case intranasal = "Intranasal"
    case oral = "Oral"
    case topical = "Topical"
}

nonisolated enum NasalSide: String, CaseIterable, Sendable {
    case left = "Left Nostril"
    case right = "Right Nostril"
    case both = "Both"
}
