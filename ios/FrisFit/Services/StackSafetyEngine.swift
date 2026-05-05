import Foundation
import SwiftUI

nonisolated enum StackBadgeKind: Sendable {
    case synergy
    case caution
    case conflict
    case note

    var color: Color {
        switch self {
        case .synergy: return .green
        case .caution: return PepTheme.amber
        case .conflict: return .red
        case .note: return PepTheme.blue
        }
    }
    var icon: String {
        switch self {
        case .synergy: return "checkmark.seal.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .conflict: return "exclamationmark.octagon.fill"
        case .note: return "info.circle.fill"
        }
    }
    var label: String {
        switch self {
        case .synergy: return "Synergy"
        case .caution: return "Caution"
        case .conflict: return "Conflict"
        case .note: return "Note"
        }
    }
}

nonisolated struct StackBadge: Identifiable, Sendable {
    let id: UUID = UUID()
    let kind: StackBadgeKind
    let title: String
    let detail: String
    let partner: String?
    let saferSwap: String?
}

nonisolated struct StackSafetySummary: Sendable {
    let score: Int // 0-100
    let synergyCount: Int
    let cautionCount: Int
    let conflictCount: Int
    let badgesByCompound: [String: [StackBadge]]
    let swapSuggestions: [StackSwapSuggestion]
}

nonisolated struct StackSwapSuggestion: Identifiable, Sendable {
    let id: UUID = UUID()
    let replace: String
    let suggestion: String
    let reason: String
}

enum StackSafetyEngine {
    static func evaluate(selected: [String]) -> StackSafetySummary {
        let interactions = DrugInteractionDatabase.interactions(among: selected)
        var badges: [String: [StackBadge]] = [:]

        for inter in interactions {
            let kind: StackBadgeKind = {
                switch inter.severity {
                case .warning: return .conflict
                case .caution: return .caution
                case .info: return .synergy
                }
            }()
            let swap = saferSwap(for: inter)
            let badgeA = StackBadge(
                kind: kind,
                title: badgeTitle(for: kind, partner: inter.compoundB),
                detail: inter.note,
                partner: inter.compoundB,
                saferSwap: swap
            )
            let badgeB = StackBadge(
                kind: kind,
                title: badgeTitle(for: kind, partner: inter.compoundA),
                detail: inter.note,
                partner: inter.compoundA,
                saferSwap: saferSwap(for: inter)
            )
            badges[inter.compoundA, default: []].append(badgeA)
            badges[inter.compoundB, default: []].append(badgeB)
        }

        // Timing notes per compound
        for name in selected {
            let timing = timingNote(for: name)
            if let note = timing {
                badges[name, default: []].append(note)
            }
        }

        let synergy = interactions.filter { $0.severity == .info }.count
        let caution = interactions.filter { $0.severity == .caution }.count
        let conflict = interactions.filter { $0.severity == .warning }.count

        let score = max(0, min(100, 100 - (conflict * 25) - (caution * 10) + (synergy * 3)))

        var swaps: [StackSwapSuggestion] = []
        for inter in interactions where inter.severity == .warning {
            if let alt = saferSwap(for: inter) {
                swaps.append(StackSwapSuggestion(
                    replace: inter.compoundB,
                    suggestion: alt,
                    reason: "Overlaps with \(inter.compoundA). \(inter.note)"
                ))
            }
        }

        return StackSafetySummary(
            score: score,
            synergyCount: synergy,
            cautionCount: caution,
            conflictCount: conflict,
            badgesByCompound: badges,
            swapSuggestions: swaps
        )
    }

    private static func badgeTitle(for kind: StackBadgeKind, partner: String) -> String {
        switch kind {
        case .synergy: return "Synergy with \(partner)"
        case .caution: return "Caution with \(partner)"
        case .conflict: return "Conflict with \(partner)"
        case .note: return "Note"
        }
    }

    private static func saferSwap(for inter: CompoundInteraction) -> String? {
        let a = inter.compoundA.lowercased()
        let b = inter.compoundB.lowercased()
        let pair = Set([a, b])
        if pair == Set(["semaglutide", "tirzepatide"]) { return "Run Tirzepatide alone — it already offers stronger weight loss effect." }
        if pair == Set(["semaglutide", "retatrutide"]) { return "Pick Retatrutide alone for most aggressive fat loss, or Semaglutide if GI tolerance is a concern." }
        if pair == Set(["tirzepatide", "retatrutide"]) { return "Retatrutide alone — adds GCG agonism on top of GLP-1/GIP." }
        if pair == Set(["cjc-1295", "sermorelin"]) { return "Keep CJC-1295 (longer half-life) and drop Sermorelin." }
        if pair == Set(["cjc-1295", "tesamorelin"]) { return "Pick one GHRH. Tesamorelin for visceral fat, CJC-1295 for general GH pulsing." }
        if pair == Set(["ipamorelin", "ghrp-2"]) { return "Keep Ipamorelin — cleaner profile (no prolactin/cortisol bump)." }
        if pair == Set(["ipamorelin", "ghrp-6"]) { return "Keep Ipamorelin to avoid GHRP-6's hunger signal." }
        if pair == Set(["melanotan ii", "pt-141"]) { return "Use PT-141 on-demand only; keep MT-II for tanning phase." }
        if pair == Set(["mk-677", "ipamorelin"]) { return "Drop MK-677 if you already pulse GH via Ipamorelin + GHRH." }
        return nil
    }

    private static func timingNote(for name: String) -> StackBadge? {
        let lower = name.lowercased()
        if lower.contains("ipamorelin") || lower.contains("cjc") || lower.contains("sermorelin") || lower.contains("tesamorelin") || lower.contains("ghrp") {
            return StackBadge(
                kind: .note,
                title: "Dose fasted pre-bed",
                detail: "GHRH/GHRP peptides work best injected on an empty stomach before sleep to align with your natural GH pulse.",
                partner: nil,
                saferSwap: nil
            )
        }
        if lower.contains("semaglutide") || lower.contains("tirzepatide") || lower.contains("retatrutide") {
            return StackBadge(
                kind: .note,
                title: "Same day each week",
                detail: "GLP-1 agonists must be injected on the same day each week to maintain steady plasma levels and minimize GI side effects.",
                partner: nil,
                saferSwap: nil
            )
        }
        if lower.contains("melanotan") {
            return StackBadge(
                kind: .note,
                title: "Start 0.25 mg — titrate",
                detail: "Melanotan II causes flushing and nausea. Start with a quarter dose for the first week.",
                partner: nil,
                saferSwap: nil
            )
        }
        return nil
    }
}
