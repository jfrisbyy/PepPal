import Foundation
import SwiftUI

nonisolated enum SoccerSessionType: String, CaseIterable, Identifiable, Sendable {
    case game = "Game"
    case pickupGame = "Pickup"
    case soloTraining = "Solo Training"
    case teamPractice = "Team Practice"
    case conditioning = "Conditioning"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .game: "soccerball"
        case .pickupGame: "figure.soccer"
        case .soloTraining: "figure.run"
        case .teamPractice: "person.3.fill"
        case .conditioning: "bolt.heart.fill"
        }
    }

    var isGame: Bool {
        switch self {
        case .game, .pickupGame: true
        default: false
        }
    }
}

nonisolated enum SoccerPosition: String, CaseIterable, Identifiable, Sendable {
    case goalkeeper = "Goalkeeper"
    case centerBack = "Center Back"
    case fullBack = "Full Back"
    case defensiveMid = "Defensive Mid"
    case centralMid = "Central Mid"
    case attackingMid = "Attacking Mid"
    case winger = "Winger"
    case striker = "Striker"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .goalkeeper: "GK"
        case .centerBack: "CB"
        case .fullBack: "FB"
        case .defensiveMid: "CDM"
        case .centralMid: "CM"
        case .attackingMid: "CAM"
        case .winger: "W"
        case .striker: "ST"
        }
    }

    var icon: String {
        switch self {
        case .goalkeeper: "hand.raised.fill"
        case .centerBack, .fullBack: "shield.lefthalf.filled"
        case .defensiveMid, .centralMid: "arrow.left.arrow.right"
        case .attackingMid: "arrow.up.forward"
        case .winger: "wind"
        case .striker: "scope"
        }
    }

    var isDefender: Bool {
        switch self {
        case .goalkeeper, .centerBack, .fullBack: true
        default: false
        }
    }

    var isMidfielder: Bool {
        switch self {
        case .defensiveMid, .centralMid, .attackingMid: true
        default: false
        }
    }

    var isAttacker: Bool {
        switch self {
        case .winger, .striker: true
        default: false
        }
    }
}

nonisolated struct SoccerGameStats: Sendable {
    var goals: Int = 0
    var assists: Int = 0
    var shotsOnTarget: Int = 0
    var shotsOffTarget: Int = 0
    var keyPasses: Int = 0
    var tacklesWon: Int = 0
    var tacklesLost: Int = 0
    var interceptions: Int = 0
    var foulsCommitted: Int = 0
    var foulsWon: Int = 0
    var yellowCards: Int = 0
    var redCards: Int = 0
    var minutesPlayed: Int = 90

    var totalShots: Int { shotsOnTarget + shotsOffTarget }

    var shotAccuracy: Double {
        totalShots > 0 ? Double(shotsOnTarget) / Double(totalShots) * 100 : 0
    }

    var tackleSuccessRate: Double {
        let total = tacklesWon + tacklesLost
        return total > 0 ? Double(tacklesWon) / Double(total) * 100 : 0
    }

    var goalContributions: Int { goals + assists }
}

nonisolated enum SoccerMatchResult: String, CaseIterable, Identifiable, Sendable {
    case win = "W"
    case draw = "D"
    case loss = "L"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .win: .green
        case .draw: .orange
        case .loss: .red
        }
    }

    var label: String {
        switch self {
        case .win: "Win"
        case .draw: "Draw"
        case .loss: "Loss"
        }
    }
}

nonisolated struct SoccerMatch: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let sessionType: SoccerSessionType
    let position: SoccerPosition
    let stats: SoccerGameStats
    let result: SoccerMatchResult?
    let teamScore: Int?
    let opponentScore: Int?
    let durationMinutes: Int
    let distanceKm: Double
    let sprintCount: Int
    let topSpeedKmh: Double
    let performanceRating: Int
    let confidenceRating: Int
    let notes: String
    let fpEarned: Int

    init(
        date: Date = Date(),
        sessionType: SoccerSessionType = .game,
        position: SoccerPosition = .centralMid,
        stats: SoccerGameStats = SoccerGameStats(),
        result: SoccerMatchResult? = nil,
        teamScore: Int? = nil,
        opponentScore: Int? = nil,
        durationMinutes: Int = 90,
        distanceKm: Double = 0,
        sprintCount: Int = 0,
        topSpeedKmh: Double = 0,
        performanceRating: Int = 5,
        confidenceRating: Int = 5,
        notes: String = ""
    ) {
        self.id = UUID()
        self.date = date
        self.sessionType = sessionType
        self.position = position
        self.stats = stats
        self.result = result
        self.teamScore = teamScore
        self.opponentScore = opponentScore
        self.durationMinutes = durationMinutes
        self.distanceKm = distanceKm
        self.sprintCount = sprintCount
        self.topSpeedKmh = topSpeedKmh
        self.performanceRating = performanceRating
        self.confidenceRating = confidenceRating
        self.notes = notes

        if sessionType.isGame {
            let statScore = Double(stats.goals) * 6.0 + Double(stats.assists) * 4.0 +
                Double(stats.keyPasses) * 1.5 + Double(stats.tacklesWon) * 2.0 +
                Double(stats.interceptions) * 1.5 - Double(stats.foulsCommitted) * 0.5
            let durationBonus = Double(durationMinutes) * 1.5
            let resultMultiplier: Double
            switch result {
            case .win: resultMultiplier = 1.3
            case .draw: resultMultiplier = 1.1
            default: resultMultiplier = 1.0
            }
            self.fpEarned = Int((statScore + durationBonus) * resultMultiplier)
        } else {
            let baseFP = Double(durationMinutes) * 2.5
            let typeMultiplier: Double
            switch sessionType {
            case .soloTraining: typeMultiplier = 1.1
            case .teamPractice: typeMultiplier = 1.2
            case .conditioning: typeMultiplier = 1.3
            default: typeMultiplier = 1.0
            }
            self.fpEarned = Int(baseFP * typeMultiplier)
        }
    }
}

nonisolated enum SoccerDrillCategory: String, CaseIterable, Identifiable, Sendable {
    case dribbling = "Dribbling"
    case passing = "Passing"
    case shooting = "Shooting"
    case defending = "Defending"
    case goalkeeping = "Goalkeeping"
    case conditioning = "Conditioning"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dribbling: "figure.soccer"
        case .passing: "arrow.turn.up.right"
        case .shooting: "scope"
        case .defending: "shield.lefthalf.filled"
        case .goalkeeping: "hand.raised.fill"
        case .conditioning: "bolt.heart.fill"
        }
    }

    var color: Color {
        switch self {
        case .dribbling: Color(red: 0.2, green: 0.78, blue: 0.35)
        case .passing: Color(red: 0.2, green: 0.6, blue: 1.0)
        case .shooting: Color(red: 1.0, green: 0.55, blue: 0.1)
        case .defending: Color(red: 0.85, green: 0.25, blue: 0.25)
        case .goalkeeping: Color(red: 0.85, green: 0.9, blue: 0.15)
        case .conditioning: Color(red: 0.55, green: 0.36, blue: 0.96)
        }
    }
}

nonisolated enum SoccerDrillDifficulty: String, CaseIterable, Identifiable, Sendable {
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

nonisolated struct SoccerDrill: Identifiable, Sendable {
    let id: UUID
    let name: String
    let category: SoccerDrillCategory
    let difficulty: SoccerDrillDifficulty
    let durationMinutes: Int
    let description: String
    let purpose: String
    let equipment: String

    init(name: String, category: SoccerDrillCategory, difficulty: SoccerDrillDifficulty, durationMinutes: Int, description: String, purpose: String, equipment: String = "Ball, Cones") {
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

nonisolated enum SoccerDrillLibrary {
    static let all: [SoccerDrill] = [
        SoccerDrill(name: "Cone Dribbling Slalom", category: .dribbling, difficulty: .beginner, durationMinutes: 10, description: "Weave through a line of 8-10 cones spaced 2 yards apart using both feet.", purpose: "Improve close ball control and agility at speed."),
        SoccerDrill(name: "1v1 Dribble Attack", category: .dribbling, difficulty: .intermediate, durationMinutes: 10, description: "Face a passive defender and practice beating them with stepovers, body feints, and changes of direction.", purpose: "Develop confidence taking on defenders in game situations."),
        SoccerDrill(name: "Speed Dribble Circuit", category: .dribbling, difficulty: .advanced, durationMinutes: 15, description: "Dribble at full speed through a complex cone pattern with direction changes, pull-backs, and Cruyff turns.", purpose: "Build elite-level dribbling speed and technique under pressure."),
        SoccerDrill(name: "Wall Pass Combos", category: .passing, difficulty: .beginner, durationMinutes: 10, description: "Pass against a wall alternating between inside foot, outside foot, and instep. Receive and control with both feet.", purpose: "Develop consistent passing technique and first touch.", equipment: "Ball, Wall"),
        SoccerDrill(name: "Triangle Passing", category: .passing, difficulty: .intermediate, durationMinutes: 15, description: "Set up 3 cones in a triangle. Move around the triangle passing to each cone, mixing one-touch and two-touch passes.", purpose: "Improve passing accuracy and movement off the ball."),
        SoccerDrill(name: "Long Ball Accuracy", category: .passing, difficulty: .advanced, durationMinutes: 15, description: "Hit long diagonal passes to target zones 30-40 yards away. Alternate between driven passes and lofted balls.", purpose: "Develop range of passing for switching play and through balls."),
        SoccerDrill(name: "Finishing from Crosses", category: .shooting, difficulty: .intermediate, durationMinutes: 15, description: "Receive crosses from both sides and finish with headers, volleys, and one-touch shots.", purpose: "Improve finishing from wide deliveries and build composure in the box."),
        SoccerDrill(name: "Shooting Accuracy Drill", category: .shooting, difficulty: .beginner, durationMinutes: 10, description: "Shoot from 18 yards at targets placed in all four corners of the goal. 10 shots per corner.", purpose: "Develop accuracy and consistent shooting technique."),
        SoccerDrill(name: "Quick-Fire Finishing", category: .shooting, difficulty: .advanced, durationMinutes: 10, description: "Receive rapid passes from different angles and shoot first-time. Emphasize body shape and shot selection.", purpose: "Build quick decision-making and clinical finishing under pressure."),
        SoccerDrill(name: "Defensive Slides", category: .defending, difficulty: .beginner, durationMinutes: 10, description: "Lateral shuffle between cones in a defensive stance, staying low and balanced.", purpose: "Build lateral quickness and proper defensive positioning.", equipment: "Cones"),
        SoccerDrill(name: "1v1 Defending", category: .defending, difficulty: .intermediate, durationMinutes: 10, description: "Defend against an attacker in a 10x10 yard box. Focus on jockeying, body position, and timing tackles.", purpose: "Improve 1v1 defending technique and reading attackers."),
        SoccerDrill(name: "Pressing Triggers", category: .defending, difficulty: .advanced, durationMinutes: 15, description: "Practice coordinated pressing patterns: when to press, when to hold, and how to cut passing lanes.", purpose: "Develop tactical awareness and team pressing discipline."),
        SoccerDrill(name: "GK Reaction Saves", category: .goalkeeping, difficulty: .intermediate, durationMinutes: 15, description: "Face rapid shots from 12 yards. Focus on set position, reaction time, and hand positioning.", purpose: "Sharpen reflexes and shot-stopping ability.", equipment: "Ball, Goal"),
        SoccerDrill(name: "GK Distribution", category: .goalkeeping, difficulty: .beginner, durationMinutes: 10, description: "Practice goal kicks, throws, and punt kicks to targets at various distances.", purpose: "Improve accuracy and range of goalkeeper distribution.", equipment: "Ball, Goal, Cones"),
        SoccerDrill(name: "Shuttle Runs", category: .conditioning, difficulty: .intermediate, durationMinutes: 10, description: "Sprint 10-20-30-40 yard shuttles with walk-back recovery. 6-8 sets.", purpose: "Build match-specific endurance and repeated sprint ability.", equipment: "Cones"),
        SoccerDrill(name: "Box-to-Box Intervals", category: .conditioning, difficulty: .advanced, durationMinutes: 15, description: "Sprint from one penalty box to the other, jog back. 10-12 reps with 30-second rest between.", purpose: "Simulate match intensity for midfielders and develop cardiovascular capacity.", equipment: "Pitch"),
    ]
}
