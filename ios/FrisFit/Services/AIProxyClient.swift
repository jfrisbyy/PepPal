import Foundation
import Supabase
import Auth

/// Builds authenticated requests to the `ai-proxy` Supabase edge function so
/// no OpenRouter API key ever ships in the iOS bundle. Every AI call site
/// goes through `request(body:timeout:)` instead of hitting OpenRouter directly.
nonisolated enum AIProxyError: Error, Sendable {
    case notConfigured
    case notAuthenticated
    case http(Int, String)
    case invalidResponse
}

enum AIProxyClient {
    /// Sends a chat-completion-style JSON body to the proxy and returns the raw
    /// upstream response data. The body shape mirrors OpenRouter (model,
    /// messages, max_tokens, temperature, tools, …) — the proxy only enforces
    /// auth, rate limits, and a model allow-list.
    static func postChatCompletion(
        body: [String: Any],
        timeout: TimeInterval = 30
    ) async throws -> Data {
        let baseURL = Config.EXPO_PUBLIC_SUPABASE_URL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !baseURL.isEmpty,
              let url = URL(string: "\(baseURL)/functions/v1/ai-proxy")
        else { throw AIProxyError.notConfigured }

        guard let session = try? await SupabaseService.shared.client.auth.session else {
            throw AIProxyError.notAuthenticated
        }
        let accessToken = session.accessToken

        let data = try JSONSerialization.data(withJSONObject: body)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        // Supabase functions require the anon key as the apikey header.
        let anonKey = Config.EXPO_PUBLIC_SUPABASE_ANON_KEY
        if !anonKey.isEmpty {
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
        }
        request.httpBody = data
        request.timeoutInterval = timeout

        let (respData, resp) = try await URLSession.shared.data(for: request)
        if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
            let text = String(data: respData, encoding: .utf8) ?? ""
            print("[AIProxy] \(http.statusCode): \(text.prefix(400))")
            throw AIProxyError.http(http.statusCode, text)
        }
        return respData
    }

    /// Convenience: extract `choices[0].message.content` (string content variant).
    static func extractContent(_ data: Data) throws -> String {
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String
        else { throw AIProxyError.invalidResponse }
        return content
    }
}
