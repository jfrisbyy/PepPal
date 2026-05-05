import Foundation
import SwiftUI

nonisolated enum UsernameAvailability: Sendable, Equatable {
    case idle
    case checking
    case available
    case taken
    case invalid(reason: String)
}

nonisolated enum SocialIdentityRules {
    static let minLength = 3
    static let maxLength = 20
    static let allowed: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "_.")
        return set
    }()

    static func isValidFormat(_ raw: String) -> Bool {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.count >= minLength, s.count <= maxLength else { return false }
        guard s.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }
        // First char must be a letter or digit (no leading underscore/dot).
        guard let first = s.first, first.isLetter || first.isNumber else { return false }
        return true
    }

    static func validationMessage(_ raw: String) -> String? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return nil }
        if s.count < minLength { return "At least \(minLength) characters." }
        if s.count > maxLength { return "At most \(maxLength) characters." }
        if let first = s.first, !(first.isLetter || first.isNumber) { return "Start with a letter or number." }
        if !s.unicodeScalars.allSatisfy({ allowed.contains($0) }) {
            return "Letters, numbers, _ and . only."
        }
        return nil
    }

    static func suggest(from seed: String) -> String {
        let lower = seed.lowercased()
        let scalars = lower.unicodeScalars.filter { allowed.contains($0) }
        var s = String(String.UnicodeScalarView(scalars))
        if let first = s.first, !(first.isLetter || first.isNumber) {
            s = String(s.dropFirst())
        }
        if s.count < minLength {
            s += String(Int.random(in: 100...9999))
        }
        return String(s.prefix(maxLength))
    }
}

nonisolated enum OnboardingAvatarPalette {
    /// Curated palette stored on `profiles.avatar_color` as hex strings.
    static let swatches: [String] = [
        "#00C9A7", // teal
        "#8B5CF6", // violet
        "#FFB800", // amber
        "#4A9EFF", // blue
        "#FF7A59", // coral
        "#F472B6", // pink
        "#10B981", // emerald
        "#EF4444"  // crimson
    ]

    static func color(forHex hex: String) -> Color {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return .gray }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        return Color(red: r, green: g, blue: b)
    }
}

nonisolated enum PersonaTrack: String, Codable, Sendable, CaseIterable {
    case A
    case B
    case C

    var title: String {
        switch self {
        case .A: "Fitness Only"
        case .B: "Curious about peptides"
        case .C: "Active or Experienced"
        }
    }

    var subtitle: String {
        switch self {
        case .A: "Train, eat, recover. No peptide tracking."
        case .B: "I'm researching — show me how EPTI helps me learn safely."
        case .C: "I'm running protocols — full peptide capture, cycles & dosing."
        }
    }

    var icon: String {
        switch self {
        case .A: "figure.run"
        case .B: "book.fill"
        case .C: "syringe.fill"
        }
    }
}

nonisolated enum OnboardingChapter: Int, CaseIterable, Sendable {
    case welcome = 0
    case aboutYou
    case connect
    case goals
    case journey
    case finish

    var title: String {
        switch self {
        case .welcome: "Welcome"
        case .aboutYou: "About You"
        case .connect: "Connect"
        case .goals: "Goals"
        case .journey: "Journey"
        case .finish: "Finish"
        }
    }

    var analyticsKey: String {
        switch self {
        case .welcome: "welcome"
        case .aboutYou: "about_you"
        case .connect: "connect"
        case .goals: "goals"
        case .journey: "journey"
        case .finish: "finish"
        }
    }
}

nonisolated enum OnboardingStep: Int, CaseIterable, Sendable {
    case welcome = 0
    case disclaimer
    case persona
    case account
    case socialIdentity
    case aboutYou
    case ageBlocked
    case pregnancyGate
    case connect
    case goals
    case journey
    case finish

    var chapter: OnboardingChapter {
        switch self {
        case .welcome, .disclaimer, .persona, .account, .socialIdentity: .welcome
        case .aboutYou, .ageBlocked, .pregnancyGate: .aboutYou
        case .connect: .connect
        case .goals: .goals
        case .journey: .journey
        case .finish: .finish
        }
    }

    var canSkip: Bool {
        switch self {
        case .disclaimer, .persona, .account, .socialIdentity, .aboutYou, .ageBlocked, .pregnancyGate: false
        default: true
        }
    }
}

nonisolated struct DisclaimerAcknowledgement: Codable, Sendable {
    let user_id: String
    let version: String
    let accepted_at: String
}

nonisolated struct OnboardingDraft: Codable, Sendable {
    var step: Int
    var personaTrack: String?
    var disclaimerAcceptedAt: Date?
    var disclaimerVersion: String?

    var firstName: String
    var dateOfBirth: Date?
    var biologicalSex: String?
    var isPregnantOrNursing: Bool?

    var unitSystem: String
    var heightCm: Double?
    var weightKg: Double?
    var bodyFatPercent: Double?
    var neckCm: Double?
    var waistCm: Double?
    var hipCm: Double?
    var activityLevel: String?

    var bmrKcal: Double?
    var tdeeKcal: Double?
    var dailyWaterMl: Int?
    var dailyStepFloor: Int?
    var starterCalories: Int?
    var starterProtein: Int?
    var starterCarbs: Int?
    var starterFat: Int?

    var primaryGoal: String?
    var secondaryGoal: String?
    var targetWeightKg: Double?
    var targetBodyFatPercent: Double?
    var targetPerformanceMetric: String
    var targetDate: Date?

    var sessionsPerWeek: Int
    var trainingModalities: [String]
    var experienceLevel: String?
    var currentProgramName: String
    var injuries: [String]
    var otherInjuryNote: String

    var dietStyle: String?
    var priorTracker: String?
    var proteinPerKgOverride: Double?
    var allergies: [String]
    var allergiesOther: String
    var restrictions: [String]
    var restrictionsOther: String

    var goalDefaults: GoalSmartDefaults?

    var socialUsername: String?
    var avatarColorHex: String?
    var avatarImageURL: String?
}
