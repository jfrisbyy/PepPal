import Foundation

nonisolated struct SavedMeal: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let createdAt: Date

    init(id: UUID = UUID(), name: String, calories: Int, protein: Double, carbs: Double, fat: Double, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.createdAt = createdAt
    }
}
