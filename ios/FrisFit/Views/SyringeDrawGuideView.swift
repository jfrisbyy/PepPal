import SwiftUI

struct SyringeDrawGuideView: View {
    @Environment(\.dismiss) private var dismiss

    let compoundName: String
    let doseMcg: Double
    let concentrationMcgPerMl: Double
    let syringe: SyringeSpec

    @State private var pulseGlow: Bool = false

    private var targetMl: Double { doseMcg / concentrationMcgPerMl }
    private var targetUnits: Double { targetMl * syringe.unitsPerMl }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    syringeVisual
                    ticksBreakdown
                    instructions
                    tip
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .navigationTitle("Draw Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PepTheme.teal)
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulseGlow = true
                }
            }
        }
    }

    private var headerCard: some View {
        GlassCard(accent: PepTheme.teal) {
            VStack(alignment: .leading, spacing: 8) {
                Text(compoundName)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                HStack(spacing: 14) {
                    stat(title: "DOSE", value: formatDose(doseMcg))
                    divider
                    stat(title: "DRAW TO", value: "\(formatNum(targetUnits)) units", highlight: true)
                    divider
                    stat(title: "VOLUME", value: "\(formatVolume(targetMl)) mL")
                }
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(PepTheme.separatorColor).frame(width: 0.5, height: 28)
    }

    private func stat(title: String, value: String, highlight: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .heavy))
                .tracking(1)
                .foregroundStyle(PepTheme.textSecondary)
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(highlight ? PepTheme.teal : PepTheme.textPrimary)
        }
    }

    private var syringeVisual: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR SYRINGE — \(syringe.short)")
                .font(.system(size: 10, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)

            GeometryReader { geo in
                let width = geo.size.width
                let capacity = syringe.totalUnits
                let drawFraction = min(1.0, max(0.02, targetUnits / capacity))
                let fillWidth = width * CGFloat(drawFraction)

                ZStack(alignment: .leading) {
                    // barrel background
                    RoundedRectangle(cornerRadius: 10)
                        .fill(PepTheme.elevated)
                        .frame(height: 60)

                    // fluid
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(colors: [PepTheme.teal.opacity(0.8), PepTheme.blue.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: fillWidth, height: 60)

                    // ticks
                    Canvas { ctx, size in
                        let majorEvery = syringe.majorTick
                        let minorEvery = syringe.minorTick
                        let count = Int(capacity / minorEvery)
                        for i in 0...count {
                            let unit = Double(i) * minorEvery
                            let x = CGFloat(unit / capacity) * size.width
                            let isMajor = unit.truncatingRemainder(dividingBy: majorEvery) == 0
                            let h: CGFloat = isMajor ? 14 : 7
                            let rect = CGRect(x: x, y: 0, width: 1, height: h)
                            ctx.fill(Path(rect), with: .color(.white.opacity(isMajor ? 0.85 : 0.5)))
                        }
                    }
                    .frame(height: 60)

                    // Draw-to indicator line
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 3, height: 84)
                        .shadow(color: PepTheme.teal.opacity(pulseGlow ? 0.9 : 0.3), radius: pulseGlow ? 12 : 4)
                        .offset(x: fillWidth - 1.5, y: -8)

                    // Number plate
                    VStack(spacing: 2) {
                        Text("\(formatNum(targetUnits))")
                            .font(.system(.subheadline, design: .rounded, weight: .heavy))
                            .foregroundStyle(.white)
                        Text("units")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(PepTheme.teal, in: .rect(cornerRadius: 6))
                    .offset(x: max(0, min(width - 44, fillWidth - 22)), y: -52)
                }
                // needle
                .overlay(alignment: .trailing) {
                    HStack(spacing: 0) {
                        Rectangle().fill(PepTheme.textSecondary.opacity(0.4)).frame(width: 6, height: 4)
                        Rectangle().fill(PepTheme.textSecondary.opacity(0.7)).frame(width: 26, height: 2)
                    }
                    .offset(x: 30, y: 0)
                }
            }
            .frame(height: 84)
            .padding(.vertical, 8)

            HStack {
                Text("0 u")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                Text("\(Int(syringe.totalUnits)) u")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
    }

    private var ticksBreakdown: some View {
        let units = targetUnits
        let whole = Int(units)
        let frac = units - Double(whole)
        let nearestMinor = syringe.minorTick
        let snapped = (units / nearestMinor).rounded() * nearestMinor
        return GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("HOW TO READ IT")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(PepTheme.textSecondary)
                bullet("Each minor tick = \(formatNum(nearestMinor)) unit\(nearestMinor == 1 ? "" : "s")")
                bullet("Each major tick = \(formatNum(syringe.majorTick)) units")
                if abs(snapped - units) < 0.01 {
                    bullet("Line up the plunger exactly with the **\(formatNum(units)) unit** mark.")
                } else {
                    bullet("Closest mark: **\(formatNum(snapped)) units** (off by \(String(format: "%.2f", abs(snapped - units))) u)")
                }
                if frac > 0 && frac < 1 && nearestMinor == 1 {
                    bullet("If you need \(formatNum(units)) and ticks are every 1 u, split the distance between \(whole) and \(whole + 1).")
                }
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(PepTheme.teal)
                .frame(width: 5, height: 5)
                .padding(.top, 7)
            Text(.init(text))
                .font(.subheadline)
                .foregroundStyle(PepTheme.textPrimary)
            Spacer(minLength: 0)
        }
    }

    private var instructions: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("STEP BY STEP")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(PepTheme.textSecondary)

                step(1, "Wipe the vial stopper with an alcohol swab — let it dry fully.")
                step(2, "Pull the plunger back to **\(formatNum(targetUnits)) units** (air).")
                step(3, "Insert the needle, push the air in, then flip vial upside down.")
                step(4, "Slowly draw solution until the plunger reaches **\(formatNum(targetUnits)) units**.")
                step(5, "Tap out any air bubbles, confirm volume, withdraw needle.")
            }
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle().fill(PepTheme.teal.opacity(0.18)).frame(width: 22, height: 22)
                Text("\(n)")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(PepTheme.teal)
            }
            Text(.init(text))
                .font(.subheadline)
                .foregroundStyle(PepTheme.textPrimary)
            Spacer(minLength: 0)
        }
    }

    private var tip: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(PepTheme.amber)
            Text("If your draw seems impossible (less than 2 u or more than syringe capacity), revisit your reconstitution volume.")
                .font(.caption)
                .foregroundStyle(PepTheme.textPrimary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.amber.opacity(0.1))
        .clipShape(.rect(cornerRadius: 12))
    }

    private func formatNum(_ d: Double) -> String {
        if d == d.rounded() { return String(Int(d)) }
        return String(format: "%.1f", d)
    }

    private func formatDose(_ mcg: Double) -> String {
        if mcg >= 1000 {
            let mg = mcg / 1000
            return mg == mg.rounded() ? "\(Int(mg)) mg" : String(format: "%.2f mg", mg)
        }
        return "\(Int(mcg)) mcg"
    }

    private func formatVolume(_ ml: Double) -> String {
        String(format: "%.2f", ml)
    }
}
