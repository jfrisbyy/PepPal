import SwiftUI

struct CommunityDiscoverView: View {
    @State private var viewModel = CommunityDiscoverViewModel()
    @State private var selectedUser: SocialUser?
    @State private var selectedPost: FeedPost?
    @State private var selectedHashtag: String?
    @State private var socialViewModel = SocialViewModel()
    @State private var commentPost: FeedPost?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if let ts = viewModel.lastRefreshed {
                    HStack {
                        Spacer()
                        Text("Refreshed \(timeAgo(ts))")
                            .font(.caption2)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                }

                trendingPostsSection
                trendingTagsSection
                suggestedPeopleSection
                popularGroupsSection
                Color.clear.frame(height: 32)
            }
            .padding(.top, 8)
        }
        .appBackground()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await viewModel.refresh() }
        .task { await viewModel.loadIfNeeded() }
        .navigationDestination(item: $selectedUser) { user in
            UserProfileView(user: user, viewModel: ProfileViewModel())
        }
        .navigationDestination(item: $selectedPost) { post in
            PostDetailView(post: post, viewModel: socialViewModel)
        }
        .navigationDestination(item: Binding(get: { selectedHashtag.map(HashtagDestination.init) }, set: { selectedHashtag = $0?.tag })) { dest in
            HashtagFeedView(tag: dest.tag)
        }
        .sheet(item: $commentPost) { post in
            FeedCommentsSheet(post: post, viewModel: socialViewModel)
        }
    }

    // MARK: - Trending Posts

    private var trendingPostsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionEyebrow("Trending", number: "01", accent: PepTheme.teal)
                .padding(.horizontal)

            if viewModel.isLoadingPosts && viewModel.trendingPosts.isEmpty {
                ProgressView().tint(PepTheme.teal).frame(maxWidth: .infinity).padding(.vertical, 40)
            } else if viewModel.trendingPosts.isEmpty {
                emptyRow("No trending posts yet", icon: "flame.fill")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(viewModel.trendingPosts.prefix(8)) { post in
                            TrendingPostCard(post: post) {
                                socialViewModel.ensurePostInFeed(post)
                                selectedPost = post
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .contentMargins(.horizontal, 0)
            }
        }
    }

    // MARK: - Trending Tags

    private var trendingTagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionEyebrow("Tags", number: "02", accent: PepTheme.teal)
                .padding(.horizontal)

            if viewModel.trendingTags.isEmpty {
                emptyRow("No tags yet", icon: "number.circle")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(viewModel.trendingTags.enumerated()), id: \.element.tag) { idx, item in
                            Button { selectedHashtag = item.tag } label: {
                                TrendingTagChip(item: item, rank: idx + 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .contentMargins(.horizontal, 0)
            }
        }
    }

    // MARK: - Suggested People

    private var suggestedPeopleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionEyebrow("People", number: "03", accent: PepTheme.violet)
                .padding(.horizontal)

            if viewModel.suggestedUsers.isEmpty {
                emptyRow("No suggestions right now", icon: "person.badge.plus")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.suggestedUsers) { user in
                            SuggestedUserCard(
                                user: user,
                                isFollowing: viewModel.isFollowing(user.id.uuidString),
                                isPending: viewModel.isPending(user.id.uuidString),
                                onTap: { selectedUser = user },
                                onFollow: {
                                    Task { await viewModel.toggleFollow(user) }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .contentMargins(.horizontal, 0)
            }
        }
    }

    // MARK: - Popular Groups

    private var popularGroupsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionEyebrow("Groups", number: "04", accent: PepTheme.amber)
                .padding(.horizontal)

            if viewModel.popularGroups.isEmpty {
                emptyRow("No groups yet", icon: "person.3")
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.popularGroups) { group in
                        PopularGroupRow(group: group)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Helpers

    private func emptyRow(_ title: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
            Text(title)
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .padding(.horizontal)
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
}

// MARK: - Cards

private struct TrendingPostCard: View {
    let post: FeedPost
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(post.user.avatarColor.opacity(0.25))
                        .frame(width: 28, height: 28)
                        .overlay {
                            Text(post.user.avatarInitial)
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .foregroundStyle(post.user.avatarColor)
                        }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(post.user.name)
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                            .lineLimit(1)
                        Text("@\(post.user.username)")
                            .font(.system(size: 10))
                            .foregroundStyle(PepTheme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }

                if !post.textContent.isEmpty {
                    Text(post.textContent)
                        .font(.system(.subheadline))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                }

                if let first = post.photoMedia.first, let urlString = first.imageURL, let url = URL(string: urlString) {
                    Color(.secondarySystemBackground)
                        .frame(height: 110)
                        .overlay {
                            AsyncImage(url: url) { phase in
                                if let img = phase.image {
                                    img.resizable().aspectRatio(contentMode: .fill)
                                }
                            }
                            .allowsHitTesting(false)
                        }
                        .clipShape(.rect(cornerRadius: 10))
                }

                Spacer(minLength: 0)

                HStack(spacing: 14) {
                    Label("\(post.likeCount)", systemImage: "heart")
                    Label("\(post.commentCount)", systemImage: "bubble.left")
                    Label("\(post.repostCount)", systemImage: "arrow.2.squarepath")
                }
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(14)
            .frame(width: 260, height: 240, alignment: .topLeading)
            .background(PepTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct TrendingTagChip: View {
    let item: TrendingTagItem
    let rank: Int

    var body: some View {
        HStack(spacing: 12) {
            Text(String(format: "%02d", rank))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(PepTheme.textSecondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("#\(item.tag)")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)
                Text("\(item.postCount) post\(item.postCount == 1 ? "" : "s")")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            MiniSpark(values: item.sparkline)
                .frame(width: 38, height: 20)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(PepTheme.cardSurface, in: .rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
        )
    }
}

private struct MiniSpark: View {
    let values: [Double]
    var body: some View {
        GeometryReader { geo in
            let maxVal = max(values.max() ?? 1, 1)
            let step = geo.size.width / CGFloat(max(values.count - 1, 1))
            Path { path in
                for (i, v) in values.enumerated() {
                    let x = CGFloat(i) * step
                    let y = geo.size.height - (CGFloat(v / maxVal) * geo.size.height)
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(PepTheme.textSecondary.opacity(0.7), style: .init(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
        }
    }
}

private struct SuggestedUserCard: View {
    let user: SocialUser
    let isFollowing: Bool
    let isPending: Bool
    let onTap: () -> Void
    let onFollow: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Button(action: onTap) {
                Circle()
                    .fill(user.avatarColor.opacity(0.25))
                    .frame(width: 64, height: 64)
                    .overlay {
                        Text(user.avatarInitial)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(user.avatarColor)
                    }
            }
            .buttonStyle(.plain)

            VStack(spacing: 2) {
                Text(user.name)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)
                Text("@\(user.username)")
                    .font(.system(size: 11))
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineLimit(1)
            }

            Button(action: onFollow) {
                Text((isFollowing ? "FOLLOWING" : (isPending ? "REQUESTED" : "FOLLOW")))
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(isFollowing ? PepTheme.textSecondary : PepTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.clear))
                    .overlay(
                        Capsule().strokeBorder(
                            isFollowing ? PepTheme.separatorColor : PepTheme.textPrimary.opacity(0.6),
                            lineWidth: 0.5
                        )
                    )
            }
            .sensoryFeedback(.selection, trigger: isFollowing)
        }
        .frame(width: 150)
        .padding(14)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
        )
    }
}

private struct PopularGroupRow: View {
    let group: FitGroup

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.clear)
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
                    )
                Text(String(group.name.prefix(1)).uppercased())
                    .font(.system(.title3, design: .serif, weight: .regular))
                    .foregroundStyle(PepTheme.textPrimary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(group.name)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)
                Text("\(group.memberCount) members · \(group.privacy.rawValue)")
                    .font(.system(size: 11))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            Text("VIEW")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(PepTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .overlay(
                    Capsule().strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
                )
        }
        .padding(12)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
    }
}

// MARK: - ViewModel

nonisolated struct TrendingTagItem: Identifiable, Hashable, Sendable {
    var id: String { tag }
    let tag: String
    let postCount: Int
    let sparkline: [Double]
}

@Observable
final class CommunityDiscoverViewModel {
    var trendingPosts: [FeedPost] = []
    var trendingTags: [TrendingTagItem] = []
    var suggestedUsers: [SocialUser] = []
    var popularGroups: [FitGroup] = []
    var isLoadingPosts: Bool = false
    var lastRefreshed: Date?

    private var followingIds: Set<String> = []
    private var pendingIds: Set<String> = []
    private var hasLoaded: Bool = false

    func loadIfNeeded() async {
        if !hasLoaded { await refresh() }
    }

    func refresh() async {
        async let posts: () = loadTrendingPosts()
        async let tags: () = loadTrendingTags()
        async let users: () = loadSuggestedUsers()
        async let groups: () = loadPopularGroups()
        _ = await (posts, tags, users, groups)
        lastRefreshed = Date()
        hasLoaded = true
    }

    func isFollowing(_ userId: String) -> Bool { followingIds.contains(userId.lowercased()) }
    func isPending(_ userId: String) -> Bool { pendingIds.contains(userId.lowercased()) }

    func toggleFollow(_ user: SocialUser) async {
        let id = user.id.uuidString.lowercased()
        do {
            let myId = try AuthService.shared.currentUserId()
            if followingIds.contains(id) {
                try await MessagingService.shared.unfollowUser(followerId: myId, followingId: id)
                followingIds.remove(id)
            } else {
                try await MessagingService.shared.followUser(followerId: myId, followingId: id)
                followingIds.insert(id)
            }
        } catch {}
    }

    private func loadTrendingPosts() async {
        isLoadingPosts = true
        defer { isLoadingPosts = false }
        do {
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let page = try await SocialService.shared.fetchPostsPage(before: nil, pageSize: 40)
            let userId = (try? AuthService.shared.currentUserId()) ?? ""
            let myFollows = (try? await MessagingService.shared.fetchFollowing(userId: userId)) ?? []
            let followSet = Set(myFollows.map { $0.lowercased() })
            followingIds.formUnion(followSet)

            let recent = page.filter { SocialService.shared.parseDate($0.created_at) >= weekAgo }
            let scored = recent.map { sp -> (SupabaseFeedPostWithProfile, Int) in
                let score = (sp.high_five_count ?? 0) + (sp.repost_count ?? 0) * 3
                return (sp, score)
            }.sorted { $0.1 > $1.1 }

            let hidden = LocalModerationStore.shared
            let mapped: [FeedPost] = scored.compactMap { (sp, _) in
                let uid = sp.user_id.lowercased()
                if followSet.contains(uid) { return nil }
                if uid == userId.lowercased() { return nil }
                let text = sp.text_content ?? ""
                let hashtagsInText = RichTextParser.extractHashtags(text)
                let tagStrings = (sp.tags ?? []).map { $0.lowercased() } + hashtagsInText
                if hidden.isPostHidden(postId: sp.id, userId: uid, tags: tagStrings) { return nil }

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
                    isLiked: false,
                    comments: [],
                    commentCount: 0,
                    repostCount: sp.repost_count ?? 0,
                    isReposted: false,
                    tags: feedTags,
                    isFollowing: false,
                    supabaseId: sp.id
                )
            }
            trendingPosts = Array(mapped.prefix(10))
        } catch {
            trendingPosts = []
        }
    }

    private func loadTrendingTags() async {
        do {
            let page = try await SocialService.shared.fetchPostsPage(before: nil, pageSize: 80)
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            var counts: [String: Int] = [:]
            var buckets: [String: [Double]] = [:]
            for sp in page {
                let date = SocialService.shared.parseDate(sp.created_at)
                guard date >= weekAgo else { continue }
                let daysAgo = Int(Date().timeIntervalSince(date) / 86400)
                let bucketIdx = max(0, min(6, 6 - daysAgo))

                var allTags = Set((sp.tags ?? []).map { $0.lowercased() })
                for h in RichTextParser.extractHashtags(sp.text_content ?? "") { allTags.insert(h) }
                for tag in allTags {
                    counts[tag, default: 0] += 1
                    var arr = buckets[tag] ?? Array(repeating: 0.0, count: 7)
                    arr[bucketIdx] += 1
                    buckets[tag] = arr
                }
            }
            let items = counts.map { (tag, count) in
                TrendingTagItem(tag: tag, postCount: count, sparkline: buckets[tag] ?? Array(repeating: 0, count: 7))
            }
            .filter { !LocalModerationStore.shared.isTagMuted($0.tag) }
            .sorted { $0.postCount > $1.postCount }
            trendingTags = Array(items.prefix(12))
        } catch {
            trendingTags = []
        }
    }

    private func loadSuggestedUsers() async {
        do {
            let userId = try AuthService.shared.currentUserId()
            let myFollows = try await MessagingService.shared.fetchFollowing(userId: userId)
            followingIds = Set(myFollows.map { $0.lowercased() })
            let sent = (try? await MessagingService.shared.fetchSentRequests(userId: userId)) ?? []
            pendingIds = Set(sent.map { $0.receiver_id.lowercased() })

            let page = try await SocialService.shared.fetchPostsPage(before: nil, pageSize: 60)
            let moderation = LocalModerationStore.shared
            var seen = Set<String>()
            var users: [SocialUser] = []
            for sp in page {
                let uid = sp.user_id.lowercased()
                if uid == userId.lowercased() { continue }
                if followingIds.contains(uid) { continue }
                if moderation.isUserMuted(uid) { continue }
                if seen.contains(uid) { continue }
                seen.insert(uid)
                users.append(SocialService.shared.socialUserFromAuthor(sp.profiles))
                if users.count >= 10 { break }
            }
            suggestedUsers = users
        } catch {
            suggestedUsers = []
        }
    }

    private func loadPopularGroups() async {
        let groups = GroupsViewModel().discoverGroups
        popularGroups = Array(groups.prefix(6))
    }
}
