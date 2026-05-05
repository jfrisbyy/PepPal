import Foundation
import SwiftUI

/// Persistent long-term memory of everything the AI has learned about the user.
/// Facts are persisted on Supabase (per-user, RLS-protected) with a UserDefaults
/// cache for offline access. They are injected into every AI call as a compact memo.
@MainActor
@Observable
final class AIMemoryStore {
    static let shared = AIMemoryStore()

    private(set) var facts: [AIMemoryFact] = []
    var isEnabled: Bool = true
    private let enabledKey = "ai_memory_enabled"

    private let maxFacts: Int = 80
    private let staleAfterDays: Int = 120

    private init() {
        isEnabled = UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
        load()
        Task { await self.hydrateFromSupabase() }
    }

    // MARK: - Public API

    func allFacts() -> [AIMemoryFact] {
        let now = Date()
        return facts
            .filter { !$0.isMuted }
            .filter { fact in
                if let exp = fact.expiresAt, exp < now { return false }
                return true
            }
            .filter { isPinned($0) || daysSince($0.lastReinforcedAt, to: now) <= staleAfterDays }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                return lhs.lastReinforcedAt > rhs.lastReinforcedAt
            }
    }

    func contradict(_ existingId: UUID, with newFactId: UUID) {
        guard let idx = facts.firstIndex(where: { $0.id == existingId }) else { return }
        facts[idx].confidence = max(0.1, facts[idx].confidence - 0.25)
        if !facts[idx].contradictedBy.contains(newFactId) {
            facts[idx].contradictedBy.append(newFactId)
        }
        facts[idx].updatedAt = Date()
        persist()
        syncFact(facts[idx])
    }

    private func detectContradictions(for newFact: AIMemoryFact) {
        let inverseMarkers = ["no longer", "now hits", "now hitting", "reversed", "stopped", "not anymore", "contradicts"]
        let lower = newFact.headline.lowercased()
        let isInverseSignal = inverseMarkers.contains(where: { lower.contains($0) })
        guard isInverseSignal else { return }
        let normNew = normalize(newFact.headline)
        let tokens = Set(normNew.split(separator: " ").map(String.init).filter { $0.count > 3 })
        for fact in facts where fact.id != newFact.id && fact.kind == newFact.kind && fact.domain == newFact.domain {
            let normOld = normalize(fact.headline)
            let oldTokens = Set(normOld.split(separator: " ").map(String.init).filter { $0.count > 3 })
            let overlap = tokens.intersection(oldTokens).count
            if overlap >= 2 {
                contradict(fact.id, with: newFact.id)
            }
        }
    }

    func facts(matching domains: [String]? = nil, kinds: [AIMemoryFact.Kind]? = nil) -> [AIMemoryFact] {
        allFacts().filter { fact in
            if let domains, !domains.isEmpty, !domains.contains(fact.domain) { return false }
            if let kinds, !kinds.isEmpty, !kinds.contains(fact.kind) { return false }
            return true
        }
    }

    @discardableResult
    func upsert(_ fact: AIMemoryFact) -> AIMemoryFact {
        guard isEnabled else { return fact }
        let norm = normalize(fact.headline)
        if let idx = facts.firstIndex(where: {
            $0.kind == fact.kind && $0.domain == fact.domain && normalize($0.headline) == norm
        }) {
            var existing = facts[idx]
            existing.detail = fact.detail
            existing.evidence = fact.evidence.isEmpty ? existing.evidence : fact.evidence
            existing.confidence = max(existing.confidence, fact.confidence)
            existing.lastReinforcedAt = Date()
            existing.updatedAt = Date()
            existing.reinforceCount += 1
            facts[idx] = existing
            persist()
            syncFact(existing)
            return existing
        }
        facts.insert(fact, at: 0)
        detectContradictions(for: fact)
        trim()
        persist()
        syncFact(fact)
        return fact
    }

    func upsertMany(_ new: [AIMemoryFact]) {
        guard isEnabled else { return }
        for f in new { upsert(f) }
    }

    func pin(_ id: UUID, pinned: Bool = true) {
        guard let idx = facts.firstIndex(where: { $0.id == id }) else { return }
        facts[idx].isPinned = pinned
        facts[idx].updatedAt = Date()
        persist()
        syncFact(facts[idx])
    }

    func mute(_ id: UUID, muted: Bool = true) {
        guard let idx = facts.firstIndex(where: { $0.id == id }) else { return }
        facts[idx].isMuted = muted
        facts[idx].updatedAt = Date()
        persist()
        syncFact(facts[idx])
    }

    func delete(_ id: UUID) {
        facts.removeAll { $0.id == id }
        persist()
        Task.detached {
            await PersistenceSyncService.shared.deleteAIMemoryFact(id: id.uuidString.lowercased())
        }
    }

    func clear(domain: String? = nil, kind: AIMemoryFact.Kind? = nil) {
        let removed = facts.filter { fact in
            (domain == nil || fact.domain == domain) &&
            (kind == nil || fact.kind == kind)
        }
        facts.removeAll { fact in
            (domain == nil || fact.domain == domain) &&
            (kind == nil || fact.kind == kind)
        }
        persist()
        for fact in removed {
            let fid = fact.id
            Task.detached {
                await PersistenceSyncService.shared.deleteAIMemoryFact(id: fid.uuidString.lowercased())
            }
        }
    }

    func clearAll() {
        let removed = facts
        facts = []
        persist()
        for fact in removed {
            let fid = fact.id
            Task.detached {
                await PersistenceSyncService.shared.deleteAIMemoryFact(id: fid.uuidString.lowercased())
            }
        }
    }

    func replaceFactsWith(
        sourceTag: String,
        domain: String? = nil,
        kind: AIMemoryFact.Kind? = nil,
        fresh: [AIMemoryFact]
    ) {
        guard !sourceTag.isEmpty else {
            upsertMany(fresh)
            return
        }
        let removed = facts.filter { fact in
            guard fact.sourceTag == sourceTag else { return false }
            if let domain, fact.domain != domain { return false }
            if let kind, fact.kind != kind { return false }
            return true
        }
        facts.removeAll { fact in
            guard fact.sourceTag == sourceTag else { return false }
            if let domain, fact.domain != domain { return false }
            if let kind, fact.kind != kind { return false }
            return true
        }
        for fact in removed {
            let fid = fact.id
            Task.detached {
                await PersistenceSyncService.shared.deleteAIMemoryFact(id: fid.uuidString.lowercased())
            }
        }
        for f in fresh { upsert(f) }
        persist()
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: enabledKey)
    }

    func memoForAgent(limit: Int = 14) -> String {
        let active = allFacts().prefix(limit)
        guard !active.isEmpty else { return "" }
        var lines: [String] = ["WHAT THE APP ALREADY KNOWS ABOUT THIS USER (persisted across sessions — don't rediscover, reference directly):"]
        for fact in active {
            let conf = Int(fact.confidence * 100)
            let stars = String(repeating: "•", count: min(max(fact.reinforceCount, 1), 5))
            lines.append("- [\(fact.kind.label)/\(fact.domain)] \(fact.headline) (conf \(conf)%, \(stars))")
            if !fact.detail.isEmpty {
                lines.append("  \(fact.detail)")
            }
        }
        lines.append("RULE: Treat pinned/high-reinforce facts as known truth. Do not re-explain them. Update them if fresh data contradicts.")
        return lines.joined(separator: "\n")
    }

    // MARK: - Private

    private func normalize(_ s: String) -> String {
        s.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { !$0.isPunctuation }
    }

    private func daysSince(_ date: Date, to end: Date) -> Int {
        Calendar.current.dateComponents([.day], from: date, to: end).day ?? 0
    }

    private func isPinned(_ fact: AIMemoryFact) -> Bool { fact.isPinned }

    private func trim() {
        guard facts.count > maxFacts else { return }
        let pinned = facts.filter(\.isPinned)
        let unpinned = facts.filter { !$0.isPinned }
            .sorted { $0.lastReinforcedAt > $1.lastReinforcedAt }
        facts = pinned + unpinned.prefix(maxFacts - pinned.count)
    }

    // MARK: - Persistence

    private var storageKey: String {
        let uid = (try? AuthService.shared.currentUserId()) ?? "anon"
        return "ai_memory_v1.\(uid)"
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([AIMemoryFact].self, from: data) else { return }
        facts = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(facts) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func syncFact(_ fact: AIMemoryFact) {
        guard isEnabled else { return }
        guard let data = try? JSONEncoder().encode(fact),
              let json = String(data: data, encoding: .utf8) else { return }
        let category = "\(fact.kind.rawValue).\(fact.domain)"
        let id = fact.id.uuidString.lowercased()
        let source = fact.sourceTag.isEmpty ? nil : fact.sourceTag
        let confidence = fact.confidence
        Task.detached {
            await PersistenceSyncService.shared.upsertAIMemoryFact(
                id: id,
                category: category,
                contentJSON: json,
                confidence: confidence,
                source: source
            )
        }
    }

    func hydrateFromSupabase() async {
        let rows = await PersistenceSyncService.shared.fetchAIMemoryFacts()
        guard !rows.isEmpty else {
            // Push current local facts to Supabase on first-ever sync.
            for fact in facts { syncFact(fact) }
            return
        }
        var byId: [UUID: AIMemoryFact] = [:]
        for fact in facts { byId[fact.id] = fact }
        for row in rows {
            guard let data = row.content.data(using: .utf8),
                  let fact = try? JSONDecoder().decode(AIMemoryFact.self, from: data) else { continue }
            if let local = byId[fact.id] {
                // Prefer the more recently reinforced version.
                byId[fact.id] = local.lastReinforcedAt > fact.lastReinforcedAt ? local : fact
            } else {
                byId[fact.id] = fact
            }
        }
        facts = byId.values.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.lastReinforcedAt > rhs.lastReinforcedAt
        }
        persist()
    }

    /// Call after sign-in/out so the store swaps to the correct user bucket.
    func reloadForCurrentUser() {
        facts = []
        load()
        Task { await self.hydrateFromSupabase() }
    }
}
