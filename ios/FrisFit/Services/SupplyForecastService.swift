import Foundation
import SwiftUI

nonisolated struct SupplyForecast: Sendable, Identifiable {
    let id: UUID = UUID()
    let compoundName: String
    let doseMcg: Double
    let dosesPerWeek: Double
    let dosesRemaining: Int
    let daysRemaining: Int
    let runOutDate: Date?
    let hasAnyVial: Bool

    var isLow: Bool { daysRemaining >= 0 && daysRemaining <= 7 }
    var isCritical: Bool { daysRemaining >= 0 && daysRemaining <= 3 }
    var isOut: Bool { daysRemaining <= 0 && hasAnyVial == false || dosesRemaining == 0 }

    var chipColor: Color {
        if dosesRemaining == 0 { return .red }
        if daysRemaining <= 3 { return .red }
        if daysRemaining <= 14 { return PepTheme.amber }
        return .green
    }

    var chipLabel: String {
        if !hasAnyVial { return "No vial" }
        if dosesRemaining == 0 { return "Empty" }
        if daysRemaining <= 0 { return "Out today" }
        if daysRemaining == 1 { return "1 day left" }
        return "\(daysRemaining) days left"
    }
}

enum SupplyForecastService {
    static func dosesPerWeek(for frequency: String) -> Double {
        let f = frequency.lowercased()
        if f.contains("eod") { return 3.5 }
        if f.contains("as needed") { return 0 }
        if f.contains("3x daily") { return 21 }
        if f.contains("2x daily") || f.contains("twice daily") { return 14 }
        if f.contains("3x weekly") { return 3 }
        if f.contains("2x weekly") { return 2 }
        if f.contains("1x weekly") || f.contains("weekly") { return 1 }
        if f.contains("daily") { return 7 }
        return 7
    }

    @MainActor
    static func forecast(for compound: ProtocolCompound, in proto: PeptideProtocol) -> SupplyForecast {
        let perWeek = dosesPerWeek(for: compound.frequency)
        let vials = VialInventoryStore.shared.activeVials(for: compound.compoundName)
        let totalMcgRemaining = vials.reduce(0.0) { $0 + $1.mcgRemaining }
        let dose = compound.doseMcg > 0 ? compound.doseMcg : 250
        let dosesRemaining = Int(totalMcgRemaining / dose)

        // Fallback: use protocol's compound-level vialSizeMg minus mcg logged
        var fallbackDoses = dosesRemaining
        if vials.isEmpty, let vialMg = compound.vialSizeMg, vialMg > 0 {
            let logs = proto.doseLog.filter { $0.compoundName == compound.compoundName && !$0.wasSkipped }
            let usedMcg = logs.reduce(0.0) { $0 + $1.doseMcg }
            let remainingMcg = max(0, vialMg * 1000 - usedMcg)
            fallbackDoses = Int(remainingMcg / dose)
        }

        let finalDoses = vials.isEmpty ? fallbackDoses : dosesRemaining
        let dosesPerDay = perWeek / 7.0
        let daysRemaining: Int
        if dosesPerDay > 0 && finalDoses > 0 {
            daysRemaining = Int((Double(finalDoses) / dosesPerDay).rounded(.down))
        } else if finalDoses == 0 {
            daysRemaining = 0
        } else {
            daysRemaining = 999
        }
        let runOut = daysRemaining < 999
            ? Calendar.current.date(byAdding: .day, value: daysRemaining, to: Date())
            : nil

        return SupplyForecast(
            compoundName: compound.compoundName,
            doseMcg: dose,
            dosesPerWeek: perWeek,
            dosesRemaining: finalDoses,
            daysRemaining: daysRemaining,
            runOutDate: runOut,
            hasAnyVial: !vials.isEmpty || compound.vialSizeMg != nil
        )
    }

    @MainActor
    static func lowStockForecasts(from protocols: [PeptideProtocol], thresholdDays: Int = 7) -> [SupplyForecast] {
        var out: [SupplyForecast] = []
        for proto in protocols where proto.isActive {
            for compound in proto.compounds {
                let f = forecast(for: compound, in: proto)
                if f.hasAnyVial && f.daysRemaining <= thresholdDays {
                    out.append(f)
                }
            }
        }
        // Deduplicate by compound name, keep lowest
        var dict: [String: SupplyForecast] = [:]
        for f in out {
            if let existing = dict[f.compoundName], existing.daysRemaining <= f.daysRemaining { continue }
            dict[f.compoundName] = f
        }
        return dict.values.sorted { $0.daysRemaining < $1.daysRemaining }
    }
}
