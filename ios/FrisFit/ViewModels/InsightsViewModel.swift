import SwiftUI

@MainActor
@Observable
final class InsightsViewModel {
    var investigation: AgentInvestigationResult?
    var isInvestigating: Bool = false
    var lastError: String?

    var askTurns: [AgentAskTurn] = []
    var askInput: String = ""
    var isAsking: Bool = false

    private var refreshTask: Task<Void, Never>?

    /// Minimum time between automatic refetches, even if the underlying data hash changes.
    /// Dashboards and the Insights tab both re-trigger on appear; this debounces them
    /// so we're not burning a Sonnet call every time a meal gets logged.
    private let minRefetchInterval: TimeInterval = 60 * 60 // 1 hour

    private let cacheKey = "insights_investigation_v1"

    static let shared = InsightsViewModel()

    private init() {
        loadCached()
    }

    var hero: AgentInsight? { investigation?.hero }
    var impact: [ProtocolImpactMetric] { investigation?.impact ?? [] }
    var patterns: [AgentInsight] { investigation?.patterns ?? [] }
    var dataPointsChecked: Int { investigation?.dataPointsChecked ?? 0 }

    func refreshIfNeeded(force: Bool = false) {
        let hash = InsightsDataStore.shared.dataHash

        if !force, let cached = investigation {
            // Same data signature → cache is authoritative, never refetch.
            if cached.dataHash == hash { return }
            // Data changed but we refreshed recently → honor the TTL to avoid thrash.
            if Date().timeIntervalSince(cached.generatedAt) < minRefetchInterval { return }
        }

        // If a fetch is already in flight, don't pile on.
        if isInvestigating { return }
        if let task = refreshTask, !task.isCancelled {
            // existing task still running
            return
        }

        refreshTask = Task { [weak self] in
            await self?.runInvestigation(hash: hash)
            self?.refreshTask = nil
        }
    }

    private func runInvestigation(hash: String) async {
        isInvestigating = true
        lastError = nil
        defer { isInvestigating = false }
        do {
            let result = try await InsightsAgentService.shared.investigate()
            withAnimation(.easeInOut(duration: 0.3)) {
                self.investigation = result
            }
            cache(result)
        } catch {
            print("[Insights] investigation failed: \(error)")
            let detail: String
            switch error {
            case InsightsAgentError.apiError(let code):
                detail = code == 401 ? "AI key missing or invalid." : "AI service error (\(code)). Try again."
            case InsightsAgentError.invalidResponse:
                detail = "AI returned an unexpected response. Try again."
            case InsightsAgentError.invalidURL:
                detail = "AI endpoint misconfigured."
            default:
                detail = "Network hiccup. Pull to retry."
            }
            lastError = detail
        }
    }

    func ask() async {
        let q = askInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !isAsking else { return }
        askInput = ""
        let turn = AgentAskTurn(question: q)
        askTurns.insert(turn, at: 0)
        isAsking = true
        defer { isAsking = false }
        do {
            let (answer, evidence) = try await InsightsAgentService.shared.answer(question: q)
            if let idx = askTurns.firstIndex(where: { $0.id == turn.id }) {
                askTurns[idx].answer = answer
                askTurns[idx].evidence = evidence
                askTurns[idx].isStreaming = false
            }
        } catch {
            if let idx = askTurns.firstIndex(where: { $0.id == turn.id }) {
                askTurns[idx].answer = "Couldn't investigate that right now. Try again in a moment."
                askTurns[idx].isStreaming = false
            }
        }
    }

    // MARK: - Persistence

    private func loadCached() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode(AgentInvestigationResult.self, from: data) else {
            return
        }
        investigation = decoded
    }

    private func cache(_ result: AgentInvestigationResult) {
        if let data = try? JSONEncoder().encode(result) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
}
