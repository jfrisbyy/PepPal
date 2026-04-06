import SwiftUI

struct RestTimerView: View {
    let secondsRemaining: Int
    let totalSeconds: Int
    let onSkip: () -> Void

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - (Double(secondsRemaining) / Double(totalSeconds))
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("REST")
                .font(.system(size: 12, weight: .bold))
                .tracking(2)
                .foregroundStyle(FrisTheme.textSecondary)

            ZStack {
                Circle()
                    .stroke(FrisTheme.elevated, lineWidth: 8)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        FrisTheme.cyan,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                VStack(spacing: 4) {
                    Text(formattedTime)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(FrisTheme.textPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText())

                    Text("remaining")
                        .font(.caption)
                        .foregroundStyle(FrisTheme.textSecondary)
                }
            }
            .frame(width: 180, height: 180)

            Button(action: onSkip) {
                HStack(spacing: 8) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14))
                    Text("Skip Rest")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(FrisTheme.cyan)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(FrisTheme.cyan.opacity(0.12))
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(FrisTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(FrisTheme.cyan.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: FrisTheme.cyan.opacity(0.08), radius: 20, y: 8)
        .padding(.horizontal, 20)
    }

    private var formattedTime: String {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        return String(format: "%d:%02d", m, s)
    }
}
