import Foundation
import Supabase

/// Long-horizon, cross-session memory of the user. The deep (Sonnet)
/// brief reads this on every run and rewrites `profile_memo` at the
/// end. The fast (Haiku) brief only reads.
///
/// Backed by `public.user_long_term_memory` (one row per user, RLS
/// scoped to `auth.uid()`).
nonisolated final class LongTermMemoryService: @unchecked Sendable {
    static let shared = LongTermMemoryService()
    private init() {}

    private var supabase: SupabaseClient { SupabaseService.shared.client }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // Memo size budget — ~1000 tokens. Hard truncation guard so a runaway
    // Sonnet output can never balloon costs forever.
    private static let memoCharCap = 4096
    private static let maxVersions = 10
    private static let maxEvents = 100

    // In-process cache so back-to-back deep+fast paths don't refetch.
    private var cache: (uid: String, snapshot: LongTermMemorySnapshot, fetchedAt: Date)?
    private let cacheTTL: TimeInterval = 60

    // MARK: - DTOs

    nonisolated struct SignificantEvent: Codable, Sendable, Hashable {
        let id: String
        let at: String          // ISO date or datetime
        let type: String
        let summary: String
        let values: [String: String]?
        let source: String?
    }

    nonisolated struct LongTermMemorySnapshot: Sendable {
        let memo: String
        let events: [SignificantEvent]
        let lastUpdatedAt: Date?
        let lastUpdatedByModel: String?
        static let empty = LongTermMemorySnapshot(memo: "", events: [], lastUpdatedAt: nil, lastUpdatedByModel: nil)
    }

    // Postgrest row mirror — JSON columns serialized as strings on the wire.
    nonisolated private struct Row: Codable, Sendable {
        let user_id: String
        let profile_memo: String
        let memo_versions: [MemoVersion]
        let significant_events: [SignificantEvent]
        let last_updated_at: String?
        let last_updated_by_model: String?
    }

    nonisolated private struct MemoVersion: Codable, Sendable {
        let at: String
        let by_model: String?
        let memo: String
    }

    nonisolated private struct UpsertRow: Codable, Sendable {
        let user_id: String
        let profile_memo: String
        let memo_versions: [MemoVersion]
        let significant_events: [SignificantEvent]
        let last_updated_at: String
        let last_updated_by_model: String?
    }

    // MARK: - Public API

    /// Fetch the user's memo + events. Cheap to call; uses a 60s in-memory
    /// cache so the deep + fast paths can call it freely.
    func fetch(forceReload: Bool = false) async -> LongTermMemorySnapshot {
        // Demo mode: never read the signed-in user's real Supabase memo.
        // Return the persona-seeded memo instead so the brief is anchored
        // to the mock identity, not the real account behind it.
        if let scenario = DemoModeProbe.activeScenario {
            return LongTermMemorySnapshot(
                memo: DemoModeProbe.profileMemo(for: scenario),
                events: [],
                lastUpdatedAt: Date(),
                lastUpdatedByModel: "demo-seed"
            )
        }
        guard let uid = await currentUserId() else { return .empty }
        if !forceReload, let c = cache, c.uid == uid, Date().timeIntervalSince(c.fetchedAt) < cacheTTL {
            return c.snapshot
        }
        do {
            let rows: [Row] = try await supabase.from("user_long_term_memory")
                .select("user_id, profile_memo, memo_versions, significant_events, last_updated_at, last_updated_by_model")
                .eq("user_id", value: uid)
                .limit(1)
                .execute()
                .value
            let snapshot: LongTermMemorySnapshot
            if let row = rows.first {
                snapshot = LongTermMemorySnapshot(
                    memo: row.profile_memo,
                    events: row.significant_events,
                    lastUpdatedAt: row.last_updated_at.flatMap { Self.iso.date(from: $0) },
                    lastUpdatedByModel: row.last_updated_by_model
                )
            } else {
                snapshot = .empty
            }
            cache = (uid, snapshot, Date())
            return snapshot
        } catch {
            print("[LongTermMemory] fetch failed: \(error.localizedDescription)")
            return cache?.snapshot ?? .empty
        }
    }

    /// Persist a freshly-rewritten memo. Pushes the prior memo into the
    /// version history (capped) and stamps `last_updated_*`.
    func saveMemo(_ newMemo: String, model: String) async {
        // Never persist demo-derived memos to the real user's row.
        if DemoModeProbe.isActive { return }
        guard let uid = await currentUserId() else { return }
        let trimmed = String(newMemo.prefix(Self.memoCharCap))
        let prior = await fetch()
        var versions: [MemoVersion] = []
        if !prior.memo.isEmpty {
            versions.append(MemoVersion(
                at: Self.iso.string(from: prior.lastUpdatedAt ?? Date()),
                by_model: prior.lastUpdatedByModel,
                memo: prior.memo
            ))
        }
        // Append onto whatever versions exist server-side. We refetch to
        // avoid clobbering, but keep this best-effort — single-writer per
        // user (only the deep path writes) makes contention near-zero.
        let existingVersions = await fetchVersions(uid: uid)
        let merged = (versions + existingVersions).prefix(Self.maxVersions)
        let row = UpsertRow(
            user_id: uid,
            profile_memo: trimmed,
            memo_versions: Array(merged),
            significant_events: prior.events,
            last_updated_at: Self.iso.string(from: Date()),
            last_updated_by_model: model
        )
        do {
            try await supabase.from("user_long_term_memory")
                .upsert(row, onConflict: "user_id")
                .execute()
            cache = (uid, LongTermMemorySnapshot(
                memo: trimmed,
                events: prior.events,
                lastUpdatedAt: Date(),
                lastUpdatedByModel: model
            ), Date())
        } catch {
            print("[LongTermMemory] saveMemo failed: \(error.localizedDescription)")
        }
    }

    /// Append (or replace) a significant event. Dedup by `(type, summary)`
    /// within a 24h window so re-uploading the same bloodwork doesn't add
    /// noise. Caps the list at `maxEvents` (oldest dropped).
    func appendEvent(
        type: String,
        summary: String,
        values: [String: String]? = nil,
        source: String? = nil,
        at date: Date = Date()
    ) async {
        if DemoModeProbe.isActive { return }
        guard let uid = await currentUserId() else { return }
        let snapshot = await fetch(forceReload: true)
        let atString = Self.iso.string(from: date)
        let lower = summary.lowercased()
        let cutoff = Date().addingTimeInterval(-24 * 3600)
        let isDup = snapshot.events.contains { e in
            e.type == type
                && e.summary.lowercased() == lower
                && (Self.iso.date(from: e.at) ?? .distantPast) >= cutoff
        }
        if isDup { return }
        let new = SignificantEvent(
            id: UUID().uuidString.lowercased(),
            at: atString,
            type: type,
            summary: String(summary.prefix(280)),
            values: values,
            source: source
        )
        var events = snapshot.events
        events.insert(new, at: 0)
        if events.count > Self.maxEvents {
            events = Array(events.prefix(Self.maxEvents))
        }
        let versions = await fetchVersions(uid: uid)
        let row = UpsertRow(
            user_id: uid,
            profile_memo: snapshot.memo,
            memo_versions: versions,
            significant_events: events,
            last_updated_at: Self.iso.string(from: Date()),
            last_updated_by_model: snapshot.lastUpdatedByModel
        )
        do {
            try await supabase.from("user_long_term_memory")
                .upsert(row, onConflict: "user_id")
                .execute()
            cache = (uid, LongTermMemorySnapshot(
                memo: snapshot.memo,
                events: events,
                lastUpdatedAt: Date(),
                lastUpdatedByModel: snapshot.lastUpdatedByModel
            ), Date())
        } catch {
            print("[LongTermMemory] appendEvent failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Prompt formatting

    /// Render the snapshot as a plain-text section ready to splice into
    /// the Sonnet/Haiku user prompt. Returns "" when there is nothing to
    /// say (cold-start users) so we don't waste tokens on empty headers.
    static func promptSection(from snapshot: LongTermMemorySnapshot, includeMemo: Bool = true) -> String {
        var lines: [String] = []
        if includeMemo, !snapshot.memo.isEmpty {
            lines.append("LONG-TERM USER MEMO (durable cross-session understanding — treat as authoritative for everything not directly contradicted by today's data):")
            lines.append(snapshot.memo)
        }
        if !snapshot.events.isEmpty {
            lines.append("")
            lines.append("SIGNIFICANT EVENTS (chronological, newest first — reference these by date when relevant):")
            for e in snapshot.events.prefix(40) {
                let dateOnly = String(e.at.prefix(10))
                var line = "- [\(dateOnly)] \(e.type): \(e.summary)"
                if let values = e.values, !values.isEmpty {
                    let kv = values.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
                    line += " (\(kv))"
                }
                lines.append(line)
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Private

    private func fetchVersions(uid: String) async -> [MemoVersion] {
        do {
            let rows: [Row] = try await supabase.from("user_long_term_memory")
                .select("user_id, profile_memo, memo_versions, significant_events, last_updated_at, last_updated_by_model")
                .eq("user_id", value: uid)
                .limit(1)
                .execute()
                .value
            return rows.first?.memo_versions ?? []
        } catch {
            return []
        }
    }

    private func currentUserId() async -> String? {
        do {
            let session = try await supabase.auth.session
            return session.user.id.uuidString.lowercased()
        } catch {
            return nil
        }
    }

    /// Drop the in-memory cache (call on sign-in/out so a new user can't
    /// momentarily see a previous user's memo).
    func reset() {
        cache = nil
    }
}
