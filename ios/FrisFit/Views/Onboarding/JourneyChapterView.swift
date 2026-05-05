import SwiftUI
import UIKit

/// Cinematic Chapter 4 wrapper. Choreographs the entry animation, pin-add
/// reactions (1st = soft success + glow + copy, 2nd = light haptic, 3rd =
/// fast-tier AI narrative chip), and the exit zoom-out + page-turn.
struct JourneyChapterView: View {
    let firstName: String
    let onContinue: () -> Void

    @State private var service = JourneyEventService.shared

    // Entry sequence
    @State private var ruleSweep: CGFloat = -1.2     // -1.2 → 1.2 across the rule
    @State private var ruleSweepActive: Bool = true
    @State private var foundCardVisible: Bool = false

    // Pin reactions
    @State private var baselineCount: Int = -1
    @State private var sessionPins: Int = 0
    @State private var firstPinOverlayVisible: Bool = false
    @State private var narrativeText: String?
    @State private var narrativeWordsShown: Int = 0
    @State private var narrativeRequested: Bool = false

    // Exit transition
    @State private var exitZoom: Bool = false
    @State private var particleBurst: Bool = false
    @State private var pageTurning: Bool = false

    var body: some View {
        ZStack {
            JourneyMapView()
                .scaleEffect(exitZoom ? 0.92 : 1.0)
                .opacity(pageTurning ? 0.0 : 1.0)
                .blur(radius: pageTurning ? 6 : 0)

            entryRuleSweep
                .allowsHitTesting(false)

            VStack { Spacer(); foundCard.padding(.bottom, 100) }
                .allowsHitTesting(false)

            VStack { Spacer(); narrativeChip.padding(.bottom, 100) }
                .allowsHitTesting(false)

            firstPinCopyOverlay
                .allowsHitTesting(false)

            if particleBurst {
                ParticleBurstView()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            VStack {
                Spacer()
                continueButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
            }
        }
        .onAppear { runEntrySequence() }
        .onChange(of: service.events.count) { _, newCount in
            handleEventCountChange(newCount: newCount)
        }
    }

    // MARK: - Entry choreography

    private func runEntrySequence() {
        // Establish baseline so HealthKit-staged auto-adds done before this view
        // appears do NOT count as session pins.
        baselineCount = service.events.count

        // 1) Timeline rule sweep (~800ms ease-out) starts immediately.
        ruleSweep = -1.2
        ruleSweepActive = true
        withAnimation(.easeOut(duration: 0.8)) { ruleSweep = 1.2 }

        // The Body weight curve and Training tick stagger already run inside
        // their renderers' .onAppear, choreographed by JourneyMotion springs.
        // We just pace the "Here is what we found" card to land after them.

        // 2) ~2.4s later: card slides up with the gentle spring.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(800))
            ruleSweepActive = false
            try? await Task.sleep(for: .milliseconds(1600))
            withAnimation(JourneyMotion.gentle) { foundCardVisible = true }
            JourneyHaptics.soft()
        }
    }

    private var entryRuleSweep: some View {
        GeometryReader { geo in
            let w = geo.size.width
            LinearGradient(
                colors: [
                    .clear,
                    PepTheme.teal.opacity(0.0),
                    PepTheme.teal.opacity(0.55),
                    .white.opacity(0.35),
                    PepTheme.teal.opacity(0.55),
                    PepTheme.teal.opacity(0.0),
                    .clear
                ],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: w * 0.45, height: 2)
            .blur(radius: 4)
            .shadow(color: PepTheme.teal.opacity(0.7), radius: 12)
            .position(x: (ruleSweep + 1) * w * 0.5, y: 130)
            .opacity(ruleSweepActive ? 1 : 0)
            .animation(.easeOut(duration: 0.4), value: ruleSweepActive)
        }
    }

    private var foundCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(headline)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
            Text(subline)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 0.6)
                )
        )
        .padding(.horizontal, 20)
        .opacity(foundCardVisible ? 1 : 0)
        .offset(y: foundCardVisible ? 0 : 24)
    }

    private var headline: String {
        let n = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "Here's what we found" : "Here's what we found, \(n)"
    }

    private var subline: String {
        let snap = JourneyMapStagingStore.load()
        if let snap, let delta = ninetyDayWeightDelta(snap) {
            let dir = delta < 0 ? "Down" : "Up"
            let workouts = snap.days.compactMap { $0.workoutCount }.reduce(0, +)
            if workouts > 0 {
                return "\(dir) \(Int(abs(delta.rounded()))) lbs over 90 days, \(workouts) workouts in. Let's tell the rest of the story."
            }
            return "\(dir) \(Int(abs(delta.rounded()))) lbs over 90 days. Let's tell the rest of the story."
        }
        return "We've sketched the past 90 days. Add a few pins to make it yours."
    }

    private func ninetyDayWeightDelta(_ snap: JourneyMapStagingSnapshot) -> Double? {
        let weights = snap.days.compactMap { d -> (Date, Double)? in
            guard let w = d.weightLbs else { return nil }
            return (d.date, w)
        }.sorted { $0.0 < $1.0 }
        guard let first = weights.first?.1, let last = weights.last?.1 else { return nil }
        return last - first
    }

    // MARK: - Pin reactions

    private func handleEventCountChange(newCount: Int) {
        guard baselineCount >= 0 else {
            baselineCount = newCount
            return
        }
        let delta = newCount - baselineCount
        guard delta > sessionPins else { return }
        sessionPins = delta

        switch sessionPins {
        case 1:
            JourneyHaptics.success()
            withAnimation(JourneyMotion.celebratory) { firstPinOverlayVisible = true }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.0))
                withAnimation(.easeOut(duration: 0.5)) { firstPinOverlayVisible = false }
            }
        case 2:
            JourneyHaptics.light()
        case 3:
            JourneyHaptics.medium()
            requestNarrativePreviewIfNeeded()
        default:
            JourneyHaptics.light()
        }
    }

    private func requestNarrativePreviewIfNeeded() {
        guard !narrativeRequested else { return }
        narrativeRequested = true
        Task { @MainActor in
            let line = await generateNarrativeLine()
            await revealNarrative(line)
        }
    }

    private func generateNarrativeLine() async -> String {
        let snap = JourneyMapStagingStore.load()
        let delta = snap.flatMap { ninetyDayWeightDelta($0) }
        let workouts = snap?.days.compactMap { $0.workoutCount }.reduce(0, +)
        let bodyPins = service.events(in: .body).count
        let compound = service.events(in: .compounds).count
        let training = service.events(in: .training).count
        let blood = service.events(in: .bloodwork).count
        let life = service.events(in: .life).count
        let ai = await JourneyNarrativeService.generatePreview(
            firstName: firstName,
            bodyPins: bodyPins,
            compoundPins: compound,
            trainingPins: training,
            bloodworkPins: blood,
            lifePins: life,
            weightDeltaLbs: delta,
            ninetyDayWorkoutCount: workouts
        )
        return ai ?? JourneyNarrativeService.fallbackPreview(firstName: firstName, weightDeltaLbs: delta)
    }

    private func revealNarrative(_ line: String) async {
        narrativeText = line
        narrativeWordsShown = 0
        let words = line.split(separator: " ").count
        for i in 1...max(1, words) {
            try? await Task.sleep(for: .milliseconds(75))
            withAnimation(.easeOut(duration: 0.25)) { narrativeWordsShown = i }
        }
    }

    @ViewBuilder
    private var narrativeChip: some View {
        if let text = narrativeText {
            let words = text.split(separator: " ").map(String.init)
            HStack(spacing: 0) {
                ForEach(Array(words.enumerated()), id: \.offset) { idx, w in
                    Text(idx == 0 ? w : " \(w)")
                        .opacity(idx < narrativeWordsShown ? 1 : 0)
                        .offset(y: idx < narrativeWordsShown ? 0 : 4)
                        .animation(.easeOut(duration: 0.3).delay(Double(idx) * 0.005), value: narrativeWordsShown)
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white.opacity(0.95))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule().strokeBorder(
                            LinearGradient(
                                colors: [PepTheme.teal.opacity(0.6), PepTheme.teal.opacity(0.1)],
                                startPoint: .leading, endPoint: .trailing
                            ),
                            lineWidth: 0.8
                        )
                    )
                    .shadow(color: PepTheme.teal.opacity(0.4), radius: 12, y: 2)
            )
            .padding(.horizontal, 24)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var firstPinCopyOverlay: some View {
        if firstPinOverlayVisible {
            VStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(PepTheme.teal)
                Text("Your story is taking shape.")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 0.6)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 18, y: 6)
            )
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
    }

    // MARK: - Exit

    private var continueButton: some View {
        Button { triggerExit() } label: {
            Text(sessionPins == 0 ? "Looks right" : "Looks right")
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [PepTheme.teal, PepTheme.teal.opacity(0.75)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .clipShape(.rect(cornerRadius: 16))
                .shadow(color: PepTheme.teal.opacity(0.4), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .scaleEffect(exitZoom ? 1.06 : 1.0)
        .opacity(pageTurning ? 0 : 1)
    }

    private func triggerExit() {
        guard !pageTurning else { return }
        JourneyHaptics.success()
        withAnimation(JourneyMotion.gentle) {
            exitZoom = true
            particleBurst = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.easeIn(duration: 0.45)) { pageTurning = true }
            try? await Task.sleep(for: .milliseconds(380))
            onContinue()
        }
    }
}

// MARK: - Particle burst

/// Small, tasteful particle burst around the CTA button. Not confetti.
private struct ParticleBurstView: View {
    @State private var t: Double = 0

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height - 56)
            ZStack {
                ForEach(0..<14, id: \.self) { i in
                    let angle = Double(i) / 14 * 2 * .pi
                    let dist = 80.0 * t
                    let x = center.x + CGFloat(cos(angle)) * dist
                    let y = center.y + CGFloat(sin(angle)) * dist
                    Circle()
                        .fill(i.isMultiple(of: 2) ? PepTheme.teal : Color.white)
                        .frame(width: 5, height: 5)
                        .opacity(1 - t)
                        .blur(radius: 0.4)
                        .position(x: x, y: y)
                        .shadow(color: PepTheme.teal.opacity(0.6), radius: 4)
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.7)) { t = 1 }
            }
        }
    }
}
