import SwiftUI

@Observable
final class VolleyballViewModel {
    static let shared = VolleyballViewModel()

    // MARK: - Stored state

    var matches: [VolleyballMatch] = []
    var primaryPosition: VolleyballPosition = .outsideHitter
    var selectedMatch: VolleyballMatch? = nil
    var selectedDrill: VolleyballDrill? = nil

    // Sheet / nav flags
    var showMatchDetail: Bool = false
    var showMatchLog: Bool = false
    var showDrillLibrary: Bool = false
    var showDrillDetail: Bool = false
    var showSettings: Bool = false
    var showWorkoutBuilder: Bool = false

    var savedSessions: [CustomVolleyballSession] = []
    var drillCompletions: [UUID: Int] = [:]

    // Log form state
    var selectedSessionType: VolleyballSessionType = .match
    var matchPosition: VolleyballPosition = .outsideHitter
    var currentStats = VolleyballMatchStats()
    var matchResult: VolleyballMatchResult? = nil
    var opponentName: String = ""
    var venue: String = ""
    var teammates: [String] = []
    var matchDuration: Int = 75
    var performanceRating: Int = 5
    var confidenceRating: Int = 5
    var matchNotes: String = ""
    var logSets: [VolleyballSetScore] = [VolleyballSetScore()]

    init() {
        matchPosition = primaryPosition
        loadSampleData()
    }

    // MARK: - Derived stats

    var gameMatches: [VolleyballMatch] {
        matches.filter { $0.sessionType.isMatch }
    }

    var totalMatchesPlayed: Int { gameMatches.count }
    var totalWins: Int { gameMatches.filter { $0.result == .win }.count }
    var totalLosses: Int { gameMatches.filter { $0.result == .loss }.count }

    var winPercentage: Double {
        guard totalMatchesPlayed > 0 else { return 0 }
        return Double(totalWins) / Double(totalMatchesPlayed) * 100
    }

    var totalKills: Int { gameMatches.reduce(0) { $0 + $1.stats.kills } }
    var totalAces: Int { gameMatches.reduce(0) { $0 + $1.stats.aces } }
    var totalBlocks: Int { gameMatches.reduce(0) { $0 + $1.stats.totalBlocks } }
    var totalDigs: Int { gameMatches.reduce(0) { $0 + $1.stats.digs } }
    var totalAssists: Int { gameMatches.reduce(0) { $0 + $1.stats.assists } }

    var averageKillsPerMatch: Double {
        guard !gameMatches.isEmpty else { return 0 }
        return Double(totalKills) / Double(gameMatches.count)
    }

    var averageHittingPercentage: Double {
        let withSwings = gameMatches.filter { $0.stats.attackAttempts > 0 }
        guard !withSwings.isEmpty else { return 0 }
        return withSwings.reduce(0.0) { $0 + $1.stats.hittingPercentage } / Double(withSwings.count)
    }

    var averageBlocksPerMatch: Double {
        guard !gameMatches.isEmpty else { return 0 }
        return Double(totalBlocks) / Double(gameMatches.count)
    }

    var averageDigsPerMatch: Double {
        guard !gameMatches.isEmpty else { return 0 }
        return Double(totalDigs) / Double(gameMatches.count)
    }

    var averagePassingRating: Double {
        let withReceptions = gameMatches.filter { $0.stats.receptionAttempts > 0 }
        guard !withReceptions.isEmpty else { return 0 }
        return withReceptions.reduce(0.0) { $0 + $1.stats.passingRating } / Double(withReceptions.count)
    }

    var thisWeekMatches: [VolleyballMatch] {
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

    var killsTrend: [(date: Date, kills: Int)] {
        gameMatches
            .sorted { $0.date < $1.date }
            .suffix(10)
            .map { ($0.date, $0.stats.kills) }
    }

    var hittingTrend: [(date: Date, hitting: Double)] {
        gameMatches
            .filter { $0.stats.attackAttempts > 0 }
            .sorted { $0.date < $1.date }
            .suffix(10)
            .map { ($0.date, $0.stats.hittingPercentage) }
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

    var positionDashboardStats: [(label: String, value: String, color: Color)] {
        let accent = Color(red: 0.95, green: 0.30, blue: 0.20)
        if primaryPosition.isAttacker {
            return [
                ("Kills/M", String(format: "%.1f", averageKillsPerMatch), accent),
                ("Hit%", String(format: "%+.3f", averageHittingPercentage), .green),
                ("Blocks/M", String(format: "%.1f", averageBlocksPerMatch), .blue),
            ]
        }
        if primaryPosition == .setter {
            return [
                ("Asst/M", String(format: "%.1f", averageOf { Double($0.stats.assists) }), accent),
                ("Aces/M", String(format: "%.1f", averageOf { Double($0.stats.aces) }), .green),
                ("Digs/M", String(format: "%.1f", averageDigsPerMatch), .blue),
            ]
        }
        // Backrow
        return [
            ("Digs/M", String(format: "%.1f", averageDigsPerMatch), accent),
            ("Pass", String(format: "%.2f", averagePassingRating), .green),
            ("Aces/M", String(format: "%.1f", averageOf { Double($0.stats.aces) }), .blue),
        ]
    }

    private func averageOf(_ extract: (VolleyballMatch) -> Double) -> Double {
        guard !gameMatches.isEmpty else { return 0 }
        return gameMatches.reduce(0.0) { $0 + extract($1) } / Double(gameMatches.count)
    }

    // MARK: - Logging

    func logMatch() {
        let usedSets = logSets.filter { $0.totalPoints > 0 }
        let resolvedResult: VolleyballMatchResult? = {
            if let r = matchResult { return r }
            guard !usedSets.isEmpty, selectedSessionType.isMatch else { return nil }
            let won = usedSets.filter(\.teamWon).count
            return won * 2 > usedSets.count ? .win : .loss
        }()

        let match = VolleyballMatch(
            date: Date(),
            sessionType: selectedSessionType,
            position: matchPosition,
            stats: currentStats,
            sets: usedSets,
            result: selectedSessionType.isMatch ? resolvedResult : nil,
            opponentName: opponentName,
            venue: venue,
            teammates: teammates,
            durationMinutes: matchDuration,
            performanceRating: performanceRating,
            confidenceRating: confidenceRating,
            notes: matchNotes
        )
        matches.insert(match, at: 0)
        resetLogForm()
    }

    func resetLogForm() {
        selectedSessionType = .match
        matchPosition = primaryPosition
        currentStats = VolleyballMatchStats()
        matchResult = nil
        opponentName = ""
        venue = ""
        teammates = []
        matchDuration = 75
        performanceRating = 5
        confidenceRating = 5
        matchNotes = ""
        logSets = [VolleyballSetScore()]
    }

    func addLogSet() {
        logSets.append(VolleyballSetScore())
    }

    func removeLastLogSet() {
        guard logSets.count > 1 else { return }
        logSets.removeLast()
    }

    // MARK: - Sample data

    private func loadSampleData() {
        let cal = Calendar.current
        let now = Date()

        matches = [
            VolleyballMatch(
                date: cal.date(byAdding: .day, value: -1, to: now)!,
                sessionType: .match,
                position: .outsideHitter,
                stats: VolleyballMatchStats(kills: 14, attackAttempts: 32, attackErrors: 4, aces: 3, serviceErrors: 1, blocks: 2, blockAssists: 3, digs: 11, assists: 2, receptionPerfect: 8, receptionAttempts: 14, receptionErrors: 1),
                sets: [
                    VolleyballSetScore(teamPoints: 25, opponentPoints: 21),
                    VolleyballSetScore(teamPoints: 23, opponentPoints: 25),
                    VolleyballSetScore(teamPoints: 25, opponentPoints: 18),
                ],
                result: .win,
                opponentName: "Riptide VBC",
                venue: "Coastal Gym",
                teammates: ["Ana", "Maya", "Jen"],
                durationMinutes: 95,
                performanceRating: 8,
                confidenceRating: 8,
                notes: "Pass game was on. Outside swings opened up after set 2."
            ),
            VolleyballMatch(
                date: cal.date(byAdding: .day, value: -3, to: now)!,
                sessionType: .teamPractice,
                position: .outsideHitter,
                stats: VolleyballMatchStats(kills: 0, attackAttempts: 0, attackErrors: 0, aces: 0, serviceErrors: 0, blocks: 0, digs: 0, assists: 0),
                durationMinutes: 90,
                performanceRating: 7,
                confidenceRating: 7,
                notes: "Hitting lines + 6v6 wash drill"
            ),
            VolleyballMatch(
                date: cal.date(byAdding: .day, value: -5, to: now)!,
                sessionType: .match,
                position: .outsideHitter,
                stats: VolleyballMatchStats(kills: 9, attackAttempts: 28, attackErrors: 7, aces: 1, serviceErrors: 3, blocks: 1, blockAssists: 1, digs: 8, assists: 1, receptionPerfect: 5, receptionAttempts: 12, receptionErrors: 2),
                sets: [
                    VolleyballSetScore(teamPoints: 22, opponentPoints: 25),
                    VolleyballSetScore(teamPoints: 25, opponentPoints: 23),
                    VolleyballSetScore(teamPoints: 18, opponentPoints: 25),
                ],
                result: .loss,
                opponentName: "Vertical Crew",
                venue: "Westside Court 3",
                teammates: ["Ana", "Maya"],
                durationMinutes: 85,
                performanceRating: 5,
                confidenceRating: 5,
                notes: "Errors in set 3 — stopped reading the block."
            ),
            VolleyballMatch(
                date: cal.date(byAdding: .day, value: -8, to: now)!,
                sessionType: .scrimmage,
                position: .outsideHitter,
                stats: VolleyballMatchStats(kills: 11, attackAttempts: 24, attackErrors: 3, aces: 4, serviceErrors: 1, blocks: 3, blockAssists: 2, digs: 9, assists: 2, receptionPerfect: 7, receptionAttempts: 11, receptionErrors: 0),
                sets: [
                    VolleyballSetScore(teamPoints: 25, opponentPoints: 19),
                    VolleyballSetScore(teamPoints: 25, opponentPoints: 22),
                ],
                result: .win,
                opponentName: "Riptide VBC",
                venue: "Coastal Gym",
                teammates: ["Ana", "Jen"],
                durationMinutes: 70,
                performanceRating: 9,
                confidenceRating: 8,
                notes: "Best serving night in a while."
            ),
            VolleyballMatch(
                date: cal.date(byAdding: .day, value: -11, to: now)!,
                sessionType: .match,
                position: .outsideHitter,
                stats: VolleyballMatchStats(kills: 12, attackAttempts: 30, attackErrors: 5, aces: 2, serviceErrors: 2, blocks: 1, blockAssists: 2, digs: 10, assists: 1, receptionPerfect: 6, receptionAttempts: 13, receptionErrors: 1),
                sets: [
                    VolleyballSetScore(teamPoints: 25, opponentPoints: 17),
                    VolleyballSetScore(teamPoints: 25, opponentPoints: 23),
                ],
                result: .win,
                opponentName: "Net Force",
                venue: "Riverside Sports Center",
                teammates: ["Maya", "Jen"],
                durationMinutes: 65,
                performanceRating: 8,
                confidenceRating: 8
            ),
        ]
    }
}
