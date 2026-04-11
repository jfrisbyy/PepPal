import SwiftUI

@Observable
final class PeptideAIChatViewModel {
    var messages: [PepMessage] = []
    var inputText: String = ""
    var isGenerating: Bool = false
    var suggestedQuestions: [String] = [
        "What peptides are best for fat loss?",
        "How do I reconstitute BPC-157?",
        "Compare Ipamorelin vs Sermorelin",
        "What bloodwork should I get before starting?"
    ]

    private var conversationHistory: [[String: Any]] = []

    private var openRouterAPIKey: String {
        Config.EXPO_PUBLIC_OPENROUTER_API_KEY
    }

    private var compoundDatabaseContext: String {
        let compounds = CompoundDatabase.all
        var context = "COMPOUND DATABASE (you have access to all of these):\n"
        for compound in compounds {
            context += "\n--- \(compound.name) ---\n"
            context += "Type: \(compound.peptideType)\n"
            context += "Categories: \(compound.categories.map(\.rawValue).joined(separator: ", "))\n"
            context += "Overview: \(compound.overview)\n"
            context += "Route: \(compound.keyFacts.administrationRoute)\n"
            context += "Half-Life: \(compound.keyFacts.halfLife)\n"
            context += "Typical Dose: \(compound.keyFacts.typicalDoseRange)\n"
            context += "Cycle Length: \(compound.cycleLength)\n"
            if !compound.stackPartners.isEmpty {
                context += "Stack Partners: \(compound.stackPartners.joined(separator: ", "))\n"
            }
            if !compound.primaryUseCases.isEmpty {
                context += "Use Cases: \(compound.primaryUseCases.joined(separator: "; "))\n"
            }
            if !compound.sideEffects.isEmpty {
                context += "Side Effects: \(compound.sideEffects.joined(separator: ", "))\n"
            }
            if !compound.tieredDosing.isEmpty {
                context += "Dosing Tiers:\n"
                for tier in compound.tieredDosing {
                    context += "  \(tier.tier): \(tier.dose), \(tier.frequency), \(tier.timingNotes)\n"
                }
            }
        }
        return context
    }

    private var vendorDatabaseContext: String {
        let vendors = CompoundDatabase.vendors
        var context = "\nVENDOR DATABASE:\n"
        for vendor in vendors {
            context += "\n- \(vendor.name): Rating \(String(format: "%.1f", vendor.rating))/5 (\(vendor.reviewCount) reviews)"
            if vendor.isVerified { context += " [VERIFIED]" }
            context += ", Carries: \(vendor.compoundsCarried.joined(separator: ", "))"
            if !vendor.websiteURL.isEmpty {
                context += ", Website: \(vendor.websiteURL)"
            }
            context += "\n"
        }
        return context
    }

    private var systemPrompt: String {
        """
        you are the peppal research assistant — a peptide intelligence built into the peppal app's discover page. you have the app's full compound database and vendor directory loaded below.

        \(compoundDatabaseContext)

        \(vendorDatabaseContext)

        NAVIGATION LINKS:
        when mentioning a compound from the database, format as [COMPOUND:CompoundName]. example: [COMPOUND:Sermorelin]
        when mentioning a vendor, format as [VENDOR:VendorName]. example: [VENDOR:Amino Asylum]

        RESPONSE FORMAT — THIS IS CRITICAL:
        - you are a chat assistant inside a mobile app. responses must feel like texting, not reading an article.
        - keep total response under 200 words. shorter is always better.
        - break thoughts into multiple short paragraphs separated by double newlines. each chunk 1-3 sentences max.
        - never write walls of text. never write essay-style responses.
        - never use numbered lists longer than 3-4 items. prefer flowing text.
        - never use bullet points or dashes for lists. just write naturally.
        - never cite sources, add footnotes, or reference URLs.
        - never say "according to research" or "studies show" — just state what's known.
        - always lowercase. no exceptions.
        - never use emojis.
        - never use markdown formatting — no bold (**), italic (*), headers (#), or backticks. plain text only.
        - no generic ai filler. no "great question!" or "absolutely!" — just answer directly.
        - knowledgeable but chill. like a friend who actually knows their stuff.

        DISCLAIMER RULES:
        - never provide medical advice or treatment suggestions.
        - educational and informational only.
        - for specific dosing questions, reference the compound's tiered dosing from the database and say "talk to your doctor for personalized recs."
        - frame everything as what the research community discusses.

        you know about: peptide compounds, reconstitution math, injection techniques, site rotation, stacking protocols, bloodwork markers, side effects, vendor comparisons, storage, and general peptide research. use the database for specific answers. if something isn't in the database, say so honestly.
        """
    }

    init() {
        messages.append(PepMessage(
            role: .pep,
            content: "hey — i'm the peppal research assistant. i have access to the full compound database and vendor directory. ask me anything about peptides, protocols, reconstitution, vendors, or research."
        ))
    }

    func sendMessage(_ text: String? = nil) {
        let messageText = (text ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !messageText.isEmpty, !isGenerating else { return }

        messages.append(PepMessage(role: .user, content: messageText))
        inputText = ""
        isGenerating = true
        suggestedQuestions = []

        conversationHistory.append(["role": "user", "content": messageText])

        Task {
            await generateResponse()
        }
    }

    private func generateResponse() async {
        var apiMessages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt]
        ]

        for entry in conversationHistory {
            let role = entry["role"] as? String ?? "user"
            let content = entry["content"] as? String ?? ""
            apiMessages.append(["role": role, "content": content])
        }

        let body: [String: Any] = [
            "model": "perplexity/sonar",
            "messages": apiMessages,
            "max_tokens": 400
        ]

        do {
            guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
                appendFallback()
                return
            }

            guard let url = URL(string: "https://openrouter.ai/api/v1/chat/completions") else {
                appendFallback()
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(openRouterAPIKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = jsonData
            request.timeoutInterval = 45

            let (data, _) = try await URLSession.shared.data(for: request)
            let responseText = extractText(from: data)

            conversationHistory.append(["role": "assistant", "content": responseText])

            let chunks = splitChunks(responseText)
            for (index, chunk) in chunks.enumerated() {
                if index > 0 {
                    try? await Task.sleep(for: .milliseconds(Int.random(in: 300...600)))
                }
                messages.append(PepMessage(role: .pep, content: chunk))
            }

            isGenerating = false
        } catch {
            appendFallback()
        }
    }

    private func extractText(from data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let content = message["content"] as? String {
            return cleanResponse(content)
        }
        return "something went wrong on my end, try again"
    }

    private func cleanResponse(_ text: String) -> String {
        var cleaned = text
        let citationPattern = #"\[\d+\]"#
        cleaned = cleaned.replacingOccurrences(of: citationPattern, with: "", options: .regularExpression)
        let sourcePattern = #"(?i)\n*sources?:.*$"#
        cleaned = cleaned.replacingOccurrences(of: sourcePattern, with: "", options: .regularExpression)
        let refPattern = #"(?i)\n*references?:.*$"#
        cleaned = cleaned.replacingOccurrences(of: refPattern, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "**", with: "")
        cleaned = cleaned.replacingOccurrences(of: "##", with: "")
        cleaned = cleaned.replacingOccurrences(of: "# ", with: "")
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func splitChunks(_ text: String) -> [String] {
        let parts = text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if parts.count > 1 { return parts }

        let lines = text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if lines.count > 1 { return lines }

        return [text.trimmingCharacters(in: .whitespacesAndNewlines)]
    }

    private func appendFallback() {
        messages.append(PepMessage(role: .pep, content: "couldn't reach the server right now — try again in a sec"))
        isGenerating = false
    }

    func matchedCompound(named name: String) -> CompoundProfile? {
        CompoundDatabase.all.first { $0.name.lowercased() == name.lowercased() }
    }

    func matchedVendor(named name: String) -> Vendor? {
        CompoundDatabase.vendors.first { $0.name.lowercased() == name.lowercased() }
    }

    func clearChat() {
        messages = [PepMessage(
            role: .pep,
            content: "fresh start — what do you want to know?"
        )]
        conversationHistory = []
        suggestedQuestions = [
            "What peptides are best for fat loss?",
            "How do I reconstitute BPC-157?",
            "Compare Ipamorelin vs Sermorelin",
            "What bloodwork should I get before starting?"
        ]
    }
}
