import SwiftUI

struct GlassCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .background(
                FrisTheme.cardSurface
                    .overlay(FrisTheme.cardOverlay)
            )
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: [FrisTheme.glassBorderTop, FrisTheme.glassBorderBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
    }
}
