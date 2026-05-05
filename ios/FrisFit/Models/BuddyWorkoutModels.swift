import Foundation

nonisolated enum BuddySessionState: String, Sendable, Codable {
    case pending
    case active
    case finished
    case declined
}

nonisolated struct BuddyParticipant: Identifiable, Sendable, Codable, Hashable {
    let id: String
    let name: String
    let avatarInitial: String
    let avatarURL: String?
    var totalSetsTarget: Int
    var setsCompleted: Int
    var currentExerciseName: String?
    var lastSetAt: Date?
    var isFinished: Bool
}

nonisolated struct BuddySession: Identifiable, Sendable, Codable {
    let id: UUID
    let workoutName: String
    var state: BuddySessionState
    var startedAt: Date
    var me: BuddyParticipant
    var buddy: BuddyParticipant
    let buddyUserId: String
}

nonisolated struct BuddySetEvent: Identifiable, Sendable, Hashable {
    let id: UUID
    let participantId: String
    let exerciseName: String
    let timestamp: Date
}
