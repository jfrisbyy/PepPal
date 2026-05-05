import Foundation

/// Lightweight analytics logger for peptide-tracking conversion events.
///
/// Emits to local logs today; once a real analytics pipeline (PostHog,
/// Mixpanel, etc.) lands the `track` implementation can be swapped in one place.
nonisolated enum PeptideAnalytics: Sendable {
    /// Surface that triggered the activation flow.
    nonisolated enum Surface: String, Sendable {
        case scanner
        case protocols
        case reconstitution
        case inventory
        case doseLog = "dose_log"
        case stackBuilder = "stack_builder"
        case protocolHistory = "protocol_history"
        case guidedInjection = "guided_injection"
        case agentSuggestion = "agent_suggestion"
        case settingsToggle = "settings_toggle"
    }

    /// Logged when the user finishes the activation flow and selects a track (B or C).
    static func activatedPeptideTracking(from surface: Surface, resolvedTrack: PersonaTrack) {
        let event: [String: String] = [
            "event": "activated_peptide_tracking",
            "surface": surface.rawValue,
            "persona_track": resolvedTrack.rawValue,
            "ts": ISO8601DateFormatter().string(from: Date())
        ]
        print("[analytics] \(event)")
    }

    /// Logged when the user opens an empty-state surface (impression).
    static func viewedTrackAEmptyState(surface: Surface) {
        let event: [String: String] = [
            "event": "viewed_track_a_empty_state",
            "surface": surface.rawValue,
            "ts": ISO8601DateFormatter().string(from: Date())
        ]
        print("[analytics] \(event)")
    }

    /// Logged when the user taps the activation CTA.
    static func tappedActivationCTA(surface: Surface) {
        let event: [String: String] = [
            "event": "tapped_activate_peptide_tracking",
            "surface": surface.rawValue,
            "ts": ISO8601DateFormatter().string(from: Date())
        ]
        print("[analytics] \(event)")
    }

    // MARK: - Onboarding funnel (Prompt 19, issues 11+12)

    static func onboardingStarted() {
        let event: [String: String] = [
            "event": "onboarding_started",
            "ts": ISO8601DateFormatter().string(from: Date())
        ]
        print("[analytics] \(event)")
    }

    static func onboardingChapterStarted(chapter: String, persona: String?) {
        var event: [String: String] = [
            "event": "onboarding_chapter_started",
            "chapter": chapter,
            "ts": ISO8601DateFormatter().string(from: Date())
        ]
        if let persona { event["persona_track"] = persona }
        print("[analytics] \(event)")
    }

    static func onboardingChapterCompleted(chapter: String, persona: String?, secondsInChapter: Int) {
        var event: [String: String] = [
            "event": "onboarding_chapter_completed",
            "chapter": chapter,
            "seconds_in_chapter": String(secondsInChapter),
            "ts": ISO8601DateFormatter().string(from: Date())
        ]
        if let persona { event["persona_track"] = persona }
        print("[analytics] \(event)")
    }

    static func onboardingChapterAbandoned(chapter: String, reason: String) {
        let event: [String: String] = [
            "event": "onboarding_chapter_abandoned",
            "chapter": chapter,
            "reason": reason,
            "ts": ISO8601DateFormatter().string(from: Date())
        ]
        print("[analytics] \(event)")
    }

    static func onboardingCompleted(persona: String?, totalSeconds: Int, perChapterSeconds: [String: Int]) {
        var event: [String: String] = [
            "event": "onboarding_completed",
            "total_seconds": String(totalSeconds),
            "ts": ISO8601DateFormatter().string(from: Date())
        ]
        if let persona { event["persona_track"] = persona }
        for (k, v) in perChapterSeconds { event["sec_\(k)"] = String(v) }
        print("[analytics] \(event)")
    }
}
