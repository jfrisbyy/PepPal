import SwiftUI

/// Reusable floating capsule pill used in the top-right of primary tabs.
/// Wraps a row of compact segments separated by hairline dividers and
/// provides an optional scroll-aware fade/shrink that mirrors HomeView.
struct FloatingNavPill<Content: View>: View {
    let scrollOffset: CGFloat
    let accent: Color?
    @ViewBuilder var content: () -> Content

    init(
        scrollOffset: CGFloat = 0,
        accent: Color? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.scrollOffset = scrollOffset
        self.accent = accent
        self.content = content
    }

    private var pillScale: CGFloat {
        let progress = min(max(scrollOffset / 80, 0), 1)
        return 1.0 - 0.12 * progress
    }

    private var pillOpacity: Double {
        let progress = min(max(Double(scrollOffset) / 80, 0), 1)
        return 1.0 - 0.3 * progress
    }

    var body: some View {
        HStack(spacing: 0) { content() }
            .background(
                Capsule()
                    .fill(PepTheme.cardSurface)
                    .overlay(
                        Capsule().strokeBorder(
                            accent?.opacity(0.45) ?? PepTheme.glassBorderTop,
                            lineWidth: 0.6
                        )
                    )
                    .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
            )
            .clipShape(.capsule)
            .scaleEffect(pillScale, anchor: .topTrailing)
            .opacity(pillOpacity)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: pillScale)
            .animation(.easeOut(duration: 0.18), value: pillOpacity)
    }
}

/// Hairline vertical divider sized to sit between pill segments.
struct FloatingPillDivider: View {
    var body: some View {
        Rectangle()
            .fill(PepTheme.textPrimary.opacity(0.08))
            .frame(width: 0.5, height: 18)
    }
}

/// A single icon-only pill segment with consistent 36pt hit target.
struct FloatingPillIconButton: View {
    let systemName: String
    let tint: Color
    let badge: Bool
    let badgeColor: Color
    let action: () -> Void

    init(
        systemName: String,
        tint: Color = PepTheme.textPrimary,
        badge: Bool = false,
        badgeColor: Color = PepTheme.coral,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.tint = tint
        self.badge = badge
        self.badgeColor = badgeColor
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: systemName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                if badge {
                    Circle()
                        .fill(badgeColor)
                        .frame(width: 7, height: 7)
                        .overlay(Circle().strokeBorder(PepTheme.cardSurface, lineWidth: 1))
                        .offset(x: -8, y: 8)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
