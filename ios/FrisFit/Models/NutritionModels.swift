import SwiftUI

nonisolated enum MealTime: String, CaseIterable, Identifiable, Sendable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snacks = "Snacks"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .breakfast: "sunrise.fill"
        case .lunch: "sun.max.fill"
        case .dinner: "moon.stars.fill"
        case .snacks: "leaf.fill"
        }
    }

    var color: Color {
        switch self {
        case .breakfast: Color.orange
        case .lunch: Color(red: 0, green: 229/255, blue: 255/255)
        case .dinner: Color(red: 139/255, green: 92/255, blue: 246/255)
        case .snacks: Color.green
        }
    }
}

nonisolated struct FoodItem: Identifiable, Sendable {
    let id: UUID
    let name: String
    let brand: String
    let servingSize: String
    let servingGrams: Double
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let category: FoodCategory

    init(id: UUID = UUID(), name: String, brand: String = "", servingSize: String = "1 serving", servingGrams: Double = 100, calories: Int, protein: Double, carbs: Double, fat: Double, category: FoodCategory = .other) {
        self.id = id
        self.name = name
        self.brand = brand
        self.servingSize = servingSize
        self.servingGrams = servingGrams
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.category = category
    }
}

nonisolated enum FoodCategory: String, CaseIterable, Sendable {
    case protein = "Protein"
    case dairy = "Dairy"
    case grains = "Grains"
    case fruits = "Fruits"
    case vegetables = "Vegetables"
    case fats = "Fats & Oils"
    case beverages = "Beverages"
    case snacks = "Snacks"
    case prepared = "Prepared Foods"
    case other = "Other"
}

nonisolated struct LoggedMeal: Identifiable, Sendable {
    let id: UUID
    let food: FoodItem
    let servings: Double
    let mealTime: MealTime
    let timestamp: Date

    init(id: UUID = UUID(), food: FoodItem, servings: Double = 1.0, mealTime: MealTime, timestamp: Date = Date()) {
        self.id = id
        self.food = food
        self.servings = servings
        self.mealTime = mealTime
        self.timestamp = timestamp
    }

    var totalCalories: Int { Int(Double(food.calories) * servings) }
    var totalProtein: Double { food.protein * servings }
    var totalCarbs: Double { food.carbs * servings }
    var totalFat: Double { food.fat * servings }
}

nonisolated struct MacroTarget: Sendable {
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
}

nonisolated enum AdherenceStatus: Sendable {
    case onTrack
    case overTarget
    case underTarget

    var label: String {
        switch self {
        case .onTrack: "On Track"
        case .overTarget: "Over Target"
        case .underTarget: "Under Target"
        }
    }

    var color: Color {
        switch self {
        case .onTrack: .green
        case .overTarget: Color(red: 255/255, green: 59/255, blue: 48/255)
        case .underTarget: Color(red: 255/255, green: 184/255, blue: 0)
        }
    }

    var icon: String {
        switch self {
        case .onTrack: "checkmark.circle.fill"
        case .overTarget: "arrow.up.circle.fill"
        case .underTarget: "arrow.down.circle.fill"
        }
    }
}
