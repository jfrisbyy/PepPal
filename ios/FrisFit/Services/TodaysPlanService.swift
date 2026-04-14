import Foundation

final class TodaysPlanService {
    static let shared = TodaysPlanService()

    private let openRouterURL = "https://openrouter.ai/api/v1/chat/completions"
    private let model = "openai/gpt-4o-2024-11-20"

    private var apiKey: String { Config.EXPO_PUBLIC_OPENROUTER_API_KEY }

    private let systemPrompt = """
    IDENTITY AND ROLE:
    You are PepPal's intelligent assistant embedded in a health and protocol tracking app. You generate the Today's Plan dashboard content that users see on their home screen. You are knowledgeable about peptide and compound protocols, nutrition science, resistance training, and body composition. You speak like a well-informed friend who also happens to know clinical context — not like a doctor, not like a chatbot, not like a corporate app.

    TONE AND PERSONALITY:
    Casual but credible. Supportive but honest. You use the user's first name. You refer to specific numbers from their data — never speak in generalities when you have specifics. You don't sugarcoat (if they're over budget on calories, say so directly) but you also don't shame or lecture. You celebrate wins without being corny. You flag concerns without being alarmist. You never use phrases like "Great job!" or "Keep it up!" or "You got this!" — those feel robotic. Instead you acknowledge progress in a grounded way like "That's 4 weeks in a row hitting your training target — consistency is doing the heavy lifting here." You never use emojis. You write in short, direct sentences. Think text message from a smart friend, not a notification from a health app.

    OUTPUT FORMAT:
    Return ONLY a valid JSON object with this exact structure, no markdown, no explanation, no extra text:
    {
      "summary": "2-3 sentence opening paragraph covering the most important things about this user's day right now, connecting insights across domains where relevant.",
      "modules": [
        {
          "type": "protocol|nutrition|training|body|side_effects|bloodwork|supplements",
          "title": "Short label for the module card",
          "content": "1-3 sentences of insight for that module."
        }
      ]
    }

    Only include modules where there is meaningful data to discuss. Do not include empty or placeholder modules. If the user has no active protocol, no training program, no meals logged, no weight data, etc., skip those modules entirely.

    CROSS-DOMAIN REASONING:
    When writing the summary and module content, actively look for connections between data points. Examples: If the user logged nausea and their calorie intake is low, connect those to the compound's appetite suppression effect at their current phase. If the user's weight has plateaued but their waist measurement is down, explain recomposition. If the user is training back-to-back days and reported fatigue, connect that to recovery needs on reduced calories. If protein has been consistently low and they're on a GLP-1 compound, flag the muscle preservation concern. If their side effects are spiking and they recently increased dose, explain the titration connection.

    WHAT TO CALL OUT:
    Be proactive about surfacing things the user might not notice. Flag positive trends (weight loss rate is ideal, side effects are declining, protein consistency has improved). Flag concerns (bloodwork is overdue, protein has been low for 5+ days, side effects are increasing, weight is spiking in an unusual way). Flag milestones (first month on protocol, halfway to goal weight, 10-session training streak). Flag correlations (side effects clustered around dose days, calorie drops on injection days, better training performance on higher calorie days).

    WHAT NOT TO DO:
    Never give medical advice or tell the user to change their dose. Never diagnose conditions. Always frame clinical concerns as "worth discussing with your provider." Never fabricate data — only reference numbers that are in the context bundle. Never be preachy about missed workouts or bad eating days. Never use filler phrases — every sentence should contain real information or a real insight. Never repeat the same point across the summary and a module — if you mention weight trend in the summary, the body module should cover something different about body data. Never use emojis.

    SAFETY GUARDRAILS:
    If the context bundle shows extreme values (weight loss exceeding 3 lbs/week, very low calorie intake under 800 cal consistently, severe or escalating side effects), the tone should shift to clearly recommend consulting a healthcare provider. Frame it as: "This is something your provider should know about."
    """

    func generatePlan(context: ContextBundle) async throws -> TodaysPlanResponse {
        let contextString = context.toPromptString()

        let messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": "Generate today's plan dashboard based on this user data:\n\n\(contextString)"]
        ]

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": 1200,
            "temperature": 0.7
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: URL(string: openRouterURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(Bundle.main.bundleIdentifier ?? "com.peppal.app", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("PepPal", forHTTPHeaderField: "X-Title")
        request.httpBody = jsonData
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            print("[TodaysPlan] API error \(httpResponse.statusCode): \(errorBody)")
            throw TodaysPlanError.apiError(httpResponse.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw TodaysPlanError.invalidResponse
        }

        return try parseResponse(content)
    }

    private func parseResponse(_ text: String) throws -> TodaysPlanResponse {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") { cleaned = String(cleaned.dropFirst(7)) }
        else if cleaned.hasPrefix("```") { cleaned = String(cleaned.dropFirst(3)) }
        if cleaned.hasSuffix("```") { cleaned = String(cleaned.dropLast(3)) }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        if let startIdx = cleaned.firstIndex(of: "{"),
           let endIdx = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[startIdx...endIdx])
        }

        guard let jsonData = cleaned.data(using: .utf8) else {
            throw TodaysPlanError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(TodaysPlanResponse.self, from: jsonData)
        return decoded
    }

    func assembleContext(
        firstName: String,
        activeProtocol: PeptideProtocol?,
        nutrition: NutritionSnapshot,
        nutritionTarget: MacroTarget,
        loggedMeals: [LoggedMeal],
        recentDailyMeals: [[LoggedMeal]] = [],
        bodyGoalVM: BodyGoalViewModel,
        todaysPlan: WorkoutPlan,
        activeProgram: TrainingProgram?,
        bloodworkEntries: [BloodworkEntry],
        streakDays: Int,
        workoutsThisWeek: Int
    ) -> ContextBundle {
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm a"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"

        let hour = Calendar.current.component(.hour, from: now)
        let timeOfDay: String
        switch hour {
        case 0..<12: timeOfDay = "morning"
        case 12..<17: timeOfDay = "afternoon"
        default: timeOfDay = "evening"
        }

        let userProfile = UserProfileContext(
            firstName: firstName,
            currentDateTime: dateFormatter.string(from: now),
            timeOfDay: timeOfDay
        )

        var protocolContext: ProtocolContext?
        var compoundKnowledge: String?

        if let proto = activeProtocol, let compound = proto.compounds.first {
            let daysSinceStart = max(1, Calendar.current.dateComponents([.day], from: proto.startDate, to: now).day ?? 1)
            let totalWeeks = proto.effectiveTotalWeeks
            let percentThrough = totalWeeks > 0 ? Int(Double(daysSinceStart) / Double(totalWeeks * 7) * 100) : nil

            let todayDoses = proto.doseLog.filter { Calendar.current.isDateInToday($0.timestamp) }
            let doseTime = todayDoses.first.map { timeFormatter.string(from: $0.timestamp) }

            protocolContext = ProtocolContext(
                compoundName: compound.compoundName,
                currentDose: CompoundUnitHelper.displayDoseShort(compound.doseMcg, for: compound.compoundName),
                frequency: compound.frequency,
                startDate: DateFormatter.localizedString(from: proto.startDate, dateStyle: .medium, timeStyle: .none),
                currentWeek: proto.currentWeek,
                currentPhase: proto.currentPhase.rawValue,
                totalDays: daysSinceStart,
                percentThrough: percentThrough,
                doseLoggedToday: !todayDoses.isEmpty,
                doseLoggedTime: doseTime
            )

            if let profile = CompoundDatabase.all.first(where: {
                $0.name.lowercased() == compound.compoundName.lowercased()
            }) {
                var knowledge = "Compound: \(profile.name)\n"
                if !profile.subtitle.isEmpty { knowledge += "Type: \(profile.subtitle)\n" }
                if !profile.sideEffects.isEmpty {
                    knowledge += "Expected side effects: \(profile.sideEffects.joined(separator: ", "))\n"
                }
                if !profile.whatToExpect.isEmpty {
                    for entry in profile.whatToExpect {
                        knowledge += "\(entry.timeframe): \(entry.description)\n"
                    }
                }
                if !profile.watchOut.isEmpty {
                    knowledge += "Watch out: \(profile.watchOut)\n"
                }
                compoundKnowledge = knowledge
            }
        }

        let totalCalories = loggedMeals.reduce(0) { $0 + $1.totalCalories }
        let totalProtein = loggedMeals.reduce(0) { $0 + $1.totalProtein }
        let totalCarbs = loggedMeals.reduce(0) { $0 + $1.totalCarbs }
        let totalFat = loggedMeals.reduce(0) { $0 + $1.totalFat }

        let hourFraction = Double(hour) / 24.0
        let expectedCalories = Int(Double(nutritionTarget.calories) * hourFraction)
        let onPace = totalCalories >= Int(Double(expectedCalories) * 0.7) && totalCalories <= Int(Double(expectedCalories) * 1.3)

        let nutritionToday = NutritionTodayContext(
            caloriesConsumed: totalCalories,
            caloriesTarget: nutritionTarget.calories,
            caloriesRemaining: max(nutritionTarget.calories - totalCalories, 0),
            proteinConsumed: Int(totalProtein),
            proteinTarget: nutritionTarget.protein,
            proteinRemaining: max(nutritionTarget.protein - Int(totalProtein), 0),
            carbsConsumed: Int(totalCarbs),
            carbsTarget: nutritionTarget.carbs,
            fatConsumed: Int(totalFat),
            fatTarget: nutritionTarget.fat,
            mealsLogged: loggedMeals.count,
            onPace: onPace
        )

        var bodyContext: BodyContext?
        if bodyGoalVM.currentWeight > 0 {
            let entries = bodyGoalVM.weightEntries
            var weeklyRate: Double?
            if entries.count >= 4 {
                let recentFour = entries.suffix(4)
                if let first = recentFour.first, let last = recentFour.last {
                    let weeks = max(1, Calendar.current.dateComponents([.weekOfYear], from: first.date, to: last.date).weekOfYear ?? 1)
                    weeklyRate = (last.weight - first.weight) / Double(weeks)
                }
            }

            let plateauDetected: Bool
            if entries.count >= 3 {
                let recent = entries.suffix(3)
                let weights = recent.map(\.weight)
                let spread = (weights.max() ?? 0) - (weights.min() ?? 0)
                plateauDetected = spread < 0.5
            } else {
                plateauDetected = false
            }

            var measurementStr: String?
            if let latest = bodyGoalVM.measurements.last {
                var parts: [String] = []
                if let w = latest.waist { parts.append("waist: \(String(format: "%.1f", w))in") }
                if let c = latest.chest { parts.append("chest: \(String(format: "%.1f", c))in") }
                if let h = latest.hips { parts.append("hips: \(String(format: "%.1f", h))in") }
                if !parts.isEmpty { measurementStr = parts.joined(separator: ", ") }
            }

            bodyContext = BodyContext(
                currentWeight: bodyGoalVM.currentWeight,
                goalWeight: bodyGoalVM.targetWeight,
                distanceToGoal: bodyGoalVM.remainingToGoal,
                totalWeightChange: bodyGoalVM.totalChange,
                weeklyAvgLossRate: weeklyRate,
                plateauDetected: plateauDetected,
                latestMeasurements: measurementStr
            )
        }

        let trainingContext = TrainingContext(
            todayWorkout: todaysPlan.isRestDay ? nil : todaysPlan.name,
            completedToday: false,
            workoutsThisWeek: workoutsThisWeek,
            weeklyTarget: activeProgram?.daysPerWeek ?? 0,
            yesterdayWorkout: nil,
            nextTrainingDay: todaysPlan.isRestDay ? "Tomorrow" : nil
        )

        var sideEffectsContext: SideEffectsContext?
        if let proto = activeProtocol {
            let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now
            let recentEffects = proto.sideEffectLog.filter { $0.timestamp >= twoWeeksAgo }

            if !recentEffects.isEmpty {
                var effectCounts: [String: Int] = [:]
                var effectSeverities: [String: [Int]] = [:]
                for effect in recentEffects {
                    effectCounts[effect.effect, default: 0] += 1
                    effectSeverities[effect.effect, default: []].append(effect.severity)
                }

                let effects = effectCounts.map { name, count -> SideEffectContext in
                    let severities = effectSeverities[name] ?? []
                    let trend: String
                    if severities.count >= 3 {
                        let firstHalf = severities.prefix(severities.count / 2)
                        let secondHalf = severities.suffix(severities.count / 2)
                        let avgFirst = Double(firstHalf.reduce(0, +)) / Double(max(firstHalf.count, 1))
                        let avgSecond = Double(secondHalf.reduce(0, +)) / Double(max(secondHalf.count, 1))
                        if avgSecond > avgFirst + 0.3 { trend = "increasing" }
                        else if avgSecond < avgFirst - 0.3 { trend = "decreasing" }
                        else { trend = "stable" }
                    } else {
                        trend = "stable"
                    }
                    return SideEffectContext(name: name, count: count, trend: trend)
                }.sorted { $0.count > $1.count }

                let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
                let thisWeekEffects = recentEffects.filter { $0.timestamp >= oneWeekAgo }
                var weekCounts: [String: Int] = [:]
                for e in thisWeekEffects { weekCounts[e.effect, default: 0] += 1 }
                let topWeek = weekCounts.max(by: { $0.value < $1.value })?.key

                sideEffectsContext = SideEffectsContext(effects: effects, mostFrequentThisWeek: topWeek)
            }
        }

        var bloodworkContext: BloodworkContext?
        if !bloodworkEntries.isEmpty {
            let latest = bloodworkEntries.sorted { $0.date > $1.date }.first!
            let daysSince = Calendar.current.dateComponents([.day], from: latest.date, to: now).day ?? 0
            let recheckDue = daysSince > 90

            let flagged = latest.results.filter { !$0.isInRange }.map { "\($0.biomarker.rawValue): \($0.value) \($0.biomarker.unit) (\($0.status.rawValue))" }

            bloodworkContext = BloodworkContext(
                lastPanelDate: DateFormatter.localizedString(from: latest.date, dateStyle: .medium, timeStyle: .none),
                daysSinceLastPanel: daysSince,
                recheckDue: recheckDue,
                flaggedBiomarkers: flagged
            )
        }

        var supplementsContext: SupplementsContext?
        if let proto = activeProtocol, !proto.supplements.isEmpty {
            let names = proto.supplements.map(\.name)
            supplementsContext = SupplementsContext(
                supplements: names,
                totalActive: names.count,
                loggedToday: 0
            )
        }

        var nutritionTrends: NutritionTrendsContext?
        if !recentDailyMeals.isEmpty {
            let dayCount = recentDailyMeals.count
            let dailyCalories = recentDailyMeals.map { day in day.reduce(0) { $0 + $1.totalCalories } }
            let dailyProtein = recentDailyMeals.map { day in Int(day.reduce(0) { $0 + $1.totalProtein }) }
            let avgCal = dailyCalories.reduce(0, +) / max(dayCount, 1)
            let avgProt = dailyProtein.reduce(0, +) / max(dayCount, 1)
            let daysProteinHit = dailyProtein.filter { $0 >= nutritionTarget.protein }.count
            let daysCalorieHit = dailyCalories.filter { abs($0 - nutritionTarget.calories) <= Int(Double(nutritionTarget.calories) * 0.1) }.count

            var pattern: String?
            if avgProt < Int(Double(nutritionTarget.protein) * 0.8) {
                pattern = "Consistently low protein"
            } else if dailyCalories.count >= 3 {
                let firstHalf = Array(dailyCalories.prefix(dailyCalories.count / 2))
                let secondHalf = Array(dailyCalories.suffix(dailyCalories.count / 2))
                let avgFirst = firstHalf.isEmpty ? 0 : firstHalf.reduce(0, +) / firstHalf.count
                let avgSecond = secondHalf.isEmpty ? 0 : secondHalf.reduce(0, +) / secondHalf.count
                if avgFirst > avgSecond + 200 { pattern = "Front-loading calories earlier in the week" }
                else if avgSecond > avgFirst + 200 { pattern = "Calorie intake increasing through the week" }
            }

            nutritionTrends = NutritionTrendsContext(
                avgCalories: avgCal,
                avgProtein: avgProt,
                daysProteinHit: daysProteinHit,
                daysCalorieHit: daysCalorieHit,
                notablePattern: pattern
            )
        }

        return ContextBundle(
            userProfile: userProfile,
            protocolContext: protocolContext,
            compoundKnowledge: compoundKnowledge,
            nutritionToday: nutritionToday,
            nutritionTrends: nutritionTrends,
            bodyContext: bodyContext,
            trainingContext: trainingContext,
            sideEffectsContext: sideEffectsContext,
            bloodworkContext: bloodworkContext,
            supplementsContext: supplementsContext
        )
    }
}

nonisolated enum TodaysPlanError: Error, Sendable {
    case apiError(Int)
    case invalidResponse
}
