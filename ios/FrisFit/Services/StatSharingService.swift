import Foundation

@MainActor
final class StatSharingService {
    static let shared = StatSharingService()

    private let defaults = UserDefaults.standard

    private init() {}

    private func prefsKey(for userId: String) -> String {
        "statSharing.prefs.\(userId.lowercased())"
    }

    private func seenOnboardingKey(for userId: String) -> String {
        "statSharing.onboarded.\(userId.lowercased())"
    }

    func prefs(for userId: String) -> StatSharingPrefs {
        guard let data = defaults.data(forKey: prefsKey(for: userId)) else {
            return .default
        }
        return (try? JSONDecoder().decode(StatSharingPrefs.self, from: data)) ?? .default
    }

    func save(_ prefs: StatSharingPrefs, for userId: String) {
        if let data = try? JSONEncoder().encode(prefs) {
            defaults.set(data, forKey: prefsKey(for: userId))
        }
        // Mirror to backend (fire-and-forget). The backend detects off→on
        // transition and fans out a sharing_on activity event to followers.
        Task { await FriendsBackendService.shared.upsertSharingPrefs(prefs) }
    }

    func hasSeenOnboarding(for userId: String) -> Bool {
        defaults.bool(forKey: seenOnboardingKey(for: userId))
    }

    func markOnboardingSeen(for userId: String) {
        defaults.set(true, forKey: seenOnboardingKey(for: userId))
    }

    var currentUserPrefs: StatSharingPrefs {
        guard let id = try? AuthService.shared.currentUserId() else { return .default }
        return prefs(for: id)
    }
}
