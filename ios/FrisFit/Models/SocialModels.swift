import SwiftUI

nonisolated struct SocialUser: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let username: String
    let avatarInitial: String
    let avatarColor: Color
    let avatarURL: String?
    let activeProgramName: String?
    let streak: Int

    init(
        id: UUID,
        name: String,
        username: String,
        avatarInitial: String,
        avatarColor: Color,
        avatarURL: String? = nil,
        activeProgramName: String?,
        streak: Int,
        totalFP: Int = 0
    ) {
        self.id = id
        self.name = name
        self.username = username
        self.avatarInitial = avatarInitial
        self.avatarColor = avatarColor
        self.avatarURL = avatarURL
        self.activeProgramName = activeProgramName
        self.streak = streak
        _ = totalFP
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    nonisolated static func == (lhs: SocialUser, rhs: SocialUser) -> Bool {
        lhs.id == rhs.id
    }
}

nonisolated struct WorkoutPost: Identifiable, Sendable {
    let id: UUID
    let user: SocialUser
    let timestamp: Date
    let workoutName: String
    let duration: Int
    let totalVolume: Int
    let exercisesCompleted: Int
    var likeCount: Int
    var isLiked: Bool
    var comments: [PostComment]
}

nonisolated struct PostComment: Identifiable, Sendable {
    let id: UUID
    let user: SocialUser
    let text: String
    let timestamp: Date
    let parentId: UUID?

    init(id: UUID, user: SocialUser, text: String, timestamp: Date, parentId: UUID? = nil) {
        self.id = id
        self.user = user
        self.text = text
        self.timestamp = timestamp
        self.parentId = parentId
    }
}

nonisolated enum LeaderboardPeriod: String, CaseIterable, Sendable {
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case allTime = "All Time"
}

nonisolated struct LeaderboardEntry: Identifiable, Sendable {
    let id: UUID
    let user: SocialUser
    let rank: Int
}

nonisolated enum FriendRequestStatus: Sendable {
    case none
    case pending
    case accepted
}

nonisolated struct FriendSearchResult: Identifiable, Sendable {
    let id: UUID
    let user: SocialUser
    var requestStatus: FriendRequestStatus
}
