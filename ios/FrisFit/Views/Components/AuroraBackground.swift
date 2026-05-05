import SwiftUI

/// Premium "Hermès boutique meets iOS 26" backdrop.
///
/// A deep, warm canvas with two slow-drifting light orbs and a hairline
/// vignette. Designed to sit *behind* glass cards so that translucent
/// surfaces have something rich to refract against.
///
/// Use as a full-bleed background on a screen:
///
/// ```swift
/// ScrollView { ... }
///     .background(AuroraBackground(accent: PepTheme.teal))
/// ```
struct AuroraBackground: View {
    /// Primary accent the orbs glow with.
    var accent: Color = PepTheme.teal
    /// Secondary accent used for the second orb (defaults to a warm contrast).
    var secondaryAccent: Color = Color(red: 196/255, green: 142/255, blue: 92/255) // saddle / cognac
    /// Strength of the orbs (0...1). Keep luxurious — never loud.
    var intensity: Double = 1.0

    @Environment(\.colorScheme) private var scheme
    @State private var drift: Double = 0

    var body: some View {
        ZStack {
            // 1. Base wash — slightly richer than PepTheme.background for the boutique feel
            baseWash
                .ignoresSafeArea()

            // 2. Drifting orbs
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                // Orb 1 — accent, top-left, floats slowly diagonally
                orb(color: accent, radius: w * 0.85)
                    .position(
                        x: w * (0.18 + 0.08 * sin(drift * 0.6)),
                        y: h * (0.12 + 0.05 * cos(drift * 0.5))
                    )
                    .opacity(orbOpacity * intensity)

                // Orb 2 — warm secondary, bottom-right
                orb(color: secondaryAccent, radius: w * 0.95)
                    .position(
                        x: w * (0.82 + 0.06 * cos(drift * 0.4)),
                        y: h * (0.78 + 0.04 * sin(drift * 0.55))
                    )
                    .opacity(orbOpacity * intensity * 0.9)
            }
            .blendMode(scheme == .dark ? .plusLighter : .multiply)
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // 3. Subtle hairline vignette to focus the eye
            GeometryReader { geo in
                RadialGradient(
                    colors: [
                        Color.black.opacity(0),
                        Color.black.opacity(scheme == .dark ? 0.32 : 0.10)
                    ],
                    center: .center,
                    startRadius: min(geo.size.width, geo.size.height) * 0.30,
                    endRadius: max(geo.size.width, geo.size.height) * 0.85
                )
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // 4. Whisper of grain to keep the canvas tactile, not plasticky
            Rectangle()
                .fill(Color.clear)
                .overlay(
                    Canvas(rendersAsynchronously: true) { ctx, size in
                        var rng = UInt64(0xC0FFEE)
                        let count = Int((size.width * size.height) / 6.0)
                        for _ in 0..<count {
                            rng ^= rng << 13; rng ^= rng >> 7; rng ^= rng << 17
                            let x = CGFloat(Double(rng & 0xFFFF) / 65535.0) * size.width
                            rng ^= rng << 13; rng ^= rng >> 7; rng ^= rng << 17
                            let y = CGFloat(Double(rng & 0xFFFF) / 65535.0) * size.height
                            rng ^= rng << 13; rng ^= rng >> 7; rng ^= rng << 17
                            let a = Double(rng & 0xFF) / 255.0 * (scheme == .dark ? 0.05 : 0.04)
                            ctx.fill(
                                Path(ellipseIn: CGRect(x: x, y: y, width: 0.6, height: 0.6)),
                                with: .color(Color.white.opacity(a))
                            )
                        }
                    }
                )
                .blendMode(.overlay)
                .opacity(0.6)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .onAppear {
            withAnimation(.linear(duration: 30).repeatForever(autoreverses: true)) {
                drift = .pi * 2
            }
        }
    }

    private var baseWash: some View {
        // A warmer, deeper base than the standard PepTheme.background.
        let dark = LinearGradient(
            colors: [
                Color(red: 12/255, green: 11/255, blue: 16/255),
                Color(red: 18/255, green: 16/255, blue: 22/255),
                Color(red: 10/255, green: 9/255, blue: 14/255)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        let light = LinearGradient(
            colors: [
                Color(red: 248/255, green: 244/255, blue: 237/255),
                Color(red: 252/255, green: 248/255, blue: 242/255),
                Color(red: 244/255, green: 239/255, blue: 231/255)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        return Group {
            if scheme == .dark {
                Rectangle().fill(dark)
            } else {
                Rectangle().fill(light)
            }
        }
    }

    private func orb(color: Color, radius: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        color.opacity(scheme == .dark ? 0.55 : 0.30),
                        color.opacity(scheme == .dark ? 0.18 : 0.10),
                        color.opacity(0.0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: radius / 2
                )
            )
            .frame(width: radius, height: radius)
            .blur(radius: 60)
    }

    private var orbOpacity: Double {
        scheme == .dark ? 0.85 : 0.55
    }
}

#Preview {
    ZStack {
        AuroraBackground()
        VStack {
            Text("Aurora").font(.system(.largeTitle, design: .serif, weight: .bold))
        }
    }
}
