import SwiftUI

struct GlassCard<Content: View>: View {
    var accent: Color? = nil
    @ViewBuilder let content: () -> Content

    init(accent: Color? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.accent = accent
        self.content = content
    }

    var body: some View {
        content()
            .padding(16)
            .background(
                Group {
                    if let accent {
                        accent.opacity(0.06)
                            .overlay(PepTheme.cardSurface.opacity(0.88))
                            .overlay(PepTheme.cardOverlay)
                    } else {
                        PepTheme.cardSurface
                            .overlay(PepTheme.cardOverlay)
                    }
                }
            )
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: accent.map { [$0.opacity(0.2), $0.opacity(0.06)] } ?? [PepTheme.glassBorderTop, PepTheme.glassBorderBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: (accent ?? .black).opacity(accent != nil ? 0.1 : 0.3), radius: 12, x: 0, y: 4)
    }
}
