import SwiftUI
import PhotosUI

nonisolated struct EstimatedFoodItem: Identifiable, Sendable, Codable {
    let id: UUID
    var name: String
    var amount: String
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double

    init(id: UUID = UUID(), name: String, amount: String, calories: Int, protein: Double, carbs: Double, fat: Double) {
        self.id = id
        self.name = name
        self.amount = amount
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }
}

nonisolated struct AIEstimationResult: Sendable {
    let items: [EstimatedFoodItem]
    let totalCalories: Int
    let totalProtein: Double
    let totalCarbs: Double
    let totalFat: Double

    init(items: [EstimatedFoodItem]) {
        self.items = items
        self.totalCalories = items.reduce(0) { $0 + $1.calories }
        self.totalProtein = items.reduce(0) { $0 + $1.protein }
        self.totalCarbs = items.reduce(0) { $0 + $1.carbs }
        self.totalFat = items.reduce(0) { $0 + $1.fat }
    }
}

nonisolated struct PhotoFoodOverlay: Identifiable, Sendable {
    let id: UUID
    let item: EstimatedFoodItem
    let relativeX: Double
    let relativeY: Double

    init(id: UUID = UUID(), item: EstimatedFoodItem, relativeX: Double, relativeY: Double) {
        self.id = id
        self.item = item
        self.relativeX = relativeX
        self.relativeY = relativeY
    }
}

final class NutritionAIService {
    static let shared = NutritionAIService()

    // Text-only nutrition estimation goes to Haiku 4.5 (fast + cheap, w/ Anthropic
    // prompt caching applied by ai-proxy). Vision (photo) calls go to Gemini 3
    // Flash, which is dramatically cheaper than GPT-4o for image understanding.
    private let textModel = "anthropic/claude-haiku-4.5"
    private let visionModel = "google/gemini-3-flash"

    private let systemPrompt = """
    You are a precise nutrition estimation AI used in a fitness tracking app. Your job is to analyze food photos or text descriptions and return accurate calorie and macronutrient estimates.

    RULES:
    - Identify every distinct food item visible in the image or described in the text.
    - Estimate portion sizes using visible context clues: plate diameter (standard dinner plate = 10-11 inches), utensil sizes, cup/bowl sizes, hand/finger references, and food-to-plate ratios.
    - For each item, estimate a realistic serving size in common units (e.g., "1 medium banana", "6 oz chicken breast", "1.5 cups rice").
    - Base all nutritional values on USDA FoodData Central standard entries. Use the most specific match available (e.g., "grilled chicken breast, skinless" not just "chicken").
    - ALWAYS account for cooking fats, oils, butter, and sauces even if not explicitly visible. Most home-cooked and restaurant foods include added fats. Add 1-2 tbsp of cooking oil/butter for pan-fried or sautéed items unless the description specifies otherwise.
    - For restaurant or takeout food, assume restaurant-sized portions which are typically 1.5-2x larger than home portions.
    - When uncertain about portion size, estimate slightly HIGH rather than low. Users tracking calories prefer to overestimate rather than underestimate.
    - Round calories to the nearest 5. Round protein, carbs, and fat to the nearest 0.5g.
    - For each food item, also return a relative X/Y position (0.0 to 1.0) representing where that item is located in the image. If working from a text description, use x: 0.5, y: 0.5 for all items.

    RESPOND WITH ONLY a valid JSON array, no markdown, no explanation, no extra text. Each element must have exactly these fields:
    [
      {
        "name": "string — specific food name",
        "amount": "string — serving size with unit",
        "calories": number,
        "protein": number,
        "carbs": number,
        "fat": number,
        "x": number,
        "y": number
      }
    ]
    """

    func estimateFromDescription(_ description: String) async throws -> AIEstimationResult {
        let messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": "Estimate the nutrition for: \(description)"]
        ]

        // Cache identical text descriptions for 24h to avoid re-billing the model
        // when many users describe the same common foods ("banana", "chipotle
        // chicken bowl", etc.).
        let cacheKey = Self.cacheKey(prefix: "nutrition:desc:v1", payload: description.lowercased())
        let responseText = try await callOpenRouter(
            model: textModel,
            messages: messages,
            maxTokens: 700,
            cacheKey: cacheKey
        )
        return try parseDescriptionResponse(responseText)
    }

    func estimateFromPhoto(_ imageData: Data) async throws -> (result: AIEstimationResult, overlays: [PhotoFoodOverlay]) {
        let optimized = Self.downscaleForVision(imageData) ?? imageData
        let base64 = optimized.base64EncodedString()
        let dataURL = "data:image/jpeg;base64,\(base64)"

        let userContent: [[String: Any]] = [
            ["type": "image_url", "image_url": ["url": dataURL]],
            ["type": "text", "text": "Analyze this food photo and estimate the nutrition for every food item visible."]
        ]

        let messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userContent]
        ]

        // Photo content is unique per user → no response cache. Vision goes through
        // Gemini 3 Flash, which is the cheapest tier capable of this task.
        let responseText = try await callOpenRouter(
            model: visionModel,
            messages: messages,
            maxTokens: 800,
            cacheKey: nil
        )
        return try parsePhotoResponse(responseText)
    }

    /// Downscales a meal photo to a vision-optimal size before sending it to the model.
    /// Vision models internally resize to ~768–1024px tiles, so anything larger just
    /// inflates payload size and token cost without improving accuracy.
    static func downscaleForVision(_ imageData: Data, maxDimension: CGFloat = 1024, quality: CGFloat = 0.7) -> Data? {
        guard let image = UIImage(data: imageData) else { return nil }
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxDimension / longest)
        if scale >= 1 {
            return image.jpegData(compressionQuality: quality)
        }
        let newSize = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }

    private func callOpenRouter(
        model: String,
        messages: [[String: Any]],
        maxTokens: Int = 700,
        cacheKey: String? = nil,
        isRetry: Bool = false
    ) async throws -> String {
        var body: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": maxTokens,
            "temperature": 0.3
        ]
        if let cacheKey {
            body["cache_key"] = cacheKey
            body["cache_ttl_seconds"] = 86_400
        }

        do {
            let data = try await AIProxyClient.postChatCompletion(body: body, timeout: 15, promptId: "nutrition_ai")
            return try AIProxyClient.extractContent(data)
        } catch let AIProxyError.http(code, _) {
            if (code == 429 || (code >= 500 && code < 600)) && !isRetry {
                try await Task.sleep(for: .seconds(2))
                return try await callOpenRouter(
                    model: model,
                    messages: messages,
                    maxTokens: maxTokens,
                    cacheKey: cacheKey,
                    isRetry: true
                )
            }
            throw NutritionAIError.apiError(code)
        } catch {
            throw NutritionAIError.invalidResponse
        }
    }

    /// Build a deterministic, length-bounded cache key the proxy can hash.
    /// Lower-cased + collapsed whitespace so trivial variations still hit cache.
    nonisolated static func cacheKey(prefix: String, payload: String) -> String {
        let normalized = payload
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return "\(prefix)|\(normalized)"
    }

    private func parseDescriptionResponse(_ text: String) throws -> AIEstimationResult {
        let cleaned = cleanJSONString(text)

        nonisolated struct DescriptionItem: Codable {
            let name: String
            let amount: String
            let calories: Int
            let protein: Double
            let carbs: Double
            let fat: Double
            let x: Double?
            let y: Double?
        }

        if let jsonData = cleaned.data(using: .utf8),
           let items = try? JSONDecoder().decode([DescriptionItem].self, from: jsonData) {
            let foodItems = items.map {
                EstimatedFoodItem(name: $0.name, amount: $0.amount, calories: $0.calories, protein: $0.protein, carbs: $0.carbs, fat: $0.fat)
            }
            return AIEstimationResult(items: foodItems)
        }

        return AIEstimationResult(items: generateFallbackItems())
    }

    private func parsePhotoResponse(_ text: String) throws -> (result: AIEstimationResult, overlays: [PhotoFoodOverlay]) {
        let cleaned = cleanJSONString(text)

        nonisolated struct PhotoItem: Codable {
            let name: String
            let amount: String
            let calories: Int
            let protein: Double
            let carbs: Double
            let fat: Double
            let x: Double?
            let y: Double?
        }

        if let jsonData = cleaned.data(using: .utf8),
           let photoItems = try? JSONDecoder().decode([PhotoItem].self, from: jsonData) {
            let items = photoItems.map {
                EstimatedFoodItem(name: $0.name, amount: $0.amount, calories: $0.calories, protein: $0.protein, carbs: $0.carbs, fat: $0.fat)
            }
            let overlays = photoItems.enumerated().map { index, pi in
                let count = Double(photoItems.count)
                let defaultX = 0.2 + (0.6 * Double(index) / max(count - 1, 1))
                let defaultY = 0.3 + (0.4 * Double(index) / max(count - 1, 1))
                return PhotoFoodOverlay(
                    item: items[index],
                    relativeX: pi.x ?? defaultX,
                    relativeY: pi.y ?? defaultY
                )
            }
            return (AIEstimationResult(items: items), overlays)
        }

        let fallbackItems = generateFallbackItems()
        let result = AIEstimationResult(items: fallbackItems)
        let overlays = fallbackItems.enumerated().map { index, item in
            PhotoFoodOverlay(item: item, relativeX: 0.5, relativeY: 0.3 + Double(index) * 0.2)
        }
        return (result, overlays)
    }

    private func cleanJSONString(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        if let startIdx = cleaned.firstIndex(of: "["),
           let endIdx = cleaned.lastIndex(of: "]") {
            cleaned = String(cleaned[startIdx...endIdx])
        }
        return cleaned
    }

    func clarifyItem(originalItem: EstimatedFoodItem, userCorrection: String) async throws -> EstimatedFoodItem {
        let clarifyPrompt = """
        You are a precise nutrition estimation AI. The user scanned a food photo and one item was misidentified or needs correction.

        ORIGINAL DETECTION:
        - Name: \(originalItem.name)
        - Amount: \(originalItem.amount)
        - Calories: \(originalItem.calories)
        - Protein: \(originalItem.protein)g
        - Carbs: \(originalItem.carbs)g
        - Fat: \(originalItem.fat)g

        USER CORRECTION: "\(userCorrection)"

        Based on the user's correction, re-estimate the food item with accurate nutrition values from USDA FoodData Central.
        Keep the same portion size context unless the user specifies a different amount.
        Round calories to the nearest 5. Round protein, carbs, and fat to the nearest 0.5g.

        RESPOND WITH ONLY a valid JSON object (not an array), no markdown, no explanation:
        {
          "name": "corrected food name",
          "amount": "serving size with unit",
          "calories": number,
          "protein": number,
          "carbs": number,
          "fat": number
        }
        """

        let messages: [[String: Any]] = [
            ["role": "system", "content": clarifyPrompt],
            ["role": "user", "content": "Please recalculate nutrition based on my correction."]
        ]

        // Corrections vary per user/item — skip cache; route to Haiku.
        let responseText = try await callOpenRouter(
            model: textModel,
            messages: messages,
            maxTokens: 400,
            cacheKey: nil
        )
        return try parseClarifyResponse(responseText, originalItem: originalItem)
    }

    private func parseClarifyResponse(_ text: String, originalItem: EstimatedFoodItem) throws -> EstimatedFoodItem {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") { cleaned = String(cleaned.dropFirst(7)) }
        else if cleaned.hasPrefix("```") { cleaned = String(cleaned.dropFirst(3)) }
        if cleaned.hasSuffix("```") { cleaned = String(cleaned.dropLast(3)) }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        if let startIdx = cleaned.firstIndex(of: "{"),
           let endIdx = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[startIdx...endIdx])
        }

        nonisolated struct ClarifyItem: Codable {
            let name: String
            let amount: String
            let calories: Int
            let protein: Double
            let carbs: Double
            let fat: Double
        }

        if let jsonData = cleaned.data(using: .utf8),
           let item = try? JSONDecoder().decode(ClarifyItem.self, from: jsonData) {
            return EstimatedFoodItem(
                id: originalItem.id,
                name: item.name,
                amount: item.amount,
                calories: item.calories,
                protein: item.protein,
                carbs: item.carbs,
                fat: item.fat
            )
        }

        return originalItem
    }

    private func generateFallbackItems() -> [EstimatedFoodItem] {
        [EstimatedFoodItem(name: "Estimated Meal", amount: "1 serving", calories: 450, protein: 25, carbs: 45, fat: 15)]
    }
}

nonisolated enum NutritionAIError: Error, Sendable {
    case apiError(Int)
    case invalidResponse
}
