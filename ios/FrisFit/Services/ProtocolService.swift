import Foundation
import Supabase

nonisolated struct SupabaseProtocol: Codable, Sendable {
    let id: String?
    let user_id: String?
    let name: String
    let goal: String?
    let start_date: String?
    let total_weeks: Int?
    let experience_level: String?
    let is_active: Bool?
    let created_at: String?
    let updated_at: String?
}

nonisolated struct SupabaseProtocolInsert: Codable, Sendable {
    let user_id: String
    let name: String
    let goal: String
    let start_date: String
    let total_weeks: Int?
    let experience_level: String?
    let is_active: Bool
}

nonisolated struct SupabaseProtocolUpdate: Codable, Sendable {
    let is_active: Bool?
    let name: String?
    let goal: String?
    let total_weeks: Int?
    let experience_level: String?
}

nonisolated struct SupabaseCompound: Codable, Sendable {
    let id: String?
    let protocol_id: String
    let compound_name: String
    let dose_mcg: Double?
    let frequency: String?
    let time_of_day: String?
    let created_at: String?
}

nonisolated struct SupabaseCompoundInsert: Codable, Sendable {
    let protocol_id: String
    let compound_name: String
    let dose_mcg: Double
    let frequency: String
    let time_of_day: String?
}

nonisolated struct SupabaseDoseLog: Codable, Sendable {
    let id: String?
    let user_id: String?
    let protocol_id: String
    let compound_name: String
    let dose_mcg: Double
    let logged_at: String?
    let notes: String?
}

nonisolated struct SupabaseDoseLogInsert: Codable, Sendable {
    let user_id: String
    let protocol_id: String
    let compound_name: String
    let dose_mcg: Double
    let notes: String?
    let logged_at: String?
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
        return session.user.id.uuidString.lowercased()
    }

    private func estimatePhases(totalWeeks: Int?) -> (loading: Int?, maintenance: Int?, tapering: Int?, offCycle: Int?) {
        guard let totalWeeks, totalWeeks > 0 else { return (nil, nil, nil, nil) }
        if totalWeeks <= 4 {
            return (nil, totalWeeks, nil, nil)
        }
        let offCycle = min(4, totalWeeks / 4)
        let remaining = totalWeeks - offCycle
        let loading = min(2, remaining / 4)
        let tapering = min(1, remaining / 6)
        let maintenance = max(1, remaining - loading - tapering)
        return (loading, maintenance, tapering, offCycle)
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
            let totalWeeks = row.total_weeks
            let phases = estimatePhases(totalWeeks: totalWeeks)
            let isActive = row.is_active ?? false

            var proto = PeptideProtocol(
                name: row.name,
                goal: goal,
                compounds: compounds,
                startDate: startDate,
                totalWeeks: totalWeeks,
                loadingWeeks: phases.loading,
                maintenanceWeeks: phases.maintenance,
                taperingWeeks: phases.tapering,
                offCycleWeeks: phases.offCycle,
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
            start_date: iso8601.string(from: proto.startDate),
            total_weeks: proto.totalWeeks,
            experience_level: nil,
            is_active: proto.isActive
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

    func updateProtocolStatus(id: String, isActive: Bool) async throws {
        let update = SupabaseProtocolUpdate(
            is_active: isActive,
            name: nil,
            goal: nil,
            total_weeks: nil,
            experience_level: nil
        )
        try await supabase
            .from("protocols")
            .update(update)
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
            var compound = ProtocolCompound(
                compoundName: row.compound_name,
                doseMcg: row.dose_mcg ?? 0,
                frequency: row.frequency ?? "Daily",
                injectionRoute: .subcutaneous
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
            time_of_day: nil
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
            var entry = DoseLogEntry(
                compoundName: row.compound_name,
                doseMcg: row.dose_mcg,
                timestamp: parseDate(row.logged_at),
                injectionSite: .leftAbdomen,
                notes: row.notes ?? ""
            )
            entry.supabaseId = row.id
            return entry
        }
    }

    func logDose(protocolId: String, compoundName: String, doseMcg: Double, injectionSite: InjectionSite, notes: String, loggedAt: Date? = nil) async throws -> DoseLogEntry {
        let userId = try await currentUserId()

        var loggedAtString: String? = nil
        if let loggedAt {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            loggedAtString = formatter.string(from: loggedAt)
        }

        let insert = SupabaseDoseLogInsert(
            user_id: userId,
            protocol_id: protocolId,
            compound_name: compoundName,
            dose_mcg: doseMcg,
            notes: notes.isEmpty ? nil : notes,
            logged_at: loggedAtString
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
