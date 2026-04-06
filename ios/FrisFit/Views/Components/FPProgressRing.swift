import SwiftUI

struct FPProgressRing: View {
    let currentFP: Int
    let targetFP: Int
    let progress: Double
    var size: CGFloat = 180
    var lineWidth: CGFloat = 14
    var fontSize: CGFloat = 42
    var showSubtitle: Bool = true

    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(FrisTheme.cyan.opacity(0.15), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [FrisTheme.cyan.opacity(0.6), FrisTheme.cyan],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * animatedProgress)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: FrisTheme.cyan.opacity(0.4), radius: 6, x: 0, y: 0)

            VStack(spacing: showSubtitle ? 2 : 1) {
                Text("\(currentFP)")
                    .font(.system(size: fontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(FrisTheme.cyan)
                Text("/ \(targetFP)")
                    .font(.system(size: showSubtitle ? 13 : fontSize * 0.38, weight: .medium, design: .rounded))
                    .foregroundStyle(FrisTheme.textSecondary)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                animatedProgress = min(progress, 1.0)
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animatedProgress = min(newValue, 1.0)
            }
        }
    }
}
