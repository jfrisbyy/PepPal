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
    let steps: [String]
    let cues: [String]
    let setsReps: String?

    init(
        name: String,
        category: TennisDrillCategory,
        difficulty: TennisDrillDifficulty,
        durationMinutes: Int,
        description: String,
        purpose: String,
        equipment: String = "Racket, Balls",
        steps: [String] = [],
        cues: [String] = [],
        setsReps: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.difficulty = difficulty
        self.durationMinutes = durationMinutes
        self.description = description
        self.purpose = purpose
        self.equipment = equipment
        self.steps = steps
        self.cues = cues
        self.setsReps = setsReps
    }
}

nonisolated enum TennisDrillLibrary {
    static let all: [TennisDrill] = [
        TennisDrill(
            name: "Flat Serve Targets", category: .serve, difficulty: .intermediate, durationMinutes: 15,
            description: "Place targets (cones or towels) in the corners of both service boxes. Hit ten flat first serves at each target before rotating, alternating between deuce and ad sides to mimic match rhythm.",
            purpose: "Develop accurate flat serve placement and a repeatable toss.",
            steps: [
                "Place 4 targets: T and wide on both service boxes.",
                "Begin in the deuce court, focus on a consistent toss out in front.",
                "Hit 10 flat serves to the T, then 10 wide.",
                "Switch to the ad court and repeat.",
                "Track makes vs. misses for each target."
            ],
            cues: ["Loose arm, fast snap", "Toss in front, not above", "Pronate through contact"],
            setsReps: "4 targets · 10 serves each"
        ),
        TennisDrill(
            name: "Slice Serve Practice", category: .serve, difficulty: .intermediate, durationMinutes: 10,
            description: "Brush around the outside of the ball to generate side spin. The ball should curve out wide and skid low — perfect for pulling opponents off the deuce court.",
            purpose: "Add a reliable slice serve to open the court.",
            steps: [
                "Toss slightly out to your hitting side.",
                "Swing low to high but brush the right edge of the ball (right-hander).",
                "Aim for a wide target outside the singles sideline.",
                "Hit 20 reps from the deuce court."
            ],
            cues: ["Brush, don't smash", "Continental grip stays loose", "Follow through across the body"],
            setsReps: "20 reps · deuce side"
        ),
        TennisDrill(
            name: "Kick Serve Drill", category: .serve, difficulty: .advanced, durationMinutes: 15,
            description: "Toss the ball slightly behind your head and brush up the back of the ball to generate heavy topspin. The serve should kick high to the backhand side.",
            purpose: "Develop a high-bouncing second serve that's difficult to attack.",
            steps: [
                "Toss above and slightly behind your head.",
                "Bend the knees deeply and arch the back.",
                "Brush from low to high, 7 to 1 on a clock face.",
                "Aim deep into the service box on the backhand side.",
                "Hit 15 reps per side."
            ],
            cues: ["Brush up, not through", "Hips drive up", "Finish across the body"],
            setsReps: "30 serves total"
        ),
        TennisDrill(
            name: "Serve and Volley Pattern", category: .serve, difficulty: .advanced, durationMinutes: 15,
            description: "Serve wide, split step at the service line, and put away the volley. Practice on both sides to build a complete attacking serve game.",
            purpose: "Build confidence approaching the net behind your serve.",
            steps: [
                "Serve wide from the deuce court.",
                "Sprint forward, split step as opponent strikes.",
                "Move diagonally toward the open court.",
                "Punch volley into the open court."
            ],
            cues: ["Land inside the baseline", "Split step on contact", "Volley with the chest"],
            setsReps: "3 sets of 10 patterns"
        ),
        TennisDrill(
            name: "Forehand Cross-Court Rally", category: .groundstroke, difficulty: .beginner, durationMinutes: 10,
            description: "Rally forehands cross-court with a partner. Focus on depth past the service line and consistency.",
            purpose: "Build forehand consistency and a reliable rally ball.",
            steps: [
                "Both players start at baseline corners.",
                "Rally forehand-to-forehand cross-court.",
                "Aim 3 feet inside the baseline.",
                "Count consecutive shots without missing."
            ],
            cues: ["Early prep, low to high", "Hit through the strike zone", "Recover after every shot"],
            setsReps: "Goal: 50 in a row"
        ),
        TennisDrill(
            name: "Backhand Down-the-Line", category: .groundstroke, difficulty: .intermediate, durationMinutes: 10,
            description: "Feed balls to your backhand and redirect them down the line. Focus on body rotation and a long follow-through.",
            purpose: "Develop the ability to change direction with the backhand.",
            steps: [
                "Partner or coach feeds cross-court to your backhand.",
                "Step in early, take the ball on the rise.",
                "Drive down the line with topspin.",
                "Recover to the middle."
            ],
            cues: ["Shoulder closes early", "Contact in front", "Finish high over the shoulder"],
            setsReps: "3 sets of 12"
        ),
        TennisDrill(
            name: "Inside-Out Forehand", category: .groundstroke, difficulty: .advanced, durationMinutes: 15,
            description: "Move around your backhand to hit forehands from the ad side cross-court. Work on footwork, recovery, and shot tolerance.",
            purpose: "Master the weapon forehand used by top pros to dominate rallies.",
            steps: [
                "Receive ball into the ad-court backhand corner.",
                "Use a quick crossover step to set up forehand.",
                "Drive inside-out to the deuce sideline.",
                "Recover with a hard step toward center."
            ],
            cues: ["Get behind the ball", "Heavy topspin, big margin", "Recover wide of center"],
            setsReps: "4 sets of 8"
        ),
        TennisDrill(
            name: "Approach Shot and Finish", category: .groundstroke, difficulty: .intermediate, durationMinutes: 10,
            description: "Hit a deep groundstroke, move forward on a short ball, hit an approach, then close to the net to finish with a volley.",
            purpose: "Practice the transition game from baseline to net.",
            steps: [
                "Rally from the baseline.",
                "On a short ball, drive an approach down the line.",
                "Close behind it with a split step.",
                "Finish with an angled volley."
            ],
            cues: ["Hit and move", "Slice approach low", "Volley into the open court"],
            setsReps: "3 rounds of 6 patterns"
        ),
        TennisDrill(
            name: "Net Touch Volley Drill", category: .volley, difficulty: .beginner, durationMinutes: 10,
            description: "Stand at the net and practice cushioning volleys with soft hands. Focus on keeping hands in front and punching through with the chest.",
            purpose: "Develop soft hands and proper volley technique.",
            steps: [
                "Set up two players at the net, three meters apart.",
                "Volley back-and-forth with controlled depth.",
                "Alternate forehand and backhand volleys.",
                "Goal: 30 consecutive without a miss."
            ],
            cues: ["Punch, don't swing", "Catch with the racket", "Hands in front of the body"],
            setsReps: "3 sets of 30 volleys"
        ),
        TennisDrill(
            name: "Reflex Volley Drill", category: .volley, difficulty: .advanced, durationMinutes: 10,
            description: "Stand inside the service line while a partner hits hard from the baseline. React and block volleys back, ramping up the pace gradually.",
            purpose: "Sharpen reflexes and build confidence at the net under pressure.",
            steps: [
                "Volleyer at the service line, feeder at baseline.",
                "Feeder rips medium-paced groundstrokes at body.",
                "Block straight back with a short, compact swing.",
                "Increase pace every 30 seconds."
            ],
            cues: ["Eyes on the ball", "Compact, no backswing", "Stay low through contact"],
            setsReps: "4 rounds of 60 seconds"
        ),
        TennisDrill(
            name: "Overhead Smash Practice", category: .volley, difficulty: .intermediate, durationMinutes: 10,
            description: "Partner lobs from the baseline. Use a sideways shuffle, point with the off-hand, and put the ball away decisively.",
            purpose: "Develop a reliable overhead to put away lobs confidently.",
            steps: [
                "Start at the service line.",
                "Partner lobs into the court.",
                "Turn sideways, point with the non-dominant hand.",
                "Smash into an open quadrant."
            ],
            cues: ["Point and track", "Reach high, snap down", "Land balanced"],
            setsReps: "3 sets of 10 smashes"
        ),
        TennisDrill(
            name: "Split Step and Sprint", category: .footwork, difficulty: .beginner, durationMinutes: 10,
            description: "Practice timing the split step at the baseline. After each split, explode out to a cone placed wide on each side.",
            purpose: "Develop the foundational tennis movement pattern.",
            equipment: "Cones",
            steps: [
                "Set cones 4m to either side of the baseline center.",
                "Split step on coach's clap.",
                "Explode laterally to the cone.",
                "Recover with shuffle steps."
            ],
            cues: ["Land balanced on the balls of your feet", "First step explosive", "Stay low"],
            setsReps: "3 rounds of 10 reps"
        ),
        TennisDrill(
            name: "Lateral Recovery Footwork", category: .footwork, difficulty: .intermediate, durationMinutes: 10,
            description: "Sprint wide to hit a ball, then recover to center with crossover steps. Alternate sides for three-minute sets.",
            purpose: "Improve court coverage and recovery speed between shots.",
            equipment: "Cones, Balls",
            steps: [
                "Coach feeds wide to forehand, then to backhand.",
                "Recover with crossover steps to center.",
                "Alternate sides without stopping."
            ],
            cues: ["Recover before settling", "Eyes upcourt", "Long crossover step"],
            setsReps: "3 minutes on, 1 minute off · 3 rounds"
        ),
        TennisDrill(
            name: "Figure-8 Agility", category: .footwork, difficulty: .advanced, durationMinutes: 15,
            description: "Set up cones in a figure-8 pattern. Sprint through the pattern incorporating split steps, side shuffles, and backpedals.",
            purpose: "Build elite multi-directional movement.",
            equipment: "Cones",
            steps: [
                "Place 5 cones in a figure-8.",
                "Sprint, shuffle, and backpedal between cones.",
                "Add a split step between transitions.",
                "Goal: 4 laps under 60 seconds."
            ],
            cues: ["Stay low through transitions", "Drive arms", "Quick feet at every cone"],
            setsReps: "4 rounds, full recovery"
        ),
        TennisDrill(
            name: "Pre-Match Visualization", category: .mental, difficulty: .beginner, durationMinutes: 5,
            description: "Sit quietly and visualize yourself executing your best shots. Imagine winning key points and staying composed under pressure.",
            purpose: "Build mental confidence and focus before matches.",
            equipment: "None",
            steps: [
                "Find a quiet spot, eyes closed.",
                "Breathe deeply for 60 seconds.",
                "Visualize your serve, your best forehand, a tough rally won.",
                "See yourself stay composed at deuce."
            ],
            cues: ["See it before you play it", "Slow, deep breaths", "Feel the racket in your hand"],
            setsReps: "5 minutes"
        ),
        TennisDrill(
            name: "Between-Point Routine", category: .mental, difficulty: .intermediate, durationMinutes: 10,
            description: "Practice your full between-point routine: towel off, bounce the ball, take a breath, set up the next point. Make it automatic so it travels with you under pressure.",
            purpose: "Develop a routine that resets emotions and locks focus.",
            steps: [
                "After every point, walk to the back fence.",
                "Towel off if needed.",
                "Take 4 breaths, bounce the ball 3 times.",
                "Step in with intent."
            ],
            cues: ["Same routine, every point", "Slow the heart rate", "One point at a time"],
            setsReps: "Apply for 30 minutes of practice"
        ),
        TennisDrill(
            name: "Court Sprints (Suicides)", category: .conditioning, difficulty: .advanced, durationMinutes: 10,
            description: "Sprint from baseline to service line and back, then to net and back, then to opposite baseline and back. 6-8 full sets.",
            purpose: "Build tennis-specific endurance and explosive speed.",
            equipment: "None",
            steps: [
                "Start at the baseline.",
                "Sprint to the service line and back.",
                "Sprint to the net and back.",
                "Sprint to the far baseline and back.",
                "Rest 60 seconds. Repeat."
            ],
            cues: ["Touch every line", "Drive arms", "Breathe in rhythm"],
            setsReps: "6-8 rounds, 60s rest"
        ),
        TennisDrill(
            name: "Shadow Swings", category: .conditioning, difficulty: .beginner, durationMinutes: 10,
            description: "Without a ball, practice full swing mechanics for forehand, backhand, serve, and volley. Focus on form, footwork, and rhythm.",
            purpose: "Reinforce technique and build muscle memory without ball pressure.",
            equipment: "Racket",
            steps: [
                "Forehand shadow swings — 25 reps.",
                "Backhand shadow swings — 25 reps.",
                "Serve motion — 15 reps.",
                "Volley footwork — 20 reps."
            ],
            cues: ["Slow it down to feel the motion", "Add footwork to every rep", "Finish balanced"],
            setsReps: "3 sets total"
        ),
    ]
}
