import SwiftUI

nonisolated struct SocialUser: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let username: String
    let avatarInitial: String
    let avatarColor: Color
    let activeProgramName: String?
    let streak: Int
    let totalFP: Int

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
    let fpEarned: Int
    let exercisesCompleted: Int
    var highFiveCount: Int
    var isHighFived: Bool
    var comments: [PostComment]
}

nonisolated struct PostComment: Identifiable, Sendable {
    let id: UUID
    let user: SocialUser
    let text: String
    let timestamp: Date
}

nonisolated enum LeaderboardPeriod: String, CaseIterable, Sendable {
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case allTime = "All Time"
}

nonisolated struct LeaderboardEntry: Identifiable, Sendable {
    let id: UUID
    let user: SocialUser
    let fp: Int
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
