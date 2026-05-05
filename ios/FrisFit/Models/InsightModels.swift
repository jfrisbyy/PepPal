import SwiftUI

nonisolated enum InsightDomain: String, Sendable, Codable {
    case protocolImpact = "protocol"
    case training
    case nutrition
    case body
    case recovery
    case sideEffects = "side_effects"
    case bloodwork
    case cross

    var label: String {
        switch self {
        case .protocolImpact: "Protocol"
        case .training: "Training"
        case .nutrition: "Nutrition"
        case .body: "Body"
        case .recovery: "Recovery"
        case .sideEffects: "Side Effects"
        case .bloodwork: "Bloodwork"
        case .cross: "Cross-domain"
        }
    }

    var color: Color {
        switch self {
        case .protocolImpact: PepTheme.teal
        case .training: PepTheme.blue
        case .nutrition: PepTheme.amber
        case .body: .green
        case .recovery: PepTheme.violet
        case .sideEffects: .orange
        case .bloodwork: .red
        case .cross: PepTheme.teal
        }
    }

    var icon: String {
        switch self {
        case .protocolImpact: "pill.fill"
        case .training: "figure.strengthtraining.traditional"
        case .nutrition: "fork.knife"
        case .body: "scalemass.fill"
        case .recovery: "moon.zzz.fill"
        case .sideEffects: "exclamationmark.triangle.fill"
        case .bloodwork: "drop.fill"
        case .cross: "sparkles"
        }
    }
}

nonisolated struct EvidencePoint: Identifiable, Sendable, Codable {
    let id: UUID
    let label: String
    let value: String
    let detail: String?
    let tool: String

    init(label: String, value: String, detail: String? = nil, tool: String) {
        self.id = UUID()
        self.label = label
        self.value = value
        self.detail = detail
        self.tool = tool
    }
}

nonisolated struct AgentInsight: Identifiable, Sendable, Codable {
    let id: UUID
    let headline: String
    let body: String
    let domain: InsightDomain
    let evidence: [EvidencePoint]
    let actions: [String]
    let providerFlag: Bool

    init(
        headline: String,
        body: String,
        domain: InsightDomain,
        evidence: [EvidencePoint] = [],
        actions: [String] = [],
        providerFlag: Bool = false
    ) {
        self.id = UUID()
        self.headline = headline
        self.body = body
        self.domain = domain
        self.evidence = evidence
        self.actions = actions
        self.providerFlag = providerFlag
    }
}

nonisolated struct ProtocolImpactMetric: Identifiable, Sendable, Codable {
    let id: UUID
    let label: String
    let baselineValue: String
    let currentValue: String
    let deltaPercent: Double?
    let direction: Direction
    let domain: InsightDomain
    let takeaway: String
    let sparkline: [Double]

    enum Direction: String, Sendable, Codable { case up, down, flat, mixed }

    init(
        label: String,
        baselineValue: String,
        currentValue: String,
        deltaPercent: Double?,
        direction: Direction,
        domain: InsightDomain,
        takeaway: String,
        sparkline: [Double]
    ) {
        self.id = UUID()
        self.label = label
        self.baselineValue = baselineValue
        self.currentValue = currentValue
        self.deltaPercent = deltaPercent
        self.direction = direction
        self.domain = domain
        self.takeaway = takeaway
        self.sparkline = sparkline
    }
}

nonisolated struct AgentInvestigationResult: Sendable, Codable {
    let hero: AgentInsight?
    let patterns: [AgentInsight]
    let impact: [ProtocolImpactMetric]
    let generatedAt: Date
    let dataPointsChecked: Int
    let dataHash: String
}

nonisolated struct AgentAskTurn: Identifiable, Sendable {
    let id: UUID
    let question: String
    var answer: String
    var evidence: [EvidencePoint]
    var isStreaming: Bool

    init(question: String, answer: String = "", evidence: [EvidencePoint] = [], isStreaming: Bool = true) {
        self.id = UUID()
        self.question = question
        self.answer = answer
        self.evidence = evidence
        self.isStreaming = isStreaming
    }
}
