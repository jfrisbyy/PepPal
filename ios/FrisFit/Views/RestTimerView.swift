import SwiftUI

struct RestTimerView: View {
    let secondsRemaining: Int
    let totalSeconds: Int
    let didFire: Bool
    let nextExerciseName: String?
    let onSkip: () -> Void
    let onAdjust: (Int) -> Void

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - (Double(secondsRemaining) / Double(totalSeconds))
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(PepTheme.elevated, lineWidth: 4)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        didFire ? Color.green : PepTheme.teal,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)
                if didFire {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text(formattedTime)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(PepTheme.textPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(eyebrowText)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(didFire ? .green : PepTheme.textSecondary)
                Text(subtitleText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            HStack(spacing: 6) {
                adjustButton(label: "-15", amount: -15)
                adjustButton(label: "+15", amount: 15)
                Button(action: onSkip) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 38, height: 36)
                        .background(PepTheme.teal)
                        .clipShape(Capsule())
                }
                .buttonStyle(.scale)
                .sensoryFeedback(.impact(weight: .medium), trigger: secondsRemaining == 0)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(PepTheme.cardSurface)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(
                    didFire ? Color.green.opacity(0.4) : PepTheme.teal.opacity(0.25),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        .sensoryFeedback(.success, trigger: didFire)
    }

    private func adjustButton(label: String, amount: Int) -> some View {
        Button { onAdjust(amount) } label: {
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(PepTheme.textPrimary)
                .frame(width: 38, height: 36)
                .background(PepTheme.elevated)
                .clipShape(Capsule())
        }
        .buttonStyle(.scale)
    }

    private var eyebrowText: String {
        if didFire { return "Rest Complete" }
        if let next = nextExerciseName { return "UP NEXT" }
        return "RESTING"
    }

    private var subtitleText: String {
        if didFire {
            return nextExerciseName ?? "Ready for your next set"
        }
        if let next = nextExerciseName {
            return next
        }
        return formattedTime
    }

    private var formattedTime: String {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        return String(format: "%d:%02d", m, s)
    }
}
