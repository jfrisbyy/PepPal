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

    private var toolkitBaseURL: String {
        let url = Config.EXPO_PUBLIC_TOOLKIT_URL
        return url.isEmpty ? "https://toolkit.rork.com" : url
    }

    func estimateFromDescription(_ description: String) async throws -> AIEstimationResult {
        let systemPrompt = """
        You are a nutrition estimation AI. The user will describe what they ate. \
        Estimate the calories and macronutrients for each food item. \
        Be as accurate as possible based on typical serving sizes. \
        Respond ONLY with a JSON array of objects with these fields: \
        name (string), amount (string like "1 cup" or "2 slices"), calories (int), protein (double), carbs (double), fat (double). \
        No markdown, no explanation, just the JSON array.
        """

        let messages: [[String: Any]] = [
            ["role": "user", "content": [
                ["type": "text", "text": systemPrompt],
                ["type": "text", "text": "Estimate the nutrition for: \(description)"]
            ]]
        ]

        let body: [String: Any] = ["messages": messages]
        let jsonData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: URL(string: "\(toolkitBaseURL)/agent/chat")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 30

        let (data, _) = try await URLSession.shared.data(for: request)
        return try parseAIResponse(data)
    }

    func estimateFromPhoto(_ imageData: Data) async throws -> (result: AIEstimationResult, overlays: [PhotoFoodOverlay]) {
        let base64 = imageData.base64EncodedString()

        let systemPrompt = """
        You are a nutrition estimation AI analyzing a photo of food. \
        Identify each distinct food item visible in the photo. \
        For each item, estimate calories and macros based on the visible portion size. \
        Respond ONLY with a JSON array of objects with these fields: \
        name (string), amount (string like "1 cup" or "1 piece"), calories (int), protein (double), carbs (double), fat (double), \
        relativeX (double 0-1 horizontal position in image), relativeY (double 0-1 vertical position in image). \
        relativeX and relativeY should approximate where each food item is located in the image. \
        No markdown, no explanation, just the JSON array.
        """

        let messages: [[String: Any]] = [
            ["role": "user", "content": [
                ["type": "text", "text": systemPrompt],
                ["type": "image", "image": base64]
            ]]
        ]

        let body: [String: Any] = ["messages": messages]
        let jsonData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: URL(string: "\(toolkitBaseURL)/agent/chat")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 45

        let (data, _) = try await URLSession.shared.data(for: request)
        return try parsePhotoResponse(data)
    }

    private func parseAIResponse(_ data: Data) throws -> AIEstimationResult {
        let responseText = extractTextFromResponse(data)
        let cleaned = cleanJSONString(responseText)

        if let jsonData = cleaned.data(using: .utf8) {
            let decoder = JSONDecoder()
            if let items = try? decoder.decode([EstimatedFoodItem].self, from: jsonData) {
                return AIEstimationResult(items: items)
            }
        }

        return AIEstimationResult(items: generateFallbackItems())
    }

    private func parsePhotoResponse(_ data: Data) throws -> (result: AIEstimationResult, overlays: [PhotoFoodOverlay]) {
        let responseText = extractTextFromResponse(data)
        let cleaned = cleanJSONString(responseText)

        nonisolated struct PhotoItem: Codable {
            let name: String
            let amount: String
            let calories: Int
            let protein: Double
            let carbs: Double
            let fat: Double
            let relativeX: Double?
            let relativeY: Double?
        }

        if let jsonData = cleaned.data(using: .utf8),
           let photoItems = try? JSONDecoder().decode([PhotoItem].self, from: jsonData) {
            let items = photoItems.map { pi in
                EstimatedFoodItem(name: pi.name, amount: pi.amount, calories: pi.calories, protein: pi.protein, carbs: pi.carbs, fat: pi.fat)
            }
            let overlays = photoItems.enumerated().map { index, pi in
                let count = Double(photoItems.count)
                let defaultX = 0.2 + (0.6 * Double(index) / max(count - 1, 1))
                let defaultY = 0.3 + (0.4 * Double(index) / max(count - 1, 1))
                return PhotoFoodOverlay(
                    item: items[index],
                    relativeX: pi.relativeX ?? defaultX,
                    relativeY: pi.relativeY ?? defaultY
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

    private func extractTextFromResponse(_ data: Data) -> String {
        if let str = String(data: data, encoding: .utf8) {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let text = json["text"] as? String { return text }
                if let result = json["result"] as? String { return result }
                if let choices = json["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String { return content }
            }
            return str
        }
        return "[]"
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

    private func generateFallbackItems() -> [EstimatedFoodItem] {
        [EstimatedFoodItem(name: "Estimated Meal", amount: "1 serving", calories: 450, protein: 25, carbs: 45, fat: 15)]
    }
}
