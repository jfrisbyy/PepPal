import SwiftUI

/// Smoothly rolls numeric values up/down when they change.
/// Drop-in replacement for `Text("\(value)")` on hero numbers.
struct AnimatedCounter: View {
    let value: Double
    var format: String = "%.0f"
    var font: Font = .pepDisplay(size: 44, weight: .semibold)
    var color: Color = PepTheme.textPrimary
    var monospaced: Bool = true

    @State private var displayed: Double = 0
    @State private var hasAppeared: Bool = false

    var body: some View {
        Text(String(format: format, displayed))
            .font(font)
            .foregroundStyle(color)
            .modifier(MonoIfNeeded(monospaced: monospaced))
            .contentTransition(.numericText(value: displayed))
            .onAppear {
                guard !hasAppeared else { return }
                hasAppeared = true
                displayed = 0
                withAnimation(.spring(response: 1.1, dampingFraction: 0.85)) {
                    displayed = value
                }
            }
            .onChange(of: value) { _, newValue in
                withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
                    displayed = newValue
                }
            }
    }
}

private struct MonoIfNeeded: ViewModifier {
    let monospaced: Bool
    func body(content: Content) -> some View {
        if monospaced {
            content.monospacedDigit()
        } else {
            content
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        AnimatedCounter(value: 1247)
        AnimatedCounter(
            value: 8.4,
            format: "%.1f",
            font: .pepDisplay(size: 64, weight: .semibold),
            color: PepTheme.teal
        )
    }
    .padding()
    .background(PepTheme.background)
}
