import SwiftUI

struct InjectionBodyMapView: View {
    let viewModel: ProtocolDetailViewModel

    private let sitePositions: [(site: InjectionSite, xFront: CGFloat, yFront: CGFloat, xBack: CGFloat, yBack: CGFloat)] = [
        (.leftDeltoid, 0.22, 0.18, 0.78, 0.18),
        (.rightDeltoid, 0.78, 0.18, 0.22, 0.18),
        (.leftAbdomen, 0.35, 0.42, -1, -1),
        (.rightAbdomen, 0.65, 0.42, -1, -1),
        (.leftThigh, 0.37, 0.68, -1, -1),
        (.rightThigh, 0.63, 0.68, -1, -1),
        (.leftGlute, -1, -1, 0.37, 0.48),
        (.rightGlute, -1, -1, 0.63, 0.48),
    ]

    @State private var showBack: Bool = false

    var body: some View {
        VStack(spacing: 10) {
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
                ZStack {
                    bodyOutline(width: geo.size.width, height: geo.size.height)

                    ForEach(sitePositions, id: \.site) { pos in
                        let x = showBack ? pos.xBack : pos.xFront
                        let y = showBack ? pos.yBack : pos.yFront

                        if x >= 0 && y >= 0 {
                            let recency = viewModel.siteRecency(pos.site)
                            let isSuggested = viewModel.suggestedNextSite == pos.site

                            Button {
                                viewModel.newDoseSite = pos.site
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(recency.color)
                                        .frame(width: 24, height: 24)

                                    if isSuggested {
                                        Circle()
                                            .strokeBorder(PepTheme.teal, lineWidth: 2)
                                            .frame(width: 30, height: 30)
                                    }

                                    if viewModel.newDoseSite == pos.site {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .position(x: geo.size.width * x, y: geo.size.height * y)
                            }
                        }
                    }
                }
            }
            .frame(height: 220)

            HStack(spacing: 0) {
                ForEach(showBack ? backSites : frontSites, id: \.self) { site in
                    let recency = viewModel.siteRecency(site)
                    VStack(spacing: 3) {
                        Circle()
                            .fill(recency.color)
                            .frame(width: 8, height: 8)
                        Text(site.shortName)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var frontSites: [InjectionSite] {
        [.leftDeltoid, .rightDeltoid, .leftAbdomen, .rightAbdomen, .leftThigh, .rightThigh]
    }

    private var backSites: [InjectionSite] {
        [.leftDeltoid, .rightDeltoid, .leftGlute, .rightGlute]
    }

    private func bodyOutline(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(PepTheme.elevated.opacity(0.4))
                .frame(width: width, height: height)

            VStack(spacing: 4) {
                Circle()
                    .fill(PepTheme.textSecondary.opacity(0.12))
                    .frame(width: 28, height: 28)

                RoundedRectangle(cornerRadius: 8)
                    .fill(PepTheme.textSecondary.opacity(0.08))
                    .frame(width: 50, height: 70)

                HStack(spacing: 20) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(PepTheme.textSecondary.opacity(0.08))
                        .frame(width: 16, height: 50)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(PepTheme.textSecondary.opacity(0.08))
                        .frame(width: 16, height: 50)
                }

                HStack(spacing: 10) {
                    Capsule()
                        .fill(PepTheme.textSecondary.opacity(0.06))
                        .frame(width: 14, height: 20)
                        .rotationEffect(.degrees(-5))
                    Capsule()
                        .fill(PepTheme.textSecondary.opacity(0.06))
                        .frame(width: 14, height: 20)
                        .rotationEffect(.degrees(5))
                }
            }

            Text(showBack ? "BACK" : "FRONT")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.25))
                .offset(y: -height / 2 + 14)
        }
    }
}
