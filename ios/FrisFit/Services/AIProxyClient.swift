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

    /// Convenience: extract `choices[0].message.content`.
    ///
    /// Handles every shape OpenRouter has been observed to emit:
    /// - `content` as a plain string (OpenAI / most models)
    /// - `content` as an array of blocks `[{"type":"text","text":"…"}]`
    ///   (Anthropic via OpenRouter, especially with prompt-cache enabled)
    /// - `content` null/empty but a sibling `reasoning` string present
    ///   (some Anthropic refresh paths)
    /// Falls through to `invalidResponse` only when there is genuinely no
    /// usable text anywhere in the choice. Logs the top-level keys on
    /// failure so we can diagnose new upstream shapes quickly.
    static func extractContent(_ data: Data) throws -> String {
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            print("[AIProxy] extractContent: response is not a JSON object")
            throw AIProxyError.invalidResponse
        }

        // Upstream errors that came through with 200 (rare but possible).
        if let err = json["error"] as? [String: Any] {
            let msg = err["message"] as? String ?? "unknown"
            print("[AIProxy] extractContent: upstream returned error in 200 body: \(msg)")
            throw AIProxyError.invalidResponse
        }

        guard
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any]
        else {
            let keys = (json.keys).joined(separator: ",")
            print("[AIProxy] extractContent: missing choices[0].message — keys=[\(keys)]")
            throw AIProxyError.invalidResponse
        }

        // Shape 1: plain string content.
        if let str = message["content"] as? String, !str.isEmpty {
            return str
        }

        // Shape 2: array-of-blocks content (Anthropic-style).
        if let blocks = message["content"] as? [[String: Any]] {
            let combined = blocks.compactMap { block -> String? in
                if let text = block["text"] as? String, !text.isEmpty { return text }
                return nil
            }.joined(separator: "\n")
            if !combined.isEmpty { return combined }
        }

        // Shape 3: content empty but reasoning present (some Anthropic paths).
        if let reasoning = message["reasoning"] as? String, !reasoning.isEmpty {
            return reasoning
        }

        // Surface why we couldn't extract so the next failure is debuggable.
        let finish = first["finish_reason"] as? String ?? (first["native_finish_reason"] as? String ?? "unknown")
        let msgKeys = message.keys.joined(separator: ",")
        print("[AIProxy] extractContent: empty content. finish_reason=\(finish) message.keys=[\(msgKeys)]")
        throw AIProxyError.invalidResponse
    }
}
