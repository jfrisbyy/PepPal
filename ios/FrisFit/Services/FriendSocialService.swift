import SwiftUI

@MainActor
@Observable
final class FriendSocialService {
    static let shared = FriendSocialService()

    private let defaults = UserDefaults.standard
    private let reactionsKey = "friendSocial.reactions.v1"
    private let nudgesKey = "friendSocial.nudges.v1"
    private let receiptsKey = "friendSocial.receipts.v1"
    private let presenceKey = "friendSocial.presence.v1"

    private(set) var reactions: [StatReaction] = []
    private(set) var sentNudges: [SentNudge] = []
    private(set) var receipts: [String: MilestoneReceipt] = [:]
    private(set) var friendPresences: [String: FriendPresence] = [:]

    static let nudgeCooldown: TimeInterval = 6 * 3600

    private init() {
        load()
        seedMockPresenceIfNeeded()
    }

    // MARK: - Reactions

    func reactions(forTarget target: String, friendId: String) -> [StatReaction] {
        reactions.filter { $0.target == target && $0.friendId == friendId }
    }

    func addReaction(friendId: String, target: String, emoji: StatReactionEmoji) {
        let reaction = StatReaction(friendId: friendId, target: target, emoji: emoji)
        reactions.append(reaction)
        persistReactions()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        // Deliver to recipient via backend
        Task {
            await FriendsBackendService.shared.sendReaction(
                receiverId: friendId,
                target: target,
                emoji: emoji
            )
        }
    }

    // MARK: - Nudges

    func canSendNudge(to friendId: String) -> Bool {
        lastNudge(to: friendId).map { Date().timeIntervalSince($0.timestamp) > Self.nudgeCooldown } ?? true
    }

    func lastNudge(to friendId: String) -> SentNudge? {
        sentNudges
            .filter { $0.friendId == friendId }
            .max(by: { $0.timestamp < $1.timestamp })
    }

    func sendNudge(to friendId: String, kind: NudgeKind) -> Bool {
        guard canSendNudge(to: friendId) else { return false }
        sentNudges.append(SentNudge(friendId: friendId, kind: kind, timestamp: Date()))
        persistNudges()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        Task {
            do {
                try await FriendsBackendService.shared.sendNudge(receiverId: friendId, kind: kind)
            } catch {
                print("FriendSocial: nudge backend failed: \(error)")
            }
        }
        return true
    }

    func nudgeCooldownRemaining(for friendId: String) -> TimeInterval? {
        guard let last = lastNudge(to: friendId) else { return nil }
        let remaining = Self.nudgeCooldown - Date().timeIntervalSince(last.timestamp)
        return remaining > 0 ? remaining : nil
    }

    // MARK: - Milestone receipts

    func markSeen(milestoneId: String, friendId: String) {
        var receipt = receipts[milestoneId] ?? MilestoneReceipt(milestoneId: milestoneId, seenByIds: [], lastSeenAt: Date())
        receipt.seenByIds.insert(friendId)
        receipt.lastSeenAt = Date()
        receipts[milestoneId] = receipt
        persistReceipts()
    }

    func receipt(for milestoneId: String) -> MilestoneReceipt? {
        receipts[milestoneId]
    }

    func simulateSeenCount(for milestoneId: String, seed: Int) -> Int {
        if let existing = receipts[milestoneId] { return existing.seenByIds.count }
        var hasher = Hasher()
        hasher.combine(milestoneId)
        hasher.combine(seed)
        let value = abs(hasher.finalize())
        return value % 6
    }

    // MARK: - Presence

    func presence(for friendId: String) -> FriendPresence? {
        guard let p = friendPresences[friendId], p.isActive else { return nil }
        return p
    }

    func setPresence(friendId: String, activity: String) {
        let p = FriendPresence(friendId: friendId, activity: activity, startedAt: Date())
        friendPresences[friendId] = p
        persistPresence()
    }

    func clearPresence(friendId: String) {
        friendPresences.removeValue(forKey: friendId)
        persistPresence()
    }

    func seedMockPresence(friendIds: [String]) {
        guard !friendIds.isEmpty else { return }
        let hasRealMock = friendPresences.values.contains(where: { friendIds.contains($0.friendId) && $0.isActive })
        if hasRealMock { return }

        let activities = ["Workout", "Running", "Cycling", "Lifting"]
        var hasher = Hasher()
        hasher.combine(friendIds.joined())
        hasher.combine(Int(Date().timeIntervalSince1970 / 600))
        let seed = abs(hasher.finalize())

        let pickCount = min(friendIds.count, max(1, seed % 2 + 1))
        let shuffled = friendIds.sorted().enumerated().map { ($0.offset, $0.element) }
        let picked = shuffled.prefix(pickCount)
        for (offset, id) in picked {
            let activity = activities[(seed + offset) % activities.count]
            let startedAt = Date().addingTimeInterval(-Double((seed + offset * 13) % 1800))
            friendPresences[id] = FriendPresence(friendId: id, activity: activity, startedAt: startedAt)
        }
        persistPresence()
    }

    private func seedMockPresenceIfNeeded() {
        friendPresences = friendPresences.filter { $0.value.isActive }
    }

    // MARK: - Persistence

    private func load() {
        if let data = defaults.data(forKey: reactionsKey),
           let decoded = try? JSONDecoder().decode([StatReaction].self, from: data) {
            reactions = decoded
        }
        if let data = defaults.data(forKey: nudgesKey),
           let decoded = try? JSONDecoder().decode([SentNudge].self, from: data) {
            sentNudges = decoded
        }
        if let data = defaults.data(forKey: receiptsKey),
           let decoded = try? JSONDecoder().decode([String: MilestoneReceipt].self, from: data) {
            receipts = decoded
        }
        if let data = defaults.data(forKey: presenceKey),
           let decoded = try? JSONDecoder().decode([String: FriendPresence].self, from: data) {
            friendPresences = decoded.filter { $0.value.isActive }
        }
    }

    private func persistReactions() {
        if let data = try? JSONEncoder().encode(reactions) {
            defaults.set(data, forKey: reactionsKey)
        }
    }

    private func persistNudges() {
        if let data = try? JSONEncoder().encode(sentNudges) {
            defaults.set(data, forKey: nudgesKey)
        }
    }

    private func persistReceipts() {
        if let data = try? JSONEncoder().encode(receipts) {
            defaults.set(data, forKey: receiptsKey)
        }
    }

    private func persistPresence() {
        if let data = try? JSONEncoder().encode(friendPresences) {
            defaults.set(data, forKey: presenceKey)
        }
    }
}
