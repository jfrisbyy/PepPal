import SwiftUI

@Observable
final class TennisViewModel {
    static let shared = TennisViewModel()

    var matches: [TennisMatch] = []
    var selectedMatch: TennisMatch? = nil
    var showMatchDetail: Bool = false
    var showMatchLog: Bool = false
    var showLiveScorer: Bool = false
    var showDrillLibrary: Bool = false
    var showSettings: Bool = false
    var showWorkoutBuilder: Bool = false
    var savedTennisSessions: [CustomTennisSession] = []

    var selectedSessionType: TennisSessionType = .singlesMatch
    var matchFormat: TennisMatchFormat = .bestOf3
    var currentStats = TennisMatchStats()
    var matchResult: TennisMatchResult? = nil
    var opponentName: String = ""
    var matchDuration: Int = 60
    var performanceRating: Int = 5
    var confidenceRating: Int = 5
    var matchNotes: String = ""
    var logSets: [TennisSetScore] = [TennisSetScore()]

    var liveScore = TennisLiveScore()

    var regularOpponents: [String] {
        let names = matches.map(\.opponentName).filter { !$0.isEmpty }
        var seen = Set<String>()
        return names.filter { seen.insert($0.lowercased()).inserted }
    }

    init() {
        loadSampleData()
    }

    var gameMatches: [TennisMatch] {
        matches.filter { $0.sessionType.isMatch }
    }

    var totalMatchesPlayed: Int { gameMatches.count }

    var totalWins: Int { gameMatches.filter { $0.result == .win }.count }
    var totalLosses: Int { gameMatches.filter { $0.result == .loss }.count }

    var winPercentage: Double {
        guard totalMatchesPlayed > 0 else { return 0 }
        return Double(totalWins) / Double(totalMatchesPlayed) * 100
    }

    var averageFirstServePercentage: Double {
        let withServes = gameMatches.filter { $0.stats.firstServesTotal > 0 }
        guard !withServes.isEmpty else { return 0 }
        return withServes.reduce(0.0) { $0 + $1.stats.firstServePercentage } / Double(withServes.count)
    }

    var totalAces: Int { gameMatches.reduce(0) { $0 + $1.stats.aces } }
    var totalDoubleFaults: Int { gameMatches.reduce(0) { $0 + $1.stats.doubleFaults } }
    var totalWinners: Int { gameMatches.reduce(0) { $0 + $1.stats.winners } }
    var totalUnforcedErrors: Int { gameMatches.reduce(0) { $0 + $1.stats.unforcedErrors } }

    var averageAcesPerMatch: Double {
        guard !gameMatches.isEmpty else { return 0 }
        return Double(totalAces) / Double(gameMatches.count)
    }

    var averageDoubleFaultsPerMatch: Double {
        guard !gameMatches.isEmpty else { return 0 }
        return Double(totalDoubleFaults) / Double(gameMatches.count)
    }

    var averageWinners: Double {
        guard !gameMatches.isEmpty else { return 0 }
        return Double(totalWinners) / Double(gameMatches.count)
    }

    var averageUnforcedErrors: Double {
        guard !gameMatches.isEmpty else { return 0 }
        return Double(totalUnforcedErrors) / Double(gameMatches.count)
    }

    var thisWeekMatches: [TennisMatch] {
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

    var serveTrendData: [(date: Date, pct: Double)] {
        gameMatches
            .filter { $0.stats.firstServesTotal > 0 }
            .sorted { $0.date < $1.date }
            .suffix(10)
            .map { ($0.date, $0.stats.firstServePercentage) }
    }

    var headToHeadRecords: [(opponent: String, wins: Int, losses: Int)] {
        var records: [String: (wins: Int, losses: Int)] = [:]
        for match in gameMatches where !match.opponentName.isEmpty {
            let key = match.opponentName.lowercased()
            var record = records[key] ?? (0, 0)
            if match.result == .win { record.wins += 1 }
            else if match.result == .loss { record.losses += 1 }
            records[key] = record
        }
        return records.map { (opponent: $0.key.capitalized, wins: $0.value.wins, losses: $0.value.losses) }
            .sorted { ($0.wins + $0.losses) > ($1.wins + $1.losses) }
    }

    var shotDistribution: [(type: String, count: Int, color: Color)] {
        let total = gameMatches.reduce(into: (fh: 0, bh: 0, sv: 0, vo: 0)) { result, match in
            result.fh += match.stats.forehandsHit
            result.bh += match.stats.backhandsHit
            result.sv += match.stats.servesHit
            result.vo += match.stats.volleysHit
        }
        return [
            ("Forehand", total.fh, Color(red: 0.85, green: 0.9, blue: 0.15)),
            ("Backhand", total.bh, .green),
            ("Serve", total.sv, .blue),
            ("Volley", total.vo, .orange),
        ]
    }

    func logMatch() {
        let match = TennisMatch(
            date: Date(),
            sessionType: selectedSessionType,
            format: matchFormat,
            stats: currentStats,
            sets: logSets.filter { $0.playerGames + $0.opponentGames > 0 },
            result: selectedSessionType.isMatch ? matchResult : nil,
            opponentName: opponentName,
            durationMinutes: matchDuration,
            performanceRating: performanceRating,
            confidenceRating: confidenceRating,
            notes: matchNotes
        )
        matches.insert(match, at: 0)
        resetLogForm()
    }

    func logFromLiveScore() {
        let match = TennisMatch(
            date: Date(),
            sessionType: selectedSessionType,
            format: liveScore.format,
            stats: currentStats,
            sets: liveScore.sets,
            result: liveScore.computedPlayerSetsWon > liveScore.computedOpponentSetsWon ? .win : .loss,
            opponentName: opponentName,
            durationMinutes: matchDuration,
            performanceRating: performanceRating,
            confidenceRating: confidenceRating,
            notes: matchNotes
        )
        matches.insert(match, at: 0)
        resetLogForm()
        resetLiveScore()
    }

    func resetLogForm() {
        selectedSessionType = .singlesMatch
        matchFormat = .bestOf3
        currentStats = TennisMatchStats()
        matchResult = nil
        opponentName = ""
        matchDuration = 60
        performanceRating = 5
        confidenceRating = 5
        matchNotes = ""
        logSets = [TennisSetScore()]
    }

    func resetLiveScore() {
        liveScore = TennisLiveScore()
        liveScore.format = matchFormat
    }

    func startLiveMatch() {
        liveScore = TennisLiveScore()
        liveScore.format = matchFormat
    }

    func addLogSet() {
        logSets.append(TennisSetScore())
    }

    func removeLastLogSet() {
        guard logSets.count > 1 else { return }
        logSets.removeLast()
    }

    private func loadSampleData() {
        let cal = Calendar.current
        let now = Date()

        matches = [
            TennisMatch(
                date: cal.date(byAdding: .day, value: -1, to: now)!,
                sessionType: .singlesMatch,
                format: .bestOf3,
                stats: TennisMatchStats(aces: 5, doubleFaults: 2, firstServesIn: 28, firstServesTotal: 42, winners: 18, unforcedErrors: 12, forehandsHit: 65, backhandsHit: 48, servesHit: 42, volleysHit: 8, breakPointsConverted: 3, breakPointsTotal: 5),
                sets: [TennisSetScore(playerGames: 6, opponentGames: 4), TennisSetScore(playerGames: 7, opponentGames: 5)],
                result: .win,
                opponentName: "Alex",
                durationMinutes: 95,
                performanceRating: 8,
                confidenceRating: 8
            ),
            TennisMatch(
                date: cal.date(byAdding: .day, value: -4, to: now)!,
                sessionType: .singlesMatch,
                format: .bestOf3,
                stats: TennisMatchStats(aces: 3, doubleFaults: 4, firstServesIn: 22, firstServesTotal: 40, winners: 14, unforcedErrors: 20, forehandsHit: 58, backhandsHit: 52, servesHit: 40, volleysHit: 5, breakPointsConverted: 1, breakPointsTotal: 4),
                sets: [TennisSetScore(playerGames: 4, opponentGames: 6), TennisSetScore(playerGames: 6, opponentGames: 7, tiebreakPlayerPoints: 5, tiebreakOpponentPoints: 7)],
                result: .loss,
                opponentName: "Jordan",
                durationMinutes: 110,
                performanceRating: 5,
                confidenceRating: 5
            ),
            TennisMatch(
                date: cal.date(byAdding: .day, value: -6, to: now)!,
                sessionType: .hittingSession,
                format: .bestOf3,
                stats: TennisMatchStats(forehandsHit: 120, backhandsHit: 80, servesHit: 50, volleysHit: 20),
                opponentName: "Coach Mike",
                durationMinutes: 60,
                performanceRating: 7,
                confidenceRating: 7
            ),
            TennisMatch(
                date: cal.date(byAdding: .day, value: -8, to: now)!,
                sessionType: .singlesMatch,
                format: .bestOf3,
                stats: TennisMatchStats(aces: 7, doubleFaults: 1, firstServesIn: 32, firstServesTotal: 45, winners: 22, unforcedErrors: 10, forehandsHit: 70, backhandsHit: 45, servesHit: 45, volleysHit: 12, breakPointsConverted: 4, breakPointsTotal: 6),
                sets: [TennisSetScore(playerGames: 6, opponentGames: 2), TennisSetScore(playerGames: 6, opponentGames: 3)],
                result: .win,
                opponentName: "Alex",
                durationMinutes: 75,
                performanceRating: 9,
                confidenceRating: 9
            ),
            TennisMatch(
                date: cal.date(byAdding: .day, value: -12, to: now)!,
                sessionType: .singlesMatch,
                format: .bestOf3,
                stats: TennisMatchStats(aces: 4, doubleFaults: 3, firstServesIn: 25, firstServesTotal: 38, winners: 16, unforcedErrors: 15, forehandsHit: 55, backhandsHit: 50, servesHit: 38, volleysHit: 6, breakPointsConverted: 2, breakPointsTotal: 3),
                sets: [TennisSetScore(playerGames: 6, opponentGames: 3), TennisSetScore(playerGames: 3, opponentGames: 6), TennisSetScore(playerGames: 7, opponentGames: 6, tiebreakPlayerPoints: 7, tiebreakOpponentPoints: 4)],
                result: .win,
                opponentName: "Sam",
                durationMinutes: 135,
                performanceRating: 7,
                confidenceRating: 6
            ),
        ]
    }
}
