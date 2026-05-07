import SwiftUI
import AVFoundation

struct PostDetailView: View {
    let post: FeedPost
    let viewModel: SocialViewModel

    @State private var commentText: String = ""
    @State private var isLoadingComments: Bool = true
    @State private var comments: [PostComment] = []
    @State private var commentError: String?
    @State private var likeBounce: Int = 0
    @State private var repostBounce: Int = 0
    @State private var showShareSheet: Bool = false
    private let likeManager = LikeManager.shared

    private var postSupabaseId: String {
        post.supabaseId ?? post.id.uuidString.lowercased()
    }
    @State private var selectedPhotoURL: String?
    @State private var showDeleteConfirm: Bool = false
    @State private var showReportConfirm: Bool = false
    @State private var commentToDelete: PostComment?
    @State private var showCommentReportAlert: Bool = false
    @FocusState private var isCommentFocused: Bool
    @State private var selectedHashtag: String?
    @State private var replyingTo: PostComment?
    @State private var expandedThreads: Set<UUID> = []

    private var currentUserId: String? {
        try? AuthService.shared.currentUserId()
    }
    @Environment(\.dismiss) private var dismiss
    private var audioPlayer: AudioPlayerService { AudioPlayerService.shared }

    private var isOwnPost: Bool {
        guard let userId = try? AuthService.shared.currentUserId() else { return false }
        return post.user.id.uuidString.lowercased() == userId.lowercased()
    }

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
        .navigationDestination(item: Binding(get: { selectedHashtag.map(HashtagDestination.init) }, set: { selectedHashtag = $0?.tag })) { dest in
            HashtagFeedView(tag: dest.tag)
        }
        .fullScreenCover(item: $selectedPhotoURL) { urlString in
            PhotoViewerOverlay(urlString: urlString) {
                selectedPhotoURL = nil
            }
        }
        .alert("Delete Comment?", isPresented: Binding(
            get: { commentToDelete != nil },
            set: { if !$0 { commentToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let comment = commentToDelete {
                    Task {
                        let success = await viewModel.deleteFeedComment(comment, from: post.id)
                        if success {
                            withAnimation(.spring(response: 0.3)) {
                                comments.removeAll { $0.id == comment.id }
                            }
                        }
                    }
                    commentToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { commentToDelete = nil }
        } message: {
            Text("This comment will be permanently removed.")
        }
        .alert("Comment Reported", isPresented: $showCommentReportAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Thanks for letting us know. We'll review this comment.")
        }
        .task {
            viewModel.ensurePostInFeed(post)
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
                RichText(
                    text: post.textContent,
                    font: .body,
                    onHashtag: { tag in selectedHashtag = tag }
                )
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal)
            }

            if !post.photoMedia.isEmpty {
                photoSection
            }

            if let voice = post.voiceMedia {
                voiceMessageSection(voice)
                    .padding(.horizontal)
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
                    Text(post.timestamp.formattedPostDate())
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }

            Spacer()

            Menu {
                if isOwnPost {
                    Button(role: .destructive) {
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
                    UIPasteboard.general.string = post.textContent
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
        .alert("Delete Post?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deletePost()
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
    }

    private func deletePost() {
        let supabaseId = post.supabaseId ?? post.id.uuidString
        Task {
            do {
                try await SocialService.shared.deletePost(postId: supabaseId)
                if let idx = viewModel.feedPosts.firstIndex(where: { $0.id == post.id }) {
                    viewModel.feedPosts.remove(at: idx)
                }
                dismiss()
            } catch {}
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

    private func voiceMessageSection(_ voice: FeedMediaItem) -> some View {
        let voiceURL = voice.imageURL ?? ""
        let isPlaying = audioPlayer.isPlayingURL(voiceURL)
        let progress = audioPlayer.progressForURL(voiceURL)
        let duration = voice.voiceDuration ?? 0

        return HStack(spacing: 10) {
            Button {
                guard !voiceURL.isEmpty else { return }
                audioPlayer.play(urlString: voiceURL, duration: duration)
            } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(PepTheme.teal)
            }

            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        detailWaveformBars(width: geo.size.width, height: geo.size.height)
                        Rectangle()
                            .fill(PepTheme.teal)
                            .frame(width: geo.size.width * progress)
                            .mask { detailWaveformBars(width: geo.size.width, height: geo.size.height) }
                    }
                }
                .frame(height: 32)

                HStack {
                    Text(formatVoiceDuration(progress * duration))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                    Text(formatVoiceDuration(duration))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
        .padding(14)
        .background(PepTheme.elevated)
        .clipShape(.rect(cornerRadius: 14))
    }

    private func detailWaveformBars(width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<Int(width / 4.5), id: \.self) { i in
                let seed = Double(i * 7 + 3)
                let h = (sin(seed) * 0.4 + 0.6) * height
                RoundedRectangle(cornerRadius: 1)
                    .fill(PepTheme.textSecondary.opacity(0.35))
                    .frame(width: 2.5, height: max(4, h))
            }
        }
    }

    private func formatVoiceDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
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
                viewModel.toggleFeedLike(for: post.id)
                likeBounce += 1
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: likeManager.isLiked(postId: postSupabaseId) ? "heart.fill" : "heart")
                        .font(.system(size: 18))
                        .foregroundStyle(likeManager.isLiked(postId: postSupabaseId) ? .red : PepTheme.textSecondary)
                        .symbolEffect(.bounce, value: likeBounce)
                    Text("\(likeManager.likeCount(postId: postSupabaseId, fallback: post.likeCount))")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(likeManager.isLiked(postId: postSupabaseId) ? .red : PepTheme.textSecondary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.scale)
            .sensoryFeedback(.impact(weight: .medium), trigger: likeBounce)

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

            Button {
                viewModel.toggleRepost(for: post.id)
                repostBounce += 1
            } label: {
                let currentPost = viewModel.feedPosts.first(where: { $0.id == post.id }) ?? post
                HStack(spacing: 6) {
                    Image(systemName: "arrow.2.squarepath")
                        .font(.system(size: 16))
                        .foregroundStyle(currentPost.isReposted ? PepTheme.teal : PepTheme.textSecondary)
                        .symbolEffect(.bounce, value: repostBounce)
                    Text("\(currentPost.repostCount)")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(currentPost.isReposted ? PepTheme.teal : PepTheme.textSecondary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.scale)
            .sensoryFeedback(.impact(weight: .light), trigger: repostBounce)

            Spacer()

            Button {
                showShareSheet = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16))
                    .foregroundStyle(PepTheme.textSecondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.scale)
            .sheet(isPresented: $showShareSheet) {
                SharePostSheet(post: post)
            }
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
                let topLevel = comments.filter { $0.parentId == nil }
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(topLevel) { comment in
                        commentThread(for: comment, isLast: comment.id == topLevel.last?.id)
                    }
                }

                if let commentError {
                    Text(commentError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                        .padding(.top, 4)
                }
            }
        }
        .padding(.bottom, 80)
    }

    private var commentInputBar: some View {
        VStack(spacing: 0) {
            if let replyingTo {
                HStack(spacing: 8) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(PepTheme.teal)
                    Text("Replying to ")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                    + Text("@\(replyingTo.user.username)")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.teal)
                    Spacer()
                    Button {
                        cancelReply()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(PepTheme.teal.opacity(0.08))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(spacing: 12) {
                TextField(replyingTo == nil ? "Add a comment..." : "Add a reply...", text: $commentText)
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
        }
        .background(
            PepTheme.cardSurface
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: -2)
        )
    }

    @ViewBuilder
    private func commentThread(for comment: PostComment, isLast: Bool) -> some View {
        let replies = comments.filter { $0.parentId == comment.id }
        let isExpanded = expandedThreads.contains(comment.id)
        let visibleReplies: [PostComment] = isExpanded ? replies : Array(replies.prefix(2))

        VStack(alignment: .leading, spacing: 0) {
            DetailCommentRow(
                comment: comment,
                isOwnComment: comment.user.id.uuidString.lowercased() == currentUserId?.lowercased(),
                replyCount: replies.count,
                onDelete: { commentToDelete = comment },
                onReport: { showCommentReportAlert = true },
                onReply: { startReply(to: comment) }
            )
            .padding(.horizontal)
            .padding(.vertical, 10)

            if !replies.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(visibleReplies) { reply in
                        DetailCommentRow(
                            comment: reply,
                            isOwnComment: reply.user.id.uuidString.lowercased() == currentUserId?.lowercased(),
                            replyCount: 0,
                            onDelete: { commentToDelete = reply },
                            onReport: { showCommentReportAlert = true },
                            onReply: { startReply(to: comment) }
                        )
                        .padding(.vertical, 8)
                    }

                    if replies.count > visibleReplies.count {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                _ = expandedThreads.insert(comment.id)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Rectangle()
                                    .fill(PepTheme.separatorColor)
                                    .frame(width: 24, height: 1)
                                Text("View \(replies.count - visibleReplies.count) more \(replies.count - visibleReplies.count == 1 ? "reply" : "replies")")
                                    .font(.system(.caption, weight: .semibold))
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                            .padding(.vertical, 6)
                        }
                    } else if isExpanded && replies.count > 2 {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                _ = expandedThreads.remove(comment.id)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Rectangle()
                                    .fill(PepTheme.separatorColor)
                                    .frame(width: 24, height: 1)
                                Text("Hide replies")
                                    .font(.system(.caption, weight: .semibold))
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                .padding(.leading, 58)
                .padding(.trailing, 16)
            }

            if !isLast {
                Divider()
                    .overlay(PepTheme.separatorColor.opacity(0.5))
                    .padding(.leading, 58)
            }
        }
    }

    private func startReply(to comment: PostComment) {
        withAnimation(.spring(response: 0.3)) {
            replyingTo = comment
        }
        isCommentFocused = true
    }

    private func cancelReply() {
        withAnimation(.spring(response: 0.3)) {
            replyingTo = nil
        }
    }

    private func sendComment() {
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let parentId = replyingTo?.parentId ?? replyingTo?.id
        if let parent = replyingTo {
            withAnimation(.spring(response: 0.3)) {
                _ = expandedThreads.insert(parent.parentId ?? parent.id)
            }
        }
        commentText = ""
        isCommentFocused = false
        commentError = nil
        withAnimation(.spring(response: 0.3)) { replyingTo = nil }

        let optimistic = viewModel.makeOptimisticComment(text: trimmed, parentId: parentId)
        withAnimation(.spring(response: 0.3)) {
            comments.append(optimistic)
        }

        Task {
            let success = await viewModel.addFeedComment(to: post.id, text: trimmed, parentCommentId: parentId, optimisticComment: optimistic)
            if let updated = viewModel.feedPosts.first(where: { $0.id == post.id }) {
                withAnimation(.spring(response: 0.3)) {
                    comments = updated.comments
                }
            }
            if !success {
                withAnimation {
                    comments.removeAll { $0.id == optimistic.id }
                    commentError = viewModel.feedError
                }
            }
        }
    }
}

private struct DetailCommentRow: View {
    let comment: PostComment
    let isOwnComment: Bool
    let replyCount: Int
    let onDelete: () -> Void
    let onReport: () -> Void
    let onReply: () -> Void

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

                    Text(comment.timestamp.formattedPostDate())
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                }

                Text(comment.text)
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onReply) {
                    HStack(spacing: 6) {
                        Text("Reply")
                            .font(.system(.caption2, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                        if replyCount > 0 {
                            Text("\(replyCount)")
                                .font(.system(.caption2, weight: .semibold))
                                .foregroundStyle(PepTheme.teal)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(PepTheme.teal.opacity(0.12))
                                .clipShape(.capsule)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .contextMenu {
            Button {
                UIPasteboard.general.string = comment.text
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            if isOwnComment {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } else {
                Button {
                    onReport()
                } label: {
                    Label("Report", systemImage: "exclamationmark.triangle")
                }
            }
        }
    }
}

private struct PhotoViewerOverlay: View {
    let urlString: String
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @GestureState private var gestureScale: CGFloat = 1.0
    @GestureState private var dragOffset: CGSize = .zero

    private var effectiveScale: CGFloat { scale * gestureScale }

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
                            .scaleEffect(effectiveScale)
                            .offset(
                                x: offset.width + dragOffset.width,
                                y: offset.height + dragOffset.height
                            )
                            .gesture(
                                MagnifyGesture()
                                    .updating($gestureScale) { value, state, _ in
                                        state = value.magnification
                                    }
                                    .onEnded { value in
                                        let newScale = scale * value.magnification
                                        withAnimation(.spring(response: 0.3)) {
                                            scale = min(max(newScale, 1.0), 5.0)
                                            if scale <= 1.0 {
                                                offset = .zero
                                            }
                                        }
                                    }
                                    .simultaneously(with:
                                        DragGesture()
                                            .updating($dragOffset) { value, state, _ in
                                                guard scale > 1 else { return }
                                                state = value.translation
                                            }
                                            .onEnded { value in
                                                guard scale > 1 else { return }
                                                offset.width += value.translation.width
                                                offset.height += value.translation.height
                                            }
                                    )
                            )
                            .onTapGesture(count: 2) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    if scale > 1 {
                                        scale = 1.0
                                        offset = .zero
                                    } else {
                                        scale = 2.5
                                    }
                                }
                            }
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
