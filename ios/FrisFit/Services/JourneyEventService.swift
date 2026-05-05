import Foundation
import Supabase

nonisolated struct SupabaseJourneyEvent: Codable, Sendable {
    let id: String?
    let user_id: String
    let lane: String
    let timestamp: String
    let duration_days: Int?
    let title: String
    let description: String?
    let source_type: String
    let confidence: Double?
    let attachments: [String]?
    let linked_fact_ids: [String]?
    let payload: String?
    let created_at: String?
}

nonisolated struct InsertJourneyEventPayload: Encodable, Sendable {
    let id: String
    let user_id: String
    let lane: String
    let timestamp: String
    let duration_days: Int?
    let title: String
    let description: String?
    let source_type: String
    let confidence: Double
    let attachments: [String]
    let linked_fact_ids: [String]
    let payload: String?
}

nonisolated struct UpdateJourneyEventPayload: Encodable, Sendable {
    let lane: String?
    let timestamp: String?
    let duration_days: Int?
    let title: String?
    let description: String?
    let confidence: Double?
    let attachments: [String]?
    let linked_fact_ids: [String]?
    let payload: String?
}

extension Notification.Name {
    static let journeyEventsChanged = Notification.Name("journeyEventsChanged")
}

/// Cache envelope persisted to UserDefaults. Includes a `cacheUserId` stamp so
/// account switches cannot leak events between users even if the keyspace is
/// somehow reused.
nonisolated struct JourneyCacheEnvelope: Codable, Sendable {
    let cacheUserId: String
    let events: [JourneyEvent]
    let fetchedRanges: [JourneyCacheRange]
}

nonisolated struct JourneyCacheRange: Codable, Sendable {
    let from: Date
    let to: Date
}

/// Persistence + auto-add hub for the Journey Map. Round-trips events through
/// Supabase per user, and keeps a local cache stamped with the userId so
/// account switches never leak events between users.
@MainActor
@Observable
final class JourneyEventService {
    static let shared = JourneyEventService()

    private(set) var events: [JourneyEvent] = []
    private(set) var isLoading: Bool = false
    /// True while a background range-fetch is in flight — drives the
    /// edge-shimmer band on the timeline.
    private(set) var isLoadingRange: Bool = false
    /// IDs of events that were just inserted locally — drives the live
    /// pin-add burst animation on the Journey Map. Each id auto-clears after
    /// ~700ms so the animation only fires once.
    private(set) var recentlyAddedIds: Set<UUID> = []
    private var loadedForUserId: String?
    private var fetchedRanges: [JourneyCacheRange] = []
    private var hasFetchedAllTime: Bool = false

    private var supabase: SupabaseClient { SupabaseService.shared.client }

    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private init() {
        loadCacheForCurrentUser()
        NotificationCenter.default.addObserver(
            forName: .authUserChanged,
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in
                let newUserId = note.userInfo?["userId"] as? String
                self?.handleAuthUserChanged(newUserId: newUserId)
            }
        }
    }

    // MARK: - Auth-aware cache

    private static func cacheKey(for userId: String) -> String {
        "peppal.journeyEvents.v1.\(userId)"
    }

    private func handleAuthUserChanged(newUserId: String?) {
        if newUserId == nil {
            // Sign-out: wipe in-memory state and EVERY journey-related
            // UserDefaults key so the next user can never see leftover pins.
            events = []
            fetchedRanges = []
            hasFetchedAllTime = false
            recentlyAddedIds = []
            Self.wipeAllJourneyCaches(forUserId: loadedForUserId)
            loadedForUserId = nil
            return
        }
        if newUserId != loadedForUserId {
            // User switch: drop the previous user's state, attempt to load this
            // user's stamped cache, and trigger a fresh Supabase pull.
            events = []
            fetchedRanges = []
            hasFetchedAllTime = false
            recentlyAddedIds = []
            loadCache(for: newUserId!)
            loadedForUserId = newUserId
            Task { try? await fetch() }
        }
    }

    /// Wipe every journey- and story-mode-related UserDefaults key for the
    /// signed-out user so leftover bytes can never leak across accounts.
    private static func wipeAllJourneyCaches(forUserId userId: String?) {
        let defaults = UserDefaults.standard
        if let userId, !userId.isEmpty {
            defaults.removeObject(forKey: cacheKey(for: userId))
            defaults.removeObject(forKey: "peppal.storymode.cache.v1.\(userId)")
        }
        // Defense-in-depth: scrub any other peppal.journeyEvents.* /
        // peppal.storymode.* keys (other accounts on this device) so a
        // misconfigured switch can't leak.
        for key in defaults.dictionaryRepresentation().keys {
            if key.hasPrefix("peppal.journeyEvents.v1.") || key.hasPrefix("peppal.storymode.cache.v1.") {
                defaults.removeObject(forKey: key)
            }
        }
    }

    private func loadCacheForCurrentUser() {
        guard let uid = try? AuthService.shared.currentUserId() else { return }
        loadCache(for: uid)
        loadedForUserId = uid
    }

    private func loadCache(for userId: String) {
        guard let data = UserDefaults.standard.data(forKey: Self.cacheKey(for: userId)) else { return }
        // Preferred path: stamped envelope. Only trust the cache if its stamp
        // matches the requested user.
        if let envelope = try? makeDecoder().decode(JourneyCacheEnvelope.self, from: data) {
            guard envelope.cacheUserId == userId else {
                UserDefaults.standard.removeObject(forKey: Self.cacheKey(for: userId))
                return
            }
            events = envelope.events.filter { $0.userId.uuidString.lowercased() == userId }
            fetchedRanges = envelope.fetchedRanges
            return
        }
        // Legacy path: bare [JourneyEvent] arrays from older app versions.
        if let decoded = try? makeDecoder().decode([JourneyEvent].self, from: data) {
            events = decoded.filter { $0.userId.uuidString.lowercased() == userId }
        }
    }

    private func persistCache() {
        guard let uid = loadedForUserId else { return }
        let envelope = JourneyCacheEnvelope(
            cacheUserId: uid,
            events: events,
            fetchedRanges: fetchedRanges
        )
        guard let data = try? makeEncoder().encode(envelope) else { return }
        UserDefaults.standard.set(data, forKey: Self.cacheKey(for: uid))
    }

    private func makeEncoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    // MARK: - Public API

    func events(in lane: JourneyLane) -> [JourneyEvent] {
        events.filter { $0.lane == lane }.sorted { $0.timestamp > $1.timestamp }
    }

    func events(in range: ClosedRange<Date>) -> [JourneyEvent] {
        events.filter { range.contains($0.timestamp) }.sorted { $0.timestamp > $1.timestamp }
    }

    /// Pull events for the signed-in user. Optionally constrain to a date range.
    @discardableResult
    func fetch(from: Date? = nil, to: Date? = nil) async throws -> [JourneyEvent] {
        let userId = try AuthService.shared.currentUserId()
        loadedForUserId = userId
        isLoading = true
        defer { isLoading = false }

        var query = supabase.from("journey_events")
            .select()
            .eq("user_id", value: userId)
        if let from {
            query = query.gte("timestamp", value: iso8601.string(from: from))
        }
        if let to {
            query = query.lte("timestamp", value: iso8601.string(from: to))
        }

        let rows: [SupabaseJourneyEvent] = try await query
            .order("timestamp", ascending: false)
            .limit(2000)
            .execute()
            .value

        let parsed = rows.compactMap(parse)
        // Merge into existing events instead of overwriting, so a tight
        // viewport fetch does not blow away pins outside the range that
        // were loaded by an earlier wide query.
        mergeFetched(parsed, range: from.flatMap { f in to.map { JourneyCacheRange(from: f, to: $0) } })
        if from == nil && to == nil { hasFetchedAllTime = true }
        persistCache()
        NotificationCenter.default.post(name: .journeyEventsChanged, object: nil)
        return parsed
    }

    /// Background fetch tied to the visible viewport range. The Journey Map
    /// calls this when the user zooms or pans — it skips the network if the
    /// range is already covered by a previous fetch (or by the all-time pull).
    func ensureRangeLoaded(from: Date, to: Date) async {
        guard !hasFetchedAllTime, !isRangeCovered(from: from, to: to) else { return }
        guard !isLoadingRange else { return }
        isLoadingRange = true
        defer { isLoadingRange = false }
        _ = try? await fetch(from: from, to: to)
    }

    /// Trigger an unconstrained background fetch (used when the user zooms
    /// to All time). Keeps the timeline responsive — the shimmer band is
    /// driven by `isLoadingRange`, not a blocking spinner.
    func ensureAllTimeLoaded() async {
        guard !hasFetchedAllTime, !isLoadingRange else { return }
        isLoadingRange = true
        defer { isLoadingRange = false }
        _ = try? await fetch()
    }

    private func isRangeCovered(from: Date, to: Date) -> Bool {
        for r in fetchedRanges where r.from <= from && r.to >= to {
            return true
        }
        return false
    }

    private func mergeFetched(_ incoming: [JourneyEvent], range: JourneyCacheRange?) {
        if let range {
            // Drop existing events inside this range that the server did not
            // return (so deletes sync down), then merge incoming.
            let incomingIds = Set(incoming.map(\.id))
            events.removeAll { e in
                e.timestamp >= range.from && e.timestamp <= range.to && !incomingIds.contains(e.id)
            }
            fetchedRanges.append(range)
        } else {
            // Full fetch — just replace.
            events.removeAll()
            fetchedRanges = []
        }
        var byId: [UUID: JourneyEvent] = Dictionary(uniqueKeysWithValues: events.map { ($0.id, $0) })
        for e in incoming { byId[e.id] = e }
        events = byId.values.sorted { $0.timestamp > $1.timestamp }
    }

    @discardableResult
    func add(_ event: JourneyEvent) async -> JourneyEvent {
        // Dedup: when a user manually adds a pin to a lane, drop any HealthKit-
        // (or workout-/dose-/bloodwork-)sourced auto-import in the same lane on
        // the same calendar day. The manual pin always wins — it's the curated
        // version. Without this, a Chapter-4 "started cycle April 10" pin
        // collides with the HK workout cluster from the same day.
        if event.sourceType == .manual {
            await dedupAutoImports(matching: event)
        }
        // Optimistic local insert.
        let working = event
        if !events.contains(where: { $0.id == event.id }) {
            events.insert(working, at: 0)
            recentlyAddedIds.insert(working.id)
            let id = working.id
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(750))
                self.recentlyAddedIds.remove(id)
            }
            persistCache()
            NotificationCenter.default.post(
                name: .journeyEventsChanged,
                object: nil,
                userInfo: ["insertedId": working.id.uuidString, "lane": working.lane.rawValue]
            )
        }

        do {
            let payloadJSON = encodePayload(event.payload)
            let insert = InsertJourneyEventPayload(
                id: event.id.uuidString.lowercased(),
                user_id: event.userId.uuidString.lowercased(),
                lane: event.lane.rawValue,
                timestamp: iso8601.string(from: event.timestamp),
                duration_days: event.durationDays,
                title: event.title,
                description: event.description,
                source_type: event.sourceType.rawValue,
                confidence: event.confidence,
                attachments: event.attachments.map { $0.absoluteString },
                linked_fact_ids: event.linkedFactIds.map { $0.uuidString.lowercased() },
                payload: payloadJSON
            )
            let _: SupabaseJourneyEvent = try await supabase
                .from("journey_events")
                .insert(insert)
                .select()
                .single()
                .execute()
                .value
        } catch {
            print("[JourneyEventService] add failed: \(error)")
        }
        return working
    }

    func update(_ event: JourneyEvent) async {
        if let idx = events.firstIndex(where: { $0.id == event.id }) {
            events[idx] = event
            persistCache()
            NotificationCenter.default.post(name: .journeyEventsChanged, object: nil)
        }
        do {
            let update = UpdateJourneyEventPayload(
                lane: event.lane.rawValue,
                timestamp: iso8601.string(from: event.timestamp),
                duration_days: event.durationDays,
                title: event.title,
                description: event.description,
                confidence: event.confidence,
                attachments: event.attachments.map { $0.absoluteString },
                linked_fact_ids: event.linkedFactIds.map { $0.uuidString.lowercased() },
                payload: encodePayload(event.payload)
            )
            try await supabase
                .from("journey_events")
                .update(update)
                .eq("id", value: event.id.uuidString.lowercased())
                .execute()
        } catch {
            print("[JourneyEventService] update failed: \(error)")
        }
    }

    func delete(_ event: JourneyEvent) async {
        events.removeAll { $0.id == event.id }
        persistCache()
        NotificationCenter.default.post(name: .journeyEventsChanged, object: nil)
        do {
            try await supabase
                .from("journey_events")
                .delete()
                .eq("id", value: event.id.uuidString.lowercased())
                .execute()
        } catch {
            print("[JourneyEventService] delete failed: \(error)")
        }
    }

    // MARK: - Dedup

    /// Removes auto-imported pins (sourceType != .manual) that share lane +
    /// calendar day with the incoming manual event, both locally and in
    /// Supabase. Idempotent — no-op when nothing matches.
    private func dedupAutoImports(matching manual: JourneyEvent) async {
        let cal = Calendar.current
        let manualDay = cal.startOfDay(for: manual.timestamp)
        let collisions = events.filter { existing in
            guard existing.id != manual.id else { return false }
            guard existing.lane == manual.lane else { return false }
            guard existing.sourceType != .manual else { return false }
            return cal.isDate(existing.timestamp, inSameDayAs: manualDay)
        }
        guard !collisions.isEmpty else { return }
        let collisionIds = Set(collisions.map { $0.id })
        events.removeAll { collisionIds.contains($0.id) }
        persistCache()
        for victim in collisions {
            do {
                try await supabase
                    .from("journey_events")
                    .delete()
                    .eq("id", value: victim.id.uuidString.lowercased())
                    .execute()
            } catch {
                print("[JourneyEventService] dedup delete failed: \(error)")
            }
        }
    }

    // MARK: - Auto-add helpers

    /// Convenience used by service hooks (DoseLogger, WorkoutService, …) so they
    /// can append a pin without knowing the userId or shape.
    func autoAdd(
        lane: JourneyLane,
        timestamp: Date,
        title: String,
        description: String? = nil,
        sourceType: JourneySourceType,
        confidence: Double = 0.95,
        durationDays: Int? = nil,
        payload: JourneyEventPayload? = nil
    ) {
        guard let uidStr = try? AuthService.shared.currentUserId(),
              let uid = UUID(uuidString: uidStr) else { return }
        let event = JourneyEvent(
            userId: uid,
            lane: lane,
            timestamp: timestamp,
            durationDays: durationDays,
            title: title,
            description: description,
            sourceType: sourceType,
            confidence: confidence,
            payload: payload
        )
        Task { await self.add(event) }
    }

    // MARK: - Parsing

    private func parse(_ row: SupabaseJourneyEvent) -> JourneyEvent? {
        guard let idStr = row.id, let id = UUID(uuidString: idStr) else { return nil }
        guard let userId = UUID(uuidString: row.user_id) else { return nil }
        guard let lane = JourneyLane(rawValue: row.lane) else { return nil }
        guard let source = JourneySourceType(rawValue: row.source_type) else { return nil }
        let ts = iso8601.date(from: row.timestamp) ?? Date()
        let attachments: [URL] = (row.attachments ?? []).compactMap(URL.init(string:))
        let factIds: [UUID] = (row.linked_fact_ids ?? []).compactMap(UUID.init(uuidString:))
        let payload: JourneyEventPayload? = decodePayload(row.payload)
        return JourneyEvent(
            id: id,
            userId: userId,
            lane: lane,
            timestamp: ts,
            durationDays: row.duration_days,
            title: row.title,
            description: row.description,
            sourceType: source,
            confidence: row.confidence ?? 1.0,
            attachments: attachments,
            linkedFactIds: factIds,
            payload: payload
        )
    }

    private func encodePayload(_ payload: JourneyEventPayload?) -> String? {
        guard let payload else { return nil }
        guard let data = try? makeEncoder().encode(payload) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func decodePayload(_ s: String?) -> JourneyEventPayload? {
        guard let s, let data = s.data(using: .utf8) else { return nil }
        return try? makeDecoder().decode(JourneyEventPayload.self, from: data)
    }
}

/*
 SUPABASE MIGRATION (run once):

 CREATE TABLE IF NOT EXISTS journey_events (
   id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
   lane text NOT NULL,
   timestamp timestamptz NOT NULL,
   duration_days int,
   title text NOT NULL,
   description text,
   source_type text NOT NULL,
   confidence double precision DEFAULT 1.0,
   attachments text[] DEFAULT '{}',
   linked_fact_ids uuid[] DEFAULT '{}',
   payload text,
   created_at timestamptz NOT NULL DEFAULT now()
 );
 CREATE INDEX IF NOT EXISTS journey_events_user_ts_idx
   ON journey_events (user_id, timestamp DESC);
 ALTER TABLE journey_events ENABLE ROW LEVEL SECURITY;
 CREATE POLICY "users select own journey events" ON journey_events
   FOR SELECT TO authenticated USING (auth.uid() = user_id);
 CREATE POLICY "users insert own journey events" ON journey_events
   FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
 CREATE POLICY "users update own journey events" ON journey_events
   FOR UPDATE TO authenticated USING (auth.uid() = user_id);
 CREATE POLICY "users delete own journey events" ON journey_events
   FOR DELETE TO authenticated USING (auth.uid() = user_id);
 */
