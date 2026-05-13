import Foundation
import HealthKit

/// Central coordinator that scrubs every piece of locally-persisted state tied
/// to a specific user account. Called from `AuthService.signOut()` and from
/// the `.authUserChanged` listener whenever the signed-in user id actually
/// changes (account switch on the same device). Keeps account state strictly
/// per-user so a user can never see leftover data from someone else's session.
///
/// There are two categories of state we touch:
///
/// 1. **Globally-keyed UserDefaults** that aren't namespaced by user id but
///    contain user-private data (legacy keys, third-party caches, etc.). We
///    delete these outright on every user switch / sign-out.
/// 2. **User-namespaced UserDefaults** with the form `<base>.<userId>` (mirrors
///    `JourneyEventService.cacheKey(for:)`'s pattern). We delete only the
///    previous user's namespaced keys; the next user will lazily build their
///    own scoped cache from Supabase.
///
/// Per-user flag accessors (onboarding completion, medical disclaimer,
/// HealthKit enabled) live here so callers don't have to reimplement the
/// keying convention. All accessors fall back to the legacy global key when
/// no per-user value exists yet, then immediately migrate the value across
/// so the next read is purely user-scoped.
enum LocalStateResetCoordinator {

    // MARK: - Per-user key conventions

    /// Builds a `<base>.<uid>` key. When the userId is missing we fall back to
    /// a sentinel so signed-out reads don't accidentally collide with a real
    /// account's namespace.
    static func userScopedKey(_ base: String, userId: String?) -> String {
        guard let uid = userId, !uid.isEmpty else { return "\(base).__anon__" }
        return "\(base).\(uid)"
    }

    /// Convenience for callers that don't already have a userId.
    static func currentUserId() -> String? {
        try? AuthService.shared.currentUserId()
    }

    // MARK: - Onboarding completed flag

    private static let onboardingCompletedBase = "peppal.onboarding.completed.v1"

    static func onboardingCompletedKey(for userId: String?) -> String {
        userScopedKey(onboardingCompletedBase, userId: userId)
    }

    static func isOnboardingCompleted(forUserId userId: String?) -> Bool {
        guard let userId, !userId.isEmpty else { return false }
        let defaults = UserDefaults.standard
        let scopedKey = onboardingCompletedKey(for: userId)
        if defaults.object(forKey: scopedKey) != nil {
            return defaults.bool(forKey: scopedKey)
        }
        // Legacy migration: the first signed-in user on a device that was
        // running an older build still has the global flag. Adopt it once.
        if defaults.bool(forKey: onboardingCompletedBase) {
            defaults.set(true, forKey: scopedKey)
            defaults.removeObject(forKey: onboardingCompletedBase)
            return true
        }
        return false
    }

    static func setOnboardingCompleted(_ value: Bool, forUserId userId: String?) {
        guard let userId, !userId.isEmpty else { return }
        UserDefaults.standard.set(value, forKey: onboardingCompletedKey(for: userId))
    }

    static func resetOnboardingCompleted(forUserId userId: String?) {
        guard let userId, !userId.isEmpty else { return }
        UserDefaults.standard.removeObject(forKey: onboardingCompletedKey(for: userId))
    }

    // MARK: - Medical disclaimer flags

    private static let disclaimerAcceptedBase = "peppal.medicalDisclaimer.accepted.v1"
    private static let disclaimerDateBase = "peppal.medicalDisclaimer.acceptedDate.v1"
    private static let disclaimerVersionBase = "peppal.medicalDisclaimer.acceptedVersion.v1"

    static func disclaimerAcceptedKey(for userId: String?) -> String {
        userScopedKey(disclaimerAcceptedBase, userId: userId)
    }

    static func disclaimerDateKey(for userId: String?) -> String {
        userScopedKey(disclaimerDateBase, userId: userId)
    }

    static func disclaimerVersionKey(for userId: String?) -> String {
        userScopedKey(disclaimerVersionBase, userId: userId)
    }

    static func isDisclaimerAccepted(forUserId userId: String?) -> Bool {
        guard let userId, !userId.isEmpty else { return false }
        let defaults = UserDefaults.standard
        let scoped = disclaimerAcceptedKey(for: userId)
        if defaults.object(forKey: scoped) != nil {
            return defaults.bool(forKey: scoped)
        }
        // Legacy global key migration (one-time per user).
        if defaults.bool(forKey: disclaimerAcceptedBase) {
            defaults.set(true, forKey: scoped)
            if let d = defaults.object(forKey: disclaimerDateBase) as? Date {
                defaults.set(d, forKey: disclaimerDateKey(for: userId))
            }
            if let v = defaults.string(forKey: disclaimerVersionBase) {
                defaults.set(v, forKey: disclaimerVersionKey(for: userId))
            }
            defaults.removeObject(forKey: disclaimerAcceptedBase)
            defaults.removeObject(forKey: disclaimerDateBase)
            defaults.removeObject(forKey: disclaimerVersionBase)
            return true
        }
        return false
    }

    static func disclaimerAcceptedVersion(forUserId userId: String?) -> String? {
        guard let userId, !userId.isEmpty else { return nil }
        return UserDefaults.standard.string(forKey: disclaimerVersionKey(for: userId))
    }

    static func setDisclaimerAccepted(date: Date, version: String, forUserId userId: String?) {
        guard let userId, !userId.isEmpty else { return }
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: disclaimerAcceptedKey(for: userId))
        defaults.set(date, forKey: disclaimerDateKey(for: userId))
        defaults.set(version, forKey: disclaimerVersionKey(for: userId))
    }

    static func resetDisclaimer(forUserId userId: String?) {
        guard let userId, !userId.isEmpty else { return }
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: disclaimerAcceptedKey(for: userId))
        defaults.removeObject(forKey: disclaimerDateKey(for: userId))
        defaults.removeObject(forKey: disclaimerVersionKey(for: userId))
    }

    // MARK: - HealthKit enabled flag

    private static let healthkitEnabledBase = "healthkit_enabled"

    static func healthKitEnabledKey(for userId: String?) -> String {
        userScopedKey(healthkitEnabledBase, userId: userId)
    }

    static func isHealthKitEnabled(forUserId userId: String?) -> Bool {
        guard let userId, !userId.isEmpty else { return false }
        let defaults = UserDefaults.standard
        let scoped = healthKitEnabledKey(for: userId)
        if defaults.object(forKey: scoped) != nil {
            return defaults.bool(forKey: scoped)
        }
        if defaults.bool(forKey: healthkitEnabledBase) {
            defaults.set(true, forKey: scoped)
            defaults.removeObject(forKey: healthkitEnabledBase)
            return true
        }
        return false
    }

    static func setHealthKitEnabled(_ value: Bool, forUserId userId: String?) {
        guard let userId, !userId.isEmpty else { return }
        UserDefaults.standard.set(value, forKey: healthKitEnabledKey(for: userId))
    }

    // MARK: - Purge

    /// Globally-keyed UserDefaults that contain personal data and are NOT
    /// namespaced by user id. These are nuked on every user switch / sign-out
    /// so the next account starts from a clean slate.
    private static let globalKeysToWipe: [String] = [
        // Legacy non-namespaced flags (post-migration these may already be empty).
        "healthkit_enabled",
        "peppal.onboarding.completed.v1",
        "peppal.medicalDisclaimer.accepted.v1",
        "peppal.medicalDisclaimer.acceptedDate.v1",
        "peppal.medicalDisclaimer.acceptedVersion.v1",
        "medicalDisclaimerAccepted",

        // Onboarding draft + chapter checkpoint + success card staging.
        "peppal.onboarding.draft.v1",
        "peppal.onboarding.currentChapter.v1",
        "peppal.onboarding.journeyInterview.v1",
        "peppal.home.onboardingSuccessCard.pending.v1",
        "peppal.onboarding.successCard.facts.v1",
        "peppal.onboarding.successCard.hkDays.v1",
        "peppal.onboarding.successCard.pins.v1",
        "peppal.onboarding.successCard.protocol.v1",
        "peppal.onboarding.successCard.firstName.v1",

        // Compound surfaces / persona — gated by user identity.
        "peppal.compoundSurfaces.isPregnantOrNursing.v1",
        "peppal.compoundSurfaces.dateOfBirth.v1",
        "peppal.compoundSurfaces.biologicalSex.v1",
        "peppal.compoundSurfaces.personaTrack.v1",
        "peppal.compoundSurfaces.pregnancyAnsweredAt.v1",
        "peppal.compoundSurfaces.pregnancyRecheckSnoozedUntil.v1",

        // HealthKit cloud sync state.
        "health.cloud.lastSyncedAt",
        "health.cloud.didBackfill90",

        // Cached body / training prefs.
        "cachedWeightLbs",
        "programStartDayOffset",
        "step_goal",
        "logActivity.lastSport",
        "ai_memory_enabled",
        "adaptive_macros_enabled",
        "multiActiveProgramsEnabled",

        // TrainViewModel local caches.
        "trainVM.cacheUserId",

        // Personal stores keyed without userId.
        "peppal.injectionSitePreferences.v1",
        "peppal.unitSystem.v1",
        "peppal.vialInventory.v1",
        "peppal.vialScanHistory.v1",
        "peppal.biomarkers.v1",
        "peppal.journey.milestones.fired.v1",
        "peppal.healthkit.connect.prompted.v1",
        "peppal.healthkit.connect.denied.v1",
        "peppal.healthkit.connect.staged.v1",
    ]

    /// Prefixes of user-namespaced UserDefaults keys (`<prefix><userId>`). We
    /// scrub *every* matching key so caches for OTHER accounts on this device
    /// are also dropped — defense-in-depth against stale rows from a prior
    /// install or a bad account-switch.
    private static let userScopedPrefixes: [String] = [
        "peppal.journeyEvents.v1.",
        "peppal.storymode.cache.v1.",
        "peppal.onboarding.completed.v1.",
        "peppal.medicalDisclaimer.accepted.v1.",
        "peppal.medicalDisclaimer.acceptedDate.v1.",
        "peppal.medicalDisclaimer.acceptedVersion.v1.",
        "healthkit_enabled.",
        // Daily Brief caches — per-user scoped via `userScopedKey`. Wiping
        // on every account switch prevents the previous user's brief copy /
        // patterns memo from leaking onto the new account's home screen.
        "todaysPlanCache.",
        "todaysPlanHash.",
        "todaysPlanCacheTimestamp.",
        "todaysPlanPatternsMemo.",
        "todaysPlanPatternsMemoTimestamp.",
        "todaysPlanWindowsDone.",
        "todaysPlanMiddayDone.",
    ]

    /// Wipe every user-scoped piece of local state. Pass the previous user's
    /// id when known so we can also drop their `<prefix>.<uid>` namespaced
    /// caches. Safe to call when `previousUserId == nil` (e.g. cold sign-out).
    static func purgeUserScopedState(previousUserId: String?) {
        let defaults = UserDefaults.standard

        for key in globalKeysToWipe {
            defaults.removeObject(forKey: key)
        }

        // Drop the per-user disk folder owned by `PerUserDiskStore` (HealthKit
        // series, journey events, story narrations, food favorites). Bytes
        // there are larger than UserDefaults could handle and contain
        // user-private cached data, so they must be scrubbed on every switch.
        if let previousUserId, !previousUserId.isEmpty {
            PerUserDiskStore.purge(userId: previousUserId.lowercased())
        } else {
            // Cold sign-out without a known userId — wipe every user folder.
            PerUserDiskStore.purgeAll()
        }

        // Defense-in-depth: scrub every namespaced key that matches one of the
        // known per-user prefixes. This guarantees that a switch from user A
        // to user B drops A's pins / onboarding flag / HealthKit toggle even
        // if A's id wasn't passed in.
        let allKeys = defaults.dictionaryRepresentation().keys
        for key in allKeys {
            for prefix in userScopedPrefixes where key.hasPrefix(prefix) {
                defaults.removeObject(forKey: key)
                break
            }
        }

        // In-memory state held by long-lived singletons. Each one owns its
        // own reset entry point so we don't reach into private storage here.
        Task { @MainActor in
            HealthKitService.shared.handleSignOutOrUserSwitch()
            PeptideAccessManager.shared.handleSignOutOrUserSwitch()
            // Drop the previous user's in-memory Daily Brief so the new
            // account renders a loading state instead of stale copy.
            TodaysPlanViewModel.shared.handleSignOutOrUserSwitch()
        }
    }
}
