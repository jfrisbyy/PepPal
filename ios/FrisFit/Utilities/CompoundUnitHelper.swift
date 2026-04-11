import Foundation

nonisolated enum CompoundUnit: String, Sendable {
    case mg = "mg"
    case mcg = "mcg"
}

nonisolated enum CompoundUnitHelper: Sendable {
    private static let mgCompounds: Set<String> = [
        "Semaglutide",
        "Tirzepatide",
        "Retatrutide",
        "Tesamorelin",
        "MK-677",
        "CJC-1295 (With DAC)",
        "TB-500",
        "GHK-Cu",
        "Thymosin Alpha-1",
        "PT-141",
        "Melanotan II",
        "Melanotan I",
        "BPC-157 Arginate",
        "Pentadecapeptide (BPC-157 Arginate)",
        "LL-37",
        "Enclomiphene",
        "Clomiphene",
        "Tamoxifen",
        "Raloxifene",
        "Cabergoline",
        "Anastrozole",
        "Exemestane",
        "Letrozole",
        "Epitalon",
        "Thymalin",
        "SS-31",
        "Humanin",
        "5-Amino-1MQ",
        "Orforglipron",
        "Cagrilintide",
        "MOTS-c",
        "Dihexa",
        "Cortagen",
        "Cerebrolysin",
        "AOD-9604",
        "ACE-031",
        "YK-11",
        "Ostarine",
        "LGD-4033",
        "RAD-140",
        "L-Carnitine",
        "5-HTP",
        "Epicatechin",
    ]

    static func unit(for compoundName: String) -> CompoundUnit {
        if mgCompounds.contains(compoundName) {
            return .mg
        }
        if let pd = ProtocolDefaultsDatabase.defaults(for: compoundName) {
            return pd.intermediate.unit == "mg" ? .mg : .mcg
        }
        if let profile = CompoundDatabase.all.first(where: { $0.name == compoundName }) {
            let doseRange = profile.keyFacts.typicalDoseRange.lowercased()
            if doseRange.contains("mg") && !doseRange.contains("mcg") {
                return .mg
            }
        }
        return .mcg
    }

    static func displayDose(_ mcgValue: Double, for compoundName: String) -> String {
        let compUnit = unit(for: compoundName)
        switch compUnit {
        case .mg:
            let mgValue = mcgValue / 1000.0
            if mgValue == mgValue.rounded() && mgValue >= 1 {
                return "\(Int(mgValue)) mg"
            }
            return "\(formatDecimal(mgValue)) mg"
        case .mcg:
            if mcgValue == mcgValue.rounded() {
                return "\(Int(mcgValue)) mcg"
            }
            return "\(formatDecimal(mcgValue)) mcg"
        }
    }

    static func displayDoseShort(_ mcgValue: Double, for compoundName: String) -> String {
        let compUnit = unit(for: compoundName)
        switch compUnit {
        case .mg:
            let mgValue = mcgValue / 1000.0
            if mgValue == mgValue.rounded() && mgValue >= 1 {
                return "\(Int(mgValue))mg"
            }
            return "\(formatDecimal(mgValue))mg"
        case .mcg:
            if mcgValue == mcgValue.rounded() {
                return "\(Int(mcgValue))mcg"
            }
            return "\(formatDecimal(mcgValue))mcg"
        }
    }

    static func toMcg(_ displayValue: Double, for compoundName: String) -> Double {
        let compUnit = unit(for: compoundName)
        switch compUnit {
        case .mg: return displayValue * 1000.0
        case .mcg: return displayValue
        }
    }

    static func fromMcg(_ mcgValue: Double, for compoundName: String) -> Double {
        let compUnit = unit(for: compoundName)
        switch compUnit {
        case .mg: return mcgValue / 1000.0
        case .mcg: return mcgValue
        }
    }

    static func defaultDoseText(for compoundName: String) -> String {
        if let pd = ProtocolDefaultsDatabase.defaults(for: compoundName) {
            return pd.intermediate.defaultDoseText
        }
        if let profile = CompoundDatabase.all.first(where: { $0.name == compoundName }),
           let tiered = profile.tieredDosing.first(where: { $0.tier == "Intermediate" }) ?? profile.tieredDosing.first {
            return tiered.dose.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        }
        let compUnit = unit(for: compoundName)
        return compUnit == .mg ? "1" : "250"
    }

    static func typicalRangeHint(for compoundName: String) -> String? {
        if let pd = ProtocolDefaultsDatabase.defaults(for: compoundName) {
            let range = pd.intermediate
            return "Typical: \(range.displayString) \(pd.defaultFrequency)"
        }
        if let profile = CompoundDatabase.all.first(where: { $0.name == compoundName }) {
            let kf = profile.keyFacts
            if !kf.typicalDoseRange.isEmpty {
                return "Typical: \(kf.typicalDoseRange)"
            }
        }
        return nil
    }

    private static func formatDecimal(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }
        let formatted = String(format: "%.2f", value)
        if formatted.hasSuffix("0") {
            return String(format: "%.1f", value)
        }
        return formatted
    }
}
