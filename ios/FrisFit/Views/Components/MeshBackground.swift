import SwiftUI

/// Quiet section-tinted mesh gradient background.
///
/// Use behind hero areas (Home, Compound Detail, Discover) to add depth
/// without overwhelming. Tints itself based on the dominant accent color
/// and respects light/dark appearance.
struct MeshBackground: View {
    var accent: Color = PepTheme.teal
    /// Higher = more visible mesh. Default is intentionally subtle.
    var intensity: Double = 0.18
    var animated: Bool = true

    @Environment(\.colorScheme) private var colorScheme
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            PepTheme.background
            mesh
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 18).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }

    @ViewBuilder
    private var mesh: some View {
        if #available(iOS 18.0, *) {
            MeshGradient(
                width: 3,
                height: 3,
                points: meshPoints,
                colors: meshColors
            )
            .opacity(intensity)
            .blur(radius: 20)
        } else {
            ZStack {
                RadialGradient(
                    colors: [accent.opacity(intensity), .clear],
                    center: .topLeading, startRadius: 0, endRadius: 380
                )
                RadialGradient(
                    colors: [accent.opacity(intensity * 0.6), .clear],
                    center: .bottomTrailing, startRadius: 0, endRadius: 420
                )
            }
        }
    }

    private var meshPoints: [SIMD2<Float>] {
        let p = Float(phase)
        return [
            SIMD2<Float>(0, 0),
            SIMD2<Float>(0.5 + 0.05 * p, 0),
            SIMD2<Float>(1, 0),
            SIMD2<Float>(0, 0.5 - 0.05 * p),
            SIMD2<Float>(0.5, 0.5 + 0.05 * p),
            SIMD2<Float>(1, 0.5 - 0.05 * p),
            SIMD2<Float>(0, 1),
            SIMD2<Float>(0.5 - 0.05 * p, 1),
            SIMD2<Float>(1, 1)
        ]
    }

    private var meshColors: [Color] {
        let base = colorScheme == .dark
            ? Color.black
            : Color.white
        let warm = colorScheme == .dark
            ? accent.opacity(0.85)
            : accent.opacity(0.65)
        let cool = colorScheme == .dark
            ? PepTheme.violet.opacity(0.55)
            : PepTheme.violet.opacity(0.35)
        return [
            warm,        base,        cool,
            base,        accent.opacity(0.4), base,
            cool.opacity(0.6), base,  warm.opacity(0.6)
        ]
    }
}

#Preview("Compound") {
    MeshBackground(accent: PepSection.compound)
}

#Preview("Nutrition") {
    MeshBackground(accent: PepSection.nutrition)
}
