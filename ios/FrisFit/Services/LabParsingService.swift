import Foundation

nonisolated struct ParsedBiomarkerResult: Codable, Sendable {
    let name: String
    let value: Double
    let unit: String
}

final class LabParsingService {
    static let shared = LabParsingService()

    private let openRouterURL = "https://openrouter.ai/api/v1/chat/completions"
    private let model = "openai/gpt-4o"

    private var apiKey: String {
        Config.EXPO_PUBLIC_OPENROUTER_API_KEY
    }

    private let systemPrompt = """
    You are a medical lab results parser. Your job is to extract biomarker values from lab report images or documents.

    You must identify and extract ONLY the following biomarkers if present in the results. Use these exact names:
    - IGF-1 (unit: ng/mL)
    - Testosterone (Total) (unit: ng/dL)
    - Testosterone (Free) (unit: pg/mL)
    - A1C (unit: %)
    - Fasting Glucose (unit: mg/dL)
    - Fasting Insulin (unit: µIU/mL)
    - AST (unit: U/L)
    - ALT (unit: U/L)
    - Total Cholesterol (unit: mg/dL)
    - HDL (unit: mg/dL)
    - LDL (unit: mg/dL)
    - Triglycerides (unit: mg/dL)
    - TSH (unit: mIU/L)
    - T3 (unit: pg/mL)
    - T4 (unit: ng/dL)
    - Creatinine (unit: mg/dL)
    - BUN (unit: mg/dL)

    RULES:
    - Only extract biomarkers from the list above.
    - Match lab report names to the closest biomarker above. For example: "Free T4" maps to "T4", "Hemoglobin A1c" maps to "A1C", "Glucose, Fasting" maps to "Fasting Glucose", "eGFR" should be ignored (not in list).
    - Return the numeric value as a number, not a string.
    - If a biomarker has a "<" or ">" prefix, use the number after it.
    - Ignore any biomarkers not in the list above.
    - If you cannot read or find any recognized biomarkers, return an empty array.

    RESPOND WITH ONLY a valid JSON array, no markdown, no explanation:
    [
      { "name": "exact biomarker name from list", "value": number, "unit": "unit string" }
    ]
    """

    func parseLabImage(_ imageData: Data) async throws -> [BiomarkerResult] {
        let base64 = imageData.base64EncodedString()
        let dataURL = "data:image/jpeg;base64,\(base64)"

        let userContent: [[String: Any]] = [
            ["type": "image_url", "image_url": ["url": dataURL]],
            ["type": "text", "text": "Extract all recognized biomarker values from this lab report image."]
        ]

        let messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userContent]
        ]

        let responseText = try await callOpenRouter(messages: messages)
        return parseResponse(responseText)
    }

    private func callOpenRouter(messages: [[String: Any]], isRetry: Bool = false) async throws -> String {
        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": 2000,
            "temperature": 0.1
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: URL(string: openRouterURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(Bundle.main.bundleIdentifier ?? "com.peppal.app", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("PepPal", forHTTPHeaderField: "X-Title")
        request.httpBody = jsonData
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            if (httpResponse.statusCode == 429 || httpResponse.statusCode >= 500) && !isRetry {
                try await Task.sleep(for: .seconds(2))
                return try await callOpenRouter(messages: messages, isRetry: true)
            }
            guard httpResponse.statusCode == 200 else {
                throw LabParsingError.apiError(httpResponse.statusCode)
            }
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LabParsingError.invalidResponse
        }

        return content
    }

    private func parseResponse(_ text: String) -> [BiomarkerResult] {
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

        guard let jsonData = cleaned.data(using: .utf8),
              let parsed = try? JSONDecoder().decode([ParsedBiomarkerResult].self, from: jsonData) else {
            return []
        }

        return parsed.compactMap { item in
            guard let biomarker = Biomarker(rawValue: item.name) else { return nil }
            guard item.value > 0 else { return nil }
            return BiomarkerResult(biomarker: biomarker, value: item.value)
        }
    }
}

nonisolated enum LabParsingError: Error, LocalizedError, Sendable {
    case apiError(Int)
    case invalidResponse
    case noResults

    var errorDescription: String? {
        switch self {
        case .apiError(let code): return "AI service error (code \(code)). Please try again."
        case .invalidResponse: return "Could not process the response. Please try again."
        case .noResults: return "No recognized biomarkers found. Try a clearer image."
        }
    }
}
