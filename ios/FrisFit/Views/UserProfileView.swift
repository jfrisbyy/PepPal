import SwiftUI

struct UserProfileView: View {
    let user: SocialUser
    let viewModel: ProfileViewModel

    @State private var selectedTab: UserProfileTab = .posts
    @State private var isFollowing: Bool = false
    @State private var friendStatus: FriendRequestStatus = .none
    @State private var friendRequestId: String?
    @State private var followBounce: Int = 0
    @State private var friendBounce: Int = 0
    @State private var followerCount: Int = 0
    @State private var followingCount: Int = 0
    @State private var isLoadingRelationship: Bool = true
    @State private var userPosts: [UserPost] = []
    @State private var isLoadingPosts: Bool = true
    @State private var showDeleteConfirm: Bool = false
    @State private var showReportConfirm: Bool = false
    @State private var pendingDeletePost: UserPost?
    @State private var selectedHashtag: String?
    @Environment(\.dismiss) private var dismiss

    private let messagingService = MessagingService.shared
    private let socialService = SocialService.shared
    private let likeManager = LikeManager.shared

    enum UserProfileTab: String, CaseIterable {
        case posts = "Posts"
        case about = "About"
    }



    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                bannerHeader
                profileInfo
                    .padding(.horizontal, 16)
                tabSection
                    .padding(.top, 20)
            }
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: FollowListDestination.self) { destination in
            FollowListView(destination: destination, profileViewModel: viewModel)
        }
        .navigationDestination(item: Binding(get: { selectedHashtag.map(HashtagDestination.init) }, set: { selectedHashtag = $0?.tag })) { dest in
            HashtagFeedView(tag: dest.tag)
        }
        .alert("Delete Post?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { pendingDeletePost = nil }
            Button("Delete", role: .destructive) {
                if let post = pendingDeletePost {
                    deletePost(post)
                }
                pendingDeletePost = nil
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Report Post?", isPresented: $showReportConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Report", role: .destructive) {}
        } message: {
            Text("This post will be flagged for review.")
        }
        .task {
            await loadRelationshipData()
            await loadUserPosts()
        }
    }

    private func isOwnPost(_ post: UserPost) -> Bool {
        guard let userId = try? AuthService.shared.currentUserId() else { return false }
        return post.authorId.uuidString.lowercased() == userId.lowercased()
    }

    private func deletePost(_ post: UserPost) {
        let supabaseId = post.id.uuidString.lowercased()
        Task {
            do {
                try await SocialService.shared.deletePost(postId: supabaseId)
                await loadUserPosts()
            } catch {}
        }
    }

    private func loadUserPosts() async {
        isLoadingPosts = true
        do {
            let currentUserId = try AuthService.shared.currentUserId()
            let targetUserId = user.id.uuidString
            let supabasePosts = try await socialService.fetchUserPosts(userId: targetUserId)
            let postIds = supabasePosts.map { $0.id }
            let likedIds = try await socialService.fetchLikedPostIds(userId: currentUserId, postIds: postIds)

            var counts: [String: Int] = [:]
            for sp in supabasePosts {
                counts[sp.id] = sp.high_five_count ?? 0
            }
            likeManager.bulkSetState(likedIds: likedIds, counts: counts)

            userPosts = supabasePosts.map { sp in
                UserPost(
                    id: UUID(uuidString: sp.id) ?? UUID(),
                    authorId: UUID(uuidString: sp.user_id) ?? UUID(),
                    content: sp.text_content ?? "",
                    timestamp: socialService.parseDate(sp.created_at),
                    likeCount: likeManager.likeCount(postId: sp.id, fallback: sp.high_five_count ?? 0),
                    isLiked: likeManager.isLiked(postId: sp.id),
                    commentCount: 0,
                    mediaUrls: sp.media_urls ?? [],
                    audioUrl: sp.audio_url,
                    audioDuration: sp.audio_duration
                )
            }
        } catch {
            userPosts = []
        }
        isLoadingPosts = false
    }

    private func loadRelationshipData() async {
        do {
            let userId = try AuthService.shared.currentUserId()
            let targetUserId = user.id.uuidString

            async let followCheck = messagingService.isFollowing(followerId: userId, followingId: targetUserId)
            async let friendCheck = messagingService.fetchFriendStatus(userId: userId, otherUserId: targetUserId)
            async let followers = messagingService.fetchFollowers(userId: targetUserId)
            async let following = messagingService.fetchFollowing(userId: targetUserId)

            let (isFollow, friendResult, followerIds, followingIds) = try await (followCheck, friendCheck, followers, following)

            isFollowing = isFollow
            friendStatus = friendResult.status
            friendRequestId = friendResult.requestId
            followerCount = followerIds.count
            followingCount = followingIds.count
            isLoadingRelationship = false
        } catch {
            isLoadingRelationship = false
        }
    }

    private var bannerHeader: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    user.avatarColor.opacity(0.18),
                    PepTheme.background
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 120)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(PepTheme.separatorColor)
                    .frame(height: 0.5)
            }

            Circle()
                .fill(PepTheme.background)
                .frame(width: 88, height: 88)
                .overlay {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [user.avatarColor.opacity(0.8), user.avatarColor.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .overlay {
                            if let urlString = user.avatarURL,
                               let url = URL(string: urlString),
                               !urlString.isEmpty {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    default:
                                        Text(user.avatarInitial)
                                            .font(.system(size: 28, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                                .allowsHitTesting(false)
                            } else {
                                Text(user.avatarInitial)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                        }
                        .clipShape(Circle())
                }
                .offset(x: 16, y: 44)
        }
        .padding(.bottom, 48)
    }

    private var profileInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.name)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)

                    Text("@\(user.username)")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textSecondary)
                }

                Spacer()

                if !isLoadingRelationship {
                    HStack(spacing: 8) {
                        Button {
                            let wasFollowing = isFollowing
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                isFollowing.toggle()
                                followerCount += isFollowing ? 1 : -1
                                followBounce += 1
                            }

                            Task {
                                do {
                                    if wasFollowing {
                                        try await messagingService.unfollowUser(
                                            followerId: AuthService.shared.currentUserId(),
                                            followingId: user.id.uuidString
                                        )
                                    } else {
                                        try await messagingService.followUser(
                                            followerId: AuthService.shared.currentUserId(),
                                            followingId: user.id.uuidString
                                        )
                                    }
                                } catch {
                                    isFollowing = wasFollowing
                                    followerCount += wasFollowing ? 1 : -1
                                }
                            }
                        } label: {
                            Text(isFollowing ? "Following" : "Follow")
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(isFollowing ? PepTheme.textPrimary : .black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(isFollowing ? PepTheme.elevated : PepTheme.teal)
                                .clipShape(.capsule)
                                .overlay(
                                    Capsule().strokeBorder(
                                        isFollowing ? PepTheme.glassBorderTop : .clear,
                                        lineWidth: 0.5
                                    )
                                )
                        }
                        .sensoryFeedback(.impact(weight: .medium), trigger: followBounce)

                        Button {
                            guard friendStatus == .none else { return }
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                friendStatus = .pending
                                friendBounce += 1
                            }

                            Task {
                                do {
                                    try await messagingService.sendFriendRequest(
                                        senderId: AuthService.shared.currentUserId(),
                                        receiverId: user.id.uuidString
                                    )
                                } catch {
                                    friendStatus = .none
                                }
                            }
                        } label: {
                            Image(systemName: friendIcon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(friendIconColor)
                                .frame(width: 34, height: 34)
                                .background(PepTheme.elevated)
                                .clipShape(Circle())
                                .overlay(
                                    Circle().strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                                )
                        }
                        .sensoryFeedback(.impact(weight: .light), trigger: friendBounce)
                        .disabled(friendStatus == .accepted)
                    }
                }
            }

            if let program = user.activeProgramName {
                Text("RUNNING — \(program.uppercased())")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(PepTheme.textSecondary)
                    .padding(.top, 6)
            }

            HStack(spacing: 20) {
                NavigationLink(value: FollowListDestination.following(userId: user.id.uuidString, username: user.name)) {
                    HStack(spacing: 4) {
                        Text("\(followingCount)")
                            .font(.system(.subheadline, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("Following")
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
                .buttonStyle(.plain)

                NavigationLink(value: FollowListDestination.followers(userId: user.id.uuidString, username: user.name)) {
                    HStack(spacing: 4) {
                        Text("\(followerCount)")
                            .font(.system(.subheadline, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("Followers")
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)

            friendStatusBadge
        }
    }

    private var friendIcon: String {
        switch friendStatus {
        case .none: "person.badge.plus"
        case .pending: "clock"
        case .accepted: "person.fill.checkmark"
        }
    }

    private var friendIconColor: Color {
        switch friendStatus {
        case .none: PepTheme.textPrimary
        case .pending: PepTheme.amber
        case .accepted: PepTheme.teal
        }
    }

    @ViewBuilder
    private var friendStatusBadge: some View {
        switch friendStatus {
        case .none:
            EmptyView()
        case .pending:
            Text("REQUEST PENDING")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(PepTheme.amber.opacity(0.9))
                .padding(.top, 6)
        case .accepted:
            Text("FRIENDS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(PepTheme.textSecondary)
                .padding(.top, 6)
        }
    }

    private var tabSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(UserProfileTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Text(tab.rawValue)
                                .font(.system(.subheadline, weight: selectedTab == tab ? .bold : .medium))
                                .foregroundStyle(selectedTab == tab ? PepTheme.textPrimary : PepTheme.textSecondary)
                                .frame(maxWidth: .infinity)

                            Rectangle()
                                .fill(selectedTab == tab ? PepTheme.teal : .clear)
                                .frame(height: 2)
                                .clipShape(.capsule)
                        }
                    }
                    .sensoryFeedback(.selection, trigger: selectedTab)
                }
            }
            .padding(.horizontal, 16)

            Divider()
                .overlay(PepTheme.separatorColor)

            switch selectedTab {
            case .posts:
                postsContent
            case .about:
                aboutContent
            }
        }
    }

    private var postsContent: some View {
        LazyVStack(spacing: 0) {
            if isLoadingPosts {
                ProgressView()
                    .padding(.vertical, 32)
                    .frame(maxWidth: .infinity)
            } else if userPosts.isEmpty {
                emptyState(icon: "text.bubble", title: "No Posts Yet", message: "\(user.name) hasn't posted anything yet.")
            } else {
                ForEach(userPosts) { post in
                    NavigationLink(value: feedPostFromUserPost(post)) {
                        userPostRow(post)
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(PepTheme.separatorColor)
                }
            }
        }
    }

    private func userPostRow(_ post: UserPost) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [user.avatarColor.opacity(0.8), user.avatarColor.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .overlay {
                    if let urlString = user.avatarURL,
                       let url = URL(string: urlString),
                       !urlString.isEmpty {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().aspectRatio(contentMode: .fill)
                            default:
                                Text(user.avatarInitial)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .allowsHitTesting(false)
                    } else {
                        Text(user.avatarInitial)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(user.name)
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)

                    Text("@\(user.username)")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)

                    Text("·")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)

                    Text(post.timestamp.formattedPostDate())
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)

                    Spacer()

                    Menu {
                        if isOwnPost(post) {
                            Button(role: .destructive) {
                                pendingDeletePost = post
                                showDeleteConfirm = true
                            } label: {
                                Label("Delete Post", systemImage: "trash")
                            }
                        }
                        Button {
                            showReportConfirm = true
                        } label: {
                            Label("Report", systemImage: "flag")
                        }
                        Button {
                            UIPasteboard.general.string = post.content
                        } label: {
                            Label("Copy Text", systemImage: "doc.on.doc")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14))
                            .foregroundStyle(PepTheme.textSecondary)
                            .frame(width: 32, height: 32)
                    }
                }

                if !post.content.isEmpty {
                    RichText(
                        text: post.content,
                        font: .subheadline,
                        onHashtag: { tag in selectedHashtag = tag }
                    )
                    .lineSpacing(3)
                }

                if !post.mediaUrls.isEmpty {
                    ProfilePostMediaGrid(mediaUrls: post.mediaUrls)
                }

                if post.audioUrl != nil {
                    ProfilePostAudioBadge(duration: post.audioDuration ?? 0)
                }

                if let attachment = post.workoutAttachment {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(attachment.workoutName)
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)

                        HStack(spacing: 14) {
                            HStack(spacing: 3) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                                Text("\(attachment.duration)m")
                                    .font(.caption2)
                            }
                            HStack(spacing: 3) {
                                Image(systemName: "dumbbell")
                                    .font(.system(size: 10))
                                Text("\(attachment.exerciseCount)")
                                    .font(.caption2)
                            }
                        }
                        .foregroundStyle(PepTheme.textSecondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PepTheme.elevated.opacity(0.6))
                    .clipShape(.rect(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                    )
                }

                HStack(spacing: 24) {
                    let pid = post.id.uuidString.lowercased()
                    HStack(spacing: 5) {
                        Image(systemName: likeManager.isLiked(postId: pid) ? "heart.fill" : "heart")
                            .font(.system(size: 14))
                        Text("\(likeManager.likeCount(postId: pid, fallback: post.likeCount))")
                            .font(.caption)
                    }
                    .foregroundStyle(likeManager.isLiked(postId: pid) ? .red : PepTheme.textSecondary)

                    HStack(spacing: 5) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 14))
                        Text("\(post.commentCount)")
                            .font(.caption)
                    }
                    .foregroundStyle(PepTheme.textSecondary)

                    Spacer()
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var aboutContent: some View {
        VStack(spacing: 0) {
            SectionEyebrow("About", number: "01", accent: PepTheme.teal)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            if let program = user.activeProgramName {
                aboutRow(label: "Active Program", value: program)
            }
        }
    }

    private func aboutRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(PepTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(PepTheme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(PepTheme.separatorColor).frame(height: 0.5)
        }
    }

    private func feedPostFromUserPost(_ post: UserPost) -> FeedPost {
        let socialUser = SocialUser(
            id: user.id,
            name: user.name,
            username: user.username,
            avatarInitial: user.avatarInitial,
            avatarColor: user.avatarColor,
            avatarURL: user.avatarURL,
            activeProgramName: user.activeProgramName,
            streak: user.streak
        )
        let mediaItems: [FeedMediaItem] = post.mediaUrls.map { url in
            FeedMediaItem(type: .photo, imageURL: url)
        }
        let pid = post.id.uuidString.lowercased()
        return FeedPost(
            id: post.id,
            user: socialUser,
            timestamp: post.timestamp,
            textContent: post.content,
            media: mediaItems,
            likeCount: likeManager.likeCount(postId: pid, fallback: post.likeCount),
            isLiked: likeManager.isLiked(postId: pid),
            supabaseId: pid
        )
    }

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
            Text(title)
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 48)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }
}
