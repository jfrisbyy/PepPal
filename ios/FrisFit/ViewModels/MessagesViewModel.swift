import SwiftUI

@Observable
final class MessagesViewModel {
    var conversations: [Conversation] = []
    var searchQuery: String = ""
    var searchResults: [SocialUser] = []
    var isSearching: Bool = false
    var isLoading: Bool = false
    var error: String?

    var totalUnread: Int {
        conversations.reduce(0) { $0 + $1.unreadCount }
    }

    var filteredConversations: [Conversation] {
        if searchQuery.isEmpty { return conversations }
        return conversations.filter {
            $0.participant.name.localizedStandardContains(searchQuery) ||
            $0.participant.username.localizedStandardContains(searchQuery)
        }
    }

    private let messagingService = MessagingService.shared

    init() {
        Task {
            await loadConversations()
        }
    }

    func loadConversations() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let userId = try AuthService.shared.currentUserId()
            let results = try await messagingService.fetchConversations(userId: userId)

            var loaded: [Conversation] = []
            for result in results {
                let participant = messagingService.socialUserFromAuthor(result.participant)

                var lastMessages: [DirectMessage] = []
                if let msg = result.lastMessage {
                    lastMessages.append(DirectMessage(
                        id: UUID(uuidString: msg.id ?? "") ?? UUID(),
                        senderID: UUID(uuidString: msg.sender_id) ?? UUID(),
                        text: msg.text_content ?? "",
                        timestamp: messagingService.parseDate(msg.created_at),
                        isRead: msg.is_read ?? false,
                        supabaseId: msg.id
                    ))
                }

                let conv = Conversation(
                    id: UUID(uuidString: result.conversation.id) ?? UUID(),
                    participant: participant,
                    messages: lastMessages,
                    unreadCount: result.unreadCount,
                    supabaseConversationId: result.conversation.id
                )
                loaded.append(conv)
            }

            conversations = loaded
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadFullConversation(conversationID: UUID) async {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }),
              let supabaseId = conversations[index].supabaseConversationId else { return }

        do {
            let messages = try await messagingService.fetchMessages(conversationId: supabaseId)
            let mapped = messages.map { msg in
                DirectMessage(
                    id: UUID(uuidString: msg.id) ?? UUID(),
                    senderID: UUID(uuidString: msg.sender_id) ?? UUID(),
                    text: msg.text_content ?? "",
                    timestamp: messagingService.parseDate(msg.created_at),
                    isRead: msg.is_read ?? false,
                    supabaseId: msg.id
                )
            }
            conversations[index].messages = mapped
        } catch {
            // Silently fail
        }
    }

    func searchUsers(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true

        Task {
            do {
                let userId = try AuthService.shared.currentUserId()
                let profiles = try await messagingService.searchUsers(query: query, excludeUserId: userId)
                let conversationUserIds = Set(conversations.compactMap { $0.participant.id.uuidString.lowercased() })

                searchResults = profiles
                    .filter { !conversationUserIds.contains($0.id.lowercased()) }
                    .map { messagingService.socialUserFromAuthor($0) }
            } catch {
                searchResults = []
            }
            isSearching = false
        }
    }

    func sendMessage(to conversationID: UUID, text: String) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }),
              let supabaseConvId = conversations[index].supabaseConversationId else { return }

        Task {
            do {
                let userId = try AuthService.shared.currentUserId()
                let sent = try await messagingService.sendMessage(
                    conversationId: supabaseConvId,
                    senderId: userId,
                    text: text
                )

                let dm = DirectMessage(
                    id: UUID(uuidString: sent.id ?? "") ?? UUID(),
                    senderID: UUID(uuidString: sent.sender_id) ?? UUID(),
                    text: sent.text_content ?? text,
                    timestamp: messagingService.parseDate(sent.created_at),
                    isRead: true,
                    supabaseId: sent.id
                )

                if let idx = conversations.firstIndex(where: { $0.id == conversationID }) {
                    conversations[idx].messages.append(dm)
                }
            } catch {
                // Silently fail
            }
        }
    }

    func startConversation(with user: SocialUser) -> UUID {
        if let existing = conversations.first(where: { $0.participant.id == user.id }) {
            return existing.id
        }

        let placeholderId = UUID()
        let conversation = Conversation(
            id: placeholderId,
            participant: user,
            supabaseConversationId: nil
        )
        conversations.insert(conversation, at: 0)

        Task {
            do {
                let userId = try AuthService.shared.currentUserId()
                let convId = try await messagingService.findOrCreateConversation(
                    userId: userId,
                    otherUserId: user.id.uuidString
                )

                if let idx = conversations.firstIndex(where: { $0.id == placeholderId }) {
                    let updated = Conversation(
                        id: UUID(uuidString: convId) ?? placeholderId,
                        participant: user,
                        messages: conversations[idx].messages,
                        supabaseConversationId: convId
                    )
                    conversations[idx] = updated
                }
            } catch {
                // Keep placeholder
            }
        }

        return placeholderId
    }

    func markAsRead(conversationID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }),
              let supabaseConvId = conversations[index].supabaseConversationId else { return }

        conversations[index].unreadCount = 0
        for i in conversations[index].messages.indices {
            conversations[index].messages[i].isRead = true
        }

        Task {
            do {
                let userId = try AuthService.shared.currentUserId()
                try await messagingService.markMessagesAsRead(conversationId: supabaseConvId, userId: userId)
            } catch {
                // Silently fail
            }
        }
    }

    func conversation(for id: UUID) -> Conversation? {
        conversations.first { $0.id == id }
    }

    func refreshConversations() async {
        isLoading = false
        await loadConversations()
    }
}
