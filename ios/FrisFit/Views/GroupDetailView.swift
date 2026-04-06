import SwiftUI

struct GroupDetailView: View {
    @Bindable var viewModel: GroupsViewModel
    let groupID: UUID
    @State private var messageText: String = ""
    @State private var showGroupInfo: Bool = false
    @FocusState private var isInputFocused: Bool

    private var group: FitGroup? {
        viewModel.group(for: groupID)
    }

    var body: some View {
        VStack(spacing: 0) {
            messagesScrollView
            inputBar
        }
        .background(PepTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if let group {
                    Button {
                        showGroupInfo = true
                    } label: {
                        HStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(group.accentColor.opacity(0.15))
                                    .frame(width: 28, height: 28)

                                Image(systemName: group.iconName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(group.accentColor)
                            }

                            VStack(alignment: .leading, spacing: 0) {
                                Text(group.name)
                                    .font(.system(.subheadline, weight: .semibold))
                                    .foregroundStyle(PepTheme.textPrimary)

                                Text("\(group.memberCount) members")
                                    .font(.system(size: 10))
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showGroupInfo) {
            if let group {
                GroupInfoSheet(group: group, viewModel: viewModel)
            }
        }
    }

    private var messagesScrollView: some View {
        ScrollView {
            ScrollViewReader { proxy in
                LazyVStack(spacing: 4) {
                    if let group {
                        groupHeaderBanner(group)
                            .padding(.bottom, 8)

                        ForEach(groupedMessages(group.messages), id: \.date) { messageGroup in
                            dateDivider(messageGroup.date)
                                .padding(.top, 8)
                                .padding(.bottom, 4)

                            ForEach(messageGroup.messages) { message in
                                groupMessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .onChange(of: group?.messages.count) { _, _ in
                    if let lastID = group?.messages.last?.id {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    if let lastID = group?.messages.last?.id {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private func groupHeaderBanner(_ group: FitGroup) -> some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(group.accentColor.opacity(0.1))
                    .frame(width: 64, height: 64)

                Image(systemName: group.iconName)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(group.accentColor)
            }

            Text(group.name)
                .font(.system(.headline, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)

            Text(group.description)
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            HStack(spacing: 12) {
                Label("\(group.memberCount) members", systemImage: "person.2.fill")
                Label(group.privacy.rawValue, systemImage: group.privacy.icon)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(PepTheme.textSecondary)
        }
        .padding(.vertical, 16)
    }

    private func groupMessageBubble(message: GroupMessage) -> some View {
        let isFromMe = message.sender.username == "me"

        return HStack(alignment: .top, spacing: 8) {
            if !isFromMe {
                Circle()
                    .fill(message.sender.avatarColor.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Text(message.sender.avatarInitial)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(message.sender.avatarColor)
                    }
            }

            if isFromMe { Spacer(minLength: 50) }

            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 3) {
                if !isFromMe {
                    Text(message.sender.name.components(separatedBy: " ").first ?? "")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(message.sender.avatarColor)
                        .padding(.leading, 4)
                }

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

                HStack(spacing: 8) {
                    Text(formatTime(message.timestamp))
                        .font(.system(size: 10))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.6))

                    if message.likeCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.red.opacity(0.7))
                            Text("\(message.likeCount)")
                                .font(.system(size: 10))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }

            if !isFromMe { Spacer(minLength: 50) }
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button {
                viewModel.toggleMessageLike(groupID: groupID, messageID: message.id)
            } label: {
                Label(message.isLiked ? "Unlike" : "Like", systemImage: message.isLiked ? "heart.slash" : "heart")
            }

            Button(role: .destructive) {} label: {
                Label("Report", systemImage: "exclamationmark.bubble")
            }
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
            .sensoryFeedback(.impact(weight: .light), trigger: group?.messages.count ?? 0)
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
        viewModel.sendMessage(to: groupID, text: trimmed)
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

    private func groupedMessages(_ messages: [GroupMessage]) -> [GroupMessageGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: messages) { msg in
            calendar.startOfDay(for: msg.timestamp)
        }
        return grouped.map { GroupMessageGroup(date: $0.key, messages: $0.value.sorted { $0.timestamp < $1.timestamp }) }
            .sorted { $0.date < $1.date }
    }
}

private struct GroupMessageGroup {
    let date: Date
    let messages: [GroupMessage]
}

struct GroupInfoSheet: View {
    let group: FitGroup
    @Bindable var viewModel: GroupsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(group.accentColor.opacity(0.12))
                                .frame(width: 80, height: 80)

                            Image(systemName: group.iconName)
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundStyle(group.accentColor)
                        }

                        Text(group.name)
                            .font(.system(.title3, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)

                        HStack(spacing: 12) {
                            Label(group.privacy.rawValue, systemImage: group.privacy.icon)
                            Label("\(group.memberCount) members", systemImage: "person.2.fill")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)

                        Text(group.description)
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Members")
                            .font(.system(.subheadline, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                            .padding(.horizontal, 20)

                        ForEach(group.members) { member in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(member.user.avatarColor.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                    .overlay {
                                        Text(member.user.avatarInitial)
                                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                                            .foregroundStyle(member.user.avatarColor)
                                    }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(member.user.name)
                                        .font(.system(.subheadline, weight: .medium))
                                        .foregroundStyle(PepTheme.textPrimary)

                                    Text("@\(member.user.username)")
                                        .font(.caption)
                                        .foregroundStyle(PepTheme.textSecondary)
                                }

                                Spacer()

                                if member.role != .member {
                                    HStack(spacing: 3) {
                                        Image(systemName: member.role.icon)
                                            .font(.system(size: 10))
                                        Text(member.role.rawValue)
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    .foregroundStyle(member.role == .owner ? PepTheme.amber : PepTheme.violet)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        (member.role == .owner ? PepTheme.amber : PepTheme.violet).opacity(0.12)
                                    )
                                    .clipShape(.capsule)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 4)
                        }
                    }

                    Button(role: .destructive) {
                        viewModel.leaveGroup(group.id)
                        dismiss()
                    } label: {
                        Text("Leave Group")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.red.opacity(0.1))
                            .clipShape(.rect(cornerRadius: 12))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
                .padding(.bottom, 20)
            }
            .background(PepTheme.background.ignoresSafeArea())
            .navigationTitle("Group Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PepTheme.teal)
                }
            }
        }
    }
}
