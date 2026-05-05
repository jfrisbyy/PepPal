import Foundation

nonisolated struct BloodworkInterpretation: Sendable, Codable {
    let headline: String
    let summary: String
    let flags: [BloodworkFlag]
    let recheckRecommendationDays: Int?
    let recheckReason: String?
    let providerFlag: Bool
    let generatedAt: Date
}

nonisolated struct BloodworkFlag: Identifiable, Sendable, Codable {
    var id: String { biomarker }
    let biomarker: String
    let value: String
    let status: String
    let interpretation: String
    let protocolContext: String?
}
