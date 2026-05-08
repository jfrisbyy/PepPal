import SwiftUI

/// Single shared messaging brain for the whole app.
///
/// Every screen that touches DMs (inbox, chat, profile chat shortcut, friend
/// dashboard) reads from and writes to this exact instance. There are no
/// per-view copies, no `@State` wrapping, and no local snapshots — that's the
/// only way the same conversation stays in sync across places.
@MainActor
@Observable
final class MessagesViewModel {
    static let shared = MessagesViewModel()

    // MARK: - Public observable state

    var conversations: [Conversation] = []
    var searchQuery: String = ""
    var searchResults: [SocialUser] = []
    var isSearching: Bool = false
    var isLoading: Bool = false
    var error: String?
    var typingUserIds: Set<String> = []
    var blockedUserIds: Set<String> = []
    var uploadingAttachment: Bool = false

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

    // MARK: - Private state

    private let messagingService = MessagingService.shared
    private var realtimeSubscribedId: String?
    private var typingResetTasks: [String: Task<Void, Never>] = [:]
    /// In-flight "create supabase conversation row" tasks, keyed by local UUID.
    /// `sendMessage` awaits on this so a fresh thread doesn't drop the first
    /// message while the row is being created server-side.
    private var pendingConversationResolution: [UUID: Task<String?, Never>] = [:]

    init() {
        Task {
            await loadBlocks()
            await loadConversations()
        }
    }

    // MARK: - Bootstrap

    func loadBlocks() async {
        guard let userId = try? AuthService.shared.currentUserId() else { return }
        if let ids = try? await ModerationService.shared.blockedUserIds(blockerId: userId) {
            blockedUserIds = Set(ids.map { $0.lowercased() })
        }
    }

    func conversation(for id: UUID) -> Conversation? {
        conversations.first { $0.id == id }
    }

    // MARK: - Helpers

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
            supabaseId: msg.id,
            status: .sent
        )
    }

    private func mergeServerMessage(_ dm: DirectMessage, into convoIdx: Int) {
        // De-dupe by supabase id first.
        if let sid = dm.supabaseId,
           let existing = conversations[convoIdx].messages.firstIndex(where: { $0.supabaseId == sid }) {
            conversations[convoIdx].messages[existing] = dm
            return
        }
        // De-dupe by local UUID (covers optimistic insert that already promoted).
        if let existing = conversations[convoIdx].messages.firstIndex(where: { $0.id == dm.id }) {
            conversations[convoIdx].messages[existing] = dm
            return
        }
        conversations[convoIdx].messages.append(dm)
        conversations[convoIdx].messages.sort { $0.timestamp < $1.timestamp }
    }

    // MARK: - Realtime

    func subscribeRealtime(conversationID: UUID) async {
        var supabaseIdOpt = conversation(for: conversationID)?.supabaseConversationId
        if supabaseIdOpt == nil, let pending = pendingConversationResolution[conversationID] {
            supabaseIdOpt = await pending.value
        }
        guard let supabaseId = supabaseIdOpt else { return }
        if realtimeSubscribedId == supabaseId { return }
        realtimeSubscribedId = supabaseId
        let myId = try? AuthService.shared.currentUserId()
        await RealtimeMessagingService.shared.subscribe(
            conversationId: supabaseId,
            userId: myId,
            onMessage: { [weak self] msg in
                guard let self else { return }
                guard let idx = self.conversations.firstIndex(where: { $0.id == conversationID }) else { return }
                if self.blockedUserIds.contains(msg.sender_id.lowercased()) { return }
                let dm = self.makeDM(from: msg)
                self.mergeServerMessage(dm, into: idx)
                self.typingUserIds.remove(dm.senderID.uuidString.lowercased())
                print("DM_REALTIME: insert id=\(dm.supabaseId ?? "?") convo=\(conversationID) total=\(self.conversations[idx].messages.count)")
            },
            onUpdate: { [weak self] msg in
                guard let self else { return }
                guard let idx = self.conversations.firstIndex(where: { $0.id == conversationID }) else { return }
                guard let mid = msg.id else { return }
                if let mIdx = self.conversations[idx].messages.firstIndex(where: { $0.supabaseId == mid }) {
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

    func unsubscribeRealtime() async {
        realtimeSubscribedId = nil
        await RealtimeMessagingService.shared.unsubscribe()
    }

    func sendTypingSignal() { RealtimeMessagingService.shared.notifyTyping() }
    func stopTypingSignal() { RealtimeMessagingService.shared.stopTyping() }

    func isParticipantTyping(in conversationID: UUID) -> Bool {
        guard let conv = conversation(for: conversationID) else { return false }
        return typingUserIds.contains(conv.participant.id.uuidString.lowercased())
    }

    // MARK: - Load conversations

    func loadConversations() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let userId = try AuthService.shared.currentUserId()
            let results = try await messagingService.fetchConversations(userId: userId)

            // Preserve any locally-created threads so we don't wipe them when a
            // server response arrives mid-flight.
            let existing = conversations
            var loaded: [Conversation] = []

            for result in results {
                let participant = messagingService.socialUserFromAuthor(result.participant)
                var lastMessages: [DirectMessage] = []
                if let msg = result.lastMessage { lastMessages.append(makeDM(from: msg)) }

                if let prior = existing.first(where: { $0.participant.id == participant.id }) {
                    var merged = prior
                    merged.supabaseConversationId = result.conversation.id
                    merged.unreadCount = result.unreadCount
                    if let serverLast = lastMessages.last,
                       !merged.messages.contains(where: { $0.supabaseId == serverLast.supabaseId }) {
                        merged.messages.append(serverLast)
                        merged.messages.sort { $0.timestamp < $1.timestamp }
                    }
                    loaded.append(merged)
                } else {
                    loaded.append(Conversation(
                        id: UUID(uuidString: result.conversation.id) ?? UUID(),
                        participant: participant,
                        messages: lastMessages,
                        unreadCount: result.unreadCount,
                        supabaseConversationId: result.conversation.id
                    ))
                }
            }

            // Carry over local-only threads not yet known to the server.
            let loadedParticipantIds = Set(loaded.map { $0.participant.id })
            for prior in existing where !loadedParticipantIds.contains(prior.participant.id) {
                loaded.append(prior)
            }

            conversations = loaded
        } catch {
            self.error = error.localizedDescription
        }
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
                    supabaseId: msg.id,
                    status: .sent
                )
            }
            guard let freshIdx = conversations.firstIndex(where: { $0.id == conversationID }) else { return }

            // Merge: keep any in-flight (sending/failed) optimistic messages
            // so the user never sees their own bubble vanish during a refetch.
            let serverIds = Set(mapped.compactMap { $0.supabaseId })
            let existing = conversations[freshIdx].messages
            let pending = existing.filter { msg in
                guard let sid = msg.supabaseId else { return msg.status != .sent }
                return !serverIds.contains(sid)
            }

            // If the server returned nothing but we already have local content,
            // assume a transient RLS/cache miss and keep what we have.
            if mapped.isEmpty && !existing.isEmpty { return }

            let combined = (mapped + pending).sorted { $0.timestamp < $1.timestamp }
            conversations[freshIdx].messages = combined
            print("DM_LOAD: convo=\(conversationID) server=\(mapped.count) pending=\(pending.count) total=\(combined.count)")
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Search

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

    // MARK: - Send

    /// Public send entry point. Always non-throwing — failure surfaces as a
    /// `.failed` bubble that the user can tap to retry.
    func sendMessage(to conversationID: UUID, text: String, attachments: [DirectMessageAttachment] = []) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            print("DM_SEND: ABORT — convo \(conversationID) not in list")
            return
        }

        let myUserId = (try? AuthService.shared.currentUserId()) ?? ""
        let optimistic = DirectMessage(
            id: UUID(),
            senderID: UUID(uuidString: myUserId) ?? UUID(),
            text: text,
            timestamp: Date(),
            isRead: false,
            readAt: nil,
            attachments: attachments,
            supabaseId: nil,
            status: .sending
        )
        conversations[index].messages.append(optimistic)
        print("DM_SEND: optimistic id=\(optimistic.id) convo=\(conversationID) total=\(conversations[index].messages.count)")

        Task { await deliver(messageID: optimistic.id, in: conversationID) }
    }

    /// Retry a failed send.
    func retrySend(messageID: UUID, in conversationID: UUID) {
        guard let cIdx = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        guard let mIdx = conversations[cIdx].messages.firstIndex(where: { $0.id == messageID }) else { return }
        conversations[cIdx].messages[mIdx].status = .sending
        Task { await deliver(messageID: messageID, in: conversationID) }
    }

    private func deliver(messageID: UUID, in conversationID: UUID) async {
        // Resolve the supabase conversation id, waiting for any pending creation.
        var supabaseConvId = conversation(for: conversationID)?.supabaseConversationId
        if supabaseConvId == nil, let pending = pendingConversationResolution[conversationID] {
            supabaseConvId = await pending.value
        }
        // If the previous resolution failed (or never existed), start a fresh
        // attempt now so a retry tap can actually recover instead of being
        // stuck on a stale nil.
        if supabaseConvId == nil, let participantId = conversation(for: conversationID)?.participant.id {
            let resolution = Task<String?, Never> { [weak self] in
                guard let self else { return nil }
                do {
                    let userId = try AuthService.shared.currentUserId()
                    let convId = try await self.messagingService.findOrCreateConversation(
                        userId: userId,
                        otherUserId: participantId.uuidString
                    )
                    if let idx = self.conversations.firstIndex(where: { $0.id == conversationID }) {
                        self.conversations[idx].supabaseConversationId = convId
                    }
                    self.pendingConversationResolution[conversationID] = nil
                    return convId
                } catch {
                    print("DM_SEND: convo resolve failed err=\(error.localizedDescription)")
                    self.error = error.localizedDescription
                    self.pendingConversationResolution[conversationID] = nil
                    return nil
                }
            }
            pendingConversationResolution[conversationID] = resolution
            supabaseConvId = await resolution.value
        }
        guard let supabaseConvId else {
            markStatus(messageID: messageID, in: conversationID, status: .failed)
            if self.error == nil {
                self.error = "Couldn't start conversation. Tap the message to retry."
            }
            return
        }

        guard let cIdx = conversations.firstIndex(where: { $0.id == conversationID }),
              let mIdx = conversations[cIdx].messages.firstIndex(where: { $0.id == messageID }) else { return }
        let outgoing = conversations[cIdx].messages[mIdx]

        do {
            let userId = try AuthService.shared.currentUserId()
            let sent = try await messagingService.sendMessage(
                conversationId: supabaseConvId,
                senderId: userId,
                text: outgoing.text,
                attachments: outgoing.attachments
            )

            guard let cIdx2 = conversations.firstIndex(where: { $0.id == conversationID }),
                  let mIdx2 = conversations[cIdx2].messages.firstIndex(where: { $0.id == messageID }) else { return }
            // Promote the optimistic bubble in place — don't replace the row,
            // just stamp the server fields onto it. That keeps the SwiftUI
            // identity stable so the view doesn't flicker.
            conversations[cIdx2].messages[mIdx2].supabaseId = sent.id
            conversations[cIdx2].messages[mIdx2].status = .sent
            print("DM_SEND: confirmed id=\(messageID) supabaseId=\(sent.id ?? "nil") total=\(conversations[cIdx2].messages.count)")

            // Make sure we're attached for incoming messages on this thread.
            await subscribeRealtime(conversationID: conversationID)
        } catch {
            print("DM_SEND: FAILED id=\(messageID) err=\(error.localizedDescription)")
            markStatus(messageID: messageID, in: conversationID, status: .failed)
            self.error = error.localizedDescription
        }
    }

    private func markStatus(messageID: UUID, in conversationID: UUID, status: MessageDeliveryStatus) {
        guard let cIdx = conversations.firstIndex(where: { $0.id == conversationID }),
              let mIdx = conversations[cIdx].messages.firstIndex(where: { $0.id == messageID }) else { return }
        conversations[cIdx].messages[mIdx].status = status
    }

    // MARK: - Attachments

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

    // MARK: - Read state

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
                // best-effort
            }
        }
    }

    // MARK: - Conversation lifecycle

    func startConversation(with user: SocialUser) -> UUID {
        if let existing = conversations.first(where: { $0.participant.id == user.id }) {
            let existingId = existing.id
            Task {
                await self.loadFullConversation(conversationID: existingId)
                await self.subscribeRealtime(conversationID: existingId)
            }
            return existingId
        }

        let localId = UUID()
        let conversation = Conversation(
            id: localId,
            participant: user,
            supabaseConversationId: nil
        )
        conversations.insert(conversation, at: 0)

        let resolution = Task<String?, Never> { [weak self] in
            guard let self else { return nil }
            do {
                let userId = try AuthService.shared.currentUserId()
                let convId = try await self.messagingService.findOrCreateConversation(
                    userId: userId,
                    otherUserId: user.id.uuidString
                )

                guard let idx = self.conversations.firstIndex(where: { $0.id == localId }) else { return convId }
                self.conversations[idx].supabaseConversationId = convId
                await self.loadFullConversation(conversationID: localId)
                await self.subscribeRealtime(conversationID: localId)
                self.pendingConversationResolution[localId] = nil
                return convId
            } catch {
                self.error = error.localizedDescription
                self.pendingConversationResolution[localId] = nil
                return nil
            }
        }
        pendingConversationResolution[localId] = resolution
        return localId
    }

    func refreshConversations() async {
        isLoading = false
        await loadConversations()
    }
}
