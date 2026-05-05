import Foundation

nonisolated struct MorningBrief: Sendable, Codable {
    let greeting: String
    let headline: String
    let body: String
    let recovery: BriefLine?
    let dose: BriefLine?
    let training: BriefLine?
    let nutrition: BriefLine?
    let watchFor: String?
    let generatedAt: Date
    let date: Date
}

nonisolated struct BriefLine: Sendable, Codable {
    let label: String
    let value: String
    let detail: String
    let tone: Tone

    nonisolated enum Tone: String, Sendable, Codable {
        case positive, neutral, caution, warning
    }
}
