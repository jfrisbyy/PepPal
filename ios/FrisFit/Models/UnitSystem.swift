import Foundation

nonisolated enum UnitSystem: String, CaseIterable, Sendable, Codable {
    case imperial
    case metric

    var label: String {
        switch self {
        case .imperial: return "Imperial"
        case .metric: return "Metric"
        }
    }

    var heightUnitLabel: String {
        switch self {
        case .imperial: return "ft / in"
        case .metric: return "cm"
        }
    }

    var weightUnitLabel: String {
        switch self {
        case .imperial: return "lb"
        case .metric: return "kg"
        }
    }

    var lengthUnitLabel: String {
        switch self {
        case .imperial: return "in"
        case .metric: return "cm"
        }
    }
}

nonisolated enum UnitConversion: Sendable {
    static let cmPerInch: Double = 2.54
    static let kgPerPound: Double = 0.45359237

    static func cmToInches(_ cm: Double) -> Double { cm / cmPerInch }
    static func inchesToCm(_ inches: Double) -> Double { inches * cmPerInch }

    static func kgToPounds(_ kg: Double) -> Double { kg / kgPerPound }
    static func poundsToKg(_ lb: Double) -> Double { lb * kgPerPound }

    static func cmToFeetInches(_ cm: Double) -> (feet: Int, inches: Int) {
        let totalInches = cmToInches(cm)
        let feet = Int(totalInches / 12)
        let inches = Int(totalInches.rounded()) - feet * 12
        if inches >= 12 { return (feet + 1, 0) }
        if inches < 0 { return (max(feet - 1, 0), 11) }
        return (feet, inches)
    }

    static func feetInchesToCm(feet: Int, inches: Int) -> Double {
        inchesToCm(Double(feet) * 12 + Double(inches))
    }
}

@MainActor
enum UnitSystemStore {
    static let key = "peppal.unitSystem.v1"

    static func current() -> UnitSystem {
        if let raw = UserDefaults.standard.string(forKey: key),
           let system = UnitSystem(rawValue: raw) {
            return system
        }
        return Locale.current.measurementSystem == .metric ? .metric : .imperial
    }

    static func save(_ system: UnitSystem) {
        UserDefaults.standard.set(system.rawValue, forKey: key)
        let weightUnit: WeightUnit = system == .metric ? .kg : .lbs
        UserDefaults.standard.set(weightUnit.rawValue, forKey: "weightUnitPref")
    }
}
