import SwiftUI

nonisolated enum PeptideCategory: String, CaseIterable, Identifiable, Sendable {
    case weightLoss = "Weight Loss"
    case muscleGrowth = "Muscle Growth"
    case healing = "Healing & Recovery"
    case cognitive = "Cognitive"
    case tanning = "Tanning & Cosmetic"
    case antiAging = "Anti-Aging"
    case all = "All"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .weightLoss: return "scalemass.fill"
        case .muscleGrowth: return "figure.strengthtraining.traditional"
        case .healing: return "cross.case.fill"
        case .cognitive: return "brain.head.profile"
        case .tanning: return "sun.max.fill"
        case .antiAging: return "hourglass"
        case .all: return "square.grid.2x2.fill"
        }
    }

    var color: Color {
        switch self {
        case .weightLoss: return .green
        case .muscleGrowth: return PepTheme.teal
        case .healing: return PepTheme.blue
        case .cognitive: return PepTheme.violet
        case .tanning: return .orange
        case .antiAging: return .pink
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
        keyFacts: CompoundKeyFacts = CompoundKeyFacts()
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
