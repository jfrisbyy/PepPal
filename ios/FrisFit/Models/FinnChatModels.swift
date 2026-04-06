import Foundation

nonisolated enum PepMessageRole: Sendable {
    case pep
    case user
}

nonisolated struct PepMessage: Identifiable, Sendable {
    let id: UUID
    let role: PepMessageRole
    let content: String
    let timestamp: Date
    let exerciseNames: [String]

    init(id: UUID = UUID(), role: PepMessageRole, content: String, timestamp: Date = Date(), exerciseNames: [String] = []) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.exerciseNames = exerciseNames
    }
}

typealias FinnMessageRole = PepMessageRole
typealias FinnMessage = PepMessage
