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
    @State private var previousTab: AppTab = .home
    @State private var workoutState = WorkoutState.shared

    var body: some View {
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

            if workoutState.isWorkoutActive {
                workoutIndicatorBar
            }

            if selectedTab != .community && selectedTab != .home {
                floatingPepButton
            }
        }
        .onAppear {
            configureTabBarAppearance()
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            previousTab = oldValue
        }
        .fullScreenCover(isPresented: $showPepChat) {
            PepChatView()
        }
        .task {
            try? await Task.sleep(for: .milliseconds(500))
            if HKHealthStore.isHealthDataAvailable() {
                await HealthKitService.shared.requestAuthorization()
            }
        }
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

    private var floatingPepButton: some View {
        Button {
            showPepChat = true
        } label: {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [PepTheme.violet, PepTheme.violet.opacity(0.7)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 28
                        )
                    )
                    .frame(width: 52, height: 52)
                    .shadow(color: PepTheme.violet.opacity(0.5), radius: 12, x: 0, y: 4)

                Image(systemName: "message.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.scale)
        .padding(.trailing, 16)
        .padding(.bottom, 80)
        .sensoryFeedback(.impact(weight: .medium), trigger: showPepChat)
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
