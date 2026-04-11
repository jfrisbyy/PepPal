import SwiftUI

enum FollowListDestination: Hashable {
    case followers(userId: String, username: String)
    case following(userId: String, username: String)

    var title: String {
        switch self {
        case .followers(_, let username): "\(username)'s Followers"
        case .following(_, let username): "\(username) Following"
        }
    }

    var userId: String {
        switch self {
        case .followers(let id, _): id
        case .following(let id, _): id
        }
    }

    var isFollowers: Bool {
        switch self {
        case .followers: true
        case .following: false
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
                    Image(systemName: destination.isFollowers ? "person.2" : "person.badge.plus")
                        .font(.system(size: 40))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                    Text(destination.isFollowers ? "No Followers Yet" : "Not Following Anyone")
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                    Text(destination.isFollowers ? "When people follow this account, they'll show up here." : "When this account follows people, they'll show up here.")
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
                            NavigationLink(value: ProfileDestination.userProfile(user)) {
                                followUserRow(user)
                            }
                            .buttonStyle(.plain)
                            Divider().overlay(PepTheme.separatorColor)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(PepTheme.background.ignoresSafeArea())
        .navigationTitle(destination.isFollowers ? "Followers" : "Following")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadUsers()
        }
    }

    private func followUserRow(_ user: SocialUser) -> some View {
        HStack(spacing: 12) {
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

            VStack(alignment: .leading, spacing: 3) {
                Text(user.name)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("@\(user.username)")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            if user.streak > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(PepTheme.amber)
                    Text("\(user.streak)")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func loadUsers() async {
        isLoading = true
        do {
            let userIds: [String]
            if destination.isFollowers {
                userIds = try await messagingService.fetchFollowers(userId: destination.userId)
            } else {
                userIds = try await messagingService.fetchFollowing(userId: destination.userId)
            }

            let profiles = try await messagingService.fetchProfilesByIds(userIds)
            users = profiles.map { SocialService.shared.socialUserFromAuthor($0) }
        } catch {
            users = []
        }
        isLoading = false
    }
}
