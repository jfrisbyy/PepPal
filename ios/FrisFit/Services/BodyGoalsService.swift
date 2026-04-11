import Foundation
import Supabase

nonisolated struct SupabaseBodyGoal: Codable, Sendable {
    let id: String?
    let user_id: String?
    let goal_type: String
    let target_weight: Double?
    let target_date: String?
    let starting_weight: Double?
    let current_weight: Double?
    let height_cm: Double?
    let weekly_rate: Double?
    let unit: String?
    let created_at: String?
    let updated_at: String?
}

nonisolated struct SupabaseBodyGoalInsert: Codable, Sendable {
    let user_id: String
    let goal_type: String
    let target_weight: Double?
    let target_date: String?
    let starting_weight: Double?
    let current_weight: Double?
    let height_cm: Double?
    let weekly_rate: Double?
    let unit: String?
}

nonisolated struct SupabaseBodyGoalUpdate: Codable, Sendable {
    let goal_type: String?
    let target_weight: Double?
    let target_date: String?
    let starting_weight: Double?
    let current_weight: Double?
    let height_cm: Double?
    let weekly_rate: Double?
    let unit: String?
    let updated_at: String?
}

nonisolated struct SupabaseWeightLog: Codable, Sendable {
    let id: String?
    let user_id: String?
    let weight: Double
    let unit: String?
    let note: String?
    let logged_at: String?
}

nonisolated struct SupabaseWeightLogInsert: Codable, Sendable {
    let user_id: String
    let weight: Double
    let unit: String
    let note: String?
}

nonisolated struct SupabaseBodyMeasurement: Codable, Sendable {
    let id: String?
    let user_id: String?
    let chest: Double?
    let waist: Double?
    let hips: Double?
    let neck: Double?
    let left_bicep: Double?
    let right_bicep: Double?
    let left_thigh: Double?
    let right_thigh: Double?
    let unit: String?
    let measured_at: String?
}

nonisolated struct SupabaseBodyMeasurementInsert: Codable, Sendable {
    let user_id: String
    let chest: Double?
    let waist: Double?
    let hips: Double?
    let neck: Double?
    let left_bicep: Double?
    let right_bicep: Double?
    let left_thigh: Double?
    let right_thigh: Double?
    let unit: String
}

final class BodyGoalsService {
    static let shared = BodyGoalsService()

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
            throw BodyGoalsServiceError.notAuthenticated
        }
        return session.user.id.uuidString.lowercased()
    }

    // MARK: - Body Goals

    func fetchGoal() async throws -> SupabaseBodyGoal? {
        let userId = try await currentUserId()
        let rows: [SupabaseBodyGoal] = try await supabase
            .from("body_goals")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func upsertGoal(goalType: FitnessGoalType, targetWeight: Double?, targetDate: Date?, startingWeight: Double?, currentWeight: Double?, heightCm: Double?, weeklyRate: Double?) async throws -> SupabaseBodyGoal {
        let userId = try await currentUserId()
        let existing = try await fetchGoal()

        if let existing, let existingId = existing.id {
            let update = SupabaseBodyGoalUpdate(
                goal_type: goalType.rawValue,
                target_weight: targetWeight,
                target_date: targetDate.map { iso8601.string(from: $0) },
                starting_weight: startingWeight,
                current_weight: currentWeight,
                height_cm: heightCm,
                weekly_rate: weeklyRate,
                unit: "lbs",
                updated_at: iso8601.string(from: Date())
            )
            let result: SupabaseBodyGoal = try await supabase
                .from("body_goals")
                .update(update)
                .eq("id", value: existingId)
                .select()
                .single()
                .execute()
                .value
            return result
        } else {
            let insert = SupabaseBodyGoalInsert(
                user_id: userId,
                goal_type: goalType.rawValue,
                target_weight: targetWeight,
                target_date: targetDate.map { iso8601.string(from: $0) },
                starting_weight: startingWeight,
                current_weight: currentWeight,
                height_cm: heightCm,
                weekly_rate: weeklyRate,
                unit: "lbs"
            )
            let result: SupabaseBodyGoal = try await supabase
                .from("body_goals")
                .insert(insert)
                .select()
                .single()
                .execute()
                .value
            return result
        }
    }

    // MARK: - Weight Logs

    func fetchWeightLogs() async throws -> [WeightEntry] {
        let userId = try await currentUserId()
        let rows: [SupabaseWeightLog] = try await supabase
            .from("weight_logs")
            .select()
            .eq("user_id", value: userId)
            .order("logged_at", ascending: true)
            .execute()
            .value

        return rows.map { row in
            WeightEntry(
                id: UUID(uuidString: row.id ?? "") ?? UUID(),
                weight: row.weight,
                date: parseDate(row.logged_at),
                note: row.note ?? "",
                supabaseId: row.id
            )
        }
    }

    func logWeight(weight: Double, note: String) async throws -> WeightEntry {
        let userId = try await currentUserId()
        let insert = SupabaseWeightLogInsert(
            user_id: userId,
            weight: weight,
            unit: "lbs",
            note: note.isEmpty ? nil : note
        )

        let result: SupabaseWeightLog = try await supabase
            .from("weight_logs")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        return WeightEntry(
            id: UUID(uuidString: result.id ?? "") ?? UUID(),
            weight: result.weight,
            date: parseDate(result.logged_at),
            note: result.note ?? "",
            supabaseId: result.id
        )
    }

    func deleteWeightLog(id: String) async throws {
        try await supabase
            .from("weight_logs")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Body Measurements

    func fetchMeasurements() async throws -> [BodyMeasurement] {
        let userId = try await currentUserId()
        let rows: [SupabaseBodyMeasurement] = try await supabase
            .from("body_measurements")
            .select()
            .eq("user_id", value: userId)
            .order("measured_at", ascending: true)
            .execute()
            .value

        return rows.map { row in
            BodyMeasurement(
                id: UUID(uuidString: row.id ?? "") ?? UUID(),
                date: parseDate(row.measured_at),
                chest: row.chest,
                waist: row.waist,
                hips: row.hips,
                bicepLeft: row.left_bicep,
                bicepRight: row.right_bicep,
                thighLeft: row.left_thigh,
                thighRight: row.right_thigh,
                neck: row.neck,
                supabaseId: row.id
            )
        }
    }

    func logMeasurement(chest: Double?, waist: Double?, hips: Double?, neck: Double?, bicepLeft: Double?, bicepRight: Double?, thighLeft: Double?, thighRight: Double?) async throws -> BodyMeasurement {
        let userId = try await currentUserId()
        let insert = SupabaseBodyMeasurementInsert(
            user_id: userId,
            chest: chest,
            waist: waist,
            hips: hips,
            neck: neck,
            left_bicep: bicepLeft,
            right_bicep: bicepRight,
            left_thigh: thighLeft,
            right_thigh: thighRight,
            unit: "inches"
        )

        let result: SupabaseBodyMeasurement = try await supabase
            .from("body_measurements")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        return BodyMeasurement(
            id: UUID(uuidString: result.id ?? "") ?? UUID(),
            date: parseDate(result.measured_at),
            chest: result.chest,
            waist: result.waist,
            hips: result.hips,
            bicepLeft: result.left_bicep,
            bicepRight: result.right_bicep,
            thighLeft: result.left_thigh,
            thighRight: result.right_thigh,
            neck: result.neck,
            supabaseId: result.id
        )
    }

    func deleteMeasurement(id: String) async throws {
        try await supabase
            .from("body_measurements")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}

nonisolated enum BodyGoalsServiceError: Error, LocalizedError, Sendable {
    case notAuthenticated
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "You must be signed in to track body goals."
        case .saveFailed: return "Failed to save body goal data."
        }
    }
}
