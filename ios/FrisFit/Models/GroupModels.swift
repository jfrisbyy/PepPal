import SwiftUI

nonisolated enum GroupPrivacy: String, CaseIterable, Sendable {
    case publicGroup = "Public"
    case privateGroup = "Private"

    var icon: String {
        switch self {
        case .publicGroup: return "globe"
        case .privateGroup: return "lock.fill"
        }
    }
}

nonisolated enum GroupMemberRole: String, Sendable {
    case owner = "Owner"
    case admin = "Admin"
    case member = "Member"

    var icon: String {
        switch self {
        case .owner: return "crown.fill"
        case .admin: return "shield.fill"
        case .member: return "person.fill"
        }
    }
}

struct FitGroup: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var description: String
    var privacy: GroupPrivacy
    var accentColor: Color
    var iconName: String
    var memberCount: Int
    var members: [GroupMember]
    var messages: [GroupMessage]
    let createdAt: Date
    let creatorID: UUID
    var statsConfig: GroupStatsConfig = GroupStatsConfig()

    var lastActivity: Date {
        messages.last?.timestamp ?? createdAt
    }

    var lastMessagePreview: String? {
        guard let msg = messages.last else { return nil }
        return "\(msg.sender.name.components(separatedBy: " ").first ?? ""): \(msg.text)"
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    nonisolated static func == (lhs: FitGroup, rhs: FitGroup) -> Bool {
        lhs.id == rhs.id
    }
}

struct GroupMember: Identifiable, Sendable {
    let id: UUID
    let user: SocialUser
    var role: GroupMemberRole
    let joinedAt: Date
    var stats: GroupMemberStats = GroupMemberStats()
    var isSharingStats: Bool = true
}

nonisolated enum GroupStatMetric: String, CaseIterable, Sendable, Identifiable, Hashable {
    case steps = "Steps"
    case workouts = "Workouts"
    case runMiles = "Run Distance"
    case activeMinutes = "Active Minutes"
    case calories = "Calories Burned"
    case streak = "Day Streak"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .steps: return "figure.walk"
        case .workouts: return "dumbbell.fill"
        case .runMiles: return "figure.run"
        case .activeMinutes: return "flame.fill"
        case .calories: return "bolt.fill"
        case .streak: return "flame"
        }
    }

    var unit: String {
        switch self {
        case .steps: return "steps"
        case .workouts: return "sessions"
        case .runMiles: return "mi"
        case .activeMinutes: return "min"
        case .calories: return "kcal"
        case .streak: return "days"
        }
    }

    var shortLabel: String {
        switch self {
        case .steps: return "Steps"
        case .workouts: return "Workouts"
        case .runMiles: return "Miles"
        case .activeMinutes: return "Active"
        case .calories: return "Calories"
        case .streak: return "Streak"
        }
    }

    func format(_ value: Double) -> String {
        switch self {
        case .steps, .calories:
            return value.formatted(.number.notation(.compactName))
        case .workouts, .activeMinutes, .streak:
            return Int(value).formatted()
        case .runMiles:
            return String(format: "%.1f", value)
        }
    }
}

nonisolated enum GroupStatsPeriod: String, CaseIterable, Sendable, Identifiable {
    case today = "Today"
    case week = "This Week"
    case month = "This Month"

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .today: return "Today"
        case .week: return "Week"
        case .month: return "Month"
        }
    }
}

struct GroupStatsConfig: Sendable, Hashable {
    var isEnabled: Bool
    var enabledMetrics: Set<GroupStatMetric>
    var period: GroupStatsPeriod

    init(
        isEnabled: Bool = false,
        enabledMetrics: Set<GroupStatMetric> = [],
        period: GroupStatsPeriod = .week
    ) {
        self.isEnabled = isEnabled
        self.enabledMetrics = enabledMetrics
        self.period = period
    }
}

struct GroupMemberStats: Sendable, Hashable {
    var values: [GroupStatMetric: Double]

    init(values: [GroupStatMetric: Double] = [:]) {
        self.values = values
    }

    func value(for metric: GroupStatMetric) -> Double {
        values[metric] ?? 0
    }
}

nonisolated struct CreateGroupJoinRequestNotification: Codable, Sendable {
    let user_id: String
    let type: String
    let title: String
    let body: String
}

struct GroupMessage: Identifiable, Sendable {
    let id: UUID
    let sender: SocialUser
    let text: String
    let timestamp: Date
    var likeCount: Int
    var isLiked: Bool
    var attachments: [DirectMessageAttachment]

    init(
        id: UUID = UUID(),
        sender: SocialUser,
        text: String,
        timestamp: Date = Date(),
        likeCount: Int = 0,
        isLiked: Bool = false,
        attachments: [DirectMessageAttachment] = []
    ) {
        self.id = id
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
        self.likeCount = likeCount
        self.isLiked = isLiked
        self.attachments = attachments
    }
}
