import Foundation
import SwiftUI

/// Pharmacokinetic helpers, per-compound color/identity, and the Bateman
/// one-compartment model used to render the medication-level chart.
nonisolated enum PeptidePharmacology: Sendable {

    // MARK: - Half-life parsing

    /// Parse a half-life string from `CompoundKeyFacts.halfLife` into hours.
    /// Handles ranges ("10-20 min"), units (min, hr, h, day, week), and DAC notes.
    /// Returns a sensible default (24h) if the string can't be parsed.
    static func halfLifeHours(from raw: String) -> Double {
        let s = raw.lowercased()

        // Pull all numbers out (so "26-38 min" averages to 32)
        let pattern = #"(\d+(?:\.\d+)?)"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let ns = s as NSString
        var numbers: [Double] = []
        regex?.enumerateMatches(in: s, range: NSRange(location: 0, length: ns.length)) { match, _, _ in
            if let r = match?.range, let v = Double(ns.substring(with: r)) {
                numbers.append(v)
            }
        }

        // Detect unit
        let unit: Double  // multiplier to hours
        if s.contains("week") || s.contains("wk") { unit = 24 * 7 }
        else if s.contains("day") || s.contains("d ") || s.hasSuffix("d") { unit = 24 }
        else if s.contains("min") { unit = 1.0 / 60.0 }
        else if s.contains("sec") { unit = 1.0 / 3600.0 }
        else if s.contains("hour") || s.contains("hr") || s.contains(" h") { unit = 1 }
        else if numbers.first ?? 0 > 24 { unit = 1.0 / 60.0 }   // probably minutes if huge
        else { unit = 1 }

        guard !numbers.isEmpty else { return 24 }

        // Average the first one or two numbers (handles ranges)
        let avg = (numbers.prefix(2).reduce(0, +)) / Double(min(2, numbers.count))
        return max(0.05, avg * unit)
    }

    // MARK: - Bateman one-compartment model

    /// Bateman equation for a single subcutaneous dose.
    /// `D` in same unit you want output (we use mg).
    /// `t` and `tDose` are absolute Dates; ka/ke in 1/hour.
    static func batemanContribution(
        doseMg: Double,
        ka: Double,
        ke: Double,
        bioavailability: Double = 0.85,
        atTime t: Date,
        doseTime tDose: Date
    ) -> Double {
        let dtHours = t.timeIntervalSince(tDose) / 3600.0
        if dtHours < 0 { return 0 }

        let F = bioavailability
        let denom = ka - ke
        if abs(denom) < 1e-6 {
            // Edge case: ka ≈ ke → use the limit form
            return F * doseMg * ka * dtHours * exp(-ke * dtHours)
        }
        let factor = (F * doseMg * ka) / denom
        return factor * (exp(-ke * dtHours) - exp(-ka * dtHours))
    }

    /// Sum Bateman contributions across all doses up to time `t`.
    static func levelMg(
        at t: Date,
        doses: [PKDose],
        ka: Double,
        ke: Double,
        bioavailability: Double = 0.85
    ) -> Double {
        var total: Double = 0
        for dose in doses where dose.time <= t {
            total += batemanContribution(
                doseMg: dose.mg,
                ka: ka,
                ke: ke,
                bioavailability: bioavailability,
                atTime: t,
                doseTime: dose.time
            )
        }
        return max(0, total)
    }

    /// Reasonable absorption rate for subcutaneous peptides — ~30 min absorption half-life.
    /// For very short half-life compounds, ensure ka stays comfortably greater than ke.
    static func absorptionRate(eliminationKe ke: Double) -> Double {
        let kaDefault = log(2.0) / 0.5  // 30-minute absorption half-life
        return max(kaDefault, ke * 4.0)
    }

    // MARK: - Per-compound color & identity

    /// Maps a compound (by name + peptide-type) to a distinct accent color.
    static func accentColor(for compoundName: String, peptideType: String? = nil) -> Color {
        let n = compoundName.lowercased()
        let t = (peptideType ?? "").lowercased()

        // GLP-1 / metabolic family — warm amber/orange
        if n.contains("semaglutide") || n.contains("tirzepatide") ||
           n.contains("retatrutide") || n.contains("cagri") ||
           t.contains("glp-1") || t.contains("gip") || t.contains("amylin") {
            return Color(red: 1.0, green: 0.62, blue: 0.20)
        }

        // Healing / repair — green
        if n.contains("bpc") || n.contains("tb-500") || n.contains("tb500") ||
           n.contains("ghk") || n.contains("kpv") || n.contains("ll-37") ||
           t.contains("body protection") || t.contains("actin") || t.contains("copper") {
            return Color(red: 0.30, green: 0.80, blue: 0.50)
        }

        // GH secretagogues — teal/cyan
        if n.contains("sermorelin") || n.contains("cjc") || n.contains("ipamorelin") ||
           n.contains("ghrp") || n.contains("hexarelin") || n.contains("tesamorelin") ||
           n.contains("mk-677") || n.contains("ibutamoren") || n.contains("aod") ||
           t.contains("ghrh") || t.contains("growth hormone") || t.contains("ghrelin") {
            return Color(red: 0.10, green: 0.78, blue: 0.85)
        }

        // Cognitive / nootropic — violet
        if n.contains("semax") || n.contains("selank") || n.contains("dihexa") ||
           n.contains("cerebrolysin") || n.contains("epitalon") || n.contains("dsip") ||
           t.contains("nootropic") || t.contains("anxiolytic") || t.contains("acth") {
            return Color(red: 0.55, green: 0.40, blue: 0.95)
        }

        // Tanning / melanocortin — burnt orange
        if n.contains("melanotan") || n.contains("ptd") || n.contains("bremelanotide") ||
           t.contains("melanocortin") {
            return Color(red: 0.95, green: 0.45, blue: 0.20)
        }

        // Immune / thymic — pink/coral
        if n.contains("thymosin") || n.contains("thymalin") || n.contains("thymulin") ||
           t.contains("immune") || t.contains("thymus") {
            return Color(red: 0.95, green: 0.45, blue: 0.62)
        }

        // SARMs / muscle / IGF — deep blue
        if n.contains("igf") || n.contains("rad") || n.contains("ostarine") ||
           n.contains("ligandrol") || n.contains("yk-11") || n.contains("follistatin") ||
           t.contains("sarm") || t.contains("igf") || t.contains("myostatin") {
            return Color(red: 0.30, green: 0.55, blue: 0.95)
        }

        // Default — EPTI teal
        return Color(red: 0, green: 201/255, blue: 167/255)
    }

    // MARK: - Convenience: PK profile lookup

    /// Build a PK profile (ka, ke, half-life hours, color) for a compound name.
    @MainActor
    static func profile(for compoundName: String) -> PKProfile {
        let comp = CompoundDatabase.compound(named: compoundName)
        let halfLifeRaw = comp?.keyFacts.halfLife ?? "24 hours"
        let h = halfLifeHours(from: halfLifeRaw)
        let ke = log(2.0) / h
        let ka = absorptionRate(eliminationKe: ke)
        return PKProfile(
            compoundName: compoundName,
            halfLifeHours: h,
            halfLifeLabel: halfLifeRaw,
            ka: ka,
            ke: ke,
            color: accentColor(for: compoundName, peptideType: comp?.peptideType)
        )
    }
}

nonisolated struct PKDose: Sendable, Hashable {
    let time: Date
    let mg: Double
}

nonisolated struct PKProfile: Sendable {
    let compoundName: String
    let halfLifeHours: Double
    let halfLifeLabel: String
    let ka: Double
    let ke: Double
    let color: Color
}

nonisolated struct PKSamplePoint: Sendable, Identifiable {
    let id = UUID()
    let time: Date
    let mg: Double
    let isFuture: Bool
}

nonisolated enum PKChartRange: String, CaseIterable, Sendable, Identifiable {
    case sevenDay = "7D"
    case thirtyDay = "30D"
    case ninetyDay = "90D"

    var id: String { rawValue }
    var totalDays: Int {
        switch self {
        case .sevenDay: return 7
        case .thirtyDay: return 30
        case .ninetyDay: return 90
        }
    }
    /// How much of the range sits in the past vs. projected future.
    var pastDays: Int {
        switch self {
        case .sevenDay: return 5
        case .thirtyDay: return 22
        case .ninetyDay: return 70
        }
    }
    var futureDays: Int { totalDays - pastDays }

    /// Number of sample points across the full range.
    var sampleCount: Int {
        switch self {
        case .sevenDay: return 96       // ~every 1.75h
        case .thirtyDay: return 180     // ~every 4h
        case .ninetyDay: return 240     // ~every 9h
        }
    }
}

@MainActor
enum PKSampleBuilder {
    /// Sample the medication-level curve for a given range, marking points
    /// after `now` as future (for dotted rendering).
    ///
    /// The grid is *adaptive*: uniform sampling across the whole range, plus
    /// dense extra samples around every dose so that short-half-life peptides
    /// (e.g. GHK-Cu, BPC-157) render as continuous rise/fall curves instead of
    /// aliased dots. A sample exactly at `now` is always included so that the
    /// past-solid and future-dotted line series share a point and connect
    /// visually without a gap.
    static func samples(
        doses: [PKDose],
        profile: PKProfile,
        range: PKChartRange,
        now: Date = Date()
    ) -> [PKSamplePoint] {
        let pastInterval = TimeInterval(range.pastDays) * 86400
        let futureInterval = TimeInterval(range.futureDays) * 86400
        let start = now.addingTimeInterval(-pastInterval)
        let end = now.addingTimeInterval(futureInterval)
        let count = max(2, range.sampleCount)
        let step = end.timeIntervalSince(start) / Double(count - 1)

        // 1) Uniform base grid across the visible range.
        var times: [TimeInterval] = []
        times.reserveCapacity(count + 64)
        for i in 0..<count {
            times.append(start.timeIntervalSince1970 + step * Double(i))
        }

        // 2) Always include `now` so past+future series meet cleanly.
        times.append(now.timeIntervalSince1970)

        // 3) Dose-anchored dense samples. Window covers ~6 half-lives after
        //    each dose (>98% cleared), with ~24 samples per half-life so even
        //    sub-hour peptides render a smooth spike+decay.
        let halfLifeHours = profile.halfLifeHours
        let windowHours = max(2.0, halfLifeHours * 6.0)
        let windowSeconds = windowHours * 3600.0
        let denseStepSeconds = max(60.0, (halfLifeHours * 3600.0) / 24.0)
        // Also include a quick rise window (absorption phase): a few samples
        // before the dose's peak based on ka, so we don't miss the leading edge.
        let absorptionHours = profile.ka > 0 ? (log(2.0) / profile.ka) : 0.5
        let preWindowSeconds = max(180.0, absorptionHours * 3600.0 * 0.5)

        let startTS = start.timeIntervalSince1970
        let endTS = end.timeIntervalSince1970
        for dose in doses {
            let dTS = dose.time.timeIntervalSince1970
            // Skip doses whose entire influence falls outside the visible range.
            if dTS + windowSeconds < startTS { continue }
            if dTS - preWindowSeconds > endTS { continue }

            // Pre-dose anchor (baseline just before the spike).
            let pre = dTS - preWindowSeconds
            if pre >= startTS && pre <= endTS { times.append(pre) }
            // The dose moment itself.
            if dTS >= startTS && dTS <= endTS { times.append(dTS) }
            // Dense post-dose samples.
            var t = dTS + denseStepSeconds
            let lastT = min(endTS, dTS + windowSeconds)
            while t <= lastT {
                if t >= startTS { times.append(t) }
                t += denseStepSeconds
            }
        }

        // 4) Sort & dedupe (within 1s) to keep the line monotonic in x.
        times.sort()
        var deduped: [TimeInterval] = []
        deduped.reserveCapacity(times.count)
        for ts in times {
            if let last = deduped.last, ts - last < 1.0 { continue }
            deduped.append(ts)
        }

        let nowTS = now.timeIntervalSince1970
        var out: [PKSamplePoint] = []
        out.reserveCapacity(deduped.count)
        for ts in deduped {
            let t = Date(timeIntervalSince1970: ts)
            let mg = PeptidePharmacology.levelMg(
                at: t,
                doses: doses,
                ka: profile.ka,
                ke: profile.ke
            )
            // `now` itself is treated as past so the solid line includes it;
            // the future series will also include it as its anchor point.
            out.append(PKSamplePoint(time: t, mg: mg, isFuture: ts > nowTS))
        }
        return out
    }

    static func dosesFromLog(_ logs: [DoseLogEntry], compoundName: String) -> [PKDose] {
        logs
            .filter { $0.compoundName == compoundName && !$0.wasSkipped }
            .map { PKDose(time: $0.timestamp, mg: $0.doseMcg / 1000.0) }
            .sorted { $0.time < $1.time }
    }
}
