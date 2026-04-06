import SwiftUI

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1.0

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: max(0, phase - 0.3)),
                            .init(color: FrisTheme.glassBorderTop, location: phase),
                            .init(color: .clear, location: min(1, phase + 0.3))
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .allowsHitTesting(false)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 2.0
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

struct SkeletonBlock: View {
    var height: CGFloat = 16
    var width: CGFloat? = nil
    var cornerRadius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(FrisTheme.elevated)
            .frame(maxWidth: width ?? .infinity)
            .frame(height: height)
            .shimmer()
    }
}

struct SkeletonCard: View {
    var lineCount: Int = 3

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    SkeletonBlock(height: 40, width: 40, cornerRadius: 20)
                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonBlock(height: 14, width: 120)
                        SkeletonBlock(height: 10, width: 80)
                    }
                    Spacer()
                }
                ForEach(0..<lineCount, id: \.self) { i in
                    SkeletonBlock(height: 12, width: i == lineCount - 1 ? 180 : nil)
                }
            }
        }
    }
}

struct SkeletonHomeView: View {
    var body: some View {
        VStack(spacing: 20) {
            SkeletonBlock(height: 180, cornerRadius: 90)
                .frame(width: 180)
                .frame(maxWidth: .infinity)

            SkeletonCard(lineCount: 2)
            SkeletonCard(lineCount: 3)
            SkeletonCard(lineCount: 2)

            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(spacing: 8) {
                        SkeletonBlock(height: 16, width: 16, cornerRadius: 8)
                        SkeletonBlock(height: 20, width: 40)
                        SkeletonBlock(height: 10, width: 50)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 14)
            .background(FrisTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 16))
        }
        .padding(.horizontal)
    }
}

struct SkeletonFeedView: View {
    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<4, id: \.self) { _ in
                SkeletonCard(lineCount: 4)
            }
        }
        .padding(.horizontal)
    }
}

struct SkeletonTrainView: View {
    var body: some View {
        VStack(spacing: 16) {
            SkeletonCard(lineCount: 3)

            SkeletonBlock(height: 52, cornerRadius: 14)
            HStack(spacing: 10) {
                SkeletonBlock(height: 52, cornerRadius: 14)
                SkeletonBlock(height: 52, cornerRadius: 14)
            }

            VStack(alignment: .leading, spacing: 12) {
                SkeletonBlock(height: 18, width: 120)
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(0..<3, id: \.self) { _ in
                            SkeletonBlock(height: 100, width: 160, cornerRadius: 14)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            ForEach(0..<3, id: \.self) { _ in
                SkeletonBlock(height: 64, cornerRadius: 12)
            }
        }
        .padding(.horizontal)
    }
}

struct SkeletonMarketView: View {
    var body: some View {
        VStack(spacing: 24) {
            SkeletonBlock(height: 320, cornerRadius: 20)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                SkeletonBlock(height: 20, width: 160)
                    .padding(.horizontal)
                ScrollView(.horizontal) {
                    HStack(spacing: 14) {
                        ForEach(0..<4, id: \.self) { _ in
                            SkeletonBlock(height: 200, width: 160, cornerRadius: 14)
                        }
                    }
                }
                .contentMargins(.horizontal, 16)
                .scrollIndicators(.hidden)
            }
        }
    }
}

struct SkeletonProfileView: View {
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 14) {
                SkeletonBlock(height: 96, width: 96, cornerRadius: 48)
                SkeletonBlock(height: 22, width: 140)
                SkeletonBlock(height: 14, width: 100)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(spacing: 6) {
                        SkeletonBlock(height: 16, width: 16, cornerRadius: 8)
                        SkeletonBlock(height: 22, width: 50)
                        SkeletonBlock(height: 10, width: 55)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 16)
            .background(FrisTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 16))

            ForEach(0..<3, id: \.self) { _ in
                SkeletonCard(lineCount: 1)
            }
        }
        .padding(.horizontal)
    }
}
