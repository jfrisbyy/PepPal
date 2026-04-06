import Foundation
import Supabase

nonisolated struct SupabaseDailyTask: Codable, Sendable {
    let id: String?
    let user_id: String
    let title: String
    let description: String?
    let category: String?
    let action_link: String?
    let target_value: Int?
    let goal_description: String?
    let is_completed: Bool?
    let task_date: String?
    let schedule_type: String?
    let scheduled_days: [Int]?
    let icon: String?
    let is_user_created: Bool?
    let custom_category_id: String?
    let created_at: String?
}

nonisolated struct CreateDailyTaskPayload: Codable, Sendable {
    let user_id: String
    let title: String
    let description: String?
    let category: String?
    let action_link: String?
    let target_value: Int?
    let goal_description: String?
    let is_completed: Bool
    let task_date: String
    let schedule_type: String?
    let scheduled_days: [Int]?
    let icon: String?
    let is_user_created: Bool
    let custom_category_id: String?
}

nonisolated struct UpdateDailyTaskPayload: Codable, Sendable {
    let title: String?
    let description: String?
    let category: String?
    let action_link: String?
    let target_value: Int?
    let goal_description: String?
    let is_completed: Bool?
    let schedule_type: String?
    let scheduled_days: [Int]?
    let icon: String?
    let custom_category_id: String?
}

final class DailyTaskService {
    static let shared = DailyTaskService()

    private var supabase: SupabaseClient {
        SupabaseService.shared.client
    }

    private init() {}

    private let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    func fetchTasks(userId: String, date: Date? = nil) async throws -> [SupabaseDailyTask] {
        var query = supabase
            .from("daily_tasks")
            .select()
            .eq("user_id", value: userId)

        if let date {
            query = query.eq("task_date", value: dateOnly.string(from: date))
        }

        let response: [SupabaseDailyTask] = try await query
            .order("created_at", ascending: true)
            .execute()
            .value
        return response
    }

    func createTask(userId: String, task: DailyTask, date: Date) async throws -> SupabaseDailyTask {
        let payload = CreateDailyTaskPayload(
            user_id: userId,
            title: task.name,
            description: nil,
            category: task.category.rawValue,
            action_link: task.actionLink.rawValue,
            target_value: task.actionTarget,
            goal_description: task.goalDescription.isEmpty ? nil : task.goalDescription,
            is_completed: task.isCompleted,
            task_date: dateOnly.string(from: date),
            schedule_type: task.scheduleType.rawValue,
            scheduled_days: task.scheduledDays.map { $0.rawValue },
            icon: task.icon,
            is_user_created: task.isUserCreated,
            custom_category_id: task.customCategoryId?.uuidString
        )

        let created: SupabaseDailyTask = try await supabase
            .from("daily_tasks")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
        return created
    }

    func updateTask(taskId: String, update: UpdateDailyTaskPayload) async throws {
        try await supabase
            .from("daily_tasks")
            .update(update)
            .eq("id", value: taskId)
            .execute()
    }

    func toggleCompletion(taskId: String, isCompleted: Bool) async throws {
        let update = UpdateDailyTaskPayload(
            title: nil, description: nil, category: nil, action_link: nil,
            target_value: nil, goal_description: nil, is_completed: isCompleted,
            schedule_type: nil, scheduled_days: nil, icon: nil, custom_category_id: nil
        )
        try await updateTask(taskId: taskId, update: update)
    }

    func deleteTask(taskId: String) async throws {
        try await supabase
            .from("daily_tasks")
            .delete()
            .eq("id", value: taskId)
            .execute()
    }

    func toDailyTask(_ task: SupabaseDailyTask) -> DailyTask {
        let category = TaskCategory(rawValue: task.category ?? "Custom") ?? .custom
        let actionLink = TaskActionLink(rawValue: task.action_link ?? "None") ?? .none
        let scheduleType = TaskScheduleType(rawValue: task.schedule_type ?? "Daily") ?? .daily
        let scheduledDays: Set<Weekday> = Set((task.scheduled_days ?? []).compactMap { Weekday(rawValue: $0) })

        return DailyTask(
            id: UUID(uuidString: task.id ?? "") ?? UUID(),
            name: task.title,
            icon: task.icon ?? "checkmark.circle",
            category: category,
            customCategoryId: task.custom_category_id.flatMap { UUID(uuidString: $0) },
            isCompleted: task.is_completed ?? false,
            scheduleType: scheduleType,
            scheduledDays: scheduledDays.isEmpty ? Set(Weekday.allCases) : scheduledDays,
            actionLink: actionLink,
            actionTarget: task.target_value ?? 0,
            goalDescription: task.goal_description ?? "",
            isUserCreated: task.is_user_created ?? false
        )
    }
}
