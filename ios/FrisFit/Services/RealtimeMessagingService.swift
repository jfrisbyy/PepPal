import Foundation
import Supabase
import Realtime

@MainActor
final class RealtimeMessagingService {
    static let shared = RealtimeMessagingService()
    private init() {}

    private var messageChannel: RealtimeChannelV2?
    private var activeConversationId: String?
    private var observationTokens: Set<RealtimeSubscription> = []
    private var typingTask: Task<Void, Never>?
    private var currentUserId: String?

    typealias MessageHandler = (SupabaseDirectMessage) -> Void
    typealias TypingHandler = (_ userId: String, _ isTyping: Bool) -> Void

    private var messageHandler: MessageHandler?
    private var updateHandler: MessageHandler?
    private var typingHandler: TypingHandler?

    func subscribe(
        conversationId: String,
        userId: String? = nil,
        onMessage: @escaping MessageHandler,
        onUpdate: MessageHandler? = nil,
        onTyping: TypingHandler? = nil
    ) async {
        await unsubscribe()
        activeConversationId = conversationId
        messageHandler = onMessage
        updateHandler = onUpdate
        typingHandler = onTyping
        currentUserId = userId

        let supabase = SupabaseService.shared.client
        let channel = supabase.realtimeV2.channel("dm-\(conversationId)")

        let token = channel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "direct_messages",
            filter: "conversation_id=eq.\(conversationId)"
        ) { [weak self] change in
            guard let self else { return }
            if let decoded = try? change.decodeRecord(as: SupabaseDirectMessage.self, decoder: JSONDecoder()) {
                Task { @MainActor in
                    self.messageHandler?(decoded)
                }
            }
        }
        observationTokens.insert(token)

        let updateToken = channel.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "direct_messages",
            filter: "conversation_id=eq.\(conversationId)"
        ) { [weak self] change in
            guard let self else { return }
            if let decoded = try? change.decodeRecord(as: SupabaseDirectMessage.self, decoder: JSONDecoder()) {
                Task { @MainActor in
                    self.updateHandler?(decoded)
                }
            }
        }
        observationTokens.insert(updateToken)

        let broadcastStream = channel.broadcastStream(event: "typing")
        Task { [weak self] in
            for await message in broadcastStream {
                guard let self else { return }
                await MainActor.run {
                    guard let payload = message["payload"]?.objectValue,
                          let uid = payload["userId"]?.stringValue,
                          let isTyping = payload["isTyping"]?.boolValue else { return }
                    if uid == self.currentUserId { return }
                    self.typingHandler?(uid, isTyping)
                }
            }
        }

        await channel.subscribe()
        self.messageChannel = channel
    }

    func sendTyping(isTyping: Bool) async {
        guard let channel = messageChannel, let uid = currentUserId else { return }
        try? await channel.broadcast(
            event: "typing",
            message: [
                "userId": .string(uid),
                "isTyping": .bool(isTyping)
            ]
        )
    }

    /// Debounced typing indicator — call on each keystroke. Auto-stops after 3s of inactivity.
    func notifyTyping() {
        typingTask?.cancel()
        Task { await sendTyping(isTyping: true) }
        typingTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled {
                await sendTyping(isTyping: false)
            }
        }
    }

    func stopTyping() {
        typingTask?.cancel()
        typingTask = nil
        Task { await sendTyping(isTyping: false) }
    }

    func unsubscribe() async {
        observationTokens.removeAll()
        typingTask?.cancel()
        typingTask = nil
        if let channel = messageChannel {
            await channel.unsubscribe()
        }
        messageChannel = nil
        activeConversationId = nil
        messageHandler = nil
        updateHandler = nil
        typingHandler = nil
        currentUserId = nil
    }
}
