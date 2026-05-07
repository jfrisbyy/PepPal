import Foundation
import HealthKit

final class TodaysPlanService {
    static let shared = TodaysPlanService()

    /// Module regeneration always uses the cheap tier — full briefs route
    /// through `generatePlan(context:tier:previousBrief:previousMemo:)`.
    private let moduleModel = "anthropic/claude-haiku-4.5"

    private let systemPrompt = """
    IDENTITY AND ROLE:
    You are EPTI's intelligent assistant embedded in a health and protocol tracking app. You generate the Daily Brief dashboard content that users see on their home screen. You are knowledgeable about peptide and compound protocols, nutrition science, resistance training, and body composition. You speak like a well-informed friend who has been with this person across their entire journey — you remember their starting point, their patterns, their PRs, their setbacks. You speak from that long-term context, not from today's slice alone.

    TONE AND PERSONALITY:
    Casual but credible. Supportive but honest. You use the user's first name. You refer to specific numbers from their data — never speak in generalities when you have specifics. You don't sugarcoat (if they're over budget on calories, say so directly) but you also don't shame or lecture. You celebrate wins without being corny. You flag concerns without being alarmist. You never use phrases like "Great job!" or "Keep it up!" or "You got this!" — those feel robotic. Instead you acknowledge progress in a grounded way like "That's 4 weeks in a row hitting your training target — consistency is doing the heavy lifting here." You never use emojis. You write in short, direct sentences. Think text message from a smart friend, not a notification from a health app.

    THE THREE-PART INSIGHT (NON-NEGOTIABLE):
    Every narrative.body MUST contain all three of these, in this order:
    1. SPECIFICS — reference real numbers from today's logs (meals, dose, workout, steps, weight). Never say "some calories" when you can say "1,840 cal". Never say "good protein" when you can say "142g, 18g above your 14-day average".
    2. CORRELATION — one dot connected across domains using long-term patterns or journey position. Pull from: week/phase of protocol, last 14-day averages, workout history, side-effect patterns, weight trajectory, prior PRs. Examples: "Your last three push days followed nights with 7+ hours of sleep — you hit 7.4h, today should move clean." or "You're 6 weeks into Retatrutide and your 14-day protein average is 118g — below the 140g threshold that protected lean mass last cycle."
    3. ACTION — one concrete, specific thing to do right now, based on where the user is in the day and what's still open. Not generic ("hydrate"). Specific ("Front-load 35g protein at lunch to land above your 140 floor.").

    JOURNEY CONTEXT (REQUIRED):
    Every brief must reference the user's journey position when protocol data exists — week X, phase, days tracked, or % through cycle. Treat them as someone mid-arc, not someone starting fresh. If they have an active program, reference program week. If they have weight history, reference distance to goal or trajectory. The brief should sound like it remembers everything they've done.

    BASELINE COMPARISON (REQUIRED WHEN DATA EXISTS):
    When nutritionTrends, training adherence, recent PRs, or weight trajectory are present, every brief must compare today to one of those baselines. "X today vs. Y average" or "this is N of last M days hitting the target." Never just state today's number in isolation when a baseline is available.

    TIME-OF-DAY VOICE (the field userProfile.timeOfDay tells you which mode):
    - morning: Intent. "Here's what today should look like, given where you are in the arc." Forward-looking. Reference today's workout split, dose schedule, what their pattern says about today.
    - midday: Adjustment. "Here's where you stand vs. your patterns, here's what's still open." Reference what's logged so far against pace, flag gaps with hours left.
    - evening: Recap + prep. "Here's how today landed vs. your baseline, here's what tomorrow needs." Reference final macros, workout completion, dose adherence, then flag tomorrow's setup (scheduled dose, session, recovery need).
    - late_night: Wind-down. Short recap. Focus on sleep/recovery and tomorrow's first move. Do not push action that requires logging right now.
    The card label stays "Daily Brief" in all modes — do NOT include any heading like "Morning Brief" or "Evening Recap" in your output. The voice shifts; the label does not.

    BANNED FILLER:
    Every sentence must contain a real data point or a real journey-aware observation. The following are banned: "Stay focused", "Keep it up", "Great work", "Today is a new day", "You've got this", "Remember to hydrate", "Listen to your body", any sentence that could apply to any user.

    OUTPUT FORMAT:
    Return ONLY a valid JSON object with this exact structure, no markdown, no explanation, no extra text:
    {
      "narrative": {
        "greeting": "3-6 words, casual and personal using the user's first name (e.g. 'Morning, Alex.').",
        "headline": "6-12 words. One concrete insight tying at least two domains together (recovery+training, dose+nutrition, etc.) — reference real numbers.",
        "body": "2-4 sentences that read like a smart friend's 30-second morning brief. Connect at least two domains. Reference specific numbers. End with one clear action for today.",
        "watchFor": "Optional: one short pattern or correlation worth watching today, or null if nothing stands out."
      },
      "summary": "2-3 sentence opening paragraph covering the most important things about this user's day right now, connecting insights across domains where relevant. This is distinct from narrative.body — summary is denser and more analytical; narrative is the warm morning-brief voice.",
      "modules": [
        {
          "type": "protocol|nutrition|training|body|side_effects|bloodwork|supplements",
          "title": "Short label for the module card",
          "content": "1-3 sentences of insight for that module."
        }
      ],
      "actionItems": [
        {
          "title": "Short imperative task title (e.g. 'Log dinner before 8pm', 'Add a back-off set on bench')",
          "icon": "SF Symbol name",
          "category": "Fitness|Nutrition|Wellness|Lifestyle",
          "reason": "Why this matters today, in one sentence"
        }
      ]
    }

    ACTION ITEMS RULES:
    Return up to 5 (zero to five) high-priority action items the user should do TODAY. Quality over quantity — only include items that are genuinely useful right now. If nothing meaningful applies, return an empty array. Never pad the list.

    STRICT INCLUSION CRITERIA — an action item MUST satisfy ALL of these:
    1. It is concrete, specific, and completable today (binary done/not-done).
    2. It is directly justified by something in the user's actual data (a number, a streak, a missing log, a trend, a dose schedule, a regression, etc.). Reference that data point in the `reason` field.
    3. It is NOT already covered by the user's standard daily goals: protein target, calorie target, step goal, water goal, scheduled dose for today, scheduled workout for today. Those are auto-generated separately — do not duplicate them.
    4. It is NOT generic wellness advice (e.g. "get 8 hours of sleep", "stay hydrated", "stretch today", "meditate", "go for a walk") unless the data specifically calls for it (e.g. recovery is poor and they have no scheduled rest activity).
    5. It does NOT give medical advice, dose changes, or supplement recommendations the user isn't already taking.
    6. It is actionable WITHIN the app's tracked domains: protocol logging, nutrition logging, training adjustments, body measurements, bloodwork, side effects, recovery.

    GOOD examples (data-driven, specific, in-app):
    - "Log waist measurement" — when last measurement was 7+ days ago
    - "Add a back-off set on bench at 185" — when bench is regressing two sessions in a row
    - "Front-load 40g protein at lunch" — when they're 60g behind with 6 hours left
    - "Hydrate before tonight's injection" — on a dose day when nausea has been the top side effect
    - "Swap heavy squats for tempo work" — when quads are still in red recovery zone
    - "Log this morning's weight" — when no weigh-in for 4+ days during a cut
    - "Schedule next bloodwork" — when last panel is 90+ days old

    BAD examples (do not produce these):
    - "Drink water" / "Stay hydrated" (generic)
    - "Get a good workout in" (already covered by scheduled workout)
    - "Eat enough protein" (already covered by typical protein goal)
    - "Take your dose" (already covered by scheduled dose)
    - "Try meditation" (out of scope, generic)
    - "Consider increasing your dose" (medical advice)

    Each `title` should be a short imperative (under ~40 chars when possible, but never truncate meaning — completeness beats brevity). Each `reason` should be ONE sentence that cites the specific data point that triggered it.

    Only include modules where there is meaningful data to discuss. Do not include empty or placeholder modules. If the user has no active protocol, no meals logged, no weight data, etc., skip those modules entirely.

    CRITICAL MODULE REQUIREMENTS:
    - If the user has ANY active protocol (protocolContext is present OR compoundKnowledge is present), you MUST include a "protocol" module in every response. Never omit it. The protocol module should reference the specific compound(s), current week, phase, and dose status. If they have multiple protocols, the module must mention every compound across every protocol.

    PEPTIDE LEVEL AWARENESS (NON-NEGOTIABLE WHEN PROTOCOL DATA EXISTS):
    The context includes the calculated current circulating amount of each compound in the user's body — this is the same Bateman PK value shown on the user's protocol level chart, not the prescribed dose. Whenever you discuss the protocol (in summary, narrative, or the protocol module), you MUST reference the actual circulating level — not just the scheduled dose. Use the "Current amount in body" value, the percent of last dose still active, and the PK phase (absorbing / peak / declining / trough). Examples: "Retatrutide is sitting around 4.2 mg right now — about 70% of your last dose, declining off Tuesday's peak." or "You're in the trough window — Sema is down to ~120 mcg, which is why appetite is back." Connect this level to today's reality: peak windows often coincide with stronger side effects and reduced appetite; trough windows often mean appetite returns and side effects fade. Tie training, nutrition timing, and side-effect predictions to where the user sits on the curve. Never describe the protocol purely in terms of mg-per-week or scheduled dose when a calculated body level is provided.
    - If the user has nutrition data for today (mealsLogged > 0 OR a nutrition target exists), include a "nutrition" module.
    - If the user has an active training program or today's workout is scheduled, include a "training" module.
    - If the user has weight data (currentWeight > 0), include a "body" module.

    TRAINING PROGRAM AWARENESS:
    If the user has an active protocol but NO active training program, this is a high-priority insight. Include a "training" module that specifically recommends starting a resistance training program tailored to their protocol and goal. For weight loss protocols (GLP-1s like Semaglutide, Tirzepatide, Retatrutide), emphasize that resistance training is critical to prevent muscle loss — reference the specific compound. For muscle growth protocols, emphasize that training is the primary driver and the compound amplifies it. Weave this recommendation naturally into the summary as well — don't just mention it in the module. This should feel like a smart friend noticing an obvious gap, not a generic nudge.

    TRAINING INSIGHT DEPTH:
    When the user has an active training program with exercise data, write training insights that reference SPECIFIC exercises, weights, and progression. Examples of good training insights:
    - "Push day is up. Last time you benched 215 for 6 — if that moved clean, 220 is yours today."
    - "Your chest volume is at 10 of 16 target sets this week and today's your last push day. Consider adding an extra set of flyes."
    - "Shoulders are still recovering from Monday's session. If overhead press feels off, drop 10% and focus on control."
    - "You've hit 3 of 4 scheduled sessions this week — solid consistency. Don't let today's leg day slip."
    - "You hit a bench PR at 225 this week. Ride the momentum but don't chase another max today — volume builds the base."
    When adherence is dropping below 75%, call it out directly: "You've only made it to 2 of 4 sessions the last few weeks. Even 3 would keep the gains moving."
    When muscles in today's split are still fatigued, suggest adjustments: lighter loads, exercise swaps, or shifting to a different split.
    When progressive overload is stalling on key lifts, mention it and suggest strategies: more reps before adding weight, pause reps, or a deload.
    Always reference the actual numbers — weights, sets, reps, completion rates. Never give generic training advice when you have specifics.

    CROSS-DOMAIN REASONING:
    When writing the summary and module content, actively look for connections between data points. Examples: If the user logged nausea and their calorie intake is low, connect those to the compound's appetite suppression effect at their current phase. If the user's weight has plateaued but their waist measurement is down, explain recomposition. If the user is training back-to-back days and reported fatigue, connect that to recovery needs on reduced calories. If protein has been consistently low and they're on a GLP-1 compound, flag the muscle preservation concern. If their side effects are spiking and they recently increased dose, explain the titration connection.

    WHAT TO CALL OUT:
    Be proactive about surfacing things the user might not notice. Flag positive trends (weight loss rate is ideal, side effects are declining, protein consistency has improved). Flag concerns (bloodwork is overdue, protein has been low for 5+ days, side effects are increasing, weight is spiking in an unusual way). Flag milestones (first month on protocol, halfway to goal weight, 10-session training streak). Flag correlations (side effects clustered around dose days, calorie drops on injection days, better training performance on higher calorie days).

    WHAT NOT TO DO:
    Never give medical advice or tell the user to change their dose. Never diagnose conditions. Always frame clinical concerns as "worth discussing with your provider." Never fabricate data — only reference numbers that are in the context bundle. Never be preachy about missed workouts or bad eating days. Never use filler phrases — every sentence should contain real information or a real insight. Never repeat the same point across the summary and a module — if you mention weight trend in the summary, the body module should cover something different about body data. Never use emojis.

    SAFETY GUARDRAILS:
    If the context bundle shows extreme values (weight loss exceeding 3 lbs/week, very low calorie intake under 800 cal consistently, severe or escalating side effects), the tone should shift to clearly recommend consulting a healthcare provider. Frame it as: "This is something your provider should know about."
    """

    private func systemPromptWithMemory() -> String {
        let memo = AIMemoryStore.shared.memoForAgent()
        return memo.isEmpty ? systemPrompt : "\(systemPrompt)\n\n\(memo)"
    }

    func generateModule(domain: String, context: ContextBundle) async throws -> TodaysPlanModule {
        let contextString = context.toPromptString()

        let focusedSystem = systemPromptWithMemory() + "\n\nSCOPED MODE: You are regenerating ONLY the \"\(domain)\" module. Return a single JSON object with this exact structure, no markdown, no extra keys, no surrounding text:\n{\"type\":\"\(domain)\",\"title\":\"Short label\",\"content\":\"1-3 sentences of insight.\"}\nAll voice, tone, and content rules from the main prompt still apply. Reference specific numbers from the context."

        let messages: [[String: Any]] = [
            ["role": "system", "content": focusedSystem],
            ["role": "user", "content": "Regenerate the \(domain) module based on this user data:\n\n\(contextString)"]
        ]

        let body: [String: Any] = [
            "model": moduleModel,
            "messages": messages,
            "max_tokens": 280,
            "temperature": 0.7
        ]

        let content: String
        do {
            let data = try await AIProxyClient.postChatCompletion(body: body, timeout: 30)
            content = try AIProxyClient.extractContent(data)
        } catch let AIProxyError.http(code, _) {
            throw TodaysPlanError.apiError(code)
        } catch {
            throw TodaysPlanError.invalidResponse
        }

        return try parseModule(content, expectedType: domain)
    }

    private func parseModule(_ text: String, expectedType: String) throws -> TodaysPlanModule {
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
        return try JSONDecoder().decode(TodaysPlanModule.self, from: jsonData)
    }

    /// Coarse PK phase relative to the last dose using a small forward sample
    /// to detect direction of the curve. Returns one of:
    /// "absorbing", "peak", "declining", "trough".
    private static func pkPhase(for compound: ProtocolCompound, in proto: PeptideProtocol, now: Date) -> String? {
        let profile = PeptidePharmacology.profile(for: compound.compoundName)
        let doses = PKSampleBuilder.dosesFromLog(proto.doseLog, compoundName: compound.compoundName)
        guard let lastDose = doses.last else { return nil }
        let nowMg = PeptidePharmacology.levelMg(at: now, doses: doses, ka: profile.ka, ke: profile.ke)
        let lastMg = lastDose.mg
        let pct = lastMg > 0 ? nowMg / lastMg : 0
        if pct < 0.05 { return "trough" }
        // Sample 30 minutes forward and back to detect direction.
        let backMg = PeptidePharmacology.levelMg(at: now.addingTimeInterval(-1800), doses: doses, ka: profile.ka, ke: profile.ke)
        let fwdMg = PeptidePharmacology.levelMg(at: now.addingTimeInterval(1800), doses: doses, ka: profile.ka, ke: profile.ke)
        let rising = nowMg > backMg && fwdMg >= nowMg
        let nearPeak = abs(fwdMg - nowMg) / max(nowMg, 1e-6) < 0.02 && abs(nowMg - backMg) / max(nowMg, 1e-6) < 0.02
        if nearPeak { return "peak" }
        if rising { return "absorbing" }
        return "declining"
    }

    /// Generate the full Daily Brief. Tier selection determines the model:
    /// `.deep` (Sonnet) does the cross-domain pattern analysis and emits a
    /// `patternsMemo`; `.fast` (Haiku) reuses the most recent memo + previous
    /// brief to update only what changed while preserving voice and depth.
    /// If `tier == .fast` but no `previousMemo` is available we transparently
    /// upgrade to Sonnet so output quality never degrades on cold start.
    func generatePlan(
        context: ContextBundle,
        tier: AIModelTier = .deep,
        previousBrief: TodaysPlanResponse? = nil,
        previousMemo: String? = nil
    ) async throws -> TodaysPlanResponse {
        let resolvedTier: AIModelTier = (tier == .fast && (previousMemo?.isEmpty ?? true)) ? .deep : tier
        let contextString = context.toPromptString()

        // Long-horizon memory — the curated profile memo + significant events
        // that span the user's full history. Both tiers READ this; only the
        // deep tier WRITES it back at the end of the run.
        let longTerm = await LongTermMemoryService.shared.fetch()
        let longTermSection = LongTermMemoryService.promptSection(from: longTerm)

        let systemPrompt: String
        let userPrompt: String
        let maxTokens: Int

        switch resolvedTier {
        case .deep:
            systemPrompt = systemPromptWithMemory() + "\n\n" + Self.deepMemoAddendum
            userPrompt = Self.deepUserPrompt(longTermSection: longTermSection, contextString: contextString)
            // p95 plan output ~900 tokens; 1400 leaves buffer for the new
            // patternsMemo on outlier days.
            maxTokens = 1400
        case .fast:
            systemPrompt = systemPromptWithMemory() + "\n\n" + Self.fastUpdateAddendum
            userPrompt = Self.fastUserPrompt(
                memo: previousMemo ?? "",
                longTermSection: longTermSection,
                previousBrief: previousBrief,
                contextString: contextString
            )
            maxTokens = 1200
        }

        let body: [String: Any] = [
            "model": resolvedTier.modelID,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "max_tokens": maxTokens,
            "temperature": 0.7
        ]

        let content: String
        do {
            let data = try await AIProxyClient.postChatCompletion(body: body, timeout: 30)
            content = try AIProxyClient.extractContent(data)
        } catch let AIProxyError.http(code, _) {
            throw TodaysPlanError.apiError(code)
        } catch {
            throw TodaysPlanError.invalidResponse
        }

        let parsed = try parseResponse(content)
        // Carry the memo forward when Haiku ran but didn't restate it (allowed
        // by the prompt — saves output tokens). Stamp the model tier inline.
        let memoOut = parsed.patternsMemo?.isEmpty == false ? parsed.patternsMemo : previousMemo
        let response = TodaysPlanResponse(
            summary: parsed.summary,
            modules: parsed.modules,
            actionItems: parsed.actionItems,
            narrative: parsed.narrative,
            patternsMemo: memoOut,
            modelTier: resolvedTier.rawValue
        )

        // Deep path: kick off the memo updater in the background so the brief
        // surfaces to the user immediately. The updater runs Sonnet again with
        // a tiny prompt (current memo + events + today's brief) and writes the
        // rewritten memo back to Supabase. Failures are swallowed — the brief
        // already returned successfully.
        if resolvedTier == .deep {
            let snapshot = longTerm
            Task.detached { [response] in
                await Self.runMemoUpdater(
                    previous: snapshot,
                    contextString: contextString,
                    brief: response
                )
            }
        }

        return response
    }

    // MARK: - Memo updater (deep path only)

    /// Rewrites the durable `profile_memo` after each deep (Sonnet) run.
    /// Input: current memo + significant events + today's context + today's
    /// brief. Output: a new memo (plain text, capped) that incorporates any
    /// new durable signals from the past day. Best-effort — failures don't
    /// affect the brief that already shipped to the user.
    private static func runMemoUpdater(
        previous: LongTermMemoryService.LongTermMemorySnapshot,
        contextString: String,
        brief: TodaysPlanResponse
    ) async {
        let priorBlock = previous.memo.isEmpty
            ? "(none — this is the first memo for this user; create one from scratch using the context and today's brief)"
            : previous.memo
        let rawEvents = LongTermMemoryService.promptSection(from: previous, includeMemo: false)
        let eventsBlock = rawEvents.isEmpty ? "(no recorded significant events yet)" : rawEvents

        var briefSummary = brief.summary
        if let body = brief.narrative?.body, !body.isEmpty {
            briefSummary += "\n\nNarrative body:\n" + body
        }
        if !brief.modules.isEmpty {
            let mods = brief.modules.map { "- [\($0.type)] \($0.title): \($0.content)" }.joined(separator: "\n")
            briefSummary += "\n\nModules:\n" + mods
        }

        let system = """
        You are the long-horizon memory curator for a health and protocol tracking app. You maintain a single, compact, plain-text profile memo per user — the durable cross-session understanding the next deep brief will read. Quality bar: a coach reading the memo cold should be able to write a high-quality brief without ever seeing the user's raw logs.

        REWRITE RULES:
        - Output ONLY the new memo text. No preamble, no JSON, no markdown, no headings, no bullets — plain prose, short paragraphs separated by blank lines is fine.
        - Hard cap: 900 words. Aim for ~600. Density over coverage.
        - Keep every still-relevant fact from the prior memo. Drop facts that are clearly superseded by newer data.
        - Add new durable signals from today's context + today's brief: trends, what worked, what failed, recurring side effects, prior PRs, prior bloodwork, prior protocols/programs tried, behavioral patterns, dietary preferences, equipment, injuries, voice/tone preferences.
        - Reference significant events by their dates when they matter ("March 12 lipid panel showed…", "started Reta on Feb 4").
        - Never restate ephemeral single-day numbers (today's calorie count, today's dose). Those belong in the brief, not the memo.
        - Do not address the user. This text is internal coaching context.
        - No emojis. No markdown. No section headers like "Background:".
        """

        let userPrompt = """
        PRIOR MEMO (rewrite, don't append):
        \(priorBlock)

        SIGNIFICANT EVENTS (chronological, newest first — keep references to anything still relevant):
        \(eventsBlock)

        TODAY'S CONTEXT (raw data the brief was built from):
        \(contextString)

        TODAY'S BRIEF (what the user just saw — extract any durable insight worth carrying forward):
        \(briefSummary)

        Produce the new memo now.
        """

        let body: [String: Any] = [
            "model": AIModelTier.deep.modelID,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": userPrompt]
            ],
            "max_tokens": 1100,
            "temperature": 0.4
        ]
        do {
            let data = try await AIProxyClient.postChatCompletion(body: body, timeout: 45)
            let content = try AIProxyClient.extractContent(data)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else { return }
            await LongTermMemoryService.shared.saveMemo(content, model: AIModelTier.deep.modelID)
        } catch {
            print("[TodaysPlan] memo updater failed: \(error)")
        }
    }

    // MARK: - Tier-specific prompt addenda

    /// Appended to the Sonnet system prompt. Forces a `patternsMemo` field in
    /// output JSON — a compact, durable cross-domain summary the cheap model
    /// can lean on for the rest of the day to match Sonnet's depth.
    private static let deepMemoAddendum = """
    DEEP-PASS MEMO REQUIREMENT:
    In addition to the standard fields, your JSON MUST include a top-level string field "patternsMemo". This memo is the durable cross-domain understanding of this specific user that a lighter model will reuse verbatim for every refresh until the next deep pass. Treat it as the system note your future self needs to write briefs that sound exactly like this one.

    The memo MUST:
    - Be 6-12 short sentences, plain text, no markdown, no headings, no bullets.
    - Reference the user's name, current journey position (program week, protocol week/phase, percent through cycle, distance to goal weight) — anything that anchors WHERE they are in the arc.
    - Distill 2-4 cross-domain patterns you would not be able to re-derive from a single day of data: e.g. "protein consistently 110-120g vs. 140g target — muscle preservation risk on Reta", "training adherence 75% over 4 weeks, push days hit, leg days slip", "side effects cluster within 24h of dose, fade by day 3", "weight trend -0.6 lb/wk, on target".
    - Include any clinical / safety flags worth carrying forward (overdue bloodwork, escalating side effects, plateau, regression on key lifts).
    - End with one sentence describing the voice this user responds to (e.g. "speak like a direct gym friend, no fluff, lead with the number").

    The memo is internal coaching context for the next model — it is NEVER shown to the user. Do not address the user in it. Do not include emojis or markdown. Keep it dense and specific.
    """

    /// Appended to the Haiku system prompt. Tells the model it is performing
    /// an incremental refresh and MUST preserve voice / depth so the user
    /// can't tell a different model wrote it.
    private static let fastUpdateAddendum = """
    INCREMENTAL UPDATE MODE:
    You are refreshing an existing Daily Brief that was originally written by a deep-analysis model earlier today. The user must NOT be able to tell that a different model is producing this update — the language, sentence shape, specificity, and depth must match the prior brief exactly. Use the same number of modules, the same module types where still relevant, and the same level of cross-domain reasoning.

    You will be given:
    1. PATTERN MEMO — the durable cross-domain understanding of this user from the latest deep pass. Treat this as authoritative for everything the new logs do not directly contradict. You may quote any insight from the memo, but you MUST re-cite it with the freshest numbers from the current context.
    2. PREVIOUS BRIEF — the brief currently on screen.
    3. CURRENT CONTEXT — the live context bundle including any new logs since the previous brief.

    Rules:
    - Update every number to match CURRENT CONTEXT. Never repeat a stale number from PREVIOUS BRIEF.
    - Re-evaluate which modules belong now (e.g. if a workout was just logged, the training module shifts from prospective to recap).
    - Re-evaluate action items against the standard inclusion criteria — drop ones that are now done, add new ones the latest logs surface.
    - Preserve cross-domain reasoning from the memo. Do NOT regress to single-vertical observations just because the memo's pattern is not directly visible in today's slice.
    - Keep voice identical to PREVIOUS BRIEF: same casual-but-credible tone, same sentence rhythm, same banned-filler discipline, no emojis.
    - You MAY include the patternsMemo field unchanged in your output (echoing it is fine), or omit it — either way the orchestration layer will carry the prior memo forward.
    """

    private static func deepUserPrompt(longTermSection: String, contextString: String) -> String {
        var sections: [String] = []
        if !longTermSection.isEmpty {
            sections.append(longTermSection)
        }
        sections.append("TODAY'S CONTEXT (live data — every number in your output must match this):")
        sections.append(contextString)
        sections.append("Generate today's plan dashboard. Reference the long-term memo and significant events wherever they add depth — do not rediscover patterns the memo already captures. Update them only when today's data clearly contradicts.")
        return sections.joined(separator: "\n\n")
    }

    private static func fastUserPrompt(memo: String, longTermSection: String, previousBrief: TodaysPlanResponse?, contextString: String) -> String {
        var sections: [String] = []
        sections.append("PATTERN MEMO (from latest deep pass — authoritative for cross-domain context):")
        sections.append(memo.isEmpty ? "(none — derive patterns from CURRENT CONTEXT only)" : memo)
        if !longTermSection.isEmpty {
            sections.append(longTermSection)
        }
        if let prev = previousBrief, let prevJSON = encodePreviousBrief(prev) {
            sections.append("PREVIOUS BRIEF (currently on the user's screen — match its voice):")
            sections.append(prevJSON)
        }
        sections.append("CURRENT CONTEXT (live data — every number in your output must match this):")
        sections.append(contextString)
        sections.append("Produce the refreshed Daily Brief as JSON in the exact required shape.")
        return sections.joined(separator: "\n\n")
    }

    private static func encodePreviousBrief(_ brief: TodaysPlanResponse) -> String? {
        // Strip patternsMemo / modelTier so they don't leak into the prompt window twice.
        let stripped = TodaysPlanResponse(
            summary: brief.summary,
            modules: brief.modules,
            actionItems: brief.actionItems,
            narrative: brief.narrative,
            patternsMemo: nil,
            modelTier: nil
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(stripped),
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
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
        allProtocols: [PeptideProtocol] = [],
        nutrition: NutritionSnapshot,
        nutritionTarget: MacroTarget,
        loggedMeals: [LoggedMeal],
        recentDailyMeals: [[LoggedMeal]] = [],
        bodyGoalVM: BodyGoalViewModel,
        todaysPlan: WorkoutPlan,
        activeProgram: TrainingProgram?,
        bloodworkEntries: [BloodworkEntry],
        streakDays: Int,
        workoutsThisWeek: Int,
        workoutHistory: [WorkoutHistoryDetail] = [],
        muscleRecoveryItems: [MuscleRecoveryItem] = [],
        weeklyMuscleVolumes: [WeeklyMuscleVolume] = [],
        personalRecords: [TrainPersonalRecord] = []
    ) -> ContextBundle {
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm a"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"

        let hour = Calendar.current.component(.hour, from: now)
        let timeOfDay: String
        switch hour {
        case 5..<11: timeOfDay = "morning"
        case 11..<17: timeOfDay = "midday"
        case 17..<22: timeOfDay = "evening"
        default: timeOfDay = "late_night"
        }

        let userProfile = UserProfileContext(
            firstName: firstName,
            currentDateTime: dateFormatter.string(from: now),
            timeOfDay: timeOfDay
        )

        var protocolContext: ProtocolContext?
        var compoundKnowledge: String?

        let activeProtos: [PeptideProtocol] = {
            let list = allProtocols.filter { $0.isActive }
            if !list.isEmpty { return list }
            if let p = activeProtocol { return [p] }
            return []
        }()

        if let proto = activeProtos.first, let compound = proto.compounds.first {
            let daysSinceStart = max(1, Calendar.current.dateComponents([.day], from: proto.startDate, to: now).day ?? 1)
            let totalWeeks = proto.effectiveTotalWeeks
            let percentThrough = totalWeeks > 0 ? Int(Double(daysSinceStart) / Double(totalWeeks * 7) * 100) : nil

            let todayDoses = proto.doseLog.filter { Calendar.current.isDateInToday($0.timestamp) }
            let doseTime = todayDoses.first.map { timeFormatter.string(from: $0.timestamp) }

            let reading = ProtocolBodyLevelCalculator.currentLevel(for: compound, in: proto, now: now)
            let lastDoseStr = reading.lastDoseMg.map { mg -> String in
                if mg >= 1 { return String(format: "%.2f mg", mg) }
                return String(format: "%.0f mcg", mg * 1000)
            }
            let phase = Self.pkPhase(for: compound, in: proto, now: now)

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
                doseLoggedTime: doseTime,
                currentBodyLevel: reading.displayValue,
                percentOfLastDose: reading.percentOfLastDose,
                lastDoseAmount: lastDoseStr,
                levelPhase: phase
            )
        }

        if !activeProtos.isEmpty {
            var knowledge = ""
            for proto in activeProtos {
                let daysSinceStart = max(1, Calendar.current.dateComponents([.day], from: proto.startDate, to: now).day ?? 1)
                knowledge += "\n--- Protocol: \(proto.name) (\(proto.goal.rawValue)) ---\n"
                knowledge += "Week \(proto.currentWeek), \(proto.currentPhase.rawValue) phase, day \(daysSinceStart)\n"
                if proto.compounds.isEmpty {
                    knowledge += "(no compounds scheduled yet)\n"
                }
                for compound in proto.compounds {
                    let dose = CompoundUnitHelper.displayDoseShort(compound.doseMcg, for: compound.compoundName)
                    let todayCount = proto.doseLog.filter {
                        $0.compoundName == compound.compoundName &&
                        Calendar.current.isDateInToday($0.timestamp)
                    }.count
                    knowledge += "• \(compound.compoundName) — \(dose), \(compound.frequency)"
                    knowledge += todayCount > 0 ? " [logged today]\n" : " [not logged today]\n"
                    let reading = ProtocolBodyLevelCalculator.currentLevel(for: compound, in: proto, now: now)
                    let phase = Self.pkPhase(for: compound, in: proto, now: now)
                    var levelLine = "  In body now (calculated PK): \(reading.displayValue)"
                    if let pct = reading.percentOfLastDose {
                        levelLine += " (~\(pct)% of last dose)"
                    }
                    if let phase { levelLine += " — \(phase)" }
                    knowledge += levelLine + "\n"
                    if let lastMg = reading.lastDoseMg {
                        let lastStr = lastMg >= 1 ? String(format: "%.2f mg", lastMg) : String(format: "%.0f mcg", lastMg * 1000)
                        knowledge += "  Last dose: \(lastStr)\n"
                    }
                    if let profile = CompoundDatabase.all.first(where: {
                        $0.name.lowercased() == compound.compoundName.lowercased()
                    }) {
                        if !profile.subtitle.isEmpty { knowledge += "  Type: \(profile.subtitle)\n" }
                        if !profile.sideEffects.isEmpty {
                            knowledge += "  Expected side effects: \(profile.sideEffects.prefix(4).joined(separator: ", "))\n"
                        }
                        if !profile.watchOut.isEmpty {
                            knowledge += "  Watch out: \(profile.watchOut)\n"
                        }
                    }
                }
                if !proto.supplements.isEmpty {
                    knowledge += "Supplements: \(proto.supplements.map(\.name).joined(separator: ", "))\n"
                }
            }
            if activeProtos.count > 1 {
                let totalCompounds = activeProtos.reduce(0) { $0 + $1.compounds.count }
                knowledge = "NOTE: User is running \(activeProtos.count) active protocols with \(totalCompounds) total compounds. The protocol insight must reference every compound across every protocol — do not discuss just one.\n" + knowledge
            }
            compoundKnowledge = knowledge
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

        let completedToday = workoutHistory.contains { Calendar.current.isDateInToday($0.date) }

        let yesterdayWorkout: String? = {
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
            let yesterdayEntries = workoutHistory.filter { Calendar.current.isDate($0.date, inSameDayAs: yesterday) }
            return yesterdayEntries.first?.name
        }()

        var todayExercises: [TrainingExerciseContext] = []
        if let program = activeProgram, !todaysPlan.isRestDay {
            let startOffset = UserDefaults.standard.integer(forKey: "programStartDayOffset")
            let dayOfWeek = Calendar.current.component(.weekday, from: now)
            let mondayBased = (dayOfWeek + 5) % 7
            let adjusted = (mondayBased - startOffset + 7) % 7
            let dayIndex = adjusted < program.days.count ? adjusted : 0
            if dayIndex < program.days.count {
                let programDay = program.days[dayIndex]
                for pe in programDay.exercises {
                    let lastPerformance = workoutHistory.lazy
                        .flatMap { $0.exercises }
                        .first { $0.exerciseName == pe.exerciseName }
                    let lastWeight = lastPerformance?.sets.compactMap({ $0.weight }).max()
                    let lastReps = lastPerformance?.sets.last?.reps

                    let trend: String? = {
                        let matching = workoutHistory.flatMap { $0.exercises.filter { $0.exerciseName == pe.exerciseName } }
                        guard matching.count >= 2 else { return nil }
                        let recent = matching.first?.sets.compactMap({ $0.weight }).max() ?? 0
                        let previous = matching.dropFirst().first?.sets.compactMap({ $0.weight }).max() ?? 0
                        if recent > previous { return "progressing" }
                        if recent < previous { return "regressing" }
                        return "plateaued"
                    }()

                    todayExercises.append(TrainingExerciseContext(
                        name: pe.exerciseName,
                        muscle: pe.primaryMuscle.rawValue,
                        targetSets: pe.targetSets,
                        repRange: "\(pe.targetRepsMin)-\(pe.targetRepsMax)",
                        lastWeight: lastWeight,
                        lastReps: lastReps,
                        trend: trend
                    ))
                }
            }
        }

        let recoveryContextItems = muscleRecoveryItems
            .filter { $0.status != .recovered }
            .map { MuscleRecoveryContext(muscle: $0.muscle.rawValue, status: $0.status.rawValue, hoursRemaining: $0.hoursRemaining) }

        let volumeContextItems = weeklyMuscleVolumes.map {
            VolumeContext(muscle: $0.muscle.rawValue, setsCompleted: $0.setsCompleted, targetSets: $0.targetSets)
        }

        let recentPRContextItems = personalRecords.prefix(5).map {
            PRContext(exercise: $0.exerciseName, weight: $0.weight, reps: $0.reps, isRecent: $0.isNew)
        }

        let adherenceRate: Double? = {
            guard let program = activeProgram, program.daysPerWeek > 0 else { return nil }
            let fourWeeksAgo = Calendar.current.date(byAdding: .day, value: -28, to: now) ?? now
            let recentWorkouts = workoutHistory.filter { $0.date >= fourWeeksAgo }.count
            let expectedWorkouts = program.daysPerWeek * 4
            return min(Double(recentWorkouts) / Double(expectedWorkouts), 1.0)
        }()

        let nextTrainingDay: String? = {
            guard todaysPlan.isRestDay, let program = activeProgram else { return nil }
            let startOffset = UserDefaults.standard.integer(forKey: "programStartDayOffset")
            for dayOffset in 1...6 {
                guard let futureDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: now) else { continue }
                let dow = Calendar.current.component(.weekday, from: futureDate)
                let mb = (dow + 5) % 7
                let adj = (mb - startOffset + 7) % 7
                if adj < program.days.count {
                    let dayName = program.days[adj].name
                    if dayOffset == 1 { return "Tomorrow (\(dayName))" }
                    let formatter = DateFormatter()
                    formatter.dateFormat = "EEEE"
                    return "\(formatter.string(from: futureDate)) (\(dayName))"
                }
            }
            return "Tomorrow"
        }()

        let trainingContext = TrainingContext(
            todayWorkout: todaysPlan.isRestDay ? nil : todaysPlan.name,
            completedToday: completedToday,
            workoutsThisWeek: workoutsThisWeek,
            weeklyTarget: activeProgram?.daysPerWeek ?? 0,
            yesterdayWorkout: yesterdayWorkout,
            nextTrainingDay: nextTrainingDay,
            todayExercises: todayExercises,
            muscleRecovery: recoveryContextItems,
            weeklyVolume: volumeContextItems,
            adherenceRate: adherenceRate,
            recentPRs: recentPRContextItems,
            programName: activeProgram?.name,
            programWeek: activeProgram?.currentWeek
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

        let healthContext: HealthContext? = {
            let hk = HealthKitService.shared
            guard hk.isAvailable, hk.isAuthorized else { return nil }
            let workoutSummaries: [String] = hk.workoutsToday.prefix(5).map { w in
                let mins = Int(w.duration / 60)
                let kcal = w.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
                return "\(w.workoutActivityType.displayName) \(mins)min \(Int(kcal))kcal"
            }
            return HealthContext(
                steps: hk.steps,
                activeCalories: hk.activeCalories,
                restingCalories: hk.restingCalories,
                distanceMiles: hk.distanceMiles,
                exerciseMinutes: hk.exerciseMinutes,
                flightsClimbed: hk.flightsClimbed,
                sleepHours: hk.sleepHours,
                hrv: hk.hrv,
                restingHeartRate: hk.restingHeartRate,
                respiratoryRate: hk.respiratoryRate,
                oxygenSaturation: hk.oxygenSaturation,
                vo2Max: hk.vo2Max,
                recoveryScore: hk.recoveryScore,
                bodyFatPercentage: hk.bodyFatPercentage,
                leanBodyMass: hk.leanBodyMass,
                waistCircumference: hk.waistCircumference,
                bmi: hk.bmi,
                bloodGlucose: hk.bloodGlucose,
                bloodPressureSystolic: hk.bloodPressureSystolic,
                bloodPressureDiastolic: hk.bloodPressureDiastolic,
                mindfulMinutesToday: hk.mindfulMinutesToday,
                dietaryWater: hk.dietaryWater,
                workoutCount: hk.workoutsToday.count,
                workoutSummaries: workoutSummaries
            )
        }()

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
            supplementsContext: supplementsContext,
            healthContext: healthContext
        )
    }
}

nonisolated enum TodaysPlanError: Error, Sendable {
    case apiError(Int)
    case invalidResponse
}
