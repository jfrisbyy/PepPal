import Foundation

@Observable
final class CompoundTrackingManager {
    static let shared = CompoundTrackingManager()

    private(set) var trackedCompoundNames: Set<String> = []

    private let defaultsKey = "tracked_compound_names"
    private let defaults = UserDefaults.standard

    private init() {
        let saved = defaults.stringArray(forKey: defaultsKey) ?? []
        self.trackedCompoundNames = Set(saved)
    }

    func isTracking(_ compoundName: String) -> Bool {
        trackedCompoundNames.contains(compoundName)
    }

    func toggleTracking(_ compoundName: String) {
        if trackedCompoundNames.contains(compoundName) {
            trackedCompoundNames.remove(compoundName)
        } else {
            trackedCompoundNames.insert(compoundName)
        }
        persist()
    }

    func trackingCount(for compoundName: String) -> Int {
        isTracking(compoundName) ? 1 : 0
    }

    private func persist() {
        defaults.set(Array(trackedCompoundNames), forKey: defaultsKey)
    }
}
