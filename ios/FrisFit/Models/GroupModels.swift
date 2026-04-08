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

    init(
        id: UUID = UUID(),
        sender: SocialUser,
        text: String,
        timestamp: Date = Date(),
        likeCount: Int = 0,
        isLiked: Bool = false
    ) {
        self.id = id
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
        self.likeCount = likeCount
        self.isLiked = isLiked
    }
}
