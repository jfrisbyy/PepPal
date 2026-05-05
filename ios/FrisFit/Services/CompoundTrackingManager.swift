import Foundation

@Observable
@MainActor
final class CompoundTrackingManager {
    static let shared = CompoundTrackingManager()

    private(set) var trackedCompoundNames: Set<String> = []

    private let defaultsKey = "tracked_compound_names"
    private let defaults = UserDefaults.standard

    private init() {
        let saved = defaults.stringArray(forKey: defaultsKey) ?? []
        self.trackedCompoundNames = Set(saved)
        Task { await self.hydrateFromSupabase() }
    }

    func isTracking(_ compoundName: String) -> Bool {
        trackedCompoundNames.contains(compoundName)
    }

    func toggleTracking(_ compoundName: String) {
        let nowTracking: Bool
        if trackedCompoundNames.contains(compoundName) {
            trackedCompoundNames.remove(compoundName)
            nowTracking = false
        } else {
            trackedCompoundNames.insert(compoundName)
            nowTracking = true
        }
        persist()
        Task.detached {
            await PersistenceSyncService.shared.setTrackedCompound(compoundName, tracked: nowTracking)
        }
    }

    func trackingCount(for compoundName: String) -> Int {
        isTracking(compoundName) ? 1 : 0
    }

    private func persist() {
        defaults.set(Array(trackedCompoundNames), forKey: defaultsKey)
    }

    func hydrateFromSupabase() async {
        let remote = Set(await PersistenceSyncService.shared.fetchTrackedCompounds())
        if remote.isEmpty && !trackedCompoundNames.isEmpty {
            // First sync from local-only state: push existing names up
            for name in trackedCompoundNames {
                await PersistenceSyncService.shared.setTrackedCompound(name, tracked: true)
            }
        } else {
            // Union: never lose an optimistic local toggle that hasn't synced yet.
            trackedCompoundNames = remote.union(trackedCompoundNames)
            persist()
        }
    }
}
