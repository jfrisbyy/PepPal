import SwiftUI

struct PepChatView: View {
    let planContext: String?

    @State private var viewModel: PepChatViewModel
    @FocusState private var isInputFocused: Bool
    @State private var showQuickActions: Bool = false
    @State private var recorder = WhisperRecorder()
    @State private var showMicPermissionAlert: Bool = false

    @Environment(\.dismiss) private var dismiss

    init(planContext: String? = nil) {
        self.planContext = planContext
        self._viewModel = State(initialValue: PepChatViewModel(planContext: planContext))
    }

    var body: some View {
        VStack(spacing: 0) {
            pepNavBar

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        pepProfileHeader
                            .padding(.bottom, 20)

                        ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                            let showTimestamp = shouldShowTimestamp(at: index)

                            if showTimestamp {
                                timestampDivider(message.timestamp)
                                    .padding(.top, index == 0 ? 0 : 18)
                                    .padding(.bottom, 10)
                            }

                            switch message.role {
                            case .pep:
                                PepBubble(message: message, viewModel: viewModel, showAvatar: shouldShowPepAvatar(at: index))
                                    .padding(.top, isSameRoleAsPrevious(at: index) && !showTimestamp ? 4 : 12)
                            case .user:
                                UserBubble(text: message.content)
                                    .padding(.top, isSameRoleAsPrevious(at: index) && !showTimestamp ? 4 : 12)
                            }
                        }

                        if viewModel.isGenerating {
                            PepTypingBubble()
                                .padding(.top, 12)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.messages.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onChange(of: viewModel.isGenerating) { _, _ in
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }

            pepInputBar
        }
        .appBackground()
    }

    // MARK: - Nav bar

    private var pepNavBar: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(PepTheme.elevated.opacity(0.7))
                        .clipShape(Circle())
                }

                Spacer()

                VStack(spacing: 1) {
                    Text("CONVERSATION")
                        .font(.system(size: 9, weight: .black))
                        .tracking(1.8)
                        .foregroundStyle(PepTheme.textTertiary)
                    Text("Pep")
                        .font(.system(.headline, design: .serif, weight: .semibold))
                        .kerning(-0.2)
                        .foregroundStyle(PepTheme.textPrimary)
                }

                Spacer()

                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(height: 0.5)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Profile header

    private var pepProfileHeader: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [PepTheme.teal.opacity(0.5), PepTheme.violet.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .frame(width: 84, height: 84)
                PepNavAvatar(size: 72)
            }

            VStack(spacing: 6) {
                Text("PEPTIDE RESEARCH COMPANION")
                    .font(.system(size: 9, weight: .black))
                    .tracking(2.0)
                    .foregroundStyle(PepTheme.teal)

                Text("Pep")
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                    .kerning(-0.5)
                    .foregroundStyle(PepTheme.textPrimary)

                Text("A thoughtful guide to your protocol — \nask anything, get clear answers.")
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(PepTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.top, 2)
            }

            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 9, weight: .bold))
                Text("Educational only · not medical advice")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.3)
            }
            .foregroundStyle(PepTheme.amber)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(PepTheme.amber.opacity(0.10))
                    .overlay(
                        Capsule()
                            .strokeBorder(PepTheme.amber.opacity(0.18), lineWidth: 0.5)
                    )
            )

            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(width: 36, height: 0.5)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 28)
    }

    // MARK: - Timestamp divider

    private func timestampDivider(_ date: Date) -> some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(height: 0.5)
            Text(date.formatted(.dateTime.hour().minute()))
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textTertiary)
            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(height: 0.5)
        }
    }

    // MARK: - Input bar

    private var pepInputBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(height: 0.5)

            HStack(alignment: .bottom, spacing: 10) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        showQuickActions.toggle()
                    }
                } label: {
                    Image(systemName: showQuickActions ? "xmark" : "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(PepTheme.elevated)
                                .overlay(
                                    Circle().strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
                                )
                        )
                        .contentTransition(.symbolEffect(.replace))
                }

                HStack(alignment: .bottom, spacing: 0) {
                    TextField("Message Pep…", text: $viewModel.inputText, axis: .vertical)
                        .lineLimit(1...5)
                        .font(.system(size: 15, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                        .focused($isInputFocused)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                    if viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            handleMicTap()
                        } label: {
                            Image(systemName: recorder.isRecording ? "stop.fill" : (recorder.isTranscribing ? "waveform" : "mic.fill"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(recorder.isRecording ? PepTheme.danger : PepTheme.textSecondary)
                                .symbolEffect(.pulse, isActive: recorder.isRecording || recorder.isTranscribing)
                                .frame(width: 30, height: 30)
                        }
                        .padding(.trailing, 6)
                        .disabled(recorder.isTranscribing)
                    } else {
                        Button {
                            viewModel.sendMessage()
                        } label: {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(PepTheme.invertedText)
                                .frame(width: 30, height: 30)
                                .background(
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [PepTheme.teal, PepTheme.violet.opacity(0.85)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                        }
                        .disabled(viewModel.isGenerating)
                        .sensoryFeedback(.impact(weight: .light), trigger: viewModel.messages.count)
                        .padding(.trailing, 4)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(PepTheme.elevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
                )
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: viewModel.inputText.isEmpty)

            if showQuickActions {
                quickActionsRow
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if recorder.isRecording {
                recordingIndicator
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: recorder.isRecording)
        .alert("Microphone Access", isPresented: $showMicPermissionAlert) {
            Button("OK") {}
        } message: {
            Text("Enable microphone access in Settings to use voice input.")
        }
        .background(
            PepTheme.background
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var quickActionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                QuickActionPill(icon: "pill.fill", label: "Peptides", color: PepTheme.teal) {
                    viewModel.inputText = "Tell me about BPC-157"
                    showQuickActions = false
                }
                QuickActionPill(icon: "function", label: "Reconstitution", color: PepTheme.blue) {
                    viewModel.inputText = "Help me with reconstitution math"
                    showQuickActions = false
                }
                QuickActionPill(icon: "syringe.fill", label: "Injection", color: PepTheme.coral) {
                    viewModel.inputText = "Where should I inject next?"
                    showQuickActions = false
                }
                QuickActionPill(icon: "dumbbell.fill", label: "Training", color: PepTheme.violet) {
                    viewModel.inputText = "What should I train today?"
                    showQuickActions = false
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .scrollClipDisabled()
    }

    private var recordingIndicator: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(PepTheme.danger)
                .frame(width: 7, height: 7)
                .symbolEffect(.pulse, options: .repeating)
            Text("Listening · tap stop when done")
                .font(.system(size: 12, weight: .medium, design: .serif))
                .foregroundStyle(PepTheme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
    }

    private func handleMicTap() {
        if recorder.isRecording {
            Task {
                if let text = await recorder.stopRecordingAndTranscribe(), !text.isEmpty {
                    viewModel.submitTranscribedText(text)
                }
            }
        } else {
            Task {
                let granted = await recorder.requestPermission()
                guard granted else {
                    showMicPermissionAlert = true
                    return
                }
                do {
                    try recorder.startRecording()
                } catch {
                    recorder.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func shouldShowTimestamp(at index: Int) -> Bool {
        guard index > 0 else { return true }
        let current = viewModel.messages[index].timestamp
        let previous = viewModel.messages[index - 1].timestamp
        return current.timeIntervalSince(previous) > 300
    }

    private func isSameRoleAsPrevious(at index: Int) -> Bool {
        guard index > 0 else { return false }
        return viewModel.messages[index].role == viewModel.messages[index - 1].role
    }

    private func shouldShowPepAvatar(at index: Int) -> Bool {
        let messages = viewModel.messages
        if index + 1 < messages.count {
            if messages[index + 1].role == .pep {
                let timeDiff = messages[index + 1].timestamp.timeIntervalSince(messages[index].timestamp)
                if timeDiff < 300 { return false }
            }
        }
        return true
    }
}

typealias FinnChatView = PepChatView

// MARK: - Quick action pill

struct QuickActionPill: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(PepTheme.elevated)
            )
            .overlay(
                Capsule()
                    .strokeBorder(color.opacity(0.25), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// Kept for any external references.
struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        QuickActionPill(icon: icon, label: label, color: color, action: action)
    }
}

// MARK: - Avatar

struct PepNavAvatar: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [PepTheme.teal, PepTheme.violet.opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            Text("P")
                .font(.system(size: size * 0.42, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
        }
    }
}

typealias FinnNavAvatar = PepNavAvatar

// MARK: - Pep bubble

struct PepBubble: View {
    let message: PepMessage
    let viewModel: PepChatViewModel
    let showAvatar: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if showAvatar {
                PepNavAvatar(size: 26)
                    .padding(.top, 2)
            } else {
                Color.clear.frame(width: 26)
            }

            VStack(alignment: .leading, spacing: 6) {
                if showAvatar {
                    Text("PEP")
                        .font(.system(size: 9, weight: .black))
                        .tracking(1.6)
                        .foregroundStyle(PepTheme.teal)
                }

                buildContent(message.content, exerciseNames: message.exerciseNames)
                    .font(.system(size: 15, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineSpacing(3)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(PepTheme.cardSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
                    )
            }

            Spacer(minLength: 40)
        }
    }

    @ViewBuilder
    private func buildContent(_ content: String, exerciseNames: [String]) -> some View {
        if exerciseNames.isEmpty {
            Text(content)
        } else {
            ExerciseLinkText(content: content, exerciseNames: exerciseNames, viewModel: viewModel)
        }
    }
}

typealias FinnBubble = PepBubble

// MARK: - User bubble

struct UserBubble: View {
    let text: String

    var body: some View {
        HStack {
            Spacer(minLength: 50)
            Text(text)
                .font(.system(size: 15, design: .serif))
                .foregroundStyle(.white)
                .lineSpacing(3)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [PepTheme.violet, PepTheme.violet.opacity(0.82)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        }
    }
}

// MARK: - Typing bubble

struct PepTypingBubble: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            PepNavAvatar(size: 26)
                .padding(.top, 2)

            TypingDots()
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(PepTheme.cardSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
                )

            Spacer()
        }
    }
}

typealias FinnTypingBubble = PepTypingBubble

struct TypingDots: View {
    @State private var phase: Int = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(PepTheme.textSecondary.opacity(phase == index ? 0.9 : 0.30))
                    .frame(width: 6, height: 6)
                    .scaleEffect(phase == index ? 1.2 : 1.0)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    phase = (phase + 1) % 3
                }
            }
        }
    }
}

// MARK: - Exercise link text

struct ExerciseLinkText: View {
    let content: String
    let exerciseNames: [String]
    let viewModel: PepChatViewModel

    @State private var selectedExercise: Exercise?

    var body: some View {
        let parts = splitContentByExercises(content, exerciseNames: exerciseNames)

        WrappingTextFlow(parts: parts, onExerciseTap: { name in
            if let exercise = viewModel.findExercise(named: name) {
                selectedExercise = exercise
            }
        })
        .navigationDestination(item: $selectedExercise) { exercise in
            ExerciseDetailView(exercise: exercise, viewModel: ExerciseLibraryViewModel())
        }
    }

    private func splitContentByExercises(_ text: String, exerciseNames: [String]) -> [TextPart] {
        var parts: [TextPart] = []
        var remaining = text

        while !remaining.isEmpty {
            var earliestRange: Range<String.Index>?
            var earliestName: String?

            for name in exerciseNames {
                if let range = remaining.range(of: name) {
                    if earliestRange == nil || range.lowerBound < earliestRange!.lowerBound {
                        earliestRange = range
                        earliestName = name
                    }
                }
            }

            if let range = earliestRange, let name = earliestName {
                let before = String(remaining[remaining.startIndex..<range.lowerBound])
                if !before.isEmpty {
                    parts.append(TextPart(text: before, isExercise: false))
                }
                parts.append(TextPart(text: name, isExercise: true))
                remaining = String(remaining[range.upperBound...])
            } else {
                parts.append(TextPart(text: remaining, isExercise: false))
                remaining = ""
            }
        }

        return parts
    }
}

nonisolated struct TextPart: Identifiable, Sendable {
    let id = UUID()
    let text: String
    let isExercise: Bool
}

struct WrappingTextFlow: View {
    let parts: [TextPart]
    let onExerciseTap: (String) -> Void

    var body: some View {
        var result = Text("")

        for part in parts {
            if part.isExercise {
                result = result + Text(part.text)
                    .fontWeight(.semibold)
                    .foregroundColor(PepTheme.teal)
                    .underline(color: PepTheme.teal.opacity(0.4))
            } else {
                result = result + Text(part.text)
                    .foregroundColor(PepTheme.textPrimary)
            }
        }

        return result
            .lineSpacing(3)
    }
}

// MARK: - Animated avatar wrappers

struct FinnAvatar: View {
    let size: CGFloat
    var isAnimating: Bool = false

    var body: some View {
        PepNavAvatar(size: size)
            .scaleEffect(isAnimating ? 1.06 : 1.0)
            .animation(
                isAnimating ?
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true) :
                    .default,
                value: isAnimating
            )
    }
}

struct PepAvatar: View {
    let size: CGFloat
    var isAnimating: Bool = false

    var body: some View {
        PepNavAvatar(size: size)
            .scaleEffect(isAnimating ? 1.06 : 1.0)
            .animation(
                isAnimating ?
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true) :
                    .default,
                value: isAnimating
            )
    }
}
