import SwiftUI

/// A liquid-glass pane used for hero content on premium screens.
/// Uses iOS 26 `glassEffect` when available and falls back to a
/// rich layered material on iOS 18.
///
/// Unlike `GlassCard` (the dense, opaque app-wide card), `PremiumPane`
/// is meant to *float* over the Aurora backdrop and let the canvas
/// breathe through.
struct PremiumPane<Content: View>: View {
    var cornerRadius: CGFloat = PepRadius.md
    var accent: Color? = nil
    var padding: CGFloat = PepSpacing.lg
    @ViewBuilder let content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content()
            .padding(padding)
            .background {
                ZStack {
                    // Subtle accent wash if provided
                    if let accent {
                        accent.opacity(0.06)
                    }

                    // Glass material
                    Rectangle()
                        .fill(.ultraThinMaterial)

                    // Inner top highlight (lifted feel)
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                    .blendMode(.plusLighter)
                    .opacity(0.7)
                }
            }
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(
                    LinearGradient(
                        colors: accent.map {
                            [$0.opacity(0.32), $0.opacity(0.06)]
                        } ?? [
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.6
                )
            )
            .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
            .modifier(PremiumPaneGlassEffect(shape: shape))
    }
}

private struct PremiumPaneGlassEffect<S: Shape>: ViewModifier {
    let shape: S
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(in: shape)
        } else {
            content
        }
    }
}
