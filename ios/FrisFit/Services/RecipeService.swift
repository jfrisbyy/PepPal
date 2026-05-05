import Foundation
import Supabase

nonisolated struct SupabaseRecipe: Codable, Sendable {
    let id: String?
    let user_id: String?
    let name: String
    let portions: Int
    let ingredients_json: String
    let created_at: String?
}

nonisolated struct CreateRecipePayload: Codable, Sendable {
    let user_id: String
    let name: String
    let portions: Int
    let ingredients_json: String
}

final class RecipeService {
    static let shared = RecipeService()
    private var supabase: SupabaseClient { SupabaseService.shared.client }
    private init() {}

    func fetch(userId: String) async throws -> [Recipe] {
        let rows: [SupabaseRecipe] = try await supabase
            .from("recipes")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows.compactMap { Self.decode($0) }
    }

    func create(userId: String, recipe: Recipe) async throws -> Recipe {
        let data = try JSONEncoder().encode(recipe.ingredients)
        let json = String(data: data, encoding: .utf8) ?? "[]"
        let payload = CreateRecipePayload(
            user_id: userId,
            name: recipe.name,
            portions: recipe.portions,
            ingredients_json: json
        )
        let created: SupabaseRecipe = try await supabase
            .from("recipes")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
        return Self.decode(created) ?? recipe
    }

    func delete(id: String) async throws {
        try await supabase.from("recipes").delete().eq("id", value: id).execute()
    }

    nonisolated static func decode(_ row: SupabaseRecipe) -> Recipe? {
        let data = row.ingredients_json.data(using: .utf8) ?? Data()
        let ings = (try? JSONDecoder().decode([RecipeIngredient].self, from: data)) ?? []
        let created: Date
        if let s = row.created_at, let d = ISO8601DateFormatter.shared.date(from: s) {
            created = d
        } else {
            created = Date()
        }
        return Recipe(
            id: UUID(uuidString: row.id ?? "") ?? UUID(),
            name: row.name,
            portions: row.portions,
            ingredients: ings,
            createdAt: created
        )
    }
}
