import SwiftUI

nonisolated enum PeptideCategory: String, CaseIterable, Identifiable, Sendable {
    case weightLoss = "Weight Loss"
    case muscleGrowth = "Muscle Growth"
    case healing = "Healing & Recovery"
    case cognitive = "Cognitive"
    case sexualHealth = "Sexual Health"
    case tanning = "Tanning & Skin"
    case antiAging = "Anti-Aging"
    case sarms = "SARMs"
    case igfVariants = "IGF Variants"
    case hormonal = "Hormonal & PCT"
    case ancillary = "Ancillaries"
    case niche = "Niche"
    case all = "All"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .weightLoss: return "scalemass.fill"
        case .muscleGrowth: return "figure.strengthtraining.traditional"
        case .healing: return "cross.case.fill"
        case .cognitive: return "brain.head.profile"
        case .sexualHealth: return "heart.fill"
        case .tanning: return "sun.max.fill"
        case .antiAging: return "hourglass"
        case .sarms: return "bolt.fill"
        case .igfVariants: return "arrow.up.forward"
        case .hormonal: return "arrow.triangle.2.circlepath"
        case .ancillary: return "pills.fill"
        case .niche: return "flask.fill"
        case .all: return "square.grid.2x2.fill"
        }
    }

    var color: Color {
        switch self {
        case .weightLoss: return .green
        case .muscleGrowth: return PepTheme.teal
        case .healing: return PepTheme.blue
        case .cognitive: return PepTheme.violet
        case .sexualHealth: return .pink
        case .tanning: return .orange
        case .antiAging: return Color(red: 200/255, green: 120/255, blue: 220/255)
        case .sarms: return .red
        case .igfVariants: return Color(red: 255/255, green: 140/255, blue: 50/255)
        case .hormonal: return Color(red: 52/255, green: 152/255, blue: 219/255)
        case .ancillary: return Color(red: 149/255, green: 165/255, blue: 166/255)
        case .niche: return Color(red: 100/255, green: 200/255, blue: 220/255)
        case .all: return PepTheme.teal
        }
    }
}

nonisolated struct CompoundSideEffect: Identifiable, Sendable {
    let id: UUID
    let name: String
    let severity: SideEffectSeverity
    let frequency: Int

    init(name: String, severity: SideEffectSeverity = .mild, frequency: Int = 10) {
        self.id = UUID()
        self.name = name
        self.severity = severity
        self.frequency = frequency
    }
}

nonisolated enum SideEffectSeverity: String, Sendable {
    case mild = "Mild"
    case moderate = "Moderate"
    case significant = "Significant"

    var color: Color {
        switch self {
        case .mild: return .green
        case .moderate: return .yellow
        case .significant: return .orange
        }
    }
}

nonisolated struct CompoundKeyFacts: Sendable {
    let molecularWeight: String
    let administrationRoute: String
    let halfLife: String
    let storageTemp: String
    let reconstitution: String
    let typicalDoseRange: String

    init(
        molecularWeight: String = "—",
        administrationRoute: String = "Subcutaneous",
        halfLife: String = "—",
        storageTemp: String = "2-8°C",
        reconstitution: String = "BAC Water",
        typicalDoseRange: String = "—"
    ) {
        self.molecularWeight = molecularWeight
        self.administrationRoute = administrationRoute
        self.halfLife = halfLife
        self.storageTemp = storageTemp
        self.reconstitution = reconstitution
        self.typicalDoseRange = typicalDoseRange
    }
}

nonisolated struct TieredDose: Identifiable, Sendable {
    let id: UUID
    let tier: String
    let dose: String
    let frequency: String
    let timingNotes: String

    init(tier: String, dose: String, frequency: String, timingNotes: String) {
        self.id = UUID()
        self.tier = tier
        self.dose = dose
        self.frequency = frequency
        self.timingNotes = timingNotes
    }
}

nonisolated struct ReconstitutionGuide: Sendable {
    let typicalVialSize: String
    let diluent: String
    let reconstitutionMath: String
    let storageLyophilized: String
    let storageReconstituted: String
    let handlingNotes: String

    init(
        typicalVialSize: String = "—",
        diluent: String = "Bacteriostatic Water",
        reconstitutionMath: String = "—",
        storageLyophilized: String = "Freezer (-20°C)",
        storageReconstituted: String = "Fridge (2-8°C)",
        handlingNotes: String = "Do not shake; swirl gently to dissolve."
    ) {
        self.typicalVialSize = typicalVialSize
        self.diluent = diluent
        self.reconstitutionMath = reconstitutionMath
        self.storageLyophilized = storageLyophilized
        self.storageReconstituted = storageReconstituted
        self.handlingNotes = handlingNotes
    }
}

nonisolated struct BloodworkMarker: Identifiable, Sendable {
    let id: UUID
    let marker: String
    let baseline: String
    let onCycle: String
    let reason: String

    init(marker: String, baseline: String, onCycle: String, reason: String) {
        self.id = UUID()
        self.marker = marker
        self.baseline = baseline
        self.onCycle = onCycle
        self.reason = reason
    }
}

nonisolated struct StackDetail: Identifiable, Sendable {
    let id: UUID
    let partner: String
    let purpose: String
    let notes: String

    init(partner: String, purpose: String, notes: String = "") {
        self.id = UUID()
        self.partner = partner
        self.purpose = purpose
        self.notes = notes
    }
}

nonisolated struct EvidenceSummary: Sendable {
    let level: String
    let keyStudies: [String]
    let researchGaps: String

    init(level: String = "—", keyStudies: [String] = [], researchGaps: String = "") {
        self.level = level
        self.keyStudies = keyStudies
        self.researchGaps = researchGaps
    }
}

nonisolated struct DetailedSideEffects: Sendable {
    let common: [String]
    let uncommon: [String]
    let rare: [String]
    let contraindications: [String]

    init(common: [String] = [], uncommon: [String] = [], rare: [String] = [], contraindications: [String] = []) {
        self.common = common
        self.uncommon = uncommon
        self.rare = rare
        self.contraindications = contraindications
    }
}

nonisolated struct CompoundProfile: Identifiable, Sendable {
    let id: UUID
    let name: String
    let peptideType: String
    let categories: [PeptideCategory]
    let overview: String
    let protocols: [CompoundProtocol]
    let sideEffects: [String]
    let structuredSideEffects: [CompoundSideEffect]
    let communityUsers: Int
    let averageRating: Double
    let stackPartners: [String]
    let iconName: String
    let keyFacts: CompoundKeyFacts
    let primaryUseCases: [String]
    let tieredDosing: [TieredDose]
    let cycleLength: String
    let loadingProtocol: String
    let onOffCycling: String
    let reconstitutionGuide: ReconstitutionGuide
    let bloodworkMarkers: [BloodworkMarker]
    let nutritionalSupport: [String]
    let beginnerTips: [String]
    let evidence: EvidenceSummary
    let stackDetails: [StackDetail]
    let detailedSideEffects: DetailedSideEffects
    let isWADAProhibited: Bool
    let wadaCategory: String

    init(
        name: String,
        peptideType: String,
        categories: [PeptideCategory],
        overview: String,
        protocols: [CompoundProtocol] = [],
        sideEffects: [String] = [],
        structuredSideEffects: [CompoundSideEffect] = [],
        communityUsers: Int = 0,
        averageRating: Double = 0,
        stackPartners: [String] = [],
        iconName: String = "pill.fill",
        keyFacts: CompoundKeyFacts = CompoundKeyFacts(),
        primaryUseCases: [String] = [],
        tieredDosing: [TieredDose] = [],
        cycleLength: String = "",
        loadingProtocol: String = "No",
        onOffCycling: String = "",
        reconstitutionGuide: ReconstitutionGuide = ReconstitutionGuide(),
        bloodworkMarkers: [BloodworkMarker] = [],
        nutritionalSupport: [String] = [],
        beginnerTips: [String] = [],
        evidence: EvidenceSummary = EvidenceSummary(),
        stackDetails: [StackDetail] = [],
        detailedSideEffects: DetailedSideEffects = DetailedSideEffects(),
        isWADAProhibited: Bool = false,
        wadaCategory: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.peptideType = peptideType
        self.categories = categories
        self.overview = overview
        self.protocols = protocols
        self.sideEffects = sideEffects
        self.structuredSideEffects = structuredSideEffects
        self.communityUsers = communityUsers
        self.averageRating = averageRating
        self.stackPartners = stackPartners
        self.iconName = iconName
        self.keyFacts = keyFacts
        self.primaryUseCases = primaryUseCases
        self.tieredDosing = tieredDosing
        self.cycleLength = cycleLength
        self.loadingProtocol = loadingProtocol
        self.onOffCycling = onOffCycling
        self.reconstitutionGuide = reconstitutionGuide
        self.bloodworkMarkers = bloodworkMarkers
        self.nutritionalSupport = nutritionalSupport
        self.beginnerTips = beginnerTips
        self.evidence = evidence
        self.stackDetails = stackDetails
        self.detailedSideEffects = detailedSideEffects
        self.isWADAProhibited = isWADAProhibited
        self.wadaCategory = wadaCategory
    }
}

nonisolated struct CompoundProtocol: Identifiable, Sendable {
    let id: UUID
    let goalName: String
    let description: String
    let typicalDose: String
    let frequency: String
    let duration: String

    init(goalName: String, description: String, typicalDose: String, frequency: String, duration: String) {
        self.id = UUID()
        self.goalName = goalName
        self.description = description
        self.typicalDose = typicalDose
        self.frequency = frequency
        self.duration = duration
    }
}

nonisolated struct Vendor: Identifiable, Sendable {
    let id: UUID
    let name: String
    let isVerified: Bool
    let rating: Double
    let reviewCount: Int
    let compoundsCarried: [String]
    let websiteURL: String
    let reviews: [VendorReview]

    init(name: String, isVerified: Bool, rating: Double, reviewCount: Int, compoundsCarried: [String], websiteURL: String, reviews: [VendorReview] = []) {
        self.id = UUID()
        self.name = name
        self.isVerified = isVerified
        self.rating = rating
        self.reviewCount = reviewCount
        self.compoundsCarried = compoundsCarried
        self.websiteURL = websiteURL
        self.reviews = reviews
    }
}

nonisolated struct VendorReview: Identifiable, Sendable {
    let id: UUID
    let userName: String
    let rating: Int
    let text: String
    let date: Date

    init(userName: String, rating: Int, text: String, daysAgo: Int = 0) {
        self.id = UUID()
        self.userName = userName
        self.rating = rating
        self.text = text
        self.date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
    }
}
