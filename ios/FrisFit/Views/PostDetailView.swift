import SwiftUI

struct PostDetailView: View {
    let post: FeedPost
    let viewModel: SocialViewModel

    @State private var commentText: String = ""
    @State private var isLoadingComments: Bool = true
    @State private var comments: [PostComment] = []
    @State private var highFiveBounce: Int = 0
    @State private var selectedPhotoURL: String?
    @FocusState private var isCommentFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    postContent
                    commentsSection
                }
            }
            .scrollIndicators(.hidden)

            commentInputBar
        }
        .background(PepTheme.background)
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $selectedPhotoURL) { urlString in
            PhotoViewerOverlay(urlString: urlString) {
                selectedPhotoURL = nil
            }
        }
        .task {
            await viewModel.loadComments(for: post.id)
            if let updated = viewModel.feedPosts.first(where: { $0.id == post.id }) {
                comments = updated.comments
            }
            isLoadingComments = false
        }
    }

    private var postContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            userHeader
                .padding(.horizontal)

            if !post.textContent.isEmpty {
                Text(post.textContent)
                    .font(.system(.body))
                    .foregroundStyle(PepTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)
            }

            if !post.photoMedia.isEmpty {
                photoSection
            }

            if !post.tags.isEmpty {
                tagRow
                    .padding(.horizontal)
            }

            actionBar
                .padding(.horizontal)

            Divider()
                .overlay(PepTheme.separatorColor)
                .padding(.horizontal)
        }
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var userHeader: some View {
        HStack(spacing: 12) {
            NavigationLink(value: post.user) {
                Circle()
                    .fill(post.user.avatarColor.opacity(0.2))
                    .frame(width: 48, height: 48)
                    .overlay {
                        if let avatarURL = post.user.avatarURL, let url = URL(string: avatarURL) {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else {
                                    Text(post.user.avatarInitial)
                                        .font(.system(.headline, design: .rounded, weight: .bold))
                                        .foregroundStyle(post.user.avatarColor)
                                }
                            }
                            .allowsHitTesting(false)
                        } else {
                            Text(post.user.avatarInitial)
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .foregroundStyle(post.user.avatarColor)
                        }
                    }
                    .clipShape(.circle)
            }

            VStack(alignment: .leading, spacing: 3) {
                NavigationLink(value: post.user) {
                    Text(post.user.name)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                }

                HStack(spacing: 4) {
                    Text("@\(post.user.username)")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                    Text("·")
                        .foregroundStyle(PepTheme.textSecondary)
                    Text(post.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }

            Spacer()

            Button { } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14))
                    .foregroundStyle(PepTheme.textSecondary)
                    .frame(width: 32, height: 32)
            }
        }
    }

    @ViewBuilder
    private var photoSection: some View {
        let photos = post.photoMedia
        if photos.count == 1 {
            singlePhoto(photos[0])
                .padding(.horizontal)
        } else {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(photos) { photo in
                        multiPhoto(photo)
                    }
                }
            }
            .contentMargins(.horizontal, 16)
            .scrollIndicators(.hidden)
        }
    }

    private func singlePhoto(_ photo: FeedMediaItem) -> some View {
        Color(.tertiarySystemFill)
            .aspectRatio(4/3, contentMode: .fit)
            .overlay {
                if let urlString = photo.imageURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                        case .empty:
                            ProgressView()
                                .tint(PepTheme.teal)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .allowsHitTesting(false)
                } else {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                }
            }
            .clipShape(.rect(cornerRadius: 14))
            .onTapGesture {
                selectedPhotoURL = photo.imageURL
            }
    }

    private func multiPhoto(_ photo: FeedMediaItem) -> some View {
        Color(.tertiarySystemFill)
            .frame(width: 260, height: 260)
            .overlay {
                if let urlString = photo.imageURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                        case .empty:
                            ProgressView()
                                .tint(PepTheme.teal)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .allowsHitTesting(false)
                } else {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                }
            }
            .clipShape(.rect(cornerRadius: 14))
            .onTapGesture {
                selectedPhotoURL = photo.imageURL
            }
    }

    private var tagRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(post.tags) { tag in
                    HStack(spacing: 4) {
                        Image(systemName: tag.icon)
                            .font(.system(size: 10))
                        Text(tag.rawValue)
                            .font(.system(.caption2, weight: .semibold))
                    }
                    .foregroundStyle(PepTheme.teal)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(PepTheme.teal.opacity(0.1))
                    .clipShape(.capsule)
                }
            }
        }
        .contentMargins(.horizontal, 0)
        .scrollIndicators(.hidden)
    }

    private var actionBar: some View {
        HStack(spacing: 0) {
            Button {
                viewModel.toggleFeedHighFive(for: post.id)
                highFiveBounce += 1
            } label: {
                let currentPost = viewModel.feedPosts.first(where: { $0.id == post.id }) ?? post
                HStack(spacing: 6) {
                    Image(systemName: currentPost.isHighFived ? "hand.raised.fill" : "hand.raised")
                        .font(.system(size: 18))
                        .foregroundStyle(currentPost.isHighFived ? PepTheme.amber : PepTheme.textSecondary)
                        .symbolEffect(.bounce, value: highFiveBounce)
                    Text("\(currentPost.highFiveCount)")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(currentPost.isHighFived ? PepTheme.amber : PepTheme.textSecondary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.scale)
            .sensoryFeedback(.impact(weight: .medium), trigger: highFiveBounce)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3)) {
                    isCommentFocused = true
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 16))
                    Text("\(comments.count)")
                        .font(.system(.subheadline, weight: .medium))
                }
                .foregroundStyle(PepTheme.textSecondary)
                .contentShape(.rect)
            }
            .buttonStyle(.scale)

            Spacer()

            Button { } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.2.squarepath")
                        .font(.system(size: 16))
                    Text("\(post.repostCount)")
                        .font(.system(.subheadline, weight: .medium))
                }
                .foregroundStyle(PepTheme.textSecondary)
                .contentShape(.rect)
            }
            .buttonStyle(.scale)

            Spacer()

            Button { } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16))
                    .foregroundStyle(PepTheme.textSecondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.scale)
        }
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Comments")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 12)

            if isLoadingComments {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(PepTheme.teal)
                    Spacer()
                }
                .padding(.vertical, 32)
            } else if comments.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 32))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                    Text("No comments yet")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textSecondary)
                    Text("Be the first to share your thoughts")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(comments) { comment in
                        DetailCommentRow(comment: comment)
                            .padding(.horizontal)
                            .padding(.vertical, 10)

                        if comment.id != comments.last?.id {
                            Divider()
                                .overlay(PepTheme.separatorColor.opacity(0.5))
                                .padding(.leading, 58)
                        }
                    }
                }
            }
        }
        .padding(.bottom, 80)
    }

    private var commentInputBar: some View {
        HStack(spacing: 12) {
            TextField("Add a comment...", text: $commentText)
                .font(.subheadline)
                .foregroundStyle(PepTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(PepTheme.elevated)
                .clipShape(.capsule)
                .focused($isCommentFocused)
                .onSubmit { sendComment() }

            Button {
                sendComment()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? PepTheme.textSecondary.opacity(0.3) : PepTheme.teal)
            }
            .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            PepTheme.cardSurface
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: -2)
        )
    }

    private func sendComment() {
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        commentText = ""
        isCommentFocused = false
        Task {
            await viewModel.addFeedComment(to: post.id, text: trimmed)
            if let updated = viewModel.feedPosts.first(where: { $0.id == post.id }) {
                withAnimation(.spring(response: 0.3)) {
                    comments = updated.comments
                }
            }
        }
    }
}

private struct DetailCommentRow: View {
    let comment: PostComment

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(comment.user.avatarColor.opacity(0.2))
                .frame(width: 36, height: 36)
                .overlay {
                    Text(comment.user.avatarInitial)
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(comment.user.avatarColor)
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(comment.user.name)
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)

                    Text(comment.timestamp.timeAgoDisplay())
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                }

                Text(comment.text)
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct PhotoViewerOverlay: View {
    let urlString: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.white.opacity(0.5))
                    case .empty:
                        ProgressView()
                            .tint(.white)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding()
            }
        }
        .statusBarHidden()
    }
}

extension String: @retroactive Identifiable {
    public var id: String { self }
}
