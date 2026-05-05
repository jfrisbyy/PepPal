import Foundation

/// Unified entry point for logging a dose. Writes to Supabase via ProtocolService,
/// decrements the selected vial in VialInventoryStore, and ingests a memory fact
/// so the AI knows the dose happened without refetching.
@MainActor
enum DoseLogger {
    struct Result: Sendable {
        let entry: DoseLogEntry?
        let persisted: Bool
    }

    @discardableResult
    static func log(
        protocolId: String?,
        compoundName: String,
        doseMcg: Double,
        injectionSite: InjectionSite,
        notes: String = "",
        loggedAt: Date? = nil,
        wasSkipped: Bool = false,
        skipReason: String? = nil,
        vial: Vial? = nil
    ) async -> Result {
        var saved: DoseLogEntry?
        var persisted = false

        if let protocolId {
            do {
                saved = try await ProtocolService.shared.logDose(
                    protocolId: protocolId,
                    compoundName: compoundName,
                    doseMcg: doseMcg,
                    injectionSite: injectionSite,
                    notes: notes,
                    loggedAt: loggedAt,
                    wasSkipped: wasSkipped,
                    skipReason: skipReason
                )
                persisted = true
            } catch {
                print("[DoseLogger] supabase log failed: \(error)")
            }
        }

        // Deduct from vial when a specific vial was used.
        if let vial, !wasSkipped, doseMcg > 0 {
            VialInventoryStore.shared.recordDose(vialId: vial.id, mcg: doseMcg)
        } else if !wasSkipped && doseMcg > 0 {
            // Auto-pick oldest active vial for this compound when caller didn't specify.
            if let auto = VialInventoryStore.shared.activeVials(for: compoundName).first {
                VialInventoryStore.shared.recordDose(vialId: auto.id, mcg: doseMcg)
            }
        }

        // Trigger correlation refresh so dose-day patterns include today.
        if !wasSkipped {
            Task { @MainActor in _ = await CorrelationEngine.shared.run() }
        }

        // Push a short-lived memory fact so AI prompts reference the latest dose.
        if !wasSkipped && doseMcg > 0 {
            let displayDose = CompoundUnitHelper.displayDoseShort(doseMcg, for: compoundName)
            AIMemoryStore.shared.upsert(AIMemoryFact(
                kind: .pattern,
                headline: "Logged \(compoundName) \(displayDose)",
                detail: "Site: \(injectionSite.rawValue). \(Date().formatted(date: .abbreviated, time: .shortened))",
                domain: "protocol",
                confidence: 1.0
            ))
            // Auto-pin on Compounds lane of the Journey Map.
            JourneyEventService.shared.autoAdd(
                lane: .compounds,
                timestamp: loggedAt ?? Date(),
                title: "\(compoundName) \(displayDose)",
                description: "Site: \(injectionSite.rawValue)\(notes.isEmpty ? "" : " · \(notes)")",
                sourceType: .doseLog,
                payload: JourneyEventPayload(
                    compoundName: compoundName,
                    doseAmount: doseMcg,
                    doseUnit: "mcg"
                )
            )
        }

        return Result(entry: saved, persisted: persisted)
    }
}
