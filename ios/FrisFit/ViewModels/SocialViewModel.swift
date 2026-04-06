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
    var selectedTags: Set<FeedTag> = []
    var isTagsExpanded: Bool = false
    var expandedCategories: Set<TagCategory> = []

    private let socialService = SocialService.shared
    private let messagingService = MessagingService.shared
    private var likedPostIds: Set<String> = []
    private var commentCounts: [String: Int] = [:]
    private var followingIds: Set<String> = []
    private var sentRequestReceiverIds: Set<String> = []

    var filteredFeedPosts: [FeedPost] {
        switch feedFilter {
        case .all:
            return feedPosts
        case .following:
            return feedPosts.filter { $0.isFollowing }
        case .tags:
            if selectedTags.isEmpty { return feedPosts }
            return feedPosts.filter { post in
                !post.tags.filter { selectedTags.contains($0) }.isEmpty
            }
        }
    }

    init() {
        Task {
            await loadFollowingIds()
            await loadSentRequests()
            await loadFeed()
        }
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

        do {
            let userId = try AuthService.shared.currentUserId()
            let supabasePosts = try await socialService.fetchPosts(limit: 50)

            let postIds = supabasePosts.map { $0.id }
            likedPostIds = try await socialService.fetchLikedPostIds(userId: userId, postIds: postIds)

            var newFeedPosts: [FeedPost] = []
            for sp in supabasePosts {
                let user = socialService.socialUserFromAuthor(sp.profiles)
                let tags = (sp.tags ?? []).compactMap { FeedTag(rawValue: $0) }
                let isLiked = likedPostIds.contains(sp.id)

                let mediaItems: [FeedMediaItem] = (sp.media_urls ?? []).map { url in
                    FeedMediaItem(type: .photo, imageURL: url)
                }

                let isFollowingUser = followingIds.contains(sp.user_id)

                let post = FeedPost(
                    id: UUID(uuidString: sp.id) ?? UUID(),
                    user: user,
                    timestamp: socialService.parseDate(sp.created_at),
                    textContent: sp.text_content ?? "",
                    media: mediaItems,
                    highFiveCount: sp.high_five_count ?? 0,
                    isHighFived: isLiked,
                    comments: [],
                    repostCount: sp.repost_count ?? 0,
                    tags: tags,
                    isFollowing: isFollowingUser,
                    supabaseId: sp.id
                )
                newFeedPosts.append(post)
            }

            feedPosts = newFeedPosts
        } catch {
            feedError = error.localizedDescription
        }

        isLoadingFeed = false
    }

    func refreshFeed() async {
        isLoadingFeed = false
        await loadFeed()
    }

    func toggleFeedHighFive(for postID: UUID) {
        guard let index = feedPosts.firstIndex(where: { $0.id == postID }) else { return }
        let wasHighFived = feedPosts[index].isHighFived
        feedPosts[index].isHighFived.toggle()
        feedPosts[index].highFiveCount += feedPosts[index].isHighFived ? 1 : -1

        let supabaseId = feedPosts[index].supabaseId ?? postID.uuidString

        Task {
            do {
                let userId = try AuthService.shared.currentUserId()
                if wasHighFived {
                    try await socialService.unlikePost(postId: supabaseId, userId: userId)
                } else {
                    try await socialService.likePost(postId: supabaseId, userId: userId)
                }
            } catch {
                guard let idx = feedPosts.firstIndex(where: { $0.id == postID }) else { return }
                feedPosts[idx].isHighFived = wasHighFived
                feedPosts[idx].highFiveCount += wasHighFived ? 1 : -1
            }
        }
    }

    func addFeedComment(to postID: UUID, text: String) {
        guard let index = feedPosts.firstIndex(where: { $0.id == postID }) else { return }
        let supabaseId = feedPosts[index].supabaseId ?? postID.uuidString

        Task {
            do {
                let userId = try AuthService.shared.currentUserId()
                let comment = try await socialService.addComment(postId: supabaseId, userId: userId, text: text)
                let user = socialService.socialUserFromAuthor(comment.profiles)
                let postComment = PostComment(
                    id: UUID(uuidString: comment.id) ?? UUID(),
                    user: user,
                    text: comment.text_content ?? text,
                    timestamp: socialService.parseDate(comment.created_at)
                )
                if let idx = feedPosts.firstIndex(where: { $0.id == postID }) {
                    feedPosts[idx].comments.append(postComment)
                }
            } catch {
                // Silently fail
            }
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
                    text: c.text_content ?? "",
                    timestamp: socialService.parseDate(c.created_at)
                )
            }
            if let idx = feedPosts.firstIndex(where: { $0.id == postID }) {
                feedPosts[idx].comments = postComments
            }
        } catch {
            // Silently fail
        }
    }

    func createPost(textContent: String, images: [UIImage], tags: [FeedTag]) async -> FeedPost? {
        do {
            let userId = try AuthService.shared.currentUserId()

            var mediaUrls: [String] = []
            for (i, image) in images.enumerated() {
                if let data = image.jpegData(compressionQuality: 0.8) {
                    let url = try await socialService.uploadMedia(userId: userId, imageData: data, index: i)
                    mediaUrls.append(url)
                }
            }

            let tagStrings = tags.map { $0.rawValue }
            let created = try await socialService.createPost(
                userId: userId,
                textContent: textContent,
                mediaUrls: mediaUrls.isEmpty ? nil : mediaUrls,
                tags: tagStrings.isEmpty ? nil : tagStrings
            )

            let user = socialService.socialUserFromAuthor(created.profiles)
            let feedTags = (created.tags ?? []).compactMap { FeedTag(rawValue: $0) }
            let mediaItems: [FeedMediaItem] = (created.media_urls ?? []).map { url in
                FeedMediaItem(type: .photo, imageURL: url)
            }

            let post = FeedPost(
                id: UUID(uuidString: created.id) ?? UUID(),
                user: user,
                timestamp: socialService.parseDate(created.created_at),
                textContent: created.text_content ?? "",
                media: mediaItems,
                highFiveCount: 0,
                isHighFived: false,
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

    func toggleHighFive(for postID: UUID) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        posts[index].isHighFived.toggle()
        posts[index].highFiveCount += posts[index].isHighFived ? 1 : -1
    }

    func addComment(to postID: UUID, text: String) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        let me = SocialUser(id: UUID(), name: "You", username: "me", avatarInitial: "Y", avatarColor: Color(red: 0, green: 0.9, blue: 1), activeProgramName: nil, streak: 0, totalFP: 0)
        let comment = PostComment(id: UUID(), user: me, text: text, timestamp: Date())
        posts[index].comments.append(comment)
    }

    func addFeedPost(_ post: FeedPost) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            feedPosts.insert(post, at: 0)
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


