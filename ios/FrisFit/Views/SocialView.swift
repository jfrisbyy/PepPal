import SwiftUI

struct SocialView: View {
    @State private var viewModel = SocialViewModel()
    @State private var messagesViewModel = MessagesViewModel()
    @State private var profileViewModel = ProfileViewModel()
    @State private var commentPost: WorkoutPost?
    @State private var commentFeedPost: FeedPost?
    @State private var isLoading: Bool = true
    @State private var showComposer: Bool = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                feedView

                composeButton
            }
            .background(PepTheme.background.ignoresSafeArea())
            .navigationTitle("Community")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        DirectMessagesView(viewModel: messagesViewModel)
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(PepTheme.teal)

                            if messagesViewModel.totalUnread > 0 {
                                Text("\(messagesViewModel.totalUnread)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(minWidth: 16, minHeight: 16)
                                    .background(Color.red)
                                    .clipShape(.circle)
                                    .offset(x: 6, y: -6)
                            }
                        }
                    }
                }
            }
            .sheet(item: $commentPost) { post in
                CommentsSheet(post: post) { text in
                    viewModel.addComment(to: post.id, text: text)
                    if let updated = viewModel.posts.first(where: { $0.id == post.id }) {
                        commentPost = updated
                    }
                }
            }
            .sheet(isPresented: $showComposer) {
                PostComposerView { post in
                    viewModel.addFeedPost(post)
                }
            }
            .navigationDestination(for: SocialUser.self) { user in
                UserProfileView(user: user, viewModel: profileViewModel)
            }
            .onAppear {
                if isLoading {
                    Task {
                        try? await Task.sleep(for: .milliseconds(500))
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            isLoading = false
                        }
                    }
                }
            }
        }
    }

    private var composeButton: some View {
        Button {
            showComposer = true
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [PepTheme.teal, PepTheme.teal.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: PepTheme.teal.opacity(0.4), radius: 12, x: 0, y: 4)

                Image(systemName: "square.and.pencil")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.scale)
        .padding(.trailing, 20)
        .padding(.bottom, 20)
        .sensoryFeedback(.impact(weight: .medium), trigger: showComposer)
        .transition(.scale.combined(with: .opacity))
    }

    private var feedView: some View {
        ScrollView {
            VStack(spacing: 0) {
                feedFilterBar
                    .padding(.top, 4)
                    .padding(.bottom, 8)

                if isLoading {
                    SkeletonFeedView()
                        .padding(.top, 8)
                        .transition(.opacity)
                } else if viewModel.filteredFeedPosts.isEmpty {
                    EmptyStateView(
                        icon: viewModel.feedFilter == .following ? "person.2" : "tag",
                        title: viewModel.feedFilter == .following ? "No Posts from Friends" : "No Matching Posts",
                        message: viewModel.feedFilter == .following
                            ? "Follow more people to see their posts here."
                            : "Try selecting different tags to find posts.",
                        actionTitle: viewModel.feedFilter == .following ? "Find Friends" : nil
                    )
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.filteredFeedPosts) { post in
                            FeedPostCard(
                                post: post,
                                onHighFive: {
                                    viewModel.toggleFeedHighFive(for: post.id)
                                },
                                onComment: {
                                    commentFeedPost = post
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 80)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .scrollIndicators(.hidden)
        .refreshable {
            try? await Task.sleep(for: .seconds(1))
        }
    }

    private var feedFilterBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ForEach(FeedFilter.allCases, id: \.self) { filter in
                    if filter == .tags {
                        tagsFilterPill
                    } else {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                viewModel.feedFilter = filter
                                viewModel.isTagsExpanded = false
                            }
                        } label: {
                            Text(filter.rawValue)
                                .font(.system(.subheadline, weight: viewModel.feedFilter == filter ? .bold : .medium))
                                .foregroundStyle(viewModel.feedFilter == filter ? PepTheme.invertedText : PepTheme.textSecondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    viewModel.feedFilter == filter
                                        ? AnyShapeStyle(PepTheme.teal)
                                        : AnyShapeStyle(PepTheme.elevated)
                                )
                                .clipShape(.capsule)
                        }
                        .sensoryFeedback(.selection, trigger: viewModel.feedFilter)
                    }
                }
                Spacer()
            }
            .padding(.horizontal)

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
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                if viewModel.feedFilter == .tags {
                    viewModel.isTagsExpanded.toggle()
                } else {
                    viewModel.feedFilter = .tags
                    viewModel.isTagsExpanded = true
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text("Tags")
                    .font(.system(.subheadline, weight: viewModel.feedFilter == .tags ? .bold : .medium))
                let activeCount = viewModel.selectedTags.count
                if viewModel.feedFilter == .tags && activeCount > 0 {
                    Text("\(activeCount)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PepTheme.teal)
                        .frame(width: 18, height: 18)
                        .background(PepTheme.invertedText.opacity(0.2))
                        .clipShape(.circle)
                }
                Image(systemName: viewModel.isTagsExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(viewModel.feedFilter == .tags ? PepTheme.invertedText : PepTheme.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                viewModel.feedFilter == .tags
                    ? AnyShapeStyle(PepTheme.teal)
                    : AnyShapeStyle(PepTheme.elevated)
            )
            .clipShape(.capsule)
        }
        .sensoryFeedback(.selection, trigger: viewModel.isTagsExpanded)
    }

    private var tagSelectionGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FeedTag.allCases) { tag in
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
                        HStack(spacing: 5) {
                            Image(systemName: tag.icon)
                                .font(.system(size: 12))
                            Text(tag.rawValue)
                                .font(.system(.caption, weight: .semibold))
                        }
                        .foregroundStyle(isSelected ? PepTheme.invertedText : PepTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            isSelected
                                ? AnyShapeStyle(PepTheme.teal)
                                : AnyShapeStyle(PepTheme.cardSurface)
                        )
                        .clipShape(.capsule)
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    isSelected ? PepTheme.teal : PepTheme.separatorColor,
                                    lineWidth: 1
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
