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
    private var realtimeSubscribedId: String?
    var typingUserIds: Set<String> = []
    private var typingResetTasks: [String: Task<Void, Never>] = [:]
    var blockedUserIds: Set<String> = []
    var uploadingAttachment: Bool = false

    init() {
        Task {
            await loadBlocks()
            await loadConversations()
        }
    }

    func loadBlocks() async {
        guard let userId = try? AuthService.shared.currentUserId() else { return }
        if let ids = try? await ModerationService.shared.blockedUserIds(blockerId: userId) {
            blockedUserIds = Set(ids.map { $0.lowercased() })
        }
    }

    private func messageDate(_ iso: String?) -> Date? {
        guard let iso else { return nil }
        return messagingService.parseDate(iso)
    }

    private func makeDM(from msg: SupabaseDirectMessage) -> DirectMessage {
        DirectMessage(
            id: UUID(uuidString: msg.id ?? "") ?? UUID(),
            senderID: UUID(uuidString: msg.sender_id) ?? UUID(),
            text: msg.text_content ?? "",
            timestamp: messagingService.parseDate(msg.created_at),
            isRead: msg.is_read ?? false,
            readAt: messageDate(msg.read_at),
            attachments: msg.attachments ?? [],
            supabaseId: msg.id
        )
    }

    func subscribeRealtime(conversationID: UUID) async {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }),
              let supabaseId = conversations[index].supabaseConversationId else { return }
        if realtimeSubscribedId == supabaseId { return }
        realtimeSubscribedId = supabaseId
        let myId = try? AuthService.shared.currentUserId()
        await RealtimeMessagingService.shared.subscribe(
            conversationId: supabaseId,
            userId: myId,
            onMessage: { [weak self] msg in
                guard let self else { return }
                guard let idx = self.conversations.firstIndex(where: { $0.id == conversationID }) else { return }
                let senderIdLower = msg.sender_id.lowercased()
                if self.blockedUserIds.contains(senderIdLower) { return }
                let dm = self.makeDM(from: msg)
                if let existing = self.conversations[idx].messages.firstIndex(where: { $0.id == dm.id }) {
                    self.conversations[idx].messages[existing] = dm
                    return
                }
                self.conversations[idx].messages.append(dm)
                self.typingUserIds.remove(dm.senderID.uuidString.lowercased())
            },
            onUpdate: { [weak self] msg in
                guard let self else { return }
                guard let idx = self.conversations.firstIndex(where: { $0.id == conversationID }) else { return }
                guard let mid = msg.id, let uuid = UUID(uuidString: mid) else { return }
                if let mIdx = self.conversations[idx].messages.firstIndex(where: { $0.id == uuid }) {
                    self.conversations[idx].messages[mIdx].isRead = msg.is_read ?? self.conversations[idx].messages[mIdx].isRead
                    if let ra = msg.read_at {
                        self.conversations[idx].messages[mIdx].readAt = self.messagingService.parseDate(ra)
                    }
                }
            },
            onTyping: { [weak self] userId, isTyping in
                guard let self else { return }
                let key = userId.lowercased()
                if isTyping {
                    self.typingUserIds.insert(key)
                    self.typingResetTasks[key]?.cancel()
                    self.typingResetTasks[key] = Task { @MainActor in
                        try? await Task.sleep(for: .seconds(5))
                        if !Task.isCancelled {
                            self.typingUserIds.remove(key)
                            self.typingResetTasks[key] = nil
                        }
                    }
                } else {
                    self.typingUserIds.remove(key)
                    self.typingResetTasks[key]?.cancel()
                    self.typingResetTasks[key] = nil
                }
            }
        )
    }

    func sendTypingSignal() {
        RealtimeMessagingService.shared.notifyTyping()
    }

    func stopTypingSignal() {
        RealtimeMessagingService.shared.stopTyping()
    }

    func isParticipantTyping(in conversationID: UUID) -> Bool {
        guard let conv = conversation(for: conversationID) else { return false }
        return typingUserIds.contains(conv.participant.id.uuidString.lowercased())
    }

    func unsubscribeRealtime() async {
        realtimeSubscribedId = nil
        await RealtimeMessagingService.shared.unsubscribe()
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
                    lastMessages.append(makeDM(from: msg))
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
            let mapped: [DirectMessage] = messages.map { msg in
                DirectMessage(
                    id: UUID(uuidString: msg.id) ?? UUID(),
                    senderID: UUID(uuidString: msg.sender_id) ?? UUID(),
                    text: msg.text_content ?? "",
                    timestamp: messagingService.parseDate(msg.created_at),
                    isRead: msg.is_read ?? false,
                    readAt: messageDate(msg.read_at),
                    attachments: msg.attachments ?? [],
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

    func sendMessage(to conversationID: UUID, text: String, attachments: [DirectMessageAttachment] = []) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }),
              let supabaseConvId = conversations[index].supabaseConversationId else { return }

        Task {
            do {
                let userId = try AuthService.shared.currentUserId()
                let sent = try await messagingService.sendMessage(
                    conversationId: supabaseConvId,
                    senderId: userId,
                    text: text,
                    attachments: attachments
                )

                let dm = makeDM(from: sent)

                if let idx = conversations.firstIndex(where: { $0.id == conversationID }) {
                    if !conversations[idx].messages.contains(where: { $0.id == dm.id }) {
                        conversations[idx].messages.append(dm)
                    }
                }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func uploadAndSendImage(to conversationID: UUID, data: Data, caption: String = "") async {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }),
              let supabaseConvId = conversations[index].supabaseConversationId else { return }
        uploadingAttachment = true
        defer { uploadingAttachment = false }
        do {
            let att = try await messagingService.uploadDMImage(data: data, conversationId: supabaseConvId)
            sendMessage(to: conversationID, text: caption, attachments: [att])
        } catch {
            self.error = error.localizedDescription
        }
    }

    func uploadAndSendVideo(to conversationID: UUID, data: Data, duration: Double?, caption: String = "") async {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }),
              let supabaseConvId = conversations[index].supabaseConversationId else { return }
        uploadingAttachment = true
        defer { uploadingAttachment = false }
        do {
            let att = try await messagingService.uploadDMVideo(data: data, conversationId: supabaseConvId, durationSeconds: duration)
            sendMessage(to: conversationID, text: caption, attachments: [att])
        } catch {
            self.error = error.localizedDescription
        }
    }

    func uploadAndSendVoice(to conversationID: UUID, data: Data, duration: Double?) async {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }),
              let supabaseConvId = conversations[index].supabaseConversationId else { return }
        uploadingAttachment = true
        defer { uploadingAttachment = false }
        do {
            let att = try await messagingService.uploadDMVoice(data: data, conversationId: supabaseConvId, durationSeconds: duration)
            sendMessage(to: conversationID, text: "", attachments: [att])
        } catch {
            self.error = error.localizedDescription
        }
    }

    func markMessageVisible(conversationID: UUID, messageID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        guard let mIdx = conversations[index].messages.firstIndex(where: { $0.id == messageID }) else { return }
        let msg = conversations[index].messages[mIdx]
        guard !msg.isRead, let supaId = msg.supabaseId else { return }
        conversations[index].messages[mIdx].isRead = true
        conversations[index].messages[mIdx].readAt = Date()
        Task {
            try? await messagingService.markSingleMessageRead(messageId: supaId)
        }
    }

    func startConversation(with user: SocialUser) -> UUID {
        if let existing = conversations.first(where: { $0.participant.id == user.id }) {
            // If we already know this conversation, make sure the supabase id is filled in
            // and proactively load full history so the chat screen has data to render.
            let existingId = existing.id
            Task { await self.loadFullConversation(conversationID: existingId) }
            return existingId
        }

        let localId = UUID()
        let conversation = Conversation(
            id: localId,
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

                guard let idx = conversations.firstIndex(where: { $0.id == localId }) else { return }
                // Keep the local UUID stable so any view holding `localId` keeps working.
                // Only attach the Supabase conversation id, then hydrate messages.
                conversations[idx].supabaseConversationId = convId
                await self.loadFullConversation(conversationID: localId)
                await self.subscribeRealtime(conversationID: localId)
            } catch {
                self.error = error.localizedDescription
            }
        }

        return localId
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
