import SwiftUI
import PhotosUI
import AVKit
import AVFoundation

struct ChatConversationView: View {
    // Anchor the observable view model in @State so SwiftUI's Observation
    // tracking reliably re-renders this view whenever the shared messaging
    // brain mutates (optimistic insert, server confirm, realtime push). A
    // bare computed property returning the singleton was NOT triggering body
    // re-evaluation in some cases, which is why the bubble would never
    // appear even though the array was being mutated correctly.
    @State private var viewModel: MessagesViewModel = .shared
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

    init(viewModel: MessagesViewModel = .shared, conversationID: UUID) {
        self.conversationID = conversationID
    }

    /// Index of this conversation inside the shared brain. Reading this in
    /// body establishes the observation dependency on `viewModel.conversations`
    /// so any append / replace anywhere in the array re-renders the view.
    private var conversationIndex: Int? {
        viewModel.conversations.firstIndex(where: { $0.id == conversationID })
    }

    private var conversation: Conversation? {
        guard let idx = conversationIndex else { return nil }
        return viewModel.conversations[idx]
    }

    /// Pulled directly out of the observed array on every body pass — never
    /// snapshotted into a local `let` outside body — so the message list
    /// updates the instant a bubble is appended.
    private var messages: [DirectMessage] {
        guard let idx = conversationIndex else { return [] }
        return viewModel.conversations[idx].messages
    }

    var body: some View {
        VStack(spacing: 0) {
            messagesScrollView
            inputBar
        }
        .appBackground()
        .navigationBarTitleDisplayMode(.inline)
        .floatingTopBar {
            FloatingNavButton(systemImage: "chevron.left") { dismiss() }
        } trailing: {
            Menu {
                Button(role: .destructive) { showReport = true } label: {
                    Label("Report", systemImage: "flag")
                }
                Button(role: .destructive) { showBlockConfirm = true } label: {
                    Label("Block User", systemImage: "hand.raised")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(PepTheme.separatorColor, lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 3)
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

    // MARK: - Floating header title

    @ViewBuilder
    private func floatingHeaderTitle(participant: SocialUser) -> some View {
        VStack(spacing: 2) {
            Text("CORRESPONDENCE WITH")
                .font(.system(size: 8, weight: .black))
                .tracking(1.8)
                .foregroundStyle(PepTheme.textTertiary)
            Text(participant.name)
                .font(.system(.subheadline, design: .serif, weight: .semibold))
                .kerning(-0.2)
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }

    // MARK: - Editorial nav bar (unused after floating bar migration)

    private var editorialNavBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
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

                Spacer()

                if let participant = conversation?.participant {
                    VStack(spacing: 2) {
                        Text("CORRESPONDENCE WITH")
                            .font(.system(size: 8, weight: .black))
                            .tracking(1.8)
                            .foregroundStyle(PepTheme.textTertiary)
                        Text(participant.name)
                            .font(.system(.headline, design: .serif, weight: .semibold))
                            .kerning(-0.2)
                            .foregroundStyle(PepTheme.textPrimary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Menu {
                    Button(role: .destructive) { showReport = true } label: {
                        Label("Report", systemImage: "flag")
                    }
                    Button(role: .destructive) { showBlockConfirm = true } label: {
                        Label("Block User", systemImage: "hand.raised")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
                        .clipShape(Circle())
                        .overlay { Circle().strokeBorder(PepTheme.separatorColor, lineWidth: 0.5) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(height: 0.5)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Messages

    private var messagesScrollView: some View {
        ScrollView {
            ScrollViewReader { proxy in
                LazyVStack(spacing: 6) {
                    // Spacer so the first message clears the floating top buttons.
                    Color.clear.frame(height: 56)

                    if let convo = conversation {
                        floatingHeaderTitle(participant: convo.participant)
                    }

                    if let convo = conversation, messages.isEmpty {
                        emptyConversationHeader(participant: convo.participant)
                            .padding(.top, 16)
                    }

                    if let convo = conversation {
                        let _ = print("DM_RENDER: convo=\(convo.id) participant=\(convo.participant.id) messageCount=\(messages.count)")
                        ForEach(groupedMessages(messages), id: \.date) { group in
                            dateDivider(group.date)
                                .padding(.top, 16)
                                .padding(.bottom, 6)

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
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .animation(.easeInOut(duration: 0.2), value: viewModel.typingUserIds)
                .onChange(of: messages.count) { _, _ in
                    if let lastID = messages.last?.id {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    if let lastID = messages.last?.id {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private func emptyConversationHeader(participant: SocialUser) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .strokeBorder(participant.avatarColor.opacity(0.35), lineWidth: 0.75)
                    .frame(width: 84, height: 84)
                Text(participant.avatarInitial)
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
            }

            VStack(spacing: 6) {
                Text("BEGINNING OF CORRESPONDENCE")
                    .font(.system(size: 9, weight: .black))
                    .tracking(2.0)
                    .foregroundStyle(PepTheme.teal)
                Text(participant.name)
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .kerning(-0.4)
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Say hello to begin the conversation.")
                    .font(.system(.footnote, design: .serif).italic())
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(width: 36, height: 0.5)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func attachmentView(_ att: DirectMessageAttachment, isFromMe: Bool) -> some View {
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
                        case .voice, .post:
                            EmptyView()
                        }
                    }
                    .clipShape(.rect(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
                    }
            }
            .buttonStyle(.plain)
        }
    }

    private func messageBubble(message: DirectMessage, isFromMe: Bool) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromMe { Spacer(minLength: 56) }

            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 6) {
                ForEach(message.attachments) { att in
                    attachmentView(att, isFromMe: isFromMe)
                }

                if !message.text.isEmpty {
                    Text(message.text)
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(isFromMe ? .white : PepTheme.textPrimary)
                        .lineSpacing(2)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Group {
                                if isFromMe {
                                    LinearGradient(
                                        colors: [PepTheme.teal, PepTheme.teal.opacity(0.88)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                } else {
                                    PepTheme.cardSurface
                                }
                            }
                        )
                        .clipShape(.rect(
                            topLeadingRadius: isFromMe ? 18 : 4,
                            bottomLeadingRadius: 18,
                            bottomTrailingRadius: isFromMe ? 4 : 18,
                            topTrailingRadius: 18
                        ))
                        .overlay {
                            if !isFromMe {
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 4,
                                    bottomLeadingRadius: 18,
                                    bottomTrailingRadius: 18,
                                    topTrailingRadius: 18
                                )
                                .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
                            }
                        }
                }

                HStack(spacing: 5) {
                    Text(formatTime(message.timestamp))
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(PepTheme.textTertiary)
                    if isFromMe {
                        Image(systemName: message.isRead ? "checkmark.circle.fill" : "checkmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(message.isRead ? PepTheme.teal : PepTheme.textTertiary)
                    }
                }
                .padding(.horizontal, 4)
            }

            if !isFromMe { Spacer(minLength: 56) }
        }
    }

    private func dateDivider(_ date: Date) -> some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(height: 0.5)
            Text(formatDateHeader(date).uppercased())
                .font(.system(size: 9, weight: .black))
                .tracking(1.8)
                .foregroundStyle(PepTheme.textTertiary)
                .fixedSize()
            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(height: 0.5)
        }
    }

    // MARK: - Input

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
                Circle().fill(.red).frame(width: 8, height: 8)
                    .phaseAnimator([0.3, 1.0]) { content, phase in
                        content.opacity(phase)
                    } animation: { _ in .easeInOut(duration: 0.7).repeatForever(autoreverses: true) }
                Text("RECORDING")
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.8)
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                Text(formatVoiceDuration(voiceRecorder.duration))
                    .font(.system(.subheadline, design: .monospaced, weight: .medium))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
            }

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
        .background(inputBarBackground)
    }

    private var textInputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            PhotosPicker(selection: $selectedMedia, matching: .any(of: [.images, .videos])) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(viewModel.uploadingAttachment ? PepTheme.textSecondary : PepTheme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
                    .clipShape(Circle())
                    .overlay { Circle().strokeBorder(PepTheme.separatorColor, lineWidth: 0.5) }
            }
            .disabled(viewModel.uploadingAttachment)

            TextField("Write a message…", text: $messageText, axis: .vertical)
                .font(.system(.subheadline, design: .serif))
                .lineLimit(1...5)
                .focused($isInputFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
                .clipShape(.rect(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
                }
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
                    Image(systemName: "mic.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(PepTheme.teal)
                        .clipShape(Circle())
                }
                .disabled(viewModel.uploadingAttachment)
                .sensoryFeedback(.impact(weight: .medium), trigger: voiceRecorder.isRecording)
            } else {
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            LinearGradient(
                                colors: [PepTheme.teal, PepTheme.teal.opacity(0.88)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                }
                .sensoryFeedback(.impact(weight: .light), trigger: messages.count)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(inputBarBackground)
        .overlay(alignment: .top) {
            if viewModel.uploadingAttachment {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7)
                    Text("UPLOADING")
                        .font(.system(size: 9, weight: .black))
                        .tracking(1.8)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(PepTheme.cardSurface)
                        .overlay(Capsule().fill(PepTheme.cardOverlay))
                        .overlay(Capsule().strokeBorder(PepTheme.separatorColor, lineWidth: 0.5))
                )
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

    private var inputBarBackground: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(.ultraThinMaterial)
            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(height: 0.5)
        }
        .ignoresSafeArea(edges: .bottom)
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
            .background(PepTheme.cardSurface)
            .clipShape(.rect(topLeadingRadius: 4, bottomLeadingRadius: 18, bottomTrailingRadius: 18, topTrailingRadius: 18))
            .overlay {
                UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 18, bottomTrailingRadius: 18, topTrailingRadius: 18)
                    .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
            }

            Spacer(minLength: 56)
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
