import SwiftUI

struct ProfileView: View {
    @State private var viewModel = ProfileViewModel()
    @State private var isLoading: Bool = true
    @State private var selectedTab: ProfileTab = .posts

    enum ProfileTab: String, CaseIterable {
        case posts = "Posts"
        case market = "Market"
        case stats = "Stats"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    SkeletonProfileView()
                        .padding(.top, 8)
                        .transition(.opacity)
                } else {
                    VStack(spacing: 0) {
                        bannerHeader
                        profileInfo
                            .padding(.horizontal, 16)
                        statsBar
                            .padding(.top, 16)
                            .padding(.horizontal, 16)
                        tabSection
                            .padding(.top, 20)
                    }
                    .padding(.bottom, 32)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .scrollIndicators(.hidden)
            .background(FrisTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: ProfileDestination.settings) {
                        Image(systemName: "gearshape")
                            .foregroundStyle(FrisTheme.textPrimary)
                    }
                }
            }
            .onAppear {
                if isLoading {
                    Task {
                        try? await Task.sleep(for: .milliseconds(500))
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            isLoading = false
                        }
                    }
                }
            }
            .navigationDestination(for: ProfileDestination.self) { destination in
                switch destination {
                case .analytics:
                    WorkoutAnalyticsView(viewModel: viewModel)
                case .achievements:
                    AchievementsView(viewModel: viewModel)
                case .settings:
                    SettingsView(viewModel: viewModel)
                case .workoutHistory:
                    WorkoutHistoryView(viewModel: viewModel)
                case .historyDetail(let workout):
                    WorkoutHistoryDetailView(workout: workout)
                case .userProfile(let user):
                    UserProfileView(user: user, viewModel: viewModel)
                }
            }
        }
    }

    private var bannerHeader: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    FrisTheme.cyan.opacity(0.25),
                    FrisTheme.violet.opacity(0.15),
                    FrisTheme.background
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 120)

            Circle()
                .fill(FrisTheme.background)
                .frame(width: 88, height: 88)
                .overlay {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [viewModel.profile.avatarColor.opacity(0.8), FrisTheme.violet.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .overlay {
                            Text(viewModel.profile.initials)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                }
                .offset(x: 16, y: 44)
        }
        .padding(.bottom, 48)
    }

    private var profileInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.profile.displayName)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(FrisTheme.textPrimary)

                    Text("@\(viewModel.profile.username)")
                        .font(.subheadline)
                        .foregroundStyle(FrisTheme.textSecondary)
                }

                Spacer()

                NavigationLink(value: ProfileDestination.settings) {
                    Text("Edit Profile")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(FrisTheme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(FrisTheme.elevated)
                        .clipShape(.capsule)
                        .overlay(
                            Capsule().strokeBorder(FrisTheme.glassBorderTop, lineWidth: 0.5)
                        )
                }
            }

            if !viewModel.profile.bio.isEmpty {
                Text(viewModel.profile.bio)
                    .font(.subheadline)
                    .foregroundStyle(FrisTheme.textPrimary)
                    .lineSpacing(3)
                    .padding(.top, 4)
            }

            HStack(spacing: 16) {
                if let program = viewModel.profile.activeProgram {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.run")
                            .font(.caption2)
                            .foregroundStyle(FrisTheme.cyan)
                        Text(program)
                            .font(.caption)
                            .foregroundStyle(FrisTheme.cyan)
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundStyle(FrisTheme.textSecondary)
                    Text(viewModel.memberSinceFormatted)
                        .font(.caption)
                        .foregroundStyle(FrisTheme.textSecondary)
                }
            }
            .padding(.top, 4)

            HStack(spacing: 20) {
                followStat(count: viewModel.profile.followingCount, label: "Following")
                followStat(count: viewModel.profile.followerCount, label: "Followers")
                followStat(count: viewModel.profile.friendCount, label: "Friends")
            }
            .padding(.top, 8)
        }
    }

    private func followStat(count: Int, label: String) -> some View {
        HStack(spacing: 4) {
            Text(formatCount(count))
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(FrisTheme.textPrimary)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(FrisTheme.textSecondary)
        }
    }

    private var statsBar: some View {
        HStack(spacing: 0) {
            ProfileQuickStat(value: formatNumber(viewModel.profile.totalFP), label: "Total FP", icon: "bolt.fill", color: FrisTheme.cyan)
            ProfileQuickStat(value: "\(viewModel.streakManager.streakData.currentStreak)", label: "Day Streak", icon: "flame.fill", color: FrisTheme.amber)
            ProfileQuickStat(value: "\(viewModel.profile.totalWorkouts)", label: "Workouts", icon: "dumbbell.fill", color: FrisTheme.violet)
        }
        .padding(.vertical, 14)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(colors: [FrisTheme.glassBorderTop, FrisTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    private var tabSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(ProfileTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Text(tab.rawValue)
                                .font(.system(.subheadline, weight: selectedTab == tab ? .bold : .medium))
                                .foregroundStyle(selectedTab == tab ? FrisTheme.textPrimary : FrisTheme.textSecondary)
                                .frame(maxWidth: .infinity)

                            Rectangle()
                                .fill(selectedTab == tab ? FrisTheme.cyan : .clear)
                                .frame(height: 2)
                                .clipShape(.capsule)
                        }
                    }
                    .sensoryFeedback(.selection, trigger: selectedTab)
                }
            }
            .padding(.horizontal, 16)

            Divider()
                .overlay(FrisTheme.separatorColor)

            switch selectedTab {
            case .posts:
                postsTab
            case .market:
                marketTab
            case .stats:
                statsTab
            }
        }
    }

    private var postsTab: some View {
        LazyVStack(spacing: 0) {
            let posts = viewModel.postsForUser(viewModel.profile.id)
            if posts.isEmpty {
                profileEmptyState(icon: "text.bubble", title: "No Posts Yet", message: "Share your workouts and thoughts with the community.")
            } else {
                ForEach(posts) { post in
                    ProfilePostRow(post: post, profile: viewModel.profile) {
                        viewModel.togglePostLike(post.id)
                    }
                    Divider().overlay(FrisTheme.separatorColor)
                }
            }
        }
    }

    private var marketTab: some View {
        LazyVStack(spacing: 12) {
            if viewModel.userMarketItems.isEmpty {
                profileEmptyState(icon: "bag", title: "No Market Items", message: "Programs and plans you publish will appear here.")
            } else {
                ForEach(viewModel.userMarketItems) { program in
                    ProfileMarketCard(program: program)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var statsTab: some View {
        VStack(spacing: 12) {
            NavigationLink(value: ProfileDestination.analytics) {
                ProfileMenuRow(icon: "chart.xyaxis.line", title: "Workout Analytics", subtitle: "Volume trends, muscle map, PRs")
            }
            .buttonStyle(.scale)

            NavigationLink(value: ProfileDestination.achievements) {
                ProfileMenuRow(icon: "trophy.fill", title: "Achievements", subtitle: "\(viewModel.unlockedCount) of \(viewModel.allAchievements.count) unlocked")
            }
            .buttonStyle(.scale)

            NavigationLink(value: ProfileDestination.workoutHistory) {
                ProfileMenuRow(icon: "clock.arrow.circlepath", title: "Workout History", subtitle: "\(viewModel.workoutHistory.count) workouts logged")
            }
            .buttonStyle(.scale)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private func profileEmptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(FrisTheme.textSecondary.opacity(0.5))
            Text(title)
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(FrisTheme.textSecondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(FrisTheme.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 48)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1000 {
            return String(format: "%.1fk", Double(n) / 1000.0)
        }
        return "\(n)"
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        }
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000)
        }
        return "\(count)"
    }
}

enum ProfileDestination: Hashable {
    case analytics
    case achievements
    case settings
    case workoutHistory
    case historyDetail(WorkoutHistoryDetail)
    case userProfile(SocialUser)
}

extension WorkoutHistoryDetail: Hashable {
    nonisolated static func == (lhs: WorkoutHistoryDetail, rhs: WorkoutHistoryDetail) -> Bool {
        lhs.id == rhs.id
    }
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct ProfileQuickStat: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(FrisTheme.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(FrisTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ProfilePostRow: View {
    let post: UserPost
    let profile: UserProfile
    let onLike: () -> Void

    @State private var likeBounce: Int = 0

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [profile.avatarColor.opacity(0.8), FrisTheme.violet.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .overlay {
                    Text(profile.initials)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(profile.displayName)
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(FrisTheme.textPrimary)

                    Text("@\(profile.username)")
                        .font(.caption)
                        .foregroundStyle(FrisTheme.textSecondary)

                    Text("·")
                        .font(.caption)
                        .foregroundStyle(FrisTheme.textSecondary)

                    Text(post.timestamp.timeAgoDisplay())
                        .font(.caption)
                        .foregroundStyle(FrisTheme.textSecondary)
                }

                Text(post.content)
                    .font(.subheadline)
                    .foregroundStyle(FrisTheme.textPrimary)
                    .lineSpacing(3)

                if let attachment = post.workoutAttachment {
                    workoutCard(attachment)
                }

                HStack(spacing: 24) {
                    Button {
                        onLike()
                        likeBounce += 1
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: post.isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 14))
                                .foregroundStyle(post.isLiked ? .red : FrisTheme.textSecondary)
                                .symbolEffect(.bounce, value: likeBounce)
                            Text("\(post.likeCount)")
                                .font(.caption)
                                .foregroundStyle(FrisTheme.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.impact(weight: .light), trigger: likeBounce)

                    HStack(spacing: 5) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 14))
                        Text("\(post.commentCount)")
                            .font(.caption)
                    }
                    .foregroundStyle(FrisTheme.textSecondary)

                    HStack(spacing: 5) {
                        Image(systemName: "arrow.2.squarepath")
                            .font(.system(size: 14))
                    }
                    .foregroundStyle(FrisTheme.textSecondary)

                    Spacer()
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func workoutCard(_ attachment: WorkoutPostAttachment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(attachment.workoutName)
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(FrisTheme.textPrimary)

            HStack(spacing: 14) {
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text("\(attachment.duration)m")
                        .font(.caption2)
                }
                HStack(spacing: 3) {
                    Image(systemName: "dumbbell")
                        .font(.system(size: 10))
                    Text("\(attachment.exerciseCount)")
                        .font(.caption2)
                }
                HStack(spacing: 3) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(FrisTheme.cyan)
                    Text("\(attachment.fpEarned) FP")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(FrisTheme.cyan)
                }
            }
            .foregroundStyle(FrisTheme.textSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FrisTheme.elevated.opacity(0.6))
        .clipShape(.rect(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(FrisTheme.glassBorderTop, lineWidth: 0.5)
        )
    }
}

struct ProfileMarketCard: View {
    let program: MarketProgram

    var body: some View {
        HStack(spacing: 14) {
            let colors = program.gradientColors.map { Color(red: $0.r, green: $0.g, blue: $0.b) }
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(colors: colors, startPoint: .topTrailing, endPoint: .bottomLeading)
                )
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: program.iconName)
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.9))
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(program.title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(FrisTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", program.rating))
                            .font(.caption)
                            .foregroundStyle(FrisTheme.textSecondary)
                    }

                    Text("·")
                        .foregroundStyle(FrisTheme.textSecondary)

                    Text("\(program.reviewCount) reviews")
                        .font(.caption)
                        .foregroundStyle(FrisTheme.textSecondary)

                    Text("·")
                        .foregroundStyle(FrisTheme.textSecondary)

                    Text(program.difficulty.rawValue)
                        .font(.caption)
                        .foregroundStyle(FrisTheme.textSecondary)
                }

                Text("\(program.durationWeeks) weeks · \(program.daysPerWeek)x/week")
                    .font(.caption2)
                    .foregroundStyle(FrisTheme.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(FrisTheme.textSecondary)
        }
        .padding(14)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(colors: [FrisTheme.glassBorderTop, FrisTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }
}

private struct ProfileMenuRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(FrisTheme.cyan)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body, weight: .medium))
                    .foregroundStyle(FrisTheme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(FrisTheme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(FrisTheme.textSecondary)
        }
        .padding(14)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(colors: [FrisTheme.glassBorderTop, FrisTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }
}
