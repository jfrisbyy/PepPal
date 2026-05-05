import Foundation
import SwiftUI

/// One beat of Story Mode. Each beat is a 9:16 cinematic card.
nonisolated enum StoryBeatKind: String, Codable, Sendable {
    case opening
    case event
    case currentSummary
    case future
    case end
}

/// A single beat in the playthrough.
nonisolated struct StoryBeat: Identifiable, Sendable {
    let id: UUID
    let kind: StoryBeatKind
    let eventId: UUID?
    let lane: JourneyLane?
    let title: String
    let subtitle: String?
    let narration: String
    let stats: [StoryStat]
    let palette: StoryPalette
    let dateLabel: String?
    let attachmentURL: URL?

    init(
        id: UUID = UUID(),
        kind: StoryBeatKind,
        eventId: UUID? = nil,
        lane: JourneyLane? = nil,
        title: String,
        subtitle: String? = nil,
        narration: String,
        stats: [StoryStat] = [],
        palette: StoryPalette,
        dateLabel: String? = nil,
        attachmentURL: URL? = nil
    ) {
        self.id = id
        self.kind = kind
        self.eventId = eventId
        self.lane = lane
        self.title = title
        self.subtitle = subtitle
        self.narration = narration
        self.stats = stats
        self.palette = palette
        self.dateLabel = dateLabel
        self.attachmentURL = attachmentURL
    }
}

/// Supporting stat chip rendered alongside a beat.
nonisolated struct StoryStat: Identifiable, Sendable, Hashable {
    let id: UUID = UUID()
    let label: String
    let value: String
    let icon: String?
}

/// Per-beat tonal palette. Soft, organic, Headspace-style washes.
@MainActor
struct StoryPalette: Sendable, Hashable {
    let top: Color
    let bottom: Color
    let accent: Color

    static let opening = StoryPalette(
        top: Color(red: 18/255, green: 24/255, blue: 38/255),
        bottom: Color(red: 12/255, green: 16/255, blue: 26/255),
        accent: Color(red: 130/255, green: 180/255, blue: 255/255)
    )

    static let summary = StoryPalette(
        top: Color(red: 20/255, green: 30/255, blue: 30/255),
        bottom: Color(red: 12/255, green: 18/255, blue: 22/255),
        accent: PepTheme.teal
    )

    static let future = StoryPalette(
        top: Color(red: 60/255, green: 36/255, blue: 18/255),
        bottom: Color(red: 24/255, green: 16/255, blue: 12/255),
        accent: Color(red: 255/255, green: 200/255, blue: 110/255)
    )

    static let end = StoryPalette(
        top: Color(red: 16/255, green: 16/255, blue: 22/255),
        bottom: Color(red: 8/255, green: 8/255, blue: 12/255),
        accent: PepTheme.teal
    )

    static func forLane(_ lane: JourneyLane, compoundName: String? = nil) -> StoryPalette {
        switch lane {
        case .body:
            return StoryPalette(
                top: Color(red: 18/255, green: 36/255, blue: 30/255),
                bottom: Color(red: 8/255, green: 18/255, blue: 16/255),
                accent: Color(red: 120/255, green: 220/255, blue: 170/255)
            )
        case .compounds:
            let accent = JourneyCompoundPalette.accent(for: compoundName)
            return StoryPalette(
                top: Color(red: 14/255, green: 28/255, blue: 36/255),
                bottom: Color(red: 8/255, green: 14/255, blue: 22/255),
                accent: accent
            )
        case .training:
            return StoryPalette(
                top: Color(red: 38/255, green: 24/255, blue: 14/255),
                bottom: Color(red: 18/255, green: 12/255, blue: 8/255),
                accent: Color(red: 255/255, green: 170/255, blue: 80/255)
            )
        case .bloodwork:
            return StoryPalette(
                top: Color(red: 16/255, green: 22/255, blue: 40/255),
                bottom: Color(red: 8/255, green: 12/255, blue: 22/255),
                accent: PepTheme.blue
            )
        case .life:
            return StoryPalette(
                top: Color(red: 30/255, green: 22/255, blue: 44/255),
                bottom: Color(red: 14/255, green: 10/255, blue: 22/255),
                accent: PepTheme.violet
            )
        case .agentAnnotation:
            return StoryPalette(
                top: Color(red: 36/255, green: 30/255, blue: 14/255),
                bottom: Color(red: 18/255, green: 14/255, blue: 8/255),
                accent: PepTheme.amber
            )
        }
    }
}

/// Cached narration line per event id, regenerated when journey events change.
nonisolated struct StoryNarrationCacheEntry: Codable, Sendable {
    let eventId: String
    let line: String
    let generatedAt: Date
}

nonisolated struct StoryNarrationCache: Codable, Sendable {
    /// keyed by `event uuid` plus reserved keys: `__opening__`, `__current__`, `__future__`.
    var entries: [String: StoryNarrationCacheEntry]
    var lastSignature: String
    var lastGeneratedAt: Date

    static let empty = StoryNarrationCache(entries: [:], lastSignature: "", lastGeneratedAt: .distantPast)
}

@MainActor
enum StoryModeMotion {
    static let beatIn: Animation = .spring(response: 0.6, dampingFraction: 0.9)
    static let pinHero: Animation = .spring(response: 0.55, dampingFraction: 0.78)
    static let textWord: Animation = .easeOut(duration: 0.32)
}
