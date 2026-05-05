import Foundation
import UIKit

nonisolated enum VialIntegrityStatus: String, Codable, Sendable {
    case pass
    case warn
    case fail
    case unknown

    var label: String {
        switch self {
        case .pass: return "Pass"
        case .warn: return "Check"
        case .fail: return "Do Not Use"
        case .unknown: return "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .pass: return "checkmark.seal.fill"
        case .warn: return "exclamationmark.triangle.fill"
        case .fail: return "xmark.octagon.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}

nonisolated struct VialIntegrityResult: Codable, Sendable {
    let status: VialIntegrityStatus
    let observations: [String]
    let recommendation: String

    static let unknown = VialIntegrityResult(status: .unknown, observations: [], recommendation: "Couldn't analyze the image. Try a clearer photo with good lighting.")
}

nonisolated final class VialIntegrityService: Sendable {
    static let shared = VialIntegrityService()

    private let model = "google/gemini-3-flash"

    private let systemPrompt = """
    You are a pharmaceutical quality inspector analyzing a photo of a reconstituted or lyophilized peptide/compound vial.
    Evaluate ONLY what is visible in the image. Do NOT invent observations.

    Check for:
    - Cloudiness, haziness, or turbidity of the solution
    - Visible particles or flakes floating or settled
    - Unusual color changes (yellow/brown tint in a clear solution)
    - Tampered or broken tamper-evident cap / flip-top
    - Crystallization or precipitation
    - Broken glass / cracks / leakage

    Then classify the vial as:
    - "pass" if the vial looks clean and safe to use
    - "warn" if something looks off but is borderline (slight haze, minor settling)
    - "fail" if there are clear signs of contamination, tampering, or damage
    - "unknown" if the image is unclear

    Respond with ONLY a JSON object (no markdown, no commentary):
    {
      "status": "pass|warn|fail|unknown",
      "observations": ["short bullet", "short bullet"],
      "recommendation": "one sentence of guidance for the user"
    }
    """

    func inspect(imageData: Data) async -> VialIntegrityResult {
        guard let compressed = compress(imageData: imageData) ?? Optional(imageData) else {
            return .unknown
        }
        let base64 = compressed.base64EncodedString()
        let dataURL = "data:image/jpeg;base64,\(base64)"

        let userContent: [[String: Any]] = [
            ["type": "text", "text": "Inspect this vial image for integrity issues."],
            ["type": "image_url", "image_url": ["url": dataURL]]
        ]

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userContent]
            ],
            "temperature": 0.1,
            "max_tokens": 300
        ]

        do {
            let text = try await callProxy(body: body)
            return parse(text)
        } catch {
            print("[VialIntegrity] Error: \(error)")
            return .unknown
        }
    }

    private func compress(imageData: Data) -> Data? {
        guard let image = UIImage(data: imageData) else { return nil }
        let maxDim: CGFloat = 1024
        let size = image.size
        let scale = min(1, maxDim / max(size.width, size.height))
        if scale >= 1 { return image.jpegData(compressionQuality: 0.7) }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized?.jpegData(compressionQuality: 0.7)
    }

    private func callProxy(body: [String: Any]) async throws -> String {
        let base = Config.EXPO_PUBLIC_TOOLKIT_URL
        let key = Config.EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY
        guard let url = URL(string: "\(base)/v2/vercel/v1/chat/completions") else {
            throw VialScanError.networkError
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw VialScanError.decodingError
        }
        return content
    }

    private func parse(_ text: String) -> VialIntegrityResult {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") { cleaned = String(cleaned.dropFirst(7)) }
        else if cleaned.hasPrefix("```") { cleaned = String(cleaned.dropFirst(3)) }
        if cleaned.hasSuffix("```") { cleaned = String(cleaned.dropLast(3)) }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = cleaned.firstIndex(of: "{"), let end = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[start...end])
        }
        guard let data = cleaned.data(using: .utf8),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .unknown
        }
        let statusStr = (raw["status"] as? String ?? "unknown").lowercased()
        let status = VialIntegrityStatus(rawValue: statusStr) ?? .unknown
        let observations = (raw["observations"] as? [String]) ?? []
        let recommendation = (raw["recommendation"] as? String) ?? ""
        return VialIntegrityResult(status: status, observations: observations, recommendation: recommendation)
    }
}
