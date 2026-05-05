import SwiftUI

nonisolated enum DeepLinkDestination: Equatable, Sendable {
    case conversation(String)
    case profile(String)
    case post(String)
    case circle(String)
    case notifications
    case home
}

extension Notification.Name {
    static let deepLinkDidChange = Notification.Name("deepLinkDidChange")
    static let switchToCommunityTab = Notification.Name("switchToCommunityTab")
    static let switchToDiscoverTab = Notification.Name("switchToDiscoverTab")
}

@Observable
final class DeepLinkRouter {
    static let shared = DeepLinkRouter()

    var pendingDestination: DeepLinkDestination?

    private init() {}

    func handle(userInfo: [AnyHashable: Any]) {
        if let convId = userInfo["conversation_id"] as? String {
            navigate(to: .conversation(convId))
        } else if let postId = userInfo["post_id"] as? String {
            navigate(to: .post(postId))
        } else if let profileId = userInfo["profile_id"] as? String {
            navigate(to: .profile(profileId))
        } else if let circleId = userInfo["circle_id"] as? String {
            navigate(to: .circle(circleId))
        } else if let type = userInfo["type"] as? String, type == "notifications" {
            navigate(to: .notifications)
        }
    }

    func handle(url: URL) {
        guard url.scheme == "peppal" else { return }
        let host = url.host ?? ""
        let path = url.pathComponents.filter { $0 != "/" }
        switch host {
        case "conversation":
            if let id = path.first { navigate(to: .conversation(id)) }
        case "post":
            if let id = path.first { navigate(to: .post(id)) }
        case "profile":
            if let id = path.first { navigate(to: .profile(id)) }
        case "circle":
            if let id = path.first { navigate(to: .circle(id)) }
        case "notifications":
            navigate(to: .notifications)
        default:
            break
        }
    }

    func navigate(to destination: DeepLinkDestination) {
        pendingDestination = destination
        NotificationCenter.default.post(name: .deepLinkDidChange, object: destination)
    }

    func consume() -> DeepLinkDestination? {
        let d = pendingDestination
        pendingDestination = nil
        return d
    }
}
