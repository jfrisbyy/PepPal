import SwiftUI
import HealthKit

/// Applies iOS 26 liquid-glass to chrome elements, falling back to the
/// plain translucent material (already set as the background) on older iOS.
private struct GlassChrome<S: Shape>: ViewModifier {
    let shape: S
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content
        }
    }
}

extension View {
    func glassChrome<S: Shape>(in shape: S) -> some View {
        modifier(GlassChrome(shape: shape))
    }
}

@Observable
final class WorkoutState {
    static let shared = WorkoutState()
    var isWorkoutActive: Bool = false
    var workoutProgress: Double = 0.0
    var workoutName: String = ""
}

struct ContentView: View {
    @State private var selectedDomain: AppDomain = .brief
    @State private var scrolledDomain: AppDomain? = .brief
    @State private var showNutrition: Bool = false
    @State private var showCreatePost: Bool = false
    @State private var showLogDose: Bool = false
    @State private var showLogBloodwork: Bool = false
    @State private var fabExpanded: Bool = false
    @State private var socialViewModel = SocialViewModel()
    @State private var showActiveWorkoutWarning: Bool = false
    @State private var workoutState = WorkoutState.shared
    @State private var sessionManager = WorkoutSessionManager.shared
    @State private var authService = AuthService.shared
    @State private var showMedicalDisclaimer: Bool = !MedicalDisclaimerManager.hasAccepted
    @State private var didSyncDisclaimer: Bool = false
    @State private var showOnboarding: Bool = !OnboardingManager.hasCompleted
    @State private var showLoginFromOnboarding: Bool = false
    @State private var didReconcileOnboarding: Bool = false
    @State private var profileTabAvatar = ProfileTabAvatarStore.shared
    @State private var profileTabBootstrap = ProfileViewModel()
    @State private var didBootstrapProfileTabAvatar: Bool = false
    @State private var screenshotMode = ScreenshotMode.shared
    @State private var capturedScreenshotURL: URL? = nil
    @State private var isCapturingScreenshot: Bool = false
    @State private var showScreenshotShare: Bool = false
    @State private var showGlobalSearch: Bool = false
    @State private var showDiscover: Bool = false
    @State private var showNotificationCenter: Bool = false
    @State private var showProfile: Bool = false
    @State private var notifStore = SmartNotificationStore.shared

    var body: some View {
        let _ = print("APP_INIT: ContentView body evaluated, authState = \(authService.authState)")
        switch authService.authState {
        case .loading:
            ZStack {
                PepTheme.background.ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(PepTheme.teal)
                    Text("Loading...")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        case .signedOut:
            if showOnboarding && !showLoginFromOnboarding {
                OnboardingFlowView(
                    onSignIn: { showLoginFromOnboarding = true },
                    onComplete: { showOnboarding = false }
                )
            } else {
                LoginView()
            }
        case .signedIn:
            let _ = print("APP_INIT: Rendering main app view (signed in)")
            mainAppView
                .fullScreenCover(isPresented: $showOnboarding) {
                    OnboardingFlowView(
                        onSignIn: { showOnboarding = false },
                        onComplete: { showOnboarding = false }
                    )
                }
                .onReceive(NotificationCenter.default.publisher(for: OnboardingManager.rerunRequested)) { _ in
                    didReconcileOnboarding = true
                    showOnboarding = true
                }
                .task(id: (try? authService.currentUserId()) ?? "") {
                    guard !didReconcileOnboarding else { return }
                    didReconcileOnboarding = true
                    let mustOnboard = await OnboardingManager.reconcileCompletionAfterSignIn()
                    await MainActor.run {
                        if mustOnboard, !showOnboarding {
                            showOnboarding = true
                        } else if !mustOnboard, showOnboarding {
                            showOnboarding = false
                        }
                    }
                }
        }
    }

    private var mainAppView: some View {
        ZStack(alignment: .bottomTrailing) {
            AppBackground(accent: selectedDomain.accent)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.45), value: selectedDomain)

            VStack(spacing: 0) {
                if !screenshotMode.hideChrome {
                    topStrip
                    DomainBubbleRail(selection: $selectedDomain)
                        .padding(.bottom, 8)
                }
                domainPager
            }

            if sessionManager.isSessionActive && !sessionManager.showActiveWorkout {
                VStack {
                    Spacer()
                    activeWorkoutBanner
                        .padding(.bottom, 24)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if workoutState.isWorkoutActive {
                workoutIndicatorBar
            }

            if selectedDomain != .social && !screenshotMode.hideChrome {
                ExpandableFABView(isExpanded: $fabExpanded, actions: fabActions)
            }

            if screenshotMode.hideChrome && !isCapturingScreenshot {
                globalCaptureScreenshotButton
                    .padding(.top, 6)
                    .padding(.leading, 14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .allowsHitTesting(true)
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .sheet(isPresented: $showScreenshotShare, onDismiss: {
            capturedScreenshotURL = nil
        }) {
            if let url = capturedScreenshotURL {
                ScreenshotShareSheet(url: url)
                    .presentationDetents([.medium, .large])
            }
        }
        .onAppear {
            configureNavBarAppearance()
        }
        .onChange(of: selectedDomain) { _, _ in
            if fabExpanded {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    fabExpanded = false
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToHomeTab)) { _ in
            withAnimation(.spring(response: 0.36, dampingFraction: 0.85)) {
                selectedDomain = .brief
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToCommunityTab)) { _ in
            withAnimation(.spring(response: 0.36, dampingFraction: 0.85)) {
                selectedDomain = .social
            }
        }
        .sheet(isPresented: $showNutrition) {
            NavigationStack {
                NutritionView()
            }
        }
        .sheet(isPresented: $showCreatePost) {
            PostComposerView(socialViewModel: socialViewModel)
        }
        .sheet(isPresented: $showLogDose) {
            QuickLogDoseSheet()
        }
        .sheet(isPresented: $showLogBloodwork) {
            NavigationStack {
                BloodworkTrackingView()
            }
        }
        .sheet(isPresented: $showGlobalSearch) {
            GlobalSearchView()
        }
        .sheet(isPresented: $showDiscover) {
            DiscoverView()
        }
        .sheet(isPresented: $showNotificationCenter) {
            SmartNotificationCenterView()
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
        }
        .fullScreenCover(isPresented: $sessionManager.showActiveWorkout) {
            if let vm = sessionManager.activeViewModel {
                ActiveWorkoutView(viewModel: vm)
            }
        }
        .overlay(alignment: .top) {
            DebugBannerOverlay()
        }
        .alert("Workout in progress", isPresented: $showActiveWorkoutWarning) {
            Button("Keep Current", role: .cancel) {
                sessionManager.resumeActiveWorkout()
            }
            Button("End & Start New", role: .destructive) {
                sessionManager.endSession()
                withAnimation(.spring(response: 0.36, dampingFraction: 0.85)) {
                    selectedDomain = .train
                }
            }
        } message: {
            Text("You're already in “\(sessionManager.workoutName)”. Starting a new workout will end the current one.")
        }
        .sheet(isPresented: $showMedicalDisclaimer) {
            MedicalDisclaimerGateView(isPresented: $showMedicalDisclaimer)
                .interactiveDismissDisabled(true)
        }
        .overlay(alignment: .topTrailing) {
            SyncStatusBadge()
                .padding(.top, 8)
                .padding(.trailing, 12)
        }
        .onReceive(NotificationCenter.default.publisher(for: .medicalDisclaimerSynced)) { _ in
            if showMedicalDisclaimer {
                withAnimation(.easeOut(duration: 0.25)) {
                    showMedicalDisclaimer = false
                }
            }
        }
        .task(id: (try? authService.currentUserId()) ?? "") {
            if !didBootstrapProfileTabAvatar {
                didBootstrapProfileTabAvatar = true
                Task { await profileTabBootstrap.loadProfile() }
            }
            print("APP_INIT: mainAppView .task started")
            showMedicalDisclaimer = !MedicalDisclaimerManager.hasAccepted
            didSyncDisclaimer = true
            await MedicalDisclaimerManager.syncFromRemote()
            if MedicalDisclaimerManager.hasAccepted && showMedicalDisclaimer {
                showMedicalDisclaimer = false
            }
            try? await Task.sleep(for: .milliseconds(500))
            print("APP_INIT: Checking HealthKit availability")
            if HKHealthStore.isHealthDataAvailable() {
                print("APP_INIT: HealthKit available, requesting authorization")
                await HealthKitService.shared.requestAuthorization()
                print("APP_INIT: HealthKit authorization complete")
            } else {
                print("APP_INIT: HealthKit NOT available on this device")
            }
        }
    }

    // MARK: - Domain Pager

    /// Horizontal paging container. A plain SwiftUI `ScrollView` draws no
    /// background of its own (unlike the old `.page` `TabView`, which is a
    /// `UIPageViewController` that paints an opaque page surface), so the single
    /// root `AppBackground` shows through it continuously — no seam under the rail.
    private var domainPager: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(AppDomain.allCases) { domain in
                            domainPage(for: domain)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .id(domain)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $scrolledDomain, anchor: .center)
                .scrollIndicators(.hidden)
                .ignoresSafeArea(.container, edges: .bottom)
            }
        }
        .onChange(of: selectedDomain) { _, newValue in
            guard scrolledDomain != newValue else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                scrolledDomain = newValue
            }
        }
        .onChange(of: scrolledDomain) { _, newValue in
            guard let newValue, selectedDomain != newValue else { return }
            selectedDomain = newValue
        }
    }

    @ViewBuilder
    private func domainPage(for domain: AppDomain) -> some View {
        switch domain {
        case .brief: BriefView()
        case .train: TrainView()
        case .fuel: NutritionView(showsBackButton: false)
        case .stack: StackRootView()
        case .labs: LabsRootView()
        case .social: SocialView()
        }
    }

    // MARK: - Top Strip

    private var topStrip: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                EptiLogoMark(size: 24)
                Text(dateLine)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(PepTheme.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            readinessChip
            topStripIconButton(systemName: "magnifyingglass") { showGlobalSearch = true }
            topStripIconButton(systemName: "sparkle.magnifyingglass") { showDiscover = true }
            notificationsButton
            avatarButton
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    private var dateLine: String {
        let f = DateFormatter()
        f.dateFormat = "EEE · MMM d"
        return f.string(from: Date()).uppercased()
    }

    private var readinessChip: some View {
        let score = HealthKitService.shared.recoveryScore
        return HStack(spacing: 5) {
            Circle()
                .fill(PepTheme.teal)
                .frame(width: 6, height: 6)
                .shadow(color: PepTheme.teal.opacity(0.5), radius: 3)
            Text(score.map { "\($0)" } ?? "—")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(PepTheme.textPrimary)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            Capsule()
                .fill(PepTheme.cardSurface.opacity(0.35))
                .overlay(Capsule().strokeBorder(PepTheme.glassBorderTop.opacity(0.18), lineWidth: 0.5))
        )
    }

    private func topStripIconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(PepTheme.cardSurface.opacity(0.35))
                        .overlay(Circle().strokeBorder(PepTheme.glassBorderTop.opacity(0.18), lineWidth: 0.5))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var notificationsButton: some View {
        Button {
            showNotificationCenter = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: notifStore.unreadCount > 0 ? "bell.badge.fill" : "bell")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(notifStore.unreadCount > 0 ? PepTheme.teal : PepTheme.textPrimary)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(PepTheme.cardSurface.opacity(0.35))
                            .overlay(Circle().strokeBorder(PepTheme.glassBorderTop.opacity(0.18), lineWidth: 0.5))
                    )
                    .symbolEffect(.bounce, value: notifStore.unreadCount)
                if notifStore.unreadCount > 0 {
                    Circle()
                        .fill(PepTheme.coral)
                        .frame(width: 7, height: 7)
                        .overlay(Circle().strokeBorder(PepTheme.cardSurface, lineWidth: 1))
                        .offset(x: -3, y: 3)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: showNotificationCenter)
    }

    private var avatarButton: some View {
        Button {
            showProfile = true
        } label: {
            Group {
                if let image = profileTabAvatar.icon {
                    Image(uiImage: image)
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.crop.circle")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            .frame(width: 30, height: 30)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(PepTheme.glassBorderTop.opacity(0.18), lineWidth: 0.5))
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: showProfile)
    }

    private var activeWorkoutBanner: some View {
        Button {
            sessionManager.resumeActiveWorkout()
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(PepTheme.teal)
                    .frame(width: 10, height: 10)
                    .shadow(color: PepTheme.teal.opacity(0.6), radius: 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text(sessionManager.workoutName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(sessionManager.formattedElapsedTime)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(PepTheme.teal)
                        .monospacedDigit()
                }

                Spacer()

                Image(systemName: "chevron.up.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(PepTheme.teal)
                    .symbolRenderingMode(.hierarchical)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                PepTheme.cardSurface
                    .overlay(PepTheme.teal.opacity(0.06))
            )
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(PepTheme.teal.opacity(0.3), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .sensoryFeedback(.impact(weight: .light), trigger: sessionManager.showActiveWorkout)
    }

    private var workoutIndicatorBar: some View {
        VStack(spacing: 0) {
            Spacer()
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(PepTheme.teal.opacity(0.15))
                        .frame(height: 2.5)

                    Rectangle()
                        .fill(PepTheme.teal)
                        .frame(width: geo.size.width * workoutState.workoutProgress, height: 2.5)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: workoutState.workoutProgress)

                    Rectangle()
                        .fill(PepTheme.teal)
                        .frame(width: 20, height: 2.5)
                        .offset(x: geo.size.width * workoutState.workoutProgress - 10)
                        .shadow(color: PepTheme.teal.opacity(0.8), radius: 4)
                }
            }
            .frame(height: 2.5)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    private var fabActions: [FABAction] {
        [
            FABAction(icon: "fork.knife", label: "Log Meal", color: PepTheme.amber, action: { showNutrition = true }),
            FABAction(icon: "figure.run", label: "Log Workout", color: PepTheme.teal, action: {
                if sessionManager.isSessionActive {
                    showActiveWorkoutWarning = true
                } else {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.85)) {
                        selectedDomain = .train
                    }
                }
            }),
            FABAction(icon: "square.and.pencil", label: "Make a Post", color: PepTheme.blue, action: { showCreatePost = true }),
            FABAction(icon: "pill.fill", label: "Log Dose", color: Color.pink, action: { showLogDose = true }),
            FABAction(icon: "drop.fill", label: "Log Bloodwork", color: .red, action: { showLogBloodwork = true }),
        ]
    }

    // MARK: - Global Screenshot Capture Button

    private var globalCaptureScreenshotButton: some View {
        Button {
            performGlobalScreenshotCapture()
        } label: {
            ZStack {
                Circle()
                    .fill(PepTheme.cardSurface)
                    .frame(width: 36, height: 36)
                    .overlay(Circle().strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.6))
                    .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
                if isCapturingScreenshot {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PepTheme.violet)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isCapturingScreenshot)
        .opacity(0.85)
        .sensoryFeedback(.success, trigger: capturedScreenshotURL?.lastPathComponent ?? "")
    }

    private func performGlobalScreenshotCapture() {
        guard !isCapturingScreenshot else { return }
        isCapturingScreenshot = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            let image = await HomeScreenshotCapturer.captureHomeScrollView()
            if let image, let url = HomeScreenshotCapturer.writeTempPNG(image) {
                capturedScreenshotURL = url
                showScreenshotShare = true
            }
            isCapturingScreenshot = false
        }
    }

    private func configureNavBarAppearance() {
        // Large nav titles use the display serif for an editorial feel.
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundEffect = nil
        nav.backgroundColor = .clear
        nav.shadowColor = .clear
        let titleColor = UIColor(PepTheme.textPrimary)
        nav.titleTextAttributes = [
            .foregroundColor: titleColor,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        if let serif = UIFont(descriptor: UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle).withDesign(.serif) ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle), size: 32) as UIFont? {
            nav.largeTitleTextAttributes = [
                .foregroundColor: titleColor,
                .font: serif,
                .kern: -0.4
            ]
        } else {
            nav.largeTitleTextAttributes = [.foregroundColor: titleColor]
        }
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
    }
}
