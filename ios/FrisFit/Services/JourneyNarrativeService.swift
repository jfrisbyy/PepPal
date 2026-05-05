import Foundation

/// Generates the one-line "the AI is learning you in real time" narrative
/// preview shown in Chapter 4 once the user has added their third pin.
/// Routed through `AIModelTier.fast` per the Prompt 8 spec — Sonnet is reserved
/// for deeper investigation.
@MainActor
enum JourneyNarrativeService {
    /// Build a tight one-liner like "Down 15 pounds, lifting steady, getting strong — let's keep going."
    /// Returns `nil` on failure so the caller can degrade silently.
    static func generatePreview(
        firstName: String?,
        bodyPins: Int,
        compoundPins: Int,
        trainingPins: Int,
        bloodworkPins: Int,
        lifePins: Int,
        weightDeltaLbs: Double?,
        ninetyDayWorkoutCount: Int?
    ) async -> String? {
        let system = """
        You are EPTI's narrator. Write ONE short, warm, present-tense sentence \
        (max 14 words) summarizing the user's journey from the seeded facts. \
        Conversational, lowercase punctuation OK, no emojis, no quotation marks, \
        no medical advice. End with a forward-looking nudge after an em dash, e.g. \
        "— let's keep going." Output ONLY the sentence.
        """

        var facts: [String] = []
        if let firstName, !firstName.isEmpty { facts.append("name: \(firstName)") }
        if let d = weightDeltaLbs, abs(d) >= 0.5 {
            let direction = d < 0 ? "down" : "up"
            facts.append(String(format: "weight %@ %.0f lbs over 90 days", direction, abs(d)))
        }
        if let w = ninetyDayWorkoutCount, w > 0 {
            facts.append("\(w) workouts in last 90 days")
        }
        if bodyPins > 0 { facts.append("\(bodyPins) body milestones logged") }
        if compoundPins > 0 { facts.append("\(compoundPins) compound cycles tracked") }
        if trainingPins > 0 { facts.append("\(trainingPins) training phases set") }
        if bloodworkPins > 0 { facts.append("\(bloodworkPins) bloodwork dates noted") }
        if lifePins > 0 { facts.append("\(lifePins) life events on the map") }

        guard !facts.isEmpty else { return nil }
        let user = "Seeded facts:\n" + facts.joined(separator: "\n") + "\n\nWrite the sentence."

        do {
            let raw = try await OpenRouterClient.shared.chat(
                tier: .fast,
                systemPrompt: system,
                userPrompt: user,
                maxTokens: 80,
                temperature: 0.7,
                timeout: 12
            )
            let cleaned = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            return cleaned.isEmpty ? nil : cleaned
        } catch {
            return nil
        }
    }

    /// Fallback line when the API is unavailable, so the moment never feels broken.
    static func fallbackPreview(firstName: String?, weightDeltaLbs: Double?) -> String {
        if let d = weightDeltaLbs, abs(d) >= 1 {
            let direction = d < 0 ? "down" : "up"
            return "\(direction) \(Int(abs(d.rounded()))) pounds, lifting steady — let's keep going."
        }
        if let n = firstName, !n.isEmpty {
            return "your story is taking shape, \(n) — let's keep going."
        }
        return "your story is taking shape — let's keep going."
    }
}
