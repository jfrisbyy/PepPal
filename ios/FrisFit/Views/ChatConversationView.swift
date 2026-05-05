import SwiftUI
import PhotosUI
import AVKit
import AVFoundation

struct ChatConversationView: View {
    @State private var viewModel: MessagesViewModel
    let conversationID: UUID
    @State private var messageText: String = ""
    @FocusState private var isInputFocused: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var hasLoadedMessages: Bool = false
    @State private var showReport: Bool = false
    @State private var showBlockConfirm: Bool = false
    @State private var selectedMedia: PhotosPickerItem?
    @State private var expandedAttachment: DirectMessageAttachment?
    @State private var voiceRecorder = DMVoiceRecorder()

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
        .appBackground()
        .navigationTitle(conversation?.participant.name ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showReport = true
                    } label: {
                        Label("Report", systemImage: "flag")
                    }
                    Button(role: .destructive) {
                        showBlockConfirm = true
                    } label: {
                        Label("Block User", systemImage: "hand.raised")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(PepTheme.teal)
                }
            }
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
            await viewModel.subscribeRealtime(conversationID: conversationID)
        }
        .onDisappear {
            Task { await viewModel.unsubscribeRealtime() }
        }
        .sheet(isPresented: $showReport) {
            if let pid = conversation?.participant.id.uuidString {
                ReportContentSheet(targetType: "user", targetId: pid)
            }
        }
        .fullScreenCover(item: $expandedAttachment) { att in
            AttachmentPreviewView(attachment: att)
        }
        .alert("Block this user?", isPresented: $showBlockConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Block", role: .destructive) {
                guard let pid = conversation?.participant.id.uuidString else { return }
                Task {
                    if let userId = try? AuthService.shared.currentUserId() {
                        try? await ModerationService.shared.block(blockerId: userId, blockedId: pid)
                        dismiss()
                    }
                }
            }
        } message: {
            Text("You won't see their messages or posts.")
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
                                    .onAppear {
                                        if !isFromMe && !message.isRead {
                                            viewModel.markMessageVisible(conversationID: conversationID, messageID: message.id)
                                        }
                                    }
                            }
                        }
                        if viewModel.isParticipantTyping(in: conversationID) {
                            typingIndicator
                                .id("typing-indicator")
                                .transition(.opacity.combined(with: .move(edge: .leading)))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .animation(.easeInOut(duration: 0.2), value: viewModel.typingUserIds)
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

    @ViewBuilder
    private func attachmentView(_ att: DirectMessageAttachment, isFromMe: Bool) -> some View {
        switch att.kind {
        case .voice:
            VoiceMessagePlayer(attachment: att, isFromMe: isFromMe)
        case .image, .video:
            Button {
                expandedAttachment = att
            } label: {
                Color(.secondarySystemBackground)
                    .frame(width: 220, height: 260)
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
                                    .font(.system(size: 44))
                                    .foregroundStyle(.white)
                            }
                            .allowsHitTesting(false)
                        case .voice:
                            EmptyView()
                        }
                    }
                    .clipShape(.rect(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
    }

    private func messageBubble(message: DirectMessage, isFromMe: Bool) -> some View {
        HStack {
            if isFromMe { Spacer(minLength: 60) }

            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 6) {
                ForEach(message.attachments) { att in
                    attachmentView(att, isFromMe: isFromMe)
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

                HStack(spacing: 4) {
                    Text(formatTime(message.timestamp))
                        .font(.system(size: 10))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
                    if isFromMe {
                        Image(systemName: message.isRead ? "checkmark.circle.fill" : "checkmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(message.isRead ? PepTheme.teal : PepTheme.textSecondary.opacity(0.6))
                    }
                }
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
                    .phaseAnimator([0.3, 1.0]) { content, phase in
                        content.opacity(phase)
                    } animation: { _ in .easeInOut(duration: 0.7).repeatForever(autoreverses: true) }
                Text(formatVoiceDuration(voiceRecorder.duration))
                    .font(.system(.subheadline, design: .monospaced, weight: .medium))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                Text("Recording…")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(PepTheme.elevated)
            .clipShape(.capsule)

            Button {
                if let (data, duration) = voiceRecorder.finish() {
                    Task { await viewModel.uploadAndSendVoice(to: conversationID, data: data, duration: duration) }
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(PepTheme.teal)
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
                .onChange(of: messageText) { _, newValue in
                    if !newValue.isEmpty {
                        viewModel.sendTypingSignal()
                    } else {
                        viewModel.stopTypingSignal()
                    }
                }

            if messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    voiceRecorder.start()
                } label: {
                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(PepTheme.teal)
                }
                .disabled(viewModel.uploadingAttachment)
                .sensoryFeedback(.impact(weight: .medium), trigger: voiceRecorder.isRecording)
            } else {
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(PepTheme.teal)
                }
                .sensoryFeedback(.impact(weight: .light), trigger: conversation?.messages.count ?? 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            PepTheme.cardSurface
                .shadow(color: .black.opacity(0.05), radius: 8, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            if viewModel.uploadingAttachment {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.8)
                    Text("Uploading…").font(.caption).foregroundStyle(PepTheme.textSecondary)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(PepTheme.elevated, in: Capsule())
                .offset(y: -32)
            }
        }
        .onChange(of: selectedMedia) { _, newItem in
            guard let item = newItem else { return }
            Task {
                await handlePickedMedia(item)
                selectedMedia = nil
            }
        }
    }

    private func handlePickedMedia(_ item: PhotosPickerItem) async {
        if let data = try? await item.loadTransferable(type: Data.self) {
            let types = item.supportedContentTypes
            let isVideo = types.contains { $0.conforms(to: .movie) || $0.conforms(to: .video) || $0.conforms(to: .mpeg4Movie) || $0.conforms(to: .quickTimeMovie) }
            if isVideo {
                await viewModel.uploadAndSendVideo(to: conversationID, data: data, duration: nil)
            } else if let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.85) {
                await viewModel.uploadAndSendImage(to: conversationID, data: jpeg)
            }
        }
    }

    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.sendMessage(to: conversationID, text: trimmed)
        viewModel.stopTypingSignal()
        messageText = ""
    }

    private var typingIndicator: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(PepTheme.textSecondary)
                        .frame(width: 6, height: 6)
                        .opacity(0.5)
                        .scaleEffect(1.0)
                        .phaseAnimator([0, 1, 0], trigger: true) { content, phase in
                            content.opacity(phase == 1 ? 1.0 : 0.3)
                        } animation: { _ in
                            .easeInOut(duration: 0.6).delay(Double(i) * 0.15).repeatForever(autoreverses: true)
                        }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(PepTheme.elevated)
            .clipShape(.rect(topLeadingRadius: 6, bottomLeadingRadius: 18, bottomTrailingRadius: 18, topTrailingRadius: 18))

            Spacer(minLength: 60)
        }
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
