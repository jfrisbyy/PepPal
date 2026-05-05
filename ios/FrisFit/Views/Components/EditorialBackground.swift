import SwiftUI

/// Editorial, magazine-feeling canvas: base wash + soft vignette +
/// faint section tint + a fine, static film-grain texture.
///
/// Drop this *behind* a screen's content as a full-bleed background.
/// Cards/lists/charts on top keep their existing styling.
struct EditorialBackground: View {
    /// Optional subtle accent tint that bleeds in from the top.
    /// Defaults to the Home tab's teal whisper.
    var accent: Color = PepTheme.teal
    /// Strength of the section tint (0...1). Keep this whisper-quiet.
    var accentStrength: Double = 0.10
    /// Grain opacity — tuned per appearance internally.
    var grainOpacity: Double = 1.0

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            // 1. Base wash
            PepTheme.background

            // 2. Section tint — single warm/cool haze high up.
            // Drawn as a large radial so it never has hard edges.
            GeometryReader { geo in
                let size = geo.size
                RadialGradient(
                    colors: [
                        accent.opacity(accentStrength),
                        accent.opacity(0)
                    ],
                    center: UnitPoint(x: 0.5, y: -0.05),
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * 0.85
                )
                .blendMode(scheme == .dark ? .plusLighter : .multiply)
            }

            // 3. Film grain
            FilmGrainLayer(scheme: scheme)
                .opacity(grainOpacity)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Film grain

/// Static fine-grain noise drawn once into an offscreen bitmap via
/// `.drawingGroup()`, then tiled-blended over the canvas. Tuned so the
/// texture reads as "paper" in light mode and "filmic" in dark mode.
private struct FilmGrainLayer: View {
    let scheme: ColorScheme

    /// Tile size kept small so the noise looks fine, not blotchy.
    private let tile: CGFloat = 220

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            // Seeded RNG so the grain is stable across redraws.
            var rng = SeededRandom(seed: 0xC0FFEE)

            // Roughly one speck per ~3 px² → fine, papery noise.
            let pixelCount = Int((size.width * size.height) / 3.0)

            let darkSpeck = scheme == .dark ? 0.055 : 0.045
            let lightSpeck = scheme == .dark ? 0.045 : 0.060

            for _ in 0..<pixelCount {
                let x = CGFloat(rng.nextUnit()) * size.width
                let y = CGFloat(rng.nextUnit()) * size.height
                let r = CGFloat(rng.nextUnit()) * 0.9 + 0.25
                let coin = rng.nextUnit()

                let alpha: Double
                let color: Color
                if coin < 0.5 {
                    color = .black
                    alpha = darkSpeck * Double(rng.nextUnit())
                } else {
                    color = .white
                    alpha = lightSpeck * Double(rng.nextUnit())
                }

                let rect = CGRect(x: x, y: y, width: r, height: r)
                context.fill(Path(ellipseIn: rect), with: .color(color.opacity(alpha)))
            }
        }
        .frame(width: tile, height: tile)
        // Cache the noise to a bitmap and tile it across the screen.
        .drawingGroup(opaque: false)
        .modifier(TiledGrainModifier(tile: tile, scheme: scheme))
    }
}

private struct TiledGrainModifier: ViewModifier {
    let tile: CGFloat
    let scheme: ColorScheme

    func body(content: Content) -> some View {
        GeometryReader { geo in
            let cols = Int(ceil(geo.size.width / tile)) + 1
            let rows = Int(ceil(geo.size.height / tile)) + 1
            ZStack(alignment: .topLeading) {
                ForEach(0..<rows, id: \.self) { row in
                    ForEach(0..<cols, id: \.self) { col in
                        content
                            .frame(width: tile, height: tile)
                            .offset(x: CGFloat(col) * tile, y: CGFloat(row) * tile)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .blendMode(scheme == .dark ? .plusLighter : .multiply)
            .opacity(scheme == .dark ? 0.55 : 0.65)
        }
    }
}

// MARK: - Deterministic RNG (so grain is stable, not flickering)

private struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed != 0 ? seed : 0xDEADBEEF }

    mutating func next() -> UInt64 {
        // xorshift64
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    /// Uniform float in [0, 1).
    mutating func nextUnit() -> Float {
        Float(next() & 0xFFFFFF) / Float(0x1000000)
    }
}
