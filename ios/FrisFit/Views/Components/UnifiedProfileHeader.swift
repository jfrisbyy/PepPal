import SwiftUI

/// Shared editorial-style header used by both the current user's profile
/// and other users' profiles. Keeps the chrome minimal: avatar, name,
/// handle, a single CTA cluster, and follow stats. Everything else
/// (bio, social links, program, etc.) lives inside the Posts tab via
/// `ProfileContextStrip` so the header stays clean across all states.
struct UnifiedProfileHeader<Actions: View, AvatarBadge: View>: View {
    let bannerImage: UIImage?
    let bannerUrl: String?
    let avatarUrl: String?
    let avatarInitials: String
    let avatarColor: Color
    let displayName: String
    let username: String
    let userIdString: String
    let followingCount: Int
    let followerCount: Int
    let friendCount: Int?
    let isUploadingAvatar: Bool

    @ViewBuilder let actions: () -> Actions
    @ViewBuilder let avatarBadge: () -> AvatarBadge

    init(
        bannerImage: UIImage? = nil,
        bannerUrl: String? = nil,
        avatarUrl: String?,
        avatarInitials: String,
        avatarColor: Color,
        displayName: String,
        username: String,
        userIdString: String,
        followingCount: Int,
        followerCount: Int,
        friendCount: Int? = nil,
        isUploadingAvatar: Bool = false,
        @ViewBuilder actions: @escaping () -> Actions,
        @ViewBuilder avatarBadge: @escaping () -> AvatarBadge = { EmptyView() }
    ) {
        self.bannerImage = bannerImage
        self.bannerUrl = bannerUrl
        self.avatarUrl = avatarUrl
        self.avatarInitials = avatarInitials
        self.avatarColor = avatarColor
        self.displayName = displayName
        self.username = username
        self.userIdString = userIdString
        self.followingCount = followingCount
        self.followerCount = followerCount
        self.friendCount = friendCount
        self.isUploadingAvatar = isUploadingAvatar
        self.actions = actions
        self.avatarBadge = avatarBadge
    }

    var body: some View {
        VStack(spacing: 0) {
            banner
            identity
                .padding(.horizontal, 16)
                .padding(.top, 12)
        }
    }

    // MARK: Banner + avatar

    private var banner: some View {
        ZStack(alignment: .bottomLeading) {
            bannerBackground
                .frame(height: 130)

            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(PepTheme.background)
                    .frame(width: 88, height: 88)
                    .overlay {
                        if isUploadingAvatar {
                            Circle()
                                .fill(PepTheme.background)
                                .frame(width: 80, height: 80)
                                .overlay {
                                    ProgressView()
                                        .controlSize(.regular)
                                        .tint(PepTheme.teal)
                                }
                        } else {
                            ProfileAvatarView(
                                avatarUrl: avatarUrl,
                                initials: avatarInitials,
                                avatarColor: avatarColor,
                                size: 80
                            )
                        }
                    }

                avatarBadge()
                    .offset(x: -2, y: -2)
            }
            .offset(x: 16, y: 44)
        }
        .padding(.bottom, 48)
    }

    @ViewBuilder
    private var bannerBackground: some View {
        if let bannerImage {
            Color(.secondarySystemBackground)
                .overlay {
                    Image(uiImage: bannerImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .allowsHitTesting(false)
                }
                .clipped()
        } else if let urlString = bannerUrl, let url = URL(string: urlString) {
            Color(.secondarySystemBackground)
                .overlay {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .allowsHitTesting(false)
                        }
                    }
                }
                .clipped()
        } else {
            LinearGradient(
                colors: [
                    avatarColor.opacity(0.18),
                    PepTheme.background
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(PepTheme.separatorColor)
                    .frame(height: 0.5)
            }
        }
    }

    // MARK: Identity row

    private var identity: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)

                    Text("@\(username)")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textSecondary)
                }

                Spacer()

                actions()
            }

            HStack(spacing: 22) {
                statLink(
                    count: followingCount,
                    label: "Following",
                    destination: .following(userId: userIdString, username: displayName)
                )
                statLink(
                    count: followerCount,
                    label: "Followers",
                    destination: .followers(userId: userIdString, username: displayName)
                )
                if let friendCount {
                    statLink(
                        count: friendCount,
                        label: "Friends",
                        destination: .friends(userId: userIdString, username: displayName)
                    )
                }
            }
        }
    }

    private func statLink(count: Int, label: String, destination: FollowListDestination) -> some View {
        NavigationLink(value: destination) {
            HStack(spacing: 4) {
                Text(formatCount(count))
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        }
        if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}
