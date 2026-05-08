import Foundation

/// Computes the current pharmacokinetic body level for a compound inside a
/// protocol using the existing Bateman one-compartment model. Powers the
/// "in body now" line on the home protocol card and any other surface that
/// needs an at-a-glance read of remaining circulating drug.
@MainActor
enum ProtocolBodyLevelCalculator {
    struct Reading {
        let mg: Double
        let lastDoseMg: Double?
        let compoundName: String

        /// Formats the level using whatever unit the user picked when they
        /// added this compound's vial (mg vs mcg) — falling back to a
        /// scale-aware auto format if no preference is stored.
        var displayValue: String {
            if mg <= 0 {
                let unit = CompoundUnitHelper.unit(for: compoundName)
                return unit == .mg ? "0 mg" : "0 mcg"
            }
            switch CompoundUnitHelper.unit(for: compoundName) {
            case .mg:
                if mg >= 1 {
                    return String(format: "%.2f mg", mg)
                }
                if mg >= 0.01 {
                    return String(format: "%.3f mg", mg)
                }
                return String(format: "%.4f mg", mg)
            case .mcg:
                let mcg = mg * 1000
                if mcg >= 100 {
                    return String(format: "%.0f mcg", mcg)
                }
                if mcg >= 10 {
                    return String(format: "%.1f mcg", mcg)
                }
                return String(format: "%.2f mcg", mcg)
            }
        }

        var percentOfLastDose: Int? {
            guard let last = lastDoseMg, last > 0 else { return nil }
            let pct = Int((mg / last * 100).rounded())
            // Clamp to a meaningful display range.
            return max(0, min(150, pct))
        }
    }

    /// Current body level for a compound at `now`, summing every logged dose
    /// through the Bateman absorption / elimination curve.
    static func currentLevel(
        for compound: ProtocolCompound,
        in proto: PeptideProtocol,
        now: Date = Date()
    ) -> Reading {
        let profile = PeptidePharmacology.profile(for: compound.compoundName)
        let doses = PKSampleBuilder.dosesFromLog(proto.doseLog, compoundName: compound.compoundName)

        let mg = PeptidePharmacology.levelMg(
            at: now,
            doses: doses,
            ka: profile.ka,
            ke: profile.ke
        )

        let lastDoseMg = doses.last?.mg

        return Reading(mg: mg, lastDoseMg: lastDoseMg, compoundName: compound.compoundName)
    }
}
