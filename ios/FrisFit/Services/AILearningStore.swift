import Foundation

/// Tracks user engagement with AI-suggested deck tasks so the agent can learn
/// what to keep suggesting and what to stop suggesting.
@MainActor
@Observable
final class AILearningStore {
    static let shared = AILearningStore()

    private let storageKey = "aiLearningEvents.v1"
    private let maxEventAgeDays: Int = 30
    private let maxEvents: Int = 200

    private(set) var events: [LearningEvent] = []

    private init() {
        load()
    }

    nonisolated struct LearningEvent: Codable, Sendable, Identifiable {
        let id: UUID
        let suggestionId: String
        let title: String
        let category: String
        let urgency: String
        let action: Action
        let dismissReason: DeckDismissReason?
        let timestamp: Date

        enum Action: String, Codable, Sendable {
            case completed
            case dismissed
            case ignored
        }
    }

    func recordCompletion(task: DailyTask) {
        guard let sid = task.aiSuggestionId else { return }
        append(
            suggestionId: sid,
            title: task.name,
            category: task.category.rawValue,
            urgency: task.aiUrgency?.rawValue ?? "",
            action: .completed,
            dismissReason: nil
        )
    }

    func recordDismissal(suggestion: AIDeckSuggestion, reason: DeckDismissReason) {
        append(
            suggestionId: suggestion.id,
            title: suggestion.title,
            category: suggestion.category.rawValue,
            urgency: suggestion.urgency.rawValue,
            action: .dismissed,
            dismissReason: reason
        )
    }

    func markIgnored(suggestion: AIDeckSuggestion) {
        append(
            suggestionId: suggestion.id,
            title: suggestion.title,
            category: suggestion.category.rawValue,
            urgency: suggestion.urgency.rawValue,
            action: .ignored,
            dismissReason: nil
        )
    }

    func reset() {
        events = []
        persist()
    }

    /// Short memo describing engagement patterns for the agent prompt.
    func memoForAgent() -> String {
        let fresh = prunedEvents()
        guard !fresh.isEmpty else {
            return "No prior engagement data yet — calibrate from the user's raw data."
        }

        var completedTitles: [String: Int] = [:]
        var dismissedTitles: [String: (count: Int, reason: String)] = [:]
        var ignoredTitles: [String: Int] = [:]

        for e in fresh {
            switch e.action {
            case .completed:
                completedTitles[e.title, default: 0] += 1
            case .dismissed:
                let prev = dismissedTitles[e.title]?.count ?? 0
                dismissedTitles[e.title] = (prev + 1, e.dismissReason?.label ?? "")
            case .ignored:
                ignoredTitles[e.title, default: 0] += 1
            }
        }

        var lines: [String] = []
        let topCompleted = completedTitles.sorted { $0.value > $1.value }.prefix(5)
        if !topCompleted.isEmpty {
            lines.append("User reliably completes: " + topCompleted.map { "\($0.key) (\($0.value)x)" }.joined(separator: ", "))
        }
        let topDismissed = dismissedTitles.sorted { $0.value.count > $1.value.count }.prefix(5)
        if !topDismissed.isEmpty {
            lines.append("User dismissed recently: " + topDismissed.map { "\"\($0.key)\" (\($0.value.count)x\($0.value.reason.isEmpty ? "" : ", reason: \($0.value.reason)"))" }.joined(separator: ", "))
        }
        let topIgnored = ignoredTitles.sorted { $0.value > $1.value }.prefix(5)
        if !topIgnored.isEmpty {
            lines.append("User ignored: " + topIgnored.map { "\"\($0.key)\" (\($0.value)x)" }.joined(separator: ", "))
        }

        lines.append("RULE: Do not re-suggest anything on the dismissed list unless the underlying data has materially changed. Prefer patterns similar to the completed list.")

        return lines.joined(separator: "\n")
    }

    func dismissedSuggestionIds() -> Set<String> {
        let fresh = prunedEvents()
        let dismissed = fresh.filter { $0.action == .dismissed }
        var counts: [String: Int] = [:]
        for e in dismissed { counts[e.suggestionId, default: 0] += 1 }
        return Set(counts.filter { $0.value >= 1 }.keys)
    }

    // MARK: - Private

    private func append(suggestionId: String, title: String, category: String, urgency: String, action: LearningEvent.Action, dismissReason: DeckDismissReason?) {
        let event = LearningEvent(
            id: UUID(),
            suggestionId: suggestionId,
            title: title,
            category: category,
            urgency: urgency,
            action: action,
            dismissReason: dismissReason,
            timestamp: Date()
        )
        events.insert(event, at: 0)
        if events.count > maxEvents { events = Array(events.prefix(maxEvents)) }
        persist()
    }

    private func prunedEvents() -> [LearningEvent] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -maxEventAgeDays, to: Date()) ?? Date()
        return events.filter { $0.timestamp >= cutoff }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([LearningEvent].self, from: data) else { return }
        events = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(events) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
