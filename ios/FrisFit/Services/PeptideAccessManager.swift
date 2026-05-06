import Foundation
import SwiftUI

@Observable
@MainActor
final class PeptideAccessManager {
    static let shared = PeptideAccessManager()

    private let pregnancyKey = "peppal.compoundSurfaces.isPregnantOrNursing.v1"
    private let dobKey = "peppal.compoundSurfaces.dateOfBirth.v1"
    private let sexKey = "peppal.compoundSurfaces.biologicalSex.v1"
    private let personaKey = "peppal.compoundSurfaces.personaTrack.v1"
    private let pregnancyAnsweredAtKey = "peppal.compoundSurfaces.pregnancyAnsweredAt.v1"
    private let pregnancyRecheckSnoozedUntilKey = "peppal.compoundSurfaces.pregnancyRecheckSnoozedUntil.v1"

    /// Re-prompt female users every 90 days to confirm pregnancy/nursing status.
    static let pregnancyRecheckIntervalDays: Int = 90

    var isPregnantOrNursing: Bool {
        didSet { UserDefaults.standard.set(isPregnantOrNursing, forKey: pregnancyKey) }
    }
    var dateOfBirth: Date? {
        didSet { UserDefaults.standard.set(dateOfBirth, forKey: dobKey) }
    }
    var biologicalSex: BiologicalSex? {
        didSet { UserDefaults.standard.set(biologicalSex?.rawValue, forKey: sexKey) }
    }
    var personaTrack: PersonaTrack? {
        didSet { UserDefaults.standard.set(personaTrack?.rawValue, forKey: personaKey) }
    }
    private(set) var pregnancyAnsweredAt: Date? {
        didSet { UserDefaults.standard.set(pregnancyAnsweredAt, forKey: pregnancyAnsweredAtKey) }
    }
    private(set) var pregnancyRecheckSnoozedUntil: Date? {
        didSet { UserDefaults.standard.set(pregnancyRecheckSnoozedUntil, forKey: pregnancyRecheckSnoozedUntilKey) }
    }

    private var authObserver: NSObjectProtocol?

    private init() {
        self.isPregnantOrNursing = UserDefaults.standard.bool(forKey: pregnancyKey)
        self.dateOfBirth = UserDefaults.standard.object(forKey: dobKey) as? Date
        if let raw = UserDefaults.standard.string(forKey: sexKey) {
            self.biologicalSex = BiologicalSex(rawValue: raw)
        } else {
            self.biologicalSex = nil
        }
        if let raw = UserDefaults.standard.string(forKey: personaKey) {
            self.personaTrack = PersonaTrack(rawValue: raw)
        } else {
            self.personaTrack = nil
        }
        self.pregnancyAnsweredAt = UserDefaults.standard.object(forKey: pregnancyAnsweredAtKey) as? Date
        self.pregnancyRecheckSnoozedUntil = UserDefaults.standard.object(forKey: pregnancyRecheckSnoozedUntilKey) as? Date
        observeAuthChanges()
    }

    /// True when we should surface the periodic pregnancy/nursing re-check prompt.
    /// Only applies to female users with pregnancy-relevant answers older than the interval
    /// and not currently snoozed. Users who already report pregnancy stay locked silently —
    /// the re-prompt is for `false` answers that may have changed.
    var shouldPromptPregnancyRecheck: Bool {
        guard biologicalSex == .female else { return false }
        guard !isPregnantOrNursing else { return false }
        if let snoozed = pregnancyRecheckSnoozedUntil, snoozed > Date() { return false }
        guard let answeredAt = pregnancyAnsweredAt else { return false }
        let interval = Double(Self.pregnancyRecheckIntervalDays) * 86400
        return Date().timeIntervalSince(answeredAt) >= interval
    }

    /// User confirmed status during a re-check (or chose to keep current answer).
    func recordPregnancyRecheck(isPregnantOrNursing value: Bool) {
        self.isPregnantOrNursing = value
        self.pregnancyAnsweredAt = Date()
        self.pregnancyRecheckSnoozedUntil = nil
        Task { await OnboardingManager.persistPregnancyAnswer(value) }
    }

    /// Snooze the re-check for ~14 days when the user dismisses the prompt.
    func snoozePregnancyRecheck(days: Int = 14) {
        let interval = Double(days) * 86400
        self.pregnancyRecheckSnoozedUntil = Date().addingTimeInterval(interval)
    }

    private func observeAuthChanges() {
        authObserver = NotificationCenter.default.addObserver(
            forName: .authUserChanged,
            object: nil,
            queue: .main
        ) { _ in
            Task { await OnboardingManager.hydratePersonaFromRemote() }
        }
    }

    /// Called by `LocalStateResetCoordinator` on sign-out / account switch.
    /// The backing UserDefaults keys have already been wiped at that point;
    /// here we just clear the in-memory mirrors so observing views render
    /// the empty/locked state until the new account hydrates from Supabase.
    func handleSignOutOrUserSwitch() {
        isPregnantOrNursing = false
        dateOfBirth = nil
        biologicalSex = nil
        personaTrack = nil
        pregnancyAnsweredAt = nil
        pregnancyRecheckSnoozedUntil = nil
    }

    /// True when the user is on Track A — peptide-related surfaces should render
    /// an educational empty state with an activation CTA instead of real content.
    var shouldShowTrackAEmptyState: Bool {
        personaTrack == .A
    }

    /// Updates the persona track locally and mirrors it to Supabase.
    func setPersonaTrack(_ track: PersonaTrack) {
        self.personaTrack = track
        Task { await OnboardingManager.persistPersona(track) }
    }

    var ageInYears: Int? {
        guard let dob = dateOfBirth else { return nil }
        return Calendar.current.dateComponents([.year], from: dob, to: Date()).year
    }

    var isAdult: Bool {
        if let age = ageInYears { return age >= 18 }
        return false
    }

    /// True iff the user has acknowledged the disclaimer, is 18+, and is not currently pregnant/nursing.
    var canAccessCompoundSurfaces: Bool {
        guard MedicalDisclaimerManager.hasAccepted else { return false }
        guard isAdult else { return false }
        if biologicalSex == .female, isPregnantOrNursing { return false }
        return true
    }

    var lockReason: LockReason? {
        if !MedicalDisclaimerManager.hasAccepted { return .disclaimer }
        if !isAdult { return .underAge }
        if biologicalSex == .female, isPregnantOrNursing { return .pregnancyNursing }
        return nil
    }

    func updateFromOnboarding(dateOfBirth: Date?, biologicalSex: BiologicalSex?, isPregnantOrNursing: Bool?) {
        if let dateOfBirth { self.dateOfBirth = dateOfBirth }
        if let biologicalSex { self.biologicalSex = biologicalSex }
        if let isPregnantOrNursing {
            self.isPregnantOrNursing = isPregnantOrNursing
            self.pregnancyAnsweredAt = Date()
        }
    }

    func setPregnancyState(_ value: Bool) {
        self.isPregnantOrNursing = value
        self.pregnancyAnsweredAt = Date()
        Task { await OnboardingManager.persistPregnancyAnswer(value) }
    }

    enum LockReason {
        case disclaimer
        case underAge
        case pregnancyNursing

        var title: String {
            switch self {
            case .disclaimer: return "Disclaimer required"
            case .underAge: return "18+ only"
            case .pregnancyNursing: return "Locked while pregnant or nursing"
            }
        }

        var message: String {
            switch self {
            case .disclaimer:
                return "Acknowledge the medical disclaimer to continue."
            case .underAge:
                return "EPTI's compound surfaces are only available to users 18 and older."
            case .pregnancyNursing:
                return "Compound tracking stays locked while you're pregnant or nursing. You can flip this in Settings any time."
            }
        }
    }
}
