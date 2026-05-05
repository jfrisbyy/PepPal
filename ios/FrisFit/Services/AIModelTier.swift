import Foundation

/// Centralized model selection so the app can route routine tasks to a fast,
/// cheap model and reserve Sonnet 4.6 for deep investigations.
nonisolated enum AIModelTier: String, Sendable {
    /// Cheap, fast — routine module regen, quick chat, deck additions.
    case fast
    /// Smart, deliberate — Morning Brief, weekly investigations, correlations,
    /// bloodwork interpretation, adaptive recalibration.
    case deep

    var modelID: String {
        switch self {
        case .fast: return "anthropic/claude-haiku-4.5"
        case .deep: return "anthropic/claude-sonnet-4.6"
        }
    }
}

/// Shared OpenRouter client so every AI service uses the same headers,
/// timeouts, and tiering rules. Kept minimal; each caller owns its prompt.
nonisolated final class OpenRouterClient: Sendable {
    static let shared = OpenRouterClient()
    private let endpoint = "https://openrouter.ai/api/v1/chat/completions"

    private init() {}

    func chat(
        tier: AIModelTier,
        systemPrompt: String,
        userPrompt: String,
        maxTokens: Int = 1200,
        temperature: Double = 0.5,
        timeout: TimeInterval = 30
    ) async throws -> String {
        let messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userPrompt]
        ]
        return try await chatRaw(
            tier: tier,
            messages: messages,
            maxTokens: maxTokens,
            temperature: temperature,
            timeout: timeout
        )
    }

    func chatRaw(
        tier: AIModelTier,
        messages: [[String: Any]],
        maxTokens: Int = 1200,
        temperature: Double = 0.5,
        timeout: TimeInterval = 30
    ) async throws -> String {
        let apiKey = Config.EXPO_PUBLIC_OPENROUTER_API_KEY
        guard !apiKey.isEmpty, let url = URL(string: endpoint) else {
            throw OpenRouterError.invalidConfig
        }

        let body: [String: Any] = [
            "model": tier.modelID,
            "messages": messages,
            "max_tokens": maxTokens,
            "temperature": temperature
        ]
        let data = try JSONSerialization.data(withJSONObject: body)

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue(Bundle.main.bundleIdentifier ?? "com.peppal.app", forHTTPHeaderField: "HTTP-Referer")
        req.setValue("EPTI", forHTTPHeaderField: "X-Title")
        req.httpBody = data
        req.timeoutInterval = timeout

        let (respData, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
            let text = String(data: respData, encoding: .utf8) ?? ""
            print("[OpenRouter/\(tier.rawValue)] \(http.statusCode): \(text.prefix(400))")
            throw OpenRouterError.apiError(http.statusCode)
        }

        guard
            let json = try JSONSerialization.jsonObject(with: respData) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw OpenRouterError.invalidResponse
        }
        return content
    }

    /// Strip common wrappers (```json, ```) and isolate the outer JSON object
    /// before decoding. Saves every caller from rewriting the same cleanup.
    static func extractJSON(_ raw: String) -> String {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") { cleaned = String(cleaned.dropFirst(7)) }
        else if cleaned.hasPrefix("```") { cleaned = String(cleaned.dropFirst(3)) }
        if cleaned.hasSuffix("```") { cleaned = String(cleaned.dropLast(3)) }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = cleaned.firstIndex(of: "{"),
           let end = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[start...end])
        }
        return cleaned
    }
}

nonisolated enum OpenRouterError: Error, Sendable {
    case invalidConfig
    case apiError(Int)
    case invalidResponse
}
