import SwiftUI

@Observable
final class SoccerViewModel {
    static let shared = SoccerViewModel()

    var matches: [SoccerMatch] = []
    var primaryPosition: SoccerPosition = .centralMid
    var selectedMatch: SoccerMatch? = nil
    var showMatchDetail: Bool = false
    var showGameLog: Bool = false
    var showDrillLibrary: Bool = false
    var showSettings: Bool = false
    var showWorkoutBuilder: Bool = false
    var savedSoccerSessions: [CustomSoccerSession] = []
    var selectedDrill: SoccerDrill? = nil
    var showDrillDetail: Bool = false
    var drillCompletions: [UUID: Int] = [:]

    var selectedSessionType: SoccerSessionType = .game
    var currentStats = SoccerGameStats()
    var matchResult: SoccerMatchResult? = nil
    var teamScore: Int = 0
    var opponentScore: Int = 0
    var matchDuration: Int = 90
    var matchPosition: SoccerPosition = .centralMid
    var distanceKm: Double = 0
    var sprintCount: Int = 0
    var topSpeedKmh: Double = 0
    var performanceRating: Int = 5
    var confidenceRating: Int = 5
    var matchNotes: String = ""

    init() {
        matchPosition = primaryPosition
        loadSampleData()
    }

    var gameMatches: [SoccerMatch] {
        matches.filter { $0.sessionType.isGame }
    }

    var totalGamesPlayed: Int { gameMatches.count }

    var totalWins: Int { gameMatches.filter { $0.result == .win }.count }
    var totalDraws: Int { gameMatches.filter { $0.result == .draw }.count }
    var totalLosses: Int { gameMatches.filter { $0.result == .loss }.count }

    var winPercentage: Double {
        guard totalGamesPlayed > 0 else { return 0 }
        return Double(totalWins) / Double(totalGamesPlayed) * 100
    }

    var averageGoals: Double {
        guard !gameMatches.isEmpty else { return 0 }
        return Double(gameMatches.reduce(0) { $0 + $1.stats.goals }) / Double(gameMatches.count)
    }

    var averageAssists: Double {
        guard !gameMatches.isEmpty else { return 0 }
        return Double(gameMatches.reduce(0) { $0 + $1.stats.assists }) / Double(gameMatches.count)
    }

    var averageDistance: Double {
        let withDist = matches.filter { $0.distanceKm > 0 }
        guard !withDist.isEmpty else { return 0 }
        return withDist.reduce(0.0) { $0 + $1.distanceKm } / Double(withDist.count)
    }

    var totalGoals: Int { gameMatches.reduce(0) { $0 + $1.stats.goals } }
    var totalAssists: Int { gameMatches.reduce(0) { $0 + $1.stats.assists } }
    var totalGoalContributions: Int { totalGoals + totalAssists }

    var averageRating: Double {
        guard !matches.isEmpty else { return 0 }
        return Double(matches.reduce(0) { $0 + $1.performanceRating }) / Double(matches.count)
    }

    var thisWeekMatches: [SoccerMatch] {
        let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return matches.filter { $0.date >= weekStart }
    }

    var thisWeekSessions: Int { thisWeekMatches.count }

    var formData: [(date: Date, rating: Int)] {
        gameMatches
            .sorted { $0.date < $1.date }
            .suffix(10)
            .map { ($0.date, $0.performanceRating) }
    }

    var goalsTrendData: [(date: Date, goals: Int)] {
        gameMatches
            .sorted { $0.date < $1.date }
            .suffix(10)
            .map { ($0.date, $0.stats.goals) }
    }

    var positionDashboardStats: [(label: String, value: String, color: Color)] {
        if primaryPosition.isAttacker || primaryPosition == .attackingMid {
            return attackerStats
        } else if primaryPosition.isDefender {
            return defenderStats
        } else {
            return midfielderStats
        }
    }

    private var attackerStats: [(label: String, value: String, color: Color)] {
        let avgShots = gameMatches.isEmpty ? 0 : Double(gameMatches.reduce(0) { $0 + $1.stats.totalShots }) / Double(gameMatches.count)
        let avgShotAcc = gameMatches.isEmpty ? 0 : gameMatches.reduce(0.0) { $0 + $1.stats.shotAccuracy } / Double(gameMatches.count)
        return [
            ("Goals/G", String(format: "%.1f", averageGoals), .green),
            ("Shots/G", String(format: "%.1f", avgShots), .orange),
            ("Shot Acc", String(format: "%.0f%%", avgShotAcc), .blue),
        ]
    }

    private var defenderStats: [(label: String, value: String, color: Color)] {
        let avgTackles = gameMatches.isEmpty ? 0 : Double(gameMatches.reduce(0) { $0 + $1.stats.tacklesWon }) / Double(gameMatches.count)
        let avgInterceptions = gameMatches.isEmpty ? 0 : Double(gameMatches.reduce(0) { $0 + $1.stats.interceptions }) / Double(gameMatches.count)
        let avgTackleRate = gameMatches.isEmpty ? 0 : gameMatches.reduce(0.0) { $0 + $1.stats.tackleSuccessRate } / Double(gameMatches.count)
        return [
            ("Tackles/G", String(format: "%.1f", avgTackles), .red),
            ("INT/G", String(format: "%.1f", avgInterceptions), .blue),
            ("Tackle %", String(format: "%.0f%%", avgTackleRate), .green),
        ]
    }

    private var midfielderStats: [(label: String, value: String, color: Color)] {
        let avgKeyPasses = gameMatches.isEmpty ? 0 : Double(gameMatches.reduce(0) { $0 + $1.stats.keyPasses }) / Double(gameMatches.count)
        let avgDist = averageDistance
        return [
            ("Assists/G", String(format: "%.1f", averageAssists), .green),
            ("Key Pass/G", String(format: "%.1f", avgKeyPasses), .blue),
            ("Avg Dist", String(format: "%.1f km", avgDist), .orange),
        ]
    }

    func logMatch() {
        let match = SoccerMatch(
            date: Date(),
            sessionType: selectedSessionType,
            position: matchPosition,
            stats: currentStats,
            result: selectedSessionType.isGame ? matchResult : nil,
            teamScore: selectedSessionType.isGame ? teamScore : nil,
            opponentScore: selectedSessionType.isGame ? opponentScore : nil,
            durationMinutes: matchDuration,
            distanceKm: distanceKm,
            sprintCount: sprintCount,
            topSpeedKmh: topSpeedKmh,
            performanceRating: performanceRating,
            confidenceRating: confidenceRating,
            notes: matchNotes
        )
        matches.insert(match, at: 0)
        resetLogForm()
    }

    func resetLogForm() {
        selectedSessionType = .game
        currentStats = SoccerGameStats()
        matchResult = nil
        teamScore = 0
        opponentScore = 0
        matchDuration = 90
        matchPosition = primaryPosition
        distanceKm = 0
        sprintCount = 0
        topSpeedKmh = 0
        performanceRating = 5
        confidenceRating = 5
        matchNotes = ""
    }

    private func loadSampleData() {
        let cal = Calendar.current
        let now = Date()

        matches = [
            SoccerMatch(
                date: cal.date(byAdding: .day, value: -1, to: now)!,
                sessionType: .game,
                position: .centralMid,
                stats: SoccerGameStats(goals: 1, assists: 2, shotsOnTarget: 3, shotsOffTarget: 1, keyPasses: 4, tacklesWon: 3, tacklesLost: 1, interceptions: 2, foulsCommitted: 1, foulsWon: 2, yellowCards: 0, redCards: 0, minutesPlayed: 90),
                result: .win,
                teamScore: 3,
                opponentScore: 1,
                durationMinutes: 90,
                distanceKm: 10.2,
                sprintCount: 18,
                topSpeedKmh: 28.5,
                performanceRating: 8,
                confidenceRating: 8
            ),
            SoccerMatch(
                date: cal.date(byAdding: .day, value: -4, to: now)!,
                sessionType: .game,
                position: .centralMid,
                stats: SoccerGameStats(goals: 0, assists: 1, shotsOnTarget: 2, shotsOffTarget: 2, keyPasses: 3, tacklesWon: 4, tacklesLost: 2, interceptions: 3, foulsCommitted: 2, foulsWon: 1, yellowCards: 1, redCards: 0, minutesPlayed: 85),
                result: .draw,
                teamScore: 1,
                opponentScore: 1,
                durationMinutes: 90,
                distanceKm: 9.8,
                sprintCount: 15,
                topSpeedKmh: 27.2,
                performanceRating: 6,
                confidenceRating: 6
            ),
            SoccerMatch(
                date: cal.date(byAdding: .day, value: -7, to: now)!,
                sessionType: .pickupGame,
                position: .striker,
                stats: SoccerGameStats(goals: 3, assists: 0, shotsOnTarget: 5, shotsOffTarget: 2, keyPasses: 1, tacklesWon: 1, tacklesLost: 0, interceptions: 0, foulsCommitted: 0, foulsWon: 3, yellowCards: 0, redCards: 0, minutesPlayed: 60),
                result: .win,
                teamScore: 5,
                opponentScore: 2,
                durationMinutes: 60,
                distanceKm: 6.5,
                sprintCount: 12,
                topSpeedKmh: 30.1,
                performanceRating: 9,
                confidenceRating: 9
            ),
            SoccerMatch(
                date: cal.date(byAdding: .day, value: -10, to: now)!,
                sessionType: .game,
                position: .centralMid,
                stats: SoccerGameStats(goals: 0, assists: 0, shotsOnTarget: 1, shotsOffTarget: 3, keyPasses: 2, tacklesWon: 2, tacklesLost: 3, interceptions: 1, foulsCommitted: 3, foulsWon: 0, yellowCards: 1, redCards: 0, minutesPlayed: 78),
                result: .loss,
                teamScore: 0,
                opponentScore: 2,
                durationMinutes: 90,
                distanceKm: 8.9,
                sprintCount: 10,
                topSpeedKmh: 26.8,
                performanceRating: 4,
                confidenceRating: 4
            ),
            SoccerMatch(
                date: cal.date(byAdding: .day, value: -3, to: now)!,
                sessionType: .soloTraining,
                position: .centralMid,
                stats: SoccerGameStats(),
                durationMinutes: 60,
                distanceKm: 4.0,
                sprintCount: 8,
                topSpeedKmh: 25.0,
                performanceRating: 7,
                confidenceRating: 7
            ),
        ]
    }
}
