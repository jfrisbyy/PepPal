import Foundation
import SwiftUI

// MARK: - Session types

nonisolated enum VolleyballSessionType: String, CaseIterable, Identifiable, Sendable {
    case match = "Match"
    case scrimmage = "Scrimmage"
    case teamPractice = "Team Practice"
    case soloDrill = "Solo Drill"
    case beachSession = "Beach"
    case conditioning = "Conditioning"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .match: "trophy.fill"
        case .scrimmage: "person.3.fill"
        case .teamPractice: "figure.volleyball"
        case .soloDrill: "figure.volleyball.circle"
        case .beachSession: "sun.max.fill"
        case .conditioning: "bolt.heart.fill"
        }
    }

    var isMatch: Bool {
        switch self {
        case .match, .scrimmage: true
        default: false
        }
    }
}

// MARK: - Positions

nonisolated enum VolleyballPosition: String, CaseIterable, Identifiable, Sendable, Codable {
    case outsideHitter = "Outside Hitter"
    case oppositeHitter = "Opposite"
    case middleBlocker = "Middle Blocker"
    case setter = "Setter"
    case libero = "Libero"
    case defensiveSpecialist = "DS"
    case servingSpecialist = "Serve Spec"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .outsideHitter: "OH"
        case .oppositeHitter: "OPP"
        case .middleBlocker: "MB"
        case .setter: "S"
        case .libero: "L"
        case .defensiveSpecialist: "DS"
        case .servingSpecialist: "SS"
        }
    }

    var icon: String {
        switch self {
        case .outsideHitter: "arrow.up.right.circle.fill"
        case .oppositeHitter: "arrow.up.left.circle.fill"
        case .middleBlocker: "shield.lefthalf.filled"
        case .setter: "hand.raised.fingers.spread.fill"
        case .libero: "figure.volleyball"
        case .defensiveSpecialist: "shield.fill"
        case .servingSpecialist: "scope"
        }
    }

    var isAttacker: Bool {
        switch self {
        case .outsideHitter, .oppositeHitter, .middleBlocker: true
        default: false
        }
    }

    var isBackrow: Bool {
        switch self {
        case .libero, .defensiveSpecialist, .servingSpecialist: true
        default: false
        }
    }
}

// MARK: - Match stats

nonisolated struct VolleyballMatchStats: Sendable {
    var kills: Int = 0
    var attackAttempts: Int = 0
    var attackErrors: Int = 0
    var aces: Int = 0
    var serviceErrors: Int = 0
    var blocks: Int = 0
    var blockAssists: Int = 0
    var digs: Int = 0
    var assists: Int = 0
    var receptionPerfect: Int = 0
    var receptionAttempts: Int = 0
    var receptionErrors: Int = 0

    var hittingPercentage: Double {
        guard attackAttempts > 0 else { return 0 }
        return Double(kills - attackErrors) / Double(attackAttempts)
    }

    var killPercentage: Double {
        guard attackAttempts > 0 else { return 0 }
        return Double(kills) / Double(attackAttempts) * 100
    }

    var totalBlocks: Int { blocks + blockAssists }

    var passingRating: Double {
        guard receptionAttempts > 0 else { return 0 }
        let perfectShare = Double(receptionPerfect) / Double(receptionAttempts)
        let errorShare = Double(receptionErrors) / Double(receptionAttempts)
        return max(0, min(3, 1.5 + perfectShare * 1.5 - errorShare * 1.5))
    }
}

// MARK: - Set scores

nonisolated struct VolleyballSetScore: Sendable, Identifiable {
    let id: UUID
    var teamPoints: Int
    var opponentPoints: Int

    init(id: UUID = UUID(), teamPoints: Int = 0, opponentPoints: Int = 0) {
        self.id = id
        self.teamPoints = teamPoints
        self.opponentPoints = opponentPoints
    }

    var teamWon: Bool { teamPoints > opponentPoints }
    var totalPoints: Int { teamPoints + opponentPoints }
}

// MARK: - Match result

nonisolated enum VolleyballMatchResult: String, CaseIterable, Identifiable, Sendable {
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

nonisolated struct VolleyballMatch: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let sessionType: VolleyballSessionType
    let position: VolleyballPosition
    let stats: VolleyballMatchStats
    let sets: [VolleyballSetScore]
    let result: VolleyballMatchResult?
    let opponentName: String
    let venue: String
    let teammates: [String]
    let durationMinutes: Int
    let performanceRating: Int
    let confidenceRating: Int
    let notes: String

    init(
        date: Date = Date(),
        sessionType: VolleyballSessionType = .match,
        position: VolleyballPosition = .outsideHitter,
        stats: VolleyballMatchStats = VolleyballMatchStats(),
        sets: [VolleyballSetScore] = [],
        result: VolleyballMatchResult? = nil,
        opponentName: String = "",
        venue: String = "",
        teammates: [String] = [],
        durationMinutes: Int = 75,
        performanceRating: Int = 5,
        confidenceRating: Int = 5,
        notes: String = ""
    ) {
        self.id = UUID()
        self.date = date
        self.sessionType = sessionType
        self.position = position
        self.stats = stats
        self.sets = sets
        self.result = result
        self.opponentName = opponentName
        self.venue = venue
        self.teammates = teammates
        self.durationMinutes = durationMinutes
        self.performanceRating = performanceRating
        self.confidenceRating = confidenceRating
        self.notes = notes
    }

    var setsWon: Int { sets.filter(\.teamWon).count }
    var setsLost: Int { sets.count - setsWon }

    var scoreDisplay: String {
        guard !sets.isEmpty else { return "" }
        return sets.map { "\($0.teamPoints)-\($0.opponentPoints)" }.joined(separator: ", ")
    }
}

// MARK: - Sport-specific session stats (for SportSpecificStats)

nonisolated struct VolleyballSessionStats: Sendable {
    var kills: Int = 0
    var aces: Int = 0
    var blocks: Int = 0
    var digs: Int = 0
    var assists: Int = 0
    var attackAttempts: Int = 0
    var attackErrors: Int = 0

    var hittingPercentage: Double {
        guard attackAttempts > 0 else { return 0 }
        return Double(kills - attackErrors) / Double(attackAttempts)
    }
}

// MARK: - Drills

nonisolated enum VolleyballDrillCategory: String, CaseIterable, Identifiable, Sendable {
    case serving = "Serving"
    case passing = "Passing"
    case setting = "Setting"
    case attacking = "Attacking"
    case blocking = "Blocking"
    case defense = "Defense"
    case footwork = "Footwork"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .serving: "scope"
        case .passing: "hand.tap.fill"
        case .setting: "hand.raised.fingers.spread.fill"
        case .attacking: "bolt.fill"
        case .blocking: "shield.lefthalf.filled"
        case .defense: "figure.volleyball"
        case .footwork: "figure.run.circle"
        }
    }

    var color: Color {
        switch self {
        case .serving: Color(red: 0.95, green: 0.45, blue: 0.10)
        case .passing: Color(red: 0.20, green: 0.60, blue: 1.00)
        case .setting: Color(red: 0.55, green: 0.36, blue: 0.96)
        case .attacking: Color(red: 0.95, green: 0.30, blue: 0.20)
        case .blocking: Color(red: 0.85, green: 0.25, blue: 0.45)
        case .defense: Color(red: 0.20, green: 0.78, blue: 0.55)
        case .footwork: Color(red: 0.85, green: 0.85, blue: 0.20)
        }
    }
}

nonisolated enum VolleyballDrillDifficulty: String, CaseIterable, Identifiable, Sendable {
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

nonisolated struct VolleyballDrill: Identifiable, Sendable {
    let id: UUID
    let name: String
    let category: VolleyballDrillCategory
    let difficulty: VolleyballDrillDifficulty
    let durationMinutes: Int
    let description: String
    let purpose: String
    let equipment: String
    let steps: [String]
    let cues: [String]
    let setsReps: String?

    init(
        name: String,
        category: VolleyballDrillCategory,
        difficulty: VolleyballDrillDifficulty,
        durationMinutes: Int,
        description: String,
        purpose: String,
        equipment: String = "Ball, Net",
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

nonisolated enum VolleyballDrillLibrary {
    static let all: [VolleyballDrill] = [
        VolleyballDrill(
            name: "Toss & Float Serve",
            category: .serving,
            difficulty: .beginner,
            durationMinutes: 10,
            description: "Develop a consistent low-spin float by perfecting the toss and contact point on a wall or to a partner.",
            purpose: "Build a repeatable, deceptive serve.",
            equipment: "Ball, Wall or Partner",
            steps: [
                "Start with feet shoulder-width, ball in non-hitting hand.",
                "Toss 2-3 feet above hitting shoulder, no spin.",
                "Step into contact with the heel of an open hand.",
                "Strike ball just below center for the float.",
                "Hold follow-through for one beat to lock the form."
            ],
            cues: [
                "Quiet toss, loud contact.",
                "Punch through, don't swing through.",
                "Eyes on the ball at contact."
            ],
            setsReps: "3 sets of 10 serves"
        ),
        VolleyballDrill(
            name: "Target Zone Serving",
            category: .serving,
            difficulty: .intermediate,
            durationMinutes: 12,
            description: "Serve to numbered cones or marker zones across the court — track makes per zone.",
            purpose: "Develop placement and pressure-serving accuracy.",
            steps: [
                "Place targets in zones 1, 5, and 6 across the net.",
                "Serve 5 to each zone, scoring 2 points for direct hits.",
                "Reset and run a second round under fatigue.",
                "Track total: chase 12+ out of 30."
            ],
            cues: [
                "Pick the target before you toss.",
                "Aim small, miss small.",
                "Stay tall through contact."
            ],
            setsReps: "30 serves total"
        ),
        VolleyballDrill(
            name: "Jump Topspin Serve",
            category: .serving,
            difficulty: .advanced,
            durationMinutes: 15,
            description: "Add an explosive approach and topspin contact to weaponize your serve.",
            purpose: "Generate pace and break passers.",
            steps: [
                "Toss high and forward — out into the court.",
                "Three-step approach (left-right-left for righties).",
                "Snap the wrist over the top of the ball.",
                "Land inside the court, balanced.",
                "Track in/out: chase 70% in."
            ],
            cues: [
                "Toss is the serve.",
                "Snap fingers down on the ball.",
                "Reach for the ceiling, finish to the floor."
            ],
            setsReps: "4 sets of 6"
        ),
        VolleyballDrill(
            name: "Wall Pass Repeats",
            category: .passing,
            difficulty: .beginner,
            durationMinutes: 8,
            description: "Pass against a wall continuously, alternating left, right, and centered platforms.",
            purpose: "Build forearm pass consistency and platform awareness.",
            equipment: "Ball, Wall",
            steps: [
                "Stand 6-8 feet from a flat wall.",
                "Pass to the wall, get under the rebound.",
                "Alternate platform angles every 5 reps.",
                "Hit 50 in a row before resting."
            ],
            cues: [
                "Knees over toes, butt down.",
                "Platform forms before the ball arrives.",
                "Angle the platform to the target."
            ],
            setsReps: "3 rounds of 50"
        ),
        VolleyballDrill(
            name: "Pepper with a Twist",
            category: .passing,
            difficulty: .intermediate,
            durationMinutes: 10,
            description: "Classic pepper sequence (pass-set-hit) with a partner, adding directional calls every cycle.",
            purpose: "Sharpen reads, control, and ball-handling rhythm.",
            steps: [
                "Stand 15 feet from your partner.",
                "Pass, set, hit — controlled tempo.",
                "Partner calls 'left' or 'right' before each pass.",
                "Hold for 5 minutes without a drop."
            ],
            cues: [
                "Read the hitter's shoulder.",
                "Cushion the hit, don't fight it.",
                "Stay light on your toes between reps."
            ],
            setsReps: "3 rounds of 5 min"
        ),
        VolleyballDrill(
            name: "Serve Receive Triangle",
            category: .passing,
            difficulty: .advanced,
            durationMinutes: 15,
            description: "Three passers rotate through a receive zone facing live serves; target a perfect-pass percentage.",
            purpose: "Game-speed passing under serve pressure.",
            steps: [
                "Form a serve-receive triangle, target at the setter spot.",
                "Coach or partner serves 30 balls, mixed types.",
                "Score 2 for a 'three' (perfect), 1 for 'two', 0 for 'one'.",
                "Rotate every 10 serves."
            ],
            cues: [
                "Move first, platform second.",
                "Beat the ball to the spot.",
                "Quiet hands at contact — no swing."
            ],
            setsReps: "30 serves"
        ),
        VolleyballDrill(
            name: "Box Setting",
            category: .setting,
            difficulty: .beginner,
            durationMinutes: 10,
            description: "Set repetitions to a 4-foot target box from station 2.",
            purpose: "Lock in hand position and consistent release point.",
            steps: [
                "Stand on the right sideline at station 2.",
                "Toss yourself up and set to the box.",
                "Hit the box 8 of 10 to advance.",
                "Add a step-in for the final round."
            ],
            cues: [
                "Hands shape the ball before contact.",
                "Push, don't slap.",
                "Square hips to the target."
            ],
            setsReps: "5 sets of 10"
        ),
        VolleyballDrill(
            name: "Set & Run Tempo",
            category: .setting,
            difficulty: .intermediate,
            durationMinutes: 12,
            description: "Set, sprint to a marker, recover, and set again — emphasize footwork and posture.",
            purpose: "Conditioning + setting under fatigue.",
            steps: [
                "Set to outside.",
                "Sprint to the 10-foot line, touch, sprint back.",
                "Re-set to outside again.",
                "Run 5-minute rounds."
            ],
            cues: [
                "Beat the ball with your feet.",
                "Square fast, set quiet.",
                "Stay tall on the second set."
            ],
            setsReps: "3 rounds of 5 min"
        ),
        VolleyballDrill(
            name: "Back Set Calibration",
            category: .setting,
            difficulty: .advanced,
            durationMinutes: 15,
            description: "Develop a deceptive, accurate back set for opposite hitters.",
            purpose: "Add a back-set weapon to keep blockers honest.",
            steps: [
                "Coach feeds free balls to the setter.",
                "Set 10 in a row to opposite (deep right).",
                "No telegraph — same arch as the front set.",
                "Track location: chase 8/10 in the antenna corridor."
            ],
            cues: [
                "Arch the back as hands release.",
                "Eyes up, then forward — never spin around.",
                "Push through the shoulders."
            ],
            setsReps: "4 sets of 10"
        ),
        VolleyballDrill(
            name: "Approach Footwork Reps",
            category: .attacking,
            difficulty: .beginner,
            durationMinutes: 10,
            description: "Three-step approach without a ball, focusing on the plant and arm swing.",
            purpose: "Build a fast, balanced approach foundation.",
            equipment: "None",
            steps: [
                "Mark a tape line as the 10-foot line.",
                "Walk through the left-right-left plant 5 times.",
                "Add the arm swing on rep 6.",
                "Build to full speed over 4 minutes."
            ],
            cues: [
                "Last two steps are quick — fast feet.",
                "Arms swing back, then up.",
                "Plant wide, jump tall."
            ],
            setsReps: "30 approach reps"
        ),
        VolleyballDrill(
            name: "Line vs. Cross Hit Mix",
            category: .attacking,
            difficulty: .intermediate,
            durationMinutes: 15,
            description: "Hit half balls to alternating line and cross-court targets off a coach toss.",
            purpose: "Develop shot discipline at game tempo.",
            steps: [
                "Coach calls 'line' or 'cross' before contact.",
                "Hit 6 sets per call, then switch.",
                "Track in-system kills out of 24."
            ],
            cues: [
                "Reach high, contact in front.",
                "Snap wrist toward the target line.",
                "Don't tip the shot — sell the swing."
            ],
            setsReps: "24 swings"
        ),
        VolleyballDrill(
            name: "Hitting Under Pressure",
            category: .attacking,
            difficulty: .advanced,
            durationMinutes: 15,
            description: "Receive a serve, pass, then attack the resulting set with full effort.",
            purpose: "Train kill-conversion in serve-receive sequences.",
            steps: [
                "Coach serves, hitter passes, setter delivers.",
                "Live block on the other side.",
                "Track first-ball kill % across 20 reps.",
                "Switch hitters every 5 reps."
            ],
            cues: [
                "Read the block as you approach.",
                "If they're set, tool them.",
                "Reset fast — every ball is in play."
            ],
            setsReps: "20 reps"
        ),
        VolleyballDrill(
            name: "Block Footwork Slides",
            category: .blocking,
            difficulty: .beginner,
            durationMinutes: 10,
            description: "Side-step blocking footwork between three positions along the net without a ball.",
            purpose: "Quick lateral movement to block any position.",
            steps: [
                "Start at middle blocker spot.",
                "Side-step to outside, jump, land, return.",
                "Add a swing-block on round 3.",
                "Rest 30s between rounds."
            ],
            cues: [
                "Stay square to the net.",
                "Hands stay above shoulders.",
                "Penetrate the net on the jump."
            ],
            setsReps: "5 rounds of 10 reps"
        ),
        VolleyballDrill(
            name: "Read Block Reps",
            category: .blocking,
            difficulty: .intermediate,
            durationMinutes: 12,
            description: "Block live attacks from coach-fed sets, focusing on reading the setter and hitter.",
            purpose: "Improve reads and timing on the block.",
            steps: [
                "Coach sets to alternating positions.",
                "Block as the read suggests.",
                "Track touches and kill-stops out of 20."
            ],
            cues: [
                "Eyes: setter → hitter → ball.",
                "Press the hands over the net.",
                "Land balanced — don't drift."
            ],
            setsReps: "20 reads"
        ),
        VolleyballDrill(
            name: "Triple Block Coordination",
            category: .blocking,
            difficulty: .advanced,
            durationMinutes: 15,
            description: "Three blockers coordinate the close on outside attacks — emphasize seam and timing.",
            purpose: "Lock in team blocking schemes.",
            steps: [
                "Outside blocker sets the angle.",
                "Middle closes hard — no seam.",
                "Right side helps on the high ball.",
                "Run 12 reps with live attacks."
            ],
            cues: [
                "Communicate before the set.",
                "Close to the outsider's hands.",
                "Eyes on the ball through contact."
            ],
            setsReps: "12 reps"
        ),
        VolleyballDrill(
            name: "Dig Pancake Drill",
            category: .defense,
            difficulty: .intermediate,
            durationMinutes: 10,
            description: "Coach tips low and hard — defenders dig or pancake to keep the ball alive.",
            purpose: "Develop emergency defensive instincts.",
            steps: [
                "Defender starts in low ready position.",
                "Coach tips short or rolls the ball.",
                "Get a hand or platform on every ball.",
                "30 reps, then rotate."
            ],
            cues: [
                "Move feet first, hands second.",
                "Stay low until the ball is up.",
                "Sell the pancake — every ball matters."
            ],
            setsReps: "30 reps"
        ),
        VolleyballDrill(
            name: "Read Defense Live",
            category: .defense,
            difficulty: .advanced,
            durationMinutes: 15,
            description: "Read hitters in a 6v6 small-court game with double points for digs.",
            purpose: "Game-speed defensive reads.",
            steps: [
                "Run a half-court 6v6.",
                "Every dig is worth 2 points.",
                "First side to 21.",
                "Reset attackers every 5 points."
            ],
            cues: [
                "Read setter → hitter shoulder.",
                "Stop your feet at contact.",
                "Beat the ball to the floor."
            ],
            setsReps: "15-min game"
        ),
        VolleyballDrill(
            name: "Lateral Speed Ladder",
            category: .footwork,
            difficulty: .beginner,
            durationMinutes: 8,
            description: "Use an agility ladder for in-out, lateral, and crossover patterns.",
            purpose: "Build elite court footwork and quickness.",
            equipment: "Agility Ladder",
            steps: [
                "Run 4 patterns, 3 reps each.",
                "Start slow — tech beats speed.",
                "Build to full speed by rep 3."
            ],
            cues: [
                "Eyes up, not on the ladder.",
                "Stay on the balls of your feet.",
                "Arms drive the legs."
            ],
            setsReps: "4 patterns x 3"
        ),
    ]
}

// MARK: - Drill items / saved sessions

nonisolated struct VolleyballDrillItem: Identifiable, Sendable {
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

nonisolated struct CustomVolleyballSession: Identifiable, Sendable {
    let id: UUID
    var name: String
    var drills: [VolleyballDrillItem]
    let dateCreated: Date

    init(name: String, drills: [VolleyballDrillItem] = [], dateCreated: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.drills = drills
        self.dateCreated = dateCreated
    }

    var totalDuration: Int { drills.reduce(0) { $0 + $1.durationMinutes } }
}
