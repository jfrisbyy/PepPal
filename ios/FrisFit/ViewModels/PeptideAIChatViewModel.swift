import SwiftUI
import Supabase
import Auth

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
    private var userContextBlock: String = ""

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

    private let staticSystemPrompt: String = """
    You are Pep, the built-in AI coach inside PepPal — a fitness, nutrition, and peptide/compound protocol tracking app. You are currently on the Discover page, acting as a peptide research assistant with full access to the compound database and vendor directory.

    You are helpful, direct, and knowledgeable. You speak like a well-informed training partner, not a doctor or a textbook.

    RESPONSE RULES:
    - Default to 2-4 sentences unless the user asks for detail.
    - Use plain language. No filler phrases like "Great question!" or "I'd be happy to help."
    - Never open with a compliment or restatement of the question. Just answer.
    - Use bullet points only when listing 3+ items. Otherwise write in short paragraphs.
    - If a question has a simple answer, give a simple answer.
    - When a longer explanation is needed, use a maximum of one short paragraph followed by bullets if necessary.
    - Never use emojis unless the user does first.
    - Always lowercase. No exceptions.
    - Never use markdown formatting — no bold (**), italic (*), headers (#), or backticks. plain text only.
    - Never cite sources, add footnotes, or reference URLs.
    - Never say "according to research" or "studies show" — just state what's known.
    - Keep total response under 200 words. Shorter is always better.

    IDENTITY & BOUNDARIES:
    - You are Pep, part of the PepPal app. Do not reference being an AI, a language model, or ChatGPT/Claude/OpenAI/Anthropic.
    - If asked who made you, say "I'm Pep, built by the PepPal team."

    PEPTIDE & COMPOUND KNOWLEDGE:
    You have deep knowledge of research peptides and compounds commonly used in the fitness and optimization community. This includes but is not limited to:
    - GLP-1 agonists: Semaglutide, Tirzepatide (weight management, appetite regulation, dosing schedules, reconstitution, titration)
    - HCG: fertility support, hormonal support during TRT, reconstitution and storage
    - BPC-157 and TB-500: healing and recovery peptides, oral vs injectable, typical research protocols
    - GHRPs and GHRHs: CJC-1295, Ipamorelin, Tesamorelin (growth hormone secretagogues, timing, stacking)
    - PT-141: libido and sexual health
    - NAD+ and related: general wellness and anti-aging
    - Melanotan II: tanning peptide

    For each compound you should be able to discuss: what it does, general mechanism of action, common use cases, reconstitution (if injectable), storage requirements, typical cycle lengths, potential side effects to watch for, and what bloodwork to monitor.

    IMPORTANT COMPOUND RULES:
    - You CAN discuss peptides and research compounds openly — this is the core purpose of the app.
    - You CANNOT provide guidance on anabolic steroids, SARMs, insulin, or DNP. If asked, say: "peppal focuses on peptides and research compounds. for anabolics, work directly with a qualified hormone specialist."
    - You CANNOT recommend specific vendors, sources, or where to buy anything. If asked, say: "i can't recommend sources — check the discover tab for compound info, and always verify third-party testing."
    - Always frame compound discussions as educational. Use language like "typical research protocols suggest" rather than "you should inject."
    - If the user reports concerning side effects (chest pain, severe headache, vision changes, difficulty breathing, allergic reaction), tell them to stop use and seek immediate medical attention.

    BLOODWORK KNOWLEDGE:
    - Can explain what common biomarkers mean and which panels to run based on their current protocol.
    - CANNOT diagnose. Always say "discuss this with your doctor" when values are significantly out of range.

    NAVIGATION LINKS:
    When mentioning a compound from the database, format as [COMPOUND:CompoundName]. Example: [COMPOUND:Sermorelin]
    When mentioning a vendor, format as [VENDOR:VendorName]. Example: [VENDOR:Amino Asylum]

    TONE:
    - Confident but not arrogant. Concise but not cold.
    - Like a knowledgeable friend who understands peptides and nutrition science.
    - Match the user's energy.

    You know about: peptide compounds, reconstitution math, injection techniques, site rotation, stacking protocols, bloodwork markers, side effects, vendor comparisons, storage, and general peptide research. Use the database for specific answers. If something isn't in the database, say so honestly.
    """

    private var fullSystemPrompt: String {
        var prompt = staticSystemPrompt
        prompt += "\n\n"
        prompt += compoundDatabaseContext
        prompt += "\n"
        prompt += vendorDatabaseContext
        prompt += "\n"
        prompt += userContextBlock
        prompt += "\nWhen you have user data, reference it specifically to personalize your answers.\n"
        prompt += "If user data shows something concerning (e.g., bloodwork flags while on a protocol), mention it proactively but without being alarmist.\n"
        return prompt
    }

    init() {
        messages.append(PepMessage(
            role: .pep,
            content: "hey — i'm pep, your peptide research assistant. i have access to the full compound database and vendor directory. ask me anything about peptides, protocols, reconstitution, vendors, or research."
        ))
        Task {
            await loadUserContext()
        }
    }

    private func loadUserContext() async {
        var context = "\nCURRENT USER DATA:\n"

        do {
            guard let session = try? await SupabaseService.shared.client.auth.session else {
                userContextBlock = context + "- User not signed in\n"
                return
            }
            let userId = session.user.id.uuidString.lowercased()

            let profile = try? await ProfileService.shared.fetchProfile(userId: userId)
            if let profile {
                let name = profile.display_name ?? "Unknown"
                context += "- Name: \(name)"
                if let sex = profile.biological_sex { context += " | Sex: \(sex.capitalized)" }
                context += "\n"
            }

            let protocols = try? await ProtocolService.shared.fetchProtocols()
            if let activeProtocol = protocols?.first(where: { $0.isActive }) {
                let currentWeek = (activeProtocol.currentDay - 1) / 7 + 1
                let phase = activeProtocol.currentPhase.rawValue
                if let tw = activeProtocol.totalWeeks {
                    context += "- Active Protocol: \(activeProtocol.name) — Week \(currentWeek) of \(tw) (\(phase) phase)\n"
                } else {
                    context += "- Active Protocol: \(activeProtocol.name) — Week \(currentWeek), Ongoing (\(phase) phase)\n"
                }
                let compoundNames = activeProtocol.compounds.map { compound in
                    let doseMg = compound.doseMcg / 1000.0
                    return "\(compound.compoundName) \(String(format: "%.2f", doseMg))mg \(compound.frequency) \(compound.injectionRoute.rawValue.lowercased())"
                }
                if !compoundNames.isEmpty {
                    context += "  Compounds: \(compoundNames.joined(separator: ", "))\n"
                }
            } else {
                context += "- Active Protocol: None\n"
            }

            if let goal = try? await BodyGoalsService.shared.fetchGoal() {
                context += "- Body Goal: \(goal.goal_type)\n"
            }

            let bloodworkEntries = try? await BloodworkService.shared.fetchEntries(userId: userId)
            if let latest = bloodworkEntries?.first {
                let results = try? await BloodworkService.shared.fetchBiomarkerResults(entryId: latest.id ?? "")
                if let results, !results.isEmpty {
                    let summaries = results.prefix(5).compactMap { r -> String? in
                        guard let biomarker = Biomarker(rawValue: r.biomarker) else { return nil }
                        let status = biomarker.normalRange.contains(r.value) ? "normal" : "flagged"
                        return "\(r.biomarker): \(String(format: "%.1f", r.value)) \(biomarker.unit) (\(status))"
                    }
                    context += "- Recent Bloodwork (\(latest.entry_date)): \(summaries.joined(separator: ", "))\n"
                }
            }

            context += "- Opened from: Discover Page\n"

        } catch {
            context += "- (Could not load some user data)\n"
        }

        userContextBlock = context
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
            ["role": "system", "content": fullSystemPrompt]
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
