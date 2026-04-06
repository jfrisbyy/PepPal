import Foundation

@Observable
final class StreakManager {
    static let shared = StreakManager()

    var streakData: StreakData
    var activityLog: [ActivityLog]
    var finnEncouragementMessage: String?

    private let calendar = Calendar.current

    private var logsLoaded: Bool = false

    private init() {
        self.activityLog = []
        self.streakData = StreakData(
            currentStreak: 0,
            longestStreak: 0,
            lastActivityDate: nil,
            streakFreezeAvailable: true,
            streakFreezeUsedThisWeek: false,
            missedYesterday: false
        )
    }

    func loadFromSupabase() {
        guard AuthService.shared.authState == .signedIn, !logsLoaded else { return }
        logsLoaded = true
        Task {
            do {
                let userId = try AuthService.shared.currentUserId()
                let logs = try await StreakService.shared.fetchActivityLogs(userId: userId)
                activityLog = logs.map { StreakService.shared.toActivityLog($0) }
                recalculateStreak()
            } catch {
                loadFallbackData()
            }
        }
    }

    private func loadFallbackData() {
        let now = Date()
        let cal = Calendar.current
        var logs: [ActivityLog] = []
        for i in 0..<12 {
            if let date = cal.date(byAdding: .day, value: -i, to: now) {
                logs.append(ActivityLog(id: UUID(), date: date, type: i % 3 == 0 ? .sportSession : .workout))
            }
        }
        activityLog = logs
        recalculateStreak()
    }

    func logActivity(type: ActivityType, sport: Sport? = nil, durationMinutes: Int? = nil) {
        let newLog = ActivityLog(id: UUID(), date: Date(), type: type, sport: sport)
        activityLog.insert(newLog, at: 0)
        recalculateStreak()
        checkMilestones()
        persistActivityToSupabase(type: type, sport: sport, durationMinutes: durationMinutes)
    }

    private func persistActivityToSupabase(type: ActivityType, sport: Sport?, durationMinutes: Int?) {
        guard AuthService.shared.authState == .signedIn else { return }
        Task {
            do {
                let userId = try AuthService.shared.currentUserId()
                _ = try await StreakService.shared.logActivity(userId: userId, type: type, sport: sport, durationMinutes: durationMinutes)
            } catch {}
        }
    }

    func useStreakFreeze() -> Bool {
        guard streakData.streakFreezeAvailable, !streakData.streakFreezeUsedThisWeek else {
            return false
        }

        let freezeLog = ActivityLog(id: UUID(), date: Date(), type: .streakFreeze)
        activityLog.insert(freezeLog, at: 0)

        streakData = StreakData(
            currentStreak: streakData.currentStreak,
            longestStreak: streakData.longestStreak,
            lastActivityDate: Date(),
            streakFreezeAvailable: true,
            streakFreezeUsedThisWeek: true,
            missedYesterday: false
        )

        return true
    }

    func checkAndHandleMissedDay() {
        guard let lastDate = streakData.lastActivityDate else { return }

        let daysSinceLastActivity = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastDate), to: calendar.startOfDay(for: Date())).day ?? 0

        if daysSinceLastActivity >= 2 {
            streakData = StreakData(
                currentStreak: 0,
                longestStreak: streakData.longestStreak,
                lastActivityDate: streakData.lastActivityDate,
                streakFreezeAvailable: true,
                streakFreezeUsedThisWeek: streakData.streakFreezeUsedThisWeek,
                missedYesterday: true
            )
            finnEncouragementMessage = encouragementMessages.randomElement()
        } else if daysSinceLastActivity == 1 {
            finnEncouragementMessage = nil
        }
    }

    var hasActivityToday: Bool {
        guard let lastDate = streakData.lastActivityDate else { return false }
        return calendar.isDateInToday(lastDate)
    }

    var streakMilestonesReached: [StreakMilestone] {
        StreakMilestone.allCases.filter { streakData.currentStreak >= $0.rawValue || streakData.longestStreak >= $0.rawValue }
    }

    var nextMilestone: StreakMilestone? {
        StreakMilestone.allCases.first { $0.rawValue > streakData.currentStreak }
    }

    var daysToNextMilestone: Int? {
        guard let next = nextMilestone else { return nil }
        return next.rawValue - streakData.currentStreak
    }

    private func recalculateStreak() {
        let sorted = activityLog.sorted { $0.date > $1.date }
        guard !sorted.isEmpty else {
            streakData = StreakData(currentStreak: 0, longestStreak: streakData.longestStreak, lastActivityDate: nil, streakFreezeAvailable: true, streakFreezeUsedThisWeek: streakData.streakFreezeUsedThisWeek, missedYesterday: false)
            return
        }

        var streak = 1
        var checkDate = calendar.startOfDay(for: Date())

        let activityDates = Set(sorted.map { calendar.startOfDay(for: $0.date) })

        if !activityDates.contains(checkDate) {
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate), activityDates.contains(yesterday) {
                checkDate = yesterday
            } else {
                streakData = StreakData(currentStreak: 0, longestStreak: streakData.longestStreak, lastActivityDate: sorted.first?.date, streakFreezeAvailable: true, streakFreezeUsedThisWeek: streakData.streakFreezeUsedThisWeek, missedYesterday: true)
                return
            }
        }

        while let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) {
            if activityDates.contains(previousDay) {
                streak += 1
                checkDate = previousDay
            } else {
                break
            }
        }

        let newLongest = max(streak, streakData.longestStreak)
        streakData = StreakData(
            currentStreak: streak,
            longestStreak: newLongest,
            lastActivityDate: sorted.first?.date,
            streakFreezeAvailable: true,
            streakFreezeUsedThisWeek: streakData.streakFreezeUsedThisWeek,
            missedYesterday: false
        )
    }

    private func checkMilestones() {
        for milestone in StreakMilestone.allCases {
            if streakData.currentStreak == milestone.rawValue {
                NotificationService.shared.sendStreakMilestoneNotification(days: milestone.rawValue)
            }
        }
    }

    private let encouragementMessages: [String] = [
        "Hey, everyone needs a break sometimes. Your body recovers and comes back stronger. Jump back in today and let's keep building!",
        "Missing a day doesn't erase your progress. You've already proven you're committed. Let's get back on track!",
        "Rest is part of the process. The best athletes know when to recover. Ready to start a new streak?",
        "No judgment here — life happens. What matters is showing up today. You've got this!",
        "A streak is just a number. Your strength, consistency, and dedication are what really count. Let's go!",
    ]
}
