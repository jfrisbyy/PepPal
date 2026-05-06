import Foundation
import UserNotifications
import UIKit

/// Centralized scheduler for all smart, locally-triggered notifications.
/// The engine wipes its own slate (any UNNotificationRequest with the
/// `smart.` identifier prefix) and re-plans the next 24h based on the
/// user's data, settings, quiet hours, and daily cap.
@MainActor
final class SmartNotificationEngine {
    static let shared = SmartNotificationEngine()

    private let center = UNUserNotificationCenter.current()
    private let store = SmartNotificationStore.shared
    private let identifierPrefix = "smart."

    private init() {}

    // MARK: - Public

    /// Request notification permission and register for remote pushes.
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                await UIApplication.shared.registerForRemoteNotifications()
            }
            return granted
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Wipes everything we own and re-schedules the next 24h.
    /// Safe to call multiple times — it's idempotent for a given input.
    func replanAll() async {
        // Clear our previously scheduled notifications. Anything not prefixed
        // `smart.` (e.g. legacy vial/titration reminders) is left alone.
        let pending = await center.pendingNotificationRequests()
        let toRemove = pending.map { $0.identifier }.filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: toRemove)

        guard store.settings.masterEnabled else { return }
        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        var planned: [PlannedNotification] = []
        planned.append(contentsOf: planTraining())
        planned.append(contentsOf: planSleep())
        planned.append(contentsOf: planNutrition())
        planned.append(contentsOf: planSupplements())
        planned.append(contentsOf: planTasks())
        planned.append(contentsOf: planStreaks())

        // Filter by enabled categories.
        planned = planned.filter { store.settings.isCategoryEnabled($0.category) }

        // Snap out of quiet hours (or drop if unrescuable).
        planned = planned.compactMap { item in
            var item = item
            if store.settings.isQuiet(at: item.fireDate) {
                item.fireDate = store.settings.nudgeOutOfQuietHours(item.fireDate)
            }
            // Skip if fire date is in the past after quiet-hour adjustment.
            if item.fireDate <= Date() { return nil }
            return item
        }

        // Apply daily cap (priority ordered).
        if let cap = store.settings.dailyCap {
            let remaining = max(0, cap - store.todayFiredCount())
            let calendar = Calendar.current
            let todayItems = planned
                .filter { calendar.isDateInToday($0.fireDate) }
                .sorted { $0.category.priority < $1.category.priority }
            let allowedToday = Set(todayItems.prefix(remaining).map { $0.id })
            planned.removeAll { calendar.isDateInToday($0.fireDate) && !allowedToday.contains($0.id) }
        }

        for p in planned {
            schedule(p)
        }
    }

    /// Sends a one-off test notification a few seconds out so the user can preview look + sound.
    func sendTest() async {
        let granted = await requestAuthorization()
        guard granted else { return }
        let content = UNMutableNotificationContent()
        content.title = "Test from your coach"
        content.body  = "If you see this, smart notifications are working."
        content.sound = .default
        content.userInfo = ["smart_category": SmartNotificationCategory.tasks.rawValue]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let req = UNNotificationRequest(
            identifier: "\(identifierPrefix)test.\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        try? await center.add(req)
        store.record(SmartNotificationLogEntry(
            category: .tasks,
            title: "Test from your coach",
            body: "If you see this, smart notifications are working.",
            firedAt: Date().addingTimeInterval(3)
        ))
    }

    // MARK: - Logging from delivery

    /// Called from AppDelegate when a remote/local notification is received.
    func recordIncoming(userInfo: [AnyHashable: Any], title: String, body: String) {
        let categoryRaw = (userInfo["smart_category"] as? String) ?? inferCategory(userInfo: userInfo)
        let category = SmartNotificationCategory(rawValue: categoryRaw) ?? .social
        var deepLink: [String: String] = [:]
        for key in ["conversation_id", "post_id", "profile_id", "circle_id", "type"] {
            if let v = userInfo[key] as? String { deepLink[key] = v }
        }
        store.record(SmartNotificationLogEntry(
            category: category,
            title: title,
            body: body,
            deepLink: deepLink.isEmpty ? nil : deepLink
        ))
    }

    private func inferCategory(userInfo: [AnyHashable: Any]) -> String {
        if userInfo["conversation_id"] != nil { return SmartNotificationCategory.social.rawValue }
        if userInfo["circle_id"] != nil { return SmartNotificationCategory.social.rawValue }
        if let t = userInfo["type"] as? String {
            if t.hasPrefix("friend_") || t == "new_message" || t == "new_follow" || t == "buddy_invite" {
                return SmartNotificationCategory.social.rawValue
            }
        }
        return SmartNotificationCategory.social.rawValue
    }

    // MARK: - Planners

    private struct PlannedNotification {
        var id: String
        var category: SmartNotificationCategory
        var title: String
        var body: String
        var fireDate: Date
        var userInfo: [String: String] = [:]
    }

    /// Pre-session reminder + missed-workout nudge.
    private func planTraining() -> [PlannedNotification] {
        var items: [PlannedNotification] = []
        let cal = Calendar.current
        let now = Date()

        // Pre-session: 30 min before usual workout window.
        let preferredHour = ReminderManager.shared.workoutTime
        var preComps = cal.dateComponents([.hour, .minute], from: preferredHour)
        var fire = cal.nextDate(after: now, matching: preComps, matchingPolicy: .nextTime) ?? now
        fire = fire.addingTimeInterval(-30 * 60)
        if fire > now {
            items.append(PlannedNotification(
                id: "training.preSession",
                category: .training,
                title: "Training window opens soon",
                body: "Your session usually starts around now. Want to get loose?",
                fireDate: fire,
                userInfo: ["tab": "train"]
            ))
        }

        // Missed-session: 8pm if nothing logged today (best-effort: we don't
        // know completion synchronously, so we schedule it and let receipt
        // be a soft nudge — the user can disable the category if too noisy).
        var evening = cal.dateComponents([.hour, .minute], from: now)
        evening.hour = 20
        evening.minute = 0
        if let eveningDate = cal.nextDate(after: now, matching: evening, matchingPolicy: .nextTime) {
            items.append(PlannedNotification(
                id: "training.missed",
                category: .training,
                title: "Still time to move",
                body: "Even 20 minutes today keeps the rhythm going.",
                fireDate: eveningDate,
                userInfo: ["tab": "train"]
            ))
        }

        return items
    }

    /// Wind-down + morning sleep log.
    private func planSleep() -> [PlannedNotification] {
        var items: [PlannedNotification] = []
        let cal = Calendar.current
        let now = Date()

        // Wind-down at 9:15pm by default — quiet-hour pass will drop it if needed.
        var windDown = cal.dateComponents([.hour, .minute], from: now)
        windDown.hour = 21
        windDown.minute = 15
        if let date = cal.nextDate(after: now, matching: windDown, matchingPolicy: .nextTime) {
            items.append(PlannedNotification(
                id: "sleep.windDown",
                category: .sleep,
                title: "Wind-down window",
                body: "Lights softer, screens off. Aim for 7+ hours tonight.",
                fireDate: date
            ))
        }

        // Morning: 8:30am — nudge to log if HealthKit didn't.
        var morning = cal.dateComponents([.hour, .minute], from: now)
        morning.hour = 8
        morning.minute = 30
        if let date = cal.nextDate(after: now, matching: morning, matchingPolicy: .nextTime) {
            items.append(PlannedNotification(
                id: "sleep.logMorning",
                category: .sleep,
                title: "How did you sleep?",
                body: "Log last night so we can tune today's load.",
                fireDate: date
            ))
        }

        return items
    }

    private func planNutrition() -> [PlannedNotification] {
        var items: [PlannedNotification] = []
        let cal = Calendar.current
        let now = Date()

        // Hydration nudge at 14:30
        var hyd = cal.dateComponents([.hour, .minute], from: now)
        hyd.hour = 14
        hyd.minute = 30
        if let date = cal.nextDate(after: now, matching: hyd, matchingPolicy: .nextTime) {
            items.append(PlannedNotification(
                id: "nutrition.hydration",
                category: .nutrition,
                title: "Water check",
                body: "Halfway through the day — top up your bottle.",
                fireDate: date
            ))
        }

        // Evening macro check at 19:30
        var macro = cal.dateComponents([.hour, .minute], from: now)
        macro.hour = 19
        macro.minute = 30
        if let date = cal.nextDate(after: now, matching: macro, matchingPolicy: .nextTime) {
            items.append(PlannedNotification(
                id: "nutrition.macros",
                category: .nutrition,
                title: "Macros check-in",
                body: "Quick scan of today's intake before dinner closes the books.",
                fireDate: date
            ))
        }

        return items
    }

    private func planSupplements() -> [PlannedNotification] {
        // Best-effort fixed time of day. The richer per-protocol scheduling
        // already lives in TitrationScheduleStore / VialBUDNotificationService —
        // we add a single morning umbrella reminder so users with neither still
        // get pinged.
        var items: [PlannedNotification] = []
        let cal = Calendar.current
        let now = Date()
        var morning = cal.dateComponents([.hour, .minute], from: now)
        morning.hour = 9
        morning.minute = 0
        if let date = cal.nextDate(after: now, matching: morning, matchingPolicy: .nextTime) {
            items.append(PlannedNotification(
                id: "supplements.morning",
                category: .supplements,
                title: "Morning protocol",
                body: "Time for today's stack — log when done.",
                fireDate: date
            ))
        }
        return items
    }

    private func planTasks() -> [PlannedNotification] {
        var items: [PlannedNotification] = []
        let cal = Calendar.current
        let now = Date()

        // Daily brief at 7:30am
        var briefTime = cal.dateComponents([.hour, .minute], from: now)
        briefTime.hour = 7
        briefTime.minute = 30
        if let date = cal.nextDate(after: now, matching: briefTime, matchingPolicy: .nextTime) {
            items.append(PlannedNotification(
                id: "tasks.brief",
                category: .tasks,
                title: "Today's brief is ready",
                body: "Open the app to see your plan.",
                fireDate: date,
                userInfo: ["tab": "home"]
            ))
        }

        // Late-afternoon reminder at 4:30pm
        var afternoon = cal.dateComponents([.hour, .minute], from: now)
        afternoon.hour = 16
        afternoon.minute = 30
        if let date = cal.nextDate(after: now, matching: afternoon, matchingPolicy: .nextTime) {
            items.append(PlannedNotification(
                id: "tasks.afternoon",
                category: .tasks,
                title: "Tasks left for today",
                body: "A few minutes now keeps tomorrow lighter.",
                fireDate: date,
                userInfo: ["tab": "home"]
            ))
        }

        return items
    }

    private func planStreaks() -> [PlannedNotification] {
        var items: [PlannedNotification] = []
        let cal = Calendar.current
        let now = Date()

        // 9:30pm streak save warning (only if user has an active streak).
        let streak = StreakManager.shared.streakData.currentStreak
        if streak > 0 {
            var save = cal.dateComponents([.hour, .minute], from: now)
            save.hour = 21
            save.minute = 30
            if let date = cal.nextDate(after: now, matching: save, matchingPolicy: .nextTime) {
                items.append(PlannedNotification(
                    id: "streaks.save",
                    category: .streaks,
                    title: "Streak at \(streak) days",
                    body: "Log anything tonight to keep it alive.",
                    fireDate: date
                ))
            }
        }
        return items
    }

    // MARK: - Schedule

    private func schedule(_ p: PlannedNotification) {
        let content = UNMutableNotificationContent()
        content.title = p.title
        content.body  = p.body
        content.sound = .default
        var ui: [String: Any] = ["smart_category": p.category.rawValue, "smart_id": p.id]
        for (k, v) in p.userInfo { ui[k] = v }
        content.userInfo = ui

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: p.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let req = UNNotificationRequest(
            identifier: "\(identifierPrefix)\(p.id).\(Int(p.fireDate.timeIntervalSince1970))",
            content: content,
            trigger: trigger
        )
        center.add(req) { _ in }
    }
}
