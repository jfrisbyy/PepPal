import SwiftUI
import HealthKit

struct ConnectStepView: View {
    let onContinue: () -> Void

    private enum SubStep: Int, CaseIterable {
        case explanation
        case permissionList
        case prompt
    }

    @State private var sub: SubStep = .explanation
    @State private var isRequesting: Bool = false
    @State private var didGrant: Bool = false
    @State private var didDeny: Bool = false
    @State private var didStage: Bool = false
    @State private var stagingProgress: String = ""

    private let healthKit = HealthKitService.shared

    var body: some View {
        ZStack {
            switch sub {
            case .explanation:
                explanationScreen
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            case .permissionList:
                permissionListScreen
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            case .prompt:
                promptScreen
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: sub)
    }

    // MARK: - Screen 1: Explanation

    private var explanationScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                heroIcon(symbol: "heart.text.square.fill", tint: PepTheme.teal)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Connect your data")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("So your journey map and morning brief feel real on day one.")
                        .font(.system(.title3, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 14) {
                    bullet(
                        icon: "calendar",
                        title: "Last 90 days",
                        body: "We'll read your weight, workouts, sleep, HRV, and resting heart rate so EPTI has context from minute one."
                    )
                    bullet(
                        icon: "lock.shield.fill",
                        title: "On-device by default",
                        body: "Nothing is transmitted off your device unless you turn on cloud sync separately in Settings."
                    )
                    bullet(
                        icon: "hand.raised.fill",
                        title: "You're in control",
                        body: "You can revoke any permission from the Health app, and disconnect from EPTI Settings anytime."
                    )
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .safeAreaInset(edge: .bottom) {
            primaryButton(title: "Continue") {
                advance(to: .permissionList)
            }
        }
    }

    // MARK: - Screen 2: Permission list

    private var permissionListScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What we'll read")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Each signal unlocks something specific. You can deny any of these in the next step.")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    permissionRow(
                        icon: "figure.walk",
                        tint: PepTheme.teal,
                        title: "Activity & workouts",
                        reads: "Steps, calories, exercise minutes, workouts.",
                        unlocks: "Powers your training timeline and weekly volume trends."
                    )
                    permissionRow(
                        icon: "bed.double.fill",
                        tint: PepTheme.violet,
                        title: "Sleep",
                        reads: "Time asleep across stages.",
                        unlocks: "Lets the agent connect your recovery to your training and protocol."
                    )
                    permissionRow(
                        icon: "waveform.path.ecg",
                        tint: PepTheme.blue,
                        title: "HRV & resting heart rate",
                        reads: "HRV (SDNN) and resting HR.",
                        unlocks: "Recovery score, overtraining flags, protocol response signals."
                    )
                    permissionRow(
                        icon: "scalemass.fill",
                        tint: PepTheme.amber,
                        title: "Body weight",
                        reads: "Weight history.",
                        unlocks: "Trend lines on the journey map and adaptive macro targets."
                    )
                    permissionRow(
                        icon: "heart.fill",
                        tint: .red,
                        title: "Heart rate & vitals",
                        reads: "Heart rate, respiratory rate, oxygen saturation.",
                        unlocks: "In-workout zones and recovery insight."
                    )
                }

                Text("Tap Continue to see the Apple Health permission sheet. You'll choose exactly what to share there.")
                    .font(.footnote)
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)

                Spacer(minLength: 16)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .safeAreaInset(edge: .bottom) {
            primaryButton(title: "Continue") {
                advance(to: .prompt)
            }
        }
    }

    // MARK: - Screen 3: Native prompt + result

    @ViewBuilder
    private var promptScreen: some View {
        if didGrant {
            grantedScreen
        } else if didDeny {
            deniedScreen
        } else {
            requestingScreen
        }
    }

    private var requestingScreen: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(PepTheme.teal.opacity(0.15))
                    .frame(width: 140, height: 140)
                    .blur(radius: 16)
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(PepTheme.teal)
                    .symbolEffect(.pulse, options: .repeating)
            }

            VStack(spacing: 10) {
                Text("Allow Apple Health")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(isRequesting
                     ? "Apple's permission sheet is open. Pick what you'd like to share."
                     : "Tap below to bring up Apple's permission sheet.")
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 10) {
                Button {
                    Task { await requestAuth() }
                } label: {
                    HStack(spacing: 10) {
                        if isRequesting {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "heart.fill")
                        }
                        Text(isRequesting ? "Waiting..." : "Allow Apple Health")
                            .font(.system(.headline, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [PepTheme.teal, PepTheme.teal.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(.rect(cornerRadius: 16))
                    .shadow(color: PepTheme.teal.opacity(0.35), radius: 16, y: 6)
                }
                .buttonStyle(.plain)
                .disabled(isRequesting)

                Button("Not now — connect later") {
                    HealthKitConnectFlags.hasBeenPrompted = true
                    HealthKitConnectFlags.wasDenied = true
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    onContinue()
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private var grantedScreen: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(PepTheme.teal.opacity(0.18))
                    .frame(width: 140, height: 140)
                    .blur(radius: 14)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 70, weight: .light))
                    .foregroundStyle(PepTheme.teal)
                    .symbolEffect(.bounce, options: .nonRepeating)
            }

            VStack(spacing: 10) {
                Text("You're connected")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                if didStage {
                    Text("We pulled your last 90 days. Your journey map will pick up where you left off.")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 32)
                } else {
                    HStack(spacing: 8) {
                        ProgressView().tint(PepTheme.textSecondary)
                        Text(stagingProgress.isEmpty ? "Pulling your last 90 days..." : stagingProgress)
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
            }

            Spacer()

            primaryButton(title: didStage ? "Continue" : "Skip & continue") {
                onContinue()
            }
        }
    }

    private var deniedScreen: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(PepTheme.amber.opacity(0.16))
                    .frame(width: 120, height: 120)
                Image(systemName: "heart.slash.fill")
                    .font(.system(size: 50, weight: .light))
                    .foregroundStyle(PepTheme.amber)
            }

            VStack(spacing: 12) {
                Text("No problem")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("You can connect Apple Health any time from Settings. Your journey map will start mostly empty until then — we'll fill it in as you log.")
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
            }

            Spacer()

            primaryButton(title: "Continue") {
                onContinue()
            }
        }
    }

    // MARK: - Actions

    private func advance(to next: SubStep) {
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            sub = next
        }
    }

    private func requestAuth() async {
        guard !isRequesting else { return }
        isRequesting = true
        defer { isRequesting = false }

        guard HKHealthStore.isHealthDataAvailable() else {
            HealthKitConnectFlags.hasBeenPrompted = true
            HealthKitConnectFlags.wasDenied = true
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                didDeny = true
            }
            return
        }

        healthKit.isHealthKitEnabled = true
        let didShowPrompt = await healthKit.requestAuthorizationInteractively()
        HealthKitConnectFlags.hasBeenPrompted = true

        if healthKit.isAuthorized {
            HealthKitConnectFlags.wasDenied = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                didGrant = true
            }
            await stageHistory()
        } else if !didShowPrompt {
            HealthKitConnectFlags.wasDenied = true
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                didDeny = true
            }
        } else {
            HealthKitConnectFlags.wasDenied = true
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                didDeny = true
            }
        }
    }

    private func stageHistory() async {
        stagingProgress = "Pulling your last 90 days..."
        await JourneyMapStagingStore.stageLast90Days()
        HealthKitConnectFlags.didStage90Days = true
        withAnimation(.easeInOut(duration: 0.25)) {
            didStage = true
        }
    }

    // MARK: - Components

    private func heroIcon(symbol: String, tint: Color) -> some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.15))
                .frame(width: 84, height: 84)
            Image(systemName: symbol)
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(tint)
        }
    }

    private func bullet(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(PepTheme.teal)
                .frame(width: 28, height: 28)
                .background(PepTheme.teal.opacity(0.12))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(body)
                    .font(.footnote)
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private func permissionRow(
        icon: String,
        tint: Color,
        title: String,
        reads: String,
        unlocks: String
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.16))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Reads: \(reads)")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Unlocks: \(unlocks)")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textPrimary.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.cardSurface.opacity(0.7))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private func primaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(PepTheme.teal)
                .clipShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .padding(.top, 8)
        .background(
            LinearGradient(
                colors: [PepTheme.background.opacity(0), PepTheme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}
