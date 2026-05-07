import SwiftUI

struct DirectMessagesView: View {
    @State private var viewModel: MessagesViewModel
    @State private var searchQuery: String = ""
    @State private var selectedConversationID: UUID?
    @State private var navigateToConversation: Bool = false
    @Environment(\.dismiss) private var dismiss

    init(viewModel: MessagesViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            editorialHeader

            searchBar
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 6)

            if !searchQuery.isEmpty && viewModel.filteredConversations.isEmpty && !viewModel.searchResults.isEmpty {
                discoverSection
            } else if !searchQuery.isEmpty && viewModel.filteredConversations.isEmpty && viewModel.searchResults.isEmpty {
                noResultsState
            } else {
                conversationsList
            }
        }
        .appBackground()
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $navigateToConversation) {
            if let id = selectedConversationID {
                ChatConversationView(viewModel: viewModel, conversationID: id)
            }
        }
        .onChange(of: searchQuery) { _, newValue in
            viewModel.searchQuery = newValue
            viewModel.searchUsers(query: newValue)
        }
    }

    // MARK: - Editorial header

    private var editorialHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text("CORRESPONDENCE")
                    .font(.system(size: 9, weight: .black))
                    .tracking(2.0)
                    .foregroundStyle(PepTheme.teal)
                Spacer()
                Text(todayLabel())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(PepTheme.textTertiary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
                        .clipShape(Circle())
                        .overlay { Circle().strokeBorder(PepTheme.separatorColor, lineWidth: 0.5) }
                }
                .buttonStyle(.plain)

                Text("Messages")
                    .font(.system(size: 34, weight: .semibold, design: .serif))
                    .kerning(-0.5)
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                let unread = viewModel.filteredConversations.reduce(0) { $0 + $1.unreadCount }
                if unread > 0 {
                    Text("\(unread) new")
                        .font(.system(.caption, design: .serif).italic())
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }

            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(height: 0.5)
                .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private func todayLabel() -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE · MMM d"
        return f.string(from: Date()).uppercased()
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)

            TextField("Search messages or find people", text: $searchQuery)
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
        }
    }

    // MARK: - Lists

    private var conversationsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if !searchQuery.isEmpty && !viewModel.searchResults.isEmpty {
                    sectionEyebrow("People")
                    ForEach(viewModel.searchResults) { user in
                        userDiscoverRow(user: user)
                        rowDivider
                    }
                    if !viewModel.filteredConversations.isEmpty {
                        sectionEyebrow("Conversations")
                            .padding(.top, 14)
                    }
                } else if !viewModel.filteredConversations.isEmpty {
                    sectionEyebrow("Inbox")
                }

                ForEach(Array(viewModel.filteredConversations.enumerated()), id: \.element.id) { index, conversation in
                    Button {
                        selectedConversationID = conversation.id
                        navigateToConversation = true
                    } label: {
                        conversationRow(conversation: conversation)
                    }
                    .buttonStyle(.plain)

                    if index < viewModel.filteredConversations.count - 1 {
                        rowDivider
                    }
                }

                if viewModel.filteredConversations.isEmpty && searchQuery.isEmpty {
                    emptyInboxState
                        .padding(.top, 60)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private var discoverSection: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                sectionEyebrow("People")
                ForEach(viewModel.searchResults) { user in
                    userDiscoverRow(user: user)
                    rowDivider
                }
            }
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
    }

    private func sectionEyebrow(_ title: String) -> some View {
        HStack(spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .black))
                .tracking(1.8)
                .foregroundStyle(PepTheme.textTertiary)
            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(height: 0.5)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(PepTheme.separatorColor.opacity(0.6))
            .frame(height: 0.5)
            .padding(.leading, 84)
    }

    // MARK: - Rows

    private func monogramAvatar(initial: String, color: Color, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(PepTheme.cardSurface)
                .overlay {
                    Circle().strokeBorder(color.opacity(0.35), lineWidth: 0.75)
                }
            Text(initial)
                .font(.system(size: size * 0.42, weight: .semibold, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
        }
        .frame(width: size, height: size)
    }

    private func userDiscoverRow(user: SocialUser) -> some View {
        Button {
            let conversationID = viewModel.startConversation(with: user)
            searchQuery = ""
            selectedConversationID = conversationID
            navigateToConversation = true
        } label: {
            HStack(spacing: 14) {
                monogramAvatar(initial: user.avatarInitial, color: user.avatarColor, size: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text(user.name)
                        .font(.system(.subheadline, design: .serif, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)

                    Text("@\(user.username)")
                        .font(.system(.caption, design: .serif).italic())
                        .foregroundStyle(PepTheme.textSecondary)
                }

                Spacer()

                Text("Message")
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.4)
                    .foregroundStyle(PepTheme.teal)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(PepTheme.teal.opacity(0.10))
                            .overlay(Capsule().strokeBorder(PepTheme.teal.opacity(0.20), lineWidth: 0.5))
                    )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private func conversationRow(conversation: Conversation) -> some View {
        HStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                monogramAvatar(initial: conversation.participant.avatarInitial,
                               color: conversation.participant.avatarColor,
                               size: 52)

                if conversation.unreadCount > 0 {
                    Circle()
                        .fill(PepTheme.teal)
                        .frame(width: 12, height: 12)
                        .overlay {
                            Circle().strokeBorder(PepTheme.background, lineWidth: 2)
                        }
                        .offset(x: 1, y: 1)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(conversation.participant.name)
                        .font(.system(.subheadline, design: .serif, weight: conversation.unreadCount > 0 ? .bold : .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    if let lastMsg = conversation.lastMessage {
                        Text(timeAgo(lastMsg.timestamp))
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(conversation.unreadCount > 0 ? PepTheme.teal : PepTheme.textTertiary)
                    }
                }

                HStack(spacing: 6) {
                    if let lastMsg = conversation.lastMessage {
                        let isFromMe = lastMsg.senderID != conversation.participant.id
                        if isFromMe {
                            Text("You·")
                                .font(.system(.caption, design: .serif).italic())
                                .foregroundStyle(PepTheme.textTertiary)
                        }
                        Text(lastMsg.text.isEmpty ? "Sent an attachment" : lastMsg.text)
                            .font(.system(.caption, design: .serif))
                            .italic(lastMsg.text.isEmpty)
                            .foregroundStyle(conversation.unreadCount > 0 ? PepTheme.textPrimary : PepTheme.textSecondary)
                            .lineLimit(1)
                    } else {
                        Text("Start the conversation")
                            .font(.system(.caption, design: .serif).italic())
                            .foregroundStyle(PepTheme.textTertiary)
                    }

                    Spacer()

                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.system(size: 10, weight: .bold, design: .serif))
                            .foregroundStyle(.white)
                            .frame(minWidth: 18, minHeight: 18)
                            .padding(.horizontal, 5)
                            .background(PepTheme.teal)
                            .clipShape(.capsule)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private var emptyInboxState: some View {
        VStack(spacing: 14) {
            Image(systemName: "envelope.open")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundStyle(PepTheme.textTertiary)

            Text("No correspondence yet")
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)

            Text("Search for someone above to begin\na conversation.")
                .font(.system(.footnote, design: .serif).italic())
                .foregroundStyle(PepTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(width: 36, height: 0.5)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    private var noResultsState: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32, weight: .ultraLight))
                .foregroundStyle(PepTheme.textTertiary)
            Text("Nothing found")
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
            Text("No conversations or people matching\n“\(searchQuery)”.")
                .font(.system(.footnote, design: .serif).italic())
                .foregroundStyle(PepTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "now" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        if interval < 604800 { return "\(Int(interval / 86400))d" }
        return "\(Int(interval / 604800))w"
    }
}
