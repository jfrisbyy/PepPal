import Foundation
import Supabase

nonisolated struct SupabaseProtocol: Codable, Sendable {
    let id: String?
    let user_id: String?
    let name: String
    let goal: String?
    let start_date: String?
    let total_weeks: Int?
    let loading_weeks: Int?
    let maintenance_weeks: Int?
    let tapering_weeks: Int?
    let off_cycle_weeks: Int?
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
    let loading_weeks: Int?
    let maintenance_weeks: Int?
    let tapering_weeks: Int?
    let off_cycle_weeks: Int?
    let experience_level: String?
    let is_active: Bool
}

nonisolated struct SupabaseProtocolUpdate: Codable, Sendable {
    let is_active: Bool?
    let name: String?
    let goal: String?
    let total_weeks: Int?
    let loading_weeks: Int?
    let maintenance_weeks: Int?
    let tapering_weeks: Int?
    let off_cycle_weeks: Int?
    let experience_level: String?
}

nonisolated struct SupabaseCompoundUpdate: Codable, Sendable {
    let dose_mcg: Double?
    let frequency: String?
    let time_of_day: String?
    let vendor_name: String?
    let batch_number: String?
    let manufacture_date: String?
    let expiration_date: String?
}

nonisolated struct SupabaseCompound: Codable, Sendable {
    let id: String?
    let protocol_id: String
    let compound_name: String
    let dose_mcg: Double?
    let frequency: String?
    let time_of_day: String?
    let injection_route: String?
    let vial_size_mg: Double?
    let reconstitution_volume_ml: Double?
    let vendor_name: String?
    let batch_number: String?
    let manufacture_date: String?
    let expiration_date: String?
    let created_at: String?
}

nonisolated struct SupabaseCompoundInsert: Codable, Sendable {
    let protocol_id: String
    let compound_name: String
    let dose_mcg: Double
    let frequency: String
    let time_of_day: String?
    let injection_route: String?
    let vial_size_mg: Double?
    let reconstitution_volume_ml: Double?
    let vendor_name: String?
    let batch_number: String?
    let manufacture_date: String?
    let expiration_date: String?
}

nonisolated struct SupabaseDoseLog: Codable, Sendable {
    let id: String?
    let user_id: String?
    let protocol_id: String
    let compound_name: String
    let dose_mcg: Double
    let logged_at: String?
    let notes: String?
    let injection_site: String?
    let was_skipped: Bool?
    let skip_reason: String?
}

nonisolated struct SupabaseDoseLogInsert: Codable, Sendable {
    let user_id: String
    let protocol_id: String
    let compound_name: String
    let dose_mcg: Double
    let notes: String?
    let logged_at: String?
    let injection_site: String?
    let was_skipped: Bool?
    let skip_reason: String?
}

nonisolated struct SupabaseDoseLogUpdate: Codable, Sendable {
    let dose_mcg: Double?
    let notes: String?
    let logged_at: String?
    let injection_site: String?
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

nonisolated struct SupabaseProtocolNote: Codable, Sendable {
    let id: String?
    let user_id: String?
    let protocol_id: String
    let text: String
    let logged_at: String?
    let dose_log_id: String?
    let photo_url: String?
}

nonisolated struct SupabaseProtocolNoteInsert: Codable, Sendable {
    let user_id: String
    let protocol_id: String
    let text: String
    let dose_log_id: String?
    let photo_url: String?
}

nonisolated struct SupabaseDailyRating: Codable, Sendable {
    let id: String?
    let user_id: String?
    let protocol_id: String
    let category: String
    let value: Int
    let label: String?
    let rating_date: String
}

nonisolated struct SupabaseDailyRatingInsert: Codable, Sendable {
    let user_id: String
    let protocol_id: String
    let category: String
    let value: Int
    let label: String?
    let rating_date: String
}

nonisolated struct SupabaseRecoveryMilestone: Codable, Sendable {
    let id: String?
    let user_id: String?
    let protocol_id: String
    let title: String
    let is_achieved: Bool
    let achieved_at: String?
}

nonisolated struct SupabaseRecoveryMilestoneInsert: Codable, Sendable {
    let user_id: String
    let protocol_id: String
    let title: String
    let is_achieved: Bool
    let achieved_at: String?
}

nonisolated struct SupabaseTitrationStep: Codable, Sendable {
    let id: String?
    let user_id: String?
    let protocol_id: String
    let week_number: Int
    let dose_mcg: Double
    let label: String?
    let is_completed: Bool
}

nonisolated struct SupabaseTitrationStepInsert: Codable, Sendable {
    let user_id: String
    let protocol_id: String
    let week_number: Int
    let dose_mcg: Double
    let label: String?
    let is_completed: Bool
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

    private let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private init() {}

    private func parseDate(_ string: String?) -> Date {
        guard let string else { return Date() }
        return iso8601.date(from: string) ?? iso8601Basic.date(from: string) ?? dateOnlyFormatter.date(from: string) ?? Date()
    }

    private func parseDateOptional(_ string: String?) -> Date? {
        guard let string else { return nil }
        return iso8601.date(from: string) ?? iso8601Basic.date(from: string) ?? dateOnlyFormatter.date(from: string)
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

            async let compoundsTask = fetchCompounds(protocolId: id)
            async let doseLogsTask = fetchDoseLogs(protocolId: id)
            async let sideEffectsTask = fetchSideEffects(protocolId: id)
            async let supplementsTask = fetchSupplements(protocolId: id)

            let compounds = try await compoundsTask
            let doseLogs = try await doseLogsTask
            let sideEffects = try await sideEffectsTask
            let supplements = try await supplementsTask

            let goal = ProtocolGoal.allCases.first { $0.rawValue == row.goal } ?? .custom
            let startDate = parseDate(row.start_date)
            let totalWeeks = row.total_weeks

            let hasStoredPhases = row.loading_weeks != nil || row.maintenance_weeks != nil || row.tapering_weeks != nil || row.off_cycle_weeks != nil
            let phases: (loading: Int?, maintenance: Int?, tapering: Int?, offCycle: Int?)
            if hasStoredPhases {
                phases = (row.loading_weeks, row.maintenance_weeks, row.tapering_weeks, row.off_cycle_weeks)
            } else {
                phases = estimatePhases(totalWeeks: totalWeeks)
            }
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
            loading_weeks: proto.loadingWeeks,
            maintenance_weeks: proto.maintenanceWeeks,
            tapering_weeks: proto.taperingWeeks,
            off_cycle_weeks: proto.offCycleWeeks,
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

        Task { await MainActor.run { Task { await CompoundStatsService.shared.refresh() } } }

        // Fan out to friends if sharing protocols is enabled
        let sharePrefs = await StatSharingService.shared.currentUserPrefs
        if sharePrefs.isEnabled, sharePrefs.categories.contains(.protocols) {
            let compoundName = proto.compounds.first?.compoundName ?? proto.name
            let totalWeeks = proto.totalWeeks ?? 8
            await FriendsBackendService.shared.recordActivityEvent(
                type: "protocol_started",
                title: "Started \(compoundName)",
                subtitle: "\(totalWeeks)-week protocol",
                data: [
                    "protocol_id": protocolId,
                    "protocol_name": proto.name,
                    "compound": compoundName
                ]
            )
        }
        let pinTitle = proto.name
        let pinStart = proto.startDate
        let pinDuration = max(1, proto.totalWeeks ?? 8) * 7
        let pinCompound = proto.compounds.first?.compoundName
        let pinDose = proto.compounds.first?.doseMcg
        let pinFrequency = proto.compounds.first?.frequency
        await MainActor.run {
            JourneyEventService.shared.autoAdd(
                lane: .compounds,
                timestamp: pinStart,
                title: pinTitle,
                description: pinCompound,
                sourceType: .agent,
                durationDays: pinDuration,
                payload: JourneyEventPayload(
                    compoundName: pinCompound,
                    doseAmount: pinDose,
                    doseUnit: "mcg",
                    frequency: pinFrequency,
                    startDate: pinStart,
                    plannedCycleWeeks: proto.totalWeeks ?? 8
                )
            )
        }
        return created
    }

    func deleteProtocol(id: String) async throws {
        try await supabase
            .from("protocols")
            .delete()
            .eq("id", value: id)
            .execute()
        await MainActor.run { Task { await CompoundStatsService.shared.refresh() } }
    }

    func updateProtocolName(id: String, name: String) async throws {
        let update = SupabaseProtocolUpdate(
            is_active: nil, name: name, goal: nil,
            total_weeks: nil, loading_weeks: nil, maintenance_weeks: nil, tapering_weeks: nil, off_cycle_weeks: nil,
            experience_level: nil
        )
        try await supabase.from("protocols").update(update).eq("id", value: id).execute()
    }

    func updateCompound(id: String, doseMcg: Double, frequency: String) async throws {
        let update = SupabaseCompoundUpdate(
            dose_mcg: doseMcg,
            frequency: frequency,
            time_of_day: nil,
            vendor_name: nil,
            batch_number: nil,
            manufacture_date: nil,
            expiration_date: nil
        )
        try await supabase
            .from("protocol_compounds")
            .update(update)
            .eq("id", value: id)
            .execute()
    }

    func updateCompoundBatch(
        id: String,
        vendorName: String?,
        batchNumber: String?,
        manufactureDate: Date?,
        expirationDate: Date?
    ) async throws {
        let update = SupabaseCompoundUpdate(
            dose_mcg: nil,
            frequency: nil,
            time_of_day: nil,
            vendor_name: vendorName,
            batch_number: batchNumber,
            manufacture_date: manufactureDate.map { dateOnlyFormatter.string(from: $0) },
            expiration_date: expirationDate.map { dateOnlyFormatter.string(from: $0) }
        )
        try await supabase
            .from("protocol_compounds")
            .update(update)
            .eq("id", value: id)
            .execute()
    }

    func deleteCompound(id: String) async throws {
        try await supabase
            .from("protocol_compounds")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func updateProtocolStatus(id: String, isActive: Bool) async throws {
        let update = SupabaseProtocolUpdate(
            is_active: isActive, name: nil, goal: nil,
            total_weeks: nil, loading_weeks: nil, maintenance_weeks: nil, tapering_weeks: nil, off_cycle_weeks: nil,
            experience_level: nil
        )
        try await supabase.from("protocols").update(update).eq("id", value: id).execute()
        await MainActor.run { Task { await CompoundStatsService.shared.refresh() } }

        if !isActive {
            // Protocol ended — fan out a finished event if sharing protocols
            let prefs = await StatSharingService.shared.currentUserPrefs
            if prefs.isEnabled, prefs.categories.contains(.protocols) {
                let row: [SupabaseProtocol] = (try? await supabase
                    .from("protocols")
                    .select("id, user_id, name, goal, start_date, total_weeks, loading_weeks, maintenance_weeks, tapering_weeks, off_cycle_weeks, experience_level, is_active")
                    .eq("id", value: id)
                    .limit(1)
                    .execute()
                    .value) ?? []
                let name = row.first?.name ?? "Protocol"
                let weeks = row.first?.total_weeks ?? 0
                await FriendsBackendService.shared.recordActivityEvent(
                    type: "protocol_finished",
                    title: "Finished \(name)",
                    subtitle: weeks > 0 ? "\(weeks)-week protocol — done" : "Wrapped a protocol",
                    data: ["protocol_id": id, "protocol_name": name]
                )
            }
        }
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
                reconstitutionVolume: row.reconstitution_volume_ml,
                vialSizeMg: row.vial_size_mg,
                vendorName: row.vendor_name,
                batchNumber: row.batch_number,
                manufactureDate: parseDateOptional(row.manufacture_date),
                expirationDate: parseDateOptional(row.expiration_date)
            )
            compound.supabaseId = row.id
            return compound
        }
    }

    func createCompound(_ compound: ProtocolCompound, protocolId: String) async throws {
        let timeOfDay = iso8601.string(from: compound.timeOfDay)
        let insert = SupabaseCompoundInsert(
            protocol_id: protocolId,
            compound_name: compound.compoundName,
            dose_mcg: compound.doseMcg,
            frequency: compound.frequency,
            time_of_day: timeOfDay,
            injection_route: compound.injectionRoute.rawValue,
            vial_size_mg: compound.vialSizeMg,
            reconstitution_volume_ml: compound.reconstitutionVolume,
            vendor_name: compound.vendorName,
            batch_number: compound.batchNumber,
            manufacture_date: compound.manufactureDate.map { dateOnlyFormatter.string(from: $0) },
            expiration_date: compound.expirationDate.map { dateOnlyFormatter.string(from: $0) }
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
                notes: row.notes ?? "",
                wasSkipped: row.was_skipped ?? false,
                skipReason: row.skip_reason
            )
            entry.supabaseId = row.id
            return entry
        }
    }

    func logDose(protocolId: String, compoundName: String, doseMcg: Double, injectionSite: InjectionSite, notes: String, loggedAt: Date? = nil, wasSkipped: Bool = false, skipReason: String? = nil) async throws -> DoseLogEntry {
        let userId = try await currentUserId()

        var loggedAtString: String? = nil
        if let loggedAt {
            loggedAtString = iso8601.string(from: loggedAt)
        }

        let insert = SupabaseDoseLogInsert(
            user_id: userId,
            protocol_id: protocolId,
            compound_name: compoundName,
            dose_mcg: doseMcg,
            notes: notes.isEmpty ? nil : notes,
            logged_at: loggedAtString,
            injection_site: injectionSite.rawValue,
            was_skipped: wasSkipped,
            skip_reason: skipReason
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
            timestamp: parseDate(result.logged_at),
            injectionSite: injectionSite,
            notes: notes,
            wasSkipped: wasSkipped,
            skipReason: skipReason
        )
        entry.supabaseId = result.id
        return entry
    }

    func deleteDoseLog(id: String) async throws {
        try await supabase.from("dose_logs").delete().eq("id", value: id).execute()
    }

    func updateDoseLog(id: String, doseMcg: Double, injectionSite: InjectionSite, notes: String, loggedAt: Date) async throws -> DoseLogEntry {
        let update = SupabaseDoseLogUpdate(
            dose_mcg: doseMcg,
            notes: notes.isEmpty ? nil : notes,
            logged_at: iso8601.string(from: loggedAt),
            injection_site: injectionSite.rawValue
        )
        let result: SupabaseDoseLog = try await supabase
            .from("dose_logs")
            .update(update)
            .eq("id", value: id)
            .select()
            .single()
            .execute()
            .value
        var entry = DoseLogEntry(
            compoundName: result.compound_name,
            doseMcg: result.dose_mcg,
            timestamp: parseDate(result.logged_at),
            injectionSite: injectionSite,
            notes: notes,
            wasSkipped: result.was_skipped ?? false,
            skipReason: result.skip_reason
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

    // MARK: - Notes

    func fetchNotes(protocolId: String) async throws -> [ProtocolNote] {
        let rows: [SupabaseProtocolNote] = try await supabase
            .from("protocol_notes")
            .select()
            .eq("protocol_id", value: protocolId)
            .order("logged_at", ascending: false)
            .execute()
            .value

        return rows.map { row in
            var note = ProtocolNote(
                timestamp: parseDate(row.logged_at),
                text: row.text,
                doseLogId: nil,
                photoUrl: row.photo_url
            )
            note.supabaseId = row.id
            return note
        }
    }

    func addNote(protocolId: String, text: String, doseLogId: String? = nil, photoUrl: String? = nil) async throws -> ProtocolNote {
        let userId = try await currentUserId()
        let insert = SupabaseProtocolNoteInsert(
            user_id: userId,
            protocol_id: protocolId,
            text: text,
            dose_log_id: doseLogId,
            photo_url: photoUrl
        )
        let result: SupabaseProtocolNote = try await supabase
            .from("protocol_notes")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        var note = ProtocolNote(
            timestamp: parseDate(result.logged_at),
            text: result.text,
            doseLogId: nil,
            photoUrl: result.photo_url
        )
        note.supabaseId = result.id
        return note
    }

    func uploadNotePhoto(imageData: Data) async throws -> String {
        let userId = try await currentUserId()
        let fileName = "\(userId)/note_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString).jpg"
        try await supabase.storage
            .from("protocol-note-photos")
            .upload(
                fileName,
                data: imageData,
                options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: false)
            )
        // Bucket is private; use a long-lived signed URL so the row stored
        // in protocol_notes.photo_url remains directly displayable.
        let signed = try await supabase.storage
            .from("protocol-note-photos")
            .createSignedURL(path: fileName, expiresIn: 60 * 60 * 24 * 365)
        return signed.absoluteString
    }

    // MARK: - Daily Ratings

    func fetchRatings(protocolId: String) async throws -> [DailyRating] {
        let rows: [SupabaseDailyRating] = try await supabase
            .from("daily_ratings")
            .select()
            .eq("protocol_id", value: protocolId)
            .order("rating_date", ascending: false)
            .execute()
            .value

        return rows.map { row in
            DailyRating(
                date: parseDate(row.rating_date),
                category: row.category,
                value: row.value,
                label: row.label ?? ""
            )
        }
    }

    func upsertRating(protocolId: String, category: String, value: Int, label: String, date: Date) async throws {
        let userId = try await currentUserId()
        let dateStr = dateOnlyFormatter.string(from: Calendar.current.startOfDay(for: date))
        let insert = SupabaseDailyRatingInsert(
            user_id: userId,
            protocol_id: protocolId,
            category: category,
            value: value,
            label: label.isEmpty ? nil : label,
            rating_date: dateStr
        )
        try await supabase
            .from("daily_ratings")
            .upsert(insert, onConflict: "protocol_id,category,rating_date")
            .execute()
    }

    // MARK: - Recovery Milestones

    func fetchMilestones(protocolId: String) async throws -> [RecoveryMilestone] {
        let rows: [SupabaseRecoveryMilestone] = try await supabase
            .from("recovery_milestones")
            .select()
            .eq("protocol_id", value: protocolId)
            .execute()
            .value

        return rows.map { row in
            RecoveryMilestone(
                title: row.title,
                isAchieved: row.is_achieved,
                achievedDate: parseDateOptional(row.achieved_at)
            )
        }
    }

    func upsertMilestone(protocolId: String, title: String, isAchieved: Bool, achievedAt: Date?) async throws {
        let userId = try await currentUserId()
        let insert = SupabaseRecoveryMilestoneInsert(
            user_id: userId,
            protocol_id: protocolId,
            title: title,
            is_achieved: isAchieved,
            achieved_at: achievedAt.map { iso8601.string(from: $0) }
        )
        try await supabase
            .from("recovery_milestones")
            .upsert(insert, onConflict: "protocol_id,title")
            .execute()
    }

    // MARK: - Titration Steps

    func fetchTitrationSteps(protocolId: String) async throws -> [TitrationStep] {
        let rows: [SupabaseTitrationStep] = try await supabase
            .from("titration_steps")
            .select()
            .eq("protocol_id", value: protocolId)
            .order("week_number", ascending: true)
            .execute()
            .value

        return rows.map { row in
            TitrationStep(
                weekNumber: row.week_number,
                doseMcg: row.dose_mcg,
                label: row.label ?? "",
                isCompleted: row.is_completed
            )
        }
    }

    func upsertTitrationStep(protocolId: String, weekNumber: Int, doseMcg: Double, label: String, isCompleted: Bool) async throws {
        let userId = try await currentUserId()
        let insert = SupabaseTitrationStepInsert(
            user_id: userId,
            protocol_id: protocolId,
            week_number: weekNumber,
            dose_mcg: doseMcg,
            label: label.isEmpty ? nil : label,
            is_completed: isCompleted
        )
        try await supabase
            .from("titration_steps")
            .upsert(insert, onConflict: "protocol_id,week_number")
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
