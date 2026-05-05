import SwiftUI
import Supabase
import Auth
import HealthKit

@Observable
final class PepChatViewModel {
    var messages: [PepMessage] = []
    var inputText: String = ""
    var isGenerating: Bool = false

    private let exerciseNames: Set<String> = {
        let names = ExerciseLibrary.all.map { $0.name }
        return Set(names)
    }()

    private var conversationHistory: [[String: Any]] = []
    private var userContextBlock: String = ""

    private var openRouterAPIKey: String {
        Config.EXPO_PUBLIC_OPENROUTER_API_KEY
    }

    private var compoundDatabaseContext: String {
        let compounds = CompoundDatabase.all
        var context = "\nCOMPOUND DATABASE (you have access to all of these):\n"
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

    private let staticSystemPrompt: String = """
    You are Pep, the built-in AI coach inside EPTI — a fitness, nutrition, and peptide/compound protocol tracking app. You are helpful, direct, and knowledgeable. You speak like a well-informed training partner, not a doctor or a textbook.

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

    IDENTITY & BOUNDARIES:
    - You are Pep, part of the EPTI app. Do not reference being an AI, a language model, or ChatGPT/Claude/OpenAI/Anthropic.
    - If asked who made you, say "I'm Pep, built by the EPTI team."
    - You help with: training, nutrition, body composition, peptides, compounds, supplements, protocols, bloodwork interpretation (general education only), goal setting, and app navigation.
    - You do NOT: diagnose medical conditions, prescribe medications, recommend specific vendors/sources for compounds, provide dosages for controlled substances (anabolic steroids, growth hormone, insulin), give legal advice, or replace a doctor.
    - If a question crosses into medical diagnosis or prescription territory, say something like: "that's outside what i can help with — talk to your prescribing physician or a qualified healthcare provider."

    PEPTIDE & COMPOUND KNOWLEDGE:
    You have deep knowledge of research peptides and compounds commonly used in the fitness and optimization community. This includes but is not limited to:
    - GLP-1 agonists: Semaglutide, Tirzepatide (weight management, appetite regulation, dosing schedules, reconstitution, titration)
    - HCG: fertility support, hormonal support during TRT, reconstitution and storage
    - BPC-157 and TB-500: healing and recovery peptides, oral vs injectable, typical research protocols
    - GHRPs and GHRHs: CJC-1295, Ipamorelin, Tesamorelin (growth hormone secretagogues, timing, stacking)
    - PT-141: libido and sexual health
    - NAD+ and related: general wellness and anti-aging
    - Melanotan II: tanning peptide
    - Other common compounds in the space

    For each compound you should be able to discuss: what it does, general mechanism of action, common use cases, reconstitution (if injectable), storage requirements, typical cycle lengths, potential side effects to watch for, and what bloodwork to monitor.

    IMPORTANT COMPOUND RULES:
    - You CAN discuss peptides and research compounds openly — this is the core purpose of the app.
    - You CANNOT provide guidance on anabolic steroids, SARMs, insulin, or DNP. If asked, say: "peppal focuses on peptides and research compounds. for anabolics, work directly with a qualified hormone specialist."
    - You CANNOT recommend specific vendors, sources, or where to buy anything. If asked, say: "i can't recommend sources — check the discover tab for compound info, and always verify third-party testing."
    - Always frame compound discussions as educational. Use language like "typical research protocols suggest" rather than "you should inject."
    - If the user reports concerning side effects (chest pain, severe headache, vision changes, difficulty breathing, allergic reaction), tell them to stop use and seek immediate medical attention. Do not try to troubleshoot serious symptoms.

    TRAINING KNOWLEDGE:
    - Understand common program structures: PPL (Push/Pull/Legs), Upper/Lower, Bro Split, Full Body, 5/3/1, GZCLP, and custom splits.
    - Can help users choose a split based on their experience level, available days, and goals.
    - Understand progressive overload, deload weeks, RPE/RIR, periodization basics.
    - Can analyze workout data: volume per muscle group, frequency, whether they're progressing.
    - Calculate estimated calories burned using MET values for different activities.
    - Help users understand their training program and suggest adjustments.

    NUTRITION KNOWLEDGE:
    - Understand BMR calculation (Mifflin-St Jeor), TDEE concepts, and caloric targets for cut/bulk/recomp.
    - Can help set macro targets based on goals and body weight (e.g., 1g protein per lb bodyweight for muscle retention during a cut).
    - Understand meal timing, pre/post workout nutrition, and how it relates to their protocol (e.g., fasting requirements for certain peptides).
    - Can help interpret their Daily Energy card data and suggest adjustments.
    - Note: EPTI tracks actual activity rather than using TDEE multipliers, so calorie recommendations should be based on BMR + their tracked activity calories.

    BLOODWORK KNOWLEDGE:
    - Can explain what common biomarkers mean: CBC, CMP, lipid panel, liver enzymes (AST/ALT), kidney markers (BUN/creatinine), hormones (testosterone, estradiol, TSH, IGF-1, prolactin), HbA1c, fasting glucose, inflammatory markers (CRP, ESR).
    - Can flag values that are outside typical reference ranges and explain what that might indicate.
    - Can suggest which panels to run based on their current protocol.
    - CANNOT diagnose. Always say "discuss this with your doctor" when values are significantly out of range.

    APP NAVIGATION HELP:
    If the user asks how to do something in the app, guide them:
    - Log a workout: Train tab, Quick Workout (or follow their program)
    - Log a meal: Green + button, Log Meal
    - Log a dose: Green + button, Log Dose
    - Start a protocol: Home screen, Protocol card, or Discover tab, find compound, create protocol
    - Track weight: Home screen, Weight card, tap to log
    - View progress photos: Profile, Health tab, Progress Photos
    - Log bloodwork: Green + button, Log Bloodwork, or Profile, Health tab, Bloodwork Tracking
    - Set up a training program: Train tab, set up a program
    - Find compound info: Discover tab, search or browse categories
    - Community/posts: Community tab
    - Settings: Profile tab, gear icon
    - Edit profile: Profile tab, Edit Profile
    - Chat with you: Green + button, Chat with Pep

    CONTEXT-AWARE BEHAVIOR:
    When you know which screen the user opened chat from, tailor your greeting and suggestions:
    - From Home screen: reference their daily stats, energy balance, or protocol status
    - From Train tab: reference their program, recent workouts, or suggest today's session
    - From Discover tab: ask if they need help understanding a compound
    - From Community tab: keep it brief, they might just have a quick question
    - From Profile/Health tab: reference their bloodwork, measurements, or progress
    - From a specific workout: help with exercise form, substitutions, or performance questions
    - From protocol view: help with dosing schedule, reconstitution, or side effect questions

    TONE:
    - Confident but not arrogant.
    - Concise but not cold.
    - Like a knowledgeable friend at the gym who also happens to understand peptides and nutrition science.
    - Match the user's energy: if they're casual, be casual. If they ask a detailed technical question, give a detailed technical answer.
    - If the user seems frustrated or stuck, be encouraging without being patronizing.

    NAVIGATION LINKS:
    When mentioning a compound from the database, format as [COMPOUND:CompoundName]. Example: [COMPOUND:Sermorelin]

    FORMATTING:
    - Separate thoughts into multiple short paragraphs using double newlines.
    - Keep each chunk punchy. Do NOT send one big paragraph. Break it up.
    - Never use numbered lists longer than 3-4 items. Prefer flowing text.
    """

    var sourceScreen: String = "Home Screen"
    private var planContext: String?

    init(planContext: String? = nil) {
        self.planContext = planContext
        if let planContext {
            messages.append(PepMessage(
                role: .pep,
                content: "i just put together your plan — what do you want to dig into?"
            ))
            conversationHistory.append(["role": "system", "content": "The user tapped \"Chat about this\" on their Today's Plan card. Here is the plan you generated for them today:\n\n\(planContext)\n\nThe user wants to continue the conversation about this plan. Reference it naturally. Do NOT repeat the plan back to them — they just read it. Answer their follow-up directly."])
        }
        Task {
            await loadHistoryAndContext()
        }
    }

    private func loadHistoryAndContext() async {
        await loadUserContext()
        let history = (try? await ChatPersistenceService.shared.fetchRecent(limit: 60)) ?? []

        if !history.isEmpty {
            if planContext == nil {
                messages = history
            } else {
                messages.insert(contentsOf: history, at: 0)
            }
            for m in history {
                conversationHistory.append([
                    "role": m.role == .user ? "user" : "assistant",
                    "content": m.content
                ])
            }
        } else if planContext == nil {
            messages.append(PepMessage(
                role: .pep,
                content: "what's good — i'm pep, your coach inside peppal"
            ))
            messages.append(PepMessage(
                role: .pep,
                content: "i can help with training, nutrition, peptides, protocols, bloodwork, or anything in the app"
            ))
            messages.append(PepMessage(
                role: .pep,
                content: "what can i help you with?"
            ))
        }
    }

    private func loadUserContext() async {
        // Primary path: read from the shared InsightsDataStore snapshot.
        let shared = AIContextBuilder.build(options: AIContextBuilder.Options(sourceScreen: sourceScreen))
        userContextBlock = shared

        // If the store looks empty (HomeView hasn't synced yet), fall back to
        // fetching the minimum profile info so the first chat in a cold start
        // still feels personalized.
        guard InsightsDataStore.shared.firstName.isEmpty else { return }

        var context = "\nCURRENT USER DATA (cold-start fallback):\n"

        do {
            guard let session = try? await SupabaseService.shared.client.auth.session else {
                userContextBlock = shared + context + "- User not signed in\n"
                return
            }
            let userId = session.user.id.uuidString.lowercased()

            let profile = try? await ProfileService.shared.fetchProfile(userId: userId)

            if let profile {
                let name = profile.display_name ?? "Unknown"
                context += "- Name: \(name)"

                var age: Int?
                if let dobStr = profile.date_of_birth {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    if let dob = formatter.date(from: dobStr) {
                        age = Calendar.current.dateComponents([.year], from: dob, to: Date()).year
                        if let age { context += " | Age: \(age)" }
                    }
                }

                if let sex = profile.biological_sex { context += " | Sex: \(sex.capitalized)" }

                if let heightCm = profile.height_cm {
                    let totalInches = heightCm / 2.54
                    let feet = Int(totalInches) / 12
                    let inches = Int(totalInches) % 12
                    context += " | Height: \(feet)'\(inches)\""
                }
                context += "\n"

                let weightLogs = try? await BodyGoalsService.shared.fetchWeightLogs()
                let latestWeight = weightLogs?.last?.weight

                if let w = latestWeight {
                    context += "- Current Weight: \(String(format: "%.1f", w)) lbs\n"
                }

                if let heightCm = profile.height_cm,
                   let sexStr = profile.biological_sex,
                   let sex = BiologicalSex(rawValue: sexStr),
                   let a = age,
                   let w = latestWeight {
                    let weightKg = w * 0.453592
                    let bmr = BMRCalculator.calculate(weightKg: weightKg, heightCm: heightCm, age: a, sex: sex)
                    context += "- BMR: ~\(Int(bmr)) cal/day\n"
                }
            }

            if let goal = try? await BodyGoalsService.shared.fetchGoal() {
                let goalType = goal.goal_type
                context += "- Goal: \(goalType)"
                if let target = goal.target_weight {
                    context += " -> \(String(format: "%.1f", target)) lbs"
                }
                if let current = goal.current_weight, let target = goal.target_weight {
                    let diff = abs(current - target)
                    context += " (\(String(format: "%.1f", diff)) lbs to go)"
                    if let starting = goal.starting_weight, abs(starting - target) > 0 {
                        let progress = max(0, min(100, (1.0 - diff / abs(starting - target)) * 100))
                        context += " (\(Int(progress))% progress)"
                    }
                }
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

            let workouts = try? await WorkoutService.shared.fetchWorkouts(userId: userId, limit: 5)
            if let workouts, !workouts.isEmpty {
                let recent = workouts.prefix(3)
                let workoutSummaries = recent.map { w in
                    let name = w.name
                    let duration = w.duration_minutes ?? 0
                    let cal = w.calories_burned ?? 0
                    return "\(name) (\(duration)min, \(cal)cal)"
                }
                context += "- Recent Workouts: \(workoutSummaries.joined(separator: "; "))\n"

                let thisWeek = workouts.filter { w in
                    guard let dateStr = w.completed_at ?? w.date else { return false }
                    let iso = ISO8601DateFormatter()
                    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    let isoBasic = ISO8601DateFormatter()
                    isoBasic.formatOptions = [.withInternetDateTime]
                    guard let date = iso.date(from: dateStr) ?? isoBasic.date(from: dateStr) else { return false }
                    return Calendar.current.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
                }
                context += "- Workouts This Week: \(thisWeek.count)\n"
            } else {
                context += "- Recent Workouts: None logged\n"
            }

            let meals = try? await NutritionService.shared.fetchLoggedMeals(userId: userId, date: Date())
            if let meals, !meals.isEmpty {
                let totalCal = meals.reduce(0) { $0 + (Int(Double($1.calories ?? 0) * $1.servings)) }
                let totalProtein = meals.reduce(0.0) { $0 + (($1.protein_g ?? 0) * $1.servings) }
                let totalCarbs = meals.reduce(0.0) { $0 + (($1.carbs_g ?? 0) * $1.servings) }
                let totalFat = meals.reduce(0.0) { $0 + (($1.fat_g ?? 0) * $1.servings) }
                context += "- Today's Nutrition: \(totalCal) cal eaten | P: \(Int(totalProtein))g C: \(Int(totalCarbs))g F: \(Int(totalFat))g\n"
            } else {
                context += "- Today's Nutrition: Nothing logged yet\n"
            }

            if let profile {
                context += "- Training Program: \(profile.active_program ?? "None active")\n"
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
                } else {
                    context += "- Recent Bloodwork: None logged\n"
                }
            } else {
                context += "- Recent Bloodwork: None logged\n"
            }

            let hk = HealthKitService.shared
            if hk.isAvailable && hk.isAuthorized {
                context += "\nAPPLE HEALTH (today, live):\n"
                context += "- Steps: \(hk.steps)\n"
                context += "- Active calories: \(Int(hk.activeCalories)) kcal | Resting: \(Int(hk.restingCalories)) kcal\n"
                context += "- Exercise minutes: \(Int(hk.exerciseMinutes)) | Flights: \(hk.flightsClimbed)\n"
                context += "- Distance: \(String(format: "%.2f", hk.distanceMiles)) mi\n"
                context += "- Sleep last night: \(String(format: "%.1f", hk.sleepHours))h\n"
                if let hrv = hk.hrv { context += "- HRV (SDNN): \(Int(hrv)) ms\n" }
                if let rhr = hk.restingHeartRate { context += "- Resting HR: \(Int(rhr)) bpm\n" }
                if let rr = hk.respiratoryRate { context += "- Respiratory rate: \(String(format: "%.1f", rr))\n" }
                if let o2 = hk.oxygenSaturation { context += "- SpO2: \(String(format: "%.1f", o2))%\n" }
                if let vo2 = hk.vo2Max { context += "- VO2 max: \(String(format: "%.1f", vo2))\n" }
                if let r = hk.recoveryScore { context += "- Recovery score: \(r)/100\n" }
                if let bf = hk.bodyFatPercentage { context += "- Body fat: \(String(format: "%.1f", bf))%\n" }
                if let lbm = hk.leanBodyMass { context += "- Lean body mass: \(String(format: "%.1f", lbm)) lb\n" }
                if let waist = hk.waistCircumference { context += "- Waist: \(String(format: "%.1f", waist)) in\n" }
                if let bmi = hk.bmi { context += "- BMI: \(String(format: "%.1f", bmi))\n" }
                if let g = hk.bloodGlucose { context += "- Blood glucose: \(Int(g)) mg/dL\n" }
                if let sys = hk.bloodPressureSystolic, let dia = hk.bloodPressureDiastolic {
                    context += "- BP: \(Int(sys))/\(Int(dia)) mmHg\n"
                }
                if hk.mindfulMinutesToday > 0 { context += "- Mindful minutes: \(Int(hk.mindfulMinutesToday))\n" }
                if !hk.workoutsToday.isEmpty {
                    let summaries = hk.workoutsToday.prefix(5).map { w -> String in
                        let mins = Int(w.duration / 60)
                        let kcal = w.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
                        return "\(w.workoutActivityType.displayName) \(mins)min \(Int(kcal))kcal"
                    }
                    context += "- HealthKit workouts today: \(summaries.joined(separator: "; "))\n"
                }
            } else {
                context += "\nApple Health: not connected or not authorized\n"
            }

            context += "- Opened from: \(sourceScreen)\n"

        } catch {
            context += "- (Could not load some user data)\n"
        }

        userContextBlock = shared + context
    }

    private var fullSystemPrompt: String {
        var prompt = staticSystemPrompt
        prompt += "\n"
        prompt += compoundDatabaseContext
        prompt += "\n"
        prompt += userContextBlock
        prompt += "\nWhen you have user data, reference it specifically. Say \"you're at 207 lbs with a 175 lb goal, so you have about 32 lbs to go\" — not \"based on your goals, you should keep working hard.\"\n"
        prompt += "If user data shows something concerning (e.g., very low calorie intake, dramatic weight swings, bloodwork flags), mention it proactively but without being alarmist.\n"
        return prompt
    }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isGenerating else { return }

        messages.append(PepMessage(role: .user, content: text))
        inputText = ""
        isGenerating = true

        conversationHistory.append(["role": "user", "content": text])

        Task {
            await ChatPersistenceService.shared.save(role: .user, content: text)
            await generateAIResponse()
        }
    }

    func submitTranscribedText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        inputText = trimmed
        sendMessage()
    }

    private func generateAIResponse() async {
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
            "max_tokens": 500
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
            request.timeoutInterval = 45

            let (data, _) = try await URLSession.shared.data(for: request)
            let responseText = extractTextFromResponse(data)

            conversationHistory.append(["role": "assistant", "content": responseText])
            await ChatPersistenceService.shared.save(role: .pep, content: responseText)

            let chunks = splitIntoChunks(responseText)
            for (index, chunk) in chunks.enumerated() {
                if index > 0 {
                    try? await Task.sleep(for: .milliseconds(Int.random(in: 300...600)))
                }
                let names = extractExerciseNames(from: chunk)
                messages.append(PepMessage(role: .pep, content: chunk, exerciseNames: names))
            }

            isGenerating = false
        } catch {
            appendFallbackResponse()
        }
    }

    private func extractTextFromResponse(_ data: Data) -> String {
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

    private func appendFallbackResponse() {
        let fallbacks = [
            "couldn't reach the server right now — try again in a sec",
            "connection dropped on my end\n\ntry sending that again",
            "something glitched — resend that?"
        ]
        let text = fallbacks.randomElement() ?? "try again"
        let chunks = splitIntoChunks(text)
        for chunk in chunks {
            messages.append(PepMessage(role: .pep, content: chunk))
        }
        isGenerating = false
    }

    func findExercise(named name: String) -> Exercise? {
        ExerciseLibrary.all.first { $0.name == name }
    }

    func extractExerciseNames(from content: String) -> [String] {
        Array(exerciseNames.filter { content.contains($0) })
    }

    func matchedCompound(named name: String) -> CompoundProfile? {
        CompoundDatabase.all.first { $0.name.lowercased() == name.lowercased() }
    }

    func clearChat() {
        messages = [
            PepMessage(role: .pep, content: "fresh start — what do you want to know?")
        ]
        conversationHistory = []
        Task {
            await ChatPersistenceService.shared.clearAll()
        }
    }
}

typealias FinnChatViewModel = PepChatViewModel
