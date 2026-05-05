import SwiftUI

/// Canonical screen background for the app.
///
/// One source of truth for the canvas every screen sits on, so that any
/// future tweak to the aesthetic only has to be made here. Internally
/// uses `AuroraBackground` — the look the app has converged on — but
/// callers don't need to know that.
///
/// ```swift
/// ScrollView { ... }
///     .appBackground()                    // default teal accent
///     .appBackground(accent: PepTheme.amber)  // section-tinted
/// ```
struct AppBackground: View {
    var accent: Color = PepTheme.teal
    /// Tone the canvas down on dense / data-heavy screens.
    var intensity: Double = 1.0

    var body: some View {
        AuroraBackground(accent: accent, intensity: intensity)
    }
}

extension View {
    /// Applies the app's canonical screen background.
    func appBackground(accent: Color = PepTheme.teal, intensity: Double = 1.0) -> some View {
        background(AppBackground(accent: accent, intensity: intensity))
    }
}

// MARK: - Surface card modifier
//
// Lightweight equivalent of `GlassCard` for places that need to apply the
// shared card surface to an existing layout without wrapping it in a new
// container. Keeps the look consistent with `GlassCard` (surface,
// hairline border, soft shadow).

extension View {
    /// Applies the shared card surface (background + border + shadow).
    /// Use when you can't easily wrap content in `GlassCard`.
    func surfaceCard(
        cornerRadius: CGFloat = PepRadius.md,
        accent: Color? = nil
    ) -> some View {
        modifier(SurfaceCardModifier(cornerRadius: cornerRadius, accent: accent))
    }
}

private struct SurfaceCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let accent: Color?

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(
                ZStack {
                    if let accent {
                        accent.opacity(0.05)
                    }
                    PepTheme.cardSurface.opacity(accent == nil ? 1.0 : 0.9)
                    PepTheme.cardOverlay
                    PepTheme.glassHighlight
                        .opacity(0.10)
                        .blendMode(.plusLighter)
                }
            )
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(
                    accent.map { AnyShapeStyle($0.opacity(0.18)) }
                        ?? AnyShapeStyle(PepTheme.glassBorderTop.opacity(0.85)),
                    lineWidth: 0.6
                )
            )
            .shadow(
                color: (accent ?? PepTheme.shadowColor).opacity(accent != nil ? 0.18 : 1.0),
                radius: 14,
                x: 0,
                y: 6
            )
    }
}
