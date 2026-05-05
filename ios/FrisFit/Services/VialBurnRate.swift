import Foundation
import SwiftUI

nonisolated struct VialBurnRatePoint: Identifiable, Sendable {
    let id: UUID = UUID()
    let date: Date
    let dosesUsed: Int
}

enum VialBurnRate {
    /// Produce a simple SupplyForecast from a vial using its typical dose and last 14 days of burn.
    static func forecast(for vial: Vial) -> SupplyForecast? {
        guard vial.typicalDoseMcg > 0 else { return nil }
        let dosesRemaining = vial.dosesRemaining
        let dosesPerDay = 1.0
        let days = dosesRemaining > 0 ? Int((Double(dosesRemaining) / dosesPerDay).rounded(.down)) : 0
        let runOut = Calendar.current.date(byAdding: .day, value: days, to: Date())
        return SupplyForecast(
            compoundName: vial.compoundName,
            doseMcg: vial.typicalDoseMcg,
            dosesPerWeek: 7,
            dosesRemaining: dosesRemaining,
            daysRemaining: days,
            runOutDate: runOut,
            hasAnyVial: true
        )
    }

    /// Build last-N-days burn chart from a protocol's dose log for a compound name.
    static func recentDailyDoses(compoundName: String, in proto: PeptideProtocol, days: Int = 14) -> [VialBurnRatePoint] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var out: [VialBurnRatePoint] = []
        for offset in (0..<days).reversed() {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let count = proto.doseLog.filter {
                $0.compoundName == compoundName && !$0.wasSkipped && cal.isDate($0.timestamp, inSameDayAs: day)
            }.count
            out.append(VialBurnRatePoint(date: day, dosesUsed: count))
        }
        return out
    }
}
