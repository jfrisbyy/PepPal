import SwiftUI

/// Small "ADJUSTED" badge surfaced on home tiles whose target has been
/// rewritten by an active adaptive bundle. The reason renders as the
/// accessibility hint and (when there's room) as inline secondary text.
struct AdjustedChip: View {
    let reason: String
    let tint: Color
    var compact: Bool = true

    @State private var pulse: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(tint)
                .frame(width: 5, height: 5)
                .opacity(pulse ? 1.0 : 0.45)
                .scaleEffect(pulse ? 1.0 : 0.7)
            Text("ADJUSTED")
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(tint.opacity(0.12), in: .capsule)
        .overlay(Capsule().strokeBorder(tint.opacity(0.28), lineWidth: 0.5))
        .accessibilityLabel("Adjusted")
        .accessibilityHint(reason)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
