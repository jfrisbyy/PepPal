import Foundation
import SwiftUI
import CoreLocation
import MapKit

nonisolated enum SwimSessionType: String, CaseIterable, Identifiable, Sendable, Codable {
    case poolLaps = "Pool Laps"
    case openWater = "Open Water"
    case structuredWorkout = "Structured Workout"
    case drillSession = "Drill Session"
    case cssTest = "CSS Test"
    case casualSwim = "Casual Swim"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .poolLaps: "figure.pool.swim"
        case .openWater: "water.waves"
        case .structuredWorkout: "list.bullet.clipboard"
        case .drillSession: "sportscourt.fill"
        case .cssTest: "speedometer"
        case .casualSwim: "drop.fill"
        }
    }

    var color: Color {
        switch self {
        case .poolLaps: Color(red: 0.2, green: 0.6, blue: 1.0)
        case .openWater: Color(red: 0.0, green: 0.8, blue: 0.7)
        case .structuredWorkout: Color(red: 0.85, green: 0.25, blue: 0.25)
        case .drillSession: Color(red: 1.0, green: 0.55, blue: 0.1)
        case .cssTest: Color(red: 0.85, green: 0.9, blue: 0.15)
        case .casualSwim: Color(red: 0.55, green: 0.36, blue: 0.96)
        }
    }
}

nonisolated enum PoolLength: String, CaseIterable, Identifiable, Sendable, Codable {
    case meters25 = "25m"
    case yards25 = "25yd"
    case meters50 = "50m"
    case custom = "Custom"

    var id: String { rawValue }

    var lengthInMeters: Double {
        switch self {
        case .meters25: 25.0
        case .yards25: 22.86
        case .meters50: 50.0
        case .custom: 25.0
        }
    }
}

nonisolated enum SwimStrokeType: String, CaseIterable, Identifiable, Sendable, Codable {
    case freestyle = "Freestyle"
    case backstroke = "Backstroke"
    case breaststroke = "Breaststroke"
    case butterfly = "Butterfly"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .freestyle: "figure.pool.swim"
        case .backstroke: "arrow.uturn.backward"
        case .breaststroke: "hands.sparkles.fill"
        case .butterfly: "bird.fill"
        }
    }

    var color: Color {
        switch self {
        case .freestyle: Color(red: 0.2, green: 0.6, blue: 1.0)
        case .backstroke: Color(red: 0.0, green: 0.8, blue: 0.7)
        case .breaststroke: Color(red: 1.0, green: 0.55, blue: 0.1)
        case .butterfly: Color(red: 0.85, green: 0.25, blue: 0.25)
        }
    }
}

nonisolated enum SwimPaceUnit: String, CaseIterable, Identifiable, Sendable, Codable {
    case per100m = "/100m"
    case per100yd = "/100yd"

    var id: String { rawValue }
}

nonisolated struct SwimLap: Identifiable, Sendable {
    let id: UUID
    let lapNumber: Int
    let strokeType: SwimStrokeType
    let duration: TimeInterval
    let strokeCount: Int
    let swolf: Int
    let pacePer100: Double

    init(lapNumber: Int, strokeType: SwimStrokeType, duration: TimeInterval, strokeCount: Int, poolLengthMeters: Double) {
        self.id = UUID()
        self.lapNumber = lapNumber
        self.strokeType = strokeType
        self.duration = duration
        self.strokeCount = strokeCount
        self.swolf = Int(duration) + strokeCount
        self.pacePer100 = poolLengthMeters > 0 ? (duration / poolLengthMeters) * 100 : 0
    }
}

nonisolated struct StrokeBreakdown: Identifiable, Sendable {
    let id: UUID
    let strokeType: SwimStrokeType
    let laps: Int
    let distanceMeters: Double
    let averagePace: Double
    let averageSwolf: Double
    let percentage: Double

    init(strokeType: SwimStrokeType, laps: Int, distanceMeters: Double, averagePace: Double, averageSwolf: Double, percentage: Double) {
        self.id = UUID()
        self.strokeType = strokeType
        self.laps = laps
        self.distanceMeters = distanceMeters
        self.averagePace = averagePace
        self.averageSwolf = averageSwolf
        self.percentage = percentage
    }
}

nonisolated struct SwimInterval: Identifiable, Sendable {
    let id: UUID
    var distanceMeters: Int
    var targetPace: Double
    var strokeType: SwimStrokeType
    var restSeconds: Int
    var repetitions: Int

    init(distanceMeters: Int = 100, targetPace: Double = 120, strokeType: SwimStrokeType = .freestyle, restSeconds: Int = 15, repetitions: Int = 4) {
        self.id = UUID()
        self.distanceMeters = distanceMeters
        self.targetPace = targetPace
        self.strokeType = strokeType
        self.restSeconds = restSeconds
        self.repetitions = repetitions
    }

    var totalDistance: Int { distanceMeters * repetitions }

    var description: String {
        "\(repetitions)x\(distanceMeters)m \(strokeType.rawValue)"
    }
}

nonisolated struct StructuredSwimWorkout: Identifiable, Sendable {
    let id: UUID
    var name: String
    var intervals: [SwimInterval]
    let dateCreated: Date

    init(name: String, intervals: [SwimInterval] = [], dateCreated: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.intervals = intervals
        self.dateCreated = dateCreated
    }

    var totalDistance: Int {
        intervals.reduce(0) { $0 + $1.totalDistance }
    }

    var totalIntervalCount: Int {
        intervals.reduce(0) { $0 + $1.repetitions }
    }

    var estimatedDurationMinutes: Int {
        let swimTime = intervals.reduce(0.0) { $0 + ($1.targetPace * Double($1.repetitions) * Double($1.distanceMeters) / 100.0) }
        let restTime = intervals.reduce(0.0) { $0 + Double($1.restSeconds * $1.repetitions) }
        return Int((swimTime + restTime) / 60.0)
    }
}

nonisolated struct OpenWaterCoordinate: Sendable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
}

nonisolated struct CompletedSwim: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let sessionType: SwimSessionType
    let poolLength: PoolLength
    let customPoolLengthMeters: Double?
    let totalLaps: Int
    let totalDistanceMeters: Double
    let durationSeconds: TimeInterval
    let averagePacePer100: Double
    let bestPacePer100: Double
    let averageSwolf: Double
    let bestSwolf: Int
    let averageStrokeCount: Double
    let totalStrokeCount: Int
    let averageHeartRate: Int
    let maxHeartRate: Int
    let caloriesBurned: Int
    let laps: [SwimLap]
    let strokeBreakdown: [StrokeBreakdown]
    let heartRateZones: [HeartRateZoneDistribution]
    let openWaterCoordinates: [OpenWaterCoordinate]
    let notes: String

    var poolLengthMeters: Double {
        if poolLength == .custom, let custom = customPoolLengthMeters {
            return custom
        }
        return poolLength.lengthInMeters
    }

    var totalDistanceYards: Double { totalDistanceMeters * 1.09361 }

    var durationFormatted: String {
        SwimFormatters.formatDuration(durationSeconds)
    }

    var averagePaceFormatted: String {
        SwimFormatters.formatPace(averagePacePer100)
    }

    var bestPaceFormatted: String {
        SwimFormatters.formatPace(bestPacePer100)
    }

    var isOpenWater: Bool { sessionType == .openWater }

    init(
        date: Date = Date(),
        sessionType: SwimSessionType = .poolLaps,
        poolLength: PoolLength = .meters25,
        customPoolLengthMeters: Double? = nil,
        totalLaps: Int = 0,
        totalDistanceMeters: Double = 0,
        durationSeconds: TimeInterval = 0,
        averagePacePer100: Double = 0,
        bestPacePer100: Double = 0,
        averageSwolf: Double = 0,
        bestSwolf: Int = 0,
        averageStrokeCount: Double = 0,
        totalStrokeCount: Int = 0,
        averageHeartRate: Int = 0,
        maxHeartRate: Int = 0,
        caloriesBurned: Int = 0,
        laps: [SwimLap] = [],
        strokeBreakdown: [StrokeBreakdown] = [],
        heartRateZones: [HeartRateZoneDistribution] = [],
        openWaterCoordinates: [OpenWaterCoordinate] = [],
        notes: String = ""
    ) {
        self.id = UUID()
        self.date = date
        self.sessionType = sessionType
        self.poolLength = poolLength
        self.customPoolLengthMeters = customPoolLengthMeters
        self.totalLaps = totalLaps
        self.totalDistanceMeters = totalDistanceMeters
        self.durationSeconds = durationSeconds
        self.averagePacePer100 = averagePacePer100
        self.bestPacePer100 = bestPacePer100
        self.averageSwolf = averageSwolf
        self.bestSwolf = bestSwolf
        self.averageStrokeCount = averageStrokeCount
        self.totalStrokeCount = totalStrokeCount
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.caloriesBurned = caloriesBurned
        self.laps = laps
        self.strokeBreakdown = strokeBreakdown
        self.heartRateZones = heartRateZones
        self.openWaterCoordinates = openWaterCoordinates
        self.notes = notes
    }
}

nonisolated struct SwimDrill: Identifiable, Sendable {
    let id: UUID
    let name: String
    let category: SwimDrillCategory
    let difficulty: SwimDrillDifficulty
    let durationMinutes: Int
    let description: String
    let purpose: String
    let targetStroke: SwimStrokeType?
    let equipment: String
    let setsReps: String?
    let steps: [String]
    let cues: [String]

    init(
        name: String,
        category: SwimDrillCategory,
        difficulty: SwimDrillDifficulty,
        durationMinutes: Int,
        description: String,
        purpose: String,
        targetStroke: SwimStrokeType? = nil,
        equipment: String = "Pool",
        setsReps: String? = nil,
        steps: [String] = [],
        cues: [String] = []
    ) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.difficulty = difficulty
        self.durationMinutes = durationMinutes
        self.description = description
        self.purpose = purpose
        self.targetStroke = targetStroke
        self.equipment = equipment
        self.setsReps = setsReps
        self.steps = steps
        self.cues = cues
    }
}

nonisolated struct SwimInsight: Identifiable, Sendable {
    let id: UUID
    let kind: SwimInsightKind
    let title: String
    let message: String

    init(kind: SwimInsightKind, title: String, message: String) {
        self.id = UUID()
        self.kind = kind
        self.title = title
        self.message = message
    }
}

nonisolated enum SwimInsightKind: Sendable {
    case progress, suggestion, warning, recovery

    var icon: String {
        switch self {
        case .progress: "arrow.up.right.circle.fill"
        case .suggestion: "lightbulb.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .recovery: "leaf.fill"
        }
    }

    var color: Color {
        switch self {
        case .progress: .green
        case .suggestion: Color(red: 0.2, green: 0.6, blue: 1.0)
        case .warning: .orange
        case .recovery: Color(red: 0.55, green: 0.36, blue: 0.96)
        }
    }

    var kicker: String {
        switch self {
        case .progress: "Progress"
        case .suggestion: "Try This"
        case .warning: "Heads Up"
        case .recovery: "Recovery"
        }
    }
}

nonisolated struct SwimWeeklyFocus: Sendable {
    let kicker: String
    let title: String
    let rationale: String
    let drillName: String?
    let targetStroke: SwimStrokeType?
}

nonisolated enum SwimDrillCategory: String, CaseIterable, Identifiable, Sendable {
    case technique = "Technique"
    case kick = "Kick"
    case pull = "Pull"
    case speed = "Speed"
    case endurance = "Endurance"
    case warmUpCoolDown = "Warm-Up/Cool-Down"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .technique: "hand.raised.fingers.spread.fill"
        case .kick: "shoe.fill"
        case .pull: "figure.pool.swim"
        case .speed: "bolt.fill"
        case .endurance: "heart.fill"
        case .warmUpCoolDown: "leaf.fill"
        }
    }

    var color: Color {
        switch self {
        case .technique: Color(red: 0.2, green: 0.6, blue: 1.0)
        case .kick: Color(red: 0.85, green: 0.25, blue: 0.25)
        case .pull: Color(red: 1.0, green: 0.55, blue: 0.1)
        case .speed: Color(red: 0.85, green: 0.9, blue: 0.15)
        case .endurance: Color(red: 0.55, green: 0.36, blue: 0.96)
        case .warmUpCoolDown: Color(red: 0.2, green: 0.78, blue: 0.35)
        }
    }
}

nonisolated enum SwimDrillDifficulty: String, CaseIterable, Identifiable, Sendable {
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

nonisolated struct CSSResult: Sendable, Codable {
    let date: Date
    let time400m: TimeInterval
    let time200m: TimeInterval
    let cssPacePer100m: Double

    var cssFormatted: String {
        SwimFormatters.formatPace(cssPacePer100m)
    }

    static func calculate(time400m: TimeInterval, time200m: TimeInterval) -> Double {
        let distance400 = 400.0
        let distance200 = 200.0
        guard time400m > time200m else { return 0 }
        return ((time400m - time200m) / (distance400 - distance200)) * 100.0
    }
}

nonisolated struct SwimPaceZone: Identifiable, Sendable {
    let id: UUID
    let name: String
    let paceRange: String
    let color: Color
    let cssPercentage: ClosedRange<Double>

    init(name: String, paceRange: String, color: Color, cssPercentage: ClosedRange<Double>) {
        self.id = UUID()
        self.name = name
        self.paceRange = paceRange
        self.color = color
        self.cssPercentage = cssPercentage
    }
}

nonisolated struct WeeklySwimVolume: Identifiable, Sendable {
    let id: UUID
    let weekStart: Date
    let totalMeters: Double
    let swimCount: Int
    let avgPace: Double
    let avgSwolf: Double

    init(weekStart: Date, totalMeters: Double, swimCount: Int, avgPace: Double, avgSwolf: Double) {
        self.id = UUID()
        self.weekStart = weekStart
        self.totalMeters = totalMeters
        self.swimCount = swimCount
        self.avgPace = avgPace
        self.avgSwolf = avgSwolf
    }
}

nonisolated struct SwimPersonalBest: Identifiable, Sendable {
    let id: UUID
    let distance: String
    let time: TimeInterval
    let pace: Double
    let date: Date

    init(distance: String, time: TimeInterval, pace: Double, date: Date) {
        self.id = UUID()
        self.distance = distance
        self.time = time
        self.pace = pace
        self.date = date
    }

    var timeFormatted: String {
        SwimFormatters.formatDuration(time)
    }
}

nonisolated struct SwimmingSettings: Sendable, Codable {
    var poolLength: PoolLength = .meters25
    var customPoolLengthMeters: Double = 25
    var paceUnit: SwimPaceUnit = .per100m
    var autoDetectStrokes: Bool = true
    var lapAlerts: Bool = true
    var targetLapsPerSession: Int = 40
}

nonisolated enum SwimFormatters {
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    static func formatPace(_ pacePer100: Double) -> String {
        guard pacePer100 > 0 else { return "--:--" }
        let minutes = Int(pacePer100) / 60
        let seconds = Int(pacePer100) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    static func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1fkm", meters / 1000)
        }
        return String(format: "%.0fm", meters)
    }
}

nonisolated enum SwimDrillLibraryData {
    static let all: [SwimDrill] = [
        SwimDrill(
            name: "Catch-Up Drill",
            category: .technique,
            difficulty: .beginner,
            durationMinutes: 5,
            description: "One arm stays extended while the other completes a full stroke cycle. Arms 'catch up' at the front.",
            purpose: "Develop proper catch position, timing, and body rotation.",
            targetStroke: .freestyle,
            equipment: "Pool · optional snorkel",
            setsReps: "4 × 50m",
            steps: [
                "Push off in streamline with both arms extended in front.",
                "Pull with one arm while the other stays extended forward.",
                "Touch the extended hand before starting the next pull.",
                "Breathe to the side of the recovering arm only."
            ],
            cues: [
                "Front hand stays patient — wait for the catch.",
                "Drive rotation from the hips, not the shoulders.",
                "Long, glide-y strokes — quality over turnover."
            ]
        ),
        SwimDrill(
            name: "Fingertip Drag",
            category: .technique,
            difficulty: .beginner,
            durationMinutes: 5,
            description: "Drag fingertips along the water surface during the recovery phase of freestyle.",
            purpose: "Encourage high elbow recovery and relaxed arm return.",
            targetStroke: .freestyle,
            equipment: "Pool",
            setsReps: "6 × 50m easy",
            steps: [
                "Swim freestyle at an easy aerobic pace.",
                "As your arm exits, lift the elbow first and let the fingertips trail.",
                "Drag fingertips along the surface from hip to ear.",
                "Enter clean — fingertips first, no slap."
            ],
            cues: [
                "High elbow, soft hand.",
                "Recovery is rest — let the arm dangle.",
                "Feel the rotation — shoulder up, opposite hip down."
            ]
        ),
        SwimDrill(
            name: "Single-Arm Freestyle",
            category: .technique,
            difficulty: .intermediate,
            durationMinutes: 5,
            description: "Swim freestyle using only one arm while the other stays at your side. Switch every 25m.",
            purpose: "Isolate and improve each arm's pull mechanics and body rotation.",
            targetStroke: .freestyle,
            equipment: "Pool · optional fins",
            setsReps: "6 × 50m (alternate arms)",
            steps: [
                "Push off in streamline, then place one arm at your side.",
                "Pull with the working arm only, keeping the other glued to your hip.",
                "Breathe to the non-working side to force rotation.",
                "Switch arms every 25m."
            ],
            cues: [
                "Rotate the resting hip up out of the water.",
                "High elbow catch — feel the press straight back.",
                "Long body line — chin tucked."
            ]
        ),
        SwimDrill(
            name: "Fist Drill",
            category: .pull,
            difficulty: .intermediate,
            durationMinutes: 5,
            description: "Swim freestyle with closed fists to remove hand paddle effect. Focus on forearm catch.",
            purpose: "Develop forearm catch awareness and improve feel for the water.",
            targetStroke: .freestyle,
            equipment: "Pool",
            setsReps: "4 × 50m fists, 50m open hand",
            steps: [
                "Make tight fists and push off in streamline.",
                "Swim freestyle, pressing water with the forearm.",
                "After each fist 50, swim one with open hands and feel the difference."
            ],
            cues: [
                "Lead the catch with your elbow.",
                "Press water back, not down.",
                "Smooth tempo — don't rush the recovery."
            ]
        ),
        SwimDrill(
            name: "Kickboard Kick Sets",
            category: .kick,
            difficulty: .beginner,
            durationMinutes: 10,
            description: "Hold a kickboard with arms extended and kick freestyle for distance. Keep a steady, rhythmic kick.",
            purpose: "Build leg strength, endurance, and kicking technique.",
            targetStroke: .freestyle,
            equipment: "Kickboard",
            setsReps: "8 × 50m kick",
            steps: [
                "Hold the kickboard at the front edge with arms extended.",
                "Kick from the hips with a steady, narrow flutter.",
                "Face down with regular breaths to the side.",
                "Keep heels just breaking the surface."
            ],
            cues: [
                "Quick ankles, soft feet.",
                "Press the chest down to lift the legs.",
                "Tempo, not splash."
            ]
        ),
        SwimDrill(
            name: "Vertical Kick",
            category: .kick,
            difficulty: .advanced,
            durationMinutes: 5,
            description: "Tread water vertically using only kick (arms crossed on chest). 30 seconds on, 15 seconds rest.",
            purpose: "Develop powerful kick and core stability in deep water.",
            equipment: "Deep end · optional fins",
            setsReps: "6 × 30s on / 15s rest",
            steps: [
                "Tread to deep water and assume a vertical position.",
                "Cross arms over your chest.",
                "Kick hard for 30s, keeping shoulders out of the water.",
                "Rest 15s on the wall, repeat."
            ],
            cues: [
                "Tight core — no hip break.",
                "Small, fast kicks from the hip.",
                "Stay tall, don't lean."
            ]
        ),
        SwimDrill(
            name: "Pull Buoy Sets",
            category: .pull,
            difficulty: .beginner,
            durationMinutes: 10,
            description: "Place pull buoy between thighs and swim freestyle, focusing only on upper body pull.",
            purpose: "Isolate upper body pull mechanics and improve arm strength.",
            targetStroke: .freestyle,
            equipment: "Pull buoy",
            setsReps: "4 × 100m pull",
            steps: [
                "Place pull buoy high between the thighs.",
                "Swim freestyle without kicking — legs stay buoyed.",
                "Maintain a long, balanced body line."
            ],
            cues: [
                "Anchor the catch — pull yourself past the hand.",
                "Don't drop the hips.",
                "Breathe early, exhale fully underwater."
            ]
        ),
        SwimDrill(
            name: "Paddle Pull Sets",
            category: .pull,
            difficulty: .intermediate,
            durationMinutes: 10,
            description: "Swim with hand paddles and pull buoy. Focus on a strong catch and powerful pull-through.",
            purpose: "Build upper body power and develop a strong pull pattern.",
            targetStroke: .freestyle,
            equipment: "Paddles + pull buoy",
            setsReps: "5 × 100m strong",
            steps: [
                "Wear paddles loosely — only one strap if available.",
                "Insert pull buoy between thighs.",
                "Swim with intention; feel the paddle press straight back.",
                "If shoulders feel sharp, drop the paddles."
            ],
            cues: [
                "Slow tempo, strong press.",
                "Elbow leads, hand follows.",
                "Stop if shoulders ache — form first."
            ]
        ),
        SwimDrill(
            name: "Backstroke Rotation",
            category: .technique,
            difficulty: .intermediate,
            durationMinutes: 5,
            description: "Swim backstroke with exaggerated hip rotation, pausing on each side for 3 kicks.",
            purpose: "Improve body rotation and streamlined backstroke position.",
            targetStroke: .backstroke,
            equipment: "Pool",
            setsReps: "6 × 50m",
            steps: [
                "Push off on your back in streamline.",
                "Pull with one arm and rotate so the opposite shoulder breaks the surface.",
                "Pause on the side and kick three times.",
                "Pull through with the other arm and repeat."
            ],
            cues: [
                "Eyes on the ceiling — head still.",
                "Reach long with the gliding arm.",
                "Kick connects to the rotation."
            ]
        ),
        SwimDrill(
            name: "Breaststroke Glide",
            category: .technique,
            difficulty: .beginner,
            durationMinutes: 5,
            description: "After each breaststroke pull, hold a streamlined glide position for a 3-count before the next stroke.",
            purpose: "Improve glide efficiency and reduce drag in breaststroke.",
            targetStroke: .breaststroke,
            equipment: "Pool",
            setsReps: "6 × 50m",
            steps: [
                "Take a normal breaststroke pull and kick.",
                "On the recovery, lock into streamline.",
                "Hold and count 1-2-3 before the next stroke.",
                "Aim to reach further on each glide."
            ],
            cues: [
                "Tight streamline — hands stacked.",
                "Stop kicking once you're gliding.",
                "Make the pool longer."
            ]
        ),
        SwimDrill(
            name: "Butterfly Single-Arm",
            category: .technique,
            difficulty: .advanced,
            durationMinutes: 5,
            description: "Swim butterfly with one arm while the other stays extended. Alternate every 25m.",
            purpose: "Break down butterfly timing and develop arm-specific power.",
            targetStroke: .butterfly,
            equipment: "Pool · fins recommended",
            setsReps: "4 × 50m (alternate arms)",
            steps: [
                "Push off with both arms extended.",
                "Pull with one arm using a full butterfly stroke; other arm stays in front.",
                "Two dolphin kicks per pull — one on entry, one on exit.",
                "Switch arms every 25m."
            ],
            cues: [
                "Two kicks: kick-pull, kick-recover.",
                "Drive the chest down on entry.",
                "Breathe early, head down before the recovery lands."
            ]
        ),
        SwimDrill(
            name: "25m Sprint Sets",
            category: .speed,
            difficulty: .intermediate,
            durationMinutes: 10,
            description: "8x25m all-out sprints with 30 seconds rest between each. Maximum effort on every rep.",
            purpose: "Develop top-end swimming speed and explosive power.",
            equipment: "Pace clock",
            setsReps: "8 × 25m max effort",
            steps: [
                "Warm up 200m easy first.",
                "Push off hard with a strong streamline.",
                "Sprint 25m at 100% effort.",
                "Rest 30 seconds on the wall, repeat."
            ],
            cues: [
                "Underwater kicks set the rep.",
                "High tempo — turnover wins sprints.",
                "Finish into the wall — don't glide."
            ]
        ),
        SwimDrill(
            name: "50m Descending",
            category: .speed,
            difficulty: .advanced,
            durationMinutes: 10,
            description: "6x50m with each swim faster than the last. Start at 70% effort, finish at 100%.",
            purpose: "Build pace awareness and the ability to negative split.",
            targetStroke: .freestyle,
            equipment: "Pace clock",
            setsReps: "6 × 50m descend",
            steps: [
                "Start the first 50 at relaxed effort.",
                "Each 50, drop the time by 1–2 seconds.",
                "50 seconds rest between reps.",
                "Final 50 should be all-out."
            ],
            cues: [
                "Negative split each rep — back half faster.",
                "Keep stroke length even as tempo rises.",
                "Read the clock honestly."
            ]
        ),
        SwimDrill(
            name: "200m Steady Swim",
            category: .endurance,
            difficulty: .beginner,
            durationMinutes: 8,
            description: "Continuous 200m swim at a comfortable, sustainable pace. Focus on breathing rhythm.",
            purpose: "Build aerobic base and swimming endurance.",
            targetStroke: .freestyle,
            equipment: "Pool",
            setsReps: "1 × 200m steady",
            steps: [
                "Push off at conversational pace.",
                "Hold steady breathing every 3 strokes.",
                "Stay relaxed — don't chase the clock.",
                "Finish feeling like you could swim 100 more."
            ],
            cues: [
                "Smooth, repeatable rhythm.",
                "Long body, soft kick.",
                "Exhale fully underwater."
            ]
        ),
        SwimDrill(
            name: "400m Threshold Set",
            category: .endurance,
            difficulty: .advanced,
            durationMinutes: 12,
            description: "3x400m at CSS pace with 45 seconds rest. Maintain consistent pace throughout.",
            purpose: "Develop lactate threshold and race-pace sustainability.",
            targetStroke: .freestyle,
            equipment: "Pace clock",
            setsReps: "3 × 400m @ CSS · 45s rest",
            steps: [
                "Warm up 400m mixed.",
                "Hold CSS pace for each 400, no faster.",
                "Rest 45 seconds between each 400.",
                "Cool down 200m easy after the set."
            ],
            cues: [
                "Same split every lap.",
                "Strong, steady — not heroic.",
                "Last 100 should match the first."
            ]
        ),
        SwimDrill(
            name: "Easy 100m Warm-Up",
            category: .warmUpCoolDown,
            difficulty: .beginner,
            durationMinutes: 3,
            description: "4x25m easy swim mixing strokes. Focus on loosening up shoulders and finding rhythm.",
            purpose: "Prepare the body for the main swim set.",
            equipment: "Pool",
            setsReps: "4 × 25m mixed",
            steps: [
                "25 freestyle easy.",
                "25 backstroke easy.",
                "25 breaststroke easy.",
                "25 your choice, building speed."
            ],
            cues: [
                "Loosen the shoulders before pushing.",
                "Find the breath rhythm.",
                "Don't skip the warm-up — it's the set's foundation."
            ]
        ),
        SwimDrill(
            name: "Cool-Down 200m",
            category: .warmUpCoolDown,
            difficulty: .beginner,
            durationMinutes: 5,
            description: "Easy 200m mixing backstroke and freestyle. Gradually reduce effort to bring heart rate down.",
            purpose: "Aid recovery and flush lactic acid after a hard session.",
            equipment: "Pool",
            setsReps: "1 × 200m easy",
            steps: [
                "50 backstroke easy — open chest, breathe.",
                "50 breaststroke gliding.",
                "50 freestyle relaxed.",
                "50 backstroke, even slower."
            ],
            cues: [
                "Drop the effort with every 50.",
                "Long arms, no rush.",
                "Breathe like you've finished."
            ]
        ),
        SwimDrill(
            name: "Underwater Dolphin Kicks",
            category: .kick,
            difficulty: .advanced,
            durationMinutes: 5,
            description: "Push off the wall and dolphin kick underwater for as far as possible. 8 reps with 20 sec rest.",
            purpose: "Develop powerful underwater kick for turns and starts.",
            targetStroke: .butterfly,
            equipment: "Pool · optional fins",
            setsReps: "8 × max-distance underwater · 20s rest",
            steps: [
                "Push off in tight streamline at least one body length under.",
                "Dolphin kick from the chest — undulate through the hips.",
                "Hold breath as long as comfortable, don't strain.",
                "Surface smoothly into freestyle for the remainder of the lap."
            ],
            cues: [
                "Both legs together — locked feet.",
                "Drive from the core, not the knees.",
                "Streamline tight — no daylight."
            ]
        ),
    ]
}
