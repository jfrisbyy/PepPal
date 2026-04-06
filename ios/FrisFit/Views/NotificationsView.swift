import SwiftUI

struct NotificationsView: View {
    @State private var viewModel = NotificationsViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if !viewModel.pendingFriendRequests.isEmpty {
                    friendRequestsSection
                }

                if viewModel.notifications.isEmpty && viewModel.pendingFriendRequests.isEmpty {
                    if viewModel.isLoading {
                        ProgressView()
                            .padding(.top, 60)
                    } else {
                        EmptyStateView(
                            icon: "bell.slash",
                            title: "No Notifications",
                            message: "You're all caught up! Notifications for follows, friend requests, and messages will appear here."
                        )
                    }
                } else {
                    ForEach(viewModel.notifications) { notification in
                        notificationRow(notification)
                        Divider().overlay(PepTheme.separatorColor)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .background(PepTheme.background.ignoresSafeArea())
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !viewModel.notifications.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.markAllRead()
                    } label: {
                        Text("Mark All Read")
                            .font(.caption)
                            .foregroundStyle(PepTheme.teal)
                    }
                }
            }
        }
        .task {
            await viewModel.loadNotifications()
        }
        .refreshable {
            await viewModel.loadNotifications()
        }
    }

    private var friendRequestsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Friend Requests")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .textCase(.uppercase)

                Text("\(viewModel.pendingFriendRequests.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(PepTheme.violet)
                    .clipShape(.circle)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            ForEach(viewModel.pendingFriendRequests) { request in
                friendRequestRow(request)
                Divider().overlay(PepTheme.separatorColor)
            }
        }
    }

    private func friendRequestRow(_ request: PendingFriendRequest) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(request.sender.avatarColor.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay {
                    Text(request.sender.avatarInitial)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(request.sender.avatarColor)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(request.sender.name)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)

                Text("@\(request.sender.username) wants to be friends")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.acceptFriendRequest(requestId: request.id)
                    }
                } label: {
                    Text("Accept")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(PepTheme.teal)
                        .clipShape(.capsule)
                }

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.rejectFriendRequest(requestId: request.id)
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(PepTheme.elevated)
                        .clipShape(.circle)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func notificationRow(_ notification: AppNotification) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(notification.iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: notification.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(notification.iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(notification.title)
                    .font(.system(.subheadline, weight: notification.isRead ? .medium : .bold))
                    .foregroundStyle(PepTheme.textPrimary)

                Text(notification.body)
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineLimit(2)

                Text(notification.createdAt.timeAgoDisplay())
                    .font(.system(size: 11))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
            }

            Spacer()

            if !notification.isRead {
                Circle()
                    .fill(PepTheme.teal)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(notification.isRead ? .clear : PepTheme.teal.opacity(0.03))
        .contentShape(Rectangle())
        .onTapGesture {
            if !notification.isRead {
                viewModel.markAsRead(notificationId: notification.id)
            }
        }
    }
}
