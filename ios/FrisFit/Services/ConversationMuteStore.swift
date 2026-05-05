import Foundation

@Observable
final class ConversationMuteStore {
    static let shared = ConversationMuteStore()

    private let key = "muted_conversations_v1"
    private(set) var mutedIds: Set<String> = []

    private init() {
        if let arr = UserDefaults.standard.array(forKey: key) as? [String] {
            mutedIds = Set(arr)
        }
    }

    func isMuted(conversationId: String) -> Bool {
        mutedIds.contains(conversationId)
    }

    func toggle(conversationId: String) {
        if mutedIds.contains(conversationId) {
            mutedIds.remove(conversationId)
        } else {
            mutedIds.insert(conversationId)
        }
        persist()
    }

    func setMuted(_ muted: Bool, conversationId: String) {
        if muted {
            mutedIds.insert(conversationId)
        } else {
            mutedIds.remove(conversationId)
        }
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(Array(mutedIds), forKey: key)
    }
}
