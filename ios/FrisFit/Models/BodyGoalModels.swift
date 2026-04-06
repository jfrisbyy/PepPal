import SwiftUI

nonisolated enum FitnessGoalType: String, CaseIterable, Identifiable, Sendable, Codable {
    case weightLoss = "Weight Loss"
    case weightGain = "Weight Gain"
    case maintain = "Maintain"
    case recomp = "Body Recomp"
    case bulking = "Bulking"
    case cutting = "Cutting"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .weightLoss: return "arrow.down.right"
        case .weightGain: return "arrow.up.right"
        case .maintain: return "equal"
        case .recomp: return "arrow.triangle.2.circlepath"
        case .bulking: return "arrow.up.circle.fill"
        case .cutting: return "arrow.down.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .weightLoss, .cutting: return Color(red: 255/255, green: 107/255, blue: 107/255)
        case .weightGain, .bulking: return Color(red: 76/255, green: 217/255, blue: 100/255)
        case .maintain: return Color(red: 0, green: 229/255, blue: 255/255)
        case .recomp: return Color(red: 139/255, green: 92/255, blue: 246/255)
        }
    }

    var subtitle: String {
        switch self {
        case .weightLoss: return "Caloric deficit"
        case .weightGain: return "Caloric surplus"
        case .maintain: return "Maintenance calories"
        case .recomp: return "Build muscle, lose fat"
        case .bulking: return "Aggressive surplus"
        case .cutting: return "Aggressive deficit"
        }
    }
}

nonisolated struct WeightEntry: Identifiable, Sendable, Codable {
    let id: UUID
    let weight: Double
    let date: Date
    let note: String

    init(id: UUID = UUID(), weight: Double, date: Date, note: String = "") {
        self.id = id
        self.weight = weight
        self.date = date
        self.note = note
    }
}

nonisolated struct BodyMeasurement: Identifiable, Sendable, Codable {
    let id: UUID
    let date: Date
    let chest: Double?
    let waist: Double?
    let hips: Double?
    let bicepLeft: Double?
    let bicepRight: Double?
    let thighLeft: Double?
    let thighRight: Double?
    let neck: Double?

    init(id: UUID = UUID(), date: Date, chest: Double? = nil, waist: Double? = nil, hips: Double? = nil, bicepLeft: Double? = nil, bicepRight: Double? = nil, thighLeft: Double? = nil, thighRight: Double? = nil, neck: Double? = nil) {
        self.id = id
        self.date = date
        self.chest = chest
        self.waist = waist
        self.hips = hips
        self.bicepLeft = bicepLeft
        self.bicepRight = bicepRight
        self.thighLeft = thighLeft
        self.thighRight = thighRight
        self.neck = neck
    }
}

nonisolated struct ProgressPhoto: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let label: String

    init(id: UUID = UUID(), date: Date, label: String = "") {
        self.id = id
        self.date = date
        self.label = label
    }
}

nonisolated struct BMIData: Sendable {
    let value: Double
    let category: String
    let color: Color

    init(weight: Double, heightCm: Double) {
        let heightM = heightCm / 100.0
        guard heightM > 0 else {
            self.value = 0
            self.category = "Unknown"
            self.color = PepTheme.textSecondary
            return
        }
        self.value = weight / (heightM * heightM)
        switch self.value {
        case ..<18.5:
            self.category = "Underweight"
            self.color = Color(red: 0, green: 229/255, blue: 255/255)
        case 18.5..<25:
            self.category = "Normal"
            self.color = Color(red: 76/255, green: 217/255, blue: 100/255)
        case 25..<30:
            self.category = "Overweight"
            self.color = Color(red: 255/255, green: 184/255, blue: 0)
        default:
            self.category = "Obese"
            self.color = Color(red: 255/255, green: 107/255, blue: 107/255)
        }
    }
}
