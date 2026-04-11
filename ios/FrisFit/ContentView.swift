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
    case home, train, discover, community, profile

    var title: String {
        switch self {
        case .home: "Home"
        case .train: "Train"
        case .discover: "Discover"
        case .community: "Community"
        case .profile: "Profile"
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .train: "figure.run"
        case .discover: "magnifyingglass"
        case .community: "person.2"
        case .profile: "person.crop.circle"
        }
    }

    var activeIcon: String {
        switch self {
        case .home: "house.fill"
        case .train: "figure.run"
        case .discover: "magnifyingglass"
        case .community: "person.2.fill"
        case .profile: "person.crop.circle.fill"
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .home
    @State private var showPepChat: Bool = false
    @State private var showNutrition: Bool = false
    @State private var showCreatePost: Bool = false
    @State private var fabExpanded: Bool = false
    @State private var previousTab: AppTab = .home
    @State private var workoutState = WorkoutState.shared
    @State private var sessionManager = WorkoutSessionManager.shared
    @State private var authService = AuthService.shared

    var body: some View {
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
            LoginView()
        case .signedIn:
            mainAppView
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
                Tab("Discover", systemImage: selectedTab == .discover ? AppTab.discover.activeIcon : AppTab.discover.icon, value: .discover) {
                    DiscoverView()
                }
                Tab("Community", systemImage: selectedTab == .community ? AppTab.community.activeIcon : AppTab.community.icon, value: .community) {
                    SocialView()
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

            if selectedTab != .community && selectedTab != .discover {
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
        .fullScreenCover(isPresented: $showPepChat) {
            PepChatView()
        }
        .sheet(isPresented: $showNutrition) {
            NavigationStack {
                NutritionView()
            }
        }
        .fullScreenCover(isPresented: $sessionManager.showActiveWorkout) {
            if let vm = sessionManager.activeViewModel {
                ActiveWorkoutView(viewModel: vm)
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(500))
            if HKHealthStore.isHealthDataAvailable() {
                await HealthKitService.shared.requestAuthorization()
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
            FABAction(icon: "figure.run", label: "Log Workout", color: PepTheme.teal, action: {}),
            FABAction(icon: "bubble.left.fill", label: "Chat with Pep", color: PepTheme.violet, action: { showPepChat = true }),
            FABAction(icon: "square.and.pencil", label: "Make a Post", color: PepTheme.blue, action: { showCreatePost = true }),
            FABAction(icon: "pill.fill", label: "Log Dose", color: Color.pink, action: {}),
            FABAction(icon: "drop.fill", label: "Log Bloodwork", color: .red, action: {}),
        ]
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor(PepTheme.cardSurface).withAlphaComponent(0.85)
        appearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)

        let normalColor = UIColor(PepTheme.textSecondary).withAlphaComponent(0.5)
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: normalColor
        ]
        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(PepTheme.teal)
        ]

        appearance.stackedLayoutAppearance.normal.iconColor = normalColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttributes
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(PepTheme.teal)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttributes

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
