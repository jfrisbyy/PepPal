import Foundation

@Observable
final class StreakManager {
    static let shared = StreakManager()

    var streakData: StreakData
    var activityLog: [ActivityLog]
    var finnEncouragementMessage: String?

    private let calendar = Calendar.current
    private let freezeWindowDays: Int = 7
    private let pauseGraceHours: Int = 24

    private var logsLoaded: Bool = false
    private var midnightTimer: Timer?

    private init() {
        self.activityLog = []
        self.streakData = .empty
        scheduleMidnightCheck()
    }

    // MARK: - Loading

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

    // MARK: - Logging

    /// Logs a qualifying activity. Pass `at:` to backdate (e.g. yesterday) — used for repair.
    func logActivity(type: ActivityType, sport: Sport? = nil, durationMinutes: Int? = nil, at date: Date = Date()) {
        let log = ActivityLog(id: UUID(), date: date, type: type, sport: sport)
        activityLog.insert(log, at: 0)
        recalculateStreak()
        checkMilestones()
        persistActivityToSupabase(type: type, sport: sport, durationMinutes: durationMinutes, at: date)
    }

    private func persistActivityToSupabase(type: ActivityType, sport: Sport?, durationMinutes: Int?, at date: Date) {
        guard AuthService.shared.authState == .signedIn else { return }
        Task {
            do {
                let userId = try AuthService.shared.currentUserId()
                _ = try await StreakService.shared.logActivity(userId: userId, type: type, sport: sport, durationMinutes: durationMinutes, at: date)
            } catch {}
        }
    }

    // MARK: - State

    var hasActivityToday: Bool {
        guard let lastDate = streakData.lastActivityDate else { return false }
        return calendar.isDateInToday(lastDate)
    }

    var streakState: StreakState {
        if streakData.currentStreak == 0 && streakData.lastActivityDate == nil { return .dormant }
        if streakData.currentStreak == 0 { return .broken }
        if hasActivityToday { return .active }
        if let pausedUntil = streakData.pausedUntil, pausedUntil > Date() { return .paused }
        return .grace
    }

    var pausedHoursRemaining: Int? {
        guard let pausedUntil = streakData.pausedUntil, pausedUntil > Date() else { return nil }
        let seconds = pausedUntil.timeIntervalSinceNow
        return max(1, Int(ceil(seconds / 3600)))
    }

    var freezeAvailableInDays: Int? {
        guard let nextAt = streakData.freezeAvailableAgainAt, nextAt > Date() else { return nil }
        let days = calendar.dateComponents([.day], from: Date(), to: nextAt).day ?? 0
        return max(1, days)
    }

    var freezeRecentlyUsed: Bool {
        guard let usedAt = streakData.freezeUsedAt else { return false }
        return Date().timeIntervalSince(usedAt) < 60 * 60 * 36 // show note for 36h
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

    // MARK: - Recalculation

    /// The core recalculator. Walks the unified activity log, applies auto-freeze
    /// and paused state per the rules in PLAN.md.
    func recalculateStreak() {
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        // Carry forward freeze state from previous run
        let previousFreezeUsedAt = streakData.freezeUsedAt
        let previousLongest = streakData.longestStreak

        // Build set of "qualifying" days from real logs (exclude streakFreeze entries)
        let qualifyingDays = Set(activityLog
            .filter { $0.type != .streakFreeze }
            .map { calendar.startOfDay(for: $0.date) })

        guard !qualifyingDays.isEmpty else {
            streakData = StreakData(
                currentStreak: 0,
                longestStreak: previousLongest,
                lastActivityDate: nil,
                streakFreezeAvailable: true,
                freezeAvailableAgainAt: nil,
                freezeUsedAt: previousFreezeUsedAt,
                pausedUntil: nil,
                missedYesterday: false
            )
            return
        }

        // Determine the freeze "next available" anchor — most recent freeze use
        var freezeAvailableAgainAt: Date? = nil
        var freezeUsedAt: Date? = previousFreezeUsedAt
        if let usedAt = previousFreezeUsedAt,
           let availAt = calendar.date(byAdding: .day, value: freezeWindowDays, to: usedAt),
           availAt > Date() {
            freezeAvailableAgainAt = availAt
        }

        // Find the most recent qualifying day and walk backward
        let lastActivity = activityLog.filter { $0.type != .streakFreeze }.map(\.date).max()

        // Determine streak anchor day:
        // - if today logged → start at today
        // - else if yesterday logged → start at yesterday (still alive, will need today before midnight)
        // - else if 2 days ago logged → eligible for freeze auto-apply OR pause
        // - else → broken
        var anchor: Date
        var pausedUntil: Date? = nil
        var missedYesterday = false

        if qualifyingDays.contains(today) {
            anchor = today
        } else if qualifyingDays.contains(yesterday) {
            anchor = yesterday
        } else {
            // Missed yesterday. Try to apply auto-freeze.
            missedYesterday = true
            let freezeAvailable = freezeAvailableAgainAt == nil
            // We only auto-freeze if there exists a streak to protect (qualifying day exactly 2 days ago)
            let dayBeforeYesterday = calendar.date(byAdding: .day, value: -2, to: today)!
            if freezeAvailable && qualifyingDays.contains(dayBeforeYesterday) {
                // Apply freeze: anchor jumps over yesterday to day-before-yesterday
                anchor = dayBeforeYesterday
                freezeUsedAt = yesterday  // attribute freeze to the missed day
                if let availAt = calendar.date(byAdding: .day, value: freezeWindowDays, to: yesterday) {
                    freezeAvailableAgainAt = availAt
                }
                ensureFreezeLogExists(for: yesterday)
            } else if qualifyingDays.contains(dayBeforeYesterday) {
                // Freeze unavailable — enter paused state for 24h from now (or until end of today)
                anchor = dayBeforeYesterday
                pausedUntil = calendar.date(byAdding: .hour, value: pauseGraceHours, to: Date())
            } else {
                // Streak fully broken
                streakData = StreakData(
                    currentStreak: 0,
                    longestStreak: previousLongest,
                    lastActivityDate: lastActivity,
                    streakFreezeAvailable: freezeAvailableAgainAt == nil,
                    freezeAvailableAgainAt: freezeAvailableAgainAt,
                    freezeUsedAt: freezeUsedAt,
                    pausedUntil: nil,
                    missedYesterday: true
                )
                if previousLongest > 0 && finnEncouragementMessage == nil {
                    finnEncouragementMessage = encouragementMessages.randomElement()
                }
                return
            }
        }

        // Walk backward from anchor counting consecutive qualifying days,
        // allowing one freeze hop within the rolling 7-day window if not already used.
        var streak = 1
        var checkDate = anchor
        var freezeUsedDuringWalk: Bool = (freezeUsedAt != nil)

        while let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) {
            if qualifyingDays.contains(prev) {
                streak += 1
                checkDate = prev
                continue
            }
            // Missing day. Can we hop one with freeze?
            if !freezeUsedDuringWalk,
               let prev2 = calendar.date(byAdding: .day, value: -2, to: checkDate),
               qualifyingDays.contains(prev2) {
                // Use freeze for `prev`
                freezeUsedDuringWalk = true
                freezeUsedAt = prev
                if freezeAvailableAgainAt == nil,
                   let availAt = calendar.date(byAdding: .day, value: freezeWindowDays, to: prev),
                   availAt > Date() {
                    freezeAvailableAgainAt = availAt
                }
                ensureFreezeLogExists(for: prev)
                streak += 1 // freeze counts as a day
                checkDate = prev2
                streak += 1
                continue
            }
            break
        }

        let newLongest = max(streak, previousLongest)

        streakData = StreakData(
            currentStreak: streak,
            longestStreak: newLongest,
            lastActivityDate: lastActivity,
            streakFreezeAvailable: freezeAvailableAgainAt == nil,
            freezeAvailableAgainAt: freezeAvailableAgainAt,
            freezeUsedAt: freezeUsedAt,
            pausedUntil: pausedUntil,
            missedYesterday: missedYesterday
        )

        if streak > 0 { finnEncouragementMessage = nil }
    }

    private func ensureFreezeLogExists(for day: Date) {
        let dayStart = calendar.startOfDay(for: day)
        let exists = activityLog.contains {
            $0.type == .streakFreeze && calendar.isDate(calendar.startOfDay(for: $0.date), inSameDayAs: dayStart)
        }
        if !exists {
            activityLog.insert(ActivityLog(id: UUID(), date: day, type: .streakFreeze), at: 0)
        }
    }

    // MARK: - Midnight watcher

    private func scheduleMidnightCheck() {
        midnightTimer?.invalidate()
        let cal = Calendar.current
        let now = Date()
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) else { return }
        let interval = max(60, tomorrow.timeIntervalSince(now) + 5)
        midnightTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.recalculateStreak()
                self?.scheduleMidnightCheck()
            }
        }
    }

    func appBecameActive() {
        recalculateStreak()
        scheduleMidnightCheck()
    }

    private func checkMilestones() {
        for milestone in StreakMilestone.allCases {
            if streakData.currentStreak == milestone.rawValue {
                NotificationService.shared.sendStreakMilestoneNotification(days: milestone.rawValue)
            }
        }
    }

    // MARK: - Public legacy API (kept for compat)

    /// Kept for compatibility — auto-freeze runs in `recalculateStreak`. This is
    /// now a no-op return since freezes are automatic.
    @discardableResult
    func useStreakFreeze() -> Bool { false }

    func checkAndHandleMissedDay() { recalculateStreak() }

    // MARK: - Developer / QA helpers

    #if DEBUG
    func qa_simulateMissedDay(days: Int = 1) {
        let cal = Calendar.current
        // Shift all activity log dates back by N days so "today" looks N days stale
        activityLog = activityLog.map {
            ActivityLog(id: $0.id, date: cal.date(byAdding: .day, value: -days, to: $0.date) ?? $0.date, type: $0.type, sport: $0.sport)
        }
        recalculateStreak()
    }

    func qa_forcePaused() {
        let cal = Calendar.current
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: Date()) ?? Date()
        // Clear today + yesterday logs
        activityLog.removeAll { cal.isDateInToday($0.date) || cal.isDateInYesterday($0.date) }
        // Burn the freeze window so freeze isn't available
        let now = Date()
        streakData = StreakData(
            currentStreak: streakData.currentStreak,
            longestStreak: streakData.longestStreak,
            lastActivityDate: twoDaysAgo,
            streakFreezeAvailable: false,
            freezeAvailableAgainAt: cal.date(byAdding: .day, value: 6, to: now),
            freezeUsedAt: cal.date(byAdding: .day, value: -1, to: now),
            pausedUntil: nil,
            missedYesterday: true
        )
        recalculateStreak()
    }

    func qa_forceFreezeUsed() {
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        activityLog.removeAll { cal.isDateInYesterday($0.date) }
        ensureFreezeLogExists(for: yesterday)
        recalculateStreak()
    }

    func qa_resetStreak() {
        activityLog.removeAll()
        streakData = .empty
    }

    func qa_seedStreak(days: Int) {
        let cal = Calendar.current
        var logs: [ActivityLog] = []
        for i in 0..<days {
            if let d = cal.date(byAdding: .day, value: -i, to: Date()) {
                logs.append(ActivityLog(id: UUID(), date: d, type: .pin))
            }
        }
        activityLog = logs
        recalculateStreak()
    }
    #endif

    private let encouragementMessages: [String] = [
        "Hey, everyone needs a break sometimes. Your body recovers and comes back stronger. Jump back in today and let's keep building!",
        "Missing a day doesn't erase your progress. You've already proven you're committed. Let's get back on track!",
        "Rest is part of the process. The best athletes know when to recover. Ready to start a new streak?",
        "No judgment here — life happens. What matters is showing up today. You've got this!",
        "A streak is just a number. Your strength, consistency, and dedication are what really count. Let's go!",
    ]
}
