import SwiftUI

@Observable
final class PickleballViewModel {
    static let shared = PickleballViewModel()

    // MARK: - Stored state

    var matches: [PickleballMatch] = []
    var preferredFormat: PickleballFormat = .doubles
    var preferredSide: PickleballSide = .right
    var dupr: Double = 0.0
    var partnerName: String = ""
    var selectedMatch: PickleballMatch? = nil
    var selectedDrill: PickleballDrill? = nil

    // Sheet / nav flags
    var showMatchDetail: Bool = false
    var showMatchLog: Bool = false
    var showDrillLibrary: Bool = false
    var showDrillDetail: Bool = false
    var showSettings: Bool = false
    var showWorkoutBuilder: Bool = false

    var savedSessions: [CustomPickleballSession] = []
    var drillCompletions: [UUID: Int] = [:]

    // Log form state
    var selectedSessionType: PickleballSessionType = .match
    var matchFormat: PickleballFormat = .doubles
    var matchSide: PickleballSide = .right
    var currentStats = PickleballMatchStats()
    var matchResult: PickleballMatchResult? = nil
    var opponentName: String = ""
    var venue: String = ""
    var matchPartner: String = ""
    var matchDuration: Int = 60
    var energyRating: Int = 5
    var footworkRating: Int = 5
    var confidenceRating: Int = 5
    var matchDUPRInput: String = ""
    var matchNotes: String = ""
    var logGames: [PickleballGameScore] = [PickleballGameScore()]

    init() {
        matchFormat = preferredFormat
        matchSide = preferredSide
        loadSampleData()
    }

    // MARK: - Derived stats

    var gameMatches: [PickleballMatch] {
        matches.filter { $0.sessionType.isMatch }
    }

    var totalMatchesPlayed: Int { gameMatches.count }
    var totalWins: Int { gameMatches.filter { $0.result == .win }.count }
    var totalLosses: Int { gameMatches.filter { $0.result == .loss }.count }

    var winPercentage: Double {
        guard totalMatchesPlayed > 0 else { return 0 }
        return Double(totalWins) / Double(totalMatchesPlayed) * 100
    }

    var totalWinners: Int { gameMatches.reduce(0) { $0 + $1.stats.winners } }
    var totalUnforcedErrors: Int { gameMatches.reduce(0) { $0 + $1.stats.unforcedErrors } }
    var totalAces: Int { gameMatches.reduce(0) { $0 + $1.stats.aces } }
    var totalDinkExchanges: Int {
        gameMatches.reduce(0) { $0 + $1.stats.dinksWon + $1.stats.dinksLost }
    }

    var averageWinnersPerMatch: Double {
        guard !gameMatches.isEmpty else { return 0 }
        return Double(totalWinners) / Double(gameMatches.count)
    }

    var averageErrorsPerMatch: Double {
        guard !gameMatches.isEmpty else { return 0 }
        return Double(totalUnforcedErrors) / Double(gameMatches.count)
    }

    var averageWinnerErrorRatio: Double {
        let withSwings = gameMatches.filter { $0.stats.winners + $0.stats.unforcedErrors > 0 }
        guard !withSwings.isEmpty else { return 0 }
        return withSwings.reduce(0.0) { $0 + $1.stats.winnerToErrorRatio } / Double(withSwings.count)
    }

    var averageThirdShotDropPercentage: Double {
        let withDrops = gameMatches.filter { $0.stats.thirdShotDropsAttempted > 0 }
        guard !withDrops.isEmpty else { return 0 }
        return withDrops.reduce(0.0) { $0 + $1.stats.thirdShotDropPercentage } / Double(withDrops.count)
    }

    var averageDinkWinPercentage: Double {
        let withDinks = gameMatches.filter { $0.stats.dinksWon + $0.stats.dinksLost > 0 }
        guard !withDinks.isEmpty else { return 0 }
        return withDinks.reduce(0.0) { $0 + $1.stats.dinkWinPercentage } / Double(withDinks.count)
    }

    var averageFirstServePercentage: Double {
        let withServes = gameMatches.filter { $0.stats.firstServeAttempts > 0 }
        guard !withServes.isEmpty else { return 0 }
        return withServes.reduce(0.0) { $0 + $1.stats.firstServePercentage } / Double(withServes.count)
    }

    var thisWeekMatches: [PickleballMatch] {
        let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return matches.filter { $0.date >= weekStart }
    }

    var thisWeekSessions: Int { thisWeekMatches.count }

    var formData: [(date: Date, rating: Int)] {
        gameMatches
            .sorted { $0.date < $1.date }
            .suffix(10)
            .map { ($0.date, ($0.energyRating + $0.footworkRating + $0.confidenceRating) / 3) }
    }

    var winnersTrend: [(date: Date, winners: Int)] {
        gameMatches
            .sorted { $0.date < $1.date }
            .suffix(10)
            .map { ($0.date, $0.stats.winners) }
    }

    var rivals: [(opponent: String, wins: Int, losses: Int)] {
        var records: [String: (wins: Int, losses: Int)] = [:]
        for match in gameMatches where !match.opponentName.isEmpty {
            let key = match.opponentName.lowercased()
            var record = records[key] ?? (0, 0)
            if match.result == .win { record.wins += 1 }
            if match.result == .loss { record.losses += 1 }
            records[key] = record
        }
        return records
            .map { (opponent: $0.key.capitalized, wins: $0.value.wins, losses: $0.value.losses) }
            .sorted { ($0.wins + $0.losses) > ($1.wins + $1.losses) }
    }

    var partners: [(name: String, sessions: Int, wins: Int)] {
        var records: [String: (sessions: Int, wins: Int)] = [:]
        for match in gameMatches where !match.partnerName.isEmpty {
            let key = match.partnerName
            var record = records[key] ?? (0, 0)
            record.sessions += 1
            if match.result == .win { record.wins += 1 }
            records[key] = record
        }
        return records
            .map { (name: $0.key, sessions: $0.value.sessions, wins: $0.value.wins) }
            .sorted { $0.sessions > $1.sessions }
    }

    // MARK: - Logging

    func logMatch() {
        let usedGames = logGames.filter { $0.totalPoints > 0 }
        let resolvedResult: PickleballMatchResult? = {
            if let r = matchResult { return r }
            guard !usedGames.isEmpty, selectedSessionType.isMatch else { return nil }
            let won = usedGames.filter(\.teamWon).count
            return won * 2 > usedGames.count ? .win : .loss
        }()

        let parsedDUPR = Double(matchDUPRInput.trimmingCharacters(in: .whitespaces))

        let match = PickleballMatch(
            date: Date(),
            sessionType: selectedSessionType,
            format: matchFormat,
            side: matchSide,
            stats: currentStats,
            games: usedGames,
            result: selectedSessionType.isMatch ? resolvedResult : nil,
            opponentName: opponentName,
            partnerName: matchPartner,
            venue: venue,
            durationMinutes: matchDuration,
            energyRating: energyRating,
            footworkRating: footworkRating,
            confidenceRating: confidenceRating,
            dupr: parsedDUPR,
            notes: matchNotes
        )
        matches.insert(match, at: 0)
        if let parsedDUPR { dupr = parsedDUPR }
        resetLogForm()
    }

    func resetLogForm() {
        selectedSessionType = .match
        matchFormat = preferredFormat
        matchSide = preferredSide
        currentStats = PickleballMatchStats()
        matchResult = nil
        opponentName = ""
        venue = ""
        matchPartner = partnerName
        matchDuration = 60
        energyRating = 5
        footworkRating = 5
        confidenceRating = 5
        matchDUPRInput = ""
        matchNotes = ""
        logGames = [PickleballGameScore()]
    }

    func addLogGame() {
        logGames.append(PickleballGameScore())
    }

    func removeLastLogGame() {
        guard logGames.count > 1 else { return }
        logGames.removeLast()
    }

    // MARK: - Sample data

    private func loadSampleData() {
        let cal = Calendar.current
        let now = Date()

        partnerName = "Sam"
        dupr = 4.12

        matches = [
            PickleballMatch(
                date: cal.date(byAdding: .day, value: -1, to: now)!,
                sessionType: .match,
                format: .doubles,
                side: .right,
                stats: PickleballMatchStats(
                    winners: 14, unforcedErrors: 9, aces: 2, serviceFaults: 1,
                    thirdShotDropsAttempted: 22, thirdShotDropsMade: 17,
                    dinksWon: 28, dinksLost: 14, kitchenViolations: 0,
                    atpHits: 1, ernes: 0, blockVolleysWon: 6,
                    firstServeIn: 18, firstServeAttempts: 22,
                    returnPointsWon: 11, returnPointsPlayed: 16
                ),
                games: [
                    PickleballGameScore(teamPoints: 11, opponentPoints: 7),
                    PickleballGameScore(teamPoints: 9, opponentPoints: 11),
                    PickleballGameScore(teamPoints: 11, opponentPoints: 5),
                ],
                result: .win,
                opponentName: "Riverside Reds",
                partnerName: "Sam",
                venue: "Bay Club Court 4",
                durationMinutes: 70,
                energyRating: 8,
                footworkRating: 8,
                confidenceRating: 9,
                dupr: 4.18,
                notes: "Drops landed when it mattered. Hands battle in game 2 was a grind."
            ),
            PickleballMatch(
                date: cal.date(byAdding: .day, value: -2, to: now)!,
                sessionType: .drilling,
                format: .singles,
                side: .ambi,
                stats: PickleballMatchStats(
                    thirdShotDropsAttempted: 40, thirdShotDropsMade: 31,
                    dinksWon: 60, dinksLost: 22
                ),
                durationMinutes: 60,
                energyRating: 7,
                footworkRating: 7,
                confidenceRating: 7,
                notes: "60-min cross-court dink + drop ladder. Backhand dinks felt clean."
            ),
            PickleballMatch(
                date: cal.date(byAdding: .day, value: -4, to: now)!,
                sessionType: .match,
                format: .doubles,
                side: .right,
                stats: PickleballMatchStats(
                    winners: 9, unforcedErrors: 14, aces: 1, serviceFaults: 3,
                    thirdShotDropsAttempted: 18, thirdShotDropsMade: 9,
                    dinksWon: 19, dinksLost: 22, kitchenViolations: 1,
                    firstServeIn: 14, firstServeAttempts: 22,
                    returnPointsWon: 8, returnPointsPlayed: 18
                ),
                games: [
                    PickleballGameScore(teamPoints: 8, opponentPoints: 11),
                    PickleballGameScore(teamPoints: 11, opponentPoints: 9),
                    PickleballGameScore(teamPoints: 6, opponentPoints: 11),
                ],
                result: .loss,
                opponentName: "Net Crashers",
                partnerName: "Sam",
                venue: "Westside Pickleball Club",
                durationMinutes: 75,
                energyRating: 5,
                footworkRating: 5,
                confidenceRating: 4,
                dupr: 4.05,
                notes: "Got pulled into too many bangers. Reset game wasn't there."
            ),
            PickleballMatch(
                date: cal.date(byAdding: .day, value: -7, to: now)!,
                sessionType: .openPlay,
                format: .mixedDoubles,
                side: .ambi,
                stats: PickleballMatchStats(
                    winners: 11, unforcedErrors: 8, aces: 2,
                    thirdShotDropsAttempted: 16, thirdShotDropsMade: 12,
                    dinksWon: 24, dinksLost: 13,
                    firstServeIn: 16, firstServeAttempts: 19
                ),
                games: [
                    PickleballGameScore(teamPoints: 11, opponentPoints: 4),
                    PickleballGameScore(teamPoints: 11, opponentPoints: 8),
                ],
                result: .win,
                opponentName: "Open Play Mix",
                partnerName: "Maya",
                venue: "Riverside Park",
                durationMinutes: 55,
                energyRating: 8,
                footworkRating: 7,
                confidenceRating: 8,
                notes: "Mixed doubles felt smooth. Stacking helped a lot."
            ),
            PickleballMatch(
                date: cal.date(byAdding: .day, value: -10, to: now)!,
                sessionType: .match,
                format: .doubles,
                side: .right,
                stats: PickleballMatchStats(
                    winners: 12, unforcedErrors: 10, aces: 3, serviceFaults: 2,
                    thirdShotDropsAttempted: 24, thirdShotDropsMade: 18,
                    dinksWon: 26, dinksLost: 17,
                    atpHits: 2, ernes: 1, blockVolleysWon: 7,
                    firstServeIn: 19, firstServeAttempts: 24,
                    returnPointsWon: 12, returnPointsPlayed: 18
                ),
                games: [
                    PickleballGameScore(teamPoints: 11, opponentPoints: 9),
                    PickleballGameScore(teamPoints: 11, opponentPoints: 6),
                ],
                result: .win,
                opponentName: "Riverside Reds",
                partnerName: "Sam",
                venue: "Bay Club Court 4",
                durationMinutes: 60,
                energyRating: 8,
                footworkRating: 8,
                confidenceRating: 8,
                dupr: 4.12
            ),
        ]
    }
}
