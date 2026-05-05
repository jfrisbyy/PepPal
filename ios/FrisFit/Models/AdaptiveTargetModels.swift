import Foundation

nonisolated struct AdaptiveAdjustment: Identifiable, Sendable, Codable {
    let id: UUID
    let domain: Domain
    let label: String
    let previousValue: String
    let proposedValue: String
    let reasoning: String
    let createdAt: Date
    var status: Status

    nonisolated enum Domain: String, Sendable, Codable, CaseIterable {
        case calories, protein, training, doseDayNutrition

        var label: String {
            switch self {
            case .calories: return "Calories"
            case .protein: return "Protein"
            case .training: return "Training Volume"
            case .doseDayNutrition: return "Dose-Day Nutrition"
            }
        }

        var icon: String {
            switch self {
            case .calories: return "flame.fill"
            case .protein: return "leaf.fill"
            case .training: return "figure.strengthtraining.traditional"
            case .doseDayNutrition: return "pill.fill"
            }
        }
    }

    nonisolated enum Status: String, Sendable, Codable {
        case proposed, accepted, reverted, dismissed
    }

    init(
        id: UUID = UUID(),
        domain: Domain,
        label: String,
        previousValue: String,
        proposedValue: String,
        reasoning: String,
        createdAt: Date = Date(),
        status: Status = .proposed
    ) {
        self.id = id
        self.domain = domain
        self.label = label
        self.previousValue = previousValue
        self.proposedValue = proposedValue
        self.reasoning = reasoning
        self.createdAt = createdAt
        self.status = status
    }
}

nonisolated struct WeeklyRecalibration: Sendable, Codable {
    let weekStart: Date
    let adjustments: [AdaptiveAdjustment]
    let summary: String
    let generatedAt: Date
}
