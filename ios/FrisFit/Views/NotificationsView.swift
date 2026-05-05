import SwiftUI

struct NotificationsView: View {
    @State private var viewModel = NotificationsViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                masthead

                if viewModel.notifications.isEmpty && viewModel.pendingFriendRequests.isEmpty {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    } else {
                        emptyState
                            .padding(.top, 40)
                    }
                } else {
                    if !viewModel.pendingFriendRequests.isEmpty {
                        friendRequestsSection
                    }

                    if !viewModel.notifications.isEmpty {
                        activitySection
                    }
                }

                Color.clear.frame(height: 40)
            }
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadNotifications()
            await viewModel.subscribeRealtime()
        }
        .refreshable {
            await viewModel.loadNotifications()
        }
    }

    // MARK: - Masthead

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("THE DISPATCH")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(2.0)
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.75))

                Rectangle()
                    .fill(PepTheme.separatorColor)
                    .frame(height: 0.5)
            }

            HStack(alignment: .firstTextBaseline) {
                Text("Notifications")
                    .font(.system(size: 34, weight: .regular, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)

                Spacer()

                if !viewModel.notifications.isEmpty {
                    Button {
                        viewModel.markAllRead()
                    } label: {
                        Text("Mark all read")
                            .font(.system(.footnote, design: .serif).italic())
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if viewModel.unreadCount > 0 {
                Text("\(viewModel.unreadCount) unread")
                    .font(.system(.caption, design: .serif).italic())
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.75))
            } else if !viewModel.notifications.isEmpty {
                Text("All caught up")
                    .font(.system(.caption, design: .serif).italic())
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.75))
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bell")
                .font(.system(size: 28, weight: .ultraLight))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.55))

            Text("Nothing to report")
                .font(.system(size: 22, weight: .regular, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)

            Text("Follows, friend requests, and messages will be filed here.")
                .font(.system(.footnote, design: .serif).italic())
                .foregroundStyle(PepTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Friend Requests

    private var friendRequestsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionEyebrow(
                "Friend Requests",
                number: "01",
                accent: PepTheme.violet
            ) {
                Text("\(viewModel.pendingFriendRequests.count)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            hairline

            ForEach(viewModel.pendingFriendRequests) { request in
                friendRequestRow(request)
                hairline
            }
        }
    }

    private func friendRequestRow(_ request: PendingFriendRequest) -> some View {
        HStack(spacing: 14) {
            Circle()
                .stroke(PepTheme.separatorColor, lineWidth: 0.5)
                .background(
                    Circle().fill(PepTheme.elevated.opacity(0.5))
                )
                .frame(width: 40, height: 40)
                .overlay {
                    Text(request.sender.avatarInitial)
                        .font(.system(.subheadline, design: .serif, weight: .regular))
                        .foregroundStyle(PepTheme.textPrimary)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(request.sender.name)
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)

                Text("@\(request.sender.username) · wants to be friends")
                    .font(.system(.caption, design: .serif).italic())
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 10) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        viewModel.acceptFriendRequest(requestId: request.id)
                    }
                } label: {
                    Text("Accept")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.4)
                        .textCase(.uppercase)
                        .foregroundStyle(PepTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .overlay(
                            Capsule().stroke(PepTheme.textPrimary.opacity(0.6), lineWidth: 0.7)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        viewModel.rejectFriendRequest(requestId: request.id)
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .light))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 26, height: 26)
                        .overlay(
                            Circle().stroke(PepTheme.separatorColor, lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Activity

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionEyebrow(
                "Activity",
                number: viewModel.pendingFriendRequests.isEmpty ? "01" : "02",
                accent: PepTheme.teal
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            hairline

            ForEach(groupedNotifications, id: \.label) { group in
                groupHeader(group.label)

                ForEach(group.items) { notification in
                    notificationRow(notification)
                    hairline
                }
            }
        }
    }

    private func groupHeader(_ label: String) -> some View {
        HStack(spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))

            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(height: 0.5)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }

    private func notificationRow(_ notification: AppNotification) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Thin vertical accent rule for unread; muted for read
            Rectangle()
                .fill(notification.isRead ? PepTheme.separatorColor : notification.iconColor.opacity(0.85))
                .frame(width: notification.isRead ? 0.5 : 1.5)
                .frame(maxHeight: .infinity)

            // Thin glyph instead of tinted circle
            Image(systemName: notification.icon)
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(notification.isRead ? PepTheme.textSecondary.opacity(0.7) : notification.iconColor)
                .frame(width: 22, height: 22)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(2)

                if !notification.body.isEmpty {
                    Text(notification.body)
                        .font(.system(.footnote, design: .serif).italic())
                        .foregroundStyle(PepTheme.textSecondary)
                        .lineLimit(2)
                }

                Text(notification.createdAt.timeAgoDisplay().uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
                    .padding(.top, 2)
            }

            Spacer(minLength: 8)

            if !notification.isRead {
                Circle()
                    .fill(PepTheme.teal)
                    .frame(width: 6, height: 6)
                    .padding(.top, 6)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 20)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture {
            if !notification.isRead {
                viewModel.markAsRead(notificationId: notification.id)
            }
        }
    }

    // MARK: - Helpers

    private var hairline: some View {
        Rectangle()
            .fill(PepTheme.separatorColor)
            .frame(height: 0.5)
            .padding(.horizontal, 20)
    }

    private struct NotificationGroup {
        let label: String
        let items: [AppNotification]
    }

    private var groupedNotifications: [NotificationGroup] {
        let cal = Calendar.current
        let now = Date()
        var today: [AppNotification] = []
        var week: [AppNotification] = []
        var earlier: [AppNotification] = []

        for n in viewModel.notifications {
            if cal.isDateInToday(n.createdAt) {
                today.append(n)
            } else if let days = cal.dateComponents([.day], from: n.createdAt, to: now).day, days < 7 {
                week.append(n)
            } else {
                earlier.append(n)
            }
        }

        var groups: [NotificationGroup] = []
        if !today.isEmpty { groups.append(.init(label: "Today", items: today)) }
        if !week.isEmpty { groups.append(.init(label: "This Week", items: week)) }
        if !earlier.isEmpty { groups.append(.init(label: "Earlier", items: earlier)) }
        return groups
    }
}
