import Foundation
import SwiftUI

// MARK: - Session types

nonisolated enum PickleballSessionType: String, CaseIterable, Identifiable, Sendable {
    case match = "Match"
    case openPlay = "Open Play"
    case drilling = "Drilling"
    case dinkSession = "Dink Session"
    case lesson = "Lesson"
    case conditioning = "Conditioning"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .match: "trophy.fill"
        case .openPlay: "person.3.fill"
        case .drilling: "scope"
        case .dinkSession: "circle.dotted"
        case .lesson: "graduationcap.fill"
        case .conditioning: "bolt.heart.fill"
        }
    }

    var isMatch: Bool {
        switch self {
        case .match, .openPlay: true
        default: false
        }
    }
}

// MARK: - Format & side

nonisolated enum PickleballFormat: String, CaseIterable, Identifiable, Sendable, Codable {
    case singles = "Singles"
    case doubles = "Doubles"
    case mixedDoubles = "Mixed"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .singles: "1s"
        case .doubles: "2s"
        case .mixedDoubles: "Mxd"
        }
    }

    var icon: String {
        switch self {
        case .singles: "person.fill"
        case .doubles: "person.2.fill"
        case .mixedDoubles: "person.2.crop.square.stack.fill"
        }
    }
}

nonisolated enum PickleballSide: String, CaseIterable, Identifiable, Sendable, Codable {
    case left = "Left"
    case right = "Right"
    case ambi = "Ambi"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .left: "L"
        case .right: "R"
        case .ambi: "A"
        }
    }

    var icon: String {
        switch self {
        case .left: "arrow.left.circle.fill"
        case .right: "arrow.right.circle.fill"
        case .ambi: "arrow.left.and.right.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .left: "Left-side specialist (backhand corner)"
        case .right: "Right-side specialist (forehand corner)"
        case .ambi: "Comfortable on either side"
        }
    }
}

// MARK: - Match stats

nonisolated struct PickleballMatchStats: Sendable {
    var winners: Int = 0
    var unforcedErrors: Int = 0
    var aces: Int = 0
    var serviceFaults: Int = 0
    var thirdShotDropsAttempted: Int = 0
    var thirdShotDropsMade: Int = 0
    var dinksWon: Int = 0
    var dinksLost: Int = 0
    var kitchenViolations: Int = 0
    var atpHits: Int = 0
    var ernes: Int = 0
    var blockVolleysWon: Int = 0
    var firstServeIn: Int = 0
    var firstServeAttempts: Int = 0
    var returnPointsWon: Int = 0
    var returnPointsPlayed: Int = 0

    var thirdShotDropPercentage: Double {
        guard thirdShotDropsAttempted > 0 else { return 0 }
        return Double(thirdShotDropsMade) / Double(thirdShotDropsAttempted)
    }

    var firstServePercentage: Double {
        guard firstServeAttempts > 0 else { return 0 }
        return Double(firstServeIn) / Double(firstServeAttempts)
    }

    var dinkWinPercentage: Double {
        let total = dinksWon + dinksLost
        guard total > 0 else { return 0 }
        return Double(dinksWon) / Double(total)
    }

    var returnPointPercentage: Double {
        guard returnPointsPlayed > 0 else { return 0 }
        return Double(returnPointsWon) / Double(returnPointsPlayed)
    }

    /// Simple W:UE ratio — anything above 1.0 is winning the rally exchange.
    var winnerToErrorRatio: Double {
        guard unforcedErrors > 0 else { return Double(winners) }
        return Double(winners) / Double(unforcedErrors)
    }
}

// MARK: - Game scores

nonisolated struct PickleballGameScore: Sendable, Identifiable {
    let id: UUID
    var teamPoints: Int
    var opponentPoints: Int
    var targetPoints: Int

    init(id: UUID = UUID(), teamPoints: Int = 0, opponentPoints: Int = 0, targetPoints: Int = 11) {
        self.id = id
        self.teamPoints = teamPoints
        self.opponentPoints = opponentPoints
        self.targetPoints = targetPoints
    }

    var teamWon: Bool {
        teamPoints >= targetPoints && teamPoints - opponentPoints >= 2
    }

    var totalPoints: Int { teamPoints + opponentPoints }
}

// MARK: - Match result

nonisolated enum PickleballMatchResult: String, CaseIterable, Identifiable, Sendable {
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

// MARK: - Match record

nonisolated struct PickleballMatch: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let sessionType: PickleballSessionType
    let format: PickleballFormat
    let side: PickleballSide
    let stats: PickleballMatchStats
    let games: [PickleballGameScore]
    let result: PickleballMatchResult?
    let opponentName: String
    let partnerName: String
    let venue: String
    let durationMinutes: Int
    let energyRating: Int
    let footworkRating: Int
    let confidenceRating: Int
    let dupr: Double?
    let notes: String

    init(
        date: Date = Date(),
        sessionType: PickleballSessionType = .match,
        format: PickleballFormat = .doubles,
        side: PickleballSide = .right,
        stats: PickleballMatchStats = PickleballMatchStats(),
        games: [PickleballGameScore] = [],
        result: PickleballMatchResult? = nil,
        opponentName: String = "",
        partnerName: String = "",
        venue: String = "",
        durationMinutes: Int = 60,
        energyRating: Int = 5,
        footworkRating: Int = 5,
        confidenceRating: Int = 5,
        dupr: Double? = nil,
        notes: String = ""
    ) {
        self.id = UUID()
        self.date = date
        self.sessionType = sessionType
        self.format = format
        self.side = side
        self.stats = stats
        self.games = games
        self.result = result
        self.opponentName = opponentName
        self.partnerName = partnerName
        self.venue = venue
        self.durationMinutes = durationMinutes
        self.energyRating = energyRating
        self.footworkRating = footworkRating
        self.confidenceRating = confidenceRating
        self.dupr = dupr
        self.notes = notes
    }

    var gamesWon: Int { games.filter(\.teamWon).count }
    var gamesLost: Int { games.count - gamesWon }

    var scoreDisplay: String {
        guard !games.isEmpty else { return "" }
        return games.map { "\($0.teamPoints)-\($0.opponentPoints)" }.joined(separator: ", ")
    }
}

// MARK: - Drills

nonisolated enum PickleballDrillCategory: String, CaseIterable, Identifiable, Sendable {
    case dinking = "Dinking"
    case thirdShot = "3rd Shot"
    case volleys = "Volleys"
    case serveReturn = "Serve & Return"
    case footwork = "Footwork"
    case strategy = "Strategy"
    case conditioning = "Conditioning"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dinking: "circle.dotted"
        case .thirdShot: "scope"
        case .volleys: "hand.raised.fingers.spread.fill"
        case .serveReturn: "arrow.up.right.circle.fill"
        case .footwork: "figure.run.circle"
        case .strategy: "brain.head.profile"
        case .conditioning: "bolt.heart.fill"
        }
    }

    var color: Color {
        switch self {
        case .dinking: Color(red: 0.62, green: 0.86, blue: 0.18)
        case .thirdShot: Color(red: 0.95, green: 0.55, blue: 0.10)
        case .volleys: Color(red: 0.20, green: 0.60, blue: 1.00)
        case .serveReturn: Color(red: 0.95, green: 0.30, blue: 0.20)
        case .footwork: Color(red: 0.85, green: 0.85, blue: 0.20)
        case .strategy: Color(red: 0.55, green: 0.36, blue: 0.96)
        case .conditioning: Color(red: 0.20, green: 0.78, blue: 0.55)
        }
    }
}

nonisolated enum PickleballDrillDifficulty: String, CaseIterable, Identifiable, Sendable {
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

nonisolated struct PickleballDrill: Identifiable, Sendable {
    let id: UUID
    let name: String
    let category: PickleballDrillCategory
    let difficulty: PickleballDrillDifficulty
    let durationMinutes: Int
    let description: String
    let purpose: String
    let equipment: String
    let steps: [String]
    let cues: [String]
    let setsReps: String?

    init(
        name: String,
        category: PickleballDrillCategory,
        difficulty: PickleballDrillDifficulty,
        durationMinutes: Int,
        description: String,
        purpose: String,
        equipment: String = "Paddle, Ball, Court",
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

nonisolated enum PickleballDrillLibrary {
    static let all: [PickleballDrill] = [
        PickleballDrill(
            name: "Cross-Court Dink Rally",
            category: .dinking,
            difficulty: .beginner,
            durationMinutes: 10,
            description: "Trade controlled cross-court dinks with a partner from kitchen line to kitchen line.",
            purpose: "Build soft-hands feel and consistent dink contact.",
            steps: [
                "Both players at the kitchen line, diagonal corners.",
                "Dink cross-court to the opponent's kitchen.",
                "Stay on the line — no backing up.",
                "Hit 50 in a row before resetting."
            ],
            cues: [
                "Push, don't slap.",
                "Paddle out front, eyes on the ball.",
                "Bend the knees, soft wrist."
            ],
            setsReps: "3 rounds of 50"
        ),
        PickleballDrill(
            name: "Dink to Roll",
            category: .dinking,
            difficulty: .intermediate,
            durationMinutes: 12,
            description: "Dink-dink-roll pattern: two soft dinks then attack a roll volley with topspin.",
            purpose: "Train the transition from soft hands to offensive roll without telegraphing.",
            steps: [
                "Partner feeds dinks to your forehand.",
                "Two controlled dinks, third ball: roll over the net.",
                "Reset and repeat — track makes.",
                "Switch to backhand side."
            ],
            cues: [
                "Lift from below the ball.",
                "Brush up on contact — short stroke.",
                "Stay low, don't pop up."
            ],
            setsReps: "3 sets of 10 rolls per side"
        ),
        PickleballDrill(
            name: "Speed-Up Defense",
            category: .dinking,
            difficulty: .advanced,
            durationMinutes: 12,
            description: "Partner randomly speeds up a dink mid-rally; you reset back to a soft dink.",
            purpose: "Train hands and patience under pressure attacks.",
            steps: [
                "Trade dinks at the kitchen.",
                "Partner attacks any dink at random.",
                "Block the speed-up softly back into the kitchen.",
                "Track resets out of 20."
            ],
            cues: [
                "Paddle up, hands ready.",
                "Absorb — don't punch back.",
                "Calm chest, quiet feet."
            ],
            setsReps: "3 rounds of 20 attacks"
        ),
        PickleballDrill(
            name: "Drop & Move",
            category: .thirdShot,
            difficulty: .beginner,
            durationMinutes: 10,
            description: "Hit a third-shot drop, then sprint to the kitchen line behind the ball.",
            purpose: "Build the foundation move of the modern game.",
            equipment: "Paddle, Ball, Court (full)",
            steps: [
                "Start at the baseline.",
                "Coach feeds a return; hit a soft drop into the kitchen.",
                "Sprint forward, split-step, dink the next ball.",
                "Reset and repeat."
            ],
            cues: [
                "Low-to-high lift, no power.",
                "Watch the ball off your strings.",
                "First step is your fastest step."
            ],
            setsReps: "20 drops"
        ),
        PickleballDrill(
            name: "Drop vs. Drive Decision",
            category: .thirdShot,
            difficulty: .intermediate,
            durationMinutes: 15,
            description: "Read the return depth and choose drop or drive accordingly off the third ball.",
            purpose: "Learn shot selection on the third shot, the highest-leverage shot in pickleball.",
            steps: [
                "Partner returns deep or short randomly.",
                "Deep return: drive low and hard.",
                "Short return: drop and follow in.",
                "Track decision accuracy out of 20."
            ],
            cues: [
                "Feet decide before hands.",
                "Drive flat, drop arched.",
                "Don't force the drop on a deep return."
            ],
            setsReps: "20 decisions"
        ),
        PickleballDrill(
            name: "Five-Ball Drop Ladder",
            category: .thirdShot,
            difficulty: .advanced,
            durationMinutes: 15,
            description: "String five consecutive drops together — drop, dink, dink, drop, dink.",
            purpose: "Sharpen the drop under fatigue and pressure.",
            steps: [
                "Coach feeds a deep return.",
                "Hit the drop, follow in two steps.",
                "Two dinks, then the coach lobs you back.",
                "Drop again, finish the rally with a dink.",
                "5 sequences in a row."
            ],
            cues: [
                "Same swing every time.",
                "Stay tall through contact.",
                "Patience — the drop is a setup, not a winner."
            ],
            setsReps: "5 ladders, 3 rounds"
        ),
        PickleballDrill(
            name: "Volley Wall Repeat",
            category: .volleys,
            difficulty: .beginner,
            durationMinutes: 8,
            description: "Stand 6 feet from a wall and volley continuously, alternating forehand and backhand.",
            purpose: "Build paddle stability and quick hands.",
            equipment: "Paddle, Ball, Wall",
            steps: [
                "Start with paddle out front.",
                "Volley to the wall, no swing.",
                "Alternate FH/BH every 5 hits.",
                "Build to 100 in a row."
            ],
            cues: [
                "Paddle face first.",
                "Punch, don't swing.",
                "Eyes on contact."
            ],
            setsReps: "3 rounds of 100"
        ),
        PickleballDrill(
            name: "Hands Battle",
            category: .volleys,
            difficulty: .intermediate,
            durationMinutes: 10,
            description: "Both players at the kitchen line — fast-hands volley exchange, no dinks.",
            purpose: "Train reaction speed and paddle position in a firefight.",
            steps: [
                "Both at the kitchen line, 12 feet apart.",
                "Coach feeds a punch volley.",
                "Trade hard volleys until one misses.",
                "First to 11 wins."
            ],
            cues: [
                "Paddle in the middle of your chest.",
                "Block first, attack second.",
                "Stay tall — don't crouch."
            ],
            setsReps: "Race to 11"
        ),
        PickleballDrill(
            name: "Topspin Roll Volleys",
            category: .volleys,
            difficulty: .advanced,
            durationMinutes: 12,
            description: "Take dinks above net height and roll them with topspin into the kitchen.",
            purpose: "Add the offensive roll volley as a finishing tool.",
            steps: [
                "Partner feeds a high dink.",
                "Step in, brush up on the ball.",
                "Aim deep into the kitchen with spin.",
                "Track makes vs. errors out of 30."
            ],
            cues: [
                "Low-to-high paddle path.",
                "Short backswing, long follow-through.",
                "Don't overhit — control then power."
            ],
            setsReps: "30 rolls"
        ),
        PickleballDrill(
            name: "Deep Serve Targets",
            category: .serveReturn,
            difficulty: .beginner,
            durationMinutes: 10,
            description: "Serve to deep target zones (cones placed at the back two feet of the box).",
            purpose: "Build a deep, consistent serve that pins the returner.",
            equipment: "Paddle, Balls, Cones",
            steps: [
                "Place cones in the back two feet of the service box.",
                "Serve 20 balls; score 1 per cone strike, 0.5 for deep box.",
                "Track total — chase 12+ out of 20."
            ],
            cues: [
                "Drop and contact below the waist.",
                "Smooth pendulum swing.",
                "Toss ball forward, not up."
            ],
            setsReps: "20 serves"
        ),
        PickleballDrill(
            name: "Return & Crash",
            category: .serveReturn,
            difficulty: .intermediate,
            durationMinutes: 12,
            description: "Hit a deep, high return and immediately rush to the kitchen line.",
            purpose: "Lock in the return-and-attack move that takes the kitchen.",
            steps: [
                "Partner serves; you return high and deep.",
                "Sprint to the kitchen line, split-step.",
                "Dink or volley the next ball.",
                "Track times you arrived before the third shot."
            ],
            cues: [
                "High loop — give yourself time.",
                "Move while the ball is still in the air.",
                "Split-step at the line."
            ],
            setsReps: "15 returns"
        ),
        PickleballDrill(
            name: "Spin Serve Mix",
            category: .serveReturn,
            difficulty: .advanced,
            durationMinutes: 15,
            description: "Mix flat, slice, and topspin serves to deep targets without telegraphing.",
            purpose: "Develop a serve arsenal that disrupts return rhythm.",
            steps: [
                "Pick three serves: flat, slice, topspin.",
                "Random order, 5 each round.",
                "Score in for placement.",
                "30 serves total."
            ],
            cues: [
                "Same setup, different finish.",
                "Hide the spin until contact.",
                "Commit fully — no half spins."
            ],
            setsReps: "30 serves"
        ),
        PickleballDrill(
            name: "Split-Step Reaction",
            category: .footwork,
            difficulty: .beginner,
            durationMinutes: 8,
            description: "Coach points left or right; you split-step and shuffle that direction.",
            purpose: "Build the foundation move for kitchen-line defense.",
            equipment: "None",
            steps: [
                "Stand at the kitchen line, paddle ready.",
                "Coach points; split-step then shuffle 2 feet.",
                "Recover, repeat.",
                "30 reps, 30 seconds rest."
            ],
            cues: [
                "Stay low — chest over toes.",
                "Land on the balls of your feet.",
                "Recover before the next call."
            ],
            setsReps: "3 rounds of 30"
        ),
        PickleballDrill(
            name: "Kitchen Slide Series",
            category: .footwork,
            difficulty: .intermediate,
            durationMinutes: 10,
            description: "Side-shuffle the kitchen line tracking dinks pulled side to side.",
            purpose: "Stay balanced and on the line through full-court dinks.",
            steps: [
                "Partner pulls dinks corner to corner.",
                "Shuffle, never crossover.",
                "Stay 4-6 inches off the line.",
                "Track 30 reps."
            ],
            cues: [
                "Shoulders square to the net.",
                "Don't lunge — slide.",
                "Recover to center after each."
            ],
            setsReps: "30 dinks"
        ),
        PickleballDrill(
            name: "Stack & Switch",
            category: .strategy,
            difficulty: .intermediate,
            durationMinutes: 12,
            description: "Practice stacking and switching with your doubles partner.",
            purpose: "Keep your strong side / forehand in the middle.",
            steps: [
                "Set the stack: both partners on the same side at start.",
                "Switch on the serve and return.",
                "Communicate the call before every point.",
                "Run 10 sequences cleanly."
            ],
            cues: [
                "Talk before the serve.",
                "Switch fast, then settle.",
                "Forehand owns the middle."
            ],
            setsReps: "10 sequences"
        ),
        PickleballDrill(
            name: "Erne & ATP Drill",
            category: .strategy,
            difficulty: .advanced,
            durationMinutes: 12,
            description: "Practice spotting and executing the Erne and Around-the-Post shot.",
            purpose: "Add elite finishing tools to your kitchen game.",
            steps: [
                "Partner dinks short and wide.",
                "Read the angle: jump the kitchen for an Erne, or sprint wide for an ATP.",
                "Track makes out of 10 each side.",
                "Reset to neutral after every rep."
            ],
            cues: [
                "Read early, commit fully.",
                "ATP: get low, hit it long.",
                "Erne: take off from outside the kitchen."
            ],
            setsReps: "20 attempts"
        ),
        PickleballDrill(
            name: "Court Sprint Triangle",
            category: .conditioning,
            difficulty: .intermediate,
            durationMinutes: 10,
            description: "Sprint baseline → kitchen → opposite kitchen corner → back; repeat under time.",
            purpose: "Train pickleball-specific change-of-direction conditioning.",
            equipment: "Court, Cones",
            steps: [
                "Set cones at baseline center, kitchen center, far kitchen corner.",
                "Sprint the triangle as fast as possible.",
                "Rest 30s, repeat 5 times.",
                "Track best lap."
            ],
            cues: [
                "Drive the first three steps.",
                "Plant outside foot to change direction.",
                "Light landings — protect knees."
            ],
            setsReps: "5 sets"
        ),
        PickleballDrill(
            name: "30-Ball Reaction Burnout",
            category: .conditioning,
            difficulty: .advanced,
            durationMinutes: 12,
            description: "Coach feeds 30 balls in 60 seconds — alternating volleys, dinks, and resets.",
            purpose: "Build pickleball-specific stamina under fatigue.",
            steps: [
                "Stand at kitchen line.",
                "Coach feeds rapidly for 60 seconds.",
                "Mix volley, dink, reset.",
                "Rest 90s. Repeat 4 rounds."
            ],
            cues: [
                "Recover paddle every shot.",
                "Breathe between feeds.",
                "Don't quit on the last 5."
            ],
            setsReps: "4 rounds"
        ),
    ]
}

// MARK: - Drill items / saved sessions

nonisolated struct PickleballDrillItem: Identifiable, Sendable {
    let id: UUID
    var drillName: String
    var durationMinutes: Int
    var notes: String

    init(drillName: String, durationMinutes: Int, notes: String = "") {
        self.id = UUID()
        self.drillName = drillName
        self.durationMinutes = durationMinutes
        self.notes = notes
    }
}

nonisolated struct CustomPickleballSession: Identifiable, Sendable {
    let id: UUID
    var name: String
    var drills: [PickleballDrillItem]
    let dateCreated: Date

    init(name: String, drills: [PickleballDrillItem] = [], dateCreated: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.drills = drills
        self.dateCreated = dateCreated
    }

    var totalDuration: Int { drills.reduce(0) { $0 + $1.durationMinutes } }
}
