import SwiftUI

@Observable
final class FinnChatViewModel {
    var messages: [FinnMessage] = []
    var inputText: String = ""
    var isGenerating: Bool = false

    private let exerciseNames: Set<String> = {
        let names = ExerciseLibrary.all.map { $0.name }
        return Set(names)
    }()

    private var conversationHistory: [[String: Any]] = []

    private var openRouterAPIKey: String {
        Config.EXPO_PUBLIC_OPENROUTER_API_KEY
    }

    private let systemPrompt: String = """
    you are finn, an ai coach inside the peppal app. you help users with workouts, nutrition, recovery, programming, and motivation.

    core rules:
    - always lowercase. no exceptions.
    - send multiple short messages separated by double newlines. each chunk should be 50-150 characters. never send one long wall of text.
    - never use emojis. ever.
    - natural slang only. no linkedin-post energy. no grindset language.
    - radical honesty over hype.
    - high eq. read their emotional state and adapt.
    - avoid generic ai language. no "great question!" or "absolutely!" — just answer.
    - never use markdown formatting. no bold, italic, headers. plain lowercase text only.
    - always use question marks at the end of questions.

    tone pillars:
    - homie energy. texting them at 2am like a sibling who cares.
    - technical depth. understand their constraints.
    - word is bond. if you say you'll help, you mean it.
    - no corporate speak. be real.

    formatting rules:
    - separate thoughts into multiple short lines/paragraphs using double newlines.
    - do NOT send one big paragraph. break it up.
    - keep each chunk punchy — 50-150 characters when possible.

    you know about exercises, training splits, nutrition, recovery, and general fitness. when mentioning specific exercises, use their proper names so users can tap them in the app.
    """

    init() {
        messages.append(FinnMessage(
            role: .finn,
            content: "yo whats good"
        ))
        messages.append(FinnMessage(
            role: .finn,
            content: "im finn, your ai coach"
        ))
        messages.append(FinnMessage(
            role: .finn,
            content: "what are we working on today?"
        ))
    }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isGenerating else { return }

        messages.append(FinnMessage(role: .user, content: text))
        inputText = ""
        isGenerating = true

        conversationHistory.append(["role": "user", "content": text])

        Task {
            await generateAIResponse()
        }
    }

    private func generateAIResponse() async {
        var apiMessages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt]
        ]

        for entry in conversationHistory {
            let role = entry["role"] as? String ?? "user"
            let content = entry["content"] as? String ?? ""
            apiMessages.append(["role": role, "content": content])
        }

        let body: [String: Any] = [
            "model": "openai/gpt-4o",
            "messages": apiMessages
        ]

        do {
            guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
                appendFallbackResponse()
                return
            }

            guard let url = URL(string: "https://openrouter.ai/api/v1/chat/completions") else {
                appendFallbackResponse()
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(openRouterAPIKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = jsonData
            request.timeoutInterval = 30

            let (data, _) = try await URLSession.shared.data(for: request)
            let responseText = extractTextFromResponse(data)

            conversationHistory.append(["role": "assistant", "content": responseText])

            let chunks = splitIntoChunks(responseText)
            for (index, chunk) in chunks.enumerated() {
                if index > 0 {
                    try? await Task.sleep(for: .milliseconds(Int.random(in: 400...800)))
                }
                let names = extractExerciseNames(from: chunk)
                messages.append(FinnMessage(role: .finn, content: chunk, exerciseNames: names))
            }

            isGenerating = false
        } catch {
            appendFallbackResponse()
        }
    }

    private func splitIntoChunks(_ text: String) -> [String] {
        let parts = text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if parts.count > 1 {
            return parts
        }

        let lines = text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if lines.count > 1 {
            return lines
        }

        return [text.trimmingCharacters(in: .whitespacesAndNewlines)]
    }

    private func extractTextFromResponse(_ data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let text = json["text"] as? String { return text }
            if let result = json["result"] as? String { return result }
            if let choices = json["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let content = message["content"] as? String { return content }
        }
        if let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "something went wrong on my end, try again"
    }

    private func appendFallbackResponse() {
        let fallbacks = [
            "my bad, connection dropped\n\ntry sending that again",
            "couldn't reach the server rn\n\nhit me again in a sec",
            "something glitched on my end\n\nresend that?"
        ]
        let text = fallbacks.randomElement() ?? "try again"
        let chunks = splitIntoChunks(text)
        for chunk in chunks {
            messages.append(FinnMessage(role: .finn, content: chunk))
        }
        isGenerating = false
    }

    func findExercise(named name: String) -> Exercise? {
        ExerciseLibrary.all.first { $0.name == name }
    }

    func extractExerciseNames(from content: String) -> [String] {
        Array(exerciseNames.filter { content.contains($0) })
    }
}
