import UserNotifications
import SwiftUI

@Observable
final class NotificationService {
    static let shared = NotificationService()

    var isAuthorized: Bool = false
    var preferences: NotificationPreferences = NotificationPreferences(
        enabled: true,
        workoutReminderTime: {
            var components = DateComponents()
            components.hour = 18
            components.minute = 0
            return Calendar.current.date(from: components) ?? Date()
        }(),
        enabledTypes: Set(NotificationType.allCases)
    )

    private init() {
        checkAuthorizationStatus()
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
            if granted {
                scheduleAllNotifications()
            }
            return granted
        } catch {
            return false
        }
    }

    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    func scheduleWorkoutReminder() {
        guard preferences.enabledTypes.contains(.workoutReminder) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time to Train 💪"
        content.body = "Your muscles are waiting. Let's crush today's workout!"
        content.sound = .default
        content.categoryIdentifier = NotificationType.workoutReminder.rawValue

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: preferences.workoutReminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(
            identifier: "daily_workout_reminder",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func scheduleStreakWarning(currentStreak: Int) {
        guard preferences.enabledTypes.contains(.streakWarning) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Don't Break Your Streak! 🔥"
        content.body = "You're on a \(currentStreak)-day streak. Log any activity today to keep it going!"
        content.sound = .default
        content.categoryIdentifier = NotificationType.streakWarning.rawValue

        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let request = UNNotificationRequest(
            identifier: "streak_warning",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func sendStreakMilestoneNotification(days: Int) {
        guard preferences.enabledTypes.contains(.streakMilestone) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Streak Milestone! 🏆"
        content.body = "Incredible! You've hit a \(days)-day streak. You're unstoppable!"
        content.sound = .default
        content.categoryIdentifier = NotificationType.streakMilestone.rawValue

        let request = UNNotificationRequest(
            identifier: "streak_milestone_\(days)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func sendFriendWorkoutNotification(friendName: String, workoutName: String) {
        guard preferences.enabledTypes.contains(.friendWorkout) else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(friendName) just crushed it"
        content.body = "Completed \(workoutName). Show them some love!"
        content.sound = .default
        content.categoryIdentifier = NotificationType.friendWorkout.rawValue

        let request = UNNotificationRequest(
            identifier: "friend_workout_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func sendLikeNotification(fromFriend: String) {
        guard preferences.enabledTypes.contains(.friendLike) else { return }

        let content = UNMutableNotificationContent()
        content.title = "New Like ❤️"
        content.body = "\(fromFriend) liked your post!"
        content.sound = .default
        content.categoryIdentifier = NotificationType.friendLike.rawValue

        let request = UNNotificationRequest(
            identifier: "like_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func scheduleWeeklyProgressNotification(fpEarned: Int, targetFP: Int) {
        guard preferences.enabledTypes.contains(.weeklyProgress) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Weekly Progress Update 📊"
        content.body = "You earned \(fpEarned) FP this week (\(Int(Double(fpEarned) / Double(targetFP) * 100))% of your goal). Keep pushing!"
        content.sound = .default
        content.categoryIdentifier = NotificationType.weeklyProgress.rawValue

        var dateComponents = DateComponents()
        dateComponents.weekday = 1
        dateComponents.hour = 10
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: "weekly_progress",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func scheduleRestDayRecovery() {
        guard preferences.enabledTypes.contains(.restDayRecovery) else { return }

        let tips = [
            "Rest days are when your muscles actually grow. Focus on hydration and sleep tonight.",
            "Active recovery tip: A 20-minute walk can boost blood flow and speed up recovery.",
            "Don't forget to stretch! 10 minutes of mobility work goes a long way.",
            "Recovery is training too. Your body is rebuilding stronger right now.",
            "Foam rolling for 15 minutes can reduce next-day soreness by up to 50%.",
        ]

        let content = UNMutableNotificationContent()
        content.title = "Finn's Recovery Tip 🧘"
        content.body = tips.randomElement() ?? tips[0]
        content.sound = .default
        content.categoryIdentifier = NotificationType.restDayRecovery.rawValue

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)

        let request = UNNotificationRequest(
            identifier: "rest_day_recovery",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func scheduleAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        guard preferences.enabled else { return }
        scheduleWorkoutReminder()
        scheduleWeeklyProgressNotification(fpEarned: 0, targetFP: 2500)
    }

    func toggleNotificationType(_ type: NotificationType) {
        if preferences.enabledTypes.contains(type) {
            preferences.enabledTypes.remove(type)
        } else {
            preferences.enabledTypes.insert(type)
        }
        scheduleAllNotifications()
    }

    func updateReminderTime(_ time: Date) {
        preferences.workoutReminderTime = time
        scheduleAllNotifications()
    }
}
