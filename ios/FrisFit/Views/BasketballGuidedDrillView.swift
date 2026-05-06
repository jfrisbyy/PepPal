import SwiftUI
import Combine

struct BasketballGuidedDrillView: View {
    let drill: BasketballDrill
    var bbVM: BasketballViewModel = .shared
    var onComplete: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var elapsed: Int = 0
    @State private var isRunning: Bool = true
    @State private var cueIndex: Int = 0
    @State private var made: Int = 0
    @State private var attempted: Int = 0
    @State private var didLog: Bool = false

    private let accentColor = BasketballPalette.courtOrange

    private var totalSeconds: Int { drill.durationMinutes * 60 }
    private var remaining: Int { max(totalSeconds - elapsed, 0) }
    private var progress: Double { totalSeconds > 0 ? min(Double(elapsed) / Double(totalSeconds), 1) : 0 }

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 24) {
                topBar

                Spacer()

                kickerAndTitle
                timerRing
                cueText

                Spacer()

                if drill.category == .shooting || drill.category == .finishing {
                    makesCounter
                }

                bottomBar
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
        }
        .preferredColorScheme(.dark)
        .statusBar(hidden: true)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard isRunning, elapsed < totalSeconds else { return }
            elapsed += 1
            if elapsed % 30 == 0 && !drill.cues.isEmpty {
                withAnimation(.spring(duration: 0.4)) {
                    cueIndex = (cueIndex + 1) % drill.cues.count
                }
            }
            if elapsed == totalSeconds {
                handleAutoFinish()
            }
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            PepTheme.background
            RadialGradient(
                colors: [drill.category.color.opacity(0.25), .black.opacity(0)],
                center: .top, startRadius: 30, endRadius: 500
            )
            RadialGradient(
                colors: [accentColor.opacity(0.18), .black.opacity(0)],
                center: .bottom, startRadius: 30, endRadius: 500
            )
        }
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack {
            Button {
                if didLog { dismiss() } else { complete(autoFinish: false) }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .frame(width: 38, height: 38)
                    .background(PepTheme.cardSurface.opacity(0.6))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text(drill.category.rawValue.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(2.0)
                .foregroundStyle(drill.category.color)

            Spacer()

            Button {
                withAnimation(.spring(duration: 0.2)) { isRunning.toggle() }
            } label: {
                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 38, height: 38)
                    .background(accentColor)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .light), trigger: isRunning)
        }
    }

    private var kickerAndTitle: some View {
        VStack(spacing: 10) {
            Text(drill.difficulty.rawValue.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(drill.difficulty.color)
            Text(drill.name)
                .font(.system(size: 30, weight: .semibold, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
    }

    private var timerRing: some View {
        ZStack {
            Circle()
                .stroke(PepTheme.elevated.opacity(0.6), lineWidth: 10)
                .frame(width: 240, height: 240)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(colors: [accentColor, BasketballPalette.courtAmber], startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .frame(width: 240, height: 240)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: progress)

            VStack(spacing: 4) {
                Text(timeString(remaining))
                    .font(.system(size: 56, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("REMAINING")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
    }

    private var cueText: some View {
        Group {
            if !drill.cues.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 11))
                        .foregroundStyle(BasketballPalette.courtAmber)
                    Text(drill.cues[cueIndex])
                        .font(.system(size: 14, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textPrimary)
                        .multilineTextAlignment(.center)
                        .id(cueIndex)
                        .transition(.opacity)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(PepTheme.cardSurface.opacity(0.7))
                .clipShape(.rect(cornerRadius: 12))
            }
        }
    }

    private var makesCounter: some View {
        VStack(spacing: 12) {
            Text("LOG YOUR REPS")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(PepTheme.textSecondary)
            HStack(spacing: 14) {
                counterStepper(label: "MADE", value: $made, color: .green)
                counterStepper(label: "ATT", value: $attempted, color: PepTheme.textSecondary)
                let pct = attempted > 0 ? Double(made) / Double(attempted) * 100 : 0
                VStack(spacing: 4) {
                    Text(String(format: "%.0f%%", pct))
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .foregroundStyle(accentColor)
                    Text("FG%")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .frame(width: 60)
            }
        }
    }

    private func counterStepper(label: String, value: Binding<Int>, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(color)
            HStack(spacing: 8) {
                Button { value.wrappedValue = max(0, value.wrappedValue - 1) } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(PepTheme.elevated)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                Text("\(value.wrappedValue)")
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .frame(width: 36)
                    .contentTransition(.numericText())
                Button { value.wrappedValue += 1 } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 28, height: 28)
                        .background(color == .green ? .green : accentColor)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: value.wrappedValue)
            }
        }
    }

    private var bottomBar: some View {
        EditorialPrimaryButton(remaining == 0 ? "Done" : "Mark Complete", icon: "checkmark.circle.fill", accent: accentColor) {
            complete(autoFinish: false)
        }
    }

    private func timeString(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func handleAutoFinish() {
        complete(autoFinish: true)
    }

    private func complete(autoFinish: Bool) {
        guard !didLog else { return }
        didLog = true
        bbVM.recordDrillCompletion(drill)
        if !bbVM.drillsCompletedThisSession.contains(drill.slug) {
            bbVM.drillsCompletedThisSession.append(drill.slug)
        }
        if drill.category == .shooting || drill.category == .finishing {
            bbVM.currentStats.fieldGoalsMade += made
            bbVM.currentStats.fieldGoalsAttempted += attempted
            bbVM.currentStats.points += made * 2
        }
        let haptic = UINotificationFeedbackGenerator()
        haptic.notificationOccurred(.success)
        onComplete?()
        dismiss()
    }
}
