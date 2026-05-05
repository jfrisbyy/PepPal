import Foundation

nonisolated struct FavoriteFood: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let name: String
    let brand: String
    let servingSize: String
    let servingGrams: Double
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let addedAt: Date

    init(from food: FoodItem) {
        self.id = UUID()
        self.name = food.name
        self.brand = food.brand
        self.servingSize = food.servingSize
        self.servingGrams = food.servingGrams
        self.calories = food.calories
        self.protein = food.protein
        self.carbs = food.carbs
        self.fat = food.fat
        self.addedAt = Date()
    }

    var asFoodItem: FoodItem {
        FoodItem(
            name: name,
            brand: brand,
            servingSize: servingSize,
            servingGrams: servingGrams,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            category: .other
        )
    }
}

@Observable
@MainActor
final class FoodFavoritesStore {
    static let shared = FoodFavoritesStore()

    var favorites: [FavoriteFood] = []

    private let key = "com.frisfit.foodFavorites"

    private init() {
        load()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([FavoriteFood].self, from: data) else { return }
        favorites = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(favorites) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func isFavorite(_ food: FoodItem) -> Bool {
        favorites.contains { $0.name == food.name && $0.brand == food.brand }
    }

    func toggle(_ food: FoodItem) {
        if let idx = favorites.firstIndex(where: { $0.name == food.name && $0.brand == food.brand }) {
            favorites.remove(at: idx)
        } else {
            favorites.insert(FavoriteFood(from: food), at: 0)
        }
        persist()
    }

    func remove(_ fav: FavoriteFood) {
        favorites.removeAll { $0.id == fav.id }
        persist()
    }
}
