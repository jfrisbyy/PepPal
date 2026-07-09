import SwiftUI

struct SocialView: View {
    @State private var viewModel = SocialViewModel()
    private let messagesViewModel = MessagesViewModel.shared
    @State private var groupsViewModel = GroupsViewModel()
    @State private var profileViewModel = ProfileViewModel()
    @State private var notificationsViewModel = NotificationsViewModel()
    @State private var commentPost: WorkoutPost?
    @State private var commentFeedPost: FeedPost?
    @State private var selectedPost: FeedPost?
    @State private var editingPost: FeedPost?
    @State private var isLoading: Bool = true
    @State private var showComposer: Bool = false
    @State private var selectedHashtag: String?
    @State private var selectedUserForMention: SocialUser?
    @State private var scrollOffset: CGFloat = 0
    @State private var showCommunityDiscover: Bool = false
    @State private var showNotifications: Bool = false
    @State private var showMessages: Bool = false
    @State private var showSettings: Bool = false
    @Namespace private var communityPickerNS

    var body: some View {
        Group {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if viewModel.communityMode == .feed {
                        feedView
                    } else {
                        FriendsStatsView(topHeader: {
                            communityModePicker
                                .padding(.horizontal)
                                .padding(.top, 4)
                                .padding(.bottom, 10)
                        })
                        .transition(.opacity)
                    }
                }

                if viewModel.communityMode == .feed && viewModel.pendingIncomingCount > 0 {
                    VStack {
                        newPostsPill
                            .padding(.top, 8)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.pendingIncomingCount)
                }

                if viewModel.communityMode == .feed {
                    composeButton
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .topTrailing) {
                communityFloatingPill
                    .padding(.trailing, 16)
                    .padding(.top, 8)
            }
            .navigationDestination(isPresented: $showCommunityDiscover) { CommunityDiscoverView() }
            .navigationDestination(isPresented: $showNotifications) { NotificationsView() }
            .navigationDestination(isPresented: $showMessages) { DirectMessagesView(viewModel: messagesViewModel) }
            .sheet(isPresented: $showSettings) {
                NavigationStack { StatSharingSettingsView() }
            }
            .sheet(item: $commentPost) { post in
                CommentsSheet(post: post) { text in
                    viewModel.addComment(to: post.id, text: text)
                    if let updated = viewModel.posts.first(where: { $0.id == post.id }) {
                        commentPost = updated
                    }
                }
            }
            .sheet(item: $commentFeedPost) { post in
                FeedCommentsSheet(post: post, viewModel: viewModel)
            }
            .navigationDestination(item: $selectedPost) { post in
                PostDetailView(post: post, viewModel: viewModel)
            }
            .sheet(isPresented: $showComposer) {
                PostComposerView(socialViewModel: viewModel)
            }
            .sheet(item: $editingPost) { post in
                EditPostSheet(post: post, viewModel: viewModel)
            }
            .navigationDestination(for: SocialUser.self) { user in
                UserProfileView(user: user, viewModel: profileViewModel)
            }
            .navigationDestination(item: Binding(get: { selectedHashtag.map(HashtagDestination.init) }, set: { selectedHashtag = $0?.tag })) { dest in
                HashtagFeedView(tag: dest.tag)
            }
            .navigationDestination(item: $selectedUserForMention) { user in
                UserProfileView(user: user, viewModel: profileViewModel)
            }
            .onChange(of: viewModel.isLoadingFeed) { _, newValue in
                if !newValue && isLoading {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        isLoading = false
                    }
                }
            }
            .task {
                await viewModel.initialLoad()
                if !viewModel.isLoadingFeed && isLoading {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        isLoading = false
                    }
                }
                await notificationsViewModel.refreshUnreadCount()
            }
        }
    }

    // MARK: - Floating Nav Pill

    private var communityFloatingPill: some View {
        FloatingNavPill(scrollOffset: scrollOffset) {
            FloatingPillIconButton(systemName: "safari") {
                showCommunityDiscover = true
            }
            FloatingPillDivider()
            FloatingPillIconButton(
                systemName: notificationsViewModel.unreadCount > 0 ? "bell.badge.fill" : "bell",
                tint: notificationsViewModel.unreadCount > 0 ? PepTheme.teal : PepTheme.textPrimary,
                badge: notificationsViewModel.unreadCount > 0
            ) {
                showNotifications = true
            }
            FloatingPillDivider()
            FloatingPillIconButton(
                systemName: "bubble.left",
                badge: messagesViewModel.totalUnread > 0,
                badgeColor: PepTheme.teal
            ) {
                showMessages = true
            }
            FloatingPillDivider()
            FloatingPillIconButton(systemName: "gearshape") {
                showSettings = true
            }
        }
    }

    private var newPostsPill: some View {
        Button {
            Task { await viewModel.loadNewPosts() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 9, weight: .semibold))
                Text("\(viewModel.pendingIncomingCount) NEW")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.4)
            }
            .foregroundStyle(PepTheme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(PepTheme.cardSurface, in: .capsule)
            .overlay(
                Capsule().strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
            )
        }
        .sensoryFeedback(.impact(weight: .light), trigger: viewModel.pendingIncomingCount)
    }

    private func blockUser(_ userId: String) async {
        do {
            let myId = try AuthService.shared.currentUserId()
            try await ModerationService.shared.block(blockerId: myId, blockedId: userId)
            await viewModel.refreshBlockedUserIds()
        } catch {}
    }

    private func openMention(_ handle: String) async {
        do {
            let myId = (try? AuthService.shared.currentUserId()) ?? ""
            let profiles = try await MessagingService.shared.searchUsers(query: handle, excludeUserId: myId)
            if let match = profiles.first(where: { ($0.username ?? "").caseInsensitiveCompare(handle) == .orderedSame }) ?? profiles.first {
                let user = MessagingService.shared.socialUserFromAuthor(match)
                selectedUserForMention = user
            }
        } catch {}
    }

    private var composeButton: some View {
        Button {
            showComposer = true
        } label: {
            ZStack {
                Circle()
                    .fill(PepTheme.cardSurface)
                    .frame(width: 52, height: 52)
                    .overlay(Circle().strokeBorder(PepTheme.separatorColor, lineWidth: 0.5))
                    .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 3)

                Image(systemName: "square.and.pencil")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(PepTheme.textPrimary)
            }
        }
        .buttonStyle(.scale)
        .padding(.trailing, 20)
        .padding(.bottom, 20)
        .sensoryFeedback(.impact(weight: .medium), trigger: showComposer)
        .transition(.scale.combined(with: .opacity))
    }

    private var communityModePicker: some View {
        HStack(spacing: 28) {
            ForEach(CommunityMode.allCases, id: \.self) { mode in
                let isSelected = viewModel.communityMode == mode
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                        viewModel.communityMode = mode
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(mode.rawValue.uppercased())
                            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                            .tracking(2.0)
                            .foregroundStyle(isSelected ? PepTheme.textPrimary : PepTheme.textSecondary.opacity(0.7))
                        ZStack(alignment: .center) {
                            Rectangle()
                                .fill(PepTheme.separatorColor.opacity(0.3))
                                .frame(height: 1)
                            if isSelected {
                                Rectangle()
                                    .fill(PepTheme.textPrimary)
                                    .frame(height: 1.5)
                                    .matchedGeometryEffect(id: "communityPickerSelection", in: communityPickerNS)
                            }
                        }
                        .frame(width: 36)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .sensoryFeedback(.selection, trigger: viewModel.communityMode)
    }

    private var feedView: some View {
        feedScrollView
    }

    private var isSearchActive: Bool {
        !viewModel.postSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var feedScrollView: some View {
        ScrollView {
            VStack(spacing: 0) {
                communityModePicker
                    .padding(.horizontal)
                    .padding(.top, 4)
                    .padding(.bottom, 10)

                if isSearchActive {
                    searchResultsSection
                        .padding(.top, 4)
                        .transition(.opacity)
                }

                feedFilterBar
                    .padding(.top, 4)
                    .padding(.bottom, 8)

                if isLoading {
                    SkeletonFeedView()
                        .padding(.top, 8)
                        .transition(.opacity)
                } else if let error = viewModel.feedError {
                    FeedErrorView(error: error) {
                        Task { await viewModel.refreshFeed() }
                    }
                } else if viewModel.filteredFeedPosts.isEmpty {
                    EmptyStateView(
                        icon: viewModel.feedFilter == .following ? "person.2" : "tag",
                        title: viewModel.feedFilter == .following ? "No Posts from Following" : "No Matching Posts",
                        message: viewModel.feedFilter == .following
                            ? "Follow more people to see their posts here."
                            : "Try selecting different tags to find posts.",
                        actionTitle: viewModel.feedFilter == .following ? "Find Friends" : nil
                    )
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.filteredFeedPosts.enumerated()), id: \.element.id) { idx, post in
                            FeedPostCard(
                                post: post,
                                onLike: {
                                    viewModel.toggleFeedLike(for: post.id)
                                },
                                onComment: {
                                    commentFeedPost = post
                                },
                                onRepost: {
                                    viewModel.toggleRepost(for: post.id)
                                },
                                onTap: {
                                    selectedPost = post
                                },
                                onDelete: {
                                    viewModel.deletePost(post.id)
                                },
                                onEdit: {
                                    editingPost = post
                                },
                                onBlock: {
                                    Task { await blockUser(post.user.id.uuidString) }
                                },
                                onMute: {
                                    // triggers filteredFeedPosts recompute via moderation store
                                },
                                onOpenMention: { handle in
                                    Task { await openMention(handle) }
                                },
                                onOpenHashtag: { tag in
                                    selectedHashtag = tag
                                },
                                onAppear: {
                                    Task { await viewModel.loadMoreIfNeeded(currentPost: post) }
                                },
                                onUserTap: { user in
                                    selectedUserForMention = user
                                }
                            )
                            if idx < viewModel.filteredFeedPosts.count - 1 {
                                ZStack {
                                    Rectangle()
                                        .fill(PepTheme.backgroundElevated.opacity(0.6))
                                        .frame(height: 8)
                                    VStack(spacing: 0) {
                                        Rectangle()
                                            .fill(PepTheme.separatorColor.opacity(0.9))
                                            .frame(height: 0.5)
                                        Spacer(minLength: 0)
                                        Rectangle()
                                            .fill(PepTheme.separatorColor.opacity(0.9))
                                            .frame(height: 0.5)
                                    }
                                    .frame(height: 8)
                                }
                            }
                        }

                        if viewModel.isLoadingMore {
                            HStack {
                                Spacer()
                                ProgressView().tint(PepTheme.teal)
                                Spacer()
                            }
                            .padding(.vertical, 20)
                        } else if !viewModel.hasMorePosts && !viewModel.filteredFeedPosts.isEmpty {
                            Text("You're all caught up")
                                .font(.caption)
                                .foregroundStyle(PepTheme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                        }
                    }
                    .padding(.bottom, 80)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.y
        } action: { _, newValue in
            scrollOffset = newValue
            if scrollOffset < -60 && viewModel.isPostSearchActive {
                searchFieldFocused = false
            }
        }
        .refreshable {
            await viewModel.refreshFeed()
        }
    }

    // MARK: - Search Results

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            hashtagsResultBlock
            peopleResultBlock
            postsEyebrow
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    private var hashtagsResultBlock: some View {
        let tags = viewModel.searchedHashtags
        return VStack(alignment: .leading, spacing: 10) {
            sectionEyebrow("01 \u{2014} HASHTAGS")
            if tags.isEmpty {
                Text("No matching tags")
                    .font(.system(size: 12))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                    .italic()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(tags.enumerated()), id: \.offset) { idx, tag in
                        Button {
                            selectedHashtag = tag
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "number")
                                    .font(.system(size: 13, weight: .light))
                                    .foregroundStyle(PepTheme.textSecondary)
                                    .frame(width: 22)
                                Text("#\(tag)")
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundStyle(PepTheme.textPrimary)
                                Spacer()
                                Text("VIEW")
                                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                                    .tracking(1.4)
                                    .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .light))
                                    .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
                            }
                            .padding(.vertical, 12)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        if idx < tags.count - 1 {
                            Rectangle()
                                .fill(PepTheme.separatorColor.opacity(0.4))
                                .frame(height: 0.5)
                        }
                    }
                }
                .overlay(
                    Rectangle()
                        .fill(PepTheme.separatorColor.opacity(0.4))
                        .frame(height: 0.5),
                    alignment: .top
                )
                .overlay(
                    Rectangle()
                        .fill(PepTheme.separatorColor.opacity(0.4))
                        .frame(height: 0.5),
                    alignment: .bottom
                )
            }
        }
    }

    private var peopleResultBlock: some View {
        let people = viewModel.searchedPeople
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                sectionEyebrow("02 \u{2014} PEOPLE")
                if viewModel.isSearchingPeople {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(PepTheme.textSecondary)
                }
                Spacer()
            }
            if people.isEmpty && !viewModel.isSearchingPeople {
                Text("No people found")
                    .font(.system(size: 12))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                    .italic()
            } else if !people.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(people.prefix(8).enumerated()), id: \.element.id) { idx, user in
                        Button {
                            selectedUserForMention = user
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(user.avatarColor.opacity(0.18))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Text(user.avatarInitial)
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                            .foregroundStyle(user.avatarColor)
                                    )
                                    .overlay(
                                        Circle().strokeBorder(PepTheme.separatorColor.opacity(0.5), lineWidth: 0.5)
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.name)
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundStyle(PepTheme.textPrimary)
                                    Text("@\(user.username)")
                                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                                        .tracking(0.4)
                                        .foregroundStyle(PepTheme.textSecondary.opacity(0.8))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .light))
                                    .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
                            }
                            .padding(.vertical, 10)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        if idx < min(people.count, 8) - 1 {
                            Rectangle()
                                .fill(PepTheme.separatorColor.opacity(0.4))
                                .frame(height: 0.5)
                        }
                    }
                }
                .overlay(
                    Rectangle()
                        .fill(PepTheme.separatorColor.opacity(0.4))
                        .frame(height: 0.5),
                    alignment: .top
                )
                .overlay(
                    Rectangle()
                        .fill(PepTheme.separatorColor.opacity(0.4))
                        .frame(height: 0.5),
                    alignment: .bottom
                )
            }
        }
    }

    private var postsEyebrow: some View {
        sectionEyebrow("03 \u{2014} POSTS")
    }

    private func sectionEyebrow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .regular, design: .monospaced))
            .tracking(1.8)
            .foregroundStyle(PepTheme.textSecondary.opacity(0.75))
    }

    @FocusState private var searchFieldFocused: Bool

    @ViewBuilder
    private var inlineSearchControl: some View {
        if viewModel.isPostSearchActive {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(PepTheme.textSecondary)
                TextField("Search posts, people, tags", text: $viewModel.postSearchQuery)
                    .font(.system(size: 13))
                    .foregroundStyle(PepTheme.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($searchFieldFocused)
                if !viewModel.postSearchQuery.isEmpty {
                    Button {
                        viewModel.postSearchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
                Button("Cancel") {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        viewModel.postSearchQuery = ""
                        viewModel.isPostSearchActive = false
                        searchFieldFocused = false
                    }
                }
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(PepTheme.cardSurface))
            .overlay(
                Capsule().strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
            )
            .frame(maxWidth: .infinity)
            .transition(.opacity)
            .onAppear { searchFieldFocused = true }
        } else {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    viewModel.isPostSearchActive = true
                }
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.85))
                    .frame(width: 32, height: 30)
                    .background(Capsule().fill(Color.clear))
                    .overlay(
                        Capsule().strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
                    )
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: viewModel.isPostSearchActive)
            .transition(.opacity)
        }
    }

    private var feedFilterBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                if !viewModel.isPostSearchActive {
                    ForEach(FeedFilter.allCases, id: \.self) { filter in
                        if filter == .tags {
                            tagsFilterPill
                        } else {
                            let isActive = viewModel.feedFilter == filter
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    viewModel.feedFilter = filter
                                    viewModel.isTagsExpanded = false
                                }
                            } label: {
                                Text(filter.rawValue.uppercased())
                                    .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                                    .tracking(1.4)
                                    .foregroundStyle(isActive ? PepTheme.textPrimary : PepTheme.textSecondary.opacity(0.7))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(
                                        Capsule().fill(isActive ? PepTheme.cardSurface : Color.clear)
                                    )
                                    .overlay(
                                        Capsule().strokeBorder(
                                            isActive ? PepTheme.textPrimary.opacity(0.7) : PepTheme.separatorColor,
                                            lineWidth: 0.5
                                        )
                                    )
                            }
                            .sensoryFeedback(.selection, trigger: viewModel.feedFilter)
                        }
                    }
                    Spacer(minLength: 4)
                }
                inlineSearchControl
            }
            .padding(.horizontal)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.isPostSearchActive)

            if viewModel.isTagsExpanded {
                tagSelectionGrid
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
    }

    private var tagsFilterPill: some View {
        let isActive = viewModel.feedFilter == .tags
        let activeCount = viewModel.selectedTags.count
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                if viewModel.feedFilter == .tags {
                    viewModel.isTagsExpanded.toggle()
                } else {
                    viewModel.feedFilter = .tags
                    viewModel.isTagsExpanded = true
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text("TAGS")
                    .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                    .tracking(1.4)
                if isActive && activeCount > 0 {
                    Text("·  \(activeCount)")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Image(systemName: viewModel.isTagsExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .regular))
            }
            .foregroundStyle(isActive ? PepTheme.textPrimary : PepTheme.textSecondary.opacity(0.7))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(isActive ? PepTheme.cardSurface : Color.clear))
            .overlay(
                Capsule().strokeBorder(
                    isActive ? PepTheme.textPrimary.opacity(0.7) : PepTheme.separatorColor,
                    lineWidth: 0.5
                )
            )
        }
        .sensoryFeedback(.selection, trigger: viewModel.isTagsExpanded)
    }

    private var tagSelectionGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TagCategory.allCases) { category in
                        let isExpanded = viewModel.expandedCategories.contains(category)
                        let hasActiveTag = category.tags.contains(where: { viewModel.selectedTags.contains($0) })
                        let activeCount = category.tags.filter { viewModel.selectedTags.contains($0) }.count
                        let active = isExpanded || hasActiveTag
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                if isExpanded {
                                    viewModel.expandedCategories.remove(category)
                                } else {
                                    viewModel.expandedCategories = [category]
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(category.rawValue.uppercased())
                                    .font(.system(size: 10, weight: active ? .semibold : .regular))
                                    .tracking(1.3)
                                if activeCount > 0 {
                                    Text("\(activeCount)")
                                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                                        .foregroundStyle(PepTheme.textSecondary)
                                }
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 8, weight: .regular))
                            }
                            .foregroundStyle(active ? PepTheme.textPrimary : PepTheme.textSecondary.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(active ? PepTheme.cardSurface : Color.clear))
                            .overlay(
                                Capsule().strokeBorder(
                                    active ? PepTheme.textPrimary.opacity(0.6) : PepTheme.separatorColor,
                                    lineWidth: 0.5
                                )
                            )
                        }
                        .sensoryFeedback(.selection, trigger: isExpanded)
                    }
                }
                .padding(.horizontal)
            }
            .contentMargins(.horizontal, 0)

            ForEach(TagCategory.allCases) { category in
                if viewModel.expandedCategories.contains(category) {
                    expandedCategoryTags(for: category)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
        }
    }

    private func expandedCategoryTags(for category: TagCategory) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        let categoryTags = Set(category.tags)
                        let allSelected = categoryTags.isSubset(of: viewModel.selectedTags)
                        if allSelected {
                            viewModel.selectedTags.subtract(categoryTags)
                        } else {
                            viewModel.selectedTags.formUnion(categoryTags)
                        }
                    }
                } label: {
                    let allSelected = Set(category.tags).isSubset(of: viewModel.selectedTags)
                    Text("ALL")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.3)
                        .foregroundStyle(allSelected ? PepTheme.textPrimary : PepTheme.textSecondary.opacity(0.7))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(allSelected ? PepTheme.cardSurface : Color.clear))
                        .overlay(
                            Capsule().strokeBorder(
                                allSelected ? PepTheme.textPrimary.opacity(0.6) : PepTheme.separatorColor,
                                lineWidth: 0.5
                            )
                        )
                }

                ForEach(category.tags) { tag in
                    let isSelected = viewModel.selectedTags.contains(tag)
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if isSelected {
                                viewModel.selectedTags.remove(tag)
                            } else {
                                viewModel.selectedTags.insert(tag)
                            }
                        }
                    } label: {
                        Text("#" + tag.rawValue.lowercased())
                            .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? PepTheme.textPrimary : PepTheme.textSecondary.opacity(0.85))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(isSelected ? PepTheme.cardSurface : Color.clear))
                            .overlay(
                                Capsule().strokeBorder(
                                    isSelected ? PepTheme.textPrimary.opacity(0.6) : PepTheme.separatorColor,
                                    lineWidth: 0.5
                                )
                            )
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: isSelected)
                }
            }
            .padding(.horizontal)
        }
        .contentMargins(.horizontal, 0)
    }
}
