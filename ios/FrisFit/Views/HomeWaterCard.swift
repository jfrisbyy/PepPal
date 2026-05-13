import SwiftUI

struct HomeWaterCard: View {
    @State private var waterVM = WaterViewModel.shared
    @State private var showWaterDetail: Bool = false
    @State private var animatedProgress: Double = 0
    @State private var goalCelebrate: Bool = false

    private let sideButtons: [WaterPreset] = [.glass, .cup, .bottle]

    var body: some View {
        let today = Date()
        let totalMl = waterVM.totalMl(for: today)
        let goal = max(waterVM.dailyGoalMl, 1)
        let progress = min(Double(totalMl) / Double(goal), 1.0)
        let oz = Int(Double(totalMl) / 29.5735)
        let goalOz = Int(Double(goal) / 29.5735)
        let remainingOz = max(0, goalOz - oz)
        let useOz = waterVM.unit == .oz
        let primary = useOz ? oz : totalMl
        let primaryGoal = useOz ? goalOz : goal
        let remaining = useOz ? remainingOz : max(0, goal - totalMl)
        let unitLabel = useOz ? "oz" : "ml"

        GlassCard(accent: PepTheme.blue) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "drop.fill")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.blue)
                    Text("Water")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    if let reason = waterVM.adaptiveWaterReason {
                        AdjustedChip(reason: reason, tint: PepTheme.blue)
                    }
                    Spacer()
                    Button {
                        showWaterDetail = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                HStack(alignment: .center, spacing: 14) {
                    PeptideBottleView(
                        fillFraction: animatedProgress,
                        liquidColor: PepTheme.blue,
                        compactHeight: 116
                    )
                    .frame(width: 64, height: 116)
                    .overlay(alignment: .center) {
                        VStack(spacing: 0) {
                            Text("\(primary)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(animatedProgress > 0.45 ? .white : PepTheme.textPrimary)
                                .shadow(color: .black.opacity(animatedProgress > 0.45 ? 0.28 : 0), radius: 1, y: 0.5)
                            Text(unitLabel)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle((animatedProgress > 0.45 ? Color.white : PepTheme.textSecondary).opacity(0.9))
                        }
                        .offset(y: 8)
                    }
                    .overlay(alignment: .top) {
                        if goalCelebrate {
                            Circle()
                                .fill(PepTheme.teal.opacity(0.35))
                                .frame(width: 80, height: 80)
                                .blur(radius: 18)
                                .offset(y: 10)
                                .transition(.opacity)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(primary) / \(primaryGoal) \(unitLabel)")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(PepTheme.textPrimary)
                            Text(remaining > 0 ? "\(remaining) \(unitLabel) to goal" : "Goal met")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(remaining > 0 ? PepTheme.textSecondary : PepTheme.teal)
                        }

                        VStack(spacing: 6) {
                            ForEach(sideButtons) { preset in
                                Button {
                                    waterVM.add(amountMl: preset.rawValue)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: preset.icon)
                                            .font(.system(size: 11, weight: .semibold))
                                            .frame(width: 14)
                                        Text(useOz ? "+\(preset.oz) oz" : "+\(preset.rawValue) ml")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                        Spacer(minLength: 0)
                                    }
                                    .foregroundStyle(PepTheme.blue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(PepTheme.blue.opacity(0.12))
                                    .clipShape(.rect(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                                .sensoryFeedback(.impact(weight: .light), trigger: totalMl)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.4) {
            showWaterDetail = true
        }
        .onAppear {
            animate(to: progress)
        }
        .onChange(of: progress) { _, new in
            animate(to: new)
            if new >= 1.0 {
                withAnimation(.easeInOut(duration: 0.6)) { goalCelebrate = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    withAnimation(.easeOut(duration: 0.6)) { goalCelebrate = false }
                }
            }
        }
        .task {
            if AuthService.shared.authState == .signedIn {
                await waterVM.load(date: today)
                animate(to: min(Double(waterVM.totalMl(for: today)) / Double(max(waterVM.dailyGoalMl, 1)), 1.0))
            }
        }
        .sheet(isPresented: $showWaterDetail) {
            WaterDetailSheet(viewModel: waterVM)
                .presentationDragIndicator(.visible)
        }
    }

    private func animate(to value: Double) {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.78)) {
            animatedProgress = value
        }
    }
}

// MARK: - Legacy bottle (unused, kept for reference)

private struct WaterBottleFillView: View {
    let progress: Double
    let wavePhase: Double
    let celebrate: Bool

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let bottle = bottlePath(in: CGRect(origin: .zero, size: size))

            ZStack {
                // Glass background
                bottle
                    .fill(
                        LinearGradient(
                            colors: [PepTheme.blue.opacity(0.10), PepTheme.blue.opacity(0.04)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Water fill, clipped to bottle shape
                WaterFillShape(progress: progress, wavePhase: wavePhase)
                    .fill(
                        LinearGradient(
                            colors: [PepTheme.blue.opacity(0.95), PepTheme.blue.opacity(0.65)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        WaterFillShape(progress: progress, wavePhase: wavePhase + .pi)
                            .fill(Color.white.opacity(celebrate ? 0.25 : 0.12))
                    )
                    .clipShape(bottle)

                // Glass highlight
                bottle
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.45), Color.white.opacity(0.05), PepTheme.blue.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )

                // Inner highlight stripe
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: max(2, size.width * 0.05), height: size.height * 0.42)
                    .offset(x: -size.width * 0.28, y: size.height * 0.05)
                    .blendMode(.plusLighter)
                    .mask(bottle)

                // Cap
                bottleCap(in: size)
            }
        }
    }

    private func bottlePath(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        // Bottle proportions: cap 14% from top, neck taper 14-26%, body to 100%
        let neckTopY = h * 0.14
        let shoulderY = h * 0.28
        let bodyTopY = h * 0.32
        let bottomY = h * 0.985
        let neckHalf = w * 0.18
        let bodyHalf = w * 0.46
        let cornerR = w * 0.18
        let cx = w / 2

        // Start top-left of neck
        p.move(to: CGPoint(x: cx - neckHalf, y: neckTopY))
        // Down the neck
        p.addLine(to: CGPoint(x: cx - neckHalf, y: shoulderY))
        // Shoulder curve out to body
        p.addQuadCurve(
            to: CGPoint(x: cx - bodyHalf, y: bodyTopY),
            control: CGPoint(x: cx - neckHalf, y: bodyTopY)
        )
        // Body left side down
        p.addLine(to: CGPoint(x: cx - bodyHalf, y: bottomY - cornerR))
        // Bottom-left corner
        p.addQuadCurve(
            to: CGPoint(x: cx - bodyHalf + cornerR, y: bottomY),
            control: CGPoint(x: cx - bodyHalf, y: bottomY)
        )
        // Bottom
        p.addLine(to: CGPoint(x: cx + bodyHalf - cornerR, y: bottomY))
        // Bottom-right corner
        p.addQuadCurve(
            to: CGPoint(x: cx + bodyHalf, y: bottomY - cornerR),
            control: CGPoint(x: cx + bodyHalf, y: bottomY)
        )
        // Body right side up
        p.addLine(to: CGPoint(x: cx + bodyHalf, y: bodyTopY))
        // Right shoulder curve in
        p.addQuadCurve(
            to: CGPoint(x: cx + neckHalf, y: shoulderY),
            control: CGPoint(x: cx + neckHalf, y: bodyTopY)
        )
        // Up the right neck
        p.addLine(to: CGPoint(x: cx + neckHalf, y: neckTopY))
        // Close top of neck
        p.closeSubpath()
        return p
    }

    @ViewBuilder
    private func bottleCap(in size: CGSize) -> some View {
        let capWidth = size.width * 0.42
        let capHeight = size.height * 0.12
        VStack(spacing: 1) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(PepTheme.blue.opacity(0.85))
                .frame(width: capWidth, height: capHeight * 0.7)
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(PepTheme.blue.opacity(0.55))
                .frame(width: capWidth * 0.95, height: capHeight * 0.25)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct WaterFillShape: Shape {
    var progress: Double
    var wavePhase: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(progress, wavePhase) }
        set { progress = newValue.first; wavePhase = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let clamped = max(0, min(progress, 1))
        // Fill rises in the body region (below ~14% top to bottom).
        let topAvailable = rect.height * 0.16
        let bottom = rect.height
        let waterTop = bottom - (bottom - topAvailable) * clamped
        let amplitude: CGFloat = clamped <= 0.001 ? 0 : 2.5
        let wavelength = rect.width * 1.1

        p.move(to: CGPoint(x: 0, y: waterTop))
        let steps = 36
        for i in 0...steps {
            let x = rect.width * CGFloat(i) / CGFloat(steps)
            let relative = (x / wavelength) * 2 * .pi
            let y = waterTop + sin(relative + wavePhase) * amplitude
            p.addLine(to: CGPoint(x: x, y: y))
        }
        p.addLine(to: CGPoint(x: rect.width, y: bottom))
        p.addLine(to: CGPoint(x: 0, y: bottom))
        p.closeSubpath()
        return p
    }
}
