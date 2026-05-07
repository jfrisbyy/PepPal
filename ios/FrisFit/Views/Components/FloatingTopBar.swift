import SwiftUI

/// A circular, glass-style floating action button used as a replacement for
/// traditional nav-bar buttons. Designed to sit on top of scrolling content
/// so the underlying text scrolls cleanly around it (the ultraThinMaterial
/// keeps it readable while letting the content peek through at the edges).
struct FloatingNavButton: View {
    let systemImage: String
    let action: () -> Void
    var tint: Color = PepTheme.textPrimary
    var size: CGFloat = 38

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(PepTheme.separatorColor, lineWidth: 0.5))
                .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
    }
}

/// Wraps any leading and trailing actions as floating circular buttons that
/// overlay the top of the view. Hides the native navigation bar so the
/// scroll content can flow cleanly behind/around the floating buttons.
private struct FloatingTopBarModifier<Leading: View, Trailing: View>: ViewModifier {
    let leading: Leading
    let trailing: Trailing
    let topPadding: CGFloat

    func body(content: Content) -> some View {
        content
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .top) {
                HStack(alignment: .top) {
                    leading
                    Spacer(minLength: 8)
                    trailing
                }
                .padding(.horizontal, 16)
                .padding(.top, topPadding)
                .allowsHitTesting(true)
            }
    }
}

extension View {
    /// Adds floating leading/trailing action buttons to a view, replacing the
    /// system navigation bar. The view's content scrolls cleanly underneath.
    func floatingTopBar<L: View, T: View>(
        topPadding: CGFloat = 6,
        @ViewBuilder leading: () -> L,
        @ViewBuilder trailing: () -> T = { EmptyView() }
    ) -> some View {
        modifier(FloatingTopBarModifier(leading: leading(), trailing: trailing(), topPadding: topPadding))
    }
}
