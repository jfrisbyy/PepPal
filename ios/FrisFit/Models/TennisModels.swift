import Foundation
import SwiftUI

nonisolated enum TennisSessionType: String, CaseIterable, Identifiable, Sendable {
    case singlesMatch = "Singles Match"
    case doublesMatch = "Doubles Match"
    case hittingSession = "Hitting Session"
    case soloRally = "Solo Rally"
    case ballMachine = "Ball Machine"
    case cardioConditioning = "Conditioning"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .singlesMatch: "tennis.racket"
        case .doublesMatch: "person.2.fill"
        case .hittingSession: "figure.tennis"
        case .soloRally: "arrow.left.arrow.right"
        case .ballMachine: "gearshape.fill"
        case .cardioConditioning: "bolt.heart.fill"
        }
    }

    var isMatch: Bool {
        switch self {
        case .singlesMatch, .doublesMatch: true
        default: false
        }
    }
}

nonisolated enum TennisMatchFormat: String, CaseIterable, Identifiable, Sendable {
    case bestOf3 = "Best of 3"
    case bestOf5 = "Best of 5"

    var id: String { rawValue }

    var setsToWin: Int {
        switch self {
        case .bestOf3: 2
        case .bestOf5: 3
        }
    }
}

nonisolated enum TennisMatchResult: String, CaseIterable, Identifiable, Sendable {
    case win = "W"
    case loss = "L"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .win: .green
        case .loss: .red
        }
    }

    var label: String {
        switch self {
        case .win: "Win"
        case .loss: "Loss"
        }
    }
}

nonisolated struct TennisSetScore: Sendable {
    var playerGames: Int = 0
    var opponentGames: Int = 0
    var tiebreakPlayerPoints: Int? = nil
    var tiebreakOpponentPoints: Int? = nil

    var display: String {
        if let tbP = tiebreakPlayerPoints, let tbO = tiebreakOpponentPoints {
            let loserTB = min(tbP, tbO)
            return "\(playerGames)-\(opponentGames)(\(loserTB))"
        }
        return "\(playerGames)-\(opponentGames)"
    }

    var playerWon: Bool { playerGames > opponentGames }
}

nonisolated struct TennisMatchStats: Sendable {
    var aces: Int = 0
    var doubleFaults: Int = 0
    var firstServesIn: Int = 0
    var firstServesTotal: Int = 0
    var winners: Int = 0
    var unforcedErrors: Int = 0
    var forehandsHit: Int = 0
    var backhandsHit: Int = 0
    var servesHit: Int = 0
    var volleysHit: Int = 0
    var breakPointsConverted: Int = 0
    var breakPointsTotal: Int = 0

    var firstServePercentage: Double {
        firstServesTotal > 0 ? Double(firstServesIn) / Double(firstServesTotal) * 100 : 0
    }

    var breakPointConversionRate: Double {
        breakPointsTotal > 0 ? Double(breakPointsConverted) / Double(breakPointsTotal) * 100 : 0
    }

    var totalShotsTracked: Int {
        forehandsHit + backhandsHit + servesHit + volleysHit
    }

    var winnerToErrorRatio: Double {
        unforcedErrors > 0 ? Double(winners) / Double(unforcedErrors) : Double(winners)
    }
}

nonisolated struct TennisMatch: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let sessionType: TennisSessionType
    let format: TennisMatchFormat
    let stats: TennisMatchStats
    let sets: [TennisSetScore]
    let result: TennisMatchResult?
    let opponentName: String
    let durationMinutes: Int
    let performanceRating: Int
    let confidenceRating: Int
    let notes: String

    init(
        date: Date = Date(),
        sessionType: TennisSessionType = .singlesMatch,
        format: TennisMatchFormat = .bestOf3,
        stats: TennisMatchStats = TennisMatchStats(),
        sets: [TennisSetScore] = [],
        result: TennisMatchResult? = nil,
        opponentName: String = "",
        durationMinutes: Int = 60,
        performanceRating: Int = 5,
        confidenceRating: Int = 5,
        notes: String = ""
    ) {
        self.id = UUID()
        self.date = date
        self.sessionType = sessionType
        self.format = format
        self.stats = stats
        self.sets = sets
        self.result = result
        self.opponentName = opponentName
        self.durationMinutes = durationMinutes
        self.performanceRating = performanceRating
        self.confidenceRating = confidenceRating
        self.notes = notes
    }

    var scoreDisplay: String {
        sets.map(\.display).joined(separator: " ")
    }

    var setsWon: Int { sets.filter(\.playerWon).count }
    var setsLost: Int { sets.filter { !$0.playerWon }.count }
}

nonisolated struct TennisLiveScore: Sendable {
    var sets: [TennisSetScore] = [TennisSetScore()]
    var playerPoints: Int = 0
    var opponentPoints: Int = 0
    var isPlayerServing: Bool = true
    var isTiebreak: Bool = false
    var matchOver: Bool = false
    var format: TennisMatchFormat = .bestOf3

    var currentSetIndex: Int { sets.count - 1 }
    var currentSet: TennisSetScore { sets[currentSetIndex] }

    var playerPointDisplay: String {
        if isTiebreak { return "\(playerPoints)" }
        switch playerPoints {
        case 0: return "0"
        case 1: return "15"
        case 2: return "30"
        case 3: return "40"
        case 4 where opponentPoints >= 3: return "AD"
        default: return "40"
        }
    }

    var opponentPointDisplay: String {
        if isTiebreak { return "\(opponentPoints)" }
        switch opponentPoints {
        case 0: return "0"
        case 1: return "15"
        case 2: return "30"
        case 3: return "40"
        case 4 where playerPoints >= 3: return "AD"
        default: return "40"
        }
    }

    var playerSetsWon: Int { sets.filter(\.playerWon).count - (matchOver ? 0 : (sets.last.map { _ in 1 } ?? 0)) + (matchOver && (sets.last?.playerWon == true) ? 0 : 0) }

    mutating func playerWonPoint() {
        guard !matchOver else { return }
        if isTiebreak {
            playerPoints += 1
            checkTiebreakGame()
        } else {
            playerPoints += 1
            checkGame()
        }
    }

    mutating func opponentWonPoint() {
        guard !matchOver else { return }
        if isTiebreak {
            opponentPoints += 1
            checkTiebreakGame()
        } else {
            opponentPoints += 1
            checkGame()
        }
    }

    private mutating func checkGame() {
        if playerPoints >= 4 && playerPoints - opponentPoints >= 2 {
            sets[currentSetIndex].playerGames += 1
            playerPoints = 0
            opponentPoints = 0
            isPlayerServing.toggle()
            checkSet()
        } else if opponentPoints >= 4 && opponentPoints - playerPoints >= 2 {
            sets[currentSetIndex].opponentGames += 1
            playerPoints = 0
            opponentPoints = 0
            isPlayerServing.toggle()
            checkSet()
        }
    }

    private mutating func checkTiebreakGame() {
        let totalPoints = playerPoints + opponentPoints
        if playerPoints >= 7 && playerPoints - opponentPoints >= 2 {
            sets[currentSetIndex].playerGames += 1
            sets[currentSetIndex].tiebreakPlayerPoints = playerPoints
            sets[currentSetIndex].tiebreakOpponentPoints = opponentPoints
            isTiebreak = false
            playerPoints = 0
            opponentPoints = 0
            isPlayerServing.toggle()
            checkSet()
        } else if opponentPoints >= 7 && opponentPoints - playerPoints >= 2 {
            sets[currentSetIndex].opponentGames += 1
            sets[currentSetIndex].tiebreakPlayerPoints = playerPoints
            sets[currentSetIndex].tiebreakOpponentPoints = opponentPoints
            isTiebreak = false
            playerPoints = 0
            opponentPoints = 0
            isPlayerServing.toggle()
            checkSet()
        } else if totalPoints > 0 && totalPoints % 2 == 1 {
            isPlayerServing.toggle()
        }
    }

    private mutating func checkSet() {
        let pGames = sets[currentSetIndex].playerGames
        let oGames = sets[currentSetIndex].opponentGames

        if pGames >= 6 && pGames - oGames >= 2 {
            checkMatch()
        } else if oGames >= 6 && oGames - pGames >= 2 {
            checkMatch()
        } else if pGames == 6 && oGames == 6 {
            isTiebreak = true
        }
    }

    private mutating func checkMatch() {
        let completeSets = sets
        let playerSets = completeSets.filter(\.playerWon).count
        let opponentSets = completeSets.filter { !$0.playerWon && ($0.playerGames + $0.opponentGames > 0) }.count

        if playerSets >= format.setsToWin || opponentSets >= format.setsToWin {
            matchOver = true
        } else {
            sets.append(TennisSetScore())
        }
    }

    var computedPlayerSetsWon: Int {
        sets.filter { $0.playerGames + $0.opponentGames > 0 && $0.playerWon }.count
    }

    var computedOpponentSetsWon: Int {
        sets.filter { $0.playerGames + $0.opponentGames > 0 && !$0.playerWon }.count
    }
}

nonisolated enum TennisDrillCategory: String, CaseIterable, Identifiable, Sendable {
    case serve = "Serve"
    case groundstroke = "Groundstroke"
    case volley = "Volley"
    case footwork = "Footwork"
    case mental = "Mental"
    case conditioning = "Conditioning"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .serve: "arrow.up.right"
        case .groundstroke: "arrow.left.arrow.right"
        case .volley: "hand.raised.fill"
        case .footwork: "figure.run"
        case .mental: "brain.head.profile.fill"
        case .conditioning: "bolt.heart.fill"
        }
    }

    var color: Color {
        switch self {
        case .serve: Color(red: 0.85, green: 0.9, blue: 0.15)
        case .groundstroke: Color(red: 0.2, green: 0.78, blue: 0.35)
        case .volley: Color(red: 0.2, green: 0.6, blue: 1.0)
        case .footwork: Color(red: 1.0, green: 0.55, blue: 0.1)
        case .mental: Color(red: 0.55, green: 0.36, blue: 0.96)
        case .conditioning: Color(red: 0.85, green: 0.25, blue: 0.25)
        }
    }
}

nonisolated enum TennisDrillDifficulty: String, CaseIterable, Identifiable, Sendable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .beginner: .green
        case .intermediate: .orange
        case .advanced: .red
        }
    }
}

nonisolated struct TennisDrill: Identifiable, Sendable {
    let id: UUID
    let name: String
    let category: TennisDrillCategory
    let difficulty: TennisDrillDifficulty
    let durationMinutes: Int
    let description: String
    let purpose: String
    let equipment: String

    init(name: String, category: TennisDrillCategory, difficulty: TennisDrillDifficulty, durationMinutes: Int, description: String, purpose: String, equipment: String = "Racket, Balls") {
        self.id = UUID()
        self.name = name
        self.category = category
        self.difficulty = difficulty
        self.durationMinutes = durationMinutes
        self.description = description
        self.purpose = purpose
        self.equipment = equipment
    }
}

nonisolated enum TennisDrillLibrary {
    static let all: [TennisDrill] = [
        TennisDrill(name: "Flat Serve Targets", category: .serve, difficulty: .intermediate, durationMinutes: 15, description: "Place targets in the service box corners. Hit 10 flat serves to each target, alternating deuce and ad court.", purpose: "Develop accurate flat serve placement and consistent toss."),
        TennisDrill(name: "Slice Serve Practice", category: .serve, difficulty: .intermediate, durationMinutes: 10, description: "Focus on brushing around the outside of the ball to generate side spin. Aim for wide serves in the deuce court.", purpose: "Add a reliable slice serve to pull opponents off court."),
        TennisDrill(name: "Kick Serve Drill", category: .serve, difficulty: .advanced, durationMinutes: 15, description: "Toss the ball slightly behind your head and brush up to generate heavy topspin. Target the backhand side.", purpose: "Develop a high-bouncing second serve that's difficult to attack."),
        TennisDrill(name: "Serve and Volley Pattern", category: .serve, difficulty: .advanced, durationMinutes: 15, description: "Serve wide, split step at the service line, and put away the volley. Practice on both sides.", purpose: "Build confidence approaching the net behind your serve."),
        TennisDrill(name: "Forehand Cross-Court Rally", category: .groundstroke, difficulty: .beginner, durationMinutes: 10, description: "Rally forehands cross-court with a partner. Focus on depth and consistency. Target 50 balls in a row.", purpose: "Build forehand consistency and develop a reliable rally ball."),
        TennisDrill(name: "Backhand Down-the-Line", category: .groundstroke, difficulty: .intermediate, durationMinutes: 10, description: "Feed balls to your backhand and redirect them down the line. Focus on body rotation and follow-through.", purpose: "Develop the ability to change direction and hit aggressive backhands."),
        TennisDrill(name: "Inside-Out Forehand", category: .groundstroke, difficulty: .advanced, durationMinutes: 15, description: "Move around your backhand to hit forehands from the ad side cross-court. Work on footwork and timing.", purpose: "Master the weapon forehand used by top ATP pros to dominate rallies."),
        TennisDrill(name: "Approach Shot and Finish", category: .groundstroke, difficulty: .intermediate, durationMinutes: 10, description: "Hit a deep groundstroke, move forward on a short ball, hit an approach shot, then finish with a volley.", purpose: "Practice the transition game from baseline to net."),
        TennisDrill(name: "Net Touch Volley Drill", category: .volley, difficulty: .beginner, durationMinutes: 10, description: "Stand at the net and practice catching volleys with a soft touch. Focus on keeping hands in front and punching through.", purpose: "Develop soft hands and proper volley technique."),
        TennisDrill(name: "Reflex Volley Drill", category: .volley, difficulty: .advanced, durationMinutes: 10, description: "Stand close to the net with a partner hitting hard shots. React and block volleys back. Increase pace gradually.", purpose: "Sharpen reflexes and build confidence at the net under pressure."),
        TennisDrill(name: "Overhead Smash Practice", category: .volley, difficulty: .intermediate, durationMinutes: 10, description: "Partner feeds lobs. Practice positioning, timing, and hitting decisive overhead smashes.", purpose: "Develop a reliable overhead to put away lobs confidently."),
        TennisDrill(name: "Split Step and Sprint", category: .footwork, difficulty: .beginner, durationMinutes: 10, description: "Practice the split step timing at the baseline. After each split step, sprint to a cone placed wide on each side.", purpose: "Develop the foundational tennis movement pattern for quick reactions.", equipment: "Cones"),
        TennisDrill(name: "Lateral Recovery Footwork", category: .footwork, difficulty: .intermediate, durationMinutes: 10, description: "Sprint wide to hit a ball, then recover to center with crossover steps. Alternate sides for 3-minute sets.", purpose: "Improve court coverage and recovery speed between shots.", equipment: "Cones, Balls"),
        TennisDrill(name: "Figure-8 Agility", category: .footwork, difficulty: .advanced, durationMinutes: 15, description: "Set up cones in a figure-8 pattern. Sprint through the pattern incorporating split steps, side shuffles, and backpedals.", purpose: "Build elite-level agility and multi-directional movement.", equipment: "Cones"),
        TennisDrill(name: "Pre-Match Visualization", category: .mental, difficulty: .beginner, durationMinutes: 5, description: "Sit quietly and visualize yourself executing your best shots. Imagine winning key points and staying composed under pressure.", purpose: "Build mental confidence and focus before matches.", equipment: "None"),
        TennisDrill(name: "Between-Point Routine", category: .mental, difficulty: .intermediate, durationMinutes: 10, description: "Practice your between-point routine: towel off, bounce the ball, take a breath, then serve. Make it automatic.", purpose: "Develop a consistent routine to manage emotions and reset between points.", equipment: "Racket, Balls"),
        TennisDrill(name: "Court Sprints (Suicides)", category: .conditioning, difficulty: .advanced, durationMinutes: 10, description: "Sprint from baseline to service line and back, then to net and back, then to opposite baseline and back. 6-8 sets.", purpose: "Build tennis-specific endurance and explosive speed.", equipment: "None"),
        TennisDrill(name: "Shadow Swings", category: .conditioning, difficulty: .beginner, durationMinutes: 10, description: "Without a ball, practice full swing mechanics for forehand, backhand, serve, and volley. Focus on form and footwork.", purpose: "Reinforce proper technique and build muscle memory without ball pressure.", equipment: "Racket"),
    ]
}
