import Foundation

nonisolated struct AIProgramRequest: Sendable {
    let goal: String
    let daysPerWeek: Int
    let equipment: [String]
    let experience: String
    let injuries: String
    let peptideProtocol: String
    let sessionLength: Int
    let preferences: String
    let userContext: String

    init(
        goal: String,
        daysPerWeek: Int,
        equipment: [String],
        experience: String,
        injuries: String,
        peptideProtocol: String,
        sessionLength: Int,
        preferences: String,
        userContext: String = ""
    ) {
        self.goal = goal
        self.daysPerWeek = daysPerWeek
        self.equipment = equipment
        self.experience = experience
        self.injuries = injuries
        self.peptideProtocol = peptideProtocol
        self.sessionLength = sessionLength
        self.preferences = preferences
        self.userContext = userContext
    }
}

nonisolated struct AIProgramExerciseJSON: Codable, Sendable {
    let name: String
    let sets: Int
    let repsMin: Int
    let repsMax: Int
}

nonisolated struct AIProgramDayJSON: Codable, Sendable {
    let name: String
    let exercises: [AIProgramExerciseJSON]
}

nonisolated struct AIProgramResponseJSON: Codable, Sendable {
    let programName: String
    let days: [AIProgramDayJSON]
}

final class AIProgramService {
    static let shared = AIProgramService()
    private init() {}

    private let openRouterURL = "https://openrouter.ai/api/v1/chat/completions"
    private let model = "openai/gpt-4o"

    private var apiKey: String {
        Config.EXPO_PUBLIC_OPENROUTER_API_KEY
    }

    func generateProgram(_ request: AIProgramRequest) async throws -> TrainingProgram {
        let exerciseNames = ExerciseLibrary.all.map(\.name).joined(separator: ", ")

        let systemPrompt = """
        You are an expert strength & conditioning coach and peptide-informed programming specialist. You build personalized training programs that account for the user's full biometric, pharmacological, and training context.

        You MUST only use exercises from this list: [\(exerciseNames)]. Do not invent exercises.

        RULES:
        - Design a program with exactly \(request.daysPerWeek) training days
        - Each day should have 4-7 exercises
        - Use compound movements first, isolation last
        - Balance push/pull volume across the week
        - Match exercise selection to available equipment
        - If there are injuries/limitations, avoid exercises that aggravate them
        - Session should fit within ~\(request.sessionLength) minutes
        - Sets range: 2-5, Reps range: 3-20 depending on goal

        PEPTIDE/COMPOUND-AWARE PROGRAMMING:
        - GLP-1 agonists (semaglutide, tirzepatide, retatrutide): User is likely in a deficit with suppressed appetite. Prioritize muscle preservation — heavier loads, moderate volume, compound-focused. Avoid excessive metabolic conditioning.
        - GH secretagogues (CJC-1295, ipamorelin, tesamorelin, sermorelin): Enhanced recovery allows higher volume and frequency. Favor hypertrophy-style programming with each muscle hit 2x/week.
        - Healing peptides (BPC-157, TB-500, GHK-Cu): User may be rehabbing an injury. Include progressive loading for healing areas, compensatory volume for unaffected muscles, and prehab/mobility work.
        - Anabolic peptides (IGF-1, follistatin): Enhanced protein synthesis — program can handle higher volume and progressive overload.
        - Off-cycle phase: Reduce volume 30-40%, keep intensity moderate, focus on maintenance.
        - Loading phase: Start conservative, plan to ramp volume over 2-3 weeks.

        BODY GOAL AWARENESS:
        - Cutting/Weight Loss: Preserve muscle with heavy compounds, moderate volume, 3-4 days
        - Bulking/Weight Gain: High volume, progressive overload, 4-6 days, each muscle 2x/week
        - Recomp: Balance strength work with hypertrophy, include some metabolic conditioning
        - Maintenance: Minimal effective dose — 3 days, compound-focused, 2-3 sets per exercise

        Give the program a creative, specific name that reflects the strategy (not generic like "4-Day Split").

        RESPOND WITH ONLY valid JSON matching this structure, no markdown:
        {
          "programName": "string",
          "days": [
            {
              "name": "string",
              "exercises": [
                { "name": "exact exercise name from the list", "sets": number, "repsMin": number, "repsMax": number }
              ]
            }
          ]
        }
        """

        var userParts: [String] = []
        userParts.append("Goal: \(request.goal)")
        userParts.append("Days per week: \(request.daysPerWeek)")
        userParts.append("Experience level: \(request.experience)")
        userParts.append("Available equipment: \(request.equipment.joined(separator: ", "))")
        userParts.append("Session length: ~\(request.sessionLength) minutes")
        if !request.injuries.isEmpty {
            userParts.append("Injuries/limitations: \(request.injuries)")
        }
        if !request.peptideProtocol.isEmpty {
            userParts.append("Current peptide protocol: \(request.peptideProtocol)")
        }
        if !request.userContext.isEmpty {
            userParts.append("User profile data:\n\(request.userContext)")
        }
        if !request.preferences.isEmpty {
            userParts.append("Strategy & preferences:\n\(request.preferences)")
        }

        let messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userParts.joined(separator: "\n")]
        ]

        let responseText = try await callOpenRouter(messages: messages)
        return try parseResponse(responseText, daysPerWeek: request.daysPerWeek)
    }

    private func callOpenRouter(messages: [[String: Any]]) async throws -> String {
        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": 2000,
            "temperature": 0.4
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: body)

        guard let requestURL = URL(string: openRouterURL) else {
            print("CRITICAL: Invalid OpenRouter URL in AIProgramService: \(openRouterURL)")
            throw AIProgramError.apiError(0)
        }
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(Bundle.main.bundleIdentifier ?? "com.peppal.app", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("EPTI", forHTTPHeaderField: "X-Title")
        request.httpBody = jsonData
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw AIProgramError.apiError(httpResponse.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIProgramError.invalidResponse
        }

        return content
    }

    private func parseResponse(_ text: String, daysPerWeek: Int) throws -> TrainingProgram {
        let cleaned = cleanJSON(text)
        guard let data = cleaned.data(using: .utf8) else {
            throw AIProgramError.parseError
        }

        let decoded = try JSONDecoder().decode(AIProgramResponseJSON.self, from: data)

        let programDays: [ProgramDay] = decoded.days.map { dayJSON in
            let exercises: [ProgramExercise] = dayJSON.exercises.compactMap { exJSON in
                guard let exercise = ExerciseLibrary.all.first(where: {
                    $0.name.lowercased() == exJSON.name.lowercased()
                }) else { return nil }
                return ProgramExercise(
                    exercise: exercise,
                    targetSets: exJSON.sets,
                    targetRepsMin: exJSON.repsMin,
                    targetRepsMax: exJSON.repsMax
                )
            }
            return ProgramDay(name: dayJSON.name, exercises: exercises)
        }

        return TrainingProgram(
            name: decoded.programName,
            type: .recurringSplit,
            daysPerWeek: daysPerWeek,
            days: programDays,
            isActive: true
        )
    }

    private func cleanJSON(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.hasPrefix("```json") {
            result = String(result.dropFirst(7))
        } else if result.hasPrefix("```") {
            result = String(result.dropFirst(3))
        }
        if result.hasSuffix("```") {
            result = String(result.dropLast(3))
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

nonisolated enum AIProgramError: Error, LocalizedError, Sendable {
    case apiError(Int)
    case invalidResponse
    case parseError

    var errorDescription: String? {
        switch self {
        case .apiError(let code): "AI service returned error \(code). Please try again."
        case .invalidResponse: "Unexpected response from AI. Please try again."
        case .parseError: "Could not parse the generated program. Please try again."
        }
    }
}
