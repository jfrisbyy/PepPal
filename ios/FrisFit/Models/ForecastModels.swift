import Foundation

nonisolated struct WeightForecastPoint: Identifiable, Sendable, Codable {
    var id: String { ISO8601DateFormatter().string(from: date) }
    let date: Date
    let projected: Double
    let lowerBound: Double
    let upperBound: Double
}

nonisolated struct WeightForecast: Sendable, Codable {
    let currentWeight: Double
    let goalWeight: Double
    let weeklyRate: Double
    let plateauRiskPercent: Int
    let points: [WeightForecastPoint]
    let reasoning: String
    let calibrationDays: Int
}

nonisolated struct FlareRisk: Sendable, Codable {
    let riskLevel: RiskLevel
    let scorePercent: Int
    let drivers: [String]
    let reasoning: String

    nonisolated enum RiskLevel: String, Sendable, Codable {
        case low, elevated, high
    }
}

nonisolated struct PRReadiness: Identifiable, Sendable, Codable {
    var id: String { exercise }
    let exercise: String
    let readinessPercent: Int
    let recommendation: String
    let greenLights: [String]
    let redFlags: [String]
}

nonisolated struct ForecastBundle: Sendable, Codable {
    let weight: WeightForecast?
    let flare: FlareRisk?
    let prReadiness: [PRReadiness]
    let generatedAt: Date
    let dataHash: String
}
