import SwiftUI

struct ChatConversationView: View {
    @State private var viewModel: MessagesViewModel
    let conversationID: UUID
    @State private var messageText: String = ""
    @FocusState private var isInputFocused: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var hasLoadedMessages: Bool = false

    init(viewModel: MessagesViewModel, conversationID: UUID) {
        _viewModel = State(initialValue: viewModel)
        self.conversationID = conversationID
    }

    private var conversation: Conversation? {
        viewModel.conversation(for: conversationID)
    }

    var body: some View {
        VStack(spacing: 0) {
            messagesScrollView

            inputBar
        }
        .background(PepTheme.background.ignoresSafeArea())
        .navigationTitle(conversation?.participant.name ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if let participant = conversation?.participant {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(participant.avatarColor.opacity(0.2))
                            .frame(width: 28, height: 28)
                            .overlay {
                                Text(participant.avatarInitial)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(participant.avatarColor)
                            }

                        Text(participant.name)
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                    }
                }
            }
        }
        .onAppear {
            viewModel.markAsRead(conversationID: conversationID)
        }
        .task {
            if !hasLoadedMessages {
                hasLoadedMessages = true
                await viewModel.loadFullConversation(conversationID: conversationID)
            }
        }
    }

    private var messagesScrollView: some View {
        ScrollView {
            ScrollViewReader { proxy in
                LazyVStack(spacing: 6) {
                    if let convo = conversation {
                        ForEach(groupedMessages(convo.messages), id: \.date) { group in
                            dateDivider(group.date)
                                .padding(.top, 12)
                                .padding(.bottom, 4)

                            ForEach(group.messages) { message in
                                let isFromMe = message.senderID != convo.participant.id
                                messageBubble(message: message, isFromMe: isFromMe)
                                    .id(message.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .onChange(of: conversation?.messages.count) { _, _ in
                    if let lastID = conversation?.messages.last?.id {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    if let lastID = conversation?.messages.last?.id {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private func messageBubble(message: DirectMessage, isFromMe: Bool) -> some View {
        HStack {
            if isFromMe { Spacer(minLength: 60) }

            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 3) {
                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(isFromMe ? .white : PepTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isFromMe
                            ? AnyShapeStyle(LinearGradient(
                                colors: [PepTheme.teal, PepTheme.teal.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            : AnyShapeStyle(PepTheme.elevated)
                    )
                    .clipShape(.rect(
                        topLeadingRadius: isFromMe ? 18 : 6,
                        bottomLeadingRadius: 18,
                        bottomTrailingRadius: isFromMe ? 6 : 18,
                        topTrailingRadius: 18
                    ))

                Text(formatTime(message.timestamp))
                    .font(.system(size: 10))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
                    .padding(.horizontal, 4)
            }

            if !isFromMe { Spacer(minLength: 60) }
        }
    }

    private func dateDivider(_ date: Date) -> some View {
        HStack {
            VStack { Divider() }
            Text(formatDateHeader(date))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
                .fixedSize()
            VStack { Divider() }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Message...", text: $messageText, axis: .vertical)
                .font(.subheadline)
                .lineLimit(1...5)
                .focused($isInputFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(PepTheme.elevated)
                .clipShape(.capsule)

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? PepTheme.textSecondary.opacity(0.3) : PepTheme.teal)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .sensoryFeedback(.impact(weight: .light), trigger: conversation?.messages.count ?? 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            PepTheme.cardSurface
                .shadow(color: .black.opacity(0.05), radius: 8, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.sendMessage(to: conversationID, text: trimmed)
        messageText = ""
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func formatDateHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func groupedMessages(_ messages: [DirectMessage]) -> [MessageGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: messages) { msg in
            calendar.startOfDay(for: msg.timestamp)
        }
        return grouped.map { MessageGroup(date: $0.key, messages: $0.value.sorted { $0.timestamp < $1.timestamp }) }
            .sorted { $0.date < $1.date }
    }
}

private struct MessageGroup {
    let date: Date
    let messages: [DirectMessage]
}
