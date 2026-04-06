import Foundation
import SwiftUI

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

    var gameScore: Double {
        Double(points) + 0.4 * Double(fieldGoalsMade) - 0.7 * Double(fieldGoalsAttempted) +
        0.7 * Double(offensiveRebounds) + 0.3 * Double(defensiveRebounds) +
        Double(steals) + 0.7 * Double(assists) + 0.7 * Double(blocks) -
        0.4 * Double(freeThrowsAttempted - freeThrowsMade) - Double(turnovers)
    }
}

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
    let fpEarned: Int

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
        notes: String = ""
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

        if sessionType.isGame {
            let statScore = Double(stats.points) + Double(stats.totalRebounds) * 1.2 +
                Double(stats.assists) * 1.5 - Double(stats.turnovers) * 0.8
            let durationBonus = Double(durationMinutes) * 2.0
            let intensityMultiplier: Double = result == .win ? 1.2 : 1.0
            self.fpEarned = Int((statScore + durationBonus) * intensityMultiplier)
        } else {
            let baseFP = Double(durationMinutes) * 2.5
            let typeMultiplier: Double
            switch sessionType {
            case .soloShooting: typeMultiplier = 1.1
            case .skillsPractice: typeMultiplier = 1.2
            case .conditioning: typeMultiplier = 1.3
            default: typeMultiplier = 1.0
            }
            self.fpEarned = Int(baseFP * typeMultiplier)
        }
    }
}

nonisolated enum DrillCategory: String, CaseIterable, Identifiable, Sendable {
    case shooting = "Shooting"
    case ballHandling = "Ball Handling"
    case defense = "Defense"
    case conditioning = "Conditioning"
    case finishing = "Finishing"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .shooting: "scope"
        case .ballHandling: "hand.raised.fingers.spread.fill"
        case .defense: "shield.lefthalf.filled"
        case .conditioning: "bolt.heart.fill"
        case .finishing: "basketball.fill"
        }
    }

    var color: Color {
        switch self {
        case .shooting: Color(red: 1.0, green: 0.55, blue: 0.1)
        case .ballHandling: Color(red: 0.2, green: 0.6, blue: 1.0)
        case .defense: Color(red: 0.85, green: 0.25, blue: 0.25)
        case .conditioning: Color(red: 0.85, green: 0.9, blue: 0.15)
        case .finishing: Color(red: 0.2, green: 0.78, blue: 0.35)
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

nonisolated struct BasketballDrill: Identifiable, Sendable {
    let id: UUID
    let name: String
    let category: DrillCategory
    let difficulty: DrillDifficulty
    let durationMinutes: Int
    let description: String
    let purpose: String

    init(name: String, category: DrillCategory, difficulty: DrillDifficulty, durationMinutes: Int, description: String, purpose: String) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.difficulty = difficulty
        self.durationMinutes = durationMinutes
        self.description = description
        self.purpose = purpose
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

    init(name: String, drills: [PracticePlanDrill] = [], dateCreated: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.drills = drills
        self.dateCreated = dateCreated
    }

    var totalDuration: Int {
        drills.reduce(0) { $0 + $1.drill.durationMinutes }
    }

    var completedCount: Int {
        drills.filter(\.isCompleted).count
    }
}

nonisolated enum BasketballDrillLibrary {
    static let all: [BasketballDrill] = [
        BasketballDrill(name: "Mikan Drill", category: .finishing, difficulty: .beginner, durationMinutes: 5, description: "Alternating layups from each side of the basket without dribbling.", purpose: "Develop touch around the rim and ambidextrous finishing."),
        BasketballDrill(name: "Form Shooting", category: .shooting, difficulty: .beginner, durationMinutes: 10, description: "Close-range one-hand shooting focusing on form, arc, and follow-through.", purpose: "Build consistent shooting mechanics and muscle memory."),
        BasketballDrill(name: "Spot-Up Shooting (5 Spots)", category: .shooting, difficulty: .intermediate, durationMinutes: 15, description: "10 shots from each of 5 spots: corners, wings, and top of key.", purpose: "Develop range and identify shooting strengths/weaknesses."),
        BasketballDrill(name: "Crossover Series", category: .ballHandling, difficulty: .intermediate, durationMinutes: 5, description: "Stationary and moving crossovers: front, between legs, behind back.", purpose: "Improve ball control and create separation from defenders."),
        BasketballDrill(name: "Behind-the-Back Dribble", category: .ballHandling, difficulty: .advanced, durationMinutes: 5, description: "Full-court behind-the-back dribble with speed changes.", purpose: "Add advanced moves to your handle for game situations."),
        BasketballDrill(name: "Between-the-Legs Combo", category: .ballHandling, difficulty: .intermediate, durationMinutes: 5, description: "Alternate between-the-legs with crossovers at speed.", purpose: "Chain moves together for fluid ball handling."),
        BasketballDrill(name: "Defensive Slides", category: .defense, difficulty: .beginner, durationMinutes: 5, description: "Lateral slides across the lane, staying low in defensive stance.", purpose: "Build lateral quickness and defensive positioning."),
        BasketballDrill(name: "Closeout Drill", category: .defense, difficulty: .intermediate, durationMinutes: 5, description: "Sprint to closeout on shooter, then slide to contain drive.", purpose: "Practice transitioning from help to on-ball defense."),
        BasketballDrill(name: "Suicides", category: .conditioning, difficulty: .advanced, durationMinutes: 5, description: "Sprint to free throw, half court, far free throw, and end line.", purpose: "Build basketball-specific endurance and mental toughness."),
        BasketballDrill(name: "Full Court Layups", category: .conditioning, difficulty: .intermediate, durationMinutes: 5, description: "Full-court dribble, finish with layup, repeat back immediately.", purpose: "Combine conditioning with finishing under fatigue."),
        BasketballDrill(name: "Free Throw Routine", category: .shooting, difficulty: .beginner, durationMinutes: 10, description: "Shoot sets of 10 free throws. Track makes and misses.", purpose: "Develop a consistent pre-shot routine and clutch shooting."),
        BasketballDrill(name: "Pick-and-Roll Reads", category: .ballHandling, difficulty: .advanced, durationMinutes: 10, description: "Practice reading the defense off ball screens: drive, pull-up, or pass.", purpose: "Improve decision-making in the most common NBA play."),
        BasketballDrill(name: "Catch-and-Shoot", category: .shooting, difficulty: .intermediate, durationMinutes: 10, description: "Receive pass and shoot immediately from various spots.", purpose: "Develop quick release and game-speed shooting."),
        BasketballDrill(name: "Euro Step Finishing", category: .finishing, difficulty: .advanced, durationMinutes: 5, description: "Drive and finish with Euro step from both sides.", purpose: "Add an elite finishing move to avoid shot blockers."),
        BasketballDrill(name: "Floater Practice", category: .finishing, difficulty: .intermediate, durationMinutes: 5, description: "Drive into the paint and finish with a floater over the defense.", purpose: "Develop a go-to move in the mid-range/paint area."),
        BasketballDrill(name: "17s (Sideline Sprints)", category: .conditioning, difficulty: .advanced, durationMinutes: 5, description: "Sprint sideline-to-sideline 17 times under 1 minute.", purpose: "Elite-level conditioning test used by college/pro teams."),
    ]
}
