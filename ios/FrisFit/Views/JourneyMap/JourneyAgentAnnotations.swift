import SwiftUI

/// Small sparkle badge rendered on the date axis when the correlation engine
/// has detected something noteworthy. Tap to expand into a reasoning card.
struct JourneyAgentBadge: View {
    let event: JourneyEvent
    let onTap: () -> Void
    @State private var glow: Bool = false

    private var tint: Color {
        if let raw = event.payload?.annotationTargetLane,
           let lane = JourneyLane(rawValue: raw) {
            return lane.color
        }
        return PepTheme.amber
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(tint.opacity(glow ? 0.42 : 0.22))
                    .frame(width: 26, height: 26)
                    .blur(radius: 5)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.9), tint.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 18, height: 18)
                    .overlay(
                        Circle().strokeBorder(.white.opacity(0.45), lineWidth: 0.6)
                    )
                    .shadow(color: tint.opacity(0.6), radius: 4)
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}

/// Floating expanded card for an agent annotation. Shows the agent's reasoning
/// in plain language and a CTA to dive deeper with the investigation agent.
struct JourneyAgentExpandedCard: View {
    let event: JourneyEvent
    let onDismiss: () -> Void
    let onTellMeMore: () -> Void

    private var tint: Color {
        if let raw = event.payload?.annotationTargetLane,
           let lane = JourneyLane(rawValue: raw) {
            return lane.color
        }
        return PepTheme.amber
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.22))
                        .frame(width: 32, height: 32)
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Agent annotation")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(.white.opacity(0.5))
                    Text(event.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }
                Spacer()
                Button {
                    JourneyHaptics.soft()
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .buttonStyle(.plain)
            }

            if let body = event.description, !body.isEmpty {
                Text(body)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 10, weight: .semibold))
                Text(event.timestamp.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.45))

            Button {
                JourneyHaptics.medium()
                onTellMeMore()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 12, weight: .heavy))
                    Text("Tell me more")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(
                        LinearGradient(
                            colors: [tint.opacity(0.85), tint.opacity(0.55)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                )
                .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.6))
                .shadow(color: tint.opacity(0.45), radius: 8, y: 2)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 22/255, green: 22/255, blue: 28/255).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [tint.opacity(0.45), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                )
                .shadow(color: .black.opacity(0.5), radius: 18, y: 6)
        )
        .frame(maxWidth: 320)
    }
}
