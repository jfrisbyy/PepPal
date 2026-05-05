import SwiftUI

/// Sheet that lets the user forward a feed post to one of their existing
/// direct-message conversations. Sends a DM with a `.post` attachment that
/// renders as a tappable `SharedPostBubble` in the chat.
struct SharePostSheet: View {
    let post: FeedPost
    @Environment(\.dismiss) private var dismiss
    @State private var conversations: [ConversationOption] = []
    @State private var isLoading: Bool = true
    @State private var sendingTo: Set<String> = []
    @State private var sentTo: Set<String> = []
    @State private var error: String?
    @State private var note: String = ""

    struct ConversationOption: Identifiable, Hashable {
        let id: String
        let conversationId: String
        let participant: SocialUser
    }

    private var previewSnippet: String {
        let text = post.textContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = text.components(separatedBy: .newlines).first ?? text
        let truncated = firstLine.count > 140 ? String(firstLine.prefix(140)) + "…" : firstLine
        if truncated.isEmpty {
            return "@\(post.user.username) shared a post"
        }
        return "@\(post.user.username): \(truncated)"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                postPreview
                noteField
                Divider().overlay(PepTheme.separatorColor)

                if isLoading {
                    Spacer()
                    ProgressView().tint(PepTheme.teal)
                    Spacer()
                } else if conversations.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .background(PepTheme.background)
            .navigationTitle("Send Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PepTheme.teal)
                }
            }
            .task { await load() }
            .alert("Couldn't Send", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK") { error = nil }
            } message: {
                Text(error ?? "")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var postPreview: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(post.user.avatarColor.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay {
                    Text(post.user.avatarInitial)
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(post.user.avatarColor)
                }
            VStack(alignment: .leading, spacing: 3) {
                Text(post.user.name)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(previewSnippet)
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var noteField: some View {
        TextField("Add a note (optional)", text: $note, axis: .vertical)
            .font(.subheadline)
            .foregroundStyle(PepTheme.textPrimary)
            .lineLimit(1...3)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(PepTheme.elevated)
            .clipShape(.rect(cornerRadius: 10))
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 36))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
            Text("No conversations yet")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
            Text("Start a chat from a profile to share posts.")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(conversations) { opt in
                    row(opt)
                    if opt.id != conversations.last?.id {
                        Divider()
                            .overlay(PepTheme.separatorColor.opacity(0.5))
                            .padding(.leading, 60)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func row(_ opt: ConversationOption) -> some View {
        let isSending = sendingTo.contains(opt.id)
        let didSend = sentTo.contains(opt.id)

        Button {
            Task { await send(to: opt) }
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(opt.participant.avatarColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text(opt.participant.avatarInitial)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(opt.participant.avatarColor)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(opt.participant.name)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("@\(opt.participant.username)")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }

                Spacer()

                Group {
                    if didSend {
                        Label("Sent", systemImage: "checkmark.circle.fill")
                            .labelStyle(.titleAndIcon)
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(PepTheme.teal)
                    } else if isSending {
                        ProgressView().controlSize(.small).tint(PepTheme.teal)
                    } else {
                        Text("Send")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(PepTheme.invertedText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(PepTheme.teal)
                            .clipShape(.capsule)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isSending || didSend)
    }

    private func load() async {
        defer { isLoading = false }
        do {
            let userId = try AuthService.shared.currentUserId()
            let convs = try await MessagingService.shared.fetchConversations(userId: userId)
            conversations = convs.map { item in
                let user = MessagingService.shared.socialUserFromAuthor(item.participant)
                return ConversationOption(
                    id: item.conversation.id,
                    conversationId: item.conversation.id,
                    participant: user
                )
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func send(to opt: ConversationOption) async {
        guard let postId = post.supabaseId, !postId.isEmpty else {
            error = "This post can't be shared yet."
            return
        }
        guard let userId = try? AuthService.shared.currentUserId() else { return }

        sendingTo.insert(opt.id)
        defer { sendingTo.remove(opt.id) }

        let attachment = DirectMessageAttachment(
            kind: .post,
            url: "peppal://post/\(postId)",
            postId: postId,
            previewText: previewSnippet
        )
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = trimmedNote.isEmpty ? "" : trimmedNote

        do {
            _ = try await MessagingService.shared.sendMessage(
                conversationId: opt.conversationId,
                senderId: userId,
                text: body,
                attachments: [attachment]
            )
            sentTo.insert(opt.id)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
