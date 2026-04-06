import Foundation

nonisolated enum MuscleGroup: String, CaseIterable, Identifiable, Sendable, Codable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case biceps = "Biceps"
    case triceps = "Triceps"
    case quadriceps = "Quadriceps"
    case hamstrings = "Hamstrings"
    case glutes = "Glutes"
    case calves = "Calves"
    case core = "Core"
    case forearms = "Forearms"
    case fullBody = "Full Body"
    case cardio = "Cardio"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .chest: "figure.strengthtraining.traditional"
        case .back: "figure.rowing"
        case .shoulders: "figure.arms.open"
        case .biceps: "figure.strengthtraining.functional"
        case .triceps: "figure.cooldown"
        case .quadriceps: "figure.step.training"
        case .hamstrings: "figure.flexibility"
        case .glutes: "figure.pilates"
        case .calves: "figure.walk"
        case .core: "figure.core.training"
        case .forearms: "hand.raised.fingers.spread"
        case .fullBody: "figure.cross.training"
        case .cardio: "figure.run"
        }
    }
}

nonisolated enum MovementPattern: String, Sendable, Codable {
    case horizontalPress = "Horizontal Press"
    case verticalPress = "Vertical Press"
    case horizontalPull = "Horizontal Pull"
    case verticalPull = "Vertical Pull"
    case hipHinge = "Hip Hinge"
    case squat = "Squat"
    case lunge = "Lunge"
    case isolation = "Isolation"
    case carry = "Carry"
    case rotation = "Rotation"
    case plank = "Plank"
    case cardioPattern = "Cardio"
    case plyometric = "Plyometric"
    case flexion = "Flexion"
    case extension_ = "Extension"
}

nonisolated enum Equipment: String, CaseIterable, Sendable, Codable {
    case barbell = "Barbell"
    case dumbbell = "Dumbbell"
    case machine = "Machine"
    case cable = "Cable"
    case bodyweight = "Bodyweight"
    case band = "Band"
    case kettlebell = "Kettlebell"
    case none = "None"

    var icon: String {
        switch self {
        case .barbell: "dumbbell.fill"
        case .dumbbell: "dumbbell"
        case .machine: "gearshape.fill"
        case .cable: "cable.connector"
        case .bodyweight: "figure.stand"
        case .band: "circle.dotted"
        case .kettlebell: "scalemass.fill"
        case .none: "minus.circle"
        }
    }
}

nonisolated enum Difficulty: String, CaseIterable, Sendable, Codable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"

    var color: String {
        switch self {
        case .beginner: "green"
        case .intermediate: "orange"
        case .advanced: "red"
        }
    }
}

nonisolated enum ExerciseType: String, Sendable, Codable {
    case compound = "Compound"
    case isolation = "Isolation"
}

nonisolated enum TrackingType: String, Sendable, Codable {
    case weightReps = "weight_reps"
    case bodyweightReps = "bodyweight_reps"
    case time = "time"
    case distanceTime = "distance_time"
    case repsOnly = "reps_only"

    var label: String {
        switch self {
        case .weightReps: "Weight & Reps"
        case .bodyweightReps: "Bodyweight Reps"
        case .time: "Time"
        case .distanceTime: "Distance & Time"
        case .repsOnly: "Reps Only"
        }
    }
}

nonisolated struct Exercise: Identifiable, Hashable, Sendable, Codable {
    nonisolated static func == (lhs: Exercise, rhs: Exercise) -> Bool { lhs.id == rhs.id }
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }

    let id: String
    let name: String
    let primaryMuscle: MuscleGroup
    let secondaryMuscles: [MuscleGroup]
    let movementPattern: MovementPattern
    let equipment: Equipment
    let difficulty: Difficulty
    let exerciseType: ExerciseType
    let trackingType: TrackingType
    let defaultRestSeconds: Int
    let instructions: [String]
    let commonMistakes: [String]
    let proTips: [String]
}
