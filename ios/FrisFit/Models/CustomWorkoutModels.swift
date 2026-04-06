import Foundation

nonisolated enum RunningWorkoutType: String, CaseIterable, Identifiable, Sendable {
    case intervalSession = "Intervals"
    case tempoRun = "Tempo Run"
    case hillRepeats = "Hill Repeats"
    case progressionRun = "Progression"
    case fartlek = "Fartlek"
    case longRun = "Long Run"
    case easyRun = "Easy Run"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .intervalSession: "repeat"
        case .tempoRun: "speedometer"
        case .hillRepeats: "mountain.2.fill"
        case .progressionRun: "chart.line.uptrend.xyaxis"
        case .fartlek: "shuffle"
        case .longRun: "road.lanes"
        case .easyRun: "figure.run"
        }
    }
}

nonisolated struct RunningInterval: Identifiable, Sendable {
    let id: UUID
    var type: RunningIntervalType
    var distanceMeters: Int
    var durationSeconds: Int
    var targetPaceMin: Double
    var targetPaceMax: Double
    var restSeconds: Int
    var repetitions: Int

    init(type: RunningIntervalType = .work, distanceMeters: Int = 400, durationSeconds: Int = 120, targetPaceMin: Double = 6.0, targetPaceMax: Double = 7.0, restSeconds: Int = 60, repetitions: Int = 4) {
        self.id = UUID()
        self.type = type
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.targetPaceMin = targetPaceMin
        self.targetPaceMax = targetPaceMax
        self.restSeconds = restSeconds
        self.repetitions = repetitions
    }

    var description: String {
        "\(repetitions)x\(distanceMeters)m @ \(String(format: "%.0f", targetPaceMin))-\(String(format: "%.0f", targetPaceMax)) min/mi"
    }
}

nonisolated enum RunningIntervalType: String, CaseIterable, Identifiable, Sendable {
    case work = "Work"
    case recovery = "Recovery"
    case warmup = "Warm-up"
    case cooldown = "Cool-down"
    var id: String { rawValue }
}

nonisolated struct CustomRunWorkout: Identifiable, Sendable {
    let id: UUID
    var name: String
    var type: RunningWorkoutType
    var intervals: [RunningInterval]
    let dateCreated: Date

    init(name: String, type: RunningWorkoutType = .intervalSession, intervals: [RunningInterval] = [], dateCreated: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.intervals = intervals
        self.dateCreated = dateCreated
    }

    var totalDistance: Int {
        intervals.reduce(0) { $0 + $1.distanceMeters * $1.repetitions }
    }

    var estimatedDurationMinutes: Int {
        let workTime = intervals.reduce(0) { $0 + $1.durationSeconds * $1.repetitions }
        let restTime = intervals.reduce(0) { $0 + $1.restSeconds * ($1.repetitions - 1) }
        return (workTime + restTime) / 60
    }
}

nonisolated enum CyclingWorkoutType: String, CaseIterable, Identifiable, Sendable {
    case intervals = "Intervals"
    case sweetSpot = "Sweet Spot"
    case endurance = "Endurance"
    case hillClimb = "Hill Climb"
    case recovery = "Recovery"
    case ftp = "FTP Test"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .intervals: "repeat"
        case .sweetSpot: "heart.fill"
        case .endurance: "road.lanes"
        case .hillClimb: "mountain.2.fill"
        case .recovery: "leaf.fill"
        case .ftp: "gauge.with.needle.fill"
        }
    }
}

nonisolated struct CyclingInterval: Identifiable, Sendable {
    let id: UUID
    var label: String
    var durationMinutes: Int
    var targetPowerLow: Int
    var targetPowerHigh: Int
    var cadenceLow: Int
    var cadenceHigh: Int
    var restMinutes: Int
    var repetitions: Int

    init(label: String = "Work", durationMinutes: Int = 5, targetPowerLow: Int = 180, targetPowerHigh: Int = 220, cadenceLow: Int = 85, cadenceHigh: Int = 95, restMinutes: Int = 2, repetitions: Int = 4) {
        self.id = UUID()
        self.label = label
        self.durationMinutes = durationMinutes
        self.targetPowerLow = targetPowerLow
        self.targetPowerHigh = targetPowerHigh
        self.cadenceLow = cadenceLow
        self.cadenceHigh = cadenceHigh
        self.restMinutes = restMinutes
        self.repetitions = repetitions
    }

    var description: String {
        "\(repetitions)x\(durationMinutes)min @ \(targetPowerLow)-\(targetPowerHigh)W"
    }
}

nonisolated struct CustomCyclingWorkout: Identifiable, Sendable {
    let id: UUID
    var name: String
    var type: CyclingWorkoutType
    var intervals: [CyclingInterval]
    let dateCreated: Date

    init(name: String, type: CyclingWorkoutType = .intervals, intervals: [CyclingInterval] = [], dateCreated: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.intervals = intervals
        self.dateCreated = dateCreated
    }

    var estimatedDurationMinutes: Int {
        intervals.reduce(0) { $0 + ($1.durationMinutes + $1.restMinutes) * $1.repetitions }
    }
}

nonisolated struct SoccerDrillItem: Identifiable, Sendable {
    let id: UUID
    var name: String
    var category: SoccerDrillCategory
    var durationMinutes: Int
    var notes: String

    init(name: String = "", category: SoccerDrillCategory = .passing, durationMinutes: Int = 10, notes: String = "") {
        self.id = UUID()
        self.name = name
        self.category = category
        self.durationMinutes = durationMinutes
        self.notes = notes
    }
}

nonisolated struct CustomSoccerSession: Identifiable, Sendable {
    let id: UUID
    var name: String
    var drills: [SoccerDrillItem]
    let dateCreated: Date

    init(name: String, drills: [SoccerDrillItem] = [], dateCreated: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.drills = drills
        self.dateCreated = dateCreated
    }

    var totalDuration: Int {
        drills.reduce(0) { $0 + $1.durationMinutes }
    }
}

nonisolated struct TennisDrillItem: Identifiable, Sendable {
    let id: UUID
    var name: String
    var category: TennisDrillCategory
    var durationMinutes: Int
    var notes: String

    init(name: String = "", category: TennisDrillCategory = .groundstroke, durationMinutes: Int = 10, notes: String = "") {
        self.id = UUID()
        self.name = name
        self.category = category
        self.durationMinutes = durationMinutes
        self.notes = notes
    }
}

nonisolated struct CustomTennisSession: Identifiable, Sendable {
    let id: UUID
    var name: String
    var drills: [TennisDrillItem]
    let dateCreated: Date

    init(name: String, drills: [TennisDrillItem] = [], dateCreated: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.drills = drills
        self.dateCreated = dateCreated
    }

    var totalDuration: Int {
        drills.reduce(0) { $0 + $1.durationMinutes }
    }
}
