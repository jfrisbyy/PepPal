import Foundation
import Supabase

nonisolated struct SupabaseTrainingProgram: Codable, Sendable {
    let id: String?
    let user_id: String?
    let name: String
    let program_type: String?
    let days_per_week: Int
    let days_json: String
    let is_active: Bool?
    let current_week: Int?
    let start_day_offset: Int?
    let created_at: String?
    let updated_at: String?
}

nonisolated struct SupabaseTrainingProgramInsert: Codable, Sendable {
    let user_id: String
    let name: String
    let program_type: String
    let days_per_week: Int
    let days_json: String
    let is_active: Bool
    let current_week: Int
    let start_day_offset: Int
}

nonisolated struct SupabaseTrainingProgramUpdate: Codable, Sendable {
    let name: String?
    let program_type: String?
    let days_per_week: Int?
    let days_json: String?
    let is_active: Bool?
    let current_week: Int?
    let start_day_offset: Int?
    let updated_at: String?
}

final class TrainingProgramService {
    static let shared = TrainingProgramService()

    private var supabase: SupabaseClient {
        SupabaseService.shared.client
    }

    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private init() {}

    private func currentUserId() async throws -> String {
        guard let session = try? await supabase.auth.session else {
            throw TrainingProgramServiceError.notAuthenticated
        }
        return session.user.id.uuidString.lowercased()
    }

    private func encodeDays(_ days: [ProgramDay]) throws -> String {
        let data = try JSONEncoder().encode(days)
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    private func decodeDays(_ json: String) -> [ProgramDay] {
        guard let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([ProgramDay].self, from: data)) ?? []
    }

    func fetchPrograms() async throws -> [(program: TrainingProgram, supabaseId: String, startDayOffset: Int)] {
        let userId = try await currentUserId()
        let rows: [SupabaseTrainingProgram] = try await supabase
            .from("training_programs")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .limit(50)
            .execute()
            .value

        return rows.compactMap { row in
            guard let sid = row.id else { return nil }
            let type = ProgramType(rawValue: row.program_type ?? "") ?? .recurringSplit
            let days = decodeDays(row.days_json)
            var program = TrainingProgram(
                name: row.name,
                type: type,
                daysPerWeek: row.days_per_week,
                days: days,
                isActive: row.is_active ?? false
            )
            program.currentWeek = row.current_week ?? 1
            return (program, sid, row.start_day_offset ?? 0)
        }
    }

    func createProgram(_ program: TrainingProgram, startDayOffset: Int) async throws -> String {
        let userId = try await currentUserId()
        let daysJSON = try encodeDays(program.days)
        let insert = SupabaseTrainingProgramInsert(
            user_id: userId,
            name: program.name,
            program_type: "custom",
            days_per_week: program.daysPerWeek,
            days_json: daysJSON,
            is_active: program.isActive,
            current_week: program.currentWeek,
            start_day_offset: startDayOffset
        )

        let result: SupabaseTrainingProgram = try await supabase
            .from("training_programs")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        guard let sid = result.id else {
            throw TrainingProgramServiceError.createFailed
        }
        return sid
    }

    func updateProgram(id: String, program: TrainingProgram, startDayOffset: Int? = nil) async throws {
        let daysJSON = try encodeDays(program.days)
        let update = SupabaseTrainingProgramUpdate(
            name: program.name,
            program_type: "custom",
            days_per_week: program.daysPerWeek,
            days_json: daysJSON,
            is_active: program.isActive,
            current_week: program.currentWeek,
            start_day_offset: startDayOffset,
            updated_at: iso8601.string(from: Date())
        )
        try await supabase
            .from("training_programs")
            .update(update)
            .eq("id", value: id)
            .execute()
    }

    func setActive(id: String, isActive: Bool) async throws {
        let update = SupabaseTrainingProgramUpdate(
            name: nil, program_type: nil, days_per_week: nil, days_json: nil,
            is_active: isActive, current_week: nil, start_day_offset: nil,
            updated_at: iso8601.string(from: Date())
        )
        try await supabase
            .from("training_programs")
            .update(update)
            .eq("id", value: id)
            .execute()
    }

    func deactivateAll(exceptId: String?) async throws {
        let userId = try await currentUserId()
        let update = SupabaseTrainingProgramUpdate(
            name: nil, program_type: nil, days_per_week: nil, days_json: nil,
            is_active: false, current_week: nil, start_day_offset: nil,
            updated_at: iso8601.string(from: Date())
        )
        if let exceptId {
            try await supabase
                .from("training_programs")
                .update(update)
                .eq("user_id", value: userId)
                .neq("id", value: exceptId)
                .execute()
        } else {
            try await supabase
                .from("training_programs")
                .update(update)
                .eq("user_id", value: userId)
                .execute()
        }
    }

    func deleteProgram(id: String) async throws {
        try await supabase
            .from("training_programs")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}

nonisolated enum TrainingProgramServiceError: Error, LocalizedError, Sendable {
    case notAuthenticated
    case createFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "You must be signed in to save training programs."
        case .createFailed: return "Failed to save training program."
        }
    }
}
