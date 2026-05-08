import SwiftUI

enum FollowListDestination: Hashable {
    case followers(userId: String, username: String)
    case following(userId: String, username: String)
    case friends(userId: String, username: String)

    var title: String {
        switch self {
        case .followers(_, let username): "\(username)'s Followers"
        case .following(_, let username): "\(username) Following"
        case .friends(_, let username): "\(username)'s Friends"
        }
    }

    var userId: String {
        switch self {
        case .followers(let id, _): id
        case .following(let id, _): id
        case .friends(let id, _): id
        }
    }

    var navTitle: String {
        switch self {
        case .followers: "Followers"
        case .following: "Following"
        case .friends: "Friends"
        }
    }

    var emptyIcon: String {
        switch self {
        case .followers: "person.2"
        case .following: "person.badge.plus"
        case .friends: "person.2.circle"
        }
    }

    var emptyTitle: String {
        switch self {
        case .followers: "No Followers Yet"
        case .following: "Not Following Anyone"
        case .friends: "No Friends Yet"
        }
    }

    var emptyMessage: String {
        switch self {
        case .followers: "When people follow this account, they'll show up here."
        case .following: "When this account follows people, they'll show up here."
        case .friends: "Friends are mutual followers. Follow people back to make them friends."
        }
    }
}

struct FollowListView: View {
    let destination: FollowListDestination
    let profileViewModel: ProfileViewModel

    @State private var users: [SocialUser] = []
    @State private var isLoading: Bool = true

    private let messagingService = MessagingService.shared

    var body: some View {
        Group {
            if isLoading {
                VStack {
                    ProgressView()
                        .tint(PepTheme.teal)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if users.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: destination.emptyIcon)
                        .font(.system(size: 40))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                    Text(destination.emptyTitle)
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                    Text(destination.emptyMessage)
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(users) { user in
                            followUserRow(user)
                            Divider().overlay(PepTheme.separatorColor)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .appBackground()
        .navigationTitle(destination.navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadUsers()
        }
    }

    private func followUserRow(_ user: SocialUser) -> some View {
        HStack(spacing: 12) {
            NavigationLink(value: ProfileDestination.userProfile(user)) {
                avatarView(user)
            }
            .buttonStyle(.plain)

            NavigationLink(value: ProfileDestination.userProfile(user)) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(user.name)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("@\(user.username)")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(.rect)
    }

    private func avatarView(_ user: SocialUser) -> some View {
        Circle()
                .fill(
                    LinearGradient(
                        colors: [user.avatarColor.opacity(0.8), user.avatarColor.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 48, height: 48)
            .overlay {
                Text(user.avatarInitial)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
    }

    private func loadUsers() async {
        isLoading = true
        do {
            let userIds: [String]
            switch destination {
            case .followers:
                userIds = try await messagingService.fetchFollowers(userId: destination.userId)
            case .following:
                userIds = try await messagingService.fetchFollowing(userId: destination.userId)
            case .friends:
                async let followers = messagingService.fetchFollowers(userId: destination.userId)
                async let following = messagingService.fetchFollowing(userId: destination.userId)
                let (f, g) = try await (followers, following)
                let followersSet = Set(f.map { $0.lowercased() })
                userIds = g.filter { followersSet.contains($0.lowercased()) }
            }

            let profiles = try await messagingService.fetchProfilesByIds(userIds)
            var resolved = profiles.map { SocialService.shared.socialUserFromAuthor($0) }

            if case .friends = destination {
                let existing = Set(resolved.map { $0.id })
                let mocks = MockFriendsService.shared.friends.filter { !existing.contains($0.id) }
                resolved.append(contentsOf: mocks)
            }
            users = resolved
        } catch {
            users = []
        }
        isLoading = false
    }
}
