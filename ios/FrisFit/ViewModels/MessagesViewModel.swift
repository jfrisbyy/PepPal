import SwiftUI

@Observable
final class MessagesViewModel {
    /// Single shared instance used everywhere in the app so the inbox,
    /// profile chat link, friend dashboard chat link, etc. all read and
    /// write to the SAME conversation list. Without this, each screen
    /// constructed its own brain and messages sent from one screen never
    /// surfaced anywhere else (the bug the user kept hitting).
    static let shared = MessagesViewModel()

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
    // Tracks in-flight conversation creation per local conversation UUID so
    // sendMessage can await the supabase id instead of silently dropping the
    // first message in a brand-new DM thread.
    private var pendingConversationResolution: [UUID: Task<String?, Never>] = [:]

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
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        // For brand-new DM threads the supabase conversation row is created
        // asynchronously inside `startConversation`. If the id isn't ready yet,
        // wait for that work instead of silently bailing — otherwise realtime
        // never attaches and incoming messages never surface in the UI.
        var supabaseIdOpt = conversations[index].supabaseConversationId
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

            // Snapshot any locally-created threads so we don't wipe them when
            // the server response arrives. A fresh DM thread (created via
            // `startConversation` while loadConversations was still in flight)
            // would otherwise vanish from `conversations`, which makes
            // `sendMessage` silently bail since it can't find the index — the
            // user taps send and no bubble ever appears.
            let existing = conversations

            var loaded: [Conversation] = []
            for result in results {
                let participant = messagingService.socialUserFromAuthor(result.participant)

                var lastMessages: [DirectMessage] = []
                if let msg = result.lastMessage {
                    lastMessages.append(makeDM(from: msg))
                }

                // Preserve the local UUID + any optimistic / loaded messages
                // for an existing thread with this participant so views
                // holding the localId keep rendering. Match by participant id
                // (server convo id may differ from our localId).
                if let prior = existing.first(where: { $0.participant.id == participant.id }) {
                    var merged = prior
                    merged.supabaseConversationId = result.conversation.id
                    merged.unreadCount = result.unreadCount
                    // Merge in the server's last message if we don't have it.
                    if let serverLast = lastMessages.last {
                        let hasIt = merged.messages.contains { msg in
                            if let sid = msg.supabaseId { return sid == serverLast.supabaseId }
                            return false
                        }
                        if !hasIt {
                            merged.messages.append(serverLast)
                            merged.messages.sort { $0.timestamp < $1.timestamp }
                        }
                    }
                    loaded.append(merged)
                } else {
                    let conv = Conversation(
                        id: UUID(uuidString: result.conversation.id) ?? UUID(),
                        participant: participant,
                        messages: lastMessages,
                        unreadCount: result.unreadCount,
                        supabaseConversationId: result.conversation.id
                    )
                    loaded.append(conv)
                }
            }

            // Carry over local-only threads (no supabase id yet, or whose
            // server row hasn't propagated to this fetch yet) so they don't
            // disappear from the UI.
            let loadedParticipantIds = Set(loaded.map { $0.participant.id })
            for prior in existing where !loadedParticipantIds.contains(prior.participant.id) {
                loaded.append(prior)
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
            // Re-locate index in case conversations changed during the await.
            guard let freshIdx = conversations.firstIndex(where: { $0.id == conversationID }) else { return }

            // MERGE rather than replace so optimistic / in-flight messages
            // (no supabaseId yet, or whose row hasn't propagated to PostgREST
            // yet) aren't wiped from the UI when the server returns a partial
            // or empty list. Without this, a single empty refetch right after
            // sending nukes the bubble the user just typed.
            let serverIds = Set(mapped.compactMap { $0.supabaseId })
            let existing = conversations[freshIdx].messages
            let pending = existing.filter { msg in
                guard let sid = msg.supabaseId else { return true } // optimistic
                return !serverIds.contains(sid)
            }
            // If the server returned nothing but we have local messages,
            // keep the local state — most likely a transient RLS / cache miss.
            if mapped.isEmpty && !existing.isEmpty { return }

            let combined = (mapped + pending).sorted { $0.timestamp < $1.timestamp }
            conversations[freshIdx].messages = combined
        } catch {
            self.error = error.localizedDescription
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
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }

        // Optimistic local insert so the bubble appears in the UI immediately —
        // even before the supabase conversation row is created (which can take
        // a beat for brand-new threads with seeded users).
        let optimisticId = UUID()
        let myUserId = (try? AuthService.shared.currentUserId()) ?? ""
        let optimistic = DirectMessage(
            id: optimisticId,
            senderID: UUID(uuidString: myUserId) ?? UUID(),
            text: text,
            timestamp: Date(),
            isRead: false,
            readAt: nil,
            attachments: attachments,
            supabaseId: nil
        )
        conversations[index].messages.append(optimistic)
        print("DM_SEND: optimistic bubble appended id=\(optimisticId) convo=\(conversationID) total=\(conversations[index].messages.count)")

        Task {
            // If the supabase conversation row hasn't been created yet (fresh
            // DM thread), wait for the in-flight creation task to finish.
            var supabaseConvId = conversations.first(where: { $0.id == conversationID })?.supabaseConversationId
            if supabaseConvId == nil, let pending = pendingConversationResolution[conversationID] {
                supabaseConvId = await pending.value
            }
            guard let supabaseConvId else {
                self.error = "Couldn't start conversation. Please try again."
                removeOptimistic(optimisticId, in: conversationID)
                return
            }

            do {
                let userId = try AuthService.shared.currentUserId()
                let sent = try await messagingService.sendMessage(
                    conversationId: supabaseConvId,
                    senderId: userId,
                    text: text,
                    attachments: attachments
                )

                let dm = makeDM(from: sent)
                print("DM_SEND: server confirmed id=\(dm.id) supabaseId=\(dm.supabaseId ?? "nil")")

                if let idx = conversations.firstIndex(where: { $0.id == conversationID }) {
                    if let optIdx = conversations[idx].messages.firstIndex(where: { $0.id == optimisticId }) {
                        conversations[idx].messages[optIdx] = dm
                    } else if !conversations[idx].messages.contains(where: { $0.id == dm.id }) {
                        conversations[idx].messages.append(dm)
                    }
                    print("DM_SEND: post-confirm message count=\(conversations[idx].messages.count)")
                }

                // Safety net: if realtime hasn't attached yet (fresh thread),
                // refetch so the new row is definitely visible. Also make sure
                // we are subscribed for any future incoming messages.
                await loadFullConversation(conversationID: conversationID)
                await subscribeRealtime(conversationID: conversationID)
            } catch {
                print("DM_SEND: ERROR \(error.localizedDescription)")
                self.error = error.localizedDescription
                removeOptimistic(optimisticId, in: conversationID)
            }
        }
    }

    private func removeOptimistic(_ id: UUID, in conversationID: UUID) {
        guard let idx = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        conversations[idx].messages.removeAll { $0.id == id }
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
                // Keep the local UUID stable so any view holding `localId` keeps working.
                // Only attach the Supabase conversation id, then hydrate messages.
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
