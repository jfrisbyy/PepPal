import SwiftUI
import HealthKit

@Observable
final class WorkoutState {
    static let shared = WorkoutState()
    var isWorkoutActive: Bool = false
    var workoutProgress: Double = 0.0
    var workoutName: String = ""
}

nonisolated enum AppTab: Int, CaseIterable {
    case home, train, community, discover, profile

    var title: String {
        switch self {
        case .home: "Home"
        case .train: "Train"
        case .community: "Community"
        case .discover: "Discover"
        case .profile: "Profile"
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .train: "figure.run"
        case .community: "person.2"
        case .discover: "magnifyingglass"
        case .profile: "person.crop.circle"
        }
    }

    var activeIcon: String {
        switch self {
        case .home: "house.fill"
        case .train: "figure.run"
        case .community: "person.2.fill"
        case .discover: "magnifyingglass"
        case .profile: "person.crop.circle.fill"
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .home
    @State private var showPepChat: Bool = false
    @State private var showNutrition: Bool = false
    @State private var showCreatePost: Bool = false
    @State private var showLogDose: Bool = false
    @State private var showLogBloodwork: Bool = false
    @State private var fabExpanded: Bool = false
    @State private var socialViewModel = SocialViewModel()
    @State private var showActiveWorkoutWarning: Bool = false
    @State private var previousTab: AppTab = .home
    @State private var workoutState = WorkoutState.shared
    @State private var sessionManager = WorkoutSessionManager.shared
    @State private var authService = AuthService.shared
    @State private var showMedicalDisclaimer: Bool = !MedicalDisclaimerManager.hasAccepted
    @State private var didSyncDisclaimer: Bool = false
    @State private var showOnboarding: Bool = !OnboardingManager.hasCompleted
    @State private var showLoginFromOnboarding: Bool = false
    @State private var didReconcileOnboarding: Bool = false

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
                    // Reconcile onboarding state with Supabase profile so pre-onboarding
                    // accounts (and cross-device sign-ins) are routed through the flow
                    // even if the local completed flag is missing/stale.
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
            TabView(selection: $selectedTab) {
                Tab("Home", systemImage: selectedTab == .home ? AppTab.home.activeIcon : AppTab.home.icon, value: .home) {
                    HomeView()
                }
                Tab("Train", systemImage: selectedTab == .train ? AppTab.train.activeIcon : AppTab.train.icon, value: .train) {
                    TrainView()
                }
                Tab("Community", systemImage: selectedTab == .community ? AppTab.community.activeIcon : AppTab.community.icon, value: .community) {
                    SocialView()
                }
                Tab("Discover", systemImage: selectedTab == .discover ? AppTab.discover.activeIcon : AppTab.discover.icon, value: .discover) {
                    DiscoverView()
                }
                Tab("Profile", systemImage: selectedTab == .profile ? AppTab.profile.activeIcon : AppTab.profile.icon, value: .profile) {
                    ProfileView()
                }
            }
            .tint(PepTheme.teal)

            if sessionManager.isSessionActive && !sessionManager.showActiveWorkout {
                VStack {
                    Spacer()
                    activeWorkoutBanner
                        .padding(.bottom, 50)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if workoutState.isWorkoutActive {
                workoutIndicatorBar
            }

            if selectedTab != .discover && selectedTab != .community {
                ExpandableFABView(isExpanded: $fabExpanded, actions: fabActions)
            }
        }
        .onAppear {
            configureTabBarAppearance()
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            previousTab = oldValue
            if fabExpanded {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    fabExpanded = false
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToHomeTab)) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                selectedTab = .home
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToCommunityTab)) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                selectedTab = .community
            }
        }
        .fullScreenCover(isPresented: $showPepChat) {
            PepChatView()
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
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    selectedTab = .train
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
        .task {
            print("APP_INIT: mainAppView .task started")
            if !didSyncDisclaimer {
                didSyncDisclaimer = true
                await MedicalDisclaimerManager.syncFromRemote()
                if MedicalDisclaimerManager.hasAccepted && showMedicalDisclaimer {
                    showMedicalDisclaimer = false
                }
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
            .offset(y: -49)
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
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        selectedTab = .train
                    }
                }
            }),
            FABAction(icon: "bubble.left.fill", label: "Chat with Pep", color: PepTheme.violet, action: { showPepChat = true }),
            FABAction(icon: "square.and.pencil", label: "Make a Post", color: PepTheme.blue, action: { showCreatePost = true }),
            FABAction(icon: "pill.fill", label: "Log Dose", color: Color.pink, action: { showLogDose = true }),
            FABAction(icon: "drop.fill", label: "Log Bloodwork", color: .red, action: { showLogBloodwork = true }),
        ]
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = UIColor(PepTheme.cardSurface).withAlphaComponent(0.55)
        appearance.shadowColor = UIColor(PepTheme.separatorColor)

        let normalColor = UIColor(PepTheme.textSecondary).withAlphaComponent(0.55)
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: normalColor,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]
        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(PepTheme.teal),
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]

        appearance.stackedLayoutAppearance.normal.iconColor = normalColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttributes
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(PepTheme.teal)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttributes

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        // Large nav titles use the display serif for an editorial feel.
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        nav.backgroundColor = UIColor(PepTheme.background).withAlphaComponent(0.6)
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
