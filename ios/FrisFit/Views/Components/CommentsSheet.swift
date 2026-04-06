import SwiftUI

struct CommentsSheet: View {
    let post: WorkoutPost
    let onAddComment: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var commentText: String = ""
    @FocusState private var isCommentFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if post.comments.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 40))
                            .foregroundStyle(FrisTheme.textSecondary.opacity(0.5))
                        Text("No comments yet")
                            .font(.subheadline)
                            .foregroundStyle(FrisTheme.textSecondary)
                        Text("Be the first to comment!")
                            .font(.caption)
                            .foregroundStyle(FrisTheme.textSecondary.opacity(0.7))
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(post.comments) { comment in
                                CommentRow(comment: comment)
                            }
                        }
                        .padding()
                    }
                }

                Divider()
                    .overlay(FrisTheme.separatorColor)

                HStack(spacing: 12) {
                    TextField("Add a comment...", text: $commentText)
                        .font(.subheadline)
                        .foregroundStyle(FrisTheme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(FrisTheme.elevated)
                        .clipShape(.capsule)
                        .focused($isCommentFocused)
                        .onSubmit { sendComment() }

                    Button {
                        sendComment()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(commentText.isEmpty ? FrisTheme.textSecondary.opacity(0.3) : FrisTheme.cyan)
                    }
                    .disabled(commentText.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(FrisTheme.cardSurface)
            }
            .background(FrisTheme.background)
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(FrisTheme.cyan)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(FrisTheme.background)
        .presentationContentInteraction(.scrolls)
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
                        .foregroundStyle(FrisTheme.textPrimary)

                    Text(comment.timestamp.timeAgoDisplay())
                        .font(.caption2)
                        .foregroundStyle(FrisTheme.textSecondary.opacity(0.7))
                }

                Text(comment.text)
                    .font(.subheadline)
                    .foregroundStyle(FrisTheme.textPrimary.opacity(0.85))
            }
        }
    }
}
