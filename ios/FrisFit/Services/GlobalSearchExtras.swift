import Foundation
import SwiftUI

// MARK: - Smart ranking (prefix → word boundary → fuzzy)

nonisolated enum SearchRanker: Sendable {
    /// Score in [0...1000]. Higher is better. Returns 0 for no match (caller should still
    /// consider whether to keep the row, since the source filter may be more permissive).
    static func score(query: String, candidates: [String]) -> Int {
        let q = sanitize(query, maxLen: 40)
        guard !q.isEmpty else { return 0 }
        var best = 0
        for raw in candidates {
            let c = sanitize(raw, maxLen: 80)
            if c.isEmpty { continue }
            if c == q { return 1000 }
            if c.hasPrefix(q) { best = max(best, 850) ; continue }
            if hasWordBoundaryPrefix(c, q) { best = max(best, 700) ; continue }
            if c.contains(q) { best = max(best, 550) ; continue }
            // Fuzzy fallback — bounded and safe.
            if let dist = safeBestEditDistance(query: q, in: c) {
                let tolerance = max(1, q.count / 4)
                if dist <= tolerance {
                    let cappedDist = min(dist, 5)
                    let bonus = max(0, 400 - cappedDist * 80)
                    best = max(best, bonus)
                }
            }
        }
        return best
    }

    private static func sanitize(_ s: String, maxLen: Int) -> String {
        let trimmed = s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLen else { return trimmed }
        return String(trimmed.prefix(maxLen))
    }

    private static func hasWordBoundaryPrefix(_ haystack: String, _ needle: String) -> Bool {
        guard !haystack.isEmpty, !needle.isEmpty else { return false }
        var inWord = false
        var idx = haystack.startIndex
        while idx < haystack.endIndex {
            let ch = haystack[idx]
            let isWordChar = ch.isLetter || ch.isNumber
            if isWordChar && !inWord {
                let remaining = haystack[idx...]
                if remaining.hasPrefix(needle) { return true }
            }
            inWord = isWordChar
            idx = haystack.index(after: idx)
        }
        return false
    }

    /// Safe wrapper that always returns nil rather than crashing on edge cases.
    private static func safeBestEditDistance(query: String, in haystack: String) -> Int? {
        let qChars = Array(query)
        let hChars = Array(haystack)
        guard !qChars.isEmpty, !hChars.isEmpty else { return nil }
        let qLen = qChars.count
        let hLen = hChars.count
        // Avoid pathological work — bail out for absurd size mismatches.
        if qLen > hLen + 4 { return nil }
        if qLen > 40 || hLen > 80 { return nil }

        let windowMin = max(qLen - 1, 1)
        let windowMax = min(qLen + 1, hLen)
        guard windowMin >= 1, windowMin <= windowMax else { return nil }

        let hardCeiling = max(qLen, 16)
        var bestDist = hardCeiling

        for wLen in windowMin...windowMax {
            guard wLen > 0, wLen <= hLen else { continue }
            var i = 0
            while i + wLen <= hLen {
                // Defensive bounds — avoid any chance of an out-of-range slice.
                let upper = i + wLen
                guard upper <= hLen, i >= 0 else { break }
                let window = Array(hChars[i..<upper])
                let d = levenshtein(qChars, window, ceiling: bestDist)
                if d < bestDist { bestDist = d }
                if bestDist == 0 { return 0 }
                i += 1
            }
        }
        return bestDist >= hardCeiling ? nil : bestDist
    }

    private static func levenshtein(_ a: [Character], _ b: [Character], ceiling: Int) -> Int {
        let n = a.count
        let m = b.count
        guard n > 0, m > 0 else { return max(n, m) }
        let diff = n > m ? n - m : m - n
        if diff > ceiling { return ceiling }

        var prev = [Int]()
        prev.reserveCapacity(m + 1)
        for v in 0...m { prev.append(v) }
        var curr = [Int](repeating: 0, count: m + 1)

        for i in 1...n {
            curr[0] = i
            var rowMin = curr[0]
            for j in 1...m {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                let del = prev[j] &+ 1
                let ins = curr[j - 1] &+ 1
                let sub = prev[j - 1] &+ cost
                let v = min(del, min(ins, sub))
                curr[j] = v
                if v < rowMin { rowMin = v }
            }
            if rowMin > ceiling { return ceiling }
            swap(&prev, &curr)
        }
        return prev[m]
    }
}

// MARK: - Recent items store (recently viewed entities, not just queries)

nonisolated enum RecentItemKind: String, Codable, Sendable {
    case exercise
    case food
    case compound
    case user
    case circle
}

nonisolated struct RecentSearchItem: Codable, Identifiable, Hashable, Sendable {
    let kind: RecentItemKind
    let referenceId: String
    let title: String
    let subtitle: String
    let viewedAt: Date

    var id: String { "\(kind.rawValue)-\(referenceId)" }
}

@MainActor
final class RecentItemsStore {
    static let shared = RecentItemsStore()
    private let key = "global_search_recent_items_v1"
    private let maxCount = 12

    private init() {}

    func load() -> [RecentSearchItem] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let items = try? JSONDecoder().decode([RecentSearchItem].self, from: data) else {
            return []
        }
        return items.sorted { $0.viewedAt > $1.viewedAt }
    }

    func record(_ item: RecentSearchItem) {
        var current = load().filter { $0.id != item.id }
        current.insert(item, at: 0)
        if current.count > maxCount { current = Array(current.prefix(maxCount)) }
        if let data = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// MARK: - Trending suggestions (lightweight, hand-curated rotation)

nonisolated enum TrendingSearches: Sendable {
    /// A small rotating set so the discovery surface always feels alive.
    /// We seed by day-of-year so the list is stable for a session but fresh daily.
    static func today() -> [String] {
        let pool = [
            "BPC-157",
            "How do I reconstitute?",
            "Bench press",
            "How to inject",
            "High protein breakfast",
            "Tirzepatide",
            "Reading a COA",
            "Pull ups",
            "Creatine",
            "Greek yogurt",
            "Retatrutide",
            "Romanian deadlift",
            "How to store peptides",
            "Magnesium glycinate",
            "Overnight oats",
            "Sermorelin",
            "Front squat",
            "Whey isolate",
            "MOTS-c",
            "Lat pulldown",
            "Cottage cheese",
            "Ipamorelin"
        ]
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        var seeded: [String] = []
        for i in 0..<6 {
            seeded.append(pool[(day + i * 5) % pool.count])
        }
        return seeded
    }
}

// MARK: - Query intent classifier

nonisolated enum QueryIntent: Sendable, Equatable {
    case lookup     // user wants results, no Pep card
    case question   // hero Pep card, results below if any
    case mixed      // both, Pep card on top but smaller-feeling
}

@MainActor
enum QueryClassifier {
    private static let questionStarters: [String] = [
        "how", "what", "why", "should", "is ", "can", "could", "would",
        "does", "do ", "are ", "when", "where", "which", "who",
        "best ", "worst ", "compare", "vs", "better than", "difference between",
        "tell me", "explain", "recommend", "suggest", "help"
    ]

    private static let libraryNames: Set<String> = {
        var s = Set<String>()
        for e in ExerciseLibrary.all { s.insert(e.name.lowercased()) }
        for c in CompoundDatabase.all { s.insert(c.name.lowercased()) }
        for f in FoodDatabase.allFoods.prefix(800) { s.insert(f.name.lowercased()) }
        return s
    }()

    static func classify(_ raw: String, hasResults: Bool) -> QueryIntent {
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else { return .lookup }
        let lower = q.lowercased()

        // Hard signals → always question.
        if lower.hasSuffix("?") { return hasResults ? .mixed : .question }

        // Username / hashtag / direct entity prefix → lookup.
        if lower.hasPrefix("@") || lower.hasPrefix("#") { return .lookup }

        // Exact library hit → lookup.
        if libraryNames.contains(lower) { return .lookup }

        let words = lower.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let starts = questionStarters.contains(where: { lower.hasPrefix($0) })
        let containsQuestionWord = lower.contains(" vs ") || lower.contains(" vs. ") || lower.contains(" or ") || lower.contains(" better than ")

        // Long natural-language style query → likely a question.
        if starts && words.count >= 2 {
            return hasResults ? .mixed : .question
        }
        if words.count >= 5 {
            return hasResults ? .mixed : .question
        }
        if containsQuestionWord && words.count >= 3 {
            return hasResults ? .mixed : .question
        }

        return .lookup
    }
}

// MARK: - "Ask Pep" personalized AI answer

@MainActor
@Observable
final class AskEptiAnswerStore {
    var query: String = ""
    var answer: String = ""
    /// Short follow-up search suggestions Pep recommends after answering. Used to power the
    /// "Keep exploring" section instead of a dead-end "no results" banner.
    var followUps: [String] = []
    var isLoading: Bool = false
    var lastError: String?

    private var task: Task<Void, Never>?
    private var compoundContextCache: String?

    func ask(_ q: String, intent: QueryIntent) {
        let trimmed = q.trimmingCharacters(in: .whitespacesAndNewlines)
        // Only fire for question / mixed intents.
        guard intent != .lookup, trimmed.count >= 4 else {
            cancel()
            return
        }
        guard trimmed != query || answer.isEmpty else { return }

        task?.cancel()
        query = trimmed
        answer = ""
        followUps = []
        lastError = nil
        isLoading = true

        task = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(650))
            if Task.isCancelled { return }
            guard let self else { return }
            await self.runAsk(trimmed)
        }
    }

    private func runAsk(_ prompt: String) async {
        let userContext = AIContextBuilder.build(
            options: AIContextBuilder.Options(sourceScreen: "Global Search")
        )
        let compoundContext = cachedCompoundContext()
        let system = systemPrompt(userContext: userContext, compoundContext: compoundContext)

        let body: [String: Any] = [
            "model": "perplexity/sonar",
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 260
        ]

        do {
            let data = try await AIProxyClient.postChatCompletion(body: body, timeout: 25)
            if Task.isCancelled { return }
            let raw = (try? AIProxyClient.extractContent(data)) ?? ""
            let parsed = parse(raw)
            await MainActor.run {
                self.answer = parsed.answer
                if !parsed.followUps.isEmpty {
                    self.followUps = parsed.followUps
                } else {
                    self.followUps = self.localFallbackFollowUps(answer: parsed.answer, query: prompt)
                }
                self.isLoading = false
            }
        } catch {
            if Task.isCancelled { return }
            await MainActor.run {
                self.lastError = "Couldn't reach Pep right now."
                self.isLoading = false
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        query = ""
        answer = ""
        followUps = []
        isLoading = false
        lastError = nil
    }

    private func cachedCompoundContext() -> String {
        if let cached = compoundContextCache { return cached }
        // Compact compound list — names + categories only — keeps prompt small for the card.
        var ctx = "\nCOMPOUND LIBRARY (names + categories you may reference):\n"
        for c in CompoundDatabase.all.prefix(60) {
            ctx += "- \(c.name) [\(c.peptideType)]\n"
        }
        compoundContextCache = ctx
        return ctx
    }

    private nonisolated func systemPrompt(userContext: String, compoundContext: String) -> String {
        return """
        You are Pep, the AI coach inside EPTI (a fitness, nutrition, and peptide protocol app). The user just typed a question into the global search bar — give them a short, direct, personalized answer, then suggest 3 follow-up things they could search next.

        RESPONSE FORMAT (mandatory, exactly two sections):
        ANSWER:
        <2 to 4 sentence answer here, lowercase conversational tone, plain text only, no markdown, no greetings>
        FOLLOWUPS:
        - <short follow-up search query, 2-6 words>
        - <short follow-up search query, 2-6 words>
        - <short follow-up search query, 2-6 words>

        FOLLOWUP RULES:
        - Each follow-up must be a natural thing the user might want to look up next, directly related to the answer (e.g. a specific compound, exercise, recipe idea, technique, side effect topic).
        - Prefer concrete nouns from EPTI's libraries when relevant (a compound name, an exercise name, a guide topic).
        - Title Case. Keep them short and tappable, like a search chip.
        - No questions, no punctuation at the end. No numbering. Just the phrase.

        ANSWER RULES:
        - 2 to 4 sentences total. No filler. No greetings.
        - Plain text only — no markdown, no asterisks, no headers, no bullets.
        - Lowercase, conversational, like a knowledgeable training partner.
        - Reference the user's actual data (weight, goal, protocol, recent workouts, nutrition today, bloodwork, sleep) when it's relevant. Use specific numbers.
        - Never diagnose, never prescribe. For controlled substances or medical issues, point to a qualified provider in one short line.
        - Never recommend vendors or sources.
        - Never cite sources, footnotes, or URLs.

        \(compoundContext)

        \(userContext)
        """
    }

    /// Splits a structured "ANSWER: ... FOLLOWUPS: - ..." response into its two parts.
    /// Falls back gracefully if the model returned plain text without sections.
    private nonisolated func parse(_ raw: String) -> (answer: String, followUps: [String]) {
        let cleaned = clean(raw)
        let lower = cleaned.lowercased()

        // Find the FOLLOWUPS marker (model may write "FOLLOWUPS:", "Follow-ups:", "Follow ups:").
        let markers = ["followups:", "follow-ups:", "follow ups:", "follow up:"]
        var splitRange: Range<String.Index>? = nil
        for m in markers {
            if let r = lower.range(of: m) {
                splitRange = r
                break
            }
        }
        guard let split = splitRange else {
            return (cleaned, [])
        }

        let answerStart = cleaned[..<split.lowerBound]
        let followsRaw = cleaned[split.upperBound...]

        // Strip an optional leading "ANSWER:" label.
        var answer = String(answerStart)
        if let answerLabel = answer.lowercased().range(of: "answer:") {
            answer = String(answer[answerLabel.upperBound...])
        }
        answer = answer.trimmingCharacters(in: .whitespacesAndNewlines)

        let lines = followsRaw.split(whereSeparator: { $0.isNewline })
        var followUps: [String] = []
        for line in lines {
            var t = line.trimmingCharacters(in: .whitespacesAndNewlines)
            // Strip bullet/number prefixes.
            t = t.replacingOccurrences(of: #"^[\-\*•·]\s*"#, with: "", options: .regularExpression)
            t = t.replacingOccurrences(of: #"^\d+[\.\)]\s*"#, with: "", options: .regularExpression)
            // Drop trailing punctuation.
            t = t.trimmingCharacters(in: CharacterSet(charactersIn: " .,;:?!"))
            guard !t.isEmpty, t.count <= 60 else { continue }
            // Avoid duplicates (case-insensitive).
            if followUps.contains(where: { $0.lowercased() == t.lowercased() }) { continue }
            followUps.append(t)
            if followUps.count >= 4 { break }
        }
        return (answer.isEmpty ? cleaned : answer, followUps)
    }

    /// Local fallback when the model didn't return parseable follow-ups. Tries to find
    /// concrete library nouns mentioned in the answer; otherwise emits topical defaults
    /// based on which domain the answer is about.
    private func localFallbackFollowUps(answer: String, query: String) -> [String] {
        let text = (answer + " " + query).lowercased()
        var found: [String] = []

        for c in CompoundDatabase.all {
            let n = c.name.lowercased()
            guard n.count >= 4 else { continue }
            if text.contains(n), !found.contains(c.name) {
                found.append(c.name)
                if found.count >= 3 { break }
            }
        }
        if found.count < 3 {
            for f in FoodDatabase.allFoods.prefix(400) {
                let n = f.name.lowercased()
                guard n.count >= 5 else { continue }
                if text.contains(n), !found.contains(f.name) {
                    found.append(f.name)
                    if found.count >= 3 { break }
                }
            }
        }
        if !found.isEmpty { return found }

        // Topical defaults.
        if text.contains("food") || text.contains("eat") || text.contains("diet") || text.contains("meal") || text.contains("recipe") || text.contains("nutrition") {
            return ["High protein recipes", "Meal prep ideas", "Foods to avoid"]
        }
        if text.contains("workout") || text.contains("training") || text.contains("exercise") || text.contains("lift") || text.contains("muscle") {
            return ["Best chest exercises", "Pull day workout", "Mobility routine"]
        }
        if text.contains("peptide") || text.contains("dose") || text.contains("inject") || text.contains("vial") {
            return ["How to reconstitute", "Injection technique", "Storage & handling"]
        }
        if text.contains("sleep") || text.contains("recovery") || text.contains("hrv") {
            return ["Sleep optimization", "Recovery protocols", "Magnesium glycinate"]
        }
        return ["High protein recipes", "Best back exercises", "How to reconstitute"]
    }

    private nonisolated func clean(_ s: String) -> String {
        var out = s
        out = out.replacingOccurrences(of: "**", with: "")
        out = out.replacingOccurrences(of: "##", with: "")
        out = out.replacingOccurrences(of: "# ", with: "")
        out = out.replacingOccurrences(of: #"\[\d+\]"#, with: "", options: .regularExpression)
        out = out.replacingOccurrences(of: #"(?i)\n*sources?:.*$"#, with: "", options: .regularExpression)
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Highlighted text

struct HighlightedText: View {
    let text: String
    let query: String
    var baseFont: Font = .subheadline.weight(.semibold)
    var baseColor: Color = PepTheme.textPrimary
    var highlightColor: Color = PepTheme.teal

    var body: some View {
        Text(buildAttributed())
            .font(baseFont)
            .foregroundStyle(baseColor)
            .lineLimit(1)
    }

    private func buildAttributed() -> AttributedString {
        var attr = AttributedString(text)
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return attr }
        let lowerText = text.lowercased()
        let lowerQuery = q.lowercased()
        var searchStart = lowerText.startIndex
        while searchStart < lowerText.endIndex,
              let range = lowerText.range(of: lowerQuery, range: searchStart..<lowerText.endIndex) {
            let nsStart = lowerText.distance(from: lowerText.startIndex, to: range.lowerBound)
            let nsLen = lowerText.distance(from: range.lowerBound, to: range.upperBound)
            if let attrStart = attr.index(attr.startIndex, offsetByCharacters: nsStart, limitedBy: attr.endIndex),
               let attrEnd = attr.index(attrStart, offsetByCharacters: nsLen, limitedBy: attr.endIndex) {
                attr[attrStart..<attrEnd].foregroundColor = highlightColor
                attr[attrStart..<attrEnd].font = baseFont.weight(.heavy)
            }
            searchStart = range.upperBound
        }
        return attr
    }
}

private extension AttributedString {
    func index(_ from: AttributedString.Index, offsetByCharacters offset: Int, limitedBy limit: AttributedString.Index) -> AttributedString.Index? {
        let chars = self.characters
        guard let charsFrom = chars.index(from, offsetBy: 0, limitedBy: chars.endIndex),
              let result = chars.index(charsFrom, offsetBy: offset, limitedBy: limit) else {
            return nil
        }
        return result
    }
}

// MARK: - Relative time helper

nonisolated enum RelativeTimeFormatter: Sendable {
    static func short(from date: Date, now: Date = Date()) -> String {
        let interval = now.timeIntervalSince(date)
        if interval < 60 { return "just now" }
        let minutes = Int(interval / 60)
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        if days < 7 { return "\(days)d ago" }
        let weeks = days / 7
        if weeks < 5 { return "\(weeks)w ago" }
        let months = days / 30
        if months < 12 { return "\(months)mo ago" }
        return "\(days / 365)y ago"
    }
}
