import Foundation
import SwiftUI

/// Interprets the latest bloodwork panel against the user's active protocol
/// and phase, recommends a recheck cadence, and flags anything that warrants
/// a provider conversation. Uses the deep tier for the narrative explanation.
@MainActor
@Observable
final class BloodworkInterpretationService {
    static let shared = BloodworkInterpretationService()

    var interpretation: BloodworkInterpretation?
    var isGenerating: Bool = false
    var lastError: String?

    private let cacheKey = "bloodwork_interpretation_v1"
    private var lastEntryId: UUID?

    private init() { load() }

    func interpret(latest: BloodworkEntry?, force: Bool = false) async {
        guard let entry = latest else { return }
        if !force, let cached = interpretation, lastEntryId == entry.id,
           Date().timeIntervalSince(cached.generatedAt) < 24 * 60 * 60 {
            return
        }
        guard !isGenerating else { return }
        isGenerating = true
        defer { isGenerating = false }

        let flaggedList = entry.results.filter { !$0.isInRange }
        let flags: [BloodworkFlag] = flaggedList.map { r in
            BloodworkFlag(
                biomarker: r.biomarker.rawValue,
                value: "\(String(format: "%.1f", r.value)) \(r.biomarker.unit)",
                status: r.status.rawValue,
                interpretation: "",
                protocolContext: nil
            )
        }

        let store = InsightsDataStore.shared
        let protoDesc: String
        if let proto = store.primaryProtocol, let compound = proto.compounds.first {
            protoDesc = "\(compound.compoundName), week \(proto.currentWeek), \(proto.currentPhase.rawValue) phase."
        } else {
            protoDesc = "No active protocol."
        }

        let flaggedText = flaggedList.map {
            "\($0.biomarker.rawValue): \($0.value) \($0.biomarker.unit) (\($0.status.rawValue), range \($0.biomarker.normalRange.lowerBound)-\($0.biomarker.normalRange.upperBound))"
        }.joined(separator: "\n")

        let system = """
        You are interpreting a user's bloodwork panel against the context of their active protocol. You are a credible, grounded voice — you never diagnose, never recommend dose changes, and always defer serious findings to their provider.

        Output STRICTLY valid JSON:
        {
          "headline": "One short sentence summary of what the panel shows.",
          "summary": "2-3 sentences explaining the big picture in plain language.",
          "flags": [
            {"biomarker": "LDL", "interpretation": "Expected during cut phase given LDL tends to rise temporarily.", "protocolContext": "Week 8, cutting phase — re-evaluate after diet ends."}
          ],
          "recheckRecommendationDays": 42,
          "recheckReason": "One sentence justifying the recheck cadence.",
          "providerFlag": false
        }

        Rules:
        - Only include flags for values OUT of range.
        - Reference the protocol+phase context specifically in `protocolContext` when relevant.
        - Set providerFlag=true if any result is extreme (e.g. liver enzymes >3x upper limit, HbA1c diabetic, lipids severely out of range).
        - Recheck cadence: 28-45 days if mildly flagged, 60-90 days if stable, sooner if providerFlag.
        - Never recommend dose changes. Do not use emojis.
        """

        let user = """
        PROTOCOL: \(protoDesc)
        PANEL DATE: \(entry.date.formatted(date: .abbreviated, time: .omitted))

        FLAGGED RESULTS:
        \(flaggedText.isEmpty ? "None — all in range." : flaggedText)

        IN-RANGE RESULTS (for context):
        \(entry.results.filter { $0.isInRange }.map { "\($0.biomarker.rawValue): \($0.value) \($0.biomarker.unit)" }.joined(separator: ", "))
        """

        var finalInterp: BloodworkInterpretation

        do {
            let raw = try await OpenRouterClient.shared.chat(
                tier: .deep,
                systemPrompt: system,
                userPrompt: user,
                maxTokens: 700,
                temperature: 0.3,
                timeout: 35,
                promptId: "bloodwork_interp"
            )
            let clean = OpenRouterClient.extractJSON(raw)
            let data = clean.data(using: .utf8) ?? Data()
            let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]

            let headline = (json["headline"] as? String) ?? "Bloodwork reviewed"
            let summary = (json["summary"] as? String) ?? ""
            let recheck = json["recheckRecommendationDays"] as? Int
            let recheckReason = json["recheckReason"] as? String
            let providerFlag = (json["providerFlag"] as? Bool) ?? false
            let explained = (json["flags"] as? [[String: Any]]) ?? []

            var mergedFlags: [BloodworkFlag] = []
            for baseFlag in flags {
                let match = explained.first(where: { ($0["biomarker"] as? String) == baseFlag.biomarker })
                mergedFlags.append(BloodworkFlag(
                    biomarker: baseFlag.biomarker,
                    value: baseFlag.value,
                    status: baseFlag.status,
                    interpretation: (match?["interpretation"] as? String) ?? "",
                    protocolContext: match?["protocolContext"] as? String
                ))
            }

            finalInterp = BloodworkInterpretation(
                headline: headline,
                summary: summary,
                flags: mergedFlags,
                recheckRecommendationDays: recheck,
                recheckReason: recheckReason,
                providerFlag: providerFlag,
                generatedAt: Date()
            )
            lastError = nil
        } catch {
            print("[Bloodwork] interpretation error: \(error)")
            lastError = "Could not interpret this panel right now."
            finalInterp = BloodworkInterpretation(
                headline: flaggedList.isEmpty ? "All values in range" : "\(flaggedList.count) flagged value\(flaggedList.count == 1 ? "" : "s")",
                summary: flaggedList.isEmpty ? "Nothing out of range on this panel." : "Review the flagged values below with your provider.",
                flags: flags,
                recheckRecommendationDays: flaggedList.isEmpty ? 90 : 45,
                recheckReason: nil,
                providerFlag: false,
                generatedAt: Date()
            )
        }

        interpretation = finalInterp
        lastEntryId = entry.id
        cache(finalInterp)
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode(BloodworkInterpretation.self, from: data) else { return }
        interpretation = decoded
    }

    private func cache(_ i: BloodworkInterpretation) {
        if let data = try? JSONEncoder().encode(i) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
}
