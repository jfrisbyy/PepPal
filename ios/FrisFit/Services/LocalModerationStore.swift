import SwiftUI

/// Viewer-side moderation state (mute users / tags, follow tags, keyword
/// filters, "report → hide locally" lists).
///
/// Mirrored to Supabase so the same blocks/filters apply across every device
/// the user signs in on. UserDefaults is kept as a short-lived cache so the
/// UI doesn't have to wait on the network on cold launch; the server is the
/// source of truth and overwrites the cache on hydration.
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

    private var authObserver: NSObjectProtocol?

    private init() {
        let d = UserDefaults.standard
        mutedUserIds = Set((d.array(forKey: mutedUsersKey) as? [String]) ?? [])
        mutedTags = Set((d.array(forKey: mutedTagsKey) as? [String]) ?? [])
        keywordFilters = (d.array(forKey: keywordsKey) as? [String]) ?? []
        reportedPostIds = Set((d.array(forKey: reportedPostsKey) as? [String]) ?? [])
        reportedCommentIds = Set((d.array(forKey: reportedCommentsKey) as? [String]) ?? [])
        reportedMessageIds = Set((d.array(forKey: reportedMessagesKey) as? [String]) ?? [])
        followedTags = Set((d.array(forKey: followedTagsKey) as? [String]) ?? [])

        authObserver = NotificationCenter.default.addObserver(
            forName: .authUserChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.resetInMemory()
            Task { @MainActor in await self.hydrateFromSupabase() }
        }
        Task { @MainActor in await self.hydrateFromSupabase() }
    }

    deinit {
        if let authObserver { NotificationCenter.default.removeObserver(authObserver) }
    }

    private func resetInMemory() {
        mutedUserIds = []
        mutedTags = []
        keywordFilters = []
        reportedPostIds = []
        reportedCommentIds = []
        reportedMessageIds = []
        followedTags = []
        let d = UserDefaults.standard
        d.removeObject(forKey: mutedUsersKey)
        d.removeObject(forKey: mutedTagsKey)
        d.removeObject(forKey: keywordsKey)
        d.removeObject(forKey: reportedPostsKey)
        d.removeObject(forKey: reportedCommentsKey)
        d.removeObject(forKey: reportedMessagesKey)
        d.removeObject(forKey: followedTagsKey)
    }

    // MARK: - Mute users

    func muteUser(_ userId: String) {
        let id = userId.lowercased()
        guard !mutedUserIds.contains(id) else { return }
        mutedUserIds.insert(id)
        persist(Array(mutedUserIds), key: mutedUsersKey)
        Task.detached { await PersistenceSyncService.shared.upsertModerationMutedUser(id) }
    }

    func unmuteUser(_ userId: String) {
        let id = userId.lowercased()
        guard mutedUserIds.contains(id) else { return }
        mutedUserIds.remove(id)
        persist(Array(mutedUserIds), key: mutedUsersKey)
        Task.detached { await PersistenceSyncService.shared.deleteModerationMutedUser(id) }
    }

    func isUserMuted(_ userId: String) -> Bool {
        mutedUserIds.contains(userId.lowercased())
    }

    // MARK: - Mute tags

    func muteTag(_ tag: String) {
        let t = normalizeTag(tag)
        guard !t.isEmpty, !mutedTags.contains(t) else { return }
        mutedTags.insert(t)
        persist(Array(mutedTags), key: mutedTagsKey)
        Task.detached { await PersistenceSyncService.shared.upsertModerationMutedTag(t) }
    }

    func unmuteTag(_ tag: String) {
        let t = normalizeTag(tag)
        guard mutedTags.contains(t) else { return }
        mutedTags.remove(t)
        persist(Array(mutedTags), key: mutedTagsKey)
        Task.detached { await PersistenceSyncService.shared.deleteModerationMutedTag(t) }
    }

    func isTagMuted(_ tag: String) -> Bool {
        mutedTags.contains(normalizeTag(tag))
    }

    // MARK: - Follow tags

    func followTag(_ tag: String) {
        let t = normalizeTag(tag)
        guard !t.isEmpty, !followedTags.contains(t) else { return }
        followedTags.insert(t)
        persist(Array(followedTags), key: followedTagsKey)
        Task.detached { await PersistenceSyncService.shared.upsertModerationFollowedTag(t) }
    }

    func unfollowTag(_ tag: String) {
        let t = normalizeTag(tag)
        guard followedTags.contains(t) else { return }
        followedTags.remove(t)
        persist(Array(followedTags), key: followedTagsKey)
        Task.detached { await PersistenceSyncService.shared.deleteModerationFollowedTag(t) }
    }

    func isTagFollowed(_ tag: String) -> Bool {
        followedTags.contains(normalizeTag(tag))
    }

    // MARK: - Keyword filters

    func addKeyword(_ keyword: String) {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !keywordFilters.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
        keywordFilters.append(trimmed)
        UserDefaults.standard.set(keywordFilters, forKey: keywordsKey)
        Task.detached { await PersistenceSyncService.shared.upsertModerationKeyword(trimmed) }
    }

    func removeKeyword(_ keyword: String) {
        let removed = keywordFilters.filter { $0.caseInsensitiveCompare(keyword) == .orderedSame }
        guard !removed.isEmpty else { return }
        keywordFilters.removeAll { $0.caseInsensitiveCompare(keyword) == .orderedSame }
        UserDefaults.standard.set(keywordFilters, forKey: keywordsKey)
        for kw in removed {
            Task.detached { await PersistenceSyncService.shared.deleteModerationKeyword(kw) }
        }
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
        let id = postId.lowercased()
        guard !reportedPostIds.contains(id) else { return }
        reportedPostIds.insert(id)
        persist(Array(reportedPostIds), key: reportedPostsKey)
        Task.detached { await PersistenceSyncService.shared.upsertModerationReport(kind: "post", targetId: id) }
    }

    func markCommentReported(_ commentId: String) {
        let id = commentId.lowercased()
        guard !reportedCommentIds.contains(id) else { return }
        reportedCommentIds.insert(id)
        persist(Array(reportedCommentIds), key: reportedCommentsKey)
        Task.detached { await PersistenceSyncService.shared.upsertModerationReport(kind: "comment", targetId: id) }
    }

    func markMessageReported(_ messageId: String) {
        let id = messageId.lowercased()
        guard !reportedMessageIds.contains(id) else { return }
        reportedMessageIds.insert(id)
        persist(Array(reportedMessageIds), key: reportedMessagesKey)
        Task.detached { await PersistenceSyncService.shared.upsertModerationReport(kind: "message", targetId: id) }
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

    // MARK: - Hydration

    func hydrateFromSupabase() async {
        async let remoteMutedUsers = PersistenceSyncService.shared.fetchModerationMutedUsers()
        async let remoteMutedTags = PersistenceSyncService.shared.fetchModerationMutedTags()
        async let remoteFollowedTags = PersistenceSyncService.shared.fetchModerationFollowedTags()
        async let remoteKeywords = PersistenceSyncService.shared.fetchModerationKeywords()
        async let remoteReports = PersistenceSyncService.shared.fetchModerationReports()

        let (muUsers, muTags, foTags, kws, reports) = await (
            remoteMutedUsers, remoteMutedTags, remoteFollowedTags, remoteKeywords, remoteReports
        )

        // Merge local-only entries up to the server, then overwrite local
        // state with the union (server-as-source-of-truth).
        let localOnlyMutedUsers = mutedUserIds.subtracting(muUsers)
        for id in localOnlyMutedUsers {
            await PersistenceSyncService.shared.upsertModerationMutedUser(id)
        }
        let localOnlyMutedTags = mutedTags.subtracting(muTags)
        for tag in localOnlyMutedTags {
            await PersistenceSyncService.shared.upsertModerationMutedTag(tag)
        }
        let localOnlyFollowed = followedTags.subtracting(foTags)
        for tag in localOnlyFollowed {
            await PersistenceSyncService.shared.upsertModerationFollowedTag(tag)
        }
        let lowerRemoteKeywords = Set(kws.map { $0.lowercased() })
        let localOnlyKeywords = keywordFilters.filter { !lowerRemoteKeywords.contains($0.lowercased()) }
        for kw in localOnlyKeywords {
            await PersistenceSyncService.shared.upsertModerationKeyword(kw)
        }

        let remotePostIds = Set(reports.filter { $0.target_kind == "post" }.map { $0.target_id })
        let remoteCommentIds = Set(reports.filter { $0.target_kind == "comment" }.map { $0.target_id })
        let remoteMessageIds = Set(reports.filter { $0.target_kind == "message" }.map { $0.target_id })

        let localOnlyPostReports = reportedPostIds.subtracting(remotePostIds)
        for id in localOnlyPostReports {
            await PersistenceSyncService.shared.upsertModerationReport(kind: "post", targetId: id)
        }
        let localOnlyCommentReports = reportedCommentIds.subtracting(remoteCommentIds)
        for id in localOnlyCommentReports {
            await PersistenceSyncService.shared.upsertModerationReport(kind: "comment", targetId: id)
        }
        let localOnlyMessageReports = reportedMessageIds.subtracting(remoteMessageIds)
        for id in localOnlyMessageReports {
            await PersistenceSyncService.shared.upsertModerationReport(kind: "message", targetId: id)
        }

        mutedUserIds = mutedUserIds.union(muUsers)
        mutedTags = mutedTags.union(muTags)
        followedTags = followedTags.union(foTags)

        // Keep local casing for keywords already present; append unique remote
        // keywords case-insensitively.
        let existingLower = Set(keywordFilters.map { $0.lowercased() })
        for kw in kws where !existingLower.contains(kw.lowercased()) {
            keywordFilters.append(kw)
        }

        reportedPostIds = reportedPostIds.union(remotePostIds)
        reportedCommentIds = reportedCommentIds.union(remoteCommentIds)
        reportedMessageIds = reportedMessageIds.union(remoteMessageIds)

        persist(Array(mutedUserIds), key: mutedUsersKey)
        persist(Array(mutedTags), key: mutedTagsKey)
        persist(Array(followedTags), key: followedTagsKey)
        UserDefaults.standard.set(keywordFilters, forKey: keywordsKey)
        persist(Array(reportedPostIds), key: reportedPostsKey)
        persist(Array(reportedCommentIds), key: reportedCommentsKey)
        persist(Array(reportedMessageIds), key: reportedMessagesKey)
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
