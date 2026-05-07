import Foundation
import SwiftUI

// MARK: - Smart ranking (prefix → word boundary → fuzzy)

nonisolated enum SearchRanker: Sendable {
    /// Score in [0...1000]. Higher is better. Returns 0 for no match (caller should still
    /// consider whether to keep the row, since the source filter may be more permissive).
    static func score(query: String, candidates: [String]) -> Int {
        let q = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return 0 }
        var best = 0
        for raw in candidates {
            let c = raw.lowercased()
            if c == q { return 1000 }
            if c.hasPrefix(q) { best = max(best, 850) ; continue }
            if hasWordBoundaryPrefix(c, q) { best = max(best, 700) ; continue }
            if c.contains(q) { best = max(best, 550) ; continue }
            let tolerance = max(1, q.count / 4)
            if let dist = bestEditDistance(query: q, in: c), dist <= tolerance {
                // Closer match = higher score; cap so it ranks below substring matches.
                let cappedDist = min(dist, 5)
                let bonus = max(0, 400 - cappedDist * 80)
                best = max(best, bonus)
            }
        }
        return best
    }

    private static func hasWordBoundaryPrefix(_ haystack: String, _ needle: String) -> Bool {
        var inWord = false
        var idx = haystack.startIndex
        while idx < haystack.endIndex {
            let ch = haystack[idx]
            let isWordChar = ch.isLetter || ch.isNumber
            if isWordChar && !inWord {
                // Word start
                let remaining = haystack[idx...]
                if remaining.hasPrefix(needle) { return true }
            }
            inWord = isWordChar
            idx = haystack.index(after: idx)
        }
        return false
    }

    /// Find the smallest edit distance between `query` and any same-length-ish window of `haystack`.
    /// Uses a small Levenshtein with early bail; good for 2–20 char queries.
    private static func bestEditDistance(query: String, in haystack: String) -> Int? {
        let qChars = Array(query)
        let hChars = Array(haystack)
        guard !qChars.isEmpty, !hChars.isEmpty else { return nil }
        let qLen = qChars.count
        if qLen > hChars.count + 2 { return nil }
        let windowMin = max(qLen - 1, 1)
        let windowMax = min(qLen + 1, hChars.count)
        guard windowMin <= windowMax else { return nil }
        // Use a bounded ceiling instead of Int.max to avoid overflow downstream.
        let hardCeiling = max(qLen, 16)
        var bestDist: Int = hardCeiling
        // Slide windows of length qLen-1, qLen, qLen+1
        for wLen in windowMin...windowMax {
            if wLen > hChars.count { continue }
            var i = 0
            while i + wLen <= hChars.count {
                let window = Array(hChars[i..<(i + wLen)])
                let d = levenshtein(qChars, window, ceiling: bestDist)
                if d < bestDist { bestDist = d }
                if bestDist == 0 { return 0 }
                i += 1
            }
        }
        return bestDist >= hardCeiling ? nil : bestDist
    }

    private static func levenshtein(_ a: [Character], _ b: [Character], ceiling: Int) -> Int {
        let n = a.count, m = b.count
        guard n > 0, m > 0 else { return max(n, m) }
        if abs(n - m) > ceiling { return ceiling }
        var prev = Array(0...m)
        var curr = [Int](repeating: 0, count: m + 1)
        for i in 1...n {
            curr[0] = i
            var rowMin = curr[0]
            for j in 1...m {
                let cost = a[i-1] == b[j-1] ? 0 : 1
                curr[j] = min(
                    prev[j] + 1,
                    curr[j-1] + 1,
                    prev[j-1] + cost
                )
                if curr[j] < rowMin { rowMin = curr[j] }
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
            "Bench press",
            "High protein breakfast",
            "Tirzepatide",
            "Pull ups",
            "Creatine",
            "Greek yogurt",
            "Retatrutide",
            "Romanian deadlift",
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

// MARK: - "Ask EPTI" lightweight AI answer

@MainActor
@Observable
final class AskEptiAnswerStore {
    var query: String = ""
    var answer: String = ""
    var isLoading: Bool = false
    var lastError: String?

    private var task: Task<Void, Never>?

    func ask(_ q: String) {
        let trimmed = q.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4, looksLikeQuestion(trimmed) else {
            cancel()
            return
        }
        guard trimmed != query || answer.isEmpty else { return }

        task?.cancel()
        query = trimmed
        answer = ""
        lastError = nil
        isLoading = true

        task = Task { [weak self] in
            // Debounce — let the user keep typing.
            try? await Task.sleep(for: .milliseconds(700))
            if Task.isCancelled { return }
            guard let self else { return }

            let prompt = trimmed
            let body: [String: Any] = [
                "model": "openai/gpt-4o-mini",
                "messages": [
                    [
                        "role": "system",
                        "content": "You are Pep, the in-app AI coach for EPTI (a fitness, nutrition, and peptide protocol app). Answer the user's search query in 1–2 short sentences, plain text only, no markdown, no emojis. Be specific and actionable. If you don't know, say so briefly."
                    ],
                    ["role": "user", "content": prompt]
                ],
                "max_tokens": 140,
                "temperature": 0.4
            ]

            do {
                let data = try await AIProxyClient.postChatCompletion(body: body, timeout: 15)
                if Task.isCancelled { return }
                let text = (try? AIProxyClient.extractContent(data)) ?? ""
                let cleaned = text
                    .replacingOccurrences(of: "**", with: "")
                    .replacingOccurrences(of: "##", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                self.answer = cleaned
                self.isLoading = false
            } catch {
                if Task.isCancelled { return }
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
        isLoading = false
        lastError = nil
    }

    private nonisolated func looksLikeQuestion(_ s: String) -> Bool {
        let lower = s.lowercased()
        if lower.hasSuffix("?") { return true }
        // Multi-word natural-language style queries trigger the AI card.
        let wordCount = s.split(whereSeparator: { $0.isWhitespace }).count
        if wordCount >= 3 { return true }
        let starters = ["how", "what", "why", "best", "compare", "vs ", "should", "can", "does", "is "]
        return starters.contains(where: { lower.hasPrefix($0) })
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
            // Convert String range to AttributedString range.
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
        // characters view supports index(_:offsetBy:limitedBy:)
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
