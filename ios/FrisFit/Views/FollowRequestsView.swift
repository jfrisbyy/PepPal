import SwiftUI

struct FollowRequestsView: View {
    @State private var requests: [SupabaseFollowRequestWithProfile] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?

    private let messagingService = MessagingService.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .tint(PepTheme.teal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if requests.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.badge.clock")
                        .font(.system(size: 40))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                    Text("No Follow Requests")
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                    Text("When people request to follow you, they'll appear here.")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(requests, id: \.id) { req in
                            row(req)
                            Divider().overlay(PepTheme.separatorColor)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .appBackground()
        .navigationTitle("Follow Requests")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        do {
            let userId = try AuthService.shared.currentUserId()
            requests = try await messagingService.fetchPendingFollowRequests(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
            requests = []
        }
        isLoading = false
    }

    private func row(_ req: SupabaseFollowRequestWithProfile) -> some View {
        let user = SocialService.shared.socialUserFromAuthor(req.profiles)
        return HStack(spacing: 12) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [user.avatarColor.opacity(0.8), user.avatarColor.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .overlay {
                    Text(user.avatarInitial)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(user.name)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("@\(user.username)")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    Task { await approve(req) }
                } label: {
                    Text("Approve")
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(PepTheme.teal)
                        .clipShape(.capsule)
                }

                Button {
                    Task { await deny(req) }
                } label: {
                    Text("Deny")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(PepTheme.elevated)
                        .clipShape(.capsule)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func approve(_ req: SupabaseFollowRequestWithProfile) async {
        do {
            try await messagingService.approveFollowRequest(
                requestId: req.id,
                requesterId: req.requester_id,
                targetId: req.target_id
            )
            requests.removeAll { $0.id == req.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deny(_ req: SupabaseFollowRequestWithProfile) async {
        do {
            try await messagingService.denyFollowRequest(requestId: req.id)
            requests.removeAll { $0.id == req.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
