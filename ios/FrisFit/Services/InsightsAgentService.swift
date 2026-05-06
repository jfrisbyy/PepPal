import Foundation

/// Orchestrates an OpenRouter (Claude Sonnet 4.6) tool-use loop.
/// The model picks from the 14 insight tools, we run them, return results,
/// and the loop continues until the model emits a final answer.
final class InsightsAgentService {
    static let shared = InsightsAgentService()

    private let model = "anthropic/claude-sonnet-4.6"
    private let maxToolRounds = 6

    private init() {}

    private let systemPrompt = """
    You are EPTI's Insights Agent. You are an intelligent assistant that investigates the user's multi-domain health data (peptide protocols, training, nutrition, body composition, HealthKit recovery signals, side effects, bloodwork) and surfaces conclusions that no single-vertical app could produce.

    IDENTITY AND VOICE:
    Casual, credible, grounded. Like a smart friend who happens to understand clinical context. You always reference specific numbers from tool results. You never use filler like "Great job!" or emojis. You write in short, direct sentences. You never give medical advice or tell the user to change their dose.

    HOW TO WORK:
    You have access to tools that query the user's actual data. Instead of guessing, call the tools you need. Plan what correlations matter most (e.g. "is training volume down because of sleep debt or because of a calorie deficit?"), call the tools, then reason across the results. Prefer calling 3-6 targeted tools over calling all 14. Use dose-day-vs-non-dose-day comparisons aggressively — cross-domain correlations are the whole point.

    WHEN ASKED FOR A JSON OUTPUT FORMAT:
    Return ONLY valid JSON, no markdown, no preamble. Always use actual numbers from tool results — never fabricate values. Cite which tool produced each fact via evidence entries.

    WHEN ASKED A FREE-FORM QUESTION:
    Investigate with tools, then answer in 2-5 sentences citing specific numbers. If the data is insufficient, say so directly. If clinical thresholds are crossed (extreme weight loss, severe side effects, flagged bloodwork), recommend discussing with a provider.

    YOU MUST NEVER:
    - Invent numbers the tools didn't return
    - Give medical advice or dose changes
    - Be preachy, use wellness platitudes, or use emojis
    - Pad tool calls — only call what you need
    """

    struct AgentOutcome: Sendable {
        let finalText: String
        let usedTools: [(name: String, args: [String: Any], evidence: [EvidencePoint])]
    }

    /// Run a tool-use loop with the given user prompt. Returns the model's final text
    /// plus an ordered list of tool calls so the UI can surface evidence.
    @MainActor
    func run(userPrompt: String, systemOverride: String? = nil) async throws -> AgentOutcome {
        let baseSystem = systemOverride ?? systemPrompt
        let memo = AIMemoryStore.shared.memoForAgent()
        let composedSystem = memo.isEmpty ? baseSystem : "\(baseSystem)\n\n\(memo)"
        var messages: [[String: Any]] = [
            ["role": "system", "content": composedSystem],
            ["role": "user", "content": userPrompt]
        ]
        var used: [(name: String, args: [String: Any], evidence: [EvidencePoint])] = []

        for _ in 0..<maxToolRounds {
            let response = try await chatCompletion(messages: messages, allowTools: true)
            // Append the assistant message verbatim so tool_call references resolve
            messages.append(response.rawAssistantMessage)
            guard !response.toolCalls.isEmpty else {
                return AgentOutcome(finalText: response.content, usedTools: used)
            }
            for call in response.toolCalls {
                let args: [String: Any] = (try? JSONSerialization.jsonObject(with: Data(call.argumentsJSON.utf8)) as? [String: Any]) ?? [:]
                let result = await InsightToolkit.shared.dispatch(call.name, arguments: args)
                used.append((call.name, args, result.evidence))
                messages.append([
                    "role": "tool",
                    "tool_call_id": call.id,
                    "content": result.text
                ])
            }
        }

        // Final round: force a text answer with no tools
        let final = try await chatCompletion(messages: messages, allowTools: false)
        return AgentOutcome(finalText: final.content, usedTools: used)
    }

    // MARK: - Chat Completion

    private struct ChatResponse {
        let content: String
        let toolCalls: [ToolCall]
        let rawAssistantMessage: [String: Any]
    }

    private struct ToolCall {
        let id: String
        let name: String
        let argumentsJSON: String
    }

    private func chatCompletion(messages: [[String: Any]], allowTools: Bool) async throws -> ChatResponse {
        var body: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": 1400,
            "temperature": 0.4,
        ]
        if allowTools {
            body["tools"] = InsightToolkit.toolDefinitions
            body["tool_choice"] = "auto"
        }

        let respData: Data
        do {
            respData = try await AIProxyClient.postChatCompletion(body: body, timeout: 45)
        } catch let AIProxyError.http(code, _) {
            throw InsightsAgentError.apiError(code)
        } catch AIProxyError.notConfigured, AIProxyError.notAuthenticated {
            throw InsightsAgentError.invalidURL
        } catch {
            throw InsightsAgentError.invalidResponse
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any]
        else {
            throw InsightsAgentError.invalidResponse
        }

        let content = (message["content"] as? String) ?? ""
        var calls: [ToolCall] = []
        if let tcs = message["tool_calls"] as? [[String: Any]] {
            for tc in tcs {
                guard
                    let id = tc["id"] as? String,
                    let fn = tc["function"] as? [String: Any],
                    let name = fn["name"] as? String
                else { continue }
                let args = (fn["arguments"] as? String) ?? "{}"
                calls.append(ToolCall(id: id, name: name, argumentsJSON: args))
            }
        }

        return ChatResponse(content: content, toolCalls: calls, rawAssistantMessage: message)
    }

    // MARK: - High-level helpers

    /// Produces a full investigation: hero insight, protocol impact metrics, patterns.
    @MainActor
    func investigate() async throws -> AgentInvestigationResult {
        let store = InsightsDataStore.shared
        let hash = store.dataHash
        let prompt = """
        Investigate this user's current state and output a structured report.

        User first name: \(store.firstName.isEmpty ? "the user" : store.firstName)
        Active protocols: \(store.activeProtocols.filter(\.isActive).map(\.name).joined(separator: ", "))

        Call the tools you need to find the most important cross-domain insight today, then compute key protocol-impact metrics, then surface 2-4 notable patterns or correlations. Prioritize insights that connect two or more domains (e.g. protocol + training, nutrition + recovery).

        Return ONLY valid JSON with this exact shape, no markdown:
        {
          "hero": {
            "headline": "Punchy one-sentence insight",
            "body": "2-4 sentences expanding with specific numbers",
            "domain": "protocol|training|nutrition|body|recovery|side_effects|bloodwork|cross",
            "evidence_tools": ["tool_name_1", "tool_name_2"],
            "actions": ["Short imperative action 1", "Action 2"],
            "provider_flag": false
          },
          "impact": [
            {
              "label": "Recovery",
              "baseline_value": "68",
              "current_value": "76",
              "delta_percent": 11.8,
              "direction": "up|down|flat|mixed",
              "domain": "recovery",
              "takeaway": "One-sentence takeaway"
            }
          ],
          "patterns": [
            {
              "headline": "Short pattern title",
              "body": "2-3 sentences with cited numbers",
              "domain": "training|nutrition|recovery|side_effects|cross|protocol|body|bloodwork",
              "evidence_tools": ["tool_name"],
              "actions": [],
              "provider_flag": false
            }
          ]
        }

        If you truly have no data to produce a section, return an empty array (or null for hero). Do not fabricate. Do not wrap in markdown.
        """

        let outcome = try await run(userPrompt: prompt)
        let parsed = try parseInvestigation(outcome.finalText, toolUsage: outcome.usedTools)
        return AgentInvestigationResult(
            hero: parsed.hero,
            patterns: parsed.patterns,
            impact: parsed.impact,
            generatedAt: Date(),
            dataPointsChecked: outcome.usedTools.count,
            dataHash: hash
        )
    }

    @MainActor
    func answer(question: String) async throws -> (answer: String, evidence: [EvidencePoint]) {
        let store = InsightsDataStore.shared
        let prompt = """
        User question: \(question)

        User first name: \(store.firstName.isEmpty ? "user" : store.firstName)
        Active protocols: \(store.activeProtocols.filter(\.isActive).map(\.name).joined(separator: ", "))

        Investigate with the tools you need, then answer the user's question in 2-5 sentences using specific numbers from tool results. Do not give medical advice or dose changes.
        """
        let outcome = try await run(userPrompt: prompt)
        let allEvidence = outcome.usedTools.flatMap(\.evidence)
        return (outcome.finalText, allEvidence)
    }

    // MARK: - Parsing

    private struct ParsedInvestigation {
        let hero: AgentInsight?
        let impact: [ProtocolImpactMetric]
        let patterns: [AgentInsight]
    }

    private func parseInvestigation(_ raw: String, toolUsage: [(name: String, args: [String: Any], evidence: [EvidencePoint])]) throws -> ParsedInvestigation {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") { cleaned = String(cleaned.dropFirst(7)) }
        else if cleaned.hasPrefix("```") { cleaned = String(cleaned.dropFirst(3)) }
        if cleaned.hasSuffix("```") { cleaned = String(cleaned.dropLast(3)) }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        if let s = cleaned.firstIndex(of: "{"), let e = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[s...e])
        }
        guard let data = cleaned.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw InsightsAgentError.invalidResponse
        }

        let evidenceByTool: [String: [EvidencePoint]] = Dictionary(grouping: toolUsage.flatMap(\.evidence), by: { $0.tool })

        func pickEvidence(_ tools: [String]) -> [EvidencePoint] {
            var out: [EvidencePoint] = []
            for t in tools { out.append(contentsOf: evidenceByTool[t] ?? []) }
            return out
        }

        func parseInsight(_ dict: [String: Any]) -> AgentInsight? {
            guard
                let headline = dict["headline"] as? String,
                let body = dict["body"] as? String
            else { return nil }
            let domainStr = (dict["domain"] as? String) ?? "cross"
            let domain = InsightDomain(rawValue: domainStr) ?? .cross
            let tools = (dict["evidence_tools"] as? [String]) ?? []
            let actions = (dict["actions"] as? [String]) ?? []
            let flag = (dict["provider_flag"] as? Bool) ?? false
            return AgentInsight(
                headline: headline,
                body: body,
                domain: domain,
                evidence: pickEvidence(tools),
                actions: actions,
                providerFlag: flag
            )
        }

        var hero: AgentInsight?
        if let heroDict = obj["hero"] as? [String: Any] {
            hero = parseInsight(heroDict)
        }

        var impact: [ProtocolImpactMetric] = []
        if let arr = obj["impact"] as? [[String: Any]] {
            for d in arr {
                guard
                    let label = d["label"] as? String,
                    let baseline = d["baseline_value"] as? String,
                    let current = d["current_value"] as? String
                else { continue }
                let delta = d["delta_percent"] as? Double
                let dirStr = (d["direction"] as? String) ?? "flat"
                let direction = ProtocolImpactMetric.Direction(rawValue: dirStr) ?? .flat
                let domainStr = (d["domain"] as? String) ?? "cross"
                let domain = InsightDomain(rawValue: domainStr) ?? .cross
                let takeaway = (d["takeaway"] as? String) ?? ""
                impact.append(ProtocolImpactMetric(
                    label: label,
                    baselineValue: baseline,
                    currentValue: current,
                    deltaPercent: delta,
                    direction: direction,
                    domain: domain,
                    takeaway: takeaway,
                    sparkline: []
                ))
            }
        }

        var patterns: [AgentInsight] = []
        if let arr = obj["patterns"] as? [[String: Any]] {
            for d in arr {
                if let p = parseInsight(d) { patterns.append(p) }
            }
        }

        return ParsedInvestigation(hero: hero, impact: impact, patterns: patterns)
    }
}

nonisolated enum InsightsAgentError: Error, Sendable {
    case invalidURL
    case apiError(Int)
    case invalidResponse
}
