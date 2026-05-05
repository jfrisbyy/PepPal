import SwiftUI
import UIKit

/// Final onboarding completion screen. Previews a stylized snapshot of the
/// populated home screen before the "Let's go" CTA hands the user off.
struct OnboardingCompletionPreviewView: View {
    let firstName: String
    let onGo: () -> Void

    @State private var briefHeadline: String = ""
    @State private var briefRecovery: String = ""
    @State private var briefBody: String = ""
    @State private var insightTitle: String = ""
    @State private var insightMessage: String = ""
    @State private var insightIcon: String = "lightbulb.fill"
    @State private var insightTint: Color = PepTheme.violet
    @State private var pinCount: Int = 0
    @State private var protocolLine: String? = nil
    @State private var appeared: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                morningBriefPreview
                journeyPreview
                insightPreview
                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            ctaBar
        }
        .onAppear {
            populate()
            withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                appeared = true
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your EPTI is ready")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text("Here's a peek at what we set up for you, \(firstName.isEmpty ? "friend" : firstName).")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
    }

    // MARK: - Morning brief preview

    private var morningBriefPreview: some View {
        previewCard(label: "MORNING BRIEF", tint: PepTheme.teal) {
            VStack(alignment: .leading, spacing: 10) {
                Text(briefHeadline.isEmpty ? "Your day, at a glance" : briefHeadline)
                    .font(.system(.title3, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if !briefRecovery.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "moon.zzz.fill").font(.caption).foregroundStyle(PepTheme.violet)
                        Text(briefRecovery).font(.subheadline).foregroundStyle(PepTheme.textSecondary)
                    }
                }
                if !briefBody.isEmpty {
                    Text(briefBody)
                        .font(.footnote)
                        .foregroundStyle(PepTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let proto = protocolLine {
                    HStack(spacing: 8) {
                        Image(systemName: "syringe.fill").font(.caption).foregroundStyle(PepTheme.amber)
                        Text(proto).font(.subheadline).foregroundStyle(PepTheme.textSecondary)
                    }
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.05), value: appeared)
    }

    // MARK: - Journey preview

    private var journeyPreview: some View {
        previewCard(label: "JOURNEY · LAST 90 DAYS", tint: PepTheme.violet) {
            VStack(alignment: .leading, spacing: 12) {
                MiniJourneyMapPreview(pinCount: max(pinCount, 3))
                    .frame(height: 78)
                Text("\(pinCount) \(pinCount == 1 ? "pin" : "pins") on your timeline")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.12), value: appeared)
    }

    // MARK: - Insight preview

    private var insightPreview: some View {
        previewCard(label: "FIRST INSIGHT", tint: insightTint) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().fill(insightTint.opacity(0.18)).frame(width: 36, height: 36)
                    Image(systemName: insightIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(insightTint)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(insightTitle.isEmpty ? "Your AI is warmed up" : insightTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(insightMessage.isEmpty
                         ? "We seeded your facts, baselines, and goals so the agent already knows who you are."
                         : insightMessage)
                        .font(.footnote)
                        .foregroundStyle(PepTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.19), value: appeared)
    }

    // MARK: - CTA

    private var ctaBar: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [PepTheme.background.opacity(0), PepTheme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 24)

            Button {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onGo()
            } label: {
                Text("Let's go")
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(PepTheme.teal)
                    .clipShape(.rect(cornerRadius: 16))
                    .shadow(color: PepTheme.teal.opacity(0.45), radius: 18, y: 8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
            .background(PepTheme.background)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func previewCard<Content: View>(label: String, tint: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle().fill(tint).frame(width: 6, height: 6)
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(tint)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    LinearGradient(
                        colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }

    private func populate() {
        let lines = MorningBriefService.shared.buildLines()
        briefHeadline = MorningBriefService.shared.fallbackHeadline(from: lines)
        if let r = lines.recovery {
            briefRecovery = "\(r.label) — \(r.value)"
        }
        briefBody = MorningBriefService.shared.fallbackBody(from: lines)

        // Use the first pinned narrative fact if available — that's the warmest line.
        let narrative = AIMemoryStore.shared.allFacts().first { $0.domain == "cross" || $0.kind == .pattern }
        if let narrative {
            briefHeadline = narrative.headline
        }

        pinCount = JourneyEventService.shared.events.count

        if let proto = InsightsDataStore.shared.primaryProtocol, let compound = proto.compounds.first {
            let dose = CompoundUnitHelper.displayDoseShort(compound.doseMcg, for: compound.compoundName)
            protocolLine = "Week \(proto.currentWeek) · \(compound.compoundName) \(dose) \(compound.frequency)"
        }

        // Pull a real proactive insight if any exists; otherwise fall back to a friendly default.
        let memoryInsights = AIMemoryStore.shared.allFacts().prefix(1)
        if let first = memoryInsights.first {
            insightTitle = "We already know your starting point"
            insightMessage = first.headline
            insightIcon = "lightbulb.fill"
            insightTint = PepTheme.violet
        }
    }
}

// MARK: - Mini journey preview

private struct MiniJourneyMapPreview: View {
    let pinCount: Int

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [PepTheme.violet.opacity(0.12), PepTheme.teal.opacity(0.10)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .clipShape(.rect(cornerRadius: 12))

                // Center rule
                Rectangle()
                    .fill(LinearGradient(
                        colors: [PepTheme.teal.opacity(0.0), PepTheme.teal.opacity(0.6), PepTheme.teal.opacity(0.0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(height: 1.5)
                    .frame(maxHeight: .infinity, alignment: .center)

                // Body curve sketch
                Path { p in
                    let h = geo.size.height
                    let w = geo.size.width
                    p.move(to: CGPoint(x: 0, y: h * 0.55))
                    p.addCurve(
                        to: CGPoint(x: w, y: h * 0.30),
                        control1: CGPoint(x: w * 0.35, y: h * 0.65),
                        control2: CGPoint(x: w * 0.65, y: h * 0.20)
                    )
                }
                .stroke(PepTheme.amber.opacity(0.85), style: StrokeStyle(lineWidth: 2, lineCap: .round))

                // Pins
                let count = max(min(pinCount, 8), 2)
                ForEach(0..<count, id: \.self) { idx in
                    let progress = Double(idx) / Double(max(count - 1, 1))
                    let x = 12 + progress * (geo.size.width - 24)
                    let yOffset = (idx % 2 == 0) ? -14.0 : 14.0
                    Circle()
                        .fill(idx % 2 == 0 ? PepTheme.teal : PepTheme.violet)
                        .frame(width: 8, height: 8)
                        .shadow(color: (idx % 2 == 0 ? PepTheme.teal : PepTheme.violet).opacity(0.6), radius: 4)
                        .position(x: x, y: geo.size.height / 2 + yOffset)
                }
            }
        }
    }
}
