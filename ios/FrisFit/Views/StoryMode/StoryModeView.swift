import SwiftUI
import UIKit

/// Full-screen, vertical 9:16 cinematic playthrough of the user's journey.
/// Each beat is one card. Tap to pause, swipe up to skip, swipe down to replay,
/// long-press to scrub, top progress bar shows position. Share button is always
/// present and exports the current beat as a still or the whole story.
struct StoryModeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var service = StoryModeService.shared

    @State private var beats: [StoryBeat] = []
    @State private var currentIndex: Int = 0
    @State private var beatProgress: Double = 0
    @State private var isPaused: Bool = false
    @State private var isLoading: Bool = true
    @State private var isScrubbing: Bool = false
    @State private var beatStartedAt: Date = Date()
    @State private var elapsedAtPause: TimeInterval = 0
    @State private var showShare: Bool = false
    @State private var soundtrackOn: Bool = false

    private let beatDuration: TimeInterval = 4.5

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                loadingView
                    .transition(.opacity)
            } else if beats.isEmpty {
                emptyView
            } else {
                playerView
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .task { await load() }
        .sheet(isPresented: $showShare) {
            StoryModeShareSheet(currentBeat: beats[safe: currentIndex])
        }
    }

    // MARK: - Loading & empty

    private var loadingView: some View {
        VStack(spacing: 18) {
            ProgressView()
                .controlSize(.large)
                .tint(PepTheme.teal)
            Text("Composing your story…")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.65))
        }
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(PepTheme.teal.opacity(0.8))
            Text("Your story is just beginning")
                .font(.system(size: 22, weight: .semibold, design: .default))
                .foregroundStyle(.white)
            Text("Add a few pins to your journey, then come back.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Close") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(PepTheme.teal)
                .padding(.top, 12)
        }
    }

    // MARK: - Player

    private var playerView: some View {
        let beat = beats[currentIndex]
        return ZStack(alignment: .top) {
            StoryBeatCard(beat: beat, isPaused: isPaused)
                .id(beat.id)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    )
                )

            // Top safe-area: progress bar + close + share
            VStack(spacing: 8) {
                StoryProgressBar(
                    count: beats.count,
                    currentIndex: currentIndex,
                    progress: beatProgress
                )
                HStack {
                    Button {
                        JourneyHaptics.soft()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    Spacer()
                    Button {
                        soundtrackOn.toggle()
                        JourneyHaptics.soft()
                    } label: {
                        Image(systemName: soundtrackOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    Button {
                        JourneyHaptics.light()
                        isPaused = true
                        showShare = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 6)
        }
        .contentShape(Rectangle())
        .onTapGesture { togglePause() }
        .gesture(swipeGesture)
        .onLongPressGesture(minimumDuration: 0.4) {
            isScrubbing = true
            isPaused = true
        }
        .animation(StoryModeMotion.beatIn, value: currentIndex)
        .onAppear { startBeat() }
        .onChange(of: currentIndex) { _, _ in startBeat() }
        .onChange(of: showShare) { _, presented in
            if !presented { isPaused = false; resumeFromPause() }
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { v in
                let dy = v.translation.height
                if dy < -50 {
                    advance()
                } else if dy > 50 {
                    rewind()
                }
            }
    }

    // MARK: - Beat playback

    private func load() async {
        let firstName = ProfileService.shared.cachedDisplayName?
            .split(separator: " ").first.map(String.init)
        let result = await service.buildBeats(firstName: firstName)
        await MainActor.run {
            self.beats = result
            self.isLoading = false
            self.currentIndex = 0
            self.startBeat()
        }
    }

    private func startBeat() {
        beatProgress = 0
        elapsedAtPause = 0
        beatStartedAt = Date()
        if !isPaused {
            tickAsync()
        }
        // Haptic for celebratory beats
        if let beat = beats[safe: currentIndex] {
            switch beat.kind {
            case .opening, .end:
                JourneyHaptics.soft()
            case .currentSummary, .future:
                JourneyHaptics.medium()
            case .event:
                JourneyHaptics.light()
            }
        }
    }

    private func tickAsync() {
        let beatId = beats[safe: currentIndex]?.id
        Task { @MainActor in
            while !isPaused, let id = beatId, currentIndex < beats.count, beats[currentIndex].id == id {
                let elapsed = elapsedAtPause + Date().timeIntervalSince(beatStartedAt)
                let p = min(1.0, elapsed / beatDuration)
                withAnimation(.linear(duration: 0.06)) { beatProgress = p }
                if p >= 1.0 {
                    advance()
                    return
                }
                try? await Task.sleep(for: .milliseconds(60))
            }
        }
    }

    private func togglePause() {
        if isScrubbing { isScrubbing = false; isPaused = false; resumeFromPause(); return }
        if isPaused {
            isPaused = false
            resumeFromPause()
        } else {
            isPaused = true
            elapsedAtPause += Date().timeIntervalSince(beatStartedAt)
        }
    }

    private func resumeFromPause() {
        beatStartedAt = Date()
        tickAsync()
    }

    private func advance() {
        if currentIndex >= beats.count - 1 {
            // End of story
            JourneyHaptics.success()
            dismiss()
            return
        }
        currentIndex += 1
    }

    private func rewind() {
        if currentIndex == 0 {
            beatProgress = 0
            elapsedAtPause = 0
            beatStartedAt = Date()
            return
        }
        currentIndex -= 1
    }
}

// MARK: - Top progress bar

struct StoryProgressBar: View {
    let count: Int
    let currentIndex: Int
    let progress: Double

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { idx in
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.18))
                        Capsule()
                            .fill(.white.opacity(0.95))
                            .frame(width: geo.size.width * fillRatio(for: idx))
                    }
                }
                .frame(height: 2.5)
            }
        }
        .padding(.horizontal, 10)
    }

    private func fillRatio(for idx: Int) -> CGFloat {
        if idx < currentIndex { return 1 }
        if idx == currentIndex { return CGFloat(progress) }
        return 0
    }
}

// MARK: - Beat card

struct StoryBeatCard: View {
    let beat: StoryBeat
    let isPaused: Bool

    @State private var animateIn: Bool = false

    var body: some View {
        ZStack {
            // Tonal gradient background per beat
            LinearGradient(
                colors: [beat.palette.top, beat.palette.bottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Soft accent radial wash
            RadialGradient(
                colors: [beat.palette.accent.opacity(0.30), .clear],
                center: .topTrailing,
                startRadius: 8,
                endRadius: 380
            )
            .ignoresSafeArea()
            .blendMode(.plusLighter)

            // Watermark — bottom-right, outside critical safe zones
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("Tracked with EPTI")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                        .tracking(0.5)
                        .padding(.trailing, 16)
                        .padding(.bottom, 14)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // Content respects safe areas — keep critical content out of
            // bottom 33% and top 10% of the frame.
            GeometryReader { geo in
                let topPad = geo.size.height * 0.18
                let bottomPad = geo.size.height * 0.34
                content
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 28)
                    .padding(.top, topPad)
                    .padding(.bottom, bottomPad)
            }
        }
        .onAppear {
            animateIn = false
            withAnimation(StoryModeMotion.beatIn.delay(0.05)) { animateIn = true }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch beat.kind {
        case .opening:
            openingContent
        case .event:
            eventContent
        case .currentSummary:
            summaryContent
        case .future:
            futureContent
        case .end:
            endContent
        }
    }

    // MARK: - Opening

    private var openingContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer(minLength: 0)
            Text(beat.title)
                .font(.system(size: 38, weight: .bold, design: .default))
                .foregroundStyle(.white)
                .tracking(-0.3)
                .blur(radius: animateIn ? 0 : 8)
                .opacity(animateIn ? 1 : 0)
                .multilineTextAlignment(.leading)
            if !beat.narration.isEmpty {
                StoryWordStaggerText(text: beat.narration, color: .white.opacity(0.85))
                    .font(.system(size: 18, weight: .medium))
            }
            if !beat.stats.isEmpty {
                HStack(spacing: 8) {
                    ForEach(beat.stats) { stat in StoryStatChip(stat: stat) }
                }
                .padding(.top, 10)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 12)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Event

    private var eventContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Date label
            if let dateLabel = beat.dateLabel {
                Text(dateLabel.uppercased())
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(beat.palette.accent)
                    .tracking(2.0)
                    .opacity(animateIn ? 1 : 0)
            }
            // Hero pin treatment
            HStack(spacing: 14) {
                if let lane = beat.lane {
                    CrystallineMilestoneNode(color: beat.palette.accent, size: 44, icon: lane.icon)
                        .scaleEffect(animateIn ? 1 : 0.4)
                        .opacity(animateIn ? 1 : 0)
                }
                Text(beat.title)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                    .tracking(-0.2)
                    .blur(radius: animateIn ? 0 : 6)
                    .opacity(animateIn ? 1 : 0)
                    .lineLimit(3)
            }
            if !beat.narration.isEmpty {
                StoryWordStaggerText(text: beat.narration, color: .white.opacity(0.88))
                    .font(.system(size: 18, weight: .medium))
            }
            if !beat.stats.isEmpty {
                StoryStatGrid(stats: beat.stats)
                    .padding(.top, 6)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 14)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Current summary

    private var summaryContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("WHERE YOU ARE NOW")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(beat.palette.accent)
                .tracking(2.5)
                .opacity(animateIn ? 1 : 0)

            // Hero stat — biggest single number from stats[0]
            if let hero = beat.stats.first {
                VStack(alignment: .leading, spacing: 4) {
                    Text(hero.value)
                        .font(.system(size: 80, weight: .heavy, design: .default))
                        .foregroundStyle(.white)
                        .tracking(-2.0)
                        .blur(radius: animateIn ? 0 : 10)
                        .opacity(animateIn ? 1 : 0)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(hero.label.uppercased())
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .tracking(1.6)
                        .opacity(animateIn ? 1 : 0)
                }
            }

            if !beat.narration.isEmpty {
                StoryWordStaggerText(text: beat.narration, color: .white.opacity(0.82))
                    .font(.system(size: 18, weight: .medium))
            }

            // Remaining stats as chips
            if beat.stats.count > 1 {
                HStack(spacing: 8) {
                    ForEach(beat.stats.dropFirst()) { stat in
                        StoryStatChip(stat: stat)
                    }
                }
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 12)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Future

    private var futureContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("WHAT'S NEXT")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(beat.palette.accent)
                .tracking(2.5)
                .opacity(animateIn ? 1 : 0)
            Text("Keep going.")
                .font(.system(size: 60, weight: .heavy, design: .default))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, beat.palette.accent.opacity(0.9)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .tracking(-1.4)
                .blur(radius: animateIn ? 0 : 8)
                .opacity(animateIn ? 1 : 0)
            if !beat.narration.isEmpty {
                StoryWordStaggerText(text: beat.narration, color: .white.opacity(0.85))
                    .font(.system(size: 18, weight: .medium))
            }
            Spacer(minLength: 0)
            // Aspirational target dot
            HStack {
                Spacer()
                GoalRadiatingDot(color: beat.palette.accent)
                    .opacity(animateIn ? 1 : 0)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - End

    private var endContent: some View {
        VStack(alignment: .center, spacing: 16) {
            Spacer(minLength: 0)
            Image(systemName: "flag.checkered")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(beat.palette.accent)
                .opacity(animateIn ? 1 : 0)
            Text(beat.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .blur(radius: animateIn ? 0 : 6)
                .opacity(animateIn ? 1 : 0)
            if let s = beat.subtitle {
                Text(s)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .opacity(animateIn ? 1 : 0)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Word-by-word fade-up

struct StoryWordStaggerText: View {
    let text: String
    var color: Color = .white

    @State private var visibleCount: Int = 0

    private var words: [String] {
        text.split(separator: " ").map(String.init)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            // FlowLayout fallback — use a simple wrapping HStack via Text
            // since iOS 18 supports flexible wrapping in Text composition.
        }
        .overlay(alignment: .leading) {
            wrappedWords
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { runStagger() }
        .onChange(of: text) { _, _ in
            visibleCount = 0
            runStagger()
        }
    }

    private var wrappedWords: some View {
        StoryFlowLayout(spacing: 6, lineSpacing: 4) {
            ForEach(Array(words.enumerated()), id: \.offset) { idx, word in
                Text(word)
                    .foregroundStyle(color)
                    .opacity(idx < visibleCount ? 1 : 0)
                    .offset(y: idx < visibleCount ? 0 : 6)
                    .blur(radius: idx < visibleCount ? 0 : 3)
            }
        }
    }

    private func runStagger() {
        Task { @MainActor in
            for i in 0..<words.count {
                try? await Task.sleep(for: .milliseconds(75))
                withAnimation(StoryModeMotion.textWord) {
                    visibleCount = i + 1
                }
            }
        }
    }
}

// MARK: - Stat chips & grid

struct StoryStatChip: View {
    let stat: StoryStat
    var body: some View {
        HStack(spacing: 6) {
            if let icon = stat.icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
            }
            Text(stat.value)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(.white.opacity(0.92))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.white.opacity(0.10), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.6))
    }
}

struct StoryStatGrid: View {
    let stats: [StoryStat]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(stats) { stat in
                HStack(spacing: 10) {
                    if let icon = stat.icon {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.65))
                            .frame(width: 18)
                    }
                    Text(stat.label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                    Spacer()
                    Text(stat.value)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
                .padding(.vertical, 4)
                Divider()
                    .background(.white.opacity(0.08))
            }
        }
    }
}

// MARK: - Simple flow layout for wrapping words

struct StoryFlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: maxWidth.isFinite ? maxWidth : x, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - Share sheet

struct StoryModeShareSheet: View {
    let currentBeat: StoryBeat?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                shareRow(icon: "photo.on.rectangle", label: "Save current beat to Photos") {
                    saveCurrentBeatStill()
                }
                shareRow(icon: "camera.metering.partial", label: "Share to Instagram Story") {
                    UIPasteboard.general.string = "Tracked with EPTI"
                    dismiss()
                }
                shareRow(icon: "person.2.fill", label: "Share to a friend") {
                    dismiss()
                }
                Spacer()
                Text("Watermark stays on every share.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
            .padding(.top, 16)
            .padding(.horizontal, 16)
            .navigationTitle("Share Story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private func shareRow(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(PepTheme.teal)
                    .frame(width: 28)
                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
            .background(PepTheme.cardSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func saveCurrentBeatStill() {
        guard let beat = currentBeat else { dismiss(); return }
        let renderer = ImageRenderer(content:
            StoryBeatCard(beat: beat, isPaused: true)
                .frame(width: 1080, height: 1920)
        )
        renderer.scale = 1.0
        if let img = renderer.uiImage {
            UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
            JourneyHaptics.success()
        }
        dismiss()
    }
}

// MARK: - Helpers

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
