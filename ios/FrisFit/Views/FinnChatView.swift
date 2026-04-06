import SwiftUI

struct PepChatView: View {
    @State private var viewModel = PepChatViewModel()
    @FocusState private var isInputFocused: Bool
    @State private var showQuickActions: Bool = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            pepNavBar

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        pepProfileHeader
                            .padding(.bottom, 8)

                        ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                            let showTimestamp = shouldShowTimestamp(at: index)

                            if showTimestamp {
                                Text(message.timestamp.formatted(.dateTime.hour().minute()))
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                                    .padding(.top, 12)
                                    .padding(.bottom, 4)
                            }

                            switch message.role {
                            case .pep:
                                PepBubble(message: message, viewModel: viewModel, showAvatar: shouldShowPepAvatar(at: index))
                                    .padding(.top, isSameRoleAsPrevious(at: index) && !showTimestamp ? 2 : 8)
                            case .user:
                                UserBubble(text: message.content)
                                    .padding(.top, isSameRoleAsPrevious(at: index) && !showTimestamp ? 2 : 8)
                            }
                        }

                        if viewModel.isGenerating {
                            PepTypingBubble()
                                .padding(.top, 8)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
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
        .background(PepTheme.background.ignoresSafeArea())
    }

    private var pepNavBar: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundStyle(PepTheme.violet)
                }

                Spacer()

                VStack(spacing: 2) {
                    PepNavAvatar(size: 32)
                    Text("Pep")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                }

                Spacer()

                Button {
                } label: {
                    Image(systemName: "video")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(PepTheme.violet)
                }
                .opacity(0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(height: 0.5)
        }
        .background(PepTheme.cardSurface.opacity(0.8))
        .background(.ultraThinMaterial)
    }

    private var pepProfileHeader: some View {
        VStack(spacing: 8) {
            PepNavAvatar(size: 60)

            Text("Pep")
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)

            Text("Peptide Research Companion")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)

            Text("For informational & educational purposes only")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PepTheme.amber)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(PepTheme.amber.opacity(0.1))
                .clipShape(.capsule)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var pepInputBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(height: 0.5)

            HStack(alignment: .bottom, spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showQuickActions.toggle()
                    }
                } label: {
                    Image(systemName: showQuickActions ? "xmark.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
                        .contentTransition(.symbolEffect(.replace))
                }

                HStack(spacing: 0) {
                    TextField("Ask Pep anything...", text: $viewModel.inputText, axis: .vertical)
                        .lineLimit(1...5)
                        .font(.body)
                        .foregroundStyle(PepTheme.textPrimary)
                        .focused($isInputFocused)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)

                    if viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                        } label: {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                        }
                        .padding(.trailing, 10)
                    }
                }
                .background(PepTheme.elevated)
                .clipShape(.capsule)

                if !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        viewModel.sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(PepTheme.violet)
                    }
                    .disabled(viewModel.isGenerating)
                    .sensoryFeedback(.impact(weight: .light), trigger: viewModel.messages.count)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: viewModel.inputText.isEmpty)

            if showQuickActions {
                quickActionsRow
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(
            PepTheme.cardSurface
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var quickActionsRow: some View {
        HStack(spacing: 20) {
            QuickActionButton(icon: "pill.fill", label: "Peptides", color: PepTheme.teal) {
                viewModel.inputText = "Tell me about BPC-157"
                showQuickActions = false
            }
            QuickActionButton(icon: "function", label: "Reconstitution", color: PepTheme.blue) {
                viewModel.inputText = "Help me with reconstitution math"
                showQuickActions = false
            }
            QuickActionButton(icon: "syringe.fill", label: "Injection", color: .orange) {
                viewModel.inputText = "Where should I inject next?"
                showQuickActions = false
            }
            QuickActionButton(icon: "dumbbell.fill", label: "Training", color: PepTheme.violet) {
                viewModel.inputText = "What should I train today?"
                showQuickActions = false
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
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

struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(color)
                    .frame(width: 50, height: 50)
                    .background(color.opacity(0.15))
                    .clipShape(Circle())

                Text(label)
                    .font(.caption2)
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
    }
}

struct PepNavAvatar: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [PepTheme.teal, PepTheme.violet.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            Text("P")
                .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

typealias FinnNavAvatar = PepNavAvatar

struct PepBubble: View {
    let message: PepMessage
    let viewModel: PepChatViewModel
    let showAvatar: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if showAvatar {
                PepNavAvatar(size: 28)
            } else {
                Color.clear.frame(width: 28)
            }

            VStack(alignment: .leading, spacing: 0) {
                buildContent(message.content, exerciseNames: message.exerciseNames)
                    .font(.body)
                    .foregroundStyle(PepTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(pepBubbleBackground)
                    .clipShape(PepBubbleShape(showTail: showAvatar))
            }

            Spacer(minLength: 50)
        }
    }

    private var pepBubbleBackground: some View {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 38/255, green: 38/255, blue: 42/255, alpha: 1)
                : UIColor(red: 230/255, green: 230/255, blue: 235/255, alpha: 1)
        })
    }

    @ViewBuilder
    private func buildContent(_ content: String, exerciseNames: [String]) -> some View {
        if exerciseNames.isEmpty {
            Text(content)
                .lineSpacing(2)
        } else {
            ExerciseLinkText(content: content, exerciseNames: exerciseNames, viewModel: viewModel)
        }
    }
}

typealias FinnBubble = PepBubble

struct PepBubbleShape: Shape {
    let showTail: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18
        let tailSize: CGFloat = showTail ? 6 : 0

        var path = Path()

        path.move(to: CGPoint(x: rect.minX + tailSize, y: rect.maxY - radius))
        path.addArc(
            center: CGPoint(x: rect.minX + tailSize + radius, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(270),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )

        if showTail {
            path.addLine(to: CGPoint(x: rect.minX + tailSize + radius, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY + 2),
                control: CGPoint(x: rect.minX + tailSize, y: rect.maxY)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + tailSize, y: rect.maxY - 4),
                control: CGPoint(x: rect.minX + tailSize - 1, y: rect.maxY)
            )
        } else {
            path.addArc(
                center: CGPoint(x: rect.minX + tailSize + radius, y: rect.maxY - radius),
                radius: radius,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
        }

        path.closeSubpath()
        return path
    }
}

typealias FinnBubbleShape = PepBubbleShape

struct UserBubble: View {
    let text: String

    var body: some View {
        HStack {
            Spacer(minLength: 50)
            Text(text)
                .font(.body)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(PepTheme.violet)
                .clipShape(UserBubbleShape())
        }
    }
}

struct UserBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18
        let tailSize: CGFloat = 6

        var path = Path()

        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.maxX - tailSize - radius, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(270),
            endAngle: .degrees(0),
            clockwise: false
        )

        path.addLine(to: CGPoint(x: rect.maxX - tailSize, y: rect.maxY - radius))

        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY + 2),
            control: CGPoint(x: rect.maxX - tailSize, y: rect.maxY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - tailSize, y: rect.maxY - 4),
            control: CGPoint(x: rect.maxX - tailSize + 1, y: rect.maxY)
        )

        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
            radius: radius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addArc(
            center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )

        path.closeSubpath()
        return path
    }
}

struct PepTypingBubble: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            PepNavAvatar(size: 28)

            TypingDots()
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Color(UIColor { traits in
                        traits.userInterfaceStyle == .dark
                            ? UIColor(red: 38/255, green: 38/255, blue: 42/255, alpha: 1)
                            : UIColor(red: 230/255, green: 230/255, blue: 235/255, alpha: 1)
                    })
                )
                .clipShape(PepBubbleShape(showTail: true))

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
                    .fill(PepTheme.textSecondary.opacity(phase == index ? 0.9 : 0.35))
                    .frame(width: 8, height: 8)
                    .scaleEffect(phase == index ? 1.15 : 1.0)
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
            .lineSpacing(2)
    }
}

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
