import Foundation

nonisolated enum FinnMessageRole: Sendable {
    case finn
    case user
}

nonisolated struct FinnMessage: Identifiable, Sendable {
    let id: UUID
    let role: FinnMessageRole
    let content: String
    let timestamp: Date
    let exerciseNames: [String]

    init(id: UUID = UUID(), role: FinnMessageRole, content: String, timestamp: Date = Date(), exerciseNames: [String] = []) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.exerciseNames = exerciseNames
    }
}
