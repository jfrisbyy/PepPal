import Foundation
import Supabase
import Auth

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

    init(
        id: UUID,
        name: String,
        brand: String,
        servingSize: String,
        servingGrams: Double,
        calories: Int,
        protein: Double,
        carbs: Double,
        fat: Double,
        addedAt: Date
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.servingSize = servingSize
        self.servingGrams = servingGrams
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.addedAt = addedAt
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

    /// Legacy global UserDefaults key — read once on first launch after the
    /// disk migration ships, then the value is rewritten under the per-user
    /// disk folder and the original key is removed.
    private let legacyKey = "com.frisfit.foodFavorites"
    private static let diskFile = "foodFavorites.v1"
    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private init() {
        load()
        Task { await self.hydrateFromSupabase() }
    }

    private func currentUserId() -> String {
        ((try? AuthService.shared.currentUserId()) ?? "").lowercased()
    }

    private func load() {
        let uid = currentUserId()
        if !uid.isEmpty,
           let decoded = PerUserDiskStore.load([FavoriteFood].self, userId: uid, name: Self.diskFile) {
            favorites = decoded
            return
        }
        // Legacy migration: pull the old global UserDefaults blob forward to
        // the per-user disk folder once, then drop it.
        if let data = UserDefaults.standard.data(forKey: legacyKey),
           let decoded = try? JSONDecoder().decode([FavoriteFood].self, from: data) {
            favorites = decoded
            persist()
            UserDefaults.standard.removeObject(forKey: legacyKey)
        }
    }

    private func persist() {
        let uid = currentUserId()
        guard !uid.isEmpty else { return }
        PerUserDiskStore.save(favorites, userId: uid, name: Self.diskFile)
    }

    func isFavorite(_ food: FoodItem) -> Bool {
        favorites.contains { $0.name == food.name && $0.brand == food.brand }
    }

    func toggle(_ food: FoodItem) {
        if let idx = favorites.firstIndex(where: { $0.name == food.name && $0.brand == food.brand }) {
            let removed = favorites.remove(at: idx)
            persist()
            Task.detached { await PersistenceSyncService.shared.deleteFoodFavorite(id: removed.id.uuidString.lowercased()) }
        } else {
            let fav = FavoriteFood(from: food)
            favorites.insert(fav, at: 0)
            persist()
            Task.detached { await PersistenceSyncService.shared.upsertFoodFavorite(self.dto(from: fav)) }
        }
    }

    func remove(_ fav: FavoriteFood) {
        favorites.removeAll { $0.id == fav.id }
        persist()
        Task.detached { await PersistenceSyncService.shared.deleteFoodFavorite(id: fav.id.uuidString.lowercased()) }
    }

    private func dto(from fav: FavoriteFood) -> FoodFavoriteRow {
        guard let session = try? SupabaseService.shared.client.auth.currentSession else {
            return FoodFavoriteRow(
                id: fav.id.uuidString.lowercased(),
                user_id: "",
                name: fav.name,
                brand: fav.brand,
                serving_size: fav.servingSize,
                serving_grams: fav.servingGrams,
                calories: fav.calories,
                protein: fav.protein,
                carbs: fav.carbs,
                fat: fav.fat,
                added_at: Self.iso.string(from: fav.addedAt)
            )
        }
        return FoodFavoriteRow(
            id: fav.id.uuidString.lowercased(),
            user_id: session.user.id.uuidString.lowercased(),
            name: fav.name,
            brand: fav.brand,
            serving_size: fav.servingSize,
            serving_grams: fav.servingGrams,
            calories: fav.calories,
            protein: fav.protein,
            carbs: fav.carbs,
            fat: fav.fat,
            added_at: Self.iso.string(from: fav.addedAt)
        )
    }

    func hydrateFromSupabase() async {
        let rows = await PersistenceSyncService.shared.fetchFoodFavorites()
        guard !rows.isEmpty else {
            for fav in favorites {
                await PersistenceSyncService.shared.upsertFoodFavorite(dto(from: fav))
            }
            return
        }
        var byKey: [String: FavoriteFood] = [:]
        for fav in favorites { byKey["\(fav.name)|\(fav.brand)"] = fav }
        for row in rows {
            let id = UUID(uuidString: row.id) ?? UUID()
            let fav = FavoriteFood(
                id: id,
                name: row.name,
                brand: row.brand,
                servingSize: row.serving_size,
                servingGrams: row.serving_grams,
                calories: row.calories,
                protein: row.protein,
                carbs: row.carbs,
                fat: row.fat,
                addedAt: row.added_at.flatMap { Self.iso.date(from: $0) } ?? Date()
            )
            byKey["\(fav.name)|\(fav.brand)"] = fav
        }
        favorites = byKey.values.sorted { $0.addedAt > $1.addedAt }
        persist()
    }
}
