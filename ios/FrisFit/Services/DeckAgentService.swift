import Foundation

/// Generates data-driven daily deck suggestions using the same tool-use agent
/// as the Insights tab. Each suggestion comes with evidence + urgency so users
/// see why the AI recommended it.
@MainActor
final class DeckAgentService {
    static let shared = DeckAgentService()

    private init() {}

    struct DeckResult: Sendable {
        let suggestions: [AIDeckSuggestion]
        let period: DeckRefreshPeriod
        let generatedAt: Date
    }

    func generate(period: DeckRefreshPeriod) async throws -> DeckResult {
        let store = InsightsDataStore.shared
        let learning = AILearningStore.shared

        let firstName = store.firstName.isEmpty ? "the user" : store.firstName
        let protocolLine = store.activeProtocols.filter(\.isActive).map(\.name).joined(separator: ", ")
        let memo = learning.memoForAgent()
        let timeOfDay = period == .morning ? "morning" : "afternoon"

        let prompt = """
        Build the user's Daily Deck AI suggestions for \(timeOfDay) (\(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short))).

        User: \(firstName)
        Active protocols: \(protocolLine.isEmpty ? "none" : protocolLine)

        Your job: investigate the user's recent data with the tools you have, then return 2-5 high-impact tasks the user should do before end of day. Each suggestion MUST be:
        - Concrete, specific, and completable today (binary done/not-done).
        - Directly justified by numbers you saw in a tool result. Cite those tools in evidence_tools.
        - NOT a duplicate of the user's standard goals (protein target, calorie target, step goal, water goal, scheduled dose, scheduled workout) — those are surfaced separately by the app. Only include nutrition/training tasks if they are a specific tactical move (e.g. "front-load 40g protein at lunch", "drop 10% on overhead press") not a generic restating of the goal.
        - NOT generic wellness advice. Every suggestion must reference a real data point.
        - NOT medical advice, dose changes, or supplement changes.
        - Respectful of the user's engagement history (see below) — do not re-suggest things they've repeatedly dismissed.

        LEARNING MEMO (last 30 days of engagement):
        \(memo)

        For the \(timeOfDay) context specifically:
        - \(period == .morning ? "Focus on setup-for-the-day moves: protein strategy, training adjustments, measurement/log opportunities, dose prep." : "Focus on tactical midday moves based on what's been logged so far: front-load protein if behind, hydrate before evening dose, take tonight's recovery measurements, etc.")

        Return ONLY valid JSON (no markdown, no preamble) with this exact shape:
        {
          "suggestions": [
            {
              "id": "stable-kebab-id-for-today",
              "title": "Short imperative title (under ~50 chars)",
              "icon": "SF Symbol name",
              "category": "Fitness|Nutrition|Wellness|Lifestyle",
              "reason": "One sentence citing the specific data point. Under ~90 chars.",
              "urgency": "high|medium|low",
              "evidence_tools": ["tool_name_1", "tool_name_2"]
            }
          ]
        }

        Rules for the fields:
        - id: short kebab-case, stable for today (e.g. "protein-frontload", "overhead-deload"). Do not add dates.
        - urgency: "high" if skipping it today has a real downside (protein deficit on dose day, recovery red zone with heavy session scheduled, bloodwork 120+ days overdue). "medium" for useful tactical moves. "low" for nice-to-have tracking moves.
        - icon: a real SF Symbol. Prefer domain-appropriate (fish.fill, flame.fill, dumbbell.fill, moon.fill, syringe.fill, drop.fill, camera.fill, scalemass.fill, exclamationmark.triangle.fill, heart.text.clipboard, pills.fill, note.text).
        - category: match the nature of the task.
        - Return an empty suggestions array if you genuinely cannot produce any meaningful suggestion. Never pad.

        Maximum 5 suggestions.
        """

        let outcome = try await InsightsAgentService.shared.run(userPrompt: prompt)
        var parsed = try parse(outcome.finalText, toolUsage: outcome.usedTools)

        // Filter out anything the user has already dismissed
        let dismissed = learning.dismissedSuggestionIds()
        if !dismissed.isEmpty {
            parsed = parsed.filter { !dismissed.contains($0.id) }
        }

        return DeckResult(suggestions: parsed, period: period, generatedAt: Date())
    }

    // MARK: - Parsing

    private func parse(_ raw: String, toolUsage: [(name: String, args: [String: Any], evidence: [EvidencePoint])]) throws -> [AIDeckSuggestion] {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") { cleaned = String(cleaned.dropFirst(7)) }
        else if cleaned.hasPrefix("```") { cleaned = String(cleaned.dropFirst(3)) }
        if cleaned.hasSuffix("```") { cleaned = String(cleaned.dropLast(3)) }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        if let s = cleaned.firstIndex(of: "{"), let e = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[s...e])
        }
        guard let data = cleaned.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = obj["suggestions"] as? [[String: Any]] else {
            return []
        }

        let evidenceByTool: [String: [EvidencePoint]] = Dictionary(grouping: toolUsage.flatMap(\.evidence), by: { $0.tool })

        var out: [AIDeckSuggestion] = []
        for dict in arr {
            guard
                let title = dict["title"] as? String,
                let reason = dict["reason"] as? String
            else { continue }
            let id = (dict["id"] as? String)?.trimmingCharacters(in: .whitespaces) ?? stableId(from: title)
            let icon = (dict["icon"] as? String) ?? "sparkles"
            let categoryRaw = (dict["category"] as? String) ?? "Wellness"
            let category = TaskCategory(rawValue: categoryRaw) ?? .wellness
            let urgencyRaw = (dict["urgency"] as? String) ?? "medium"
            let urgency = DeckUrgency(rawValue: urgencyRaw) ?? .medium
            let tools = (dict["evidence_tools"] as? [String]) ?? []
            var evidence: [EvidencePoint] = []
            for t in tools {
                evidence.append(contentsOf: evidenceByTool[t] ?? [])
            }
            out.append(AIDeckSuggestion(
                id: id,
                title: title,
                icon: icon,
                category: category,
                reason: reason,
                urgency: urgency,
                evidence: evidence
            ))
        }
        return Array(out.prefix(5))
    }

    private func stableId(from title: String) -> String {
        var hasher = Hasher()
        hasher.combine(title.lowercased())
        return "ai-\(hasher.finalize())"
    }
}
