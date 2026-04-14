import Foundation
import Supabase

nonisolated struct EnergyActivityLog: Codable, Sendable {
    let id: String?
    let user_id: String
    let activity_date: String
    let activity_type: String
    let sport: String?
    let duration_minutes: Int?
    let calories_burned: Int?
    let notes: String?
    let created_at: String?
}

nonisolated struct CreateEnergyActivityPayload: Codable, Sendable {
    let user_id: String
    let activity_date: String
    let activity_type: String
    let sport: String?
    let duration_minutes: Int?
    let calories_burned: Int?
    let notes: String?
}

final class ActivityLogService {
    static let shared = ActivityLogService()

    private var supabase: SupabaseClient {
        SupabaseService.shared.client
    }

    private let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private init() {}

    func logActivity(
        userId: String,
        activityType: String,
        sport: String?,
        durationMinutes: Int,
        caloriesBurned: Int,
        metValue: Double?,
        notes: String? = nil
    ) async throws {
        let payload = CreateEnergyActivityPayload(
            user_id: userId,
            activity_date: dateOnly.string(from: Date()),
            activity_type: activityType,
            sport: sport,
            duration_minutes: durationMinutes,
            calories_burned: caloriesBurned,
            notes: notes
        )

        try await supabase
            .from("activity_logs")
            .insert(payload)
            .execute()
    }

    func fetchTodayActivities(userId: String) async throws -> [EnergyActivityLog] {
        let todayStr = dateOnly.string(from: Date())

        let rows: [EnergyActivityLog] = try await supabase
            .from("activity_logs")
            .select()
            .eq("user_id", value: userId)
            .eq("activity_date", value: todayStr)
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows
    }

    func fetchWeekActivities(userId: String) async throws -> [EnergyActivityLog] {
        let calendar = Calendar.current
        let weekStart = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let startStr = dateOnly.string(from: weekStart)

        let rows: [EnergyActivityLog] = try await supabase
            .from("activity_logs")
            .select()
            .eq("user_id", value: userId)
            .gte("activity_date", value: startStr)
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows
    }

    func deleteActivity(id: String) async throws {
        try await supabase
            .from("activity_logs")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func todayCaloriesBurned(userId: String) async throws -> (calories: Int, count: Int) {
        let today = try await fetchTodayActivities(userId: userId)
        let workouts = try await WorkoutService.shared.fetchWorkouts(userId: userId, limit: 20)
        let todayStr = dateOnly.string(from: Date())
        let todayWorkouts = workouts.filter { $0.date == todayStr }
        let workoutCals = todayWorkouts.reduce(0) { $0 + ($1.calories_burned ?? 0) }
        let manualCals = today.filter { $0.activity_type == "manual" }.reduce(0) { $0 + ($1.calories_burned ?? 0) }
        let totalCals = workoutCals + manualCals
        let count = todayWorkouts.count + today.filter { $0.activity_type == "manual" }.count
        return (totalCals, count)
    }

    func fetchDailyCalories(userId: String, days: Int = 7) async throws -> [(date: String, calories: Int)] {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: Date()) ?? Date()
        let startStr = dateOnly.string(from: start)

        let rows: [EnergyActivityLog] = try await supabase
            .from("activity_logs")
            .select()
            .eq("user_id", value: userId)
            .gte("activity_date", value: startStr)
            .order("activity_date", ascending: true)
            .execute()
            .value

        var dailyMap: [String: Int] = [:]
        for i in 0..<days {
            if let d = calendar.date(byAdding: .day, value: i - (days - 1), to: Date()) {
                dailyMap[dateOnly.string(from: d)] = 0
            }
        }

        for row in rows where row.activity_type == "manual" {
            dailyMap[row.activity_date, default: 0] += row.calories_burned ?? 0
        }

        let workouts = try await WorkoutService.shared.fetchWorkouts(userId: userId, limit: 50)
        for w in workouts {
            if let d = w.date, dailyMap.keys.contains(d) {
                dailyMap[d, default: 0] += w.calories_burned ?? 0
            }
        }

        return dailyMap.sorted { $0.key < $1.key }.map { (date: $0.key, calories: $0.value) }
    }
}
