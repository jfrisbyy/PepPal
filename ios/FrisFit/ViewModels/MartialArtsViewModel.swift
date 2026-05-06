import SwiftUI

@Observable
final class MartialArtsViewModel {
    static let shared = MartialArtsViewModel()

    // MARK: - Stored state

    var sessions: [MartialArtsSession] = []
    var primaryDiscipline: MartialArtsDiscipline = .bjj
    var trainedDisciplines: Set<MartialArtsDiscipline> = [.bjj]
    var rank: String = "White"
    var stripes: Int = 0
    var gymName: String = ""
    var coachName: String = ""

    var selectedSession: MartialArtsSession? = nil
    var selectedDrill: MartialArtsDrill? = nil

    // Sheet / nav flags
    var showSessionDetail: Bool = false
    var showSessionLog: Bool = false
    var showDrillLibrary: Bool = false
    var showSettings: Bool = false
    var showWorkoutBuilder: Bool = false
    var showDisciplinePicker: Bool = false

    var savedSessions: [CustomMartialArtsSession] = []

    // Log form state
    var logDiscipline: MartialArtsDiscipline = .bjj
    var logSessionType: MartialArtsSessionType = .classSession
    var logDuration: Int = 60
    var logIntensity: Int = 6
    var logEnergyRating: Int = 5
    var logTechniqueRating: Int = 5
    var logCardioRating: Int = 5
    var logOpponent: String = ""
    var logCoach: String = ""
    var logGym: String = ""
    var logOutcome: MartialArtsOutcome? = nil
    var logTechniquesText: String = ""
    var logNotes: String = ""
    var logStats = MartialArtsSessionStats()

    init() {
        logDiscipline = primaryDiscipline
        loadSampleData()
    }

    // MARK: - Derived stats

    var totalSessions: Int { sessions.count }

    var thisWeekSessions: [MartialArtsSession] {
        let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return sessions.filter { $0.date >= weekStart }
    }

    var totalRoundsLogged: Int { sessions.reduce(0) { $0 + $1.stats.roundsCompleted } }
    var totalMatTime: Int { sessions.reduce(0) { $0 + $1.durationMinutes } }
    var totalLiveSessions: Int { sessions.filter { $0.sessionType.isLive }.count }

    var competitions: [MartialArtsSession] {
        sessions.filter { $0.sessionType == .competition }
    }
    var competitionWins: Int { competitions.filter { $0.outcome == .win }.count }
    var competitionLosses: Int { competitions.filter { $0.outcome == .loss }.count }

    var winPercentage: Double {
        let total = competitionWins + competitionLosses
        guard total > 0 else { return 0 }
        return Double(competitionWins) / Double(total) * 100
    }

    var totalSubmissionsLanded: Int { sessions.reduce(0) { $0 + $1.stats.submissionsLanded } }
    var totalSubsReceived: Int { sessions.reduce(0) { $0 + $1.stats.tapsReceived } }
    var subRatio: Double {
        let received = max(totalSubsReceived, 1)
        return Double(totalSubmissionsLanded) / Double(received)
    }

    var totalTakedownsLanded: Int { sessions.reduce(0) { $0 + $1.stats.takedownsLanded } }
    var totalTakedownsAttempted: Int { sessions.reduce(0) { $0 + $1.stats.takedownsAttempted } }
    var takedownPercentage: Double {
        guard totalTakedownsAttempted > 0 else { return 0 }
        return Double(totalTakedownsLanded) / Double(totalTakedownsAttempted)
    }

    var totalStrikes: Int { sessions.reduce(0) { $0 + $1.stats.totalStrikes } }
    var averageStrikesPerSession: Double {
        let striking = sessions.filter { $0.stats.totalStrikes > 0 }
        guard !striking.isEmpty else { return 0 }
        return Double(totalStrikes) / Double(striking.count)
    }

    /// Streak of consecutive days with at least one session, ending today/yesterday.
    var currentStreak: Int {
        let cal = Calendar.current
        let dayKeys = Set(sessions.map { cal.startOfDay(for: $0.date) })
        var streak = 0
        var cursor = cal.startOfDay(for: Date())
        // Allow "missed today, but trained yesterday" to still count.
        if !dayKeys.contains(cursor) {
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
            if !dayKeys.contains(cursor) { return 0 }
        }
        while dayKeys.contains(cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    var formData: [(date: Date, rating: Int)] {
        sessions
            .sorted { $0.date < $1.date }
            .suffix(10)
            .map { ($0.date, ($0.energyRating + $0.techniqueRating + $0.cardioRating) / 3) }
    }

    var disciplineBreakdown: [(discipline: MartialArtsDiscipline, sessions: Int, minutes: Int)] {
        var bucket: [MartialArtsDiscipline: (sessions: Int, minutes: Int)] = [:]
        for session in sessions {
            var entry = bucket[session.discipline] ?? (0, 0)
            entry.sessions += 1
            entry.minutes += session.durationMinutes
            bucket[session.discipline] = entry
        }
        return bucket
            .map { (discipline: $0.key, sessions: $0.value.sessions, minutes: $0.value.minutes) }
            .sorted { $0.minutes > $1.minutes }
    }

    var trainingPartners: [(name: String, sessions: Int)] {
        var bucket: [String: Int] = [:]
        for session in sessions where !session.opponentName.isEmpty {
            bucket[session.opponentName, default: 0] += 1
        }
        return bucket
            .map { (name: $0.key, sessions: $0.value) }
            .sorted { $0.sessions > $1.sessions }
    }

    /// Last 12 weeks day-by-day session counts (most recent week last).
    var twelveWeekHeatmap: [[Int]] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dayKeys: [Date: Int] = sessions.reduce(into: [:]) { acc, s in
            acc[cal.startOfDay(for: s.date), default: 0] += 1
        }
        var weeks: [[Int]] = []
        for weekOffset in (0..<12).reversed() {
            var week: [Int] = []
            for dayOffset in 0..<7 {
                let date = cal.date(byAdding: .day, value: -(weekOffset * 7 + (6 - dayOffset)), to: today) ?? today
                week.append(dayKeys[cal.startOfDay(for: date)] ?? 0)
            }
            weeks.append(week)
        }
        return weeks
    }

    // MARK: - Logging

    func logSession() {
        let techniques = logTechniquesText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let session = MartialArtsSession(
            date: Date(),
            discipline: logDiscipline,
            sessionType: logSessionType,
            durationMinutes: logDuration,
            stats: logStats,
            outcome: logSessionType.isCompetitive ? logOutcome : nil,
            opponentName: logOpponent,
            coachName: logCoach.isEmpty ? coachName : logCoach,
            gymName: logGym.isEmpty ? gymName : logGym,
            energyRating: logEnergyRating,
            techniqueRating: logTechniqueRating,
            cardioRating: logCardioRating,
            intensity: logIntensity,
            techniquesWorked: techniques,
            notes: logNotes
        )
        sessions.insert(session, at: 0)
        trainedDisciplines.insert(logDiscipline)
        resetLogForm()
    }

    func resetLogForm() {
        logDiscipline = primaryDiscipline
        logSessionType = .classSession
        logDuration = 60
        logIntensity = 6
        logEnergyRating = 5
        logTechniqueRating = 5
        logCardioRating = 5
        logOpponent = ""
        logCoach = ""
        logGym = ""
        logOutcome = nil
        logTechniquesText = ""
        logNotes = ""
        logStats = MartialArtsSessionStats()
    }

    // MARK: - Sample data

    private func loadSampleData() {
        let cal = Calendar.current
        let now = Date()

        gymName = "Iron Hill Academy"
        coachName = "Coach Diaz"
        primaryDiscipline = .bjj
        rank = "Blue"
        stripes = 2
        trainedDisciplines = [.bjj, .muayThai, .mma]

        sessions = [
            MartialArtsSession(
                date: cal.date(byAdding: .day, value: -1, to: now)!,
                discipline: .bjj,
                sessionType: .rolling,
                durationMinutes: 75,
                stats: MartialArtsSessionStats(
                    takedownsAttempted: 4, takedownsLanded: 2,
                    sweepsLanded: 3, passesLanded: 4,
                    submissionsAttempted: 6, submissionsLanded: 3, submissionsDefended: 5,
                    tapsGiven: 3, tapsReceived: 2,
                    roundsCompleted: 6, roundDurationSeconds: 300
                ),
                opponentName: "Marco",
                coachName: "Coach Diaz",
                gymName: "Iron Hill Academy",
                energyRating: 8, techniqueRating: 8, cardioRating: 7,
                intensity: 8,
                techniquesWorked: ["Triangle from guard", "Knee cut pass"],
                notes: "Tagged the triangle off the cross-grip. Cardio held in round 6."
            ),
            MartialArtsSession(
                date: cal.date(byAdding: .day, value: -2, to: now)!,
                discipline: .muayThai,
                sessionType: .padwork,
                durationMinutes: 60,
                stats: MartialArtsSessionStats(
                    jabs: 60, crosses: 50, hooks: 30,
                    lowKicks: 24, bodyKicks: 18, headKicks: 6, knees: 12,
                    roundsCompleted: 5
                ),
                gymName: "Iron Hill Academy",
                energyRating: 7, techniqueRating: 8, cardioRating: 6,
                intensity: 8,
                techniquesWorked: ["Switch kick", "Teep recovery"]
            ),
            MartialArtsSession(
                date: cal.date(byAdding: .day, value: -3, to: now)!,
                discipline: .bjj,
                sessionType: .drilling,
                durationMinutes: 45,
                stats: MartialArtsSessionStats(),
                gymName: "Iron Hill Academy",
                energyRating: 6, techniqueRating: 7, cardioRating: 5,
                intensity: 5,
                techniquesWorked: ["Hip escape ladder", "Guard retention"]
            ),
            MartialArtsSession(
                date: cal.date(byAdding: .day, value: -5, to: now)!,
                discipline: .mma,
                sessionType: .sparring,
                durationMinutes: 60,
                stats: MartialArtsSessionStats(
                    jabs: 30, crosses: 24, hooks: 12,
                    lowKicks: 8,
                    takedownsAttempted: 3, takedownsLanded: 2,
                    submissionsAttempted: 1, submissionsLanded: 0,
                    tapsGiven: 0, tapsReceived: 1,
                    roundsCompleted: 4
                ),
                opponentName: "Tomas",
                coachName: "Coach Diaz",
                gymName: "Iron Hill Academy",
                energyRating: 6, techniqueRating: 6, cardioRating: 5,
                intensity: 9,
                notes: "Rounds 3-4 felt rough. Need more pace work."
            ),
            MartialArtsSession(
                date: cal.date(byAdding: .day, value: -7, to: now)!,
                discipline: .bjj,
                sessionType: .competition,
                durationMinutes: 30,
                stats: MartialArtsSessionStats(
                    sweepsLanded: 1, passesLanded: 2,
                    submissionsAttempted: 2, submissionsLanded: 1,
                    roundsCompleted: 2, roundDurationSeconds: 360
                ),
                outcome: .win,
                opponentName: "Open Division",
                gymName: "City Open BJJ",
                energyRating: 9, techniqueRating: 8, cardioRating: 7,
                intensity: 10,
                notes: "Gold in absolute. Triangle finish in the second match."
            ),
            MartialArtsSession(
                date: cal.date(byAdding: .day, value: -9, to: now)!,
                discipline: .boxing,
                sessionType: .bagwork,
                durationMinutes: 45,
                stats: MartialArtsSessionStats(
                    jabs: 80, crosses: 60, hooks: 40, uppercuts: 20,
                    roundsCompleted: 6
                ),
                gymName: "Iron Hill Academy",
                energyRating: 7, techniqueRating: 7, cardioRating: 8,
                intensity: 7
            ),
            MartialArtsSession(
                date: cal.date(byAdding: .day, value: -11, to: now)!,
                discipline: .bjj,
                sessionType: .openMat,
                durationMinutes: 90,
                stats: MartialArtsSessionStats(
                    submissionsAttempted: 5, submissionsLanded: 2,
                    tapsGiven: 2, tapsReceived: 4,
                    roundsCompleted: 8, roundDurationSeconds: 360
                ),
                gymName: "Iron Hill Academy",
                energyRating: 7, techniqueRating: 7, cardioRating: 7,
                intensity: 7
            )
        ]
    }
}
