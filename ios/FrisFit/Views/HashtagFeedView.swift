import SwiftUI

struct HashtagFeedView: View {
    let tag: String
    @Environment(\.dismiss) private var dismiss
    @State private var moderation = LocalModerationStore.shared
    @State private var posts: [FeedPost] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var sortMode: SortMode = .recent
    @State private var commentPost: FeedPost?
    @State private var selectedPost: FeedPost?
    @State private var selectedUser: SocialUser?
    @State private var selectedHashtag: String?
    @State private var socialViewModel = SocialViewModel()

    enum SortMode: String, CaseIterable {
        case recent = "Recent"
        case top = "Top"
    }

    private var normalizedTag: String {
        var t = tag.lowercased()
        if t.hasPrefix("#") { t.removeFirst() }
        return t
    }

    private var displayTag: String { "#\(normalizedTag)" }

    private var isFollowed: Bool {
        moderation.isTagFollowed(normalizedTag)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                sortBar
                    .padding(.horizontal)
                    .padding(.bottom, 12)

                if isLoading {
                    ProgressView()
                        .tint(PepTheme.teal)
                        .padding(.top, 60)
                } else if posts.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(sortedPosts) { post in
                            FeedPostCard(
                                post: post,
                                onLike: { socialViewModel.toggleFeedLike(for: post.id) },
                                onComment: { commentPost = post },
                                onRepost: { socialViewModel.toggleRepost(for: post.id) },
                                onTap: { selectedPost = post },
                                onUserTap: { user in selectedUser = user }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
        }
        .appBackground()
        .navigationTitle(displayTag)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
        .sheet(item: $commentPost) { post in
            FeedCommentsSheet(post: post, viewModel: socialViewModel)
        }
        .navigationDestination(item: $selectedPost) { post in
            PostDetailView(post: post, viewModel: socialViewModel)
        }
        .navigationDestination(item: $selectedUser) { user in
            UserProfileView(user: user, viewModel: ProfileViewModel())
        }
        .navigationDestination(item: Binding(get: { selectedHashtag.map(HashtagDestination.init) }, set: { selectedHashtag = $0?.tag })) { dest in
            HashtagFeedView(tag: dest.tag)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [PepTheme.teal.opacity(0.25), PepTheme.blue.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 56, height: 56)
                    Image(systemName: "number")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(PepTheme.teal)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(displayTag)
                        .font(.system(.title3, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(postCountLabel)
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        if isFollowed {
                            moderation.unfollowTag(normalizedTag)
                        } else {
                            moderation.followTag(normalizedTag)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isFollowed ? "checkmark" : "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text(isFollowed ? "Following" : "Follow Tag")
                            .font(.system(.subheadline, weight: .semibold))
                    }
                    .foregroundStyle(isFollowed ? PepTheme.textPrimary : PepTheme.invertedText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(isFollowed ? PepTheme.elevated : PepTheme.teal)
                    .clipShape(.capsule)
                }
                .sensoryFeedback(.selection, trigger: isFollowed)

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        if moderation.isTagMuted(normalizedTag) {
                            moderation.unmuteTag(normalizedTag)
                        } else {
                            moderation.muteTag(normalizedTag)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: moderation.isTagMuted(normalizedTag) ? "bell.slash.fill" : "bell.slash")
                            .font(.system(size: 11, weight: .semibold))
                        Text(moderation.isTagMuted(normalizedTag) ? "Muted" : "Mute")
                            .font(.system(.subheadline, weight: .semibold))
                    }
                    .foregroundStyle(PepTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(PepTheme.elevated)
                    .clipShape(.capsule)
                }
                .sensoryFeedback(.selection, trigger: moderation.isTagMuted(normalizedTag))

                Spacer()
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 18))
    }

    private var sortBar: some View {
        HStack(spacing: 8) {
            ForEach(SortMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.spring(response: 0.3)) { sortMode = mode }
                } label: {
                    Text(mode.rawValue)
                        .font(.system(.caption, weight: sortMode == mode ? .bold : .medium))
                        .foregroundStyle(sortMode == mode ? PepTheme.invertedText : PepTheme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(sortMode == mode ? PepTheme.teal : PepTheme.elevated)
                        .clipShape(.capsule)
                }
                .sensoryFeedback(.selection, trigger: sortMode)
            }
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "number.circle")
                .font(.system(size: 44))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
            Text("No posts yet")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
            Text("Be the first to post with \(displayTag)")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity)
    }

    private var sortedPosts: [FeedPost] {
        switch sortMode {
        case .recent: return posts.sorted { $0.timestamp > $1.timestamp }
        case .top: return posts.sorted { ($0.likeCount + $0.commentCount * 2 + $0.repostCount * 3) > ($1.likeCount + $1.commentCount * 2 + $1.repostCount * 3) }
        }
    }

    private var postCountLabel: String {
        let count = posts.count
        if count == 1 { return "1 post" }
        return "\(count) posts"
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let userId = (try? AuthService.shared.currentUserId()) ?? ""
            let rawPosts = try await SocialService.shared.searchPosts(query: "#\(normalizedTag)", limit: 50)
            let postIds = rawPosts.map { $0.id }
            let likedIds = (try? await SocialService.shared.fetchLikedPostIds(userId: userId, postIds: postIds)) ?? []
            let commentCounts = (try? await SocialService.shared.fetchCommentCounts(postIds: postIds)) ?? [:]

            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let mapped: [FeedPost] = rawPosts.compactMap { sp in
                let text = sp.text_content ?? ""
                let hashtagsInText = Set(RichTextParser.extractHashtags(text))
                let tagLower = normalizedTag
                let hasTagField = (sp.tags ?? []).contains(where: { $0.lowercased() == tagLower || $0.lowercased().replacingOccurrences(of: " ", with: "-") == tagLower })
                let hasInline = hashtagsInText.contains(tagLower)
                guard hasTagField || hasInline else { return nil }

                let user = SocialService.shared.socialUserFromAuthor(sp.profiles)
                var mediaItems: [FeedMediaItem] = (sp.media_urls ?? []).map { FeedMediaItem(type: .photo, imageURL: $0) }
                if let audio = sp.audio_url, !audio.isEmpty {
                    mediaItems.append(FeedMediaItem(type: .voice, imageURL: audio, voiceDuration: sp.audio_duration ?? 0))
                }
                let feedTags = (sp.tags ?? []).compactMap { FeedTag(rawValue: $0) }

                return FeedPost(
                    id: UUID(uuidString: sp.id) ?? UUID(),
                    user: user,
                    timestamp: SocialService.shared.parseDate(sp.created_at),
                    textContent: text,
                    media: mediaItems,
                    likeCount: sp.high_five_count ?? 0,
                    isLiked: likedIds.contains(sp.id),
                    comments: [],
                    commentCount: commentCounts[sp.id] ?? 0,
                    repostCount: sp.repost_count ?? 0,
                    isReposted: false,
                    tags: feedTags,
                    isFollowing: false,
                    supabaseId: sp.id,
                    editedAt: sp.edited_at.flatMap { iso.date(from: $0) }
                )
            }

            let hidden = LocalModerationStore.shared
            posts = mapped.filter { post in
                !hidden.isPostHidden(
                    postId: post.supabaseId ?? post.id.uuidString.lowercased(),
                    userId: post.user.id.uuidString.lowercased(),
                    tags: post.tags.map { $0.rawValue.lowercased() } + RichTextParser.extractHashtags(post.textContent)
                )
            }
            for p in posts { socialViewModel.ensurePostInFeed(p) }
        } catch {
            errorMessage = error.localizedDescription
            posts = []
        }
        isLoading = false
    }
}

nonisolated struct HashtagDestination: Hashable, Sendable {
    let tag: String
}
