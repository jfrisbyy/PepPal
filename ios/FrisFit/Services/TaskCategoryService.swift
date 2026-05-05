import Foundation
import Supabase

nonisolated struct SupabaseTaskCategory: Codable, Sendable {
    let id: String?
    let user_id: String?
    let client_id: String
    let name: String
    let color_hex: String?
    let icon: String?
    let sort_order: Int
    let created_at: String?
}

nonisolated struct SupabaseTaskCategoryUpsert: Codable, Sendable {
    let user_id: String
    let client_id: String
    let name: String
    let color_hex: String?
    let icon: String?
    let sort_order: Int
}

nonisolated struct TaskCategoryRecord: Identifiable, Sendable, Hashable {
    let id: UUID
    var name: String
    var colorHex: String?
    var icon: String?
    var sortOrder: Int
}

final class TaskCategoryService {
    static let shared = TaskCategoryService()
    private init() {}

    private var supabase: SupabaseClient { SupabaseService.shared.client }

    private func userId() async -> String? {
        guard let session = try? await supabase.auth.session else { return nil }
        return session.user.id.uuidString.lowercased()
    }

    func fetchAll() async -> [TaskCategoryRecord] {
        guard let uid = await userId() else { return [] }
        do {
            let rows: [SupabaseTaskCategory] = try await supabase
                .from("task_categories")
                .select()
                .eq("user_id", value: uid)
                .order("sort_order", ascending: true)
                .execute()
                .value
            return rows.map {
                TaskCategoryRecord(
                    id: UUID(uuidString: $0.client_id) ?? UUID(),
                    name: $0.name,
                    colorHex: $0.color_hex,
                    icon: $0.icon,
                    sortOrder: $0.sort_order
                )
            }
        } catch {
            print("[TaskCategoryService] fetch error: \(error)")
            return []
        }
    }

    func upsert(_ category: TaskCategoryRecord) async {
        guard let uid = await userId() else { return }
        let payload = SupabaseTaskCategoryUpsert(
            user_id: uid,
            client_id: category.id.uuidString.lowercased(),
            name: category.name,
            color_hex: category.colorHex,
            icon: category.icon,
            sort_order: category.sortOrder
        )
        do {
            try await supabase
                .from("task_categories")
                .upsert(payload, onConflict: "user_id,client_id")
                .execute()
        } catch {
            print("[TaskCategoryService] upsert error: \(error)")
        }
    }

    func delete(clientId: UUID) async {
        guard let uid = await userId() else { return }
        do {
            try await supabase
                .from("task_categories")
                .delete()
                .eq("user_id", value: uid)
                .eq("client_id", value: clientId.uuidString.lowercased())
                .execute()
        } catch {
            print("[TaskCategoryService] delete error: \(error)")
        }
    }
}
