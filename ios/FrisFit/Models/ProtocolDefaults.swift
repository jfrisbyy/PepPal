import Foundation

nonisolated struct DoseRange: Sendable {
    let low: Double
    let high: Double
    let unit: String

    init(_ low: Double, _ high: Double, unit: String = "mcg") {
        self.low = low
        self.high = high
        self.unit = unit
    }

    init(_ value: Double, unit: String = "mcg") {
        self.low = value
        self.high = value
        self.unit = unit
    }

    var displayString: String {
        if low == high {
            if unit == "mg" {
                return formatMg(low)
            }
            return "\(formatNumber(low)) \(unit)"
        }
        if unit == "mg" {
            return "\(formatMg(low)) - \(formatMg(high))"
        }
        return "\(formatNumber(low)) - \(formatNumber(high)) \(unit)"
    }

    var midpoint: Double {
        (low + high) / 2.0
    }

    var defaultDoseText: String {
        if low == high {
            return formatNumber(low)
        }
        return formatNumber(low)
    }

    private func formatNumber(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }

    private func formatMg(_ value: Double) -> String {
        let formatted = formatNumber(value)
        return "\(formatted) mg"
    }
}

nonisolated struct WarningZone: Sendable {
    let low: Double
    let high: Double
    let warning: String

    init(_ low: Double, _ high: Double, _ warning: String) {
        self.low = low
        self.high = high
        self.warning = warning
    }
}

nonisolated struct TitrationStep2: Sendable {
    let weekRange: String
    let dose: String
}

nonisolated struct ProtocolDefault: Sendable {
    let compoundName: String
    let beginner: DoseRange
    let intermediate: DoseRange
    let advanced: DoseRange
    let defaultFrequency: String
    let defaultCycle: String
    let route: String
    let greenZone: WarningZone
    let yellowZone: WarningZone
    let redZone: WarningZone
    let frequencyWarning: String
    let titrationSchedule: [TitrationStep2]?

    func doseRange(for level: ExperienceLevel) -> DoseRange {
        switch level {
        case .beginner: return beginner
        case .intermediate: return intermediate
        case .advanced: return advanced
        }
    }
}

nonisolated enum ProtocolDefaultsDatabase: Sendable {
    static func defaults(for compoundName: String) -> ProtocolDefault? {
        all.first { $0.compoundName == compoundName }
    }

    static let all: [ProtocolDefault] = [
        ProtocolDefault(
            compoundName: "Sermorelin",
            beginner: DoseRange(100, 200),
            intermediate: DoseRange(200, 300),
            advanced: DoseRange(300, 500),
            defaultFrequency: "Once nightly (30-60 min before bed)",
            defaultCycle: "3-6 months",
            route: "Subcutaneous injection",
            greenZone: WarningZone(100, 300, "Safe therapeutic range"),
            yellowZone: WarningZone(300, 500, "Higher dose — monitor for side effects"),
            redZone: WarningZone(500, 1000, "Exceeds typical protocols — increased risk"),
            frequencyWarning: "Must be injected fasted (2+ hours after eating). Insulin blunts GH release.",
            titrationSchedule: nil
        ),
        ProtocolDefault(
            compoundName: "Ipamorelin",
            beginner: DoseRange(100, 150),
            intermediate: DoseRange(150, 200),
            advanced: DoseRange(200, 300),
            defaultFrequency: "1-2x daily",
            defaultCycle: "8-12 weeks",
            route: "Subcutaneous injection",
            greenZone: WarningZone(100, 200, "Safe therapeutic range"),
            yellowZone: WarningZone(200, 300, "Higher dose — diminishing returns possible"),
            redZone: WarningZone(300, 600, "Exceeds typical protocols"),
            frequencyWarning: "Best used fasted. Almost always stacked with CJC-1295 (No DAC) for synergy.",
            titrationSchedule: nil
        ),
        ProtocolDefault(
            compoundName: "GHRP-2",
            beginner: DoseRange(100),
            intermediate: DoseRange(100, 200),
            advanced: DoseRange(200, 300),
            defaultFrequency: "1-3x daily (fasted)",
            defaultCycle: "8-12 weeks",
            route: "Subcutaneous injection",
            greenZone: WarningZone(100, 200, "Safe therapeutic range"),
            yellowZone: WarningZone(200, 300, "Higher dose — increased hunger and cortisol elevation"),
            redZone: WarningZone(300, 600, "Exceeds typical protocols — significant cortisol/prolactin risk"),
            frequencyWarning: "Must be used fasted. Causes significant hunger — plan meals accordingly.",
            titrationSchedule: nil
        ),
        ProtocolDefault(
            compoundName: "GHRP-6",
            beginner: DoseRange(100),
            intermediate: DoseRange(100, 200),
            advanced: DoseRange(200, 300),
            defaultFrequency: "1-3x daily (fasted)",
            defaultCycle: "8-12 weeks",
            route: "Subcutaneous injection",
            greenZone: WarningZone(100, 200, "Safe therapeutic range"),
            yellowZone: WarningZone(200, 300, "Higher dose — extreme hunger, cortisol/prolactin elevation"),
            redZone: WarningZone(300, 600, "Exceeds typical protocols — significant side effect risk"),
            frequencyWarning: "Causes extreme hunger within 20 minutes of injection. Must be used fasted.",
            titrationSchedule: nil
        ),
        ProtocolDefault(
            compoundName: "Hexarelin",
            beginner: DoseRange(50, 100),
            intermediate: DoseRange(100),
            advanced: DoseRange(100, 200),
            defaultFrequency: "1-2x daily",
            defaultCycle: "4-6 weeks maximum",
            route: "Subcutaneous injection",
            greenZone: WarningZone(50, 100, "Safe therapeutic range"),
            yellowZone: WarningZone(100, 200, "Higher dose — increased cortisol/prolactin"),
            redZone: WarningZone(200, 400, "Exceeds typical protocols — rapid desensitization risk"),
            frequencyWarning: "Desensitization occurs faster than other GHRPs. Keep cycles short (4-6 weeks max).",
            titrationSchedule: nil
        ),
        ProtocolDefault(
            compoundName: "MK-677",
            beginner: DoseRange(10, 15, unit: "mg"),
            intermediate: DoseRange(15, 25, unit: "mg"),
            advanced: DoseRange(25, unit: "mg"),
            defaultFrequency: "Once daily (evening, with food)",
            defaultCycle: "3-6 months",
            route: "Oral",
            greenZone: WarningZone(10, 25, "Safe therapeutic range"),
            yellowZone: WarningZone(25, 50, "Higher dose — increased water retention and insulin resistance"),
            redZone: WarningZone(50, 100, "Dangerous — severe insulin resistance and edema risk"),
            frequencyWarning: "Take with food to reduce nausea. Monitor fasting blood glucose — MK-677 impairs insulin sensitivity.",
            titrationSchedule: nil
        ),
        ProtocolDefault(
            compoundName: "Tesamorelin",
            beginner: DoseRange(1, unit: "mg"),
            intermediate: DoseRange(1, 2, unit: "mg"),
            advanced: DoseRange(2, unit: "mg"),
            defaultFrequency: "Once daily (before bed)",
            defaultCycle: "3-6 months",
            route: "Subcutaneous injection",
            greenZone: WarningZone(1, 2, "FDA-approved therapeutic range"),
            yellowZone: WarningZone(2, 4, "Above standard — monitor HbA1c"),
            redZone: WarningZone(4, 10, "Exceeds all known protocols"),
            frequencyWarning: "Must be injected fasted. High cost — ensure legitimate source.",
            titrationSchedule: nil
        ),
        ProtocolDefault(
            compoundName: "CJC-1295 (No DAC)",
            beginner: DoseRange(100),
            intermediate: DoseRange(100, 200),
            advanced: DoseRange(200, 300),
            defaultFrequency: "1-3x daily (always with a GHRP)",
            defaultCycle: "8-12 weeks",
            route: "Subcutaneous injection",
            greenZone: WarningZone(100, 200, "Safe therapeutic range"),
            yellowZone: WarningZone(200, 300, "Higher dose — diminishing returns"),
            redZone: WarningZone(300, 600, "Exceeds typical protocols"),
            frequencyWarning: "Almost never used alone. Stack with Ipamorelin or GHRP-2 for synergy. Must be fasted.",
            titrationSchedule: nil
        ),
        ProtocolDefault(
            compoundName: "CJC-1295 (With DAC)",
            beginner: DoseRange(1, unit: "mg"),
            intermediate: DoseRange(1, 2, unit: "mg"),
            advanced: DoseRange(2, unit: "mg"),
            defaultFrequency: "1-2x weekly",
            defaultCycle: "8-12 weeks",
            route: "Subcutaneous injection",
            greenZone: WarningZone(1, 2, "Typical therapeutic range"),
            yellowZone: WarningZone(2, 4, "Higher dose — increased water retention and insulin resistance"),
            redZone: WarningZone(4, 10, "Dangerous — pituitary desensitization risk"),
            frequencyWarning: "Causes continuous GH elevation ('GH bleed'). Not recommended for beginners by many experts.",
            titrationSchedule: nil
        ),
        ProtocolDefault(
            compoundName: "Semaglutide",
            beginner: DoseRange(0.25, unit: "mg"),
            intermediate: DoseRange(0.5, 1, unit: "mg"),
            advanced: DoseRange(1.7, 2.4, unit: "mg"),
            defaultFrequency: "1x weekly",
            defaultCycle: "Ongoing",
            route: "Subcutaneous injection",
            greenZone: WarningZone(0.25, 1, "Standard titration range"),
            yellowZone: WarningZone(1, 2.4, "Higher dose — monitor GI side effects"),
            redZone: WarningZone(2.4, 5, "Exceeds FDA-approved dose"),
            frequencyWarning: "Inject same day each week. Slow titration is mandatory — increase dose every 4 weeks minimum.",
            titrationSchedule: [
                TitrationStep2(weekRange: "Weeks 1-4", dose: "0.25 mg"),
                TitrationStep2(weekRange: "Weeks 5-8", dose: "0.5 mg"),
                TitrationStep2(weekRange: "Weeks 9-12", dose: "1.0 mg"),
                TitrationStep2(weekRange: "Weeks 13-16", dose: "1.7 mg"),
                TitrationStep2(weekRange: "Weeks 17+", dose: "2.4 mg"),
            ]
        ),
        ProtocolDefault(
            compoundName: "Tirzepatide",
            beginner: DoseRange(2.5, unit: "mg"),
            intermediate: DoseRange(5, 7.5, unit: "mg"),
            advanced: DoseRange(10, 15, unit: "mg"),
            defaultFrequency: "1x weekly",
            defaultCycle: "Ongoing",
            route: "Subcutaneous injection",
            greenZone: WarningZone(2.5, 7.5, "Standard titration range"),
            yellowZone: WarningZone(7.5, 15, "Higher dose — monitor GI tolerance"),
            redZone: WarningZone(15, 30, "Exceeds FDA-approved dose"),
            frequencyWarning: "Inject same day each week. Increase by 2.5 mg every 4 weeks. Do not rush titration.",
            titrationSchedule: [
                TitrationStep2(weekRange: "Weeks 1-4", dose: "2.5 mg"),
                TitrationStep2(weekRange: "Weeks 5-8", dose: "5.0 mg"),
                TitrationStep2(weekRange: "Weeks 9-12", dose: "7.5 mg"),
                TitrationStep2(weekRange: "Weeks 13-16", dose: "10.0 mg"),
                TitrationStep2(weekRange: "Weeks 17-20", dose: "12.5 mg"),
                TitrationStep2(weekRange: "Weeks 21+", dose: "15.0 mg"),
            ]
        ),
        ProtocolDefault(
            compoundName: "Retatrutide",
            beginner: DoseRange(1, 2, unit: "mg"),
            intermediate: DoseRange(4, 8, unit: "mg"),
            advanced: DoseRange(8, 12, unit: "mg"),
            defaultFrequency: "1x weekly",
            defaultCycle: "Ongoing",
            route: "Subcutaneous injection",
            greenZone: WarningZone(1, 8, "Standard titration range"),
            yellowZone: WarningZone(8, 12, "Higher dose — monitor closely"),
            redZone: WarningZone(12, 20, "Exceeds known trial doses"),
            frequencyWarning: "Monthly dose escalation required. Start at lowest dose and titrate up slowly.",
            titrationSchedule: [
                TitrationStep2(weekRange: "Month 1", dose: "1 mg"),
                TitrationStep2(weekRange: "Month 2", dose: "2 mg"),
                TitrationStep2(weekRange: "Month 3", dose: "4 mg"),
                TitrationStep2(weekRange: "Month 4", dose: "8 mg"),
                TitrationStep2(weekRange: "Month 5+", dose: "12 mg"),
            ]
        ),
        ProtocolDefault(
            compoundName: "BPC-157",
            beginner: DoseRange(250),
            intermediate: DoseRange(250, 500),
            advanced: DoseRange(500, 750),
            defaultFrequency: "1-2x daily",
            defaultCycle: "4-8 weeks",
            route: "Subcutaneous injection",
            greenZone: WarningZone(200, 500, "Safe therapeutic range"),
            yellowZone: WarningZone(500, 1000, "Higher dose — generally well tolerated"),
            redZone: WarningZone(1000, 2000, "Exceeds typical protocols"),
            frequencyWarning: "Can be injected near the injury site for localized effect.",
            titrationSchedule: nil
        ),
        ProtocolDefault(
            compoundName: "TB-500",
            beginner: DoseRange(2, unit: "mg"),
            intermediate: DoseRange(2, 2.5, unit: "mg"),
            advanced: DoseRange(2.5, 5, unit: "mg"),
            defaultFrequency: "2-3x weekly",
            defaultCycle: "4-6 weeks loading, then maintenance",
            route: "Subcutaneous injection",
            greenZone: WarningZone(2, 2.5, "Standard loading range"),
            yellowZone: WarningZone(2.5, 5, "Higher loading dose"),
            redZone: WarningZone(5, 10, "Exceeds typical protocols"),
            frequencyWarning: "Loading phase 2-3x weekly for 4-6 weeks, then reduce to 1x weekly for maintenance.",
            titrationSchedule: nil
        ),
        ProtocolDefault(
            compoundName: "PT-141",
            beginner: DoseRange(0.5, 1, unit: "mg"),
            intermediate: DoseRange(1, 1.75, unit: "mg"),
            advanced: DoseRange(1.75, 2, unit: "mg"),
            defaultFrequency: "As needed (1-2 hrs before)",
            defaultCycle: "As needed (max 8x/month)",
            route: "Subcutaneous injection",
            greenZone: WarningZone(0.5, 1.75, "Standard range"),
            yellowZone: WarningZone(1.75, 3, "Higher dose — increased nausea risk"),
            redZone: WarningZone(3, 5, "Exceeds typical protocols"),
            frequencyWarning: "Do not use more than once in 24 hours. May cause nausea — start low.",
            titrationSchedule: nil
        ),
        ProtocolDefault(
            compoundName: "Melanotan II",
            beginner: DoseRange(0.25, 0.5, unit: "mg"),
            intermediate: DoseRange(0.5, 1, unit: "mg"),
            advanced: DoseRange(1, unit: "mg"),
            defaultFrequency: "Daily (loading) then 2x weekly",
            defaultCycle: "2-3 weeks loading, then maintenance",
            route: "Subcutaneous injection",
            greenZone: WarningZone(0.25, 1, "Standard range"),
            yellowZone: WarningZone(1, 2, "Higher dose — more side effects"),
            redZone: WarningZone(2, 5, "Exceeds typical protocols"),
            frequencyWarning: "Start very low to assess nausea tolerance. Loading phase daily, then reduce.",
            titrationSchedule: nil
        ),
        ProtocolDefault(
            compoundName: "GHK-Cu",
            beginner: DoseRange(1, unit: "mg"),
            intermediate: DoseRange(1, 2, unit: "mg"),
            advanced: DoseRange(2, unit: "mg"),
            defaultFrequency: "1-2x daily",
            defaultCycle: "4-8 weeks (30 on / 30 off)",
            route: "Subcutaneous injection",
            greenZone: WarningZone(1, 2, "Standard range"),
            yellowZone: WarningZone(2, 4, "Higher dose — increased PIP"),
            redZone: WarningZone(4, 10, "Exceeds typical protocols"),
            frequencyWarning: "Known for painful injection site reactions (PIP). Inject slowly.",
            titrationSchedule: nil
        ),
        ProtocolDefault(
            compoundName: "Enclomiphene",
            beginner: DoseRange(6.25, 12.5, unit: "mg"),
            intermediate: DoseRange(12.5, 25, unit: "mg"),
            advanced: DoseRange(25, unit: "mg"),
            defaultFrequency: "1x daily or EOD",
            defaultCycle: "4-6 weeks (PCT) or ongoing",
            route: "Oral",
            greenZone: WarningZone(6.25, 25, "Standard range"),
            yellowZone: WarningZone(25, 50, "Higher dose — diminishing returns"),
            redZone: WarningZone(50, 100, "Exceeds typical protocols"),
            frequencyWarning: "Monitor testosterone and estradiol levels. May suppress IGF-1.",
            titrationSchedule: nil
        ),
    ]
}
