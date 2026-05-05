import SwiftUI

struct InjectionBodyMapView: View {
    let viewModel: ProtocolDetailViewModel

    // Normalized site positions on a 1.0 x 1.0 silhouette canvas.
    // -1 means the site is not visible from that side.
    private let sitePositions: [(site: InjectionSite, xFront: CGFloat, yFront: CGFloat, xBack: CGFloat, yBack: CGFloat)] = [
        (.leftDeltoid,  0.30, 0.235, 0.70, 0.235),
        (.rightDeltoid, 0.70, 0.235, 0.30, 0.235),
        (.leftAbdomen,  0.43, 0.46,  -1,   -1),
        (.rightAbdomen, 0.57, 0.46,  -1,   -1),
        (.leftThigh,    0.43, 0.72,  -1,   -1),
        (.rightThigh,   0.57, 0.72,  -1,   -1),
        (.leftGlute,    -1,   -1,    0.43, 0.575),
        (.rightGlute,   -1,   -1,    0.57, 0.575),
    ]

    @State private var showBack: Bool = false
    @State private var pulsePhase: Bool = false

    var body: some View {
        VStack(spacing: 14) {
            sideToggle

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                ZStack {
                    // Editorial backdrop
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.06, green: 0.07, blue: 0.10),
                                    Color(red: 0.03, green: 0.04, blue: 0.06)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    // Subtle vertical center beam
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.0),
                                    Color.white.opacity(0.03),
                                    Color.white.opacity(0.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)

                    // Soft floor shadow under the figure
                    Ellipse()
                        .fill(Color.black.opacity(0.35))
                        .frame(width: w * 0.35, height: 14)
                        .blur(radius: 10)
                        .position(x: w * 0.5, y: h * 0.965)

                    // Heat aura behind the body
                    Canvas { context, size in
                        drawHeatZones(context: &context, size: size, intensity: 0.08)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                    // The silhouette itself
                    bodySilhouette(width: w, height: h)

                    // Heat zones masked to body
                    Canvas { context, size in
                        drawHeatZones(context: &context, size: size, intensity: 0.45)
                    }
                    .mask(bodySilhouette(width: w, height: h, maskMode: true))
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                    // Site dots
                    ForEach(sitePositions, id: \.site) { pos in
                        let x = showBack ? pos.xBack : pos.xFront
                        let y = showBack ? pos.yBack : pos.yFront

                        if x >= 0 && y >= 0 {
                            siteDot(site: pos.site, x: x, y: y, w: w, h: h)
                        }
                    }

                    // Side label (top corner)
                    Text(showBack ? "POSTERIOR" : "ANTERIOR")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.18))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(14)
                }
            }
            .frame(height: 320)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulsePhase = true
                }
            }

            heatMapLegend

            siteLabelGrid
        }
    }

    // MARK: - Toggle

    private var sideToggle: some View {
        HStack(spacing: 4) {
            toggleChip(title: "Front", active: !showBack) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showBack = false }
            }
            toggleChip(title: "Back", active: showBack) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showBack = true }
            }
        }
        .padding(3)
        .background(PepTheme.elevated)
        .clipShape(.capsule)
    }

    private func toggleChip(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(active ? PepTheme.invertedText : PepTheme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(active ? PepTheme.teal : Color.clear)
                .clipShape(.capsule)
        }
    }

    // MARK: - Site dot

    private func siteDot(site: InjectionSite, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) -> some View {
        let recency = viewModel.siteRecency(site)
        let isSuggested = viewModel.suggestedNextSite == site
        let isSelected = viewModel.newDoseSite == site

        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                viewModel.newDoseSite = site
            }
        } label: {
            ZStack {
                if recency != .unused {
                    Circle()
                        .fill(recency.heatColor.opacity(0.35))
                        .frame(width: 46, height: 46)
                        .blur(radius: 9)
                }

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                recency.heatColor,
                                recency.heatColor.opacity(0.55)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 13
                        )
                    )
                    .frame(width: 18, height: 18)
                    .overlay(
                        Circle()
                            .strokeBorder(.white.opacity(0.35), lineWidth: 0.5)
                    )
                    .shadow(color: recency.heatColor.opacity(0.7), radius: 6)

                Circle()
                    .fill(.white.opacity(0.5))
                    .frame(width: 5, height: 5)
                    .offset(x: -2.5, y: -2.5)

                if isSuggested && !isSelected {
                    Circle()
                        .strokeBorder(PepTheme.teal, lineWidth: 1.5)
                        .frame(width: 30, height: 30)
                        .scaleEffect(pulsePhase ? 1.2 : 1.0)
                        .opacity(pulsePhase ? 0.4 : 1.0)
                }

                if isSelected {
                    Circle()
                        .strokeBorder(.white, lineWidth: 2)
                        .frame(width: 30, height: 30)

                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.white)
                }
            }
            .position(x: w * x, y: h * y)
        }
    }

    // MARK: - Heat zones

    private func drawHeatZones(context: inout GraphicsContext, size: CGSize, intensity: Double) {
        let active = sitePositions.compactMap { pos -> (CGPoint, SiteRecency)? in
            let x = showBack ? pos.xBack : pos.xFront
            let y = showBack ? pos.yBack : pos.yFront
            guard x >= 0 && y >= 0 else { return nil }
            let recency = viewModel.siteRecency(pos.site)
            guard recency != .unused else { return nil }
            return (CGPoint(x: size.width * x, y: size.height * y), recency)
        }

        for (point, recency) in active {
            let radius: CGFloat = recency == .overused ? 55 : recency == .recentlyUsed ? 42 : 32
            let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
            let gradient = Gradient(colors: [
                recency.heatColor.opacity(intensity),
                recency.heatColor.opacity(intensity * 0.4),
                recency.heatColor.opacity(0)
            ])
            context.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(gradient, center: point, startRadius: 0, endRadius: radius)
            )
        }
    }

    // MARK: - Body silhouette (single unified path)

    @ViewBuilder
    private func bodySilhouette(width w: CGFloat, height h: CGFloat, maskMode: Bool = false) -> some View {
        let shape = HumanSilhouetteShape(showBack: showBack)

        if maskMode {
            shape.fill(.white)
        } else {
            ZStack {
                // Outer rim glow
                shape
                    .stroke(PepTheme.teal.opacity(0.18), lineWidth: 1)
                    .blur(radius: 4)

                // Body fill — gradient gives subtle volume
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.16, green: 0.17, blue: 0.22),
                                Color(red: 0.10, green: 0.11, blue: 0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Highlight edge
                shape
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.22),
                                Color.white.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )

                // Centerline anatomical crease
                if !showBack {
                    Path { p in
                        p.move(to: CGPoint(x: w * 0.5, y: h * 0.20))
                        p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.55))
                    }
                    .stroke(Color.black.opacity(0.35), lineWidth: 0.7)
                } else {
                    Path { p in
                        p.move(to: CGPoint(x: w * 0.5, y: h * 0.18))
                        p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.60))
                    }
                    .stroke(Color.black.opacity(0.45), lineWidth: 0.8)
                }
            }
        }
    }

    // MARK: - Legend

    private var heatMapLegend: some View {
        HStack(spacing: 14) {
            legendDot(color: SiteRecency.rotated.heatColor, label: "Cool")
            legendDot(color: SiteRecency.recentlyUsed.heatColor, label: "Warm")
            legendDot(color: SiteRecency.overused.heatColor, label: "Hot")
            legendDot(color: SiteRecency.unused.heatColor, label: "Unused")

            Spacer()

            HStack(spacing: 4) {
                Circle()
                    .strokeBorder(PepTheme.teal, lineWidth: 1.5)
                    .frame(width: 10, height: 10)
                Text("Suggested")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .shadow(color: color.opacity(0.5), radius: 3)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
    }

    // MARK: - Site labels

    private var siteLabelGrid: some View {
        HStack(spacing: 0) {
            ForEach(showBack ? backSites : frontSites, id: \.self) { site in
                let recency = viewModel.siteRecency(site)
                let isSelected = viewModel.newDoseSite == site
                VStack(spacing: 3) {
                    Circle()
                        .fill(recency.heatColor)
                        .frame(width: 8, height: 8)
                        .shadow(color: recency.heatColor.opacity(0.4), radius: 2)
                    Text(site.shortName)
                        .font(.system(size: 9, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? PepTheme.textPrimary : PepTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var frontSites: [InjectionSite] {
        [.leftDeltoid, .rightDeltoid, .leftAbdomen, .rightAbdomen, .leftThigh, .rightThigh]
    }

    private var backSites: [InjectionSite] {
        [.leftDeltoid, .rightDeltoid, .leftGlute, .rightGlute]
    }
}

// MARK: - Human Silhouette Shape

/// A single, anatomically-aware silhouette path that scales to any rect.
/// All control points are normalized so the figure stays centered and proportional.
struct HumanSilhouetteShape: Shape {
    let showBack: Bool

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let cx = w * 0.5

        // Vertical anchors (normalized to height)
        let headTop      = h * 0.04
        let headBottom   = h * 0.135
        let neckBottom   = h * 0.165
        let shoulderY    = h * 0.195
        let chestY       = h * 0.27
        let waistY       = h * 0.435
        let hipY         = h * 0.555
        let crotchY      = h * 0.605
        let kneeY        = h * 0.79
        let ankleY       = h * 0.965
        let footY        = h * 0.99

        // Horizontal anchors (normalized to width)
        let headHalf     = w * 0.062
        let neckHalf     = w * 0.038
        let shoulderHalf = w * 0.205
        let chestHalf    = w * 0.175
        let waistHalf    = w * 0.115
        let hipHalf      = w * 0.175
        let thighHalf    = w * 0.095
        let kneeHalf     = w * 0.072
        let ankleHalf    = w * 0.052
        let footHalf     = w * 0.075

        // Arm anchors
        let bicepHalf    = w * 0.058
        let elbowHalf    = w * 0.048
        let wristHalf    = w * 0.038
        let elbowY       = h * 0.41
        let wristY       = h * 0.585
        let armOuterTop  = shoulderHalf - w * 0.005
        let armOuterEl   = shoulderHalf + w * 0.005
        let armOuterWr   = shoulderHalf - w * 0.025
        let armInnerTop  = chestHalf - w * 0.015

        // ───── Head + neck (top) ─────
        p.move(to: CGPoint(x: cx - neckHalf, y: neckBottom))
        // up to left jaw
        p.addQuadCurve(
            to: CGPoint(x: cx - headHalf, y: headBottom - h * 0.005),
            control: CGPoint(x: cx - neckHalf - w * 0.01, y: neckBottom - h * 0.015)
        )
        // around the head (left → top → right)
        p.addCurve(
            to: CGPoint(x: cx + headHalf, y: headBottom - h * 0.005),
            control1: CGPoint(x: cx - headHalf - w * 0.005, y: headTop),
            control2: CGPoint(x: cx + headHalf + w * 0.005, y: headTop)
        )
        // right jaw down to right neck
        p.addQuadCurve(
            to: CGPoint(x: cx + neckHalf, y: neckBottom),
            control: CGPoint(x: cx + neckHalf + w * 0.01, y: neckBottom - h * 0.015)
        )

        // ───── Right shoulder + arm (down outer right side) ─────
        // shoulder cap
        p.addQuadCurve(
            to: CGPoint(x: cx + shoulderHalf, y: shoulderY),
            control: CGPoint(x: cx + neckHalf + w * 0.04, y: shoulderY - h * 0.01)
        )
        // outer arm: shoulder → bicep → elbow → wrist
        p.addCurve(
            to: CGPoint(x: cx + armOuterEl, y: elbowY),
            control1: CGPoint(x: cx + armOuterTop, y: chestY),
            control2: CGPoint(x: cx + armOuterTop + w * 0.005, y: chestY + h * 0.06)
        )
        p.addCurve(
            to: CGPoint(x: cx + armOuterWr, y: wristY),
            control1: CGPoint(x: cx + armOuterEl + w * 0.005, y: elbowY + h * 0.05),
            control2: CGPoint(x: cx + armOuterEl - w * 0.005, y: wristY - h * 0.04)
        )
        // hand (right)
        p.addQuadCurve(
            to: CGPoint(x: cx + armOuterWr - w * 0.005, y: wristY + h * 0.045),
            control: CGPoint(x: cx + armOuterWr + w * 0.025, y: wristY + h * 0.03)
        )
        // wrist inner up
        p.addQuadCurve(
            to: CGPoint(x: cx + armOuterWr - wristHalf, y: wristY),
            control: CGPoint(x: cx + armOuterWr - wristHalf - w * 0.005, y: wristY + h * 0.02)
        )
        // inner arm: wrist → elbow → armpit
        p.addCurve(
            to: CGPoint(x: cx + chestHalf - w * 0.01, y: elbowY - h * 0.01),
            control1: CGPoint(x: cx + armOuterEl - elbowHalf, y: wristY - h * 0.05),
            control2: CGPoint(x: cx + armOuterTop - bicepHalf, y: elbowY + h * 0.01)
        )
        p.addCurve(
            to: CGPoint(x: cx + armInnerTop, y: chestY),
            control1: CGPoint(x: cx + chestHalf - w * 0.005, y: chestY + h * 0.06),
            control2: CGPoint(x: cx + armInnerTop + w * 0.01, y: chestY + h * 0.02)
        )

        // ───── Right side of torso: chest → waist → hip ─────
        p.addQuadCurve(
            to: CGPoint(x: cx + waistHalf, y: waistY),
            control: CGPoint(x: cx + chestHalf - w * 0.01, y: chestY + h * 0.08)
        )
        p.addQuadCurve(
            to: CGPoint(x: cx + hipHalf, y: hipY),
            control: CGPoint(x: cx + waistHalf + w * 0.005, y: hipY - h * 0.04)
        )

        // ───── Right leg: hip → outer thigh → knee → ankle → foot ─────
        p.addCurve(
            to: CGPoint(x: cx + thighHalf + w * 0.025, y: kneeY - h * 0.06),
            control1: CGPoint(x: cx + hipHalf, y: hipY + h * 0.07),
            control2: CGPoint(x: cx + thighHalf + w * 0.03, y: kneeY - h * 0.18)
        )
        p.addQuadCurve(
            to: CGPoint(x: cx + kneeHalf, y: kneeY),
            control: CGPoint(x: cx + thighHalf + w * 0.018, y: kneeY - h * 0.015)
        )
        p.addCurve(
            to: CGPoint(x: cx + ankleHalf, y: ankleY),
            control1: CGPoint(x: cx + kneeHalf - w * 0.005, y: kneeY + h * 0.06),
            control2: CGPoint(x: cx + ankleHalf + w * 0.005, y: ankleY - h * 0.05)
        )
        // right foot
        p.addQuadCurve(
            to: CGPoint(x: cx + footHalf, y: footY),
            control: CGPoint(x: cx + footHalf, y: footY - h * 0.005)
        )
        p.addLine(to: CGPoint(x: cx + w * 0.018, y: footY))

        // ───── Inner right leg: ankle → crotch ─────
        p.addLine(to: CGPoint(x: cx + w * 0.018, y: ankleY - h * 0.005))
        p.addCurve(
            to: CGPoint(x: cx + w * 0.005, y: crotchY),
            control1: CGPoint(x: cx + w * 0.045, y: kneeY + h * 0.05),
            control2: CGPoint(x: cx + w * 0.04, y: kneeY - h * 0.05)
        )

        // ───── Crotch ─────
        p.addQuadCurve(
            to: CGPoint(x: cx - w * 0.005, y: crotchY),
            control: CGPoint(x: cx, y: crotchY + h * 0.012)
        )

        // ───── Left leg: crotch → inner ankle → foot → outer thigh → hip ─────
        p.addCurve(
            to: CGPoint(x: cx - w * 0.018, y: ankleY - h * 0.005),
            control1: CGPoint(x: cx - w * 0.04, y: kneeY - h * 0.05),
            control2: CGPoint(x: cx - w * 0.045, y: kneeY + h * 0.05)
        )
        p.addLine(to: CGPoint(x: cx - w * 0.018, y: footY))
        p.addLine(to: CGPoint(x: cx - footHalf, y: footY))
        p.addQuadCurve(
            to: CGPoint(x: cx - ankleHalf, y: ankleY),
            control: CGPoint(x: cx - footHalf, y: footY - h * 0.005)
        )
        p.addCurve(
            to: CGPoint(x: cx - kneeHalf, y: kneeY),
            control1: CGPoint(x: cx - ankleHalf - w * 0.005, y: ankleY - h * 0.05),
            control2: CGPoint(x: cx - kneeHalf + w * 0.005, y: kneeY + h * 0.06)
        )
        p.addQuadCurve(
            to: CGPoint(x: cx - thighHalf - w * 0.025, y: kneeY - h * 0.06),
            control: CGPoint(x: cx - thighHalf - w * 0.018, y: kneeY - h * 0.015)
        )
        p.addCurve(
            to: CGPoint(x: cx - hipHalf, y: hipY),
            control1: CGPoint(x: cx - thighHalf - w * 0.03, y: kneeY - h * 0.18),
            control2: CGPoint(x: cx - hipHalf, y: hipY + h * 0.07)
        )

        // ───── Left side of torso: hip → waist → chest ─────
        p.addQuadCurve(
            to: CGPoint(x: cx - waistHalf, y: waistY),
            control: CGPoint(x: cx - waistHalf - w * 0.005, y: hipY - h * 0.04)
        )
        p.addQuadCurve(
            to: CGPoint(x: cx - armInnerTop, y: chestY),
            control: CGPoint(x: cx - chestHalf + w * 0.01, y: chestY + h * 0.08)
        )

        // ───── Left arm: armpit → elbow → wrist → hand → outer arm → shoulder ─────
        p.addCurve(
            to: CGPoint(x: cx - chestHalf + w * 0.01, y: elbowY - h * 0.01),
            control1: CGPoint(x: cx - armInnerTop - w * 0.01, y: chestY + h * 0.02),
            control2: CGPoint(x: cx - chestHalf + w * 0.005, y: chestY + h * 0.06)
        )
        p.addCurve(
            to: CGPoint(x: cx - armOuterWr + wristHalf, y: wristY),
            control1: CGPoint(x: cx - armOuterTop + bicepHalf, y: elbowY + h * 0.01),
            control2: CGPoint(x: cx - armOuterEl + elbowHalf, y: wristY - h * 0.05)
        )
        p.addQuadCurve(
            to: CGPoint(x: cx - armOuterWr + w * 0.005, y: wristY + h * 0.045),
            control: CGPoint(x: cx - armOuterWr + wristHalf + w * 0.005, y: wristY + h * 0.02)
        )
        p.addQuadCurve(
            to: CGPoint(x: cx - armOuterWr, y: wristY),
            control: CGPoint(x: cx - armOuterWr - w * 0.025, y: wristY + h * 0.03)
        )
        p.addCurve(
            to: CGPoint(x: cx - armOuterEl, y: elbowY),
            control1: CGPoint(x: cx - armOuterEl + w * 0.005, y: wristY - h * 0.04),
            control2: CGPoint(x: cx - armOuterEl - w * 0.005, y: elbowY + h * 0.05)
        )
        p.addCurve(
            to: CGPoint(x: cx - shoulderHalf, y: shoulderY),
            control1: CGPoint(x: cx - armOuterTop - w * 0.005, y: chestY + h * 0.06),
            control2: CGPoint(x: cx - armOuterTop, y: chestY)
        )
        p.addQuadCurve(
            to: CGPoint(x: cx - neckHalf, y: neckBottom),
            control: CGPoint(x: cx - neckHalf - w * 0.04, y: shoulderY - h * 0.01)
        )

        p.closeSubpath()
        return p
    }
}

// MARK: - Heat Color Extension

extension SiteRecency {
    var heatColor: Color {
        switch self {
        case .unused: return Color(red: 0.30, green: 0.32, blue: 0.42)
        case .rotated: return Color(red: 0.10, green: 0.72, blue: 0.92)
        case .recentlyUsed: return Color(red: 1.00, green: 0.74, blue: 0.10)
        case .overused: return Color(red: 1.00, green: 0.25, blue: 0.20)
        }
    }
}
