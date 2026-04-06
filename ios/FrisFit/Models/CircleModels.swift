import SwiftUI

nonisolated enum CircleRole: String, Sendable, CaseIterable {
    case owner = "Owner"
    case admin = "Admin"
    case member = "Member"

    var color: Color {
        switch self {
        case .owner: return FrisTheme.amber
        case .admin: return FrisTheme.violet
        case .member: return FrisTheme.cyan
        }
    }

    var icon: String {
        switch self {
        case .owner: return "crown.fill"
        case .admin: return "shield.fill"
        case .member: return "person.fill"
        }
    }
}

nonisolated enum CircleTaskType: String, Sendable {
    case perPerson = "per_person"
    case circleTask = "circle_task"
}

nonisolated enum CompetitionType: String, CaseIterable, Sendable {
    case targetPoints = "Target Points"
    case timed = "Timed"
    case ongoing = "Ongoing"
}

nonisolated enum CompetitionStatus: String, Sendable {
    case pending = "Pending"
    case active = "Active"
    case completed = "Completed"
}

nonisolated enum AwardType: String, CaseIterable, Sendable {
    case firstTo = "First To"
    case mostInCategory = "Most in Category"
    case weeklyChampion = "Weekly Champion"
}

nonisolated enum RewardType: String, CaseIterable, Sendable {
    case points = "Points"
    case gift = "Gift"
    case both = "Both"
}

struct FitCircle: Identifiable, Sendable {
    let id: UUID
    var name: String
    var description: String
    var ownerId: UUID
    var isPrivate: Bool
    var dailyPointGoal: Int?
    var weeklyPointGoal: Int?
    var totalCirclePoints: Int
    var inviteCode: String
    var createdAt: Date
    var members: [CircleMember]
    var accentColor: Color

    var memberCount: Int { members.count }

    var ownerName: String {
        members.first(where: { $0.role == .owner })?.user.name ?? "Unknown"
    }
}

extension FitCircle: Hashable {
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    nonisolated static func == (lhs: FitCircle, rhs: FitCircle) -> Bool {
        lhs.id == rhs.id
    }
}

struct CircleMember: Identifiable, Sendable {
    let id: UUID
    let user: SocialUser
    var role: CircleRole
    let joinedAt: Date
    var totalPoints: Int
    var weeklyPoints: Int
    var goalStreak: Int
    var longestStreak: Int
}

struct CircleMessage: Identifiable, Sendable {
    let id: UUID
    let sender: SocialUser
    let content: String
    let imageUrl: String?
    let createdAt: Date
}

struct CirclePost: Identifiable, Sendable {
    let id: UUID
    let author: SocialUser
    let content: String
    let imageUrl: String?
    let createdAt: Date
    var likeCount: Int
    var isLiked: Bool
    var comments: [CirclePostComment]
}

struct CirclePostComment: Identifiable, Sendable {
    let id: UUID
    let author: SocialUser
    let content: String
    let createdAt: Date
    var likeCount: Int
    var isLiked: Bool
}

struct CircleTask: Identifiable, Sendable {
    let id: UUID
    let name: String
    let value: Int
    let category: String
    let taskType: CircleTaskType
    let createdBy: SocialUser
    let isPenalty: Bool
    var isCompletedToday: Bool
}

struct CircleBadge: Identifiable, Sendable {
    let id: UUID
    let name: String
    let description: String
    let icon: String
    let required: Int
    var progress: Int
    var earned: Bool
    let rewardType: RewardType
    let rewardPoints: Int?
    let rewardGift: String?
}

struct CircleAward: Identifiable, Sendable {
    let id: UUID
    let name: String
    let description: String
    let type: AwardType
    let target: Int?
    let category: String?
    let winnerId: UUID?
    let winnerName: String?
    let rewardType: RewardType
    let rewardPoints: Int?
    let rewardGift: String?
}

struct CircleCompetition: Identifiable, Sendable {
    let id: UUID
    let name: String
    let description: String
    let competitionType: CompetitionType
    let circleOne: CompetitionCircleInfo
    let circleTwo: CompetitionCircleInfo
    let startDate: Date
    let endDate: Date?
    let targetPoints: Int?
    var circleOnePoints: Int
    var circleTwoPoints: Int
    var winnerId: UUID?
    var status: CompetitionStatus
}

struct CompetitionCircleInfo: Sendable {
    let id: UUID
    let name: String
    let memberCount: Int
}

struct CircleInvite: Identifiable, Sendable {
    let id: UUID
    let circleId: UUID
    let circleName: String
    let inviter: SocialUser
    let status: String
    let createdAt: Date
}

struct Cheerline: Identifiable, Sendable {
    let id: UUID
    let sender: SocialUser
    let message: String
    let expiresAt: Date
    var read: Bool
    let createdAt: Date
}

struct CircleTaskRequest: Identifiable, Sendable {
    let id: UUID
    let requester: SocialUser
    let type: String
    let taskName: String
    let taskValue: Int
    let status: String
    let createdAt: Date
}

struct LeaderboardMember: Identifiable, Sendable {
    let id: UUID
    let user: SocialUser
    let rank: Int
    let totalPoints: Int
    let goalStreak: Int
    let longestStreak: Int
    let weeklyHistory: [Int]
    let topTasks: [TaskTotal]
}

nonisolated struct TaskTotal: Identifiable, Sendable {
    var id: String { taskName }
    let taskName: String
    let count: Int
}
