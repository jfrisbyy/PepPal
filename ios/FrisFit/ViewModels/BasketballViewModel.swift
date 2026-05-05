import SwiftUI

@Observable
final class BasketballViewModel {
    static let shared = BasketballViewModel()

    var games: [BasketballGame] = []
    var practicePlans: [PracticePlan] = []
    var selectedGame: BasketballGame? = nil
    var showGameDetail: Bool = false
    var showGameLog: Bool = false
    var showDrillLibrary: Bool = false
    var showPracticePlanBuilder: Bool = false
    var showShotChart: Bool = false

    var selectedSessionType: BasketballSessionType = .pickupGame
    var currentStats = BasketballGameStats()
    var gameResult: GameResult? = nil
    var teamScore: Int = 0
    var opponentScore: Int = 0
    var gameDuration: Int = 60
    var shotChartEntries: [ShotChartEntry] = []
    var confidenceRating: Int = 5
    var performanceRating: Int = 5
    var gameNotes: String = ""

    private(set) var hasHydratedFromCloud: Bool = false

    init() {
        Task { await self.hydrateFromCloud() }
    }

    @MainActor
    func hydrateFromCloud() async {
        let remote = await BasketballGameService.shared.fetchAll()
        if !remote.isEmpty {
            self.games = remote
        }
        self.hasHydratedFromCloud = true
    }

    var totalGamesPlayed: Int {
        games.filter { $0.sessionType.isGame }.count
    }

    var totalWins: Int {
        games.filter { $0.result == .win }.count
    }

    var totalLosses: Int {
        games.filter { $0.result == .loss }.count
    }

    var winPercentage: Double {
        let total = totalWins + totalLosses
        guard total > 0 else { return 0 }
        return Double(totalWins) / Double(total) * 100
    }

    var averagePoints: Double {
        let gameStats = games.filter { $0.sessionType.isGame }
        guard !gameStats.isEmpty else { return 0 }
        return Double(gameStats.reduce(0) { $0 + $1.stats.points }) / Double(gameStats.count)
    }

    var averageRebounds: Double {
        let gameStats = games.filter { $0.sessionType.isGame }
        guard !gameStats.isEmpty else { return 0 }
        return Double(gameStats.reduce(0) { $0 + $1.stats.totalRebounds }) / Double(gameStats.count)
    }

    var averageAssists: Double {
        let gameStats = games.filter { $0.sessionType.isGame }
        guard !gameStats.isEmpty else { return 0 }
        return Double(gameStats.reduce(0) { $0 + $1.stats.assists }) / Double(gameStats.count)
    }

    var seasonHighPoints: Int {
        games.filter { $0.sessionType.isGame }.map(\.stats.points).max() ?? 0
    }

    var overallFGPercentage: Double {
        let gameStats = games.filter { $0.sessionType.isGame }
        let totalMade = gameStats.reduce(0) { $0 + $1.stats.fieldGoalsMade }
        let totalAttempted = gameStats.reduce(0) { $0 + $1.stats.fieldGoalsAttempted }
        guard totalAttempted > 0 else { return 0 }
        return Double(totalMade) / Double(totalAttempted) * 100
    }

    var overall3PTPercentage: Double {
        let gameStats = games.filter { $0.sessionType.isGame }
        let totalMade = gameStats.reduce(0) { $0 + $1.stats.threePointersMade }
        let totalAttempted = gameStats.reduce(0) { $0 + $1.stats.threePointersAttempted }
        guard totalAttempted > 0 else { return 0 }
        return Double(totalMade) / Double(totalAttempted) * 100
    }

    var overallFTPercentage: Double {
        let gameStats = games.filter { $0.sessionType.isGame }
        let totalMade = gameStats.reduce(0) { $0 + $1.stats.freeThrowsMade }
        let totalAttempted = gameStats.reduce(0) { $0 + $1.stats.freeThrowsAttempted }
        guard totalAttempted > 0 else { return 0 }
        return Double(totalMade) / Double(totalAttempted) * 100
    }

    var thisWeekGames: [BasketballGame] {
        let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return games.filter { $0.date >= weekStart }
    }

    var thisWeekSessions: Int {
        thisWeekGames.count
    }

    var pointsTrendData: [(date: Date, points: Int)] {
        games.filter { $0.sessionType.isGame }
            .sorted { $0.date < $1.date }
            .suffix(10)
            .map { ($0.date, $0.stats.points) }
    }

    var shootingTrendData: [(date: Date, fgPct: Double)] {
        games.filter { $0.sessionType.isGame && $0.stats.fieldGoalsAttempted > 0 }
            .sorted { $0.date < $1.date }
            .suffix(10)
            .map { ($0.date, $0.stats.fieldGoalPercentage) }
    }

    var confidenceCorrelation: [(confidence: Int, fgPct: Double)] {
        games.filter { $0.sessionType.isGame && $0.stats.fieldGoalsAttempted > 0 }
            .map { ($0.confidenceRating, $0.stats.fieldGoalPercentage) }
    }

    var allShotChartEntries: [ShotChartEntry] {
        games.flatMap(\.shotChart)
    }

    func shotZoneStats(for zone: ShotZone) -> (made: Int, attempted: Int, percentage: Double) {
        let entries = allShotChartEntries.filter { $0.zone == zone }
        let made = entries.filter(\.made).count
        let attempted = entries.count
        let pct = attempted > 0 ? Double(made) / Double(attempted) * 100 : 0
        return (made, attempted, pct)
    }

    func logGame() {
        let game = BasketballGame(
            date: Date(),
            sessionType: selectedSessionType,
            stats: currentStats,
            result: selectedSessionType.isGame ? gameResult : nil,
            teamScore: selectedSessionType.isGame ? teamScore : nil,
            opponentScore: selectedSessionType.isGame ? opponentScore : nil,
            durationMinutes: gameDuration,
            shotChart: shotChartEntries,
            confidenceRating: confidenceRating,
            performanceRating: performanceRating,
            notes: gameNotes
        )
        games.insert(game, at: 0)
        Task { await BasketballGameService.shared.insert(game) }
        resetLogForm()
    }

    func resetLogForm() {
        selectedSessionType = .pickupGame
        currentStats = BasketballGameStats()
        gameResult = nil
        teamScore = 0
        opponentScore = 0
        gameDuration = 60
        shotChartEntries = []
        confidenceRating = 5
        performanceRating = 5
        gameNotes = ""
    }

    func addShotEntry(zone: ShotZone, made: Bool) {
        shotChartEntries.append(ShotChartEntry(zone: zone, made: made))
        if made {
            currentStats.fieldGoalsMade += 1
            if zone.isThreePointer {
                currentStats.threePointersMade += 1
                currentStats.threePointersAttempted += 1
                currentStats.points += 3
            } else {
                currentStats.points += 2
            }
        } else {
            if zone.isThreePointer {
                currentStats.threePointersAttempted += 1
            }
        }
        currentStats.fieldGoalsAttempted += 1
    }

    func savePracticePlan(_ plan: PracticePlan) {
        practicePlans.insert(plan, at: 0)
    }

    /// Ingest a generic SportSession logged from the Train page. If it's basketball,
    /// turn it into a BasketballGame so it shows up on the basketball dashboard.
    func ingestSportSession(_ session: SportSession) {
        guard session.sport == .basketball else { return }

        var stats = BasketballGameStats()
        if case .basketball(let s) = session.specificStats {
            stats.points = s.points
            stats.assists = s.assists
            stats.defensiveRebounds = s.rebounds
        }
        stats.minutesPlayed = session.durationMinutes

        let sessionType: BasketballSessionType = {
            switch session.sessionType {
            case .game: return .pickupGame
            case .practice: return .skillsPractice
            case .training: return .soloShooting
            }
        }()

        let game = BasketballGame(
            date: session.date,
            sessionType: sessionType,
            stats: stats,
            result: nil,
            teamScore: nil,
            opponentScore: nil,
            durationMinutes: session.durationMinutes,
            shotChart: [],
            confidenceRating: session.intensity,
            performanceRating: session.intensity,
            notes: ""
        )
        games.insert(game, at: 0)
        Task { await BasketballGameService.shared.insert(game) }
    }

    private func loadSampleData() {
        let cal = Calendar.current
        let now = Date()

        games = [
            BasketballGame(
                date: cal.date(byAdding: .day, value: -1, to: now)!,
                sessionType: .pickupGame,
                stats: BasketballGameStats(points: 22, fieldGoalsMade: 9, fieldGoalsAttempted: 18, threePointersMade: 2, threePointersAttempted: 5, freeThrowsMade: 2, freeThrowsAttempted: 3, offensiveRebounds: 2, defensiveRebounds: 5, assists: 6, steals: 3, blocks: 1, turnovers: 2, minutesPlayed: 40),
                result: .win,
                teamScore: 62,
                opponentScore: 55,
                durationMinutes: 90,
                shotChart: generateSampleShotChart(),
                confidenceRating: 8,
                performanceRating: 8
            ),
            BasketballGame(
                date: cal.date(byAdding: .day, value: -3, to: now)!,
                sessionType: .fullGame5v5,
                stats: BasketballGameStats(points: 15, fieldGoalsMade: 6, fieldGoalsAttempted: 15, threePointersMade: 1, threePointersAttempted: 4, freeThrowsMade: 2, freeThrowsAttempted: 2, offensiveRebounds: 1, defensiveRebounds: 4, assists: 8, steals: 2, blocks: 0, turnovers: 3, minutesPlayed: 36),
                result: .loss,
                teamScore: 48,
                opponentScore: 52,
                durationMinutes: 80,
                shotChart: generateSampleShotChart(),
                confidenceRating: 6,
                performanceRating: 6
            ),
            BasketballGame(
                date: cal.date(byAdding: .day, value: -5, to: now)!,
                sessionType: .soloShooting,
                stats: BasketballGameStats(points: 0, fieldGoalsMade: 38, fieldGoalsAttempted: 50, threePointersMade: 15, threePointersAttempted: 25, freeThrowsMade: 8, freeThrowsAttempted: 10, offensiveRebounds: 0, defensiveRebounds: 0, assists: 0, steals: 0, blocks: 0, turnovers: 0, minutesPlayed: 45),
                durationMinutes: 45,
                shotChart: generateSampleShotChart(),
                confidenceRating: 7,
                performanceRating: 7
            ),
            BasketballGame(
                date: cal.date(byAdding: .day, value: -7, to: now)!,
                sessionType: .pickupGame,
                stats: BasketballGameStats(points: 28, fieldGoalsMade: 11, fieldGoalsAttempted: 20, threePointersMade: 4, threePointersAttempted: 8, freeThrowsMade: 2, freeThrowsAttempted: 4, offensiveRebounds: 3, defensiveRebounds: 6, assists: 4, steals: 1, blocks: 2, turnovers: 1, minutesPlayed: 44),
                result: .win,
                teamScore: 71,
                opponentScore: 58,
                durationMinutes: 95,
                shotChart: generateSampleShotChart(),
                confidenceRating: 9,
                performanceRating: 9
            ),
            BasketballGame(
                date: cal.date(byAdding: .day, value: -10, to: now)!,
                sessionType: .fullGame3v3,
                stats: BasketballGameStats(points: 18, fieldGoalsMade: 7, fieldGoalsAttempted: 14, threePointersMade: 3, threePointersAttempted: 6, freeThrowsMade: 1, freeThrowsAttempted: 2, offensiveRebounds: 2, defensiveRebounds: 3, assists: 3, steals: 2, blocks: 0, turnovers: 2, minutesPlayed: 30),
                result: .win,
                teamScore: 21,
                opponentScore: 15,
                durationMinutes: 50,
                shotChart: generateSampleShotChart(),
                confidenceRating: 7,
                performanceRating: 8
            ),
        ]

        practicePlans = [
            PracticePlan(name: "Shooting Warmup", drills: [
                PracticePlanDrill(drill: BasketballDrillLibrary.all[1]),
                PracticePlanDrill(drill: BasketballDrillLibrary.all[2]),
                PracticePlanDrill(drill: BasketballDrillLibrary.all[10]),
            ]),
        ]
    }

    private func generateSampleShotChart() -> [ShotChartEntry] {
        var entries: [ShotChartEntry] = []
        let zones: [ShotZone] = [.paint, .freeThrow, .leftElbow, .rightElbow, .leftWing3, .rightWing3, .topArc3, .leftCorner3, .rightCorner3]
        for zone in zones {
            let attempts = Int.random(in: 1...4)
            for _ in 0..<attempts {
                let made = Double.random(in: 0...1) > (zone.isThreePointer ? 0.65 : 0.5)
                entries.append(ShotChartEntry(zone: zone, made: made))
            }
        }
        return entries
    }
}
