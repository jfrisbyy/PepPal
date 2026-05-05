import SwiftUI

@Observable
final class LocalModerationStore {
    static let shared = LocalModerationStore()

    private let mutedUsersKey = "moderation.mutedUserIds"
    private let mutedTagsKey = "moderation.mutedTags"
    private let keywordsKey = "moderation.keywordFilters"
    private let reportedPostsKey = "moderation.reportedPostIds"
    private let reportedCommentsKey = "moderation.reportedCommentIds"
    private let reportedMessagesKey = "moderation.reportedMessageIds"
    private let followedTagsKey = "moderation.followedTags"

    private(set) var mutedUserIds: Set<String> = []
    private(set) var mutedTags: Set<String> = []
    private(set) var keywordFilters: [String] = []
    private(set) var reportedPostIds: Set<String> = []
    private(set) var reportedCommentIds: Set<String> = []
    private(set) var reportedMessageIds: Set<String> = []
    private(set) var followedTags: Set<String> = []

    private init() {
        let d = UserDefaults.standard
        mutedUserIds = Set((d.array(forKey: mutedUsersKey) as? [String]) ?? [])
        mutedTags = Set((d.array(forKey: mutedTagsKey) as? [String]) ?? [])
        keywordFilters = (d.array(forKey: keywordsKey) as? [String]) ?? []
        reportedPostIds = Set((d.array(forKey: reportedPostsKey) as? [String]) ?? [])
        reportedCommentIds = Set((d.array(forKey: reportedCommentsKey) as? [String]) ?? [])
        reportedMessageIds = Set((d.array(forKey: reportedMessagesKey) as? [String]) ?? [])
        followedTags = Set((d.array(forKey: followedTagsKey) as? [String]) ?? [])
    }

    // MARK: - Mute users

    func muteUser(_ userId: String) {
        let id = userId.lowercased()
        mutedUserIds.insert(id)
        persist(Array(mutedUserIds), key: mutedUsersKey)
    }

    func unmuteUser(_ userId: String) {
        mutedUserIds.remove(userId.lowercased())
        persist(Array(mutedUserIds), key: mutedUsersKey)
    }

    func isUserMuted(_ userId: String) -> Bool {
        mutedUserIds.contains(userId.lowercased())
    }

    // MARK: - Mute tags

    func muteTag(_ tag: String) {
        let t = normalizeTag(tag)
        guard !t.isEmpty else { return }
        mutedTags.insert(t)
        persist(Array(mutedTags), key: mutedTagsKey)
    }

    func unmuteTag(_ tag: String) {
        mutedTags.remove(normalizeTag(tag))
        persist(Array(mutedTags), key: mutedTagsKey)
    }

    func isTagMuted(_ tag: String) -> Bool {
        mutedTags.contains(normalizeTag(tag))
    }

    // MARK: - Follow tags

    func followTag(_ tag: String) {
        let t = normalizeTag(tag)
        guard !t.isEmpty else { return }
        followedTags.insert(t)
        persist(Array(followedTags), key: followedTagsKey)
    }

    func unfollowTag(_ tag: String) {
        followedTags.remove(normalizeTag(tag))
        persist(Array(followedTags), key: followedTagsKey)
    }

    func isTagFollowed(_ tag: String) -> Bool {
        followedTags.contains(normalizeTag(tag))
    }

    // MARK: - Keyword filters

    func addKeyword(_ keyword: String) {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !keywordFilters.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
        keywordFilters.append(trimmed)
        UserDefaults.standard.set(keywordFilters, forKey: keywordsKey)
    }

    func removeKeyword(_ keyword: String) {
        keywordFilters.removeAll { $0.caseInsensitiveCompare(keyword) == .orderedSame }
        UserDefaults.standard.set(keywordFilters, forKey: keywordsKey)
    }

    func matchedKeyword(in text: String) -> String? {
        guard !keywordFilters.isEmpty, !text.isEmpty else { return nil }
        for kw in keywordFilters where !kw.isEmpty {
            if text.localizedCaseInsensitiveContains(kw) { return kw }
        }
        return nil
    }

    // MARK: - Reports (local hide)

    func markPostReported(_ postId: String) {
        reportedPostIds.insert(postId.lowercased())
        persist(Array(reportedPostIds), key: reportedPostsKey)
    }

    func markCommentReported(_ commentId: String) {
        reportedCommentIds.insert(commentId.lowercased())
        persist(Array(reportedCommentIds), key: reportedCommentsKey)
    }

    func markMessageReported(_ messageId: String) {
        reportedMessageIds.insert(messageId.lowercased())
        persist(Array(reportedMessageIds), key: reportedMessagesKey)
    }

    func isPostReported(_ postId: String) -> Bool {
        reportedPostIds.contains(postId.lowercased())
    }

    // MARK: - Combined filter

    /// Returns true if the post should be completely hidden (reported).
    func isPostHidden(postId: String, userId: String, tags: [String]) -> Bool {
        if isPostReported(postId) { return true }
        if isUserMuted(userId) { return true }
        if tags.contains(where: { isTagMuted($0) }) { return true }
        return false
    }

    // MARK: - Helpers

    private func normalizeTag(_ tag: String) -> String {
        var t = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if t.hasPrefix("#") { t.removeFirst() }
        return t
    }

    private func persist(_ array: [String], key: String) {
        UserDefaults.standard.set(array, forKey: key)
    }
}
