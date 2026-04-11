import SwiftUI

struct PeptideAIChatView: View {
    @State private var viewModel = PeptideAIChatViewModel()
    @FocusState private var isInputFocused: Bool
    let onNavigateToCompound: ((CompoundProfile) -> Void)?
    let onNavigateToVendor: ((Vendor) -> Void)?

    init(
        onNavigateToCompound: ((CompoundProfile) -> Void)? = nil,
        onNavigateToVendor: ((Vendor) -> Void)? = nil
    ) {
        self.onNavigateToCompound = onNavigateToCompound
        self.onNavigateToVendor = onNavigateToVendor
    }

    var body: some View {
        VStack(spacing: 0) {
            chatHeader

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(viewModel.messages) { message in
                            ChatBubbleView(
                                message: message,
                                onCompoundTap: { name in
                                    if let compound = viewModel.matchedCompound(named: name) {
                                        onNavigateToCompound?(compound)
                                    }
                                },
                                onVendorTap: { name in
                                    if let vendor = viewModel.matchedVendor(named: name) {
                                        onNavigateToVendor?(vendor)
                                    }
                                }
                            )
                        }

                        if viewModel.isGenerating {
                            typingIndicator
                        }

                        if !viewModel.suggestedQuestions.isEmpty && viewModel.messages.count <= 2 {
                            suggestedQuestionsGrid
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                    .id("chatBottom")
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.messages.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("chatBottom", anchor: .bottom)
                    }
                }
            }

            inputBar
        }
        .background(PepTheme.background.ignoresSafeArea())
    }

    private var chatHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [PepTheme.teal, PepTheme.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)

                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("PepPal AI")
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)

                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                    Text("Live Research · Compound Database")
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }

            Spacer()

            Button {
                viewModel.clearChat()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(PepTheme.elevated)
                    .clipShape(.circle)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(PepTheme.cardSurface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(height: 0.5)
        }
    }

    private var typingIndicator: some View {
        HStack(alignment: .bottom, spacing: 8) {
            aiAvatar

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(PepTheme.teal.opacity(0.6))
                        .frame(width: 7, height: 7)
                        .offset(y: typingOffset(for: index))
                        .animation(
                            .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                            value: viewModel.isGenerating
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(PepTheme.elevated)
            .clipShape(.rect(cornerRadius: 18, style: .continuous))

            Spacer(minLength: 60)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @State private var typingBounce: Bool = false

    private func typingOffset(for index: Int) -> CGFloat {
        viewModel.isGenerating ? -4 : 0
    }

    private var suggestedQuestionsGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Try asking...")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
                .padding(.top, 8)

            ForEach(viewModel.suggestedQuestions, id: \.self) { question in
                Button {
                    viewModel.sendMessage(question)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(PepTheme.teal)

                        Text(question)
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundStyle(PepTheme.textPrimary)
                            .multilineTextAlignment(.leading)

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(PepTheme.cardSurface)
                    .clipShape(.rect(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
                    )
                }
            }
        }
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(height: 0.5)

            HStack(spacing: 10) {
                TextField("Ask about peptides...", text: $viewModel.inputText, axis: .vertical)
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1...4)
                    .focused($isInputFocused)
                    .onSubmit {
                        viewModel.sendMessage()
                    }

                Button {
                    viewModel.sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(
                            viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isGenerating
                            ? PepTheme.textSecondary.opacity(0.3)
                            : PepTheme.teal
                        )
                        .symbolRenderingMode(.hierarchical)
                }
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isGenerating)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(PepTheme.elevated.opacity(0.6))
            .clipShape(.rect(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(PepTheme.cardSurface)
        }
    }

    private var aiAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [PepTheme.teal.opacity(0.3), PepTheme.blue.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 28)

            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PepTheme.teal)
        }
    }
}

struct ChatBubbleView: View {
    let message: PepMessage
    let onCompoundTap: (String) -> Void
    let onVendorTap: (String) -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .pep {
                aiAvatar
                aiBubble
                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)
                userBubble
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private var aiAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [PepTheme.teal.opacity(0.3), PepTheme.blue.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 28)

            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PepTheme.teal)
        }
    }

    private var aiBubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            parseContent(message.content)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(PepTheme.elevated)
        .clipShape(.rect(cornerRadius: 18, style: .continuous))
    }

    private var userBubble: some View {
        Text(message.content)
            .font(.system(.subheadline, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [PepTheme.teal, PepTheme.teal.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(.rect(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func parseContent(_ text: String) -> some View {
        let segments = parseLinkedContent(text)
        let combined = segments.reduce(Text("")) { result, segment in
            switch segment {
            case .plain(let str):
                return result + Text(str)
                    .font(.system(.subheadline))
                    .foregroundColor(Color(PepTheme.textPrimary))
            case .compound(let name):
                return result + Text(name)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundColor(Color(PepTheme.teal))
                    .underline()
            case .vendor(let name):
                return result + Text(name)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundColor(Color(PepTheme.blue))
                    .underline()
            }
        }
        combined
    }

    private func parseLinkedContent(_ text: String) -> [ContentSegment] {
        var segments: [ContentSegment] = []
        var remaining = text

        while !remaining.isEmpty {
            if let compoundRange = remaining.range(of: #"\[COMPOUND:([^\]]+)\]"#, options: .regularExpression) {
                let before = String(remaining[remaining.startIndex..<compoundRange.lowerBound])
                if !before.isEmpty { segments.append(.plain(before)) }

                let match = String(remaining[compoundRange])
                let name = String(match.dropFirst(10).dropLast(1))
                segments.append(.compound(name))
                remaining = String(remaining[compoundRange.upperBound...])
            } else if let vendorRange = remaining.range(of: #"\[VENDOR:([^\]]+)\]"#, options: .regularExpression) {
                let before = String(remaining[remaining.startIndex..<vendorRange.lowerBound])
                if !before.isEmpty { segments.append(.plain(before)) }

                let match = String(remaining[vendorRange])
                let name = String(match.dropFirst(8).dropLast(1))
                segments.append(.vendor(name))
                remaining = String(remaining[vendorRange.upperBound...])
            } else {
                segments.append(.plain(remaining))
                remaining = ""
            }
        }

        return segments
    }
}

private enum ContentSegment {
    case plain(String)
    case compound(String)
    case vendor(String)
}
