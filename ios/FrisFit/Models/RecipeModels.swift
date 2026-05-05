import Foundation

nonisolated struct RecipeIngredient: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    var name: String
    var brand: String
    var servings: Double
    var servingSize: String
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double

    init(
        id: UUID = UUID(),
        name: String,
        brand: String = "",
        servings: Double = 1.0,
        servingSize: String = "1 serving",
        calories: Int,
        protein: Double,
        carbs: Double,
        fat: Double
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.servings = servings
        self.servingSize = servingSize
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }

    var totalCalories: Int { Int(Double(calories) * servings) }
    var totalProtein: Double { protein * servings }
    var totalCarbs: Double { carbs * servings }
    var totalFat: Double { fat * servings }

    static func from(_ food: FoodItem, servings: Double = 1.0) -> RecipeIngredient {
        RecipeIngredient(
            name: food.name,
            brand: food.brand,
            servings: servings,
            servingSize: food.servingSize,
            calories: food.calories,
            protein: food.protein,
            carbs: food.carbs,
            fat: food.fat
        )
    }
}

nonisolated struct Recipe: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var portions: Int
    var ingredients: [RecipeIngredient]
    let createdAt: Date

    init(id: UUID = UUID(), name: String, portions: Int = 1, ingredients: [RecipeIngredient] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.portions = max(1, portions)
        self.ingredients = ingredients
        self.createdAt = createdAt
    }

    var totalCalories: Int { ingredients.reduce(0) { $0 + $1.totalCalories } }
    var totalProtein: Double { ingredients.reduce(0) { $0 + $1.totalProtein } }
    var totalCarbs: Double { ingredients.reduce(0) { $0 + $1.totalCarbs } }
    var totalFat: Double { ingredients.reduce(0) { $0 + $1.totalFat } }

    var caloriesPerPortion: Int { totalCalories / max(portions, 1) }
    var proteinPerPortion: Double { totalProtein / Double(max(portions, 1)) }
    var carbsPerPortion: Double { totalCarbs / Double(max(portions, 1)) }
    var fatPerPortion: Double { totalFat / Double(max(portions, 1)) }

    func asFoodItem(portions portionsToLog: Double = 1.0) -> FoodItem {
        FoodItem(
            name: name,
            brand: "Recipe",
            servingSize: "1 portion",
            servingGrams: 0,
            calories: caloriesPerPortion,
            protein: proteinPerPortion,
            carbs: carbsPerPortion,
            fat: fatPerPortion,
            category: .prepared
        )
    }
}
