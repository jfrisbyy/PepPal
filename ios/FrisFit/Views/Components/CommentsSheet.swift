import SwiftUI

struct CommentsSheet: View {
    let post: WorkoutPost
    let onAddComment: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var commentText: String = ""
    @State private var showReportAlert: Bool = false
    @FocusState private var isCommentFocused: Bool

    private var currentUserId: String? {
        try? AuthService.shared.currentUserId()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if post.comments.isEmpty {
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
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(post.comments) { comment in
                                CommentRow(
                                    comment: comment,
                                    isOwnComment: comment.user.id.uuidString.lowercased() == currentUserId?.lowercased(),
                                    onReport: { showReportAlert = true }
                                )
                            }
                        }
                        .padding()
                    }
                }

                Divider()
                    .overlay(PepTheme.separatorColor)

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
        .alert("Comment Reported", isPresented: $showReportAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Thanks for letting us know. We'll review this comment.")
        }
    }

    private func sendComment() {
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onAddComment(trimmed)
        commentText = ""
    }
}

private struct CommentRow: View {
    let comment: PostComment
    let isOwnComment: Bool
    let onReport: () -> Void

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
            }
        }
        .contextMenu {
            Button {
                UIPasteboard.general.string = comment.text
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            if !isOwnComment {
                Button {
                    onReport()
                } label: {
                    Label("Report", systemImage: "exclamationmark.triangle")
                }
            }
        }
    }
}
