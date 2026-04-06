import SwiftUI

struct DirectMessagesView: View {
    @State private var viewModel: MessagesViewModel
    @State private var searchQuery: String = ""
    @State private var selectedConversationID: UUID?

    init(viewModel: MessagesViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

            if !searchQuery.isEmpty && viewModel.filteredConversations.isEmpty && !viewModel.searchResults.isEmpty {
                discoverSection
            } else if !searchQuery.isEmpty && viewModel.filteredConversations.isEmpty && viewModel.searchResults.isEmpty {
                noResultsState
            } else {
                conversationsList
            }
        }
        .background(PepTheme.background.ignoresSafeArea())
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: UUID.self) { conversationID in
            ChatConversationView(viewModel: viewModel, conversationID: conversationID)
        }
        .onChange(of: searchQuery) { _, newValue in
            viewModel.searchQuery = newValue
            viewModel.searchUsers(query: newValue)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)

            TextField("Search messages or find people...", text: $searchQuery)
                .font(.subheadline)
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
        .background(PepTheme.elevated)
        .clipShape(.capsule)
    }

    private var conversationsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if !searchQuery.isEmpty && !viewModel.searchResults.isEmpty {
                    discoverHeader
                    ForEach(viewModel.searchResults) { user in
                        userDiscoverRow(user: user)
                    }
                    if !viewModel.filteredConversations.isEmpty {
                        sectionDivider(title: "Conversations")
                    }
                }

                ForEach(viewModel.filteredConversations) { conversation in
                    NavigationLink(value: conversation.id) {
                        conversationRow(conversation: conversation)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
        }
        .scrollIndicators(.hidden)
    }

    private var discoverSection: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                discoverHeader
                ForEach(viewModel.searchResults) { user in
                    userDiscoverRow(user: user)
                }
            }
            .padding(.top, 4)
        }
        .scrollIndicators(.hidden)
    }

    private var discoverHeader: some View {
        HStack {
            Text("People")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private func sectionDivider(title: String) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(height: 0.5)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

            HStack {
                Text(title)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
        }
    }

    private func userDiscoverRow(user: SocialUser) -> some View {
        Button {
            let conversationID = viewModel.startConversation(with: user)
            searchQuery = ""
            selectedConversationID = conversationID
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(user.avatarColor.opacity(0.2))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Text(user.avatarInitial)
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(user.avatarColor)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(user.name)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)

                    Text("@\(user.username)")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(PepTheme.teal)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .navigationDestination(isPresented: Binding(
            get: { selectedConversationID != nil },
            set: { if !$0 { selectedConversationID = nil } }
        )) {
            if let id = selectedConversationID {
                ChatConversationView(viewModel: viewModel, conversationID: id)
            }
        }
    }

    private func conversationRow(conversation: Conversation) -> some View {
        HStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(conversation.participant.avatarColor.opacity(0.2))
                    .frame(width: 52, height: 52)
                    .overlay {
                        Text(conversation.participant.avatarInitial)
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(conversation.participant.avatarColor)
                    }

                if conversation.unreadCount > 0 {
                    Circle()
                        .fill(PepTheme.teal)
                        .frame(width: 14, height: 14)
                        .overlay {
                            Circle().strokeBorder(PepTheme.background, lineWidth: 2)
                        }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.participant.name)
                        .font(.system(.subheadline, weight: conversation.unreadCount > 0 ? .bold : .semibold))
                        .foregroundStyle(PepTheme.textPrimary)

                    Spacer()

                    if let lastMsg = conversation.lastMessage {
                        Text(timeAgo(lastMsg.timestamp))
                            .font(.caption2)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }

                HStack(spacing: 4) {
                    if let lastMsg = conversation.lastMessage {
                        let isFromMe = lastMsg.senderID != conversation.participant.id
                        if isFromMe {
                            Text("You:")
                                .font(.system(.caption, weight: .medium))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        Text(lastMsg.text)
                            .font(.caption)
                            .foregroundStyle(conversation.unreadCount > 0 ? PepTheme.textPrimary : PepTheme.textSecondary)
                            .fontWeight(conversation.unreadCount > 0 ? .medium : .regular)
                            .lineLimit(1)
                    }

                    Spacer()

                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(PepTheme.teal)
                            .clipShape(.circle)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var noResultsState: some View {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "No Results",
            message: "No conversations or people matching \"\(searchQuery)\"."
        )
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
