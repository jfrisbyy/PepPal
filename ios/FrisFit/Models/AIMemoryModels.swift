import Foundation

/// A single thing the AI has learned and remembered about the user.
/// Memory is persisted locally and used to contextualize every AI call.
nonisolated struct AIMemoryFact: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var kind: Kind
    var headline: String
    var detail: String
    var domain: String
    var evidence: String
    var confidence: Double
    var createdAt: Date
    var updatedAt: Date
    var lastReinforcedAt: Date
    var reinforceCount: Int
    var isPinned: Bool
    var isMuted: Bool
    var expiresAt: Date?
    var contradictedBy: [UUID]
    var sourceTag: String

    nonisolated enum Kind: String, Codable, Sendable, CaseIterable {
        case pattern
        case preference
        case correlation
        case milestone
        case concern
        case investigation

        var label: String {
            switch self {
            case .pattern: return "Pattern"
            case .preference: return "Preference"
            case .correlation: return "Correlation"
            case .milestone: return "Milestone"
            case .concern: return "Concern"
            case .investigation: return "Past Investigation"
            }
        }

        var icon: String {
            switch self {
            case .pattern: return "waveform.path.ecg"
            case .preference: return "heart.fill"
            case .correlation: return "link"
            case .milestone: return "flag.checkered"
            case .concern: return "exclamationmark.triangle.fill"
            case .investigation: return "doc.text.magnifyingglass"
            }
        }
    }

    init(
        id: UUID = UUID(),
        kind: Kind,
        headline: String,
        detail: String,
        domain: String,
        evidence: String = "",
        confidence: Double = 0.6,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastReinforcedAt: Date = Date(),
        reinforceCount: Int = 1,
        isPinned: Bool = false,
        isMuted: Bool = false,
        expiresAt: Date? = nil,
        contradictedBy: [UUID] = [],
        sourceTag: String = ""
    ) {
        self.id = id
        self.kind = kind
        self.headline = headline
        self.detail = detail
        self.domain = domain
        self.evidence = evidence
        self.confidence = confidence
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastReinforcedAt = lastReinforcedAt
        self.reinforceCount = reinforceCount
        self.isPinned = isPinned
        self.isMuted = isMuted
        self.expiresAt = expiresAt
        self.contradictedBy = contradictedBy
        self.sourceTag = sourceTag
    }

    nonisolated enum CodingKeys: String, CodingKey {
        case id, kind, headline, detail, domain, evidence, confidence
        case createdAt, updatedAt, lastReinforcedAt, reinforceCount
        case isPinned, isMuted, expiresAt, contradictedBy, sourceTag
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.kind = try c.decode(Kind.self, forKey: .kind)
        self.headline = try c.decode(String.self, forKey: .headline)
        self.detail = try c.decode(String.self, forKey: .detail)
        self.domain = try c.decode(String.self, forKey: .domain)
        self.evidence = try c.decodeIfPresent(String.self, forKey: .evidence) ?? ""
        self.confidence = try c.decodeIfPresent(Double.self, forKey: .confidence) ?? 0.6
        self.createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        self.lastReinforcedAt = try c.decodeIfPresent(Date.self, forKey: .lastReinforcedAt) ?? Date()
        self.reinforceCount = try c.decodeIfPresent(Int.self, forKey: .reinforceCount) ?? 1
        self.isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        self.isMuted = try c.decodeIfPresent(Bool.self, forKey: .isMuted) ?? false
        self.expiresAt = try c.decodeIfPresent(Date.self, forKey: .expiresAt)
        self.contradictedBy = try c.decodeIfPresent([UUID].self, forKey: .contradictedBy) ?? []
        self.sourceTag = try c.decodeIfPresent(String.self, forKey: .sourceTag) ?? ""
    }
}
