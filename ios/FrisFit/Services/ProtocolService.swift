import Foundation
import Supabase

nonisolated struct SupabaseProtocol: Codable, Sendable {
    let id: String?
    let user_id: String?
    let name: String
    let goal: String?
    let status: String?
    let start_date: String?
    let end_date: String?
    let notes: String?
    let created_at: String?
    let updated_at: String?
    let loading_weeks: Int?
    let maintenance_weeks: Int?
    let tapering_weeks: Int?
    let off_cycle_weeks: Int?
    let total_weeks: Int?
}

nonisolated struct SupabaseProtocolInsert: Codable, Sendable {
    let user_id: String
    let name: String
    let goal: String
    let status: String
    let start_date: String
    let notes: String?
    let loading_weeks: Int
    let maintenance_weeks: Int
    let tapering_weeks: Int
    let off_cycle_weeks: Int
    let total_weeks: Int
}

nonisolated struct SupabaseCompound: Codable, Sendable {
    let id: String?
    let protocol_id: String
    let compound_name: String
    let dose_mcg: Double?
    let frequency: String?
    let time_of_day: String?
    let injection_route: String?
    let reconstitution_volume: Double?
    let vial_size_mg: Double?
    let vendor_name: String?
    let batch_number: String?
    let start_date: String?
    let end_date: String?
}

nonisolated struct SupabaseCompoundInsert: Codable, Sendable {
    let protocol_id: String
    let compound_name: String
    let dose_mcg: Double
    let frequency: String
    let time_of_day: String?
    let injection_route: String
    let reconstitution_volume: Double?
    let vial_size_mg: Double?
    let vendor_name: String?
    let batch_number: String?
}

nonisolated struct SupabaseDoseLog: Codable, Sendable {
    let id: String?
    let user_id: String?
    let protocol_id: String
    let compound_name: String
    let dose_mcg: Double
    let logged_at: String?
    let injection_site: String?
    let notes: String?
}

nonisolated struct SupabaseDoseLogInsert: Codable, Sendable {
    let user_id: String
    let protocol_id: String
    let compound_name: String
    let dose_mcg: Double
    let injection_site: String?
    let notes: String?
}

nonisolated struct SupabaseSideEffectLog: Codable, Sendable {
    let id: String?
    let user_id: String?
    let protocol_id: String
    let symptom: String
    let severity: Int
    let logged_at: String?
    let notes: String?
}

nonisolated struct SupabaseSideEffectInsert: Codable, Sendable {
    let user_id: String
    let protocol_id: String
    let symptom: String
    let severity: Int
    let notes: String?
}

nonisolated struct SupabaseSupplement: Codable, Sendable {
    let id: String?
    let user_id: String?
    let protocol_id: String
    let name: String
    let dosage: String?
    let frequency: String?
    let notes: String?
}

nonisolated struct SupabaseSupplementInsert: Codable, Sendable {
    let user_id: String
    let protocol_id: String
    let name: String
    let dosage: String?
    let frequency: String?
    let notes: String?
}

final class ProtocolService {
    static let shared = ProtocolService()

    private var supabase: SupabaseClient {
        SupabaseService.shared.client
    }

    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private let iso8601Basic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private init() {}

    private func parseDate(_ string: String?) -> Date {
        guard let string else { return Date() }
        return iso8601.date(from: string) ?? iso8601Basic.date(from: string) ?? Date()
    }

    private func currentUserId() async throws -> String {
        guard let session = try? await supabase.auth.session else {
            throw ProtocolServiceError.notAuthenticated
        }
        return session.user.id.uuidString
    }

    // MARK: - Protocols CRUD

    func fetchProtocols() async throws -> [PeptideProtocol] {
        let userId = try await currentUserId()

        let rows: [SupabaseProtocol] = try await supabase
            .from("protocols")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value

        var protocols: [PeptideProtocol] = []
        for row in rows {
            guard let id = row.id else { continue }
            let compounds = try await fetchCompounds(protocolId: id)
            let doseLogs = try await fetchDoseLogs(protocolId: id)
            let sideEffects = try await fetchSideEffects(protocolId: id)
            let supplements = try await fetchSupplements(protocolId: id)

            let goal = ProtocolGoal.allCases.first { $0.rawValue == row.goal } ?? .custom
            let startDate = parseDate(row.start_date)
            let totalWeeks = row.total_weeks ?? 8
            let loadingWeeks = row.loading_weeks ?? 1
            let maintenanceWeeks = row.maintenance_weeks ?? 5
            let taperingWeeks = row.tapering_weeks ?? 1
            let offCycleWeeks = row.off_cycle_weeks ?? 4
            let isActive = row.status == "active"

            var proto = PeptideProtocol(
                name: row.name,
                goal: goal,
                compounds: compounds,
                startDate: startDate,
                totalWeeks: totalWeeks,
                loadingWeeks: loadingWeeks,
                maintenanceWeeks: maintenanceWeeks,
                taperingWeeks: taperingWeeks,
                offCycleWeeks: offCycleWeeks,
                isActive: isActive,
                doseLog: doseLogs,
                sideEffectLog: sideEffects,
                supplements: supplements
            )
            proto.supabaseId = id
            protocols.append(proto)
        }

        return protocols
    }

    func createProtocol(_ proto: PeptideProtocol) async throws -> PeptideProtocol {
        let userId = try await currentUserId()

        let insert = SupabaseProtocolInsert(
            user_id: userId,
            name: proto.name,
            goal: proto.goal.rawValue,
            status: proto.isActive ? "active" : "inactive",
            start_date: iso8601.string(from: proto.startDate),
            notes: nil,
            loading_weeks: proto.loadingWeeks,
            maintenance_weeks: proto.maintenanceWeeks,
            tapering_weeks: proto.taperingWeeks,
            off_cycle_weeks: proto.offCycleWeeks,
            total_weeks: proto.totalWeeks
        )

        let result: SupabaseProtocol = try await supabase
            .from("protocols")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        guard let protocolId = result.id else {
            throw ProtocolServiceError.createFailed
        }

        for compound in proto.compounds {
            try await createCompound(compound, protocolId: protocolId)
        }

        for supplement in proto.supplements {
            try await createSupplement(supplement, protocolId: protocolId, userId: userId)
        }

        var created = proto
        created.supabaseId = protocolId
        return created
    }

    func deleteProtocol(id: String) async throws {
        try await supabase
            .from("protocols")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func updateProtocolStatus(id: String, status: String) async throws {
        try await supabase
            .from("protocols")
            .update(["status": status])
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Compounds

    func fetchCompounds(protocolId: String) async throws -> [ProtocolCompound] {
        let rows: [SupabaseCompound] = try await supabase
            .from("protocol_compounds")
            .select()
            .eq("protocol_id", value: protocolId)
            .execute()
            .value

        return rows.map { row in
            let route = InjectionRoute.allCases.first { $0.rawValue == row.injection_route } ?? .subcutaneous
            var compound = ProtocolCompound(
                compoundName: row.compound_name,
                doseMcg: row.dose_mcg ?? 0,
                frequency: row.frequency ?? "Daily",
                injectionRoute: route,
                reconstitutionVolume: row.reconstitution_volume,
                vialSizeMg: row.vial_size_mg,
                vendorName: row.vendor_name,
                batchNumber: row.batch_number
            )
            compound.supabaseId = row.id
            return compound
        }
    }

    func createCompound(_ compound: ProtocolCompound, protocolId: String) async throws {
        let insert = SupabaseCompoundInsert(
            protocol_id: protocolId,
            compound_name: compound.compoundName,
            dose_mcg: compound.doseMcg,
            frequency: compound.frequency,
            time_of_day: nil,
            injection_route: compound.injectionRoute.rawValue,
            reconstitution_volume: compound.reconstitutionVolume,
            vial_size_mg: compound.vialSizeMg,
            vendor_name: compound.vendorName,
            batch_number: compound.batchNumber
        )

        try await supabase
            .from("protocol_compounds")
            .insert(insert)
            .execute()
    }

    // MARK: - Dose Logs

    func fetchDoseLogs(protocolId: String) async throws -> [DoseLogEntry] {
        let rows: [SupabaseDoseLog] = try await supabase
            .from("dose_logs")
            .select()
            .eq("protocol_id", value: protocolId)
            .order("logged_at", ascending: false)
            .execute()
            .value

        return rows.map { row in
            let site = InjectionSite.allCases.first { $0.rawValue == row.injection_site } ?? .leftAbdomen
            var entry = DoseLogEntry(
                compoundName: row.compound_name,
                doseMcg: row.dose_mcg,
                timestamp: parseDate(row.logged_at),
                injectionSite: site,
                notes: row.notes ?? ""
            )
            entry.supabaseId = row.id
            return entry
        }
    }

    func logDose(protocolId: String, compoundName: String, doseMcg: Double, injectionSite: InjectionSite, notes: String) async throws -> DoseLogEntry {
        let userId = try await currentUserId()

        let insert = SupabaseDoseLogInsert(
            user_id: userId,
            protocol_id: protocolId,
            compound_name: compoundName,
            dose_mcg: doseMcg,
            injection_site: injectionSite.rawValue,
            notes: notes.isEmpty ? nil : notes
        )

        let result: SupabaseDoseLog = try await supabase
            .from("dose_logs")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        var entry = DoseLogEntry(
            compoundName: compoundName,
            doseMcg: doseMcg,
            injectionSite: injectionSite,
            notes: notes
        )
        entry.supabaseId = result.id
        return entry
    }

    // MARK: - Side Effects

    func fetchSideEffects(protocolId: String) async throws -> [SideEffectEntry] {
        let rows: [SupabaseSideEffectLog] = try await supabase
            .from("side_effect_logs")
            .select()
            .eq("protocol_id", value: protocolId)
            .order("logged_at", ascending: false)
            .execute()
            .value

        return rows.map { row in
            var entry = SideEffectEntry(
                timestamp: parseDate(row.logged_at),
                effect: row.symptom,
                severity: row.severity,
                notes: row.notes ?? ""
            )
            entry.supabaseId = row.id
            return entry
        }
    }

    func logSideEffect(protocolId: String, symptom: String, severity: Int, notes: String) async throws -> SideEffectEntry {
        let userId = try await currentUserId()

        let insert = SupabaseSideEffectInsert(
            user_id: userId,
            protocol_id: protocolId,
            symptom: symptom,
            severity: severity,
            notes: notes.isEmpty ? nil : notes
        )

        let result: SupabaseSideEffectLog = try await supabase
            .from("side_effect_logs")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        var entry = SideEffectEntry(
            effect: symptom,
            severity: severity,
            notes: notes
        )
        entry.supabaseId = result.id
        return entry
    }

    // MARK: - Supplements

    func fetchSupplements(protocolId: String) async throws -> [SupplementEntry] {
        let rows: [SupabaseSupplement] = try await supabase
            .from("supplements")
            .select()
            .eq("protocol_id", value: protocolId)
            .execute()
            .value

        return rows.map { row in
            var entry = SupplementEntry(
                name: row.name,
                dose: row.dosage ?? "",
                frequency: row.frequency ?? "Daily"
            )
            entry.supabaseId = row.id
            return entry
        }
    }

    func addSupplement(_ supplement: SupplementEntry, protocolId: String) async throws -> SupplementEntry {
        let userId = try await currentUserId()
        return try await createSupplement(supplement, protocolId: protocolId, userId: userId)
    }

    func createSupplement(_ supplement: SupplementEntry, protocolId: String, userId: String) async throws -> SupplementEntry {
        let insert = SupabaseSupplementInsert(
            user_id: userId,
            protocol_id: protocolId,
            name: supplement.name,
            dosage: supplement.dose.isEmpty ? nil : supplement.dose,
            frequency: supplement.frequency,
            notes: nil
        )

        let result: SupabaseSupplement = try await supabase
            .from("supplements")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        var entry = supplement
        entry.supabaseId = result.id
        return entry
    }

    func deleteSupplement(id: String) async throws {
        try await supabase
            .from("supplements")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}

nonisolated enum ProtocolServiceError: Error, LocalizedError, Sendable {
    case notAuthenticated
    case createFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "You must be signed in to manage protocols."
        case .createFailed: return "Failed to create protocol."
        }
    }
}
