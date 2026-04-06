import SwiftUI

nonisolated struct DirectMessage: Identifiable, Sendable {
    let id: UUID
    let senderID: UUID
    let text: String
    let timestamp: Date
    var isRead: Bool
    let supabaseId: String?

    init(id: UUID = UUID(), senderID: UUID, text: String, timestamp: Date = Date(), isRead: Bool = false, supabaseId: String? = nil) {
        self.id = id
        self.senderID = senderID
        self.text = text
        self.timestamp = timestamp
        self.isRead = isRead
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
