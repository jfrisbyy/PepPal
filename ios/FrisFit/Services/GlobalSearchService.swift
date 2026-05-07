import Foundation
import SwiftUI
import Supabase

nonisolated enum GlobalSearchScope: String, CaseIterable, Sendable, Identifiable {
    case all = "All"
    case guides = "Guides"
    case exercises = "Exercises"
    case foods = "Foods"
    case compounds = "Compounds"
    case users = "Users"
    case circles = "Circles"
    case posts = "Posts"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: "magnifyingglass"
        case .guides: "book.pages.fill"
        case .exercises: "dumbbell.fill"
        case .foods: "fork.knife"
        case .compounds: "pills.fill"
        case .users: "person.2.fill"
        case .circles: "person.3.fill"
        case .posts: "bubble.left.fill"
        }
    }

    var emptyIcon: String {
        switch self {
        case .all: "sparkle.magnifyingglass"
        case .guides: "book.closed"
        case .exercises: "figure.strengthtraining.traditional"
        case .foods: "takeoutbag.and.cup.and.straw"
        case .compounds: "cross.vial"
        case .users: "person.crop.circle.badge.questionmark"
        case .circles: "person.3"
        case .posts: "bubble.left.and.bubble.right"
        }
    }
}

nonisolated enum GlobalSearchResult: Identifiable, Sendable {
    case exercise(Exercise)
    case food(FoodItem)
    case compound(CompoundProfile)
    case user(SocialUser)
    case circle(FitCircle)
    case post(id: String, userId: String, author: SocialUser, snippet: String, createdAt: Date)
    case guide(GuideEntry)

    var id: String {
        switch self {
        case .exercise(let e): return "ex-\(e.id)"
        case .food(let f): return "food-\(f.id.uuidString)"
        case .compound(let c): return "cmp-\(c.id.uuidString)"
        case .user(let u): return "u-\(u.id.uuidString)"
        case .circle(let c): return "cir-\(c.id.uuidString)"
        case .post(let id, _, _, _, _): return "post-\(id)"
        case .guide(let g): return "guide-\(g.id)"
        }
    }

    var scope: GlobalSearchScope {
        switch self {
        case .exercise: .exercises
        case .food: .foods
        case .compound: .compounds
        case .user: .users
        case .circle: .circles
        case .post: .posts
        case .guide: .guides
        }
    }

    var title: String {
        switch self {
        case .exercise(let e): e.name
        case .food(let f): f.name
        case .compound(let c): c.name
        case .user(let u): u.name
        case .circle(let c): c.name
        case .post(_, _, let author, _, _): author.name
        case .guide(let g): g.title
        }
    }

    var subtitle: String {
        switch self {
        case .exercise(let e): "\(e.primaryMuscle.rawValue) • \(e.equipment.rawValue)"
        case .food(let f): f.brand.isEmpty ? "\(f.calories) cal • \(f.servingSize)" : "\(f.brand) • \(f.calories) cal"
        case .compound(let c): c.peptideType
        case .user(let u): "@\(u.username)"
        case .circle(let c): c.isPrivate ? "Private • \(c.memberCount) members" : "\(c.memberCount) members"
        case .post(_, _, _, let snippet, _): snippet
        case .guide(let g): g.subtitle
        }
    }

    var icon: String {
        switch self {
        case .exercise(let e): e.primaryMuscle.icon
        case .food: "fork.knife"
        case .compound: "pills.fill"
        case .user: "person.crop.circle"
        case .circle: "person.3.fill"
        case .post: "bubble.left.fill"
        case .guide(let g): g.icon
        }
    }

    /// Strings the ranker should evaluate against the query for this row.
    var rankableStrings: [String] {
        switch self {
        case .exercise(let e):
            return [e.name, e.primaryMuscle.rawValue, e.equipment.rawValue]
        case .food(let f):
            return [f.name, f.brand]
        case .compound(let c):
            return [c.name, c.peptideType]
        case .user(let u):
            return [u.name, u.username]
        case .circle(let c):
            return [c.name]
        case .post(_, _, let author, let snippet, _):
            return [snippet, author.name, author.username]
        case .guide(let g):
            return g.rankableStrings
        }
    }
}

@MainActor
final class RecentSearchesStore {
    static let shared = RecentSearchesStore()
    private let key = "global_search_recent_v1"
    private let maxCount = 10

    private init() {}

    func load() -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    func add(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return }
        var current = load().filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        current.insert(trimmed, at: 0)
        if current.count > maxCount { current = Array(current.prefix(maxCount)) }
        UserDefaults.standard.set(current, forKey: key)
    }

    func remove(_ query: String) {
        let current = load().filter { $0 != query }
        UserDefaults.standard.set(current, forKey: key)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

@Observable
@MainActor
final class GlobalSearchViewModel {
    var query: String = ""
    var scope: GlobalSearchScope = .all
    var results: [GlobalSearchResult] = []
    var isSearching: Bool = false
    var recents: [String] = []

    private var searchTask: Task<Void, Never>?
    private var blockedIds: Set<String> = []
    private var blockedLoaded: Bool = false

    init() {
        recents = RecentSearchesStore.shared.load()
    }

    func reloadRecents() {
        recents = RecentSearchesStore.shared.load()
    }

    func commitRecent() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        RecentSearchesStore.shared.add(q)
        recents = RecentSearchesStore.shared.load()
    }

    func removeRecent(_ q: String) {
        RecentSearchesStore.shared.remove(q)
        recents = RecentSearchesStore.shared.load()
    }

    func clearRecents() {
        RecentSearchesStore.shared.clear()
        recents = []
    }

    func search() {
        searchTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            results = []
            isSearching = false
            return
        }
        isSearching = true
        let currentScope = scope

        searchTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(300))
            if Task.isCancelled { return }

            await self.loadBlockedIfNeeded()
            if Task.isCancelled { return }

            let combined = await self.performSearch(q: q, scope: currentScope)
            if Task.isCancelled { return }
            self.results = combined
            self.isSearching = false
        }
    }

    private func loadBlockedIfNeeded() async {
        guard !blockedLoaded else { return }
        blockedLoaded = true
        guard AuthService.shared.authState == .signedIn,
              let userId = try? AuthService.shared.currentUserId() else { return }
        if let ids = try? await ModerationService.shared.blockedUserIds(blockerId: userId) {
            blockedIds = ids
        }
    }

    private func performSearch(q: String, scope: GlobalSearchScope) async -> [GlobalSearchResult] {
        let wantExercises = scope == .all || scope == .exercises
        let wantFoods = scope == .all || scope == .foods
        let wantCompounds = scope == .all || scope == .compounds
        let wantUsers = scope == .all || scope == .users
        let wantCircles = scope == .all || scope == .circles
        let wantPosts = scope == .all || scope == .posts
        let wantGuides = scope == .all || scope == .guides

        let perScopeLimit = scope == .all ? 3 : 25
        let blocked = blockedIds

        async let exercisesTask = Self.searchExercises(q, limit: perScopeLimit, enabled: wantExercises)
        async let foodsTask = Self.searchFoods(q, limit: perScopeLimit, enabled: wantFoods)
        async let compoundsTask = Self.searchCompounds(q, limit: perScopeLimit, enabled: wantCompounds)
        async let usersTask = Self.searchUsers(q, limit: perScopeLimit, enabled: wantUsers, blocked: blocked)
        async let circlesTask = Self.searchCircles(q, limit: perScopeLimit, enabled: wantCircles)
        async let postsTask = Self.searchPosts(q, limit: perScopeLimit, enabled: wantPosts, blocked: blocked)
        async let guidesTask = Self.searchGuides(q, limit: perScopeLimit, enabled: wantGuides)

        let exercises = await exercisesTask
        let foods = await foodsTask
        let compounds = await compoundsTask
        let users = await usersTask
        let circles = await circlesTask
        let posts = await postsTask
        let guides = await guidesTask

        let unranked = guides + exercises + foods + compounds + users + circles + posts
        return Self.rank(results: unranked, query: q)
    }

    /// Rank merged results: prefix > word-boundary > substring > fuzzy.
    /// Stable across scopes by including a small per-scope bias so the
    /// merged "All" view feels balanced rather than dominated by foods.
    nonisolated private static func rank(results: [GlobalSearchResult], query: String) -> [GlobalSearchResult] {
        struct Scored {
            let result: GlobalSearchResult
            let score: Int
            let originalIndex: Int
        }
        let scored: [Scored] = results.enumerated().map { idx, r in
            let s = SearchRanker.score(query: query, candidates: r.rankableStrings)
            return Scored(result: r, score: s, originalIndex: idx)
        }
        return scored
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.originalIndex < rhs.originalIndex
            }
            .map { $0.result }
    }

    // MARK: - Scope searches

    nonisolated private static func searchGuides(_ q: String, limit: Int, enabled: Bool) async -> [GlobalSearchResult] {
        guard enabled else { return [] }
        let qLower = q.lowercased()
        // Score every guide using its title + subtitle + keyword phrases.
        // Use a low threshold so natural language ("how do i reconstitute") still matches
        // the keyword "how do i reconstitute" or "reconstitute peptide".
        var scored: [(GuideEntry, Int)] = []
        for entry in GuideLibrary.all {
            // Direct contains shortcut for any keyword phrase.
            var directHit = false
            for kw in entry.rankableStrings {
                let kwLower = kw.lowercased()
                if kwLower.contains(qLower) || qLower.contains(kwLower) {
                    directHit = true
                    break
                }
            }
            let s = SearchRanker.score(query: q, candidates: entry.rankableStrings)
            let finalScore = directHit ? max(s, 600) : s
            if finalScore >= 300 {
                scored.append((entry, finalScore))
            }
        }
        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { GlobalSearchResult.guide($0.0) }
    }

    nonisolated private static func searchExercises(_ q: String, limit: Int, enabled: Bool) async -> [GlobalSearchResult] {
        guard enabled else { return [] }
        return ExerciseLibrary.all
            .filter {
                $0.name.localizedStandardContains(q) ||
                $0.primaryMuscle.rawValue.localizedStandardContains(q) ||
                $0.equipment.rawValue.localizedStandardContains(q)
            }
            .prefix(limit)
            .map { GlobalSearchResult.exercise($0) }
    }

    nonisolated private static func searchFoods(_ q: String, limit: Int, enabled: Bool) async -> [GlobalSearchResult] {
        guard enabled else { return [] }
        return FoodDatabase.allFoods
            .filter {
                $0.name.localizedStandardContains(q) ||
                $0.brand.localizedStandardContains(q)
            }
            .prefix(limit)
            .map { GlobalSearchResult.food($0) }
    }

    nonisolated private static func searchCompounds(_ q: String, limit: Int, enabled: Bool) async -> [GlobalSearchResult] {
        guard enabled else { return [] }
        return CompoundDatabase.all
            .filter {
                $0.name.localizedStandardContains(q) ||
                $0.peptideType.localizedStandardContains(q)
            }
            .prefix(limit)
            .map { GlobalSearchResult.compound($0) }
    }

    @MainActor
    private static func searchUsers(_ q: String, limit: Int, enabled: Bool, blocked: Set<String>) async -> [GlobalSearchResult] {
        guard enabled else { return [] }
        guard AuthService.shared.authState == .signedIn,
              let userId = try? AuthService.shared.currentUserId() else { return [] }
        do {
            let profiles = try await MessagingService.shared.searchUsers(query: q, excludeUserId: userId)
            return profiles
                .filter { !blocked.contains($0.id) }
                .prefix(limit)
                .map { p in
                    let user = MessagingService.shared.socialUserFromAuthor(p)
                    return GlobalSearchResult.user(user)
                }
        } catch {
            return []
        }
    }

    @MainActor
    private static func searchCircles(_ q: String, limit: Int, enabled: Bool) async -> [GlobalSearchResult] {
        guard enabled else { return [] }
        guard AuthService.shared.authState == .signedIn,
              let userId = try? AuthService.shared.currentUserId() else { return [] }
        do {
            let rows = try await CircleService.shared.searchCircles(query: q, userId: userId, limit: limit)
            return rows.map { GlobalSearchResult.circle($0) }
        } catch {
            return []
        }
    }

    @MainActor
    private static func searchPosts(_ q: String, limit: Int, enabled: Bool, blocked: Set<String>) async -> [GlobalSearchResult] {
        guard enabled else { return [] }
        guard AuthService.shared.authState == .signedIn else { return [] }
        do {
            let rows = try await SocialService.shared.searchPosts(query: q, limit: limit * 2)
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return rows
                .filter { !blocked.contains($0.user_id) }
                .prefix(limit)
                .map { row in
                    let author = SocialService.shared.socialUserFromAuthor(row.profiles)
                    let snippet = (row.text_content ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmed = snippet.count > 120 ? String(snippet.prefix(120)) + "…" : snippet
                    let createdAt = iso.date(from: row.created_at ?? "") ?? Date()
                    return GlobalSearchResult.post(
                        id: row.id,
                        userId: row.user_id,
                        author: author,
                        snippet: trimmed.isEmpty ? "Post" : trimmed,
                        createdAt: createdAt
                    )
                }
        } catch {
            return []
        }
    }
}
