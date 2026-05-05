import SwiftUI

nonisolated enum DeckUrgency: String, Sendable, Codable {
    case high
    case medium
    case low

    var label: String {
        switch self {
        case .high: "Act today"
        case .medium: "Worth doing"
        case .low: "Nice to have"
        }
    }

    var color: Color {
        switch self {
        case .high: return Color(red: 0.95, green: 0.35, blue: 0.35)
        case .medium: return PepTheme.amber
        case .low: return PepTheme.blue
        }
    }

    var sortWeight: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }
}

nonisolated struct AIDeckSuggestion: Identifiable, Sendable, Codable {
    let id: String
    let title: String
    let icon: String
    let category: TaskCategory
    let reason: String
    let urgency: DeckUrgency
    let evidence: [EvidencePoint]
    let generatedAt: Date

    init(
        id: String,
        title: String,
        icon: String,
        category: TaskCategory,
        reason: String,
        urgency: DeckUrgency,
        evidence: [EvidencePoint],
        generatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.category = category
        self.reason = reason
        self.urgency = urgency
        self.evidence = evidence
        self.generatedAt = generatedAt
    }
}

nonisolated enum DeckRefreshPeriod: String, Sendable, Codable {
    case morning
    case afternoon

    var label: String {
        switch self {
        case .morning: return "Morning plan"
        case .afternoon: return "Afternoon recalibration"
        }
    }

    static func current(for date: Date = Date()) -> DeckRefreshPeriod {
        let hour = Calendar.current.component(.hour, from: date)
        return hour < 13 ? .morning : .afternoon
    }
}

nonisolated enum DeckDismissReason: String, Sendable, Codable, CaseIterable {
    case snooze
    case notRelevant
    case alreadyDoing

    var label: String {
        switch self {
        case .snooze: return "Not today"
        case .notRelevant: return "Not relevant"
        case .alreadyDoing: return "Already doing it"
        }
    }

    var icon: String {
        switch self {
        case .snooze: return "clock.fill"
        case .notRelevant: return "xmark.circle.fill"
        case .alreadyDoing: return "checkmark.circle.fill"
        }
    }
}
