import SwiftUI

/// Stylized glass peptide bottle with a colored liquid, a continuous wave
/// animation, and a subtle moving highlight shimmer.
///
/// `fillFraction` is 0...1; the liquid level animates whenever it changes.
struct PeptideBottleView: View {
    let fillFraction: Double
    let liquidColor: Color
    var compactHeight: CGFloat = 96
    var showHighlights: Bool = true

    @Environment(\.colorScheme) private var colorScheme
    @State private var wavePhase: CGFloat = 0
    @State private var shimmerPhase: CGFloat = -1

    private var clampedFill: CGFloat {
        CGFloat(max(0, min(1, fillFraction)))
    }

    private var glassTint: Color {
        colorScheme == .dark ? .white : .black
    }

    private var glassFillOpacityTop: Double {
        colorScheme == .dark ? 0.10 : 0.04
    }

    private var glassFillOpacityBottom: Double {
        colorScheme == .dark ? 0.03 : 0.01
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let neckW = w * 0.42
            let neckH = h * 0.10
            let capH = h * 0.08
            let bodyTop = capH + neckH
            let bodyHeight = h - bodyTop
            let bodyRect = CGRect(x: 0, y: bodyTop, width: w, height: bodyHeight)
            let bodyShape = RoundedRectangle(cornerRadius: w * 0.22, style: .continuous)

            ZStack {
                // Cap
                RoundedRectangle(cornerRadius: w * 0.08, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [Color(white: 0.55), Color(white: 0.32)]
                                : [Color(white: 0.78), Color(white: 0.55)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: neckW * 1.05, height: capH)
                    .position(x: w / 2, y: capH / 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: w * 0.08)
                            .strokeBorder(glassTint.opacity(0.18), lineWidth: 0.6)
                            .frame(width: neckW * 1.05, height: capH)
                            .position(x: w / 2, y: capH / 2)
                    )

                // Neck
                Rectangle()
                    .fill(glassTint.opacity(0.06))
                    .frame(width: neckW, height: neckH)
                    .position(x: w / 2, y: capH + neckH / 2)
                    .overlay(
                        Rectangle()
                            .strokeBorder(glassTint.opacity(0.10), lineWidth: 0.5)
                            .frame(width: neckW, height: neckH)
                            .position(x: w / 2, y: capH + neckH / 2)
                    )

                // Glass body background
                bodyShape
                    .fill(
                        LinearGradient(
                            colors: [
                                glassTint.opacity(glassFillOpacityTop),
                                glassTint.opacity(glassFillOpacityBottom)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: w, height: bodyHeight)
                    .position(x: w / 2, y: bodyTop + bodyHeight / 2)

                // Liquid (clipped to body)
                LiquidFillShape(fillFraction: clampedFill, wavePhase: wavePhase)
                    .fill(
                        LinearGradient(
                            colors: [
                                liquidColor.opacity(0.95),
                                liquidColor.opacity(0.70)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: bodyRect.width, height: bodyRect.height)
                    .position(x: bodyRect.midX, y: bodyRect.midY)
                    .mask(
                        bodyShape
                            .frame(width: w, height: bodyHeight)
                            .position(x: w / 2, y: bodyTop + bodyHeight / 2)
                    )
                    .animation(.spring(response: 0.7, dampingFraction: 0.85), value: clampedFill)

                // Liquid surface shimmer (slow moving highlight)
                if showHighlights && clampedFill > 0.02 {
                    let surfaceY = bodyTop + bodyHeight * (1 - clampedFill)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0), .white.opacity(0.55), .white.opacity(0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: w * 0.35, height: max(2, bodyHeight * 0.014))
                        .blur(radius: 0.6)
                        .position(
                            x: w * 0.5 + (shimmerPhase * w * 0.35),
                            y: surfaceY + 1
                        )
                        .mask(
                            bodyShape
                                .frame(width: w, height: bodyHeight)
                                .position(x: w / 2, y: bodyTop + bodyHeight / 2)
                        )
                }

                // Tick marks on the body
                if showHighlights {
                    VStack(spacing: bodyHeight / 6) {
                        ForEach(0..<5, id: \.self) { _ in
                            Rectangle()
                                .fill(glassTint.opacity(0.18))
                                .frame(width: w * 0.06, height: 1)
                        }
                    }
                    .frame(width: w, height: bodyHeight, alignment: .leading)
                    .padding(.leading, w * 0.10)
                    .position(x: w / 2, y: bodyTop + bodyHeight / 2)
                }

                // Glass highlights (rim + vertical pearly streak)
                if showHighlights {
                    bodyShape
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(colorScheme == .dark ? 0.45 : 0.7),
                                    .white.opacity(0.06),
                                    .white.opacity(0.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                        .frame(width: w, height: bodyHeight)
                        .position(x: w / 2, y: bodyTop + bodyHeight / 2)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(colorScheme == .dark ? 0.40 : 0.55), .white.opacity(0)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(width: w * 0.05, height: bodyHeight * 0.65)
                        .position(x: w * 0.18, y: bodyTop + bodyHeight * 0.42)
                        .blur(radius: 0.4)
                }
            }
        }
        .aspectRatio(0.55, contentMode: .fit)
        .frame(height: compactHeight)
        .onAppear {
            startWaveAnimation()
            startShimmer()
        }
    }

    private func startWaveAnimation() {
        withAnimation(.linear(duration: 3.2).repeatForever(autoreverses: false)) {
            wavePhase = .pi * 2
        }
    }

    private func startShimmer() {
        shimmerPhase = -1
        withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: false)) {
            shimmerPhase = 1
        }
    }
}

/// Liquid shape with a sine-wave top edge.
private struct LiquidFillShape: Shape, @unchecked Sendable {
    var fillFraction: CGFloat
    var wavePhase: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(fillFraction, wavePhase) }
        set {
            fillFraction = newValue.first
            wavePhase = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let level = rect.height * (1 - fillFraction)
        let waveAmp: CGFloat = max(1.5, min(4, rect.height * 0.02))
        let waveLen = rect.width

        p.move(to: CGPoint(x: 0, y: rect.height))
        p.addLine(to: CGPoint(x: 0, y: level))

        let steps = 32
        for i in 0...steps {
            let x = rect.width * CGFloat(i) / CGFloat(steps)
            let phase = (x / waveLen) * .pi * 2 + wavePhase
            let y = level + sin(phase) * waveAmp
            p.addLine(to: CGPoint(x: x, y: y))
        }

        p.addLine(to: CGPoint(x: rect.width, y: rect.height))
        p.closeSubpath()
        return p
    }
}

#Preview {
    HStack(spacing: 20) {
        PeptideBottleView(
            fillFraction: 0.96,
            liquidColor: Color(red: 0.30, green: 0.80, blue: 0.50),
            compactHeight: 140
        )
        PeptideBottleView(
            fillFraction: 0.42,
            liquidColor: Color(red: 1.0, green: 0.62, blue: 0.20),
            compactHeight: 140
        )
        PeptideBottleView(
            fillFraction: 0.12,
            liquidColor: Color(red: 0.55, green: 0.40, blue: 0.95),
            compactHeight: 140
        )
    }
    .padding()
    .background(PepTheme.background)
}
