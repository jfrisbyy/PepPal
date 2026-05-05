import Foundation
import Supabase

nonisolated struct SupabaseFoodItem: Codable, Sendable {
    let id: String?
    let user_id: String?
    let name: String
    let brand: String?
    let calories: Int
    let protein_g: Double
    let carbs_g: Double
    let fat_g: Double
    let fiber_g: Double?
    let sugar_g: Double?
    let is_custom: Bool?
    let created_at: String?
}

nonisolated struct SupabaseLoggedMeal: Codable, Sendable {
    let id: String?
    let user_id: String
    let food_item_id: String?
    let food_name: String?
    let food_brand: String?
    let calories: Int?
    let protein_g: Double?
    let carbs_g: Double?
    let fat_g: Double?
    let servings: Double
    let meal_time: String
    let logged_at: String?
    let created_at: String?
}

nonisolated struct CreateFoodItemPayload: Codable, Sendable {
    let user_id: String
    let name: String
    let brand: String?
    let calories: Int
    let protein_g: Double
    let carbs_g: Double
    let fat_g: Double
    let fiber_g: Double?
    let sugar_g: Double?
    let is_custom: Bool
}

nonisolated struct CreateLoggedMealPayload: Codable, Sendable {
    let user_id: String
    let food_item_id: String?
    let food_name: String
    let food_brand: String?
    let calories: Int
    let protein_g: Double
    let carbs_g: Double
    let fat_g: Double
    let servings: Double
    let meal_time: String
    let logged_at: String
}

final class NutritionService {
    static let shared = NutritionService()

    private var supabase: SupabaseClient {
        SupabaseService.shared.client
    }

    private init() {}

    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    func fetchLoggedMealsInRange(userId: String, from startDate: Date, to endDate: Date) async throws -> [SupabaseLoggedMeal] {
        let startStr = iso8601.string(from: startDate)
        let endStr = iso8601.string(from: endDate)

        let response: [SupabaseLoggedMeal] = try await supabase
            .from("logged_meals")
            .select()
            .eq("user_id", value: userId)
            .gte("logged_at", value: startStr)
            .lt("logged_at", value: endStr)
            .order("logged_at", ascending: true)
            .execute()
            .value
        return response
    }

    func fetchLoggedMeals(userId: String, date: Date) async throws -> [SupabaseLoggedMeal] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }

        // Widen the server-side window by 24h on each side to avoid timezone edge cases
        // (Calendar.current uses local time; logged_at is stored in UTC), then filter locally.
        let fetchStart = calendar.date(byAdding: .hour, value: -24, to: startOfDay) ?? startOfDay
        let fetchEnd = calendar.date(byAdding: .hour, value: 24, to: endOfDay) ?? endOfDay

        let startStr = iso8601.string(from: fetchStart)
        let endStr = iso8601.string(from: fetchEnd)

        let response: [SupabaseLoggedMeal] = try await supabase
            .from("logged_meals")
            .select()
            .eq("user_id", value: userId)
            .gte("logged_at", value: startStr)
            .lt("logged_at", value: endStr)
            .order("logged_at", ascending: true)
            .execute()
            .value

        return response.filter { meal in
            guard let loggedStr = meal.logged_at,
                  let logged = iso8601.date(from: loggedStr) else { return true }
            return logged >= startOfDay && logged < endOfDay
        }
    }

    func logMeal(userId: String, food: FoodItem, servings: Double, mealTime: MealTime, loggedAt: Date = Date()) async throws -> SupabaseLoggedMeal {
        let payload = CreateLoggedMealPayload(
            user_id: userId,
            food_item_id: nil,
            food_name: food.name,
            food_brand: food.brand,
            calories: food.calories,
            protein_g: food.protein,
            carbs_g: food.carbs,
            fat_g: food.fat,
            servings: servings,
            meal_time: mealTime.rawValue.lowercased(),
            logged_at: iso8601.string(from: loggedAt)
        )

        let created: SupabaseLoggedMeal = try await supabase
            .from("logged_meals")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
        return created
    }

    nonisolated func mealInsertPayload(userId: String, food: FoodItem, servings: Double, mealTime: MealTime, loggedAt: Date, clientMutationId: String = UUID().uuidString) -> [String: JSONPrimitive] {
        return [
            "user_id": .string(userId),
            "food_name": .string(food.name),
            "food_brand": food.brand.isEmpty ? .null : .string(food.brand),
            "calories": .int(Int(Double(food.calories) * servings)),
            "protein_g": .double(food.protein * servings),
            "carbs_g": .double(food.carbs * servings),
            "fat_g": .double(food.fat * servings),
            "servings": .double(servings),
            "meal_time": .string(mealTime.rawValue.lowercased()),
            "logged_at": .string(iso8601.string(from: loggedAt)),
            "client_mutation_id": .string(clientMutationId)
        ]
    }

    func deleteMeal(mealId: String) async throws {
        try await supabase
            .from("logged_meals")
            .delete()
            .eq("id", value: mealId)
            .execute()
    }

    func createCustomFood(userId: String, food: FoodItem) async throws -> SupabaseFoodItem {
        let payload = CreateFoodItemPayload(
            user_id: userId,
            name: food.name,
            brand: food.brand,
            calories: food.calories,
            protein_g: food.protein,
            carbs_g: food.carbs,
            fat_g: food.fat,
            fiber_g: nil,
            sugar_g: nil,
            is_custom: true
        )

        let created: SupabaseFoodItem = try await supabase
            .from("food_items")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
        return created
    }

    func fetchCustomFoods(userId: String) async throws -> [SupabaseFoodItem] {
        let response: [SupabaseFoodItem] = try await supabase
            .from("food_items")
            .select()
            .eq("user_id", value: userId)
            .eq("is_custom", value: true)
            .order("created_at", ascending: false)
            .execute()
            .value
        return response
    }

    func toFoodItem(_ item: SupabaseFoodItem) -> FoodItem {
        FoodItem(
            id: UUID(uuidString: item.id ?? "") ?? UUID(),
            name: item.name,
            brand: item.brand ?? "",
            calories: item.calories,
            protein: item.protein_g,
            carbs: item.carbs_g,
            fat: item.fat_g
        )
    }

    func toLoggedMeal(_ meal: SupabaseLoggedMeal) -> LoggedMeal {
        let food = FoodItem(
            name: meal.food_name ?? "Unknown",
            brand: meal.food_brand ?? "",
            calories: meal.calories ?? 0,
            protein: meal.protein_g ?? 0,
            carbs: meal.carbs_g ?? 0,
            fat: meal.fat_g ?? 0
        )
        let mealTime = MealTime(rawValue: meal.meal_time.capitalized) ?? MealTime(rawValue: meal.meal_time) ?? .snacks
        let timestamp: Date
        if let dateStr = meal.logged_at {
            timestamp = iso8601.date(from: dateStr) ?? Date()
        } else {
            timestamp = Date()
        }
        return LoggedMeal(
            id: UUID(uuidString: meal.id ?? "") ?? UUID(),
            food: food,
            servings: meal.servings,
            mealTime: mealTime,
            timestamp: timestamp
        )
    }
}
