import Foundation
import Network

@Observable
final class NetworkMonitor {
    @MainActor static let shared = NetworkMonitor()

    var isOnline: Bool = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.frisfit.network.monitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                if self.isOnline != online {
                    self.isOnline = online
                    NotificationCenter.default.post(
                        name: .networkReachabilityChanged,
                        object: nil,
                        userInfo: ["online": online]
                    )
                    if online {
                        OfflineQueue.shared.flush()
                    }
                }
            }
        }
        monitor.start(queue: queue)
    }
}

extension Notification.Name {
    static let networkReachabilityChanged = Notification.Name("com.frisfit.networkReachabilityChanged")
    static let offlineQueueChanged = Notification.Name("com.frisfit.offlineQueueChanged")
    static let waterIntakeChanged = Notification.Name("com.frisfit.waterIntakeChanged")
}
