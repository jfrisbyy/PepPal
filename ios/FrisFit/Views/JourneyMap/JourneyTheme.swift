import SwiftUI
import UIKit

/// Visual + motion tokens for the Journey Map. Centralizes the cinematic feel
/// (springs, haptics, palettes, gradients) so every lane renderer shares the
/// same vocabulary.
nonisolated enum JourneyMotion {
    /// response 0.6 / dampingFraction 0.9 — Story Mode beats, ambient motion.
    static let gentle: Animation = .spring(response: 0.6, dampingFraction: 0.9)
    /// response 0.5 / dampingFraction 0.8 — everyday interactions, pin add, lane collapse.
    static let standard: Animation = .spring(response: 0.5, dampingFraction: 0.8)
    /// response 0.45 / dampingFraction 0.7 — milestone moments, streak rewards.
    static let celebratory: Animation = .spring(response: 0.45, dampingFraction: 0.7)
}

/// Haptic vocabulary for the Journey Map.
nonisolated enum JourneyHaptics {
    @MainActor static func soft() {
        let g = UIImpactFeedbackGenerator(style: .soft)
        g.prepare(); g.impactOccurred(intensity: 0.5)
    }
    @MainActor static func light() {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.prepare(); g.impactOccurred()
    }
    @MainActor static func medium() {
        let g = UIImpactFeedbackGenerator(style: .medium)
        g.prepare(); g.impactOccurred()
    }
    @MainActor static func success() {
        let g = UINotificationFeedbackGenerator()
        g.prepare(); g.notificationOccurred(.success)
    }
}

/// Compound-class jewel-tone gradient palette. Maps a compound name to a
/// two-stop gradient. Falls back to the lane teal.
@MainActor
enum JourneyCompoundPalette {
    static func gradient(for compoundName: String?) -> LinearGradient {
        let stops = stops(for: compoundName)
        return LinearGradient(colors: stops, startPoint: .leading, endPoint: .trailing)
    }

    static func accent(for compoundName: String?) -> Color {
        stops(for: compoundName).last ?? PepTheme.teal
    }

    private static func stops(for compoundName: String?) -> [Color] {
        let n = (compoundName ?? "").lowercased()
        // GLP-1 — teal → mint
        if n.contains("semaglutide") || n.contains("tirzepatide") || n.contains("retatrutide")
            || n.contains("ozempic") || n.contains("mounjaro") || n.contains("wegovy")
            || n.contains("glp") {
            return [
                Color(red: 0/255, green: 170/255, blue: 160/255),
                Color(red: 120/255, green: 230/255, blue: 200/255)
            ]
        }
        // Growth peptides — warm amber
        if n.contains("ipamorelin") || n.contains("sermorelin") || n.contains("tesamorelin")
            || n.contains("ghrp") || n.contains("hexarelin") || n.contains("mk-677")
            || n.contains("cjc") || n.contains("hgh") || n.contains("igf") {
            return [
                Color(red: 200/255, green: 120/255, blue: 30/255),
                Color(red: 255/255, green: 200/255, blue: 90/255)
            ]
        }
        // Healing — soft violet
        if n.contains("bpc") || n.contains("tb-500") || n.contains("tb500")
            || n.contains("ghk") || n.contains("kpv") || n.contains("thymosin") {
            return [
                Color(red: 110/255, green: 70/255, blue: 200/255),
                Color(red: 180/255, green: 140/255, blue: 240/255)
            ]
        }
        // Recovery / sleep — deep indigo
        if n.contains("dsip") || n.contains("epitalon") || n.contains("selank")
            || n.contains("semax") || n.contains("melatonin") || n.contains("sleep") {
            return [
                Color(red: 50/255, green: 60/255, blue: 160/255),
                Color(red: 110/255, green: 130/255, blue: 220/255)
            ]
        }
        // Default — lane teal soft
        return [
            Color(red: 0/255, green: 150/255, blue: 140/255),
            Color(red: 90/255, green: 220/255, blue: 200/255)
        ]
    }
}

/// Background gradient that shifts subtly cooler → warmer left to right,
/// layered over a deep, slightly warm near-black. Never pure black.
struct JourneyBackground: View {
    var body: some View {
        ZStack {
            Color(red: 14/255, green: 14/255, blue: 16/255)
                .ignoresSafeArea()
            LinearGradient(
                colors: [
                    Color(red: 24/255, green: 28/255, blue: 44/255).opacity(0.55),
                    Color(red: 18/255, green: 18/255, blue: 24/255).opacity(0.20),
                    Color(red: 36/255, green: 26/255, blue: 22/255).opacity(0.40)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .ignoresSafeArea()
            RadialGradient(
                colors: [
                    Color.white.opacity(0.05),
                    Color.clear
                ],
                center: .top,
                startRadius: 0,
                endRadius: 320
            )
            .ignoresSafeArea()
            .blendMode(.plusLighter)
        }
    }
}

/// Today marker: glowing teal vertical rule with a softly breathing dot.
struct TodayPulseMarker: View {
    var height: CGFloat
    @State private var pulse: Bool = false

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [
                    PepTheme.teal.opacity(0.0),
                    PepTheme.teal.opacity(0.55),
                    PepTheme.teal.opacity(0.0)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(width: 1.2, height: height)
            .shadow(color: PepTheme.teal.opacity(0.6), radius: 6)

            Circle()
                .fill(PepTheme.teal)
                .frame(width: 10, height: 10)
                .shadow(color: PepTheme.teal.opacity(0.8), radius: 8)
                .scaleEffect(pulse ? 1.05 : 0.95)
                .opacity(pulse ? 1.0 : 0.85)
                .offset(y: -2)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                }
        }
    }
}

/// Future goal marker — target dot with a soft outward radiating ring.
struct GoalRadiatingDot: View {
    var color: Color = PepTheme.amber
    @State private var ring: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(color.opacity(ring ? 0.0 : 0.55), lineWidth: 1.2)
                .frame(width: ring ? 28 : 10, height: ring ? 28 : 10)
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .shadow(color: color.opacity(0.7), radius: 4)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                ring = true
            }
        }
    }
}

/// Crystalline milestone node — multi-faceted, catches light, soft outward glow.
struct CrystallineMilestoneNode: View {
    var color: Color
    var size: CGFloat = 22
    var icon: String?

    var body: some View {
        ZStack {
            // Soft outward glow
            Circle()
                .fill(color.opacity(0.35))
                .frame(width: size * 1.9, height: size * 1.9)
                .blur(radius: 10)
            // Faceted body
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            color.opacity(0.95),
                            color.opacity(0.55),
                            Color.white.opacity(0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.45), lineWidth: 0.6)
                )
                .rotationEffect(.degrees(45))
                .frame(width: size, height: size)
                .shadow(color: color.opacity(0.5), radius: 4, y: 1)
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: size * 0.42, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.95))
            }
        }
    }
}
