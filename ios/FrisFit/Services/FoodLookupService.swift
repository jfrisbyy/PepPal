import Foundation

nonisolated struct OFFResponse: Codable, Sendable {
    let status: Int
    let product: OFFProduct?
}

nonisolated struct OFFProduct: Codable, Sendable {
    let product_name: String?
    let brands: String?
    let serving_size: String?
    let nutriments: OFFNutriments?
}

nonisolated struct OFFNutriments: Codable, Sendable {
    let energy_kcal_serving: Double?
    let energy_kcal_100g: Double?
    let proteins_serving: Double?
    let proteins_100g: Double?
    let carbohydrates_serving: Double?
    let carbohydrates_100g: Double?
    let fat_serving: Double?
    let fat_100g: Double?

    enum CodingKeys: String, CodingKey {
        case energy_kcal_serving = "energy-kcal_serving"
        case energy_kcal_100g = "energy-kcal_100g"
        case proteins_serving = "proteins_serving"
        case proteins_100g = "proteins_100g"
        case carbohydrates_serving = "carbohydrates_serving"
        case carbohydrates_100g = "carbohydrates_100g"
        case fat_serving = "fat_serving"
        case fat_100g = "fat_100g"
    }
}

nonisolated enum FoodLookupError: Error, LocalizedError, Sendable {
    case notFound
    case network(String)

    var errorDescription: String? {
        switch self {
        case .notFound: return "Product not found in database"
        case .network(let msg): return "Network error: \(msg)"
        }
    }
}

nonisolated final class FoodLookupService: Sendable {
    static let shared = FoodLookupService()

    func lookup(barcode: String) async throws -> FoodItem {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(trimmed).json?fields=product_name,brands,serving_size,nutriments") else {
            throw FoodLookupError.notFound
        }
        var req = URLRequest(url: url)
        req.setValue("FrisFit iOS (contact@frisfit.app)", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 10

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let resp = try JSONDecoder().decode(OFFResponse.self, from: data)
            guard resp.status == 1, let p = resp.product else {
                throw FoodLookupError.notFound
            }
            let name = p.product_name?.trimmingCharacters(in: .whitespaces) ?? "Unknown Product"
            let brand = p.brands?.split(separator: ",").first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""
            let serving = p.serving_size ?? "1 serving"

            let n = p.nutriments
            let calories = Int(n?.energy_kcal_serving ?? n?.energy_kcal_100g ?? 0)
            let protein = n?.proteins_serving ?? n?.proteins_100g ?? 0
            let carbs = n?.carbohydrates_serving ?? n?.carbohydrates_100g ?? 0
            let fat = n?.fat_serving ?? n?.fat_100g ?? 0

            return FoodItem(
                name: name.isEmpty ? "Product \(trimmed)" : name,
                brand: brand,
                servingSize: serving,
                servingGrams: 0,
                calories: max(calories, 0),
                protein: max(protein, 0),
                carbs: max(carbs, 0),
                fat: max(fat, 0),
                category: .other
            )
        } catch let e as FoodLookupError {
            throw e
        } catch {
            throw FoodLookupError.network(error.localizedDescription)
        }
    }
}
