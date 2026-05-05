import SwiftUI

nonisolated struct ProactiveInsight: Identifiable, Sendable {
    let id: UUID = UUID()
    let title: String
    let message: String
    let icon: String
    let tint: Color
    let priority: Int
}

@MainActor
enum ProactiveInsightService {
    static func insights(for proto: PeptideProtocol, adherence7d: Double, sideEffects: [SideEffectEntry]) -> [ProactiveInsight] {
        var out: [ProactiveInsight] = insightsFromMemory(domain: "protocol")

        let cal = Calendar.current
        let now = Date()

        let realLogs = proto.doseLog.filter { !$0.wasSkipped }
        if let last = realLogs.sorted(by: { $0.timestamp > $1.timestamp }).first {
            let days = cal.dateComponents([.day], from: last.timestamp, to: now).day ?? 0
            if days >= 2 {
                out.append(ProactiveInsight(
                    title: "No dose in \(days) days",
                    message: "Your last logged dose was \(days) days ago. Tap log dose if you've taken one.",
                    icon: "clock.badge.exclamationmark.fill",
                    tint: PepTheme.amber,
                    priority: 10
                ))
            }
        } else if proto.isActive && proto.currentDay > 1 {
            out.append(ProactiveInsight(
                title: "Haven't logged a dose yet",
                message: "This protocol is active but has no dose history. Log your first dose to start tracking.",
                icon: "syringe",
                tint: PepTheme.teal,
                priority: 8
            ))
        }

        if adherence7d < 0.5 && !proto.doseLog.isEmpty {
            out.append(ProactiveInsight(
                title: "Adherence dropped",
                message: "You've logged under 50% of expected doses this week.",
                icon: "chart.line.downtrend.xyaxis",
                tint: .red,
                priority: 9
            ))
        }

        for compound in proto.compounds {
            if let exp = compound.expirationDate {
                let days = cal.dateComponents([.day], from: now, to: exp).day ?? 0
                if days >= 0 && days <= 14 {
                    out.append(ProactiveInsight(
                        title: "\(compound.compoundName) expiring soon",
                        message: "Expires in \(days) day\(days == 1 ? "" : "s"). Plan your next vial.",
                        icon: "calendar.badge.exclamationmark",
                        tint: PepTheme.amber,
                        priority: 7
                    ))
                } else if days < 0 {
                    out.append(ProactiveInsight(
                        title: "\(compound.compoundName) expired",
                        message: "This vial expired \(-days) day\(days == -1 ? "" : "s") ago. Do not use.",
                        icon: "exclamationmark.octagon.fill",
                        tint: .red,
                        priority: 11
                    ))
                }
            }
        }

        let interactions = DrugInteractionDatabase.interactions(among: proto.compounds.map(\.compoundName))
        for inter in interactions where inter.severity == .warning {
            out.append(ProactiveInsight(
                title: "\(inter.compoundA) + \(inter.compoundB)",
                message: inter.note,
                icon: "exclamationmark.triangle.fill",
                tint: .red,
                priority: 12
            ))
        }

        let recentSevere = sideEffects.filter {
            $0.severity >= 3 && (cal.dateComponents([.day], from: $0.timestamp, to: now).day ?? 99) <= 3
        }
        if recentSevere.count >= 2 {
            out.append(ProactiveInsight(
                title: "Severe side effects logged",
                message: "You've logged \(recentSevere.count) moderate+ side effects in the last 3 days. Consider discussing with your provider.",
                icon: "heart.text.square.fill",
                tint: .red,
                priority: 10
            ))
        }

        return out.sorted { $0.priority > $1.priority }
    }

    /// Surface high-signal AIMemoryStore facts as proactive insights so learned
    /// patterns and correlations show up alongside the hardcoded rules.
    static func insightsFromMemory(domain: String? = nil) -> [ProactiveInsight] {
        let facts = AIMemoryStore.shared.allFacts()
        var out: [ProactiveInsight] = []
        for fact in facts {
            if let domain, fact.domain != domain && fact.domain != "cross" { continue }
            guard fact.confidence >= 0.65 else { continue }
            let priority: Int
            let tint: Color
            let icon: String
            switch fact.kind {
            case .concern:
                priority = 9
                tint = .red
                icon = "exclamationmark.triangle.fill"
            case .correlation:
                priority = 7
                tint = PepTheme.violet
                icon = "link"
            case .pattern:
                priority = 6
                tint = PepTheme.teal
                icon = "waveform.path.ecg"
            case .milestone:
                priority = 5
                tint = PepTheme.amber
                icon = "flag.checkered"
            case .investigation, .preference:
                continue
            }
            if fact.isPinned { /* pinned facts boost priority */ }
            out.append(ProactiveInsight(
                title: fact.headline,
                message: fact.detail.isEmpty ? "Learned from your patterns." : fact.detail,
                icon: icon,
                tint: tint,
                priority: fact.isPinned ? priority + 2 : priority
            ))
            if out.count >= 4 { break }
        }
        return out
    }
}
