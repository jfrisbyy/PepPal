import SwiftUI

nonisolated struct DirectMessage: Identifiable, Sendable {
    let id: UUID
    let senderID: UUID
    let text: String
    let timestamp: Date
    var isRead: Bool

    init(id: UUID = UUID(), senderID: UUID, text: String, timestamp: Date = Date(), isRead: Bool = false) {
        self.id = id
        self.senderID = senderID
        self.text = text
        self.timestamp = timestamp
        self.isRead = isRead
    }
}

nonisolated struct Conversation: Identifiable, Sendable {
    let id: UUID
    let participant: SocialUser
    var messages: [DirectMessage]
    var lastMessage: DirectMessage? { messages.last }
    var unreadCount: Int { messages.filter { !$0.isRead && $0.senderID == participant.id }.count }

    init(id: UUID = UUID(), participant: SocialUser, messages: [DirectMessage] = []) {
        self.id = id
        self.participant = participant
        self.messages = messages
    }
}
