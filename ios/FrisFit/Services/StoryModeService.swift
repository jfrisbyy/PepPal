import Foundation
import SwiftUI

/// Builds the beat sequence for Story Mode and manages the cached narration
/// lines that the cinematic player reads.
@MainActor
@Observable
final class StoryModeService {
    static let shared = StoryModeService()

    private(set) var isLoading: Bool = false
    private(set) var lastBeats: [StoryBeat] = []

    private init() {}

    // MARK: - Public API

    /// Build (and cache narration for) the beat sequence for the current user.
    func buildBeats(firstName: String?) async -> [StoryBeat] {
        isLoading = true
        defer { isLoading = false }

        let events = JourneyEventService.shared.events
            .sorted { $0.timestamp < $1.timestamp }

        // Pick "significant" events. Cap at ~7 mid beats so total runtime stays
        // under ~30s at 4s per beat.
        let significant = significantEvents(from: events)

        let signature = signature(for: events, firstName: firstName)
        var cache = loadCache()
        let needsRegen = cache.lastSignature != signature

        // Generate or reuse narration lines.
        if needsRegen {
            cache = await regenerateNarration(
                events: significant,
                firstName: firstName,
                priorCache: cache,
                signature: signature
            )
            persist(cache)
        }

        // Build beats.
        var beats: [StoryBeat] = []

        // Beat 1 — Opening title card.
        let openingNarration = cache.entries["__opening__"]?.line
            ?? defaultOpeningLine(firstName: firstName)
        beats.append(
            StoryBeat(
                kind: .opening,
                title: "Your story so far\(firstName.map { ", \($0)" } ?? "")",
                subtitle: nil,
                narration: openingNarration,
                stats: openingStats(events: events),
                palette: .opening
            )
        )

        // Mid beats — one per significant event.
        for event in significant {
            let cached = cache.entries[event.id.uuidString]?.line
            beats.append(makeEventBeat(event: event, narration: cached ?? defaultEventLine(event)))
        }

        // Penultimate beat — "Where you are now"
        let currentLine = cache.entries["__current__"]?.line ?? defaultCurrentLine()
        beats.append(makeCurrentBeat(events: events, narration: currentLine))

        // Final beat — "What's next"
        let futureLine = cache.entries["__future__"]?.line ?? defaultFutureLine()
        beats.append(makeFutureBeat(narration: futureLine))

        // End watermark
        beats.append(
            StoryBeat(
                kind: .end,
                title: "Tracked with EPTI",
                subtitle: "Your story, your data.",
                narration: "",
                palette: .end
            )
        )

        lastBeats = beats
        return beats
    }

    // MARK: - Significant event selection

    private func significantEvents(from events: [JourneyEvent]) -> [JourneyEvent] {
        // Prefer compound cycle starts/ends, body milestones, training phases,
        // bloodwork events. Hard cap so the story stays brisk.
        let priorityLanes: [JourneyLane] = [.body, .compounds, .training, .bloodwork]
        let filtered = events.filter { priorityLanes.contains($0.lane) }
        guard filtered.count > 7 else { return filtered }

        // Spread across time: keep first, last, and evenly-spaced events between.
        var keep: [JourneyEvent] = []
        let stride = max(1, filtered.count / 7)
        for i in Swift.stride(from: 0, to: filtered.count, by: stride) {
            keep.append(filtered[i])
            if keep.count == 7 { break }
        }
        if let last = filtered.last, keep.last?.id != last.id {
            keep[keep.count - 1] = last
        }
        return keep
    }

    // MARK: - Beat factories

    private func makeEventBeat(event: JourneyEvent, narration: String) -> StoryBeat {
        let palette = StoryPalette.forLane(event.lane, compoundName: event.payload?.compoundName)
        let dateFmt = Date.FormatStyle.dateTime.month(.abbreviated).year()
        let dateLabel = event.timestamp.formatted(dateFmt)
        let stats = statsForEvent(event)
        return StoryBeat(
            kind: .event,
            eventId: event.id,
            lane: event.lane,
            title: event.title,
            subtitle: event.description,
            narration: narration,
            stats: stats,
            palette: palette,
            dateLabel: dateLabel,
            attachmentURL: event.attachments.first
        )
    }

    private func makeCurrentBeat(events: [JourneyEvent], narration: String) -> StoryBeat {
        var stats: [StoryStat] = []
        if let latestWeight = events.last(where: { $0.lane == .body && $0.payload?.weightLbs != nil })?.payload?.weightLbs {
            stats.append(StoryStat(label: "Now", value: "\(Int(latestWeight)) lb", icon: "scalemass.fill"))
        }
        if let activeCompound = events
            .filter({ $0.lane == .compounds })
            .last(where: { ($0.payload?.endDate ?? .distantFuture) > Date() })?
            .payload?.compoundName {
            stats.append(StoryStat(label: "Cycle", value: activeCompound, icon: "syringe.fill"))
        }
        let streak = StreakManager.shared.streakData.currentStreak
        if streak > 0 {
            stats.append(StoryStat(label: "Streak", value: "\(streak) days", icon: "flame.fill"))
        }
        return StoryBeat(
            kind: .currentSummary,
            title: "Where you are now",
            subtitle: nil,
            narration: narration,
            stats: stats,
            palette: .summary
        )
    }

    private func makeFutureBeat(narration: String) -> StoryBeat {
        return StoryBeat(
            kind: .future,
            title: "What's next",
            subtitle: nil,
            narration: narration,
            stats: [],
            palette: .future
        )
    }

    private func statsForEvent(_ event: JourneyEvent) -> [StoryStat] {
        var stats: [StoryStat] = []
        if let w = event.payload?.weightLbs {
            stats.append(StoryStat(label: "Weight", value: "\(Int(w)) lb", icon: "scalemass"))
        }
        if let bf = event.payload?.bodyFatPercent {
            stats.append(StoryStat(label: "Body fat", value: String(format: "%.1f%%", bf), icon: "figure"))
        }
        if let dose = event.payload?.doseAmount, let unit = event.payload?.doseUnit {
            stats.append(StoryStat(label: "Dose", value: "\(formatDose(dose)) \(unit)", icon: "syringe"))
        }
        if let freq = event.payload?.frequency {
            stats.append(StoryStat(label: "Schedule", value: freq, icon: "calendar"))
        }
        if let phase = event.payload?.phaseType {
            stats.append(StoryStat(label: "Phase", value: phase.capitalized, icon: "dumbbell"))
        }
        return Array(stats.prefix(3))
    }

    private func formatDose(_ d: Double) -> String {
        if d.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(d))
        }
        return String(format: "%.2f", d)
    }

    // MARK: - Default fallback narration

    private func defaultOpeningLine(firstName: String?) -> String {
        if let n = firstName, !n.isEmpty {
            return "Here's how far you've come, \(n)."
        }
        return "Here's how far you've come."
    }

    private func defaultEventLine(_ event: JourneyEvent) -> String {
        switch event.lane {
        case .body:
            if let w = event.payload?.weightLbs {
                return "You logged \(Int(w)) pounds — another step in your story."
            }
            return "A moment worth marking."
        case .compounds:
            if let name = event.payload?.compoundName {
                return "You started \(name) — a new chapter in your protocol."
            }
            return "A new compound entered the picture."
        case .training:
            if let phase = event.payload?.phaseType {
                return "You moved into a \(phase) phase — the work was about to shift."
            }
            return "Training kept moving forward."
        case .bloodwork:
            return "Bloodwork drawn — facts on the page, not just feelings."
        case .life:
            return "Life happened, and you kept going."
        case .agentAnnotation:
            return "A pattern worth noticing emerged."
        }
    }

    private func defaultCurrentLine() -> String {
        "Here's where you stand right now."
    }

    private func defaultFutureLine() -> String {
        "Keep showing up — your goal is closer than it feels."
    }

    private func openingStats(events: [JourneyEvent]) -> [StoryStat] {
        var stats: [StoryStat] = []
        let body = events.filter { $0.lane == .body }
        if let first = body.first?.payload?.weightLbs, let last = body.last?.payload?.weightLbs, abs(last - first) >= 1 {
            let delta = last - first
            let arrow = delta < 0 ? "arrow.down" : "arrow.up"
            stats.append(StoryStat(label: "Weight", value: "\(delta < 0 ? "-" : "+")\(Int(abs(delta))) lb", icon: arrow))
        }
        let workouts = events.filter { $0.lane == .training || $0.sourceType == .workout }.count
        if workouts > 0 {
            stats.append(StoryStat(label: "Sessions", value: "\(workouts)", icon: "dumbbell.fill"))
        }
        return stats
    }

    // MARK: - Narration generation (fast tier)

    private func regenerateNarration(
        events: [JourneyEvent],
        firstName: String?,
        priorCache: StoryNarrationCache,
        signature: String
    ) async -> StoryNarrationCache {
        let memo = AIMemoryStore.shared.memoForAgent(limit: 10)
        let narrativeFact = AIMemoryStore.shared.facts(kinds: [.pattern])
            .first(where: { $0.domain == "cross" })?.headline ?? ""

        let system = """
        You are EPTI's Story Mode narrator. Write short, warm, second-person narration lines for a \
        cinematic playthrough of the user's journey. ONE line per moment, max 16 words. Use lowercase \
        punctuation freely. No emojis. No clinical phrasing. No medical advice. No quotation marks. \
        Sound like an encouraging coach, never hyped, never saccharine. Output ONLY a JSON object \
        with the requested keys, each value a single sentence string.
        """

        var moments: [String] = []
        moments.append("__opening__: opening title beat — set the tone, address the user by first name if provided")
        for e in events {
            moments.append("\(e.id.uuidString): \(beatSummary(e))")
        }
        moments.append("__current__: present-day status summary")
        moments.append("__future__: aspirational forward-looking line about the user's goal")

        var userPrompt = ""
        if !memo.isEmpty { userPrompt += memo + "\n\n" }
        if !narrativeFact.isEmpty { userPrompt += "Overall arc: \(narrativeFact)\n\n" }
        if let n = firstName, !n.isEmpty { userPrompt += "First name: \(n)\n\n" }
        userPrompt += "Write narration lines for these keys (return JSON only, no prose around it):\n"
        userPrompt += moments.joined(separator: "\n")

        do {
            let raw = try await OpenRouterClient.shared.chat(
                tier: .fast,
                systemPrompt: system,
                userPrompt: userPrompt,
                maxTokens: 800,
                temperature: 0.65,
                timeout: 18,
                promptId: "story_mode"
            )
            let cleaned = OpenRouterClient.extractJSON(raw)
            if let data = cleaned.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                var entries: [String: StoryNarrationCacheEntry] = [:]
                for (key, value) in json {
                    entries[key] = StoryNarrationCacheEntry(
                        eventId: key,
                        line: cleanLine(value),
                        generatedAt: Date()
                    )
                }
                return StoryNarrationCache(
                    entries: entries,
                    lastSignature: signature,
                    lastGeneratedAt: Date()
                )
            }
        } catch {
            print("[StoryModeService] narration regen failed: \(error)")
        }
        return StoryNarrationCache(
            entries: priorCache.entries,
            lastSignature: signature,
            lastGeneratedAt: Date()
        )
    }

    private func beatSummary(_ e: JourneyEvent) -> String {
        let date = e.timestamp.formatted(.dateTime.month(.abbreviated).year())
        var s = "\(e.lane.rawValue) on \(date) — \(e.title)"
        if let w = e.payload?.weightLbs { s += ", \(Int(w)) lb" }
        if let name = e.payload?.compoundName { s += ", \(name)" }
        if let dose = e.payload?.doseAmount, let unit = e.payload?.doseUnit { s += " \(formatDose(dose))\(unit)" }
        if let freq = e.payload?.frequency { s += " \(freq)" }
        if let phase = e.payload?.phaseType { s += ", \(phase) phase" }
        return s
    }

    private func cleanLine(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
    }

    // MARK: - Cache persistence

    private static let diskFile = "storymode.cache.v1"

    private var cacheUserId: String {
        ((try? AuthService.shared.currentUserId()) ?? "").lowercased()
    }

    /// Legacy UserDefaults key for one-shot migration to disk.
    private var legacyDefaultsKey: String {
        let uid = (try? AuthService.shared.currentUserId()) ?? "anon"
        return "peppal.storymode.cache.v1.\(uid)"
    }

    private func loadCache() -> StoryNarrationCache {
        let uid = cacheUserId
        if !uid.isEmpty,
           let cache = PerUserDiskStore.load(StoryNarrationCache.self, userId: uid, name: Self.diskFile) {
            return cache
        }
        // Legacy migration from UserDefaults — promote to disk and clear the
        // original key so the next read is purely disk-backed.
        if let data = UserDefaults.standard.data(forKey: legacyDefaultsKey),
           let decoded = try? JSONDecoder().decode(StoryNarrationCache.self, from: data) {
            UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
            if !uid.isEmpty {
                PerUserDiskStore.save(decoded, userId: uid, name: Self.diskFile)
            }
            return decoded
        }
        return .empty
    }

    private func persist(_ cache: StoryNarrationCache) {
        let uid = cacheUserId
        guard !uid.isEmpty else { return }
        PerUserDiskStore.save(cache, userId: uid, name: Self.diskFile)
    }

    private func signature(for events: [JourneyEvent], firstName: String?) -> String {
        let parts = events.map { "\($0.id.uuidString):\(Int($0.timestamp.timeIntervalSince1970))" }
        return (firstName ?? "") + "|" + parts.joined(separator: ",")
    }
}
