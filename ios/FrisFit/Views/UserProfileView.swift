import SwiftUI

struct UserProfileView: View {
    let user: SocialUser
    let viewModel: ProfileViewModel

    @State private var selectedTab: UserProfileTab = .posts
    @State private var isFollowing: Bool = false
    @State private var friendStatus: FriendRequestStatus = .none
    @State private var followBounce: Int = 0
    @State private var friendBounce: Int = 0
    @Environment(\.dismiss) private var dismiss

    enum UserProfileTab: String, CaseIterable {
        case posts = "Posts"
        case market = "Market"
        case about = "About"
    }

    private var mockPosts: [UserPost] {
        let now = Date()
        return [
            UserPost(
                authorId: user.id,
                content: "Great session today! Feeling stronger every week.",
                timestamp: now.addingTimeInterval(-7200),
                likeCount: 15,
                commentCount: 3,
                workoutAttachment: WorkoutPostAttachment(workoutName: user.activeProgramName ?? "Full Body", duration: 55, exerciseCount: 5, fpEarned: 280)
            ),
            UserPost(
                authorId: user.id,
                content: "New week, new goals. Let's get it!",
                timestamp: now.addingTimeInterval(-172800),
                likeCount: 22,
                commentCount: 7
            ),
            UserPost(
                authorId: user.id,
                content: "Recovery day. Foam rolling and stretching. Don't skip it.",
                timestamp: now.addingTimeInterval(-345600),
                likeCount: 34,
                commentCount: 5
            ),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                bannerHeader
                profileInfo
                    .padding(.horizontal, 16)
                quickStats
                    .padding(.top, 16)
                    .padding(.horizontal, 16)
                tabSection
                    .padding(.top, 20)
            }
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(PepTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private var bannerHeader: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    user.avatarColor.opacity(0.3),
                    PepTheme.violet.opacity(0.1),
                    PepTheme.background
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 120)

            Circle()
                .fill(PepTheme.background)
                .frame(width: 88, height: 88)
                .overlay {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [user.avatarColor.opacity(0.8), user.avatarColor.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .overlay {
                            Text(user.avatarInitial)
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
                    Text(user.name)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)

                    Text("@\(user.username)")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textSecondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            isFollowing.toggle()
                            followBounce += 1
                        }
                    } label: {
                        Text(isFollowing ? "Following" : "Follow")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(isFollowing ? PepTheme.textPrimary : .black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(isFollowing ? PepTheme.elevated : PepTheme.teal)
                            .clipShape(.capsule)
                            .overlay(
                                Capsule().strokeBorder(
                                    isFollowing ? PepTheme.glassBorderTop : .clear,
                                    lineWidth: 0.5
                                )
                            )
                    }
                    .sensoryFeedback(.impact(weight: .medium), trigger: followBounce)

                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            if friendStatus == .none {
                                friendStatus = .pending
                            }
                            friendBounce += 1
                        }
                    } label: {
                        Image(systemName: friendIcon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(friendIconColor)
                            .frame(width: 34, height: 34)
                            .background(PepTheme.elevated)
                            .clipShape(Circle())
                            .overlay(
                                Circle().strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                            )
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: friendBounce)
                    .disabled(friendStatus == .accepted)
                }
            }

            if let program = user.activeProgramName {
                HStack(spacing: 4) {
                    Image(systemName: "figure.run")
                        .font(.caption2)
                        .foregroundStyle(PepTheme.teal)
                    Text("Running \(program)")
                        .font(.caption)
                        .foregroundStyle(PepTheme.teal)
                }
                .padding(.top, 4)
            }

            HStack(spacing: 20) {
                HStack(spacing: 4) {
                    Text("\(Int.random(in: 100...500))")
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Following")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textSecondary)
                }

                HStack(spacing: 4) {
                    Text("\(Int.random(in: 200...2000))")
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Followers")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            .padding(.top, 8)

            friendStatusBadge
        }
    }

    private var friendIcon: String {
        switch friendStatus {
        case .none: "person.badge.plus"
        case .pending: "clock"
        case .accepted: "person.fill.checkmark"
        }
    }

    private var friendIconColor: Color {
        switch friendStatus {
        case .none: PepTheme.textPrimary
        case .pending: PepTheme.amber
        case .accepted: PepTheme.teal
        }
    }

    @ViewBuilder
    private var friendStatusBadge: some View {
        switch friendStatus {
        case .none:
            EmptyView()
        case .pending:
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.caption2)
                Text("Friend request sent")
                    .font(.caption)
            }
            .foregroundStyle(PepTheme.amber)
            .padding(.top, 4)
        case .accepted:
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.caption2)
                Text("Friends")
                    .font(.caption)
            }
            .foregroundStyle(PepTheme.teal)
            .padding(.top, 4)
        }
    }

    private var quickStats: some View {
        HStack(spacing: 0) {
            ProfileQuickStat(value: "\(user.streak)", label: "Day Streak", icon: "flame.fill", color: PepTheme.amber)
        }
        .padding(.vertical, 14)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    private var tabSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(UserProfileTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Text(tab.rawValue)
                                .font(.system(.subheadline, weight: selectedTab == tab ? .bold : .medium))
                                .foregroundStyle(selectedTab == tab ? PepTheme.textPrimary : PepTheme.textSecondary)
                                .frame(maxWidth: .infinity)

                            Rectangle()
                                .fill(selectedTab == tab ? PepTheme.teal : .clear)
                                .frame(height: 2)
                                .clipShape(.capsule)
                        }
                    }
                    .sensoryFeedback(.selection, trigger: selectedTab)
                }
            }
            .padding(.horizontal, 16)

            Divider()
                .overlay(PepTheme.separatorColor)

            switch selectedTab {
            case .posts:
                postsContent
            case .market:
                marketContent
            case .about:
                aboutContent
            }
        }
    }

    private var postsContent: some View {
        LazyVStack(spacing: 0) {
            ForEach(mockPosts) { post in
                userPostRow(post)
                Divider().overlay(PepTheme.separatorColor)
            }
        }
    }

    private func userPostRow(_ post: UserPost) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [user.avatarColor.opacity(0.8), user.avatarColor.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .overlay {
                    Text(user.avatarInitial)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(user.name)
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)

                    Text("@\(user.username)")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)

                    Text("·")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)

                    Text(post.timestamp.timeAgoDisplay())
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }

                Text(post.content)
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineSpacing(3)

                if let attachment = post.workoutAttachment {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(attachment.workoutName)
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)

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
                        }
                        .foregroundStyle(PepTheme.textSecondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PepTheme.elevated.opacity(0.6))
                    .clipShape(.rect(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                    )
                }

                HStack(spacing: 24) {
                    HStack(spacing: 5) {
                        Image(systemName: "heart")
                            .font(.system(size: 14))
                        Text("\(post.likeCount)")
                            .font(.caption)
                    }
                    .foregroundStyle(PepTheme.textSecondary)

                    HStack(spacing: 5) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 14))
                        Text("\(post.commentCount)")
                            .font(.caption)
                    }
                    .foregroundStyle(PepTheme.textSecondary)

                    Spacer()
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var marketContent: some View {
        VStack(spacing: 12) {
            emptyState(icon: "bag", title: "No Market Items", message: "\(user.name) hasn't published any programs yet.")
        }
        .padding(.top, 12)
    }

    private var aboutContent: some View {
        VStack(spacing: 12) {
            if let program = user.activeProgramName {
                aboutRow(icon: "figure.run", label: "Active Program", value: program)
            }
            aboutRow(icon: "flame.fill", label: "Current Streak", value: "\(user.streak) days")
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private func aboutRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(PepTheme.teal)
                .frame(width: 28)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
        }
        .padding(14)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
            Text(title)
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
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
}
