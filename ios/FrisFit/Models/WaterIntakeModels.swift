import Foundation

nonisolated struct WaterEntry: Identifiable, Codable, Sendable {
    let id: UUID
    let amountMl: Int
    let loggedAt: Date
    var supabaseId: String?

    init(id: UUID = UUID(), amountMl: Int, loggedAt: Date = Date(), supabaseId: String? = nil) {
        self.id = id
        self.amountMl = amountMl
        self.loggedAt = loggedAt
        self.supabaseId = supabaseId
    }
}

nonisolated enum WaterPreset: Int, CaseIterable, Sendable, Identifiable {
    case sip = 100
    case glass = 250
    case cup = 355
    case bottle = 500
    case large = 750

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .sip: return "Sip"
        case .glass: return "Glass"
        case .cup: return "Cup"
        case .bottle: return "Bottle"
        case .large: return "Large"
        }
    }

    var oz: Int {
        Int((Double(rawValue) / 29.5735).rounded())
    }

    var icon: String {
        switch self {
        case .sip: return "drop"
        case .glass: return "cup.and.saucer"
        case .cup: return "mug"
        case .bottle: return "waterbottle"
        case .large: return "waterbottle.fill"
        }
    }
}
