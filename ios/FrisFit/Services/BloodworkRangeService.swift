import Foundation

nonisolated struct PersonalizedRange: Sendable {
    let low: Double
    let high: Double
}

nonisolated enum BloodworkRangeService {
    /// Personalize a biomarker's reference range using age and biological sex when available.
    /// Falls back to the biomarker's static `normalRange`.
    static func range(for biomarker: Biomarker, age: Int?, sex: BiologicalSex?) -> PersonalizedRange {
        let fallback = PersonalizedRange(
            low: biomarker.normalRange.lowerBound,
            high: biomarker.normalRange.upperBound
        )

        switch biomarker {
        case .testosteroneTotal:
            guard let sex else { return fallback }
            switch sex {
            case .male:
                if let age {
                    if age < 30 { return PersonalizedRange(low: 400, high: 1080) }
                    if age < 50 { return PersonalizedRange(low: 350, high: 950) }
                    return PersonalizedRange(low: 270, high: 850)
                }
                return PersonalizedRange(low: 300, high: 1000)
            case .female:
                return PersonalizedRange(low: 15, high: 70)
            }

        case .testosteroneFree:
            guard let sex else { return fallback }
            switch sex {
            case .male:
                if let age, age >= 50 { return PersonalizedRange(low: 5, high: 19) }
                return PersonalizedRange(low: 9, high: 30)
            case .female:
                return PersonalizedRange(low: 0.3, high: 1.9)
            }

        case .igf1:
            guard let age else { return fallback }
            if age < 30 { return PersonalizedRange(low: 115, high: 355) }
            if age < 45 { return PersonalizedRange(low: 100, high: 310) }
            if age < 60 { return PersonalizedRange(low: 85, high: 260) }
            return PersonalizedRange(low: 75, high: 220)

        case .creatinine:
            guard let sex else { return fallback }
            return sex == .male
                ? PersonalizedRange(low: 0.74, high: 1.35)
                : PersonalizedRange(low: 0.59, high: 1.04)

        case .hdl:
            guard let sex else { return fallback }
            return sex == .male
                ? PersonalizedRange(low: 40, high: 100)
                : PersonalizedRange(low: 50, high: 100)

        default:
            return fallback
        }
    }

    static func status(_ value: Double, range: PersonalizedRange) -> BiomarkerStatus {
        if value < range.low { return .low }
        if value > range.high { return .high }
        return .normal
    }

    /// Trend for a biomarker across entries (oldest → newest).
    /// Returns nil if fewer than 2 entries or movement is under 5% of range width.
    static func trend(values: [(date: Date, value: Double)], range: PersonalizedRange) -> BiomarkerTrend? {
        guard values.count >= 2 else { return nil }
        let sorted = values.sorted { $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last else { return nil }

        let width = max(0.01, range.high - range.low)
        let delta = last.value - first.value
        let relative = abs(delta) / width

        if relative < 0.05 { return .stable }
        return delta > 0 ? .rising : .falling
    }
}

nonisolated enum BiomarkerTrend: String, Sendable {
    case rising = "Rising"
    case falling = "Falling"
    case stable = "Stable"

    var icon: String {
        switch self {
        case .rising: return "arrow.up.right"
        case .falling: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }
}

nonisolated struct BiomarkerTrendAlert: Sendable {
    let biomarker: Biomarker
    let direction: BiomarkerTrend
    let consecutiveCount: Int
    let slopePerDay: Double
    let latestValue: Double
    let latestStatus: BiomarkerStatus
    let message: String
    let severity: Severity

    enum Severity: Sendable {
        case info, warning, critical
    }
}

extension BloodworkRangeService {
    /// Compute a trend alert over the most recent N entries (newest → oldest input).
    /// Returns nil when the slope is negligible or there aren't enough data points.
    static func trendAlert(
        for biomarker: Biomarker,
        values: [(date: Date, value: Double)],
        range: PersonalizedRange,
        lookback: Int = 3
    ) -> BiomarkerTrendAlert? {
        guard values.count >= lookback else { return nil }
        let sorted = values.sorted { $0.date < $1.date }
        let window = Array(sorted.suffix(lookback))
        guard window.count >= 2,
              let first = window.first,
              let last = window.last else { return nil }

        // Strictly monotonic check
        var rising = true
        var falling = true
        for i in 1..<window.count {
            if window[i].value <= window[i - 1].value { rising = false }
            if window[i].value >= window[i - 1].value { falling = false }
        }
        guard rising || falling else { return nil }

        let days = max(1.0, last.date.timeIntervalSince(first.date) / 86_400.0)
        let delta = last.value - first.value
        let slopePerDay = delta / days
        let width = max(0.01, range.high - range.low)
        let relative = abs(delta) / width

        let threshold = thresholdRelative(for: biomarker)
        guard relative >= threshold else { return nil }

        let direction: BiomarkerTrend = rising ? .rising : .falling
        let latestStatus = status(last.value, range: range)
        let severity: BiomarkerTrendAlert.Severity
        if latestStatus != .normal {
            severity = .critical
        } else if relative >= threshold * 2 {
            severity = .warning
        } else {
            severity = .info
        }

        let message = buildMessage(biomarker: biomarker, direction: direction, count: window.count, relative: relative, latestStatus: latestStatus)
        return BiomarkerTrendAlert(
            biomarker: biomarker,
            direction: direction,
            consecutiveCount: window.count,
            slopePerDay: slopePerDay,
            latestValue: last.value,
            latestStatus: latestStatus,
            message: message,
            severity: severity
        )
    }

    private static func thresholdRelative(for biomarker: Biomarker) -> Double {
        switch biomarker {
        case .alt, .ast: return 0.10
        case .ldl, .triglycerides, .totalCholesterol: return 0.08
        case .a1c, .fastingGlucose, .fastingInsulin: return 0.08
        case .creatinine, .bun: return 0.10
        case .tsh, .t3, .t4: return 0.10
        default: return 0.10
        }
    }

    private static func buildMessage(
        biomarker: Biomarker,
        direction: BiomarkerTrend,
        count: Int,
        relative: Double,
        latestStatus: BiomarkerStatus
    ) -> String {
        let verb = direction == .rising ? "rising" : "falling"
        let pct = Int(relative * 100)
        var msg = "\(biomarker.rawValue) has been \(verb) \(count) entries in a row (~\(pct)% of normal range)."
        if latestStatus != .normal {
            msg += " Latest reading is out of range — consider retesting and consulting your doctor."
        } else {
            msg += " Consider retesting to confirm the trend."
        }
        return msg
    }
}
