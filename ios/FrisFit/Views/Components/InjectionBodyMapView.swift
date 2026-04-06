import SwiftUI

struct InjectionBodyMapView: View {
    let viewModel: ProtocolDetailViewModel

    private let sitePositions: [(site: InjectionSite, xFront: CGFloat, yFront: CGFloat, xBack: CGFloat, yBack: CGFloat)] = [
        (.leftDeltoid, 0.24, 0.20, 0.76, 0.20),
        (.rightDeltoid, 0.76, 0.20, 0.24, 0.20),
        (.leftAbdomen, 0.38, 0.43, -1, -1),
        (.rightAbdomen, 0.62, 0.43, -1, -1),
        (.leftThigh, 0.38, 0.70, -1, -1),
        (.rightThigh, 0.62, 0.70, -1, -1),
        (.leftGlute, -1, -1, 0.38, 0.48),
        (.rightGlute, -1, -1, 0.62, 0.48),
    ]

    @State private var showBack: Bool = false
    @State private var pulsePhase: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showBack = false
                    }
                } label: {
                    Text("Front")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(!showBack ? PepTheme.invertedText : PepTheme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(!showBack ? PepTheme.teal : PepTheme.elevated)
                        .clipShape(.capsule)
                }

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showBack = true
                    }
                } label: {
                    Text("Back")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(showBack ? PepTheme.invertedText : PepTheme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(showBack ? PepTheme.teal : PepTheme.elevated)
                        .clipShape(.capsule)
                }
            }

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 0.04, green: 0.04, blue: 0.08))

                    Canvas { context, size in
                        drawHeatZones(context: &context, size: size)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    bodyShape(width: w, height: h)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    Canvas { context, size in
                        drawHeatZonesClipped(context: &context, size: size)
                    }
                    .mask(bodyShape(width: w, height: h))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    ForEach(sitePositions, id: \.site) { pos in
                        let x = showBack ? pos.xBack : pos.xFront
                        let y = showBack ? pos.yBack : pos.yFront

                        if x >= 0 && y >= 0 {
                            let recency = viewModel.siteRecency(pos.site)
                            let isSuggested = viewModel.suggestedNextSite == pos.site
                            let isSelected = viewModel.newDoseSite == pos.site

                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                    viewModel.newDoseSite = pos.site
                                }
                            } label: {
                                ZStack {
                                    if recency != .unused {
                                        Circle()
                                            .fill(recency.heatColor.opacity(0.3))
                                            .frame(width: 44, height: 44)
                                            .blur(radius: 8)
                                    }

                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                colors: [
                                                    recency.heatColor,
                                                    recency.heatColor.opacity(0.6)
                                                ],
                                                center: .center,
                                                startRadius: 0,
                                                endRadius: 14
                                            )
                                        )
                                        .frame(width: 22, height: 22)
                                        .shadow(color: recency.heatColor.opacity(0.6), radius: 6)

                                    Circle()
                                        .fill(.white.opacity(0.25))
                                        .frame(width: 8, height: 8)
                                        .offset(x: -3, y: -3)

                                    if isSuggested && !isSelected {
                                        Circle()
                                            .strokeBorder(PepTheme.teal, lineWidth: 2)
                                            .frame(width: 30, height: 30)
                                            .scaleEffect(pulsePhase ? 1.15 : 1.0)
                                            .opacity(pulsePhase ? 0.5 : 1.0)
                                    }

                                    if isSelected {
                                        Circle()
                                            .strokeBorder(.white, lineWidth: 2.5)
                                            .frame(width: 30, height: 30)

                                        Image(systemName: "checkmark")
                                            .font(.system(size: 9, weight: .black))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .position(x: w * x, y: h * y)
                            }
                        }
                    }

                    Text(showBack ? "BACK" : "FRONT")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.15))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(10)

                    scanLineOverlay(height: h)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .frame(height: 260)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulsePhase = true
                }
            }

            heatMapLegend

            siteLabelGrid
        }
    }

    // MARK: - Heat Zone Drawing

    private func drawHeatZones(context: inout GraphicsContext, size: CGSize) {
        let activeSites = sitePositions.compactMap { pos -> (CGPoint, SiteRecency)? in
            let x = showBack ? pos.xBack : pos.xFront
            let y = showBack ? pos.yBack : pos.yFront
            guard x >= 0 && y >= 0 else { return nil }
            let recency = viewModel.siteRecency(pos.site)
            guard recency != .unused else { return nil }
            return (CGPoint(x: size.width * x, y: size.height * y), recency)
        }

        for (point, recency) in activeSites {
            let radius: CGFloat = recency == .overused ? 50 : recency == .recentlyUsed ? 38 : 28
            let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
            let gradient = Gradient(colors: [
                recency.heatColor.opacity(0.06),
                recency.heatColor.opacity(0.0)
            ])
            context.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(gradient, center: point, startRadius: 0, endRadius: radius)
            )
        }
    }

    private func drawHeatZonesClipped(context: inout GraphicsContext, size: CGSize) {
        let activeSites = sitePositions.compactMap { pos -> (CGPoint, SiteRecency)? in
            let x = showBack ? pos.xBack : pos.xFront
            let y = showBack ? pos.yBack : pos.yFront
            guard x >= 0 && y >= 0 else { return nil }
            let recency = viewModel.siteRecency(pos.site)
            guard recency != .unused else { return nil }
            return (CGPoint(x: size.width * x, y: size.height * y), recency)
        }

        for (point, recency) in activeSites {
            let radius: CGFloat = recency == .overused ? 60 : recency == .recentlyUsed ? 45 : 32
            let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
            let gradient = Gradient(colors: [
                recency.heatColor.opacity(0.5),
                recency.heatColor.opacity(0.2),
                recency.heatColor.opacity(0.0)
            ])
            context.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(gradient, center: point, startRadius: 0, endRadius: radius)
            )
        }
    }

    // MARK: - Body Silhouette

    private func bodyShape(width: CGFloat, height: CGFloat) -> some View {
        let cx = width * 0.5
        let bodyFill = showBack ? Color(red: 0.12, green: 0.12, blue: 0.18) : Color(red: 0.10, green: 0.10, blue: 0.16)

        return ZStack {
            // Head
            Ellipse()
                .fill(bodyFill)
                .frame(width: 36, height: 40)
                .position(x: cx, y: height * 0.07)

            // Neck
            RoundedRectangle(cornerRadius: 4)
                .fill(bodyFill)
                .frame(width: 18, height: 14)
                .position(x: cx, y: height * 0.12)

            // Torso
            BodyTorsoShape()
                .fill(bodyFill)
                .frame(width: 90, height: 110)
                .position(x: cx, y: height * 0.32)

            // Left arm
            BodyArmShape(isLeft: true)
                .fill(bodyFill)
                .frame(width: 28, height: 105)
                .position(x: cx - 58, y: height * 0.30)

            // Right arm
            BodyArmShape(isLeft: false)
                .fill(bodyFill)
                .frame(width: 28, height: 105)
                .position(x: cx + 58, y: height * 0.30)

            // Left leg
            BodyLegShape(isLeft: true)
                .fill(bodyFill)
                .frame(width: 34, height: 120)
                .position(x: cx - 22, y: height * 0.72)

            // Right leg
            BodyLegShape(isLeft: false)
                .fill(bodyFill)
                .frame(width: 34, height: 120)
                .position(x: cx + 22, y: height * 0.72)
        }
    }

    // MARK: - Scan Line Overlay

    private func scanLineOverlay(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<Int(height / 3), id: \.self) { _ in
                Rectangle()
                    .fill(.white.opacity(0.012))
                    .frame(height: 1)
                Rectangle()
                    .fill(.clear)
                    .frame(height: 2)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Legend

    private var heatMapLegend: some View {
        HStack(spacing: 16) {
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

    // MARK: - Site Labels

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

// MARK: - Body Part Shapes

struct BodyTorsoShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: w * 0.15, y: 0))
        p.addQuadCurve(to: CGPoint(x: 0, y: h * 0.15), control: CGPoint(x: 0, y: 0))
        p.addCurve(to: CGPoint(x: w * 0.08, y: h * 0.55),
                   control1: CGPoint(x: -w * 0.02, y: h * 0.3),
                   control2: CGPoint(x: w * 0.02, y: h * 0.45))
        p.addCurve(to: CGPoint(x: w * 0.12, y: h),
                   control1: CGPoint(x: w * 0.10, y: h * 0.65),
                   control2: CGPoint(x: w * 0.08, y: h * 0.85))
        p.addLine(to: CGPoint(x: w * 0.88, y: h))
        p.addCurve(to: CGPoint(x: w * 0.92, y: h * 0.55),
                   control1: CGPoint(x: w * 0.92, y: h * 0.85),
                   control2: CGPoint(x: w * 0.90, y: h * 0.65))
        p.addCurve(to: CGPoint(x: w, y: h * 0.15),
                   control1: CGPoint(x: w * 0.98, y: h * 0.45),
                   control2: CGPoint(x: w * 1.02, y: h * 0.3))
        p.addQuadCurve(to: CGPoint(x: w * 0.85, y: 0), control: CGPoint(x: w, y: 0))
        p.closeSubpath()
        return p
    }
}

struct BodyArmShape: Shape {
    let isLeft: Bool

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        if isLeft {
            p.move(to: CGPoint(x: w * 0.8, y: 0))
            p.addCurve(to: CGPoint(x: w * 0.3, y: h * 0.45),
                       control1: CGPoint(x: w * 0.6, y: h * 0.1),
                       control2: CGPoint(x: w * 0.2, y: h * 0.25))
            p.addCurve(to: CGPoint(x: w * 0.15, y: h),
                       control1: CGPoint(x: w * 0.25, y: h * 0.65),
                       control2: CGPoint(x: w * 0.1, y: h * 0.85))
            p.addLine(to: CGPoint(x: w * 0.55, y: h))
            p.addCurve(to: CGPoint(x: w * 0.7, y: h * 0.45),
                       control1: CGPoint(x: w * 0.5, y: h * 0.85),
                       control2: CGPoint(x: w * 0.55, y: h * 0.65))
            p.addCurve(to: CGPoint(x: w, y: 0),
                       control1: CGPoint(x: w * 0.75, y: h * 0.25),
                       control2: CGPoint(x: w * 0.9, y: h * 0.1))
        } else {
            p.move(to: CGPoint(x: w * 0.2, y: 0))
            p.addCurve(to: CGPoint(x: w * 0.7, y: h * 0.45),
                       control1: CGPoint(x: w * 0.4, y: h * 0.1),
                       control2: CGPoint(x: w * 0.8, y: h * 0.25))
            p.addCurve(to: CGPoint(x: w * 0.85, y: h),
                       control1: CGPoint(x: w * 0.75, y: h * 0.65),
                       control2: CGPoint(x: w * 0.9, y: h * 0.85))
            p.addLine(to: CGPoint(x: w * 0.45, y: h))
            p.addCurve(to: CGPoint(x: w * 0.3, y: h * 0.45),
                       control1: CGPoint(x: w * 0.5, y: h * 0.85),
                       control2: CGPoint(x: w * 0.45, y: h * 0.65))
            p.addCurve(to: CGPoint(x: 0, y: 0),
                       control1: CGPoint(x: w * 0.25, y: h * 0.25),
                       control2: CGPoint(x: w * 0.1, y: h * 0.1))
        }
        p.closeSubpath()
        return p
    }
}

struct BodyLegShape: Shape {
    let isLeft: Bool

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let inset: CGFloat = isLeft ? 0.1 : 0.0
        let outset: CGFloat = isLeft ? 0.0 : 0.1
        p.move(to: CGPoint(x: w * (0.05 + inset), y: 0))
        p.addCurve(to: CGPoint(x: w * (0.0 + inset), y: h),
                   control1: CGPoint(x: w * (0.0 + inset), y: h * 0.35),
                   control2: CGPoint(x: w * (0.05 + inset), y: h * 0.7))
        p.addLine(to: CGPoint(x: w * (0.85 - outset), y: h))
        p.addCurve(to: CGPoint(x: w * (0.95 - outset), y: 0),
                   control1: CGPoint(x: w * (0.95 - outset), y: h * 0.7),
                   control2: CGPoint(x: w * (1.0 - outset), y: h * 0.35))
        p.closeSubpath()
        return p
    }
}

// MARK: - Heat Color Extension

extension SiteRecency {
    var heatColor: Color {
        switch self {
        case .unused: return Color(red: 0.3, green: 0.3, blue: 0.4)
        case .rotated: return Color(red: 0.1, green: 0.7, blue: 0.9)
        case .recentlyUsed: return Color(red: 1.0, green: 0.75, blue: 0.0)
        case .overused: return Color(red: 1.0, green: 0.2, blue: 0.15)
        }
    }
}
