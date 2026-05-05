import SwiftUI

nonisolated enum InteractionSeverity: String, Sendable {
    case info = "Info"
    case caution = "Caution"
    case warning = "Warning"

    var color: Color {
        switch self {
        case .info: return PepTheme.blue
        case .caution: return PepTheme.amber
        case .warning: return .red
        }
    }

    var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .warning: return "exclamationmark.octagon.fill"
        }
    }
}

nonisolated struct CompoundInteraction: Identifiable, Sendable {
    let id: UUID = UUID()
    let compoundA: String
    let compoundB: String
    let severity: InteractionSeverity
    let note: String
}

enum DrugInteractionDatabase {
    /// Static, educational-only interaction matrix for peptides/compounds commonly stacked together.
    /// Matching is case-insensitive and tolerates common aliases (Tirzepatide / Mounjaro, Semaglutide / Ozempic).
    static let all: [CompoundInteraction] = [
        CompoundInteraction(
            compoundA: "Semaglutide", compoundB: "Tirzepatide",
            severity: .warning,
            note: "Both are GLP-1 agonists — stacking compounds appetite suppression and GI side effects. Most users pick one."
        ),
        CompoundInteraction(
            compoundA: "Semaglutide", compoundB: "Retatrutide",
            severity: .warning,
            note: "Overlapping GLP-1 activity. Not intended to be run together; choose one."
        ),
        CompoundInteraction(
            compoundA: "CJC-1295", compoundB: "Sermorelin",
            severity: .caution,
            note: "Both are GHRH analogs. Running both is redundant and raises GH spillover without added benefit."
        ),
        CompoundInteraction(
            compoundA: "CJC-1295", compoundB: "Tesamorelin",
            severity: .caution,
            note: "Redundant GHRH stimulation. Typically you'd pick one long-acting GHRH and pair with a GHRP."
        ),
        CompoundInteraction(
            compoundA: "Ipamorelin", compoundB: "GHRP-2",
            severity: .caution,
            note: "Both are GHRPs. Stacking two GHRPs increases cortisol/prolactin risk — pair a GHRP with a GHRH instead."
        ),
        CompoundInteraction(
            compoundA: "Ipamorelin", compoundB: "GHRP-6",
            severity: .caution,
            note: "Both are GHRPs. Doubling up raises hunger signaling and cortisol response."
        ),
        CompoundInteraction(
            compoundA: "Melanotan II", compoundB: "PT-141",
            severity: .caution,
            note: "Both act on melanocortin receptors. Stacking can amplify flushing, nausea, and blood-pressure changes."
        ),
        CompoundInteraction(
            compoundA: "BPC-157", compoundB: "TB-500",
            severity: .info,
            note: "Commonly stacked for healing. Widely reported as synergistic — no known adverse interaction."
        ),
        CompoundInteraction(
            compoundA: "Tirzepatide", compoundB: "Retatrutide",
            severity: .warning,
            note: "Overlapping incretin activity. Do not stack without medical supervision."
        ),
        CompoundInteraction(
            compoundA: "HCG", compoundB: "Testosterone",
            severity: .info,
            note: "HCG is frequently used alongside TRT to preserve testicular function — generally complementary, monitor E2."
        ),
        CompoundInteraction(
            compoundA: "MK-677", compoundB: "Ipamorelin",
            severity: .caution,
            note: "Both are ghrelin-mimetic GH secretagogues. Stacking amplifies appetite, water retention, and blood glucose rise."
        ),
    ]

    static func interactions(among compoundNames: [String]) -> [CompoundInteraction] {
        let normalized = compoundNames.map { normalize($0) }
        var results: [CompoundInteraction] = []
        for i in 0..<normalized.count {
            for j in (i + 1)..<normalized.count {
                let a = normalized[i]
                let b = normalized[j]
                for entry in all {
                    let ea = normalize(entry.compoundA)
                    let eb = normalize(entry.compoundB)
                    if (a == ea && b == eb) || (a == eb && b == ea) {
                        results.append(entry)
                    }
                }
            }
        }
        return results
    }

    private static func normalize(_ name: String) -> String {
        var s = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let aliases: [String: String] = [
            "ozempic": "semaglutide",
            "wegovy": "semaglutide",
            "mounjaro": "tirzepatide",
            "zepbound": "tirzepatide",
            "ibutamoren": "mk-677",
            "mk677": "mk-677",
            "cjc1295": "cjc-1295",
            "ghrp2": "ghrp-2",
            "ghrp6": "ghrp-6",
            "bpc157": "bpc-157",
            "tb500": "tb-500",
            "pt141": "pt-141",
            "mt2": "melanotan ii",
            "melanotan 2": "melanotan ii"
        ]
        if let mapped = aliases[s] { s = mapped }
        return s
    }
}
