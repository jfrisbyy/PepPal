import Foundation

/// Per-account list of silenced direct-message threads. Mirrored to Supabase
/// (`conversation_mutes` table) so a mute follows the user to other devices
/// and survives sign-in / sign-out cycles. UserDefaults is kept only as a
/// short-term cache between launches.
@Observable
final class ConversationMuteStore {
    static let shared = ConversationMuteStore()

    private let cacheKey = "muted_conversations_v1"
    private(set) var mutedIds: Set<String> = []

    private var authObserver: NSObjectProtocol?

    private init() {
        if let arr = UserDefaults.standard.array(forKey: cacheKey) as? [String] {
            mutedIds = Set(arr)
        }
        authObserver = NotificationCenter.default.addObserver(
            forName: .authUserChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.mutedIds = []
            self.persistCache()
            Task { @MainActor in await self.hydrateFromSupabase() }
        }
        Task { @MainActor in await self.hydrateFromSupabase() }
    }

    deinit {
        if let authObserver { NotificationCenter.default.removeObserver(authObserver) }
    }

    func isMuted(conversationId: String) -> Bool {
        mutedIds.contains(conversationId)
    }

    func toggle(conversationId: String) {
        if mutedIds.contains(conversationId) {
            setMuted(false, conversationId: conversationId)
        } else {
            setMuted(true, conversationId: conversationId)
        }
    }

    func setMuted(_ muted: Bool, conversationId: String) {
        if muted {
            guard !mutedIds.contains(conversationId) else { return }
            mutedIds.insert(conversationId)
            persistCache()
            Task.detached { await PersistenceSyncService.shared.upsertConversationMute(conversationId: conversationId) }
        } else {
            guard mutedIds.contains(conversationId) else { return }
            mutedIds.remove(conversationId)
            persistCache()
            Task.detached { await PersistenceSyncService.shared.deleteConversationMute(conversationId: conversationId) }
        }
    }

    private func persistCache() {
        UserDefaults.standard.set(Array(mutedIds), forKey: cacheKey)
    }

    func hydrateFromSupabase() async {
        let remote = await PersistenceSyncService.shared.fetchConversationMutes()
        if remote.isEmpty {
            // First sync from a device with a local cache: push everything up
            // so the server takes over as the source of truth.
            for id in mutedIds {
                await PersistenceSyncService.shared.upsertConversationMute(conversationId: id)
            }
            return
        }
        let merged = mutedIds.union(remote)
        // Push any local-only ids that the server didn't have yet.
        let localOnly = mutedIds.subtracting(remote)
        for id in localOnly {
            await PersistenceSyncService.shared.upsertConversationMute(conversationId: id)
        }
        mutedIds = merged
        persistCache()
    }
}
