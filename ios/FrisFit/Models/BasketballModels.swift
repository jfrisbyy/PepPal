import Foundation
import SwiftUI

// MARK: - Palette

nonisolated enum BasketballPalette {
    static let courtOrange = Color(red: 1.0, green: 0.55, blue: 0.1)
    static let courtAmber = Color(red: 0.96, green: 0.72, blue: 0.20)
    static let leather = Color(red: 0.55, green: 0.30, blue: 0.12)
    static let netWhite = Color(red: 0.96, green: 0.93, blue: 0.86)
    static let hardwood = Color(red: 0.85, green: 0.55, blue: 0.18)
}

// MARK: - Session Type

nonisolated enum BasketballSessionType: String, CaseIterable, Identifiable, Sendable {
    case fullGame5v5 = "5v5 Game"
    case fullGame3v3 = "3v3 Game"
    case pickupGame = "Pickup"
    case soloShooting = "Solo Shooting"
    case skillsPractice = "Skills Practice"
    case teamPractice = "Team Practice"
    case conditioning = "Conditioning"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .fullGame5v5: "sportscourt.fill"
        case .fullGame3v3: "person.3.fill"
        case .pickupGame: "basketball.fill"
        case .soloShooting: "scope"
        case .skillsPractice: "figure.basketball"
        case .teamPractice: "person.2.fill"
        case .conditioning: "bolt.heart.fill"
        }
    }

    var isGame: Bool {
        switch self {
        case .fullGame5v5, .fullGame3v3, .pickupGame: true
        default: false
        }
    }

    /// Approximate intensity (1–10) used by the calorie estimator.
    var defaultIntensity: Int {
        switch self {
        case .fullGame5v5: 8
        case .fullGame3v3: 8
        case .pickupGame: 7
        case .soloShooting: 4
        case .skillsPractice: 6
        case .teamPractice: 6
        case .conditioning: 9
        }
    }

    /// Casual-friendly verb used on the dashboard ("logged a run", "shot around").
    var casualVerb: String {
        switch self {
        case .fullGame5v5, .fullGame3v3, .pickupGame: "Hooped"
        case .soloShooting: "Shot around"
        case .skillsPractice: "Worked on skills"
        case .teamPractice: "Team practice"
        case .conditioning: "Conditioning"
        }
    }
}

nonisolated enum GameResult: String, CaseIterable, Identifiable, Sendable {
    case win = "W"
    case loss = "L"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .win: .green
        case .loss: .red
        }
    }
}

// MARK: - Shot Chart

nonisolated enum ShotZone: String, CaseIterable, Identifiable, Sendable {
    case paint = "Paint"
    case midRangeLeft = "Mid Left"
    case midRangeRight = "Mid Right"
    case freeThrow = "Free Throw"
    case leftElbow = "Left Elbow"
    case rightElbow = "Right Elbow"
    case leftBaseline = "Left Baseline"
    case rightBaseline = "Right Baseline"
    case topOfKey = "Top of Key"
    case leftWing3 = "Left Wing 3"
    case rightWing3 = "Right Wing 3"
    case leftCorner3 = "Left Corner 3"
    case rightCorner3 = "Right Corner 3"
    case topArc3 = "Top Arc 3"

    var id: String { rawValue }

    var isThreePointer: Bool {
        switch self {
        case .leftWing3, .rightWing3, .leftCorner3, .rightCorner3, .topArc3: true
        default: false
        }
    }

    var position: CGPoint {
        switch self {
        case .paint: CGPoint(x: 0.5, y: 0.82)
        case .freeThrow: CGPoint(x: 0.5, y: 0.68)
        case .midRangeLeft: CGPoint(x: 0.25, y: 0.7)
        case .midRangeRight: CGPoint(x: 0.75, y: 0.7)
        case .leftElbow: CGPoint(x: 0.3, y: 0.6)
        case .rightElbow: CGPoint(x: 0.7, y: 0.6)
        case .leftBaseline: CGPoint(x: 0.15, y: 0.82)
        case .rightBaseline: CGPoint(x: 0.85, y: 0.82)
        case .topOfKey: CGPoint(x: 0.5, y: 0.52)
        case .leftWing3: CGPoint(x: 0.18, y: 0.5)
        case .rightWing3: CGPoint(x: 0.82, y: 0.5)
        case .leftCorner3: CGPoint(x: 0.08, y: 0.78)
        case .rightCorner3: CGPoint(x: 0.92, y: 0.78)
        case .topArc3: CGPoint(x: 0.5, y: 0.38)
        }
    }
}

nonisolated struct ShotChartEntry: Identifiable, Sendable {
    let id: UUID
    let zone: ShotZone
    let made: Bool

    init(zone: ShotZone, made: Bool) {
        self.id = UUID()
        self.zone = zone
        self.made = made
    }
}

// MARK: - Stats

nonisolated struct BasketballGameStats: Sendable {
    var points: Int = 0
    var fieldGoalsMade: Int = 0
    var fieldGoalsAttempted: Int = 0
    var threePointersMade: Int = 0
    var threePointersAttempted: Int = 0
    var freeThrowsMade: Int = 0
    var freeThrowsAttempted: Int = 0
    var offensiveRebounds: Int = 0
    var defensiveRebounds: Int = 0
    var assists: Int = 0
    var steals: Int = 0
    var blocks: Int = 0
    var turnovers: Int = 0
    var minutesPlayed: Int = 0

    var totalRebounds: Int { offensiveRebounds + defensiveRebounds }

    var fieldGoalPercentage: Double {
        fieldGoalsAttempted > 0 ? Double(fieldGoalsMade) / Double(fieldGoalsAttempted) * 100 : 0
    }

    var threePointPercentage: Double {
        threePointersAttempted > 0 ? Double(threePointersMade) / Double(threePointersAttempted) * 100 : 0
    }

    var freeThrowPercentage: Double {
        freeThrowsAttempted > 0 ? Double(freeThrowsMade) / Double(freeThrowsAttempted) * 100 : 0
    }

    var hasAnyStats: Bool {
        points + fieldGoalsAttempted + freeThrowsAttempted + offensiveRebounds + defensiveRebounds + assists + steals + blocks + turnovers > 0
    }

    var gameScore: Double {
        Double(points) + 0.4 * Double(fieldGoalsMade) - 0.7 * Double(fieldGoalsAttempted) +
        0.7 * Double(offensiveRebounds) + 0.3 * Double(defensiveRebounds) +
        Double(steals) + 0.7 * Double(assists) + 0.7 * Double(blocks) -
        0.4 * Double(freeThrowsAttempted - freeThrowsMade) - Double(turnovers)
    }
}

// MARK: - Game / Run

nonisolated struct BasketballGame: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let sessionType: BasketballSessionType
    let stats: BasketballGameStats
    let result: GameResult?
    let teamScore: Int?
    let opponentScore: Int?
    let durationMinutes: Int
    let shotChart: [ShotChartEntry]
    let confidenceRating: Int
    let performanceRating: Int
    let notes: String

    // New casual-mode fields (local-only, defaulted for backward compat).
    let location: String
    let partners: [String]
    let energyRating: Int
    let legsRating: Int
    let vibeRating: Int
    let drillsCompleted: [String]
    let caloriesBurned: Int

    init(
        date: Date = Date(),
        sessionType: BasketballSessionType = .pickupGame,
        stats: BasketballGameStats = BasketballGameStats(),
        result: GameResult? = nil,
        teamScore: Int? = nil,
        opponentScore: Int? = nil,
        durationMinutes: Int = 60,
        shotChart: [ShotChartEntry] = [],
        confidenceRating: Int = 5,
        performanceRating: Int = 5,
        notes: String = "",
        location: String = "",
        partners: [String] = [],
        energyRating: Int = 5,
        legsRating: Int = 5,
        vibeRating: Int = 5,
        drillsCompleted: [String] = [],
        caloriesBurned: Int = 0
    ) {
        self.id = UUID()
        self.date = date
        self.sessionType = sessionType
        self.stats = stats
        self.result = result
        self.teamScore = teamScore
        self.opponentScore = opponentScore
        self.durationMinutes = durationMinutes
        self.shotChart = shotChart
        self.confidenceRating = confidenceRating
        self.performanceRating = performanceRating
        self.notes = notes
        self.location = location
        self.partners = partners
        self.energyRating = energyRating
        self.legsRating = legsRating
        self.vibeRating = vibeRating
        self.drillsCompleted = drillsCompleted
        self.caloriesBurned = caloriesBurned
    }
}

// MARK: - Drills

nonisolated enum DrillCategory: String, CaseIterable, Identifiable, Sendable {
    case shooting = "Shooting"
    case ballHandling = "Ball Handling"
    case defense = "Defense"
    case conditioning = "Conditioning"
    case finishing = "Finishing"
    case footwork = "Footwork"
    case iq = "IQ"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .shooting: "scope"
        case .ballHandling: "hand.raised.fingers.spread.fill"
        case .defense: "shield.lefthalf.filled"
        case .conditioning: "bolt.heart.fill"
        case .finishing: "basketball.fill"
        case .footwork: "shoeprints.fill"
        case .iq: "brain.head.profile"
        }
    }

    var color: Color {
        switch self {
        case .shooting: BasketballPalette.courtOrange
        case .ballHandling: Color(red: 0.20, green: 0.60, blue: 1.0)
        case .defense: Color(red: 0.85, green: 0.25, blue: 0.25)
        case .conditioning: Color(red: 0.85, green: 0.90, blue: 0.15)
        case .finishing: Color(red: 0.20, green: 0.78, blue: 0.35)
        case .footwork: Color(red: 0.78, green: 0.45, blue: 0.95)
        case .iq: Color(red: 0.55, green: 0.85, blue: 0.95)
        }
    }
}

nonisolated enum DrillDifficulty: String, CaseIterable, Identifiable, Sendable {
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

nonisolated enum DrillEquipment: String, CaseIterable, Identifiable, Sendable {
    case hoop = "Hoop"
    case noHoop = "No Hoop"
    case partner = "Partner"
    case ball = "Ball Only"
    case cones = "Cones"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .hoop: "basketball.fill"
        case .noHoop: "figure.run"
        case .partner: "person.2.fill"
        case .ball: "circle.fill"
        case .cones: "cone.fill"
        }
    }
}

nonisolated enum DrillMastery: String, CaseIterable, Identifiable, Sendable, Codable {
    case touched = "Touched"
    case working = "Working"
    case sharp = "Sharp"
    case lockedIn = "Locked-in"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .touched: Color(red: 0.55, green: 0.55, blue: 0.55)
        case .working: BasketballPalette.courtAmber
        case .sharp: Color(red: 0.20, green: 0.78, blue: 0.35)
        case .lockedIn: BasketballPalette.courtOrange
        }
    }

    var progress: Double {
        switch self {
        case .touched: 0.25
        case .working: 0.50
        case .sharp: 0.75
        case .lockedIn: 1.0
        }
    }

    static func forSessionCount(_ count: Int) -> DrillMastery {
        switch count {
        case 0...1: .touched
        case 2...4: .working
        case 5...9: .sharp
        default: .lockedIn
        }
    }
}

nonisolated struct BasketballDrill: Identifiable, Sendable {
    let id: UUID
    let slug: String
    let name: String
    let category: DrillCategory
    let difficulty: DrillDifficulty
    let durationMinutes: Int
    let equipment: [DrillEquipment]
    let purpose: String
    let description: String
    let steps: [String]
    let cues: [String]
    let setsReps: String?

    init(
        slug: String,
        name: String,
        category: DrillCategory,
        difficulty: DrillDifficulty,
        durationMinutes: Int,
        equipment: [DrillEquipment],
        purpose: String,
        description: String,
        steps: [String] = [],
        cues: [String] = [],
        setsReps: String? = nil
    ) {
        self.id = UUID()
        self.slug = slug
        self.name = name
        self.category = category
        self.difficulty = difficulty
        self.durationMinutes = durationMinutes
        self.equipment = equipment
        self.purpose = purpose
        self.description = description
        self.steps = steps
        self.cues = cues
        self.setsReps = setsReps
    }
}

nonisolated struct PracticePlanDrill: Identifiable, Sendable {
    let id: UUID
    let drill: BasketballDrill
    var isCompleted: Bool

    init(drill: BasketballDrill, isCompleted: Bool = false) {
        self.id = UUID()
        self.drill = drill
        self.isCompleted = isCompleted
    }
}

nonisolated struct PracticePlan: Identifiable, Sendable {
    let id: UUID
    var name: String
    var drills: [PracticePlanDrill]
    let dateCreated: Date
    let isTemplate: Bool
    let templateBlurb: String

    init(
        name: String,
        drills: [PracticePlanDrill] = [],
        dateCreated: Date = Date(),
        isTemplate: Bool = false,
        templateBlurb: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.drills = drills
        self.dateCreated = dateCreated
        self.isTemplate = isTemplate
        self.templateBlurb = templateBlurb
    }

    var totalDuration: Int {
        drills.reduce(0) { $0 + $1.drill.durationMinutes }
    }

    var completedCount: Int {
        drills.filter(\.isCompleted).count
    }
}

// MARK: - Goals & Focus

nonisolated enum BasketballGoalType: String, CaseIterable, Identifiable, Sendable, Codable {
    case sessionsPerWeek = "Sessions / Week"
    case minutesPerWeek = "Minutes / Week"
    case shotsPerWeek = "Shots Made / Week"
    case drillsPerWeek = "Drills / Week"
    case streakDays = "Streak Days"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .sessionsPerWeek: "calendar"
        case .minutesPerWeek: "clock.fill"
        case .shotsPerWeek: "scope"
        case .drillsPerWeek: "list.bullet.rectangle"
        case .streakDays: "flame.fill"
        }
    }

    var color: Color {
        switch self {
        case .sessionsPerWeek: BasketballPalette.courtOrange
        case .minutesPerWeek: Color(red: 0.20, green: 0.60, blue: 1.0)
        case .shotsPerWeek: Color(red: 0.20, green: 0.78, blue: 0.35)
        case .drillsPerWeek: Color(red: 0.78, green: 0.45, blue: 0.95)
        case .streakDays: Color(red: 0.95, green: 0.45, blue: 0.20)
        }
    }

    var defaultTarget: Int {
        switch self {
        case .sessionsPerWeek: 3
        case .minutesPerWeek: 180
        case .shotsPerWeek: 100
        case .drillsPerWeek: 5
        case .streakDays: 7
        }
    }

    var unit: String {
        switch self {
        case .sessionsPerWeek: "sessions"
        case .minutesPerWeek: "min"
        case .shotsPerWeek: "makes"
        case .drillsPerWeek: "drills"
        case .streakDays: "days"
        }
    }
}

nonisolated struct BasketballGoal: Identifiable, Sendable, Codable {
    let id: UUID
    let type: BasketballGoalType
    var target: Int
    let dateCreated: Date

    init(type: BasketballGoalType, target: Int, dateCreated: Date = Date()) {
        self.id = UUID()
        self.type = type
        self.target = target
        self.dateCreated = dateCreated
    }
}

nonisolated enum BasketballFocusSkill: String, CaseIterable, Identifiable, Sendable, Codable {
    case catchAndShoot = "Catch & Shoot"
    case offTheDribble = "Off-the-Dribble"
    case finishing = "Finishing"
    case handles = "Handles"
    case defense = "Defense"
    case conditioning = "Conditioning"
    case freeThrows = "Free Throws"
    case footwork = "Footwork"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .catchAndShoot: "scope"
        case .offTheDribble: "figure.basketball"
        case .finishing: "basketball.fill"
        case .handles: "hand.raised.fingers.spread.fill"
        case .defense: "shield.lefthalf.filled"
        case .conditioning: "bolt.heart.fill"
        case .freeThrows: "target"
        case .footwork: "shoeprints.fill"
        }
    }

    var blurb: String {
        switch self {
        case .catchAndShoot: "Quick release. Feet set. Confidence on the catch."
        case .offTheDribble: "Get to your spots. Pull up clean."
        case .finishing: "Soft touch around the rim — both hands."
        case .handles: "Tight, low, fluid. Get loose with the rock."
        case .defense: "Quiet hands, active feet, locked stance."
        case .conditioning: "Build the engine. Late-game minutes are won here."
        case .freeThrows: "Routine over outcome. Same shot, every time."
        case .footwork: "Pivots, jump stops, drop steps. Boring details, big returns."
        }
    }

    var primaryCategory: DrillCategory {
        switch self {
        case .catchAndShoot, .freeThrows: .shooting
        case .offTheDribble, .handles: .ballHandling
        case .finishing: .finishing
        case .defense: .defense
        case .conditioning: .conditioning
        case .footwork: .footwork
        }
    }
}

// MARK: - Drill Library

nonisolated enum BasketballDrillLibrary {
    static let all: [BasketballDrill] = [
        // SHOOTING
        BasketballDrill(
            slug: "form-shooting",
            name: "Form Shooting",
            category: .shooting,
            difficulty: .beginner,
            durationMinutes: 10,
            equipment: [.hoop],
            purpose: "Build consistent shooting mechanics and muscle memory.",
            description: "Close-range one-hand shooting focusing on form, arc, and follow-through.",
            steps: [
                "Stand 3 feet from the rim, ball in shooting hand only.",
                "Shoot with your guide hand off the ball — focus on the arc.",
                "Make 25 in a row before stepping back two feet.",
                "Repeat through 3 distances."
            ],
            cues: ["High elbow", "Snap the wrist", "Hold the follow-through"],
            setsReps: "3 distances · 25 makes each"
        ),
        BasketballDrill(
            slug: "spot-up-5",
            name: "Spot-Up Shooting (5 Spots)",
            category: .shooting,
            difficulty: .intermediate,
            durationMinutes: 15,
            equipment: [.hoop],
            purpose: "Develop range and identify shooting strengths.",
            description: "10 shots from each of 5 spots: corners, wings, top of key.",
            steps: [
                "Pick 5 spots — both corners, both wings, top of key.",
                "Shoot 10 shots from each. Track makes.",
                "Move on once you hit 5+ at a spot."
            ],
            cues: ["Square to the rim", "Same routine every shot"],
            setsReps: "5 spots × 10 shots"
        ),
        BasketballDrill(
            slug: "catch-and-shoot",
            name: "Catch-and-Shoot",
            category: .shooting,
            difficulty: .intermediate,
            durationMinutes: 10,
            equipment: [.hoop, .partner],
            purpose: "Develop quick release and game-speed shooting.",
            description: "Receive pass and shoot immediately from various spots.",
            steps: [
                "Partner passes from the paint to a wing.",
                "Catch with feet ready, shoot in rhythm.",
                "Cycle through 5 spots, 5 makes each."
            ],
            cues: ["Hands ready", "Inside foot pivot", "Quick to the air"],
            setsReps: "5 spots · 5 makes each"
        ),
        BasketballDrill(
            slug: "free-throw-routine",
            name: "Free Throw Routine",
            category: .shooting,
            difficulty: .beginner,
            durationMinutes: 10,
            equipment: [.hoop],
            purpose: "Develop a consistent pre-shot routine and clutch shooting.",
            description: "Shoot sets of 10 free throws. Track makes and misses.",
            steps: [
                "Define your routine — 3 dribbles, deep breath, shoot.",
                "Shoot 5 sets of 10. Note your make %.",
                "End the session on 3 makes in a row."
            ],
            cues: ["Same routine", "Knees, elbow, eyes"],
            setsReps: "5 sets × 10"
        ),
        BasketballDrill(
            slug: "pull-up-jumpers",
            name: "Pull-Up Jumpers",
            category: .shooting,
            difficulty: .advanced,
            durationMinutes: 12,
            equipment: [.hoop],
            purpose: "Score off the dribble vs a sagging defender.",
            description: "Attack closeouts with one or two dribbles into a balanced jumper.",
            steps: [
                "Start at the wing. Take 1–2 dribbles.",
                "Jump-stop. Square. Shoot.",
                "10 reps each side."
            ],
            cues: ["Low dribble", "1-2 stop", "Eyes up early"],
            setsReps: "20 makes total"
        ),
        BasketballDrill(
            slug: "step-back",
            name: "Step-Back Threes",
            category: .shooting,
            difficulty: .advanced,
            durationMinutes: 10,
            equipment: [.hoop],
            purpose: "Create space against tight defense.",
            description: "Pound dribble into a hard step-back three.",
            steps: [
                "From wing, attack with 2 hard dribbles.",
                "Plant inside foot, push back into step-back.",
                "10 reps each side."
            ],
            cues: ["Sell the drive", "Push off the front foot", "Land balanced"]
        ),
        BasketballDrill(
            slug: "elbow-jumpers",
            name: "Elbow Jumpers",
            category: .shooting,
            difficulty: .intermediate,
            durationMinutes: 8,
            equipment: [.hoop],
            purpose: "Reliable mid-range pull-up.",
            description: "Catch at the elbow, jab, rise.",
            steps: ["Catch at elbow", "Jab step", "Rise into the shot"],
            cues: ["Knees bent on the catch", "Don't fade"]
        ),
        BasketballDrill(
            slug: "deep-three",
            name: "Logo Threes",
            category: .shooting,
            difficulty: .advanced,
            durationMinutes: 10,
            equipment: [.hoop],
            purpose: "Extend range under fatigue.",
            description: "Shoot from logo distance for makes.",
            steps: ["Shoot from logo", "Track makes/attempts", "Rotate spots"],
            cues: ["Use your legs", "Same form, more drive"]
        ),

        // BALL HANDLING
        BasketballDrill(
            slug: "crossover-series",
            name: "Crossover Series",
            category: .ballHandling,
            difficulty: .intermediate,
            durationMinutes: 5,
            equipment: [.ball],
            purpose: "Improve ball control and create separation.",
            description: "Stationary and moving crossovers — front, between, behind.",
            steps: [
                "60 seconds front cross.",
                "60 seconds between-the-legs.",
                "60 seconds behind-the-back.",
                "60 seconds combo."
            ],
            cues: ["Stay low", "Push, don't pat"]
        ),
        BasketballDrill(
            slug: "two-ball",
            name: "Two-Ball Pound",
            category: .ballHandling,
            difficulty: .intermediate,
            durationMinutes: 6,
            equipment: [.ball],
            purpose: "Strengthen weak hand, improve rhythm.",
            description: "Dribble two balls in unison and alternating.",
            steps: ["30s in unison pound", "30s alternating", "Repeat 4 times"],
            cues: ["Eyes up", "Below the knees"]
        ),
        BasketballDrill(
            slug: "between-legs-combo",
            name: "Between-the-Legs Combo",
            category: .ballHandling,
            difficulty: .intermediate,
            durationMinutes: 5,
            equipment: [.ball],
            purpose: "Chain moves together for fluid handling.",
            description: "Alternate between-the-legs with crossovers at speed.",
            cues: ["Tight to the body", "Plant and explode"]
        ),
        BasketballDrill(
            slug: "behind-back",
            name: "Behind-the-Back Series",
            category: .ballHandling,
            difficulty: .advanced,
            durationMinutes: 5,
            equipment: [.ball],
            purpose: "Add advanced moves to your handle.",
            description: "Full-court behind-the-back with speed changes."
        ),
        BasketballDrill(
            slug: "tennis-ball-toss",
            name: "Tennis Ball Toss",
            category: .ballHandling,
            difficulty: .advanced,
            durationMinutes: 5,
            equipment: [.ball],
            purpose: "Force eyes up while dribbling.",
            description: "Dribble while tossing and catching a tennis ball with the off hand.",
            cues: ["Don't look down", "Same speed both hands"]
        ),
        BasketballDrill(
            slug: "cone-dribble",
            name: "Cone Dribble Course",
            category: .ballHandling,
            difficulty: .beginner,
            durationMinutes: 6,
            equipment: [.ball, .cones],
            purpose: "Game-speed change of direction.",
            description: "Weave through cones with crossover, between, behind.",
            cues: ["Plant outside foot", "Explode out"]
        ),

        // FINISHING
        BasketballDrill(
            slug: "mikan",
            name: "Mikan Drill",
            category: .finishing,
            difficulty: .beginner,
            durationMinutes: 5,
            equipment: [.hoop],
            purpose: "Develop touch around the rim and ambidextrous finishing.",
            description: "Alternating layups from each side of the basket without dribbling.",
            steps: ["Right hand layup", "Rebound, switch sides", "Left hand layup"],
            cues: ["Soft off the glass", "Quick second jump"],
            setsReps: "Make 25"
        ),
        BasketballDrill(
            slug: "euro-step",
            name: "Euro Step Finishing",
            category: .finishing,
            difficulty: .advanced,
            durationMinutes: 5,
            equipment: [.hoop],
            purpose: "Finish around shot blockers.",
            description: "Drive and finish with a Euro step from both sides.",
            cues: ["Sell the first step", "Big second step"]
        ),
        BasketballDrill(
            slug: "floater",
            name: "Floater Practice",
            category: .finishing,
            difficulty: .intermediate,
            durationMinutes: 5,
            equipment: [.hoop],
            purpose: "Score over taller defenders.",
            description: "Drive into the paint and finish with a floater.",
            cues: ["High off the fingertips", "One-foot jump"]
        ),
        BasketballDrill(
            slug: "reverse-layup",
            name: "Reverse Layups",
            category: .finishing,
            difficulty: .intermediate,
            durationMinutes: 5,
            equipment: [.hoop],
            purpose: "Use the rim as a shield.",
            description: "Drive baseline and finish reverse on both sides.",
            cues: ["Get under the rim", "Ball over the head"]
        ),
        BasketballDrill(
            slug: "contact-finishes",
            name: "Contact Finishes",
            category: .finishing,
            difficulty: .advanced,
            durationMinutes: 6,
            equipment: [.hoop, .partner],
            purpose: "Finish through contact.",
            description: "Partner bumps you on the way to the rim — finish anyway.",
            cues: ["Strong gather", "Chin the ball"]
        ),

        // DEFENSE
        BasketballDrill(
            slug: "defensive-slides",
            name: "Defensive Slides",
            category: .defense,
            difficulty: .beginner,
            durationMinutes: 5,
            equipment: [.noHoop],
            purpose: "Build lateral quickness and defensive positioning.",
            description: "Lateral slides across the lane, staying low.",
            cues: ["Don't cross the feet", "Hands active"]
        ),
        BasketballDrill(
            slug: "closeout",
            name: "Closeout Drill",
            category: .defense,
            difficulty: .intermediate,
            durationMinutes: 5,
            equipment: [.hoop, .partner],
            purpose: "Transition from help to on-ball defense.",
            description: "Sprint to closeout on shooter, then slide to contain.",
            cues: ["Short, choppy steps", "High hand on the shooter"]
        ),
        BasketballDrill(
            slug: "shell-drill",
            name: "Shell Drill (1-on-1)",
            category: .defense,
            difficulty: .intermediate,
            durationMinutes: 8,
            equipment: [.hoop, .partner],
            purpose: "Stay in front of your man.",
            description: "Live 1-on-1, no help. Win 3 stops.",
            cues: ["Mirror the hips", "Force the weak hand"]
        ),
        BasketballDrill(
            slug: "deny-stance",
            name: "Deny Stance",
            category: .defense,
            difficulty: .beginner,
            durationMinutes: 4,
            equipment: [.partner],
            purpose: "Off-ball pressure.",
            description: "One hand in the passing lane, one foot in the gap. Hold the stance for 30s reps.",
            cues: ["See ball, see man"]
        ),

        // CONDITIONING
        BasketballDrill(
            slug: "suicides",
            name: "Suicides",
            category: .conditioning,
            difficulty: .advanced,
            durationMinutes: 5,
            equipment: [.noHoop],
            purpose: "Build basketball-specific endurance.",
            description: "Sprint to free throw, half court, far free throw, end line.",
            setsReps: "4 reps under 35s each"
        ),
        BasketballDrill(
            slug: "full-court-layups",
            name: "Full Court Layups",
            category: .conditioning,
            difficulty: .intermediate,
            durationMinutes: 5,
            equipment: [.hoop],
            purpose: "Combine conditioning with finishing under fatigue.",
            description: "Full-court dribble, finish with layup, repeat back."
        ),
        BasketballDrill(
            slug: "17s",
            name: "17s",
            category: .conditioning,
            difficulty: .advanced,
            durationMinutes: 4,
            equipment: [.noHoop],
            purpose: "Elite-level conditioning test.",
            description: "Sprint sideline-to-sideline 17 times under 1 minute."
        ),
        BasketballDrill(
            slug: "lane-jumps",
            name: "Lane Line Jumps",
            category: .conditioning,
            difficulty: .beginner,
            durationMinutes: 4,
            equipment: [.noHoop],
            purpose: "Build calves and explosiveness.",
            description: "Two-foot side-to-side jumps over the lane line for 30s reps."
        ),
        BasketballDrill(
            slug: "jump-rope",
            name: "Jump Rope Intervals",
            category: .conditioning,
            difficulty: .beginner,
            durationMinutes: 8,
            equipment: [.noHoop],
            purpose: "Footwork and lung capacity.",
            description: "8 rounds — 45s on, 15s off."
        ),

        // FOOTWORK
        BasketballDrill(
            slug: "jump-stop",
            name: "Jump Stop & Pivot",
            category: .footwork,
            difficulty: .beginner,
            durationMinutes: 5,
            equipment: [.ball],
            purpose: "Avoid travels and create space.",
            description: "Drive, jump stop, pivot, pass — both pivot feet.",
            cues: ["Two-foot stop", "Heel down on pivot"]
        ),
        BasketballDrill(
            slug: "drop-step",
            name: "Drop Step Series",
            category: .footwork,
            difficulty: .intermediate,
            durationMinutes: 5,
            equipment: [.hoop],
            purpose: "Score on the block.",
            description: "Catch on the block, drop step baseline or middle, finish.",
            cues: ["Seal first", "Big drop step"]
        ),
        BasketballDrill(
            slug: "pivot-series",
            name: "Triple Threat Pivots",
            category: .footwork,
            difficulty: .beginner,
            durationMinutes: 4,
            equipment: [.ball],
            purpose: "Stay a threat with the ball.",
            description: "Catch, jab, sweep, shot fake — repeat."
        ),
        BasketballDrill(
            slug: "spin-finish",
            name: "Spin Move Finish",
            category: .footwork,
            difficulty: .advanced,
            durationMinutes: 6,
            equipment: [.hoop],
            purpose: "Counter aggressive defenders.",
            description: "Drive, sense contact, spin off and finish.",
            cues: ["Sweep the ball", "Stay low through the spin"]
        ),

        // IQ
        BasketballDrill(
            slug: "pnr-reads",
            name: "Pick-and-Roll Reads",
            category: .iq,
            difficulty: .advanced,
            durationMinutes: 10,
            equipment: [.hoop, .partner],
            purpose: "Improve decision-making in the most common play.",
            description: "Read coverage: drive, pull, pocket, slip.",
            cues: ["Reject hard coverage", "Reward the screener"]
        ),
        BasketballDrill(
            slug: "film-study",
            name: "Film Study",
            category: .iq,
            difficulty: .beginner,
            durationMinutes: 15,
            equipment: [.noHoop],
            purpose: "Steal moves from the pros.",
            description: "Pick a player. Watch a full game. Note 3 things you can steal.",
            cues: ["Watch off-ball", "Pause and rewind"]
        ),
        BasketballDrill(
            slug: "shot-selection",
            name: "Shot Selection Audit",
            category: .iq,
            difficulty: .intermediate,
            durationMinutes: 8,
            equipment: [.noHoop],
            purpose: "Take better shots.",
            description: "Review your last 3 sessions. Mark each shot Good / Okay / Bad."
        ),
        BasketballDrill(
            slug: "reading-the-help",
            name: "Reading the Help",
            category: .iq,
            difficulty: .advanced,
            durationMinutes: 8,
            equipment: [.hoop, .partner],
            purpose: "Make the right pass.",
            description: "Drive baseline. Help comes — find the corner."
        ),

        // Extra shooting / handling for variety
        BasketballDrill(
            slug: "shooting-warmup",
            name: "Routine Warmup",
            category: .shooting,
            difficulty: .beginner,
            durationMinutes: 8,
            equipment: [.hoop],
            purpose: "Lock in your stroke before a session.",
            description: "Form shots → midrange → three sequence."
        ),
        BasketballDrill(
            slug: "around-the-world",
            name: "Around the World",
            category: .shooting,
            difficulty: .beginner,
            durationMinutes: 8,
            equipment: [.hoop],
            purpose: "Hit shots from every angle.",
            description: "Make 1 from each of 7 spots in a row."
        ),
        BasketballDrill(
            slug: "post-moves",
            name: "Post Move Series",
            category: .finishing,
            difficulty: .intermediate,
            durationMinutes: 6,
            equipment: [.hoop],
            purpose: "Score from the block.",
            description: "Drop step, jump hook, up-and-under.",
            cues: ["Seal first", "Strong base"]
        )
    ]

    static func drill(forSlug slug: String) -> BasketballDrill? {
        all.first { $0.slug == slug }
    }
}

// MARK: - Plan Templates

nonisolated enum BasketballPlanTemplates {
    static let all: [PracticePlan] = [
        PracticePlan(
            name: "Solo Shooting 30",
            drills: drillsBySlug(["shooting-warmup", "spot-up-5", "catch-and-shoot"]),
            isTemplate: true,
            templateBlurb: "30 min on the gun. Warm up, work the spots, finish in rhythm."
        ),
        PracticePlan(
            name: "Pre-Game Warmup",
            drills: drillsBySlug(["form-shooting", "mikan", "around-the-world", "free-throw-routine"]),
            isTemplate: true,
            templateBlurb: "Get loose, get sharp. Walk into your run feeling ready."
        ),
        PracticePlan(
            name: "Handles 20",
            drills: drillsBySlug(["crossover-series", "two-ball", "between-legs-combo", "cone-dribble"]),
            isTemplate: true,
            templateBlurb: "20 minutes of pure handles. No hoop required."
        ),
        PracticePlan(
            name: "Conditioning Killer",
            drills: drillsBySlug(["jump-rope", "lane-jumps", "suicides", "17s"]),
            isTemplate: true,
            templateBlurb: "Lungs, legs, late-game minutes."
        ),
        PracticePlan(
            name: "Form Fix",
            drills: drillsBySlug(["form-shooting", "free-throw-routine", "elbow-jumpers"]),
            isTemplate: true,
            templateBlurb: "Reset the stroke. Slow, repeatable, deliberate."
        ),
        PracticePlan(
            name: "Finisher's Block",
            drills: drillsBySlug(["mikan", "floater", "euro-step", "contact-finishes"]),
            isTemplate: true,
            templateBlurb: "Become a problem at the rim."
        )
    ]

    private static func drillsBySlug(_ slugs: [String]) -> [PracticePlanDrill] {
        slugs.compactMap { slug in
            guard let drill = BasketballDrillLibrary.drill(forSlug: slug) else { return nil }
            return PracticePlanDrill(drill: drill)
        }
    }
}
