import SwiftUI

@Observable
final class SocialViewModel {
    var posts: [WorkoutPost] = []
    var feedPosts: [FeedPost] = []
    var searchResults: [FriendSearchResult] = []
    var searchQuery: String = ""
    var isSearching: Bool = false
    var isLoadingFeed: Bool = false
    var feedError: String?

    var feedFilter: FeedFilter = .all
    var communityMode: CommunityMode = .feed
    var selectedTags: Set<FeedTag> = []
    var postSearchQuery: String = "" {
        didSet {
            if postSearchQuery != oldValue { runFeedSearch() }
        }
    }
    var isPostSearchActive: Bool = false
    var searchedPeople: [SocialUser] = []
    var isSearchingPeople: Bool = false
    private var feedSearchTask: Task<Void, Never>?
    var isTagsExpanded: Bool = false
    var expandedCategories: Set<TagCategory> = []

    var isLoadingMore: Bool = false
    var hasMorePosts: Bool = true
    private var oldestCursor: Date?
    private let pageSize: Int = 20

    var pendingIncomingCount: Int = 0
    private var pendingIncomingIds: [String] = []

    var blockedUserIds: Set<String> = []

    private let socialService = SocialService.shared
    private let messagingService = MessagingService.shared
    private let likeManager = LikeManager.shared
    private let realtimeFeed = RealtimeFeedService.shared
    private var repostedPostIds: Set<String> = []
    private var commentCounts: [String: Int] = [:]
    private var followingIds: Set<String> = []
    private var sentRequestReceiverIds: Set<String> = []

    var filteredFeedPosts: [FeedPost] {
        let moderation = LocalModerationStore.shared
        let visible = feedPosts.filter { post in
            if blockedUserIds.contains(post.user.id.uuidString.lowercased()) { return false }
            let tagStrings = post.tags.map { $0.rawValue.lowercased() } + RichTextParser.extractHashtags(post.textContent)
            if moderation.isPostHidden(
                postId: post.supabaseId ?? post.id.uuidString.lowercased(),
                userId: post.user.id.uuidString.lowercased(),
                tags: tagStrings
            ) { return false }
            return true
        }
        let byFilter: [FeedPost]
        switch feedFilter {
        case .all:
            byFilter = visible
        case .following:
            let followedTags = LocalModerationStore.shared.followedTags
            byFilter = visible.filter { post in
                if post.isFollowing { return true }
                let postTagStrings = Set(post.tags.map { $0.rawValue.lowercased() } + RichTextParser.extractHashtags(post.textContent).map { $0.lowercased() })
                return !postTagStrings.isDisjoint(with: followedTags)
            }
        case .tags:
            if selectedTags.isEmpty {
                byFilter = visible
            } else {
                byFilter = visible.filter { post in
                    !post.tags.filter { selectedTags.contains($0) }.isEmpty
                }
            }
        }
        let trimmed = postSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return byFilter }
        return byFilter.filter { post in
            if post.textContent.localizedCaseInsensitiveContains(trimmed) { return true }
            if post.user.name.localizedCaseInsensitiveContains(trimmed) { return true }
            if post.user.username.localizedCaseInsensitiveContains(trimmed) { return true }
            if post.tags.contains(where: { $0.rawValue.localizedCaseInsensitiveContains(trimmed) }) { return true }
            return false
        }
    }

    init() {}

    func initialLoad() async {
        if AuthService.shared.session == nil {
            for _ in 0..<10 {
                try? await Task.sleep(for: .milliseconds(300))
                if AuthService.shared.session != nil { break }
            }
        }
        await loadFollowingIds()
        await loadSentRequests()
        await loadBlockedUserIds()
        await loadFeed()
        await startRealtime()
    }

    private func loadBlockedUserIds() async {
        do {
            let userId = try AuthService.shared.currentUserId()
            let ids = try await ModerationService.shared.blockedUserIds(blockerId: userId)
            blockedUserIds = Set(ids.map { $0.lowercased() })
        } catch {}
    }

    func refreshBlockedUserIds() async {
        await loadBlockedUserIds()
    }

    private func startRealtime() async {
        guard let userId = try? AuthService.shared.currentUserId() else { return }
        await realtimeFeed.subscribe(
            userId: userId,
            onInsert: { [weak self] inserted in
                guard let self else { return }
                if self.feedPosts.contains(where: { $0.supabaseId == inserted.id }) { return }
                if self.blockedUserIds.contains(inserted.user_id.lowercased()) { return }
                if self.pendingIncomingIds.contains(inserted.id) { return }
                self.pendingIncomingIds.append(inserted.id)
                self.pendingIncomingCount = self.pendingIncomingIds.count
            },
            onUpdate: { [weak self] updated in
                guard let self else { return }
                Task { await self.applyRealtimeUpdate(updated) }
            },
            onDelete: { [weak self] deletedId in
                guard let self else { return }
                self.feedPosts.removeAll { $0.supabaseId == deletedId }
                self.pendingIncomingIds.removeAll { $0 == deletedId }
                self.pendingIncomingCount = self.pendingIncomingIds.count
            }
        )
    }

    private func applyRealtimeUpdate(_ updated: SupabaseFeedPost) async {
        guard let index = feedPosts.firstIndex(where: { $0.supabaseId == updated.id }) else { return }
        var post = feedPosts[index]
        post.textContent = updated.text_content ?? post.textContent
        post.tags = (updated.tags ?? []).compactMap { FeedTag(rawValue: $0) }
        if let editedISO = updated.edited_at {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            post.editedAt = iso.date(from: editedISO)
        }
        feedPosts[index] = post
    }

    func loadNewPosts() async {
        guard !pendingIncomingIds.isEmpty else { return }
        let ids = pendingIncomingIds
        pendingIncomingIds = []
        pendingIncomingCount = 0

        var newPosts: [FeedPost] = []
        for id in ids {
            if let full = try? await socialService.fetchPost(postId: id) {
                if let converted = buildFeedPost(from: full) {
                    newPosts.append(converted)
                }
            }
        }
        guard !newPosts.isEmpty else { return }
        newPosts.sort { $0.timestamp > $1.timestamp }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            feedPosts.insert(contentsOf: newPosts, at: 0)
        }
    }

    func buildFeedPost(from sp: SupabaseFeedPostWithProfile) -> FeedPost? {
        let user = socialService.socialUserFromAuthor(sp.profiles)
        let tags = (sp.tags ?? []).compactMap { FeedTag(rawValue: $0) }
        var mediaItems: [FeedMediaItem] = (sp.media_urls ?? []).map { url in
            FeedMediaItem(type: .photo, imageURL: url)
        }
        if let audioUrl = sp.audio_url, !audioUrl.isEmpty {
            mediaItems.append(FeedMediaItem(type: .voice, imageURL: audioUrl, voiceDuration: sp.audio_duration ?? 0))
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let edited = sp.edited_at.flatMap { iso.date(from: $0) }
        return FeedPost(
            id: UUID(uuidString: sp.id) ?? UUID(),
            user: user,
            timestamp: socialService.parseDate(sp.created_at),
            textContent: sp.text_content ?? "",
            media: mediaItems,
            likeCount: sp.high_five_count ?? 0,
            isLiked: likeManager.isLiked(postId: sp.id),
            comments: [],
            commentCount: 0,
            repostCount: sp.repost_count ?? 0,
            isReposted: repostedPostIds.contains(sp.id),
            tags: tags,
            isFollowing: followingIds.contains(sp.user_id),
            supabaseId: sp.id,
            editedAt: edited
        )
    }

    private func loadFollowingIds() async {
        do {
            let userId = try AuthService.shared.currentUserId()
            let ids = try await messagingService.fetchFollowing(userId: userId)
            followingIds = Set(ids)
        } catch {}
    }

    private func loadSentRequests() async {
        do {
            let userId = try AuthService.shared.currentUserId()
            let requests = try await messagingService.fetchSentRequests(userId: userId)
            sentRequestReceiverIds = Set(requests.map { $0.receiver_id })
        } catch {}
    }

    func loadFeed() async {
        guard !isLoadingFeed else { return }
        isLoadingFeed = true
        feedError = nil
        oldestCursor = nil
        hasMorePosts = true

        do {
            let userId = try AuthService.shared.currentUserId()
            print("FEED_LOAD: Fetching posts for user \(userId)")
            let supabasePosts = try await socialService.fetchPostsPage(before: nil, pageSize: pageSize)
            print("FEED_LOAD: Fetched \(supabasePosts.count) posts from Supabase")

            let postIds = supabasePosts.map { $0.id }

            var likedIds: Set<String> = []
            do {
                likedIds = try await socialService.fetchLikedPostIds(userId: userId, postIds: postIds)
            } catch {
                print("FEED_LOAD: Failed to fetch liked IDs: \(error.localizedDescription)")
            }

            do {
                repostedPostIds = try await socialService.fetchRepostedPostIds(userId: userId, postIds: postIds)
            } catch {
                print("FEED_LOAD: Failed to fetch reposted IDs: \(error.localizedDescription)")
            }

            var counts: [String: Int] = [:]
            for sp in supabasePosts {
                counts[sp.id] = sp.high_five_count ?? 0
            }
            likeManager.bulkSetState(likedIds: likedIds, counts: counts)

            var commentCounts: [String: Int] = [:]
            do {
                commentCounts = try await socialService.fetchCommentCounts(postIds: postIds)
            } catch {
                print("FEED_LOAD: Failed to fetch comment counts: \(error.localizedDescription)")
            }

            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var newFeedPosts: [FeedPost] = []
            for sp in supabasePosts {
                let user = socialService.socialUserFromAuthor(sp.profiles)
                let tags = (sp.tags ?? []).compactMap { FeedTag(rawValue: $0) }
                let isLiked = likeManager.isLiked(postId: sp.id)
                let isReposted = repostedPostIds.contains(sp.id)

                var mediaItems: [FeedMediaItem] = (sp.media_urls ?? []).map { url in
                    FeedMediaItem(type: .photo, imageURL: url)
                }
                if let audioUrl = sp.audio_url, !audioUrl.isEmpty {
                    mediaItems.append(FeedMediaItem(type: .voice, imageURL: audioUrl, voiceDuration: sp.audio_duration ?? 0))
                }

                let isFollowingUser = followingIds.contains(sp.user_id)
                let edited = sp.edited_at.flatMap { iso.date(from: $0) }

                let post = FeedPost(
                    id: UUID(uuidString: sp.id) ?? UUID(),
                    user: user,
                    timestamp: socialService.parseDate(sp.created_at),
                    textContent: sp.text_content ?? "",
                    media: mediaItems,
                    likeCount: sp.high_five_count ?? 0,
                    isLiked: isLiked,
                    comments: [],
                    commentCount: commentCounts[sp.id] ?? 0,
                    repostCount: sp.repost_count ?? 0,
                    isReposted: isReposted,
                    tags: tags,
                    isFollowing: isFollowingUser,
                    supabaseId: sp.id,
                    editedAt: edited
                )
                newFeedPosts.append(post)
            }

            feedPosts = newFeedPosts
            pendingIncomingIds = []
            pendingIncomingCount = 0
            oldestCursor = feedPosts.last?.timestamp
            hasMorePosts = supabasePosts.count >= pageSize
            print("FEED_LOAD: Successfully loaded \(feedPosts.count) feed posts")
        } catch is CancellationError {
            print("FEED_LOAD: cancelled")
            isLoadingFeed = false
            return
        } catch let urlError as URLError where urlError.code == .cancelled {
            print("FEED_LOAD: URL cancelled")
            isLoadingFeed = false
            return
        } catch {
            print("FEED_LOAD: ERROR loading feed: \(error)")
            feedError = error.localizedDescription
        }

        isLoadingFeed = false
    }

    func refreshFeed() async {
        isLoadingFeed = false
        await loadFeed()
    }

    func loadMoreIfNeeded(currentPost: FeedPost) async {
        guard hasMorePosts, !isLoadingMore, !isLoadingFeed else { return }
        let threshold = 3
        guard let index = feedPosts.firstIndex(where: { $0.id == currentPost.id }) else { return }
        guard index >= feedPosts.count - threshold else { return }
        await loadMore()
    }

    private func loadMore() async {
        guard hasMorePosts, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let userId = try AuthService.shared.currentUserId()
            let cursor = oldestCursor
            let supabasePosts = try await socialService.fetchPostsPage(before: cursor, pageSize: pageSize)
            if supabasePosts.isEmpty {
                hasMorePosts = false
                return
            }

            let postIds = supabasePosts.map { $0.id }
            let likedIds = (try? await socialService.fetchLikedPostIds(userId: userId, postIds: postIds)) ?? []
            let reposted = (try? await socialService.fetchRepostedPostIds(userId: userId, postIds: postIds)) ?? []
            let commentCountMap = (try? await socialService.fetchCommentCounts(postIds: postIds)) ?? [:]

            var counts: [String: Int] = [:]
            for sp in supabasePosts { counts[sp.id] = sp.high_five_count ?? 0 }
            likeManager.bulkSetState(likedIds: likedIds, counts: counts)

            let existingIds = Set(feedPosts.compactMap(\.supabaseId))
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var newPosts: [FeedPost] = []
            for sp in supabasePosts where !existingIds.contains(sp.id) {
                let user = socialService.socialUserFromAuthor(sp.profiles)
                let tags = (sp.tags ?? []).compactMap { FeedTag(rawValue: $0) }
                var mediaItems: [FeedMediaItem] = (sp.media_urls ?? []).map { url in
                    FeedMediaItem(type: .photo, imageURL: url)
                }
                if let audioUrl = sp.audio_url, !audioUrl.isEmpty {
                    mediaItems.append(FeedMediaItem(type: .voice, imageURL: audioUrl, voiceDuration: sp.audio_duration ?? 0))
                }
                let edited = sp.edited_at.flatMap { iso.date(from: $0) }
                let post = FeedPost(
                    id: UUID(uuidString: sp.id) ?? UUID(),
                    user: user,
                    timestamp: socialService.parseDate(sp.created_at),
                    textContent: sp.text_content ?? "",
                    media: mediaItems,
                    likeCount: sp.high_five_count ?? 0,
                    isLiked: likedIds.contains(sp.id),
                    comments: [],
                    commentCount: commentCountMap[sp.id] ?? 0,
                    repostCount: sp.repost_count ?? 0,
                    isReposted: reposted.contains(sp.id),
                    tags: tags,
                    isFollowing: followingIds.contains(sp.user_id),
                    supabaseId: sp.id,
                    editedAt: edited
                )
                newPosts.append(post)
            }

            feedPosts.append(contentsOf: newPosts)
            oldestCursor = feedPosts.last?.timestamp
            hasMorePosts = supabasePosts.count >= pageSize
        } catch is CancellationError {
            print("FEED_LOAD_MORE: cancelled")
        } catch let urlError as URLError where urlError.code == .cancelled {
            print("FEED_LOAD_MORE: URL cancelled")
        } catch {
            print("FEED_LOAD_MORE: ERROR: \(error)")
        }
    }

    func updatePost(postID: UUID, textContent: String, tags: [FeedTag]) async -> Bool {
        guard let index = feedPosts.firstIndex(where: { $0.id == postID }) else { return false }
        let supabaseId = feedPosts[index].supabaseId ?? postID.uuidString
        do {
            let tagStrings = tags.map { $0.rawValue }
            let updated = try await socialService.updatePost(
                postId: supabaseId,
                textContent: textContent,
                tags: tagStrings.isEmpty ? nil : tagStrings
            )
            let user = socialService.socialUserFromAuthor(updated.profiles)
            let updatedTags = (updated.tags ?? []).compactMap { FeedTag(rawValue: $0) }
            var mediaItems: [FeedMediaItem] = (updated.media_urls ?? []).map { url in
                FeedMediaItem(type: .photo, imageURL: url)
            }
            if let audioUrl = updated.audio_url, !audioUrl.isEmpty {
                mediaItems.append(FeedMediaItem(type: .voice, imageURL: audioUrl, voiceDuration: updated.audio_duration ?? 0))
            }
            let original = feedPosts[index]
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let edited = updated.edited_at.flatMap { iso.date(from: $0) } ?? Date()
            let newPost = FeedPost(
                id: original.id,
                user: user,
                timestamp: original.timestamp,
                textContent: updated.text_content ?? textContent,
                media: mediaItems.isEmpty ? original.media : mediaItems,
                likeCount: original.likeCount,
                isLiked: original.isLiked,
                comments: original.comments,
                commentCount: original.commentCount,
                repostCount: original.repostCount,
                isReposted: original.isReposted,
                tags: updatedTags,
                isFollowing: original.isFollowing,
                supabaseId: original.supabaseId,
                editedAt: edited
            )
            feedPosts[index] = newPost
            return true
        } catch {
            feedError = "Failed to update post: \(error.localizedDescription)"
            return false
        }
    }

    func toggleFeedLike(for postID: UUID) {
        guard let index = feedPosts.firstIndex(where: { $0.id == postID }) else { return }
        let supabaseId = feedPosts[index].supabaseId ?? postID.uuidString
        likeManager.toggleLike(postId: supabaseId)
        feedPosts[index].isLiked = likeManager.isLiked(postId: supabaseId)
        feedPosts[index].likeCount = likeManager.likeCount(postId: supabaseId, fallback: feedPosts[index].likeCount)
    }

    func ensurePostInFeed(_ post: FeedPost) {
        if !feedPosts.contains(where: { $0.id == post.id }) {
            feedPosts.append(post)
        }
    }

    func makeOptimisticComment(text: String) -> PostComment {
        let currentUser: SocialUser
        if let userId = try? AuthService.shared.currentUserId(),
           let me = feedPosts.first(where: { $0.user.id.uuidString.lowercased() == userId.lowercased() })?.user {
            currentUser = me
        } else {
            currentUser = SocialUser(id: UUID(), name: "You", username: "me", avatarInitial: "Y", avatarColor: Color(red: 0, green: 0.9, blue: 1), activeProgramName: nil, streak: 0, totalFP: 0)
        }
        return PostComment(id: UUID(), user: currentUser, text: text, timestamp: Date())
    }

    func addFeedComment(to postID: UUID, text: String, optimisticComment: PostComment? = nil) async -> Bool {
        guard let index = feedPosts.firstIndex(where: { $0.id == postID }) else { return false }
        let supabaseId = feedPosts[index].supabaseId ?? postID.uuidString

        let placeholder = optimisticComment ?? makeOptimisticComment(text: text)

        if !feedPosts[index].comments.contains(where: { $0.id == placeholder.id }) {
            feedPosts[index].comments.append(placeholder)
            feedPosts[index].commentCount += 1
        }

        do {
            let userId = try AuthService.shared.currentUserId()
            let comment = try await socialService.addComment(postId: supabaseId, userId: userId, text: text)
            let user = socialService.socialUserFromAuthor(comment.profiles)
            let postComment = PostComment(
                id: UUID(uuidString: comment.id) ?? UUID(),
                user: user,
                text: comment.commentText ?? text,
                timestamp: socialService.parseDate(comment.created_at)
            )
            if let idx = feedPosts.firstIndex(where: { $0.id == postID }) {
                if let optimisticIdx = feedPosts[idx].comments.firstIndex(where: { $0.id == placeholder.id }) {
                    feedPosts[idx].comments[optimisticIdx] = postComment
                }
            }
            return true
        } catch {
            if let idx = feedPosts.firstIndex(where: { $0.id == postID }) {
                feedPosts[idx].comments.removeAll { $0.id == placeholder.id }
                feedPosts[idx].commentCount = max(0, feedPosts[idx].commentCount - 1)
            }
            feedError = "Failed to add comment: \(error.localizedDescription)"
            return false
        }
    }

    func deleteFeedComment(_ comment: PostComment, from postID: UUID) async -> Bool {
        let commentIdString = comment.id.uuidString.lowercased()

        if let idx = feedPosts.firstIndex(where: { $0.id == postID }) {
            withAnimation(.spring(response: 0.3)) {
                feedPosts[idx].comments.removeAll { $0.id == comment.id }
                feedPosts[idx].commentCount = max(0, feedPosts[idx].commentCount - 1)
            }
        }

        do {
            try await socialService.deleteComment(commentId: commentIdString)
            return true
        } catch {
            if let idx = feedPosts.firstIndex(where: { $0.id == postID }) {
                feedPosts[idx].comments.append(comment)
                feedPosts[idx].commentCount += 1
            }
            feedError = "Failed to delete comment"
            return false
        }
    }

    func loadComments(for postID: UUID) async {
        guard let index = feedPosts.firstIndex(where: { $0.id == postID }) else { return }
        let supabaseId = feedPosts[index].supabaseId ?? postID.uuidString

        do {
            let comments = try await socialService.fetchComments(postId: supabaseId)
            let postComments = comments.map { c in
                PostComment(
                    id: UUID(uuidString: c.id) ?? UUID(),
                    user: socialService.socialUserFromAuthor(c.profiles),
                    text: c.commentText ?? "",
                    timestamp: socialService.parseDate(c.created_at)
                )
            }
            if let idx = feedPosts.firstIndex(where: { $0.id == postID }) {
                feedPosts[idx].comments = postComments
                feedPosts[idx].commentCount = postComments.count
            }
        } catch {
            feedError = "Failed to load comments"
        }
    }

    func createPost(textContent: String, images: [UIImage], tags: [FeedTag], voiceData: Data? = nil, voiceDuration: TimeInterval = 0) async -> FeedPost? {
        do {
            let userId = try AuthService.shared.currentUserId()

            var mediaUrls: [String] = []
            for (i, image) in images.enumerated() {
                if let data = image.jpegData(compressionQuality: 0.8) {
                    let url = try await socialService.uploadMedia(userId: userId, imageData: data, index: i)
                    mediaUrls.append(url)
                }
            }

            var audioUrl: String?
            if let voiceData {
                audioUrl = try await socialService.uploadAudio(userId: userId, audioData: voiceData)
            }

            let tagStrings = tags.map { $0.rawValue }
            let created = try await socialService.createPost(
                userId: userId,
                textContent: textContent,
                mediaUrls: mediaUrls.isEmpty ? nil : mediaUrls,
                tags: tagStrings.isEmpty ? nil : tagStrings,
                audioUrl: audioUrl,
                audioDuration: voiceData != nil ? voiceDuration : nil
            )

            let user = socialService.socialUserFromAuthor(created.profiles)
            let feedTags = (created.tags ?? []).compactMap { FeedTag(rawValue: $0) }
            var mediaItems: [FeedMediaItem] = (created.media_urls ?? []).map { url in
                FeedMediaItem(type: .photo, imageURL: url)
            }
            if let createdAudio = created.audio_url, !createdAudio.isEmpty {
                mediaItems.append(FeedMediaItem(type: .voice, imageURL: createdAudio, voiceDuration: created.audio_duration ?? voiceDuration))
            }

            let post = FeedPost(
                id: UUID(uuidString: created.id) ?? UUID(),
                user: user,
                timestamp: socialService.parseDate(created.created_at),
                textContent: created.text_content ?? "",
                media: mediaItems,
                likeCount: 0,
                isLiked: false,
                comments: [],
                repostCount: 0,
                tags: feedTags,
                isFollowing: false,
                supabaseId: created.id
            )

            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                feedPosts.insert(post, at: 0)
            }

            return post
        } catch {
            feedError = error.localizedDescription
            return nil
        }
    }

    func toggleRepost(for postID: UUID) {
        guard let index = feedPosts.firstIndex(where: { $0.id == postID }) else { return }
        let wasReposted = feedPosts[index].isReposted
        feedPosts[index].isReposted.toggle()
        feedPosts[index].repostCount += feedPosts[index].isReposted ? 1 : -1

        let supabaseId = feedPosts[index].supabaseId ?? postID.uuidString

        Task {
            do {
                let userId = try AuthService.shared.currentUserId()
                if wasReposted {
                    try await socialService.unrepostPost(postId: supabaseId, userId: userId)
                } else {
                    try await socialService.repostPost(postId: supabaseId, userId: userId)
                }
            } catch {
                guard let idx = feedPosts.firstIndex(where: { $0.id == postID }) else { return }
                feedPosts[idx].isReposted = wasReposted
                feedPosts[idx].repostCount += wasReposted ? 1 : -1
            }
        }
    }

    func toggleLike(for postID: UUID) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        let supabaseId = postID.uuidString.lowercased()
        likeManager.toggleLike(postId: supabaseId)
        posts[index].isLiked = likeManager.isLiked(postId: supabaseId)
        posts[index].likeCount = likeManager.likeCount(postId: supabaseId, fallback: posts[index].likeCount)
    }

    func addComment(to postID: UUID, text: String) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        let me = SocialUser(id: UUID(), name: "You", username: "me", avatarInitial: "Y", avatarColor: Color(red: 0, green: 0.9, blue: 1), activeProgramName: nil, streak: 0, totalFP: 0)
        let comment = PostComment(id: UUID(), user: me, text: text, timestamp: Date())
        posts[index].comments.append(comment)
    }

    func deletePost(_ postID: UUID) {
        guard let index = feedPosts.firstIndex(where: { $0.id == postID }) else { return }
        let supabaseId = feedPosts[index].supabaseId ?? postID.uuidString
        feedPosts.remove(at: index)

        Task {
            do {
                try await socialService.deletePost(postId: supabaseId)
            } catch {}
        }
    }

    func addFeedPost(_ post: FeedPost) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            feedPosts.insert(post, at: 0)
        }
    }

    var searchedHashtags: [String] {
        let trimmed = postSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var raw = trimmed
        if raw.hasPrefix("#") { raw.removeFirst() }
        let needle = raw.lowercased()
        guard !needle.isEmpty else { return [] }

        var counts: [String: Int] = [:]
        for post in feedPosts {
            var tagsForPost = Set<String>()
            for t in post.tags { tagsForPost.insert(t.rawValue.lowercased()) }
            for h in RichTextParser.extractHashtags(post.textContent) { tagsForPost.insert(h.lowercased()) }
            for t in tagsForPost where t.contains(needle) {
                counts[t, default: 0] += 1
            }
        }
        var ordered = counts.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            return lhs.key < rhs.key
        }.map { $0.key }

        // Always surface the literal query as a tag option so users can navigate even with no matches.
        if !ordered.contains(needle) {
            ordered.insert(needle, at: 0)
        }
        return Array(ordered.prefix(8))
    }

    func runFeedSearch() {
        feedSearchTask?.cancel()
        let trimmed = postSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchedPeople = []
            isSearchingPeople = false
            return
        }
        // Strip leading # for people queries
        var peopleQuery = trimmed
        if peopleQuery.hasPrefix("#") { peopleQuery.removeFirst() }
        guard !peopleQuery.isEmpty else {
            searchedPeople = []
            return
        }

        isSearchingPeople = true
        feedSearchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(220))
            guard let self else { return }
            if Task.isCancelled { return }
            do {
                let myId = (try? AuthService.shared.currentUserId()) ?? ""
                let profiles = try await self.messagingService.searchUsers(query: peopleQuery, excludeUserId: myId)
                if Task.isCancelled { return }
                let users = profiles.map { self.messagingService.socialUserFromAuthor($0) }
                self.searchedPeople = users
            } catch {
                if !Task.isCancelled { self.searchedPeople = [] }
            }
            if !Task.isCancelled { self.isSearchingPeople = false }
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

                searchResults = profiles.map { profile in
                    let user = messagingService.socialUserFromAuthor(profile)
                    let status: FriendRequestStatus = sentRequestReceiverIds.contains(profile.id) ? .pending : .none
                    return FriendSearchResult(id: user.id, user: user, requestStatus: status)
                }
            } catch {
                searchResults = []
            }
            isSearching = false
        }
    }

    func sendFriendRequest(to userID: UUID) {
        guard let index = searchResults.firstIndex(where: { $0.id == userID }) else { return }
        searchResults[index].requestStatus = .pending

        Task {
            do {
                let userId = try AuthService.shared.currentUserId()
                try await messagingService.sendFriendRequest(senderId: userId, receiverId: userID.uuidString)
                sentRequestReceiverIds.insert(userID.uuidString)
            } catch {
                if let idx = searchResults.firstIndex(where: { $0.id == userID }) {
                    searchResults[idx].requestStatus = .none
                }
            }
        }
    }

    func followUser(userId: String) async throws {
        let myId = try AuthService.shared.currentUserId()
        try await messagingService.followUser(followerId: myId, followingId: userId)
        followingIds.insert(userId)
    }

    func unfollowUser(userId: String) async throws {
        let myId = try AuthService.shared.currentUserId()
        try await messagingService.unfollowUser(followerId: myId, followingId: userId)
        followingIds.remove(userId)
    }

    func isFollowing(userId: String) -> Bool {
        followingIds.contains(userId)
    }
}


