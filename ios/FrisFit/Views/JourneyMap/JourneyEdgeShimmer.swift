import SwiftUI

/// Thin shimmer band drawn just under the date axis while a background
/// range-fetch is in flight. Non-blocking — the timeline stays interactive.
struct JourneyEdgeShimmer: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            Rectangle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.0), location: 0.0),
                            .init(color: PepTheme.teal.opacity(0.55), location: 0.5),
                            .init(color: .white.opacity(0.0), location: 1.0)
                        ],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(width: max(120, w * 0.4))
                .offset(x: phase * w)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
        }
        .blendMode(.plusLighter)
    }
}
