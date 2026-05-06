import SwiftUI

@Observable
final class BasketballViewModel {
    static let shared = BasketballViewModel()

    // MARK: - Persistence keys
    private enum Keys {
        static let seriousMode = "bb.seriousMode"
        static let goals = "bb.goals"
        static let weeklyFocus = "bb.weeklyFocus"
        static let weeklyFocusDate = "bb.weeklyFocusDate"
        static let drillSessions = "bb.drillSessions"
    }

    // MARK: - Persistent settings

    var seriousMode: Bool = UserDefaults.standard.bool(forKey: Keys.seriousMode) {
        didSet { UserDefaults.standard.set(seriousMode, forKey: Keys.seriousMode) }
    }

    var goals: [BasketballGoal] = [] {
        didSet { saveGoals() }
    }

    var weeklyFocus: BasketballFocusSkill = .catchAndShoot {
        didSet {
            UserDefaults.standard.set(weeklyFocus.rawValue, forKey: Keys.weeklyFocus)
            UserDefaults.standard.set(Date(), forKey: Keys.weeklyFocusDate)
        }
    }

    /// drillSlug -> session count
    private(set) var drillSessions: [String: Int] = [:] {
        didSet { saveDrillSessions() }
    }

    // MARK: - Data

    var games: [BasketballGame] = []
    var practicePlans: [PracticePlan] = []
    var selectedGame: BasketballGame? = nil
    var showGameDetail: Bool = false
    var showRunDetail: Bool = false
    var showGameLog: Bool = false
    var showRunLog: Bool = false
    var showDrillLibrary: Bool = false
    var showPracticePlanBuilder: Bool = false
    var showShotChart: Bool = false
    var showSettings: Bool = false
    var showGoalsEditor: Bool = false
    var showWeeklyFocus: Bool = false

    // Drill / plan runner state
    var selectedDrill: BasketballDrill? = nil
    var showDrillDetail: Bool = false
    var runningDrill: BasketballDrill? = nil
    var runningPlan: PracticePlan? = nil

    // MARK: - Log form state

    var selectedSessionType: BasketballSessionType = .pickupGame
    var currentStats = BasketballGameStats()
    var gameResult: GameResult? = nil
    var teamScore: Int = 0
    var opponentScore: Int = 0
    var gameDuration: Int = 60
    var shotChartEntries: [ShotChartEntry] = []
    var confidenceRating: Int = 7
    var performanceRating: Int = 7
    var energyRating: Int = 7
    var legsRating: Int = 7
    var vibeRating: Int = 7
    var gameNotes: String = ""
    var location: String = ""
    var partners: [String] = []
    var drillsCompletedThisSession: [String] = []

    private(set) var hasHydratedFromCloud: Bool = false

    init() {
        loadPersisted()
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

    private func loadPersisted() {
        if let raw = UserDefaults.standard.string(forKey: Keys.weeklyFocus),
           let skill = BasketballFocusSkill(rawValue: raw) {
            weeklyFocus = skill
        }
        if let data = UserDefaults.standard.data(forKey: Keys.goals),
           let decoded = try? JSONDecoder().decode([BasketballGoal].self, from: data) {
            goals = decoded
        } else {
            goals = [BasketballGoal(type: .sessionsPerWeek, target: 3)]
        }
        if let data = UserDefaults.standard.data(forKey: Keys.drillSessions),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            drillSessions = decoded
        }
    }

    private func saveGoals() {
        if let data = try? JSONEncoder().encode(goals) {
            UserDefaults.standard.set(data, forKey: Keys.goals)
        }
    }

    private func saveDrillSessions() {
        if let data = try? JSONEncoder().encode(drillSessions) {
            UserDefaults.standard.set(data, forKey: Keys.drillSessions)
        }
    }

    // MARK: - Aggregates (serious mode)

    var totalGamesPlayed: Int { games.filter { $0.sessionType.isGame }.count }
    var totalWins: Int { games.filter { $0.result == .win }.count }
    var totalLosses: Int { games.filter { $0.result == .loss }.count }

    var winPercentage: Double {
        let total = totalWins + totalLosses
        guard total > 0 else { return 0 }
        return Double(totalWins) / Double(total) * 100
    }

    var averagePoints: Double {
        let g = games.filter { $0.sessionType.isGame }
        guard !g.isEmpty else { return 0 }
        return Double(g.reduce(0) { $0 + $1.stats.points }) / Double(g.count)
    }

    var averageRebounds: Double {
        let g = games.filter { $0.sessionType.isGame }
        guard !g.isEmpty else { return 0 }
        return Double(g.reduce(0) { $0 + $1.stats.totalRebounds }) / Double(g.count)
    }

    var averageAssists: Double {
        let g = games.filter { $0.sessionType.isGame }
        guard !g.isEmpty else { return 0 }
        return Double(g.reduce(0) { $0 + $1.stats.assists }) / Double(g.count)
    }

    var seasonHighPoints: Int {
        games.filter { $0.sessionType.isGame }.map(\.stats.points).max() ?? 0
    }

    var overallFGPercentage: Double { pct(\.stats.fieldGoalsMade, \.stats.fieldGoalsAttempted) }
    var overall3PTPercentage: Double { pct(\.stats.threePointersMade, \.stats.threePointersAttempted) }
    var overallFTPercentage: Double { pct(\.stats.freeThrowsMade, \.stats.freeThrowsAttempted) }

    private func pct(_ made: KeyPath<BasketballGame, Int>, _ att: KeyPath<BasketballGame, Int>) -> Double {
        let g = games.filter { $0.sessionType.isGame }
        let totalMade = g.reduce(0) { $0 + $1[keyPath: made] }
        let totalAtt = g.reduce(0) { $0 + $1[keyPath: att] }
        guard totalAtt > 0 else { return 0 }
        return Double(totalMade) / Double(totalAtt) * 100
    }

    var thisWeekGames: [BasketballGame] {
        let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return games.filter { $0.date >= weekStart }
    }

    var thisWeekSessions: Int { thisWeekGames.count }

    var thisWeekMinutes: Int {
        thisWeekGames.reduce(0) { $0 + $1.durationMinutes }
    }

    var thisWeekMakes: Int {
        thisWeekGames.reduce(0) { $0 + $1.stats.fieldGoalsMade + $1.stats.freeThrowsMade } +
        thisWeekGames.reduce(0) { $0 + $1.shotChart.filter(\.made).count }
    }

    var thisWeekDrillsCompleted: Int {
        thisWeekGames.reduce(0) { $0 + $1.drillsCompleted.count }
    }

    // MARK: - Streak

    /// Current consecutive-day session streak.
    var currentStreak: Int {
        let cal = Calendar.current
        let dates = Set(games.map { cal.startOfDay(for: $0.date) })
        var streak = 0
        var day = cal.startOfDay(for: Date())
        // Allow today to not count as breaker — start from today and walk back.
        if !dates.contains(day) { day = cal.date(byAdding: .day, value: -1, to: day)! }
        while dates.contains(day) {
            streak += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return streak
    }

    /// 12-week heatmap data — number of sessions on each day, last 84 days.
    var heatmapData: [(date: Date, count: Int)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var bucket: [Date: Int] = [:]
        for game in games {
            let day = cal.startOfDay(for: game.date)
            bucket[day, default: 0] += 1
        }
        return (0..<84).reversed().compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return (day, bucket[day] ?? 0)
        }
    }

    // MARK: - Trends (serious mode)

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

    // MARK: - Goals

    func progress(for goal: BasketballGoal) -> Double {
        let value = currentValue(for: goal.type)
        guard goal.target > 0 else { return 0 }
        return min(Double(value) / Double(goal.target), 1.0)
    }

    func currentValue(for type: BasketballGoalType) -> Int {
        switch type {
        case .sessionsPerWeek: thisWeekSessions
        case .minutesPerWeek: thisWeekMinutes
        case .shotsPerWeek: thisWeekMakes
        case .drillsPerWeek: thisWeekDrillsCompleted
        case .streakDays: currentStreak
        }
    }

    func addGoal(_ goal: BasketballGoal) { goals.append(goal) }

    func removeGoal(_ goal: BasketballGoal) {
        goals.removeAll { $0.id == goal.id }
    }

    func updateGoal(_ goal: BasketballGoal) {
        if let idx = goals.firstIndex(where: { $0.id == goal.id }) {
            goals[idx] = goal
        }
    }

    // MARK: - Drill mastery

    func mastery(for drill: BasketballDrill) -> DrillMastery {
        DrillMastery.forSessionCount(drillSessions[drill.slug] ?? 0)
    }

    func sessionCount(for drill: BasketballDrill) -> Int {
        drillSessions[drill.slug] ?? 0
    }

    func recordDrillCompletion(_ drill: BasketballDrill) {
        drillSessions[drill.slug, default: 0] += 1
    }

    var drillsTouched: [(drill: BasketballDrill, count: Int)] {
        drillSessions.compactMap { (slug, count) -> (drill: BasketballDrill, count: Int)? in
            guard let drill = BasketballDrillLibrary.drill(forSlug: slug) else { return nil }
            return (drill, count)
        }
        .sorted { $0.count > $1.count }
    }

    // MARK: - Hero copy

    func heroLine(firstName: String) -> String {
        if thisWeekSessions == 0 {
            return "Time to get back on the court."
        }
        if currentStreak >= 3 {
            return "\(currentStreak)-day streak — keep cooking."
        }
        if thisWeekSessions >= 4 {
            return "\(thisWeekSessions) runs this week — locked in."
        }
        return "\(thisWeekSessions) run\(thisWeekSessions == 1 ? "" : "s") this week — keep going."
    }

    // MARK: - Logging

    func logRun() {
        let intensity = max(min(Int(round(Double(energyRating + legsRating + vibeRating) / 3)), 10), 1)
        let calories = METCalculator.caloriesBurned(
            sport: "Basketball",
            workoutType: nil,
            durationMinutes: gameDuration,
            weightKg: BasketballViewModel.userWeightKg(),
            intensity: intensity
        )

        var stats = currentStats
        if stats.minutesPlayed == 0 { stats.minutesPlayed = gameDuration }

        let game = BasketballGame(
            date: Date(),
            sessionType: selectedSessionType,
            stats: stats,
            result: selectedSessionType.isGame ? gameResult : nil,
            teamScore: selectedSessionType.isGame ? teamScore : nil,
            opponentScore: selectedSessionType.isGame ? opponentScore : nil,
            durationMinutes: gameDuration,
            shotChart: shotChartEntries,
            confidenceRating: confidenceRating,
            performanceRating: performanceRating,
            notes: gameNotes,
            location: location,
            partners: partners,
            energyRating: energyRating,
            legsRating: legsRating,
            vibeRating: vibeRating,
            drillsCompleted: drillsCompletedThisSession,
            caloriesBurned: calories
        )
        games.insert(game, at: 0)

        // Record drill mastery progress
        for slug in drillsCompletedThisSession {
            drillSessions[slug, default: 0] += 1
        }

        Task {
            await BasketballGameService.shared.insert(game)
            await Self.logCaloriesToActivity(
                durationMinutes: game.durationMinutes,
                calories: game.caloriesBurned,
                notes: game.location.isEmpty ? nil : "Hooped at \(game.location)"
            )
        }
        resetLogForm()
    }

    /// Legacy 4-step logger entry point (serious mode).
    func logGame() { logRun() }

    func resetLogForm() {
        selectedSessionType = .pickupGame
        currentStats = BasketballGameStats()
        gameResult = nil
        teamScore = 0
        opponentScore = 0
        gameDuration = 60
        shotChartEntries = []
        confidenceRating = 7
        performanceRating = 7
        energyRating = 7
        legsRating = 7
        vibeRating = 7
        gameNotes = ""
        location = ""
        partners = []
        drillsCompletedThisSession = []
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
        } else if zone.isThreePointer {
            currentStats.threePointersAttempted += 1
        }
        currentStats.fieldGoalsAttempted += 1
    }

    // MARK: - Practice plans

    func savePracticePlan(_ plan: PracticePlan) {
        practicePlans.insert(plan, at: 0)
    }

    func deletePracticePlan(_ plan: PracticePlan) {
        practicePlans.removeAll { $0.id == plan.id }
    }

    /// Adopt a template into the user's saved plans.
    func adoptTemplate(_ template: PracticePlan) {
        let cloned = PracticePlan(
            name: template.name,
            drills: template.drills.map { PracticePlanDrill(drill: $0.drill) }
        )
        savePracticePlan(cloned)
    }

    // MARK: - Sport session ingestion

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

        let calories = METCalculator.caloriesBurned(
            sport: "Basketball",
            workoutType: nil,
            durationMinutes: session.durationMinutes,
            weightKg: BasketballViewModel.userWeightKg(),
            intensity: session.intensity
        )

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
            notes: "",
            caloriesBurned: calories
        )
        games.insert(game, at: 0)
        Task {
            await BasketballGameService.shared.insert(game)
            await Self.logCaloriesToActivity(durationMinutes: game.durationMinutes, calories: game.caloriesBurned)
        }
    }

    // MARK: - Calorie + weight helpers

    static func userWeightKg() -> Double {
        let cachedLbs = UserDefaults.standard.double(forKey: "cachedWeightLbs")
        return cachedLbs > 0 ? cachedLbs * 0.453592 : 75.0
    }

    static func logCaloriesToActivity(durationMinutes: Int, calories: Int, notes: String? = nil) async {
        guard calories > 0 else { return }
        guard let uid = try? AuthService.shared.currentUserId() else { return }
        try? await ActivityLogService.shared.logActivity(
            userId: uid,
            activityType: "sportSession",
            sport: "Basketball",
            durationMinutes: durationMinutes,
            caloriesBurned: calories,
            metValue: nil,
            notes: notes
        )
    }
}
