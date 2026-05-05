import SwiftUI

nonisolated enum StatReactionEmoji: String, CaseIterable, Identifiable, Sendable, Codable {
    case fire = "🔥"
    case clap = "👏"
    case muscle = "💪"
    case hundred = "💯"
    case party = "🎉"

    var id: String { rawValue }
}

nonisolated struct StatReaction: Identifiable, Sendable, Codable, Hashable {
    let id: UUID
    let friendId: String
    let target: String
    let emoji: StatReactionEmoji
    let timestamp: Date

    init(id: UUID = UUID(), friendId: String, target: String, emoji: StatReactionEmoji, timestamp: Date = Date()) {
        self.id = id
        self.friendId = friendId
        self.target = target
        self.emoji = emoji
        self.timestamp = timestamp
    }
}

nonisolated enum NudgeKind: String, CaseIterable, Identifiable, Sendable, Codable {
    case streak
    case water
    case legDay
    case gym
    case cardio
    case sleep
    case check

    var id: String { rawValue }

    var title: String {
        switch self {
        case .streak: return "Don't break the streak"
        case .water: return "Water check"
        case .legDay: return "Leg day?"
        case .gym: return "Hit the gym"
        case .cardio: return "Cardio time"
        case .sleep: return "Get some rest"
        case .check: return "Just checking in"
        }
    }

    var body: String {
        switch self {
        case .streak: return "Get back on your streak — you've got this."
        case .water: return "Hydrate up. Where you at on water today?"
        case .legDay: return "Leg day? Don't skip it."
        case .gym: return "Let's get a workout in today."
        case .cardio: return "Time for some cardio — I'll go if you go."
        case .sleep: return "Prioritize sleep tonight — recovery matters."
        case .check: return "How's training going?"
        }
    }

    var icon: String {
        switch self {
        case .streak: return "flame.fill"
        case .water: return "drop.fill"
        case .legDay: return "figure.strengthtraining.traditional"
        case .gym: return "dumbbell.fill"
        case .cardio: return "figure.run"
        case .sleep: return "moon.fill"
        case .check: return "hand.wave.fill"
        }
    }

    var color: Color {
        switch self {
        case .streak: return PepTheme.amber
        case .water: return PepTheme.blue
        case .legDay: return PepTheme.violet
        case .gym: return PepTheme.violet
        case .cardio: return PepTheme.teal
        case .sleep: return .indigo
        case .check: return PepTheme.textSecondary
        }
    }
}

nonisolated struct SentNudge: Sendable, Codable, Hashable {
    let friendId: String
    let kind: NudgeKind
    let timestamp: Date
}

nonisolated struct MilestoneReceipt: Sendable, Codable, Hashable {
    let milestoneId: String
    var seenByIds: Set<String>
    var lastSeenAt: Date
}

nonisolated struct FriendPresence: Sendable, Codable, Hashable {
    let friendId: String
    let activity: String
    let startedAt: Date

    var isActive: Bool {
        Date().timeIntervalSince(startedAt) < 4 * 3600
    }
}
