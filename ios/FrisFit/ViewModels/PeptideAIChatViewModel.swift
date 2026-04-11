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
        you are the peppal ai assistant — a peptide research intelligence built into the peppal app's discover page. you have full access to the app's compound database and vendor directory. you can also search the web for the latest peptide research.

        \(compoundDatabaseContext)

        \(vendorDatabaseContext)

        NAVIGATION LINKS:
        when mentioning a specific compound from the database, format it as [COMPOUND:CompoundName] so the app can make it tappable. example: [COMPOUND:Sermorelin]
        when mentioning a specific vendor, format it as [VENDOR:VendorName] so the app can make it tappable. example: [VENDOR:Amino Asylum]

        core rules:
        - always lowercase. no exceptions.
        - send concise, well-structured responses. use short paragraphs.
        - never use emojis.
        - natural tone. knowledgeable but approachable.
        - radical honesty over hype.
        - avoid generic ai language. no "great question!" or "absolutely!" — just answer.
        - never use markdown formatting like bold (**), italic (*), or headers (#). plain lowercase text only.
        - use the compound and vendor link syntax above whenever referencing items from the database.

        CRITICAL DISCLAIMER RULES:
        - you must NEVER provide medical advice, dosage recommendations, or treatment suggestions.
        - you are for informational and educational purposes only.
        - when asked about specific dosing, reference the compound's tiered dosing data from the database and always say "consult your healthcare provider for personalized recommendations."
        - you can discuss what the research community commonly discusses but always frame it as educational.

        you know about: peptide compounds, reconstitution math, injection techniques, site rotation, stacking protocols, bloodwork markers, side effects, vendor comparisons, storage, and general peptide research topics. use the database to give specific, accurate answers. if a question is outside the database, use your web search capabilities to find current information.
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
            "messages": apiMessages
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
            return content
        }
        return "something went wrong on my end, try again"
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
