import SwiftUI
import PhotosUI
import AVKit

struct GroupDetailView: View {
    @Bindable var viewModel: GroupsViewModel
    let groupID: UUID
    @State private var messageText: String = ""
    @State private var showGroupInfo: Bool = false
    @FocusState private var isInputFocused: Bool
    @State private var selectedMedia: PhotosPickerItem?
    @State private var voiceRecorder = DMVoiceRecorder()
    @State private var expandedAttachment: DirectMessageAttachment?
    @State private var selectedSection: GroupDetailSection = .chat

    private var group: FitGroup? {
        viewModel.group(for: groupID)
    }

    var body: some View {
        VStack(spacing: 0) {
            sectionTabBar
            switch selectedSection {
            case .chat:
                messagesScrollView
                inputBar
            case .stats:
                GroupStatsView(viewModel: viewModel, groupID: groupID)
            }
        }
        .appBackground()
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
        .fullScreenCover(item: $expandedAttachment) { att in
            AttachmentPreviewView(attachment: att)
        }
        .onChange(of: selectedMedia) { _, newItem in
            guard let item = newItem else { return }
            Task {
                await handlePickedMedia(item)
                selectedMedia = nil
            }
        }
    }

    private var sectionTabBar: some View {
        HStack(spacing: 0) {
            ForEach(GroupDetailSection.allCases, id: \.self) { section in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        selectedSection = section
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(section.title.uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.6)
                            .foregroundStyle(selectedSection == section ? PepTheme.textPrimary : PepTheme.textSecondary.opacity(0.75))
                        Rectangle()
                            .fill(selectedSection == section ? PepTheme.textPrimary : Color.clear)
                            .frame(height: 1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .background(
            VStack(spacing: 0) {
                Spacer()
                Rectangle()
                    .fill(PepTheme.separatorColor)
                    .frame(height: 0.6)
            }
        )
    }

    private func handlePickedMedia(_ item: PhotosPickerItem) async {
        if let data = try? await item.loadTransferable(type: Data.self) {
            let types = item.supportedContentTypes
            let isVideo = types.contains { $0.conforms(to: .movie) || $0.conforms(to: .video) || $0.conforms(to: .mpeg4Movie) || $0.conforms(to: .quickTimeMovie) }
            if isVideo {
                await viewModel.sendVideo(to: groupID, data: data, duration: nil)
            } else if let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.85) {
                await viewModel.sendImage(to: groupID, data: jpeg)
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

                ForEach(message.attachments) { att in
                    groupAttachmentView(att, isFromMe: isFromMe)
                }

                if !message.text.isEmpty {
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
                }

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

    @ViewBuilder
    private func groupAttachmentView(_ att: DirectMessageAttachment, isFromMe: Bool) -> some View {
        switch att.kind {
        case .voice:
            VoiceMessagePlayer(attachment: att, isFromMe: isFromMe)
        case .post:
            SharedPostBubble(attachment: att, isFromMe: isFromMe)
        case .image, .video:
            Button {
                expandedAttachment = att
            } label: {
                Color(.secondarySystemBackground)
                    .frame(width: 200, height: 240)
                    .overlay {
                        switch att.kind {
                        case .image:
                            AsyncImage(url: URL(string: att.url)) { phase in
                                if let image = phase.image {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } else if phase.error != nil {
                                    Image(systemName: "photo").foregroundStyle(.secondary)
                                } else {
                                    ProgressView()
                                }
                            }
                            .allowsHitTesting(false)
                        case .video:
                            ZStack {
                                Color.black
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.white)
                            }
                            .allowsHitTesting(false)
                        case .voice, .post:
                            EmptyView()
                        }
                    }
                    .clipShape(.rect(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var inputBar: some View {
        if voiceRecorder.isRecording {
            voiceRecordingBar
        } else {
            textInputBar
        }
    }

    private var voiceRecordingBar: some View {
        HStack(spacing: 12) {
            Button {
                voiceRecorder.cancel()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            HStack(spacing: 10) {
                Circle().fill(.red).frame(width: 10, height: 10)
                Text(formatVoiceDuration(voiceRecorder.duration))
                    .font(.system(.subheadline, design: .monospaced, weight: .medium))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                Text("Recording…").font(.caption).foregroundStyle(PepTheme.textSecondary)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(PepTheme.elevated).clipShape(.capsule)
            Button {
                if let (data, duration) = voiceRecorder.finish() {
                    Task { await viewModel.sendVoice(to: groupID, data: data, duration: duration) }
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(PepTheme.teal)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(
            PepTheme.cardSurface
                .shadow(color: .black.opacity(0.05), radius: 8, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var textInputBar: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $selectedMedia, matching: .any(of: [.images, .videos])) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(viewModel.uploadingAttachment ? PepTheme.textSecondary : PepTheme.teal)
            }
            .disabled(viewModel.uploadingAttachment)

            TextField("Message...", text: $messageText, axis: .vertical)
                .font(.subheadline)
                .lineLimit(1...5)
                .focused($isInputFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(PepTheme.elevated)
                .clipShape(.capsule)

            if messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    voiceRecorder.start()
                } label: {
                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(PepTheme.teal)
                }
                .disabled(viewModel.uploadingAttachment)
            } else {
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(PepTheme.teal)
                }
                .sensoryFeedback(.impact(weight: .light), trigger: group?.messages.count ?? 0)
            }
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

nonisolated enum GroupDetailSection: String, CaseIterable, Sendable {
    case chat
    case stats

    var title: String {
        switch self {
        case .chat: return "Chat"
        case .stats: return "Stats"
        }
    }
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
            .appBackground()
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
