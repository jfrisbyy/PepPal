import SwiftUI

nonisolated enum DirectMessageAttachmentKind: String, Sendable, Codable {
    case image
    case video
    case voice
}

nonisolated struct DirectMessageAttachment: Identifiable, Sendable, Codable, Hashable {
    let id: String
    let kind: DirectMessageAttachmentKind
    let url: String
    let width: Int?
    let height: Int?
    let durationSeconds: Double?

    init(id: String = UUID().uuidString, kind: DirectMessageAttachmentKind, url: String, width: Int? = nil, height: Int? = nil, durationSeconds: Double? = nil) {
        self.id = id
        self.kind = kind
        self.url = url
        self.width = width
        self.height = height
        self.durationSeconds = durationSeconds
    }
}

nonisolated struct DirectMessage: Identifiable, Sendable {
    let id: UUID
    let senderID: UUID
    let text: String
    let timestamp: Date
    var isRead: Bool
    var readAt: Date?
    var attachments: [DirectMessageAttachment]
    let supabaseId: String?

    init(id: UUID = UUID(), senderID: UUID, text: String, timestamp: Date = Date(), isRead: Bool = false, readAt: Date? = nil, attachments: [DirectMessageAttachment] = [], supabaseId: String? = nil) {
        self.id = id
        self.senderID = senderID
        self.text = text
        self.timestamp = timestamp
        self.isRead = isRead
        self.readAt = readAt
        self.attachments = attachments
        self.supabaseId = supabaseId
    }
}

nonisolated struct Conversation: Identifiable, Sendable {
    let id: UUID
    let participant: SocialUser
    var messages: [DirectMessage]
    var lastMessage: DirectMessage? { messages.last }
    var unreadCount: Int
    let supabaseConversationId: String?

    init(id: UUID = UUID(), participant: SocialUser, messages: [DirectMessage] = [], unreadCount: Int? = nil, supabaseConversationId: String? = nil) {
        self.id = id
        self.participant = participant
        self.messages = messages
        self.supabaseConversationId = supabaseConversationId
        if let unreadCount {
            self.unreadCount = unreadCount
        } else {
            self.unreadCount = messages.filter { !$0.isRead && $0.senderID == participant.id }.count
        }
    }
}
