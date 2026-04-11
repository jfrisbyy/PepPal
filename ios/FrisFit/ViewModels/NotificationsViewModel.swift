import SwiftUI

@Observable
final class NotificationsViewModel {
    var notifications: [AppNotification] = []
    var pendingFriendRequests: [PendingFriendRequest] = []
    var isLoading: Bool = false
    var unreadCount: Int = 0

    private let messagingService = MessagingService.shared

    func loadNotifications() async {
        guard !isLoading else { return }
        isLoading = true

        do {
            let userId = try AuthService.shared.currentUserId()

            async let notifResult = messagingService.fetchNotifications(userId: userId)
            async let requestsResult = messagingService.fetchPendingRequests(userId: userId)
            async let unreadResult = messagingService.unreadNotificationCount(userId: userId)

            let (notifs, requests, unread) = try await (notifResult, requestsResult, unreadResult)

            notifications = notifs.map { n in
                AppNotification(
                    id: n.id,
                    type: n.type ?? "general",
                    title: n.title ?? "",
                    body: n.body ?? "",
                    isRead: n.is_read ?? false,
                    createdAt: messagingService.parseDate(n.created_at)
                )
            }

            pendingFriendRequests = requests.map { r in
                let sender = messagingService.socialUserFromAuthor(r.sender_profile)
                return PendingFriendRequest(
                    id: r.id,
                    sender: sender,
                    createdAt: messagingService.parseDate(r.created_at)
                )
            }

            unreadCount = unread + requests.count
        } catch {
            // Silently fail
        }

        isLoading = false
    }

    func markAsRead(notificationId: String) {
        Task {
            try? await messagingService.markNotificationRead(notificationId: notificationId)
            if let idx = notifications.firstIndex(where: { $0.id == notificationId }) {
                notifications[idx].isRead = true
                unreadCount = max(0, unreadCount - 1)
            }
        }
    }

    func markAllRead() {
        Task {
            do {
                let userId = try AuthService.shared.currentUserId()
                try await messagingService.markAllNotificationsRead(userId: userId)
                for i in notifications.indices {
                    notifications[i].isRead = true
                }
                unreadCount = pendingFriendRequests.count
            } catch {}
        }
    }

    func acceptFriendRequest(requestId: String) {
        Task {
            do {
                try await messagingService.acceptFriendRequest(requestId: requestId)
                pendingFriendRequests.removeAll { $0.id == requestId }
                unreadCount = max(0, unreadCount - 1)
            } catch {}
        }
    }

    func rejectFriendRequest(requestId: String) {
        Task {
            do {
                try await messagingService.rejectFriendRequest(requestId: requestId)
                pendingFriendRequests.removeAll { $0.id == requestId }
                unreadCount = max(0, unreadCount - 1)
            } catch {}
        }
    }

    func refreshUnreadCount() async {
        do {
            let userId = try AuthService.shared.currentUserId()
            let count = try await messagingService.unreadNotificationCount(userId: userId)
            let requests = try await messagingService.fetchPendingRequests(userId: userId)
            unreadCount = count + requests.count
        } catch {}
    }
}

struct AppNotification: Identifiable {
    let id: String
    let type: String
    let title: String
    let body: String
    var isRead: Bool
    let createdAt: Date

    var icon: String {
        switch type {
        case "new_follow": return "person.badge.plus"
        case "friend_request": return "person.2.fill"
        case "new_message": return "bubble.left.fill"
        case "friend_like", "friend_high_five": return "heart.fill"
        default: return "bell.fill"
        }
    }

    var iconColor: Color {
        switch type {
        case "new_follow": return PepTheme.teal
        case "friend_request": return PepTheme.violet
        case "new_message": return .blue
        case "friend_like", "friend_high_five": return .red
        default: return PepTheme.textSecondary
        }
    }
}

struct PendingFriendRequest: Identifiable {
    let id: String
    let sender: SocialUser
    let createdAt: Date
}
