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
        let body: [String: Any] = [
            "model": tier.modelID,
            "messages": messages,
            "max_tokens": maxTokens,
            "temperature": temperature
        ]
        do {
            let data = try await AIProxyClient.postChatCompletion(body: body, timeout: timeout)
            return try AIProxyClient.extractContent(data)
        } catch let AIProxyError.http(code, _) {
            throw OpenRouterError.apiError(code)
        } catch AIProxyError.notConfigured, AIProxyError.notAuthenticated {
            throw OpenRouterError.invalidConfig
        } catch AIProxyError.invalidResponse {
            throw OpenRouterError.invalidResponse
        }
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
