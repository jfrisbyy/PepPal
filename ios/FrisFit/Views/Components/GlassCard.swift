import SwiftUI

/// Signature glass card used across the app.
/// - Faint inner top highlight (gives a lifted, glass feel)
/// - Hairline border that fades top→bottom
/// - Soft adaptive shadow
struct GlassCard<Content: View>: View {
    enum Size { case compact, standard, hero }

    var accent: Color? = nil
    var size: Size = .standard
    @ViewBuilder let content: () -> Content

    init(
        accent: Color? = nil,
        size: Size = .standard,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.accent = accent
        self.size = size
        self.content = content
    }

    private var radius: CGFloat {
        switch size {
        case .compact: PepRadius.sm
        case .standard: PepRadius.md
        case .hero: PepRadius.lg
        }
    }

    private var padding: CGFloat {
        switch size {
        case .compact: PepSpacing.md
        case .standard: PepSpacing.lg
        case .hero: PepSpacing.xl
        }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        return content()
            .padding(padding)
            .background(
                ZStack {
                    if let accent {
                        accent.opacity(0.05)
                    }
                    PepTheme.cardSurface.opacity(accent == nil ? 1.0 : 0.9)
                    PepTheme.cardOverlay
                    // Whisper-faint, edge-to-edge sheen so the whole card
                    // reads as one evenly-lit plane (no top→middle falloff).
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
                radius: size == .hero ? 24 : 14,
                x: 0,
                y: size == .hero ? 10 : 6
            )
    }
}
