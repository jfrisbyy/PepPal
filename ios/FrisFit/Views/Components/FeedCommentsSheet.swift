import SwiftUI

struct FeedCommentsSheet: View {
    let post: FeedPost
    let viewModel: SocialViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var commentText: String = ""
    @State private var isLoadingComments: Bool = true
    @State private var comments: [PostComment] = []
    @State private var commentError: String?
    @State private var commentToDelete: PostComment?
    @State private var showReportAlert: Bool = false
    @FocusState private var isCommentFocused: Bool
    @State private var replyingTo: PostComment?
    @State private var expandedThreads: Set<UUID> = []

    private var currentUserId: String? {
        try? AuthService.shared.currentUserId()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoadingComments {
                    Spacer()
                    ProgressView()
                        .tint(PepTheme.teal)
                    Spacer()
                } else if comments.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 40))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                        Text("No comments yet")
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textSecondary)
                        Text("Be the first to comment!")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                    }
                    Spacer()
                    if let commentError {
                        Text(commentError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                            .padding(.bottom, 4)
                    }
                } else {
                    let topLevel = comments.filter { $0.parentId == nil }
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(topLevel) { comment in
                                commentThread(for: comment)
                            }
                        }
                        .padding()
                    }
                }

                if let commentError, !comments.isEmpty {
                    Text(commentError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                }

                Divider()
                    .overlay(PepTheme.separatorColor)

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
                            .foregroundStyle(commentText.isEmpty ? PepTheme.textSecondary.opacity(0.3) : PepTheme.teal)
                    }
                    .disabled(commentText.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(PepTheme.cardSurface)
            }
            .background(PepTheme.background)
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PepTheme.teal)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(PepTheme.background)
        .presentationContentInteraction(.scrolls)
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
        .alert("Comment Reported", isPresented: $showReportAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Thanks for letting us know. We'll review this comment.")
        }
        .task {
            await viewModel.loadComments(for: post.id)
            if let updated = viewModel.feedPosts.first(where: { $0.id == post.id }) {
                comments = updated.comments
            }
            isLoadingComments = false
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
        commentError = nil
        withAnimation(.spring(response: 0.3)) { replyingTo = nil }

        let optimistic = viewModel.makeOptimisticComment(text: trimmed, parentId: parentId)
        withAnimation(.spring(response: 0.3)) {
            comments.append(optimistic)
        }

        Task {
            let success = await viewModel.addFeedComment(to: post.id, text: trimmed, parentCommentId: parentId, optimisticComment: optimistic)
            if let updated = viewModel.feedPosts.first(where: { $0.id == post.id }) {
                withAnimation(.spring(response: 0.3)) { comments = updated.comments }
            }
            if !success {
                withAnimation {
                    comments.removeAll { $0.id == optimistic.id }
                    commentError = viewModel.feedError
                }
            }
        }
    }

    @ViewBuilder
    private func commentThread(for comment: PostComment) -> some View {
        let replies = comments.filter { $0.parentId == comment.id }
        let isExpanded = expandedThreads.contains(comment.id)
        let visibleReplies: [PostComment] = isExpanded ? replies : Array(replies.prefix(2))

        VStack(alignment: .leading, spacing: 10) {
            FeedCommentRow(
                comment: comment,
                isOwnComment: comment.user.id.uuidString.lowercased() == currentUserId?.lowercased(),
                onDelete: { commentToDelete = comment },
                onReport: { showReportAlert = true },
                onReply: { startReply(to: comment) }
            )

            if !replies.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(visibleReplies) { reply in
                        FeedCommentRow(
                            comment: reply,
                            isOwnComment: reply.user.id.uuidString.lowercased() == currentUserId?.lowercased(),
                            onDelete: { commentToDelete = reply },
                            onReport: { showReportAlert = true },
                            onReply: { startReply(to: comment) }
                        )
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
                        }
                    }
                }
                .padding(.leading, 42)
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
}

private struct FeedCommentRow: View {
    let comment: PostComment
    let isOwnComment: Bool
    let onDelete: () -> Void
    let onReport: () -> Void
    let onReply: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(comment.user.avatarColor.opacity(0.2))
                .frame(width: 32, height: 32)
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

                Button(action: onReply) {
                    Text("Reply")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
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
