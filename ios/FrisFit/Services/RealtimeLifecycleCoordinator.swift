import Foundation
import SwiftUI
import UIKit

/// Centralised lifecycle for every Supabase Realtime subscription the app holds.
///
/// Why this exists:
/// Supabase Realtime caps simultaneous connections per project. If we leave a
/// channel open for every backgrounded device we run into the cap quickly at
/// scale. This coordinator tears every channel down when the app enters
/// background and rehydrates the subscriptions the foreground UI cared about
/// when it returns to active.
///
/// The contract:
/// - Subscribe through ``RealtimeLifecycleCoordinator/shared``, not directly
///   on the underlying services. Each subscription registers a `Hydrator`
///   block that the coordinator replays on foreground.
/// - Channels are scoped per-user. ``unsubscribeAll()`` is safe to call from
///   ``LocalStateResetCoordinator`` on sign-out/account switch.
@MainActor
final class RealtimeLifecycleCoordinator {
    static let shared = RealtimeLifecycleCoordinator()
    private init() {
        installLifecycleObservers()
    }

    typealias Hydrator = @MainActor () async -> Void

    private struct Registration {
        let key: String
        let hydrate: Hydrator
        let teardown: Hydrator
    }

    private var registrations: [String: Registration] = [:]
    private var isForeground: Bool = true

    /// Register a subscription. The coordinator immediately runs `hydrate`
    /// (foreground) or schedules it to run when the app next becomes active.
    /// `teardown` is called on background and on `unsubscribeAll`.
    func register(
        key: String,
        hydrate: @escaping Hydrator,
        teardown: @escaping Hydrator
    ) async {
        registrations[key] = Registration(key: key, hydrate: hydrate, teardown: teardown)
        if isForeground {
            await hydrate()
        }
    }

    func unregister(key: String) async {
        guard let reg = registrations.removeValue(forKey: key) else { return }
        await reg.teardown()
    }

    /// Tear every channel down — used on sign-out / account switch so we never
    /// keep a previous user's subscriptions open under the new user.
    func unsubscribeAll() async {
        let regs = registrations.values
        registrations.removeAll()
        for reg in regs {
            await reg.teardown()
        }
    }

    // MARK: - Lifecycle

    private func installLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                await RealtimeLifecycleCoordinator.shared.handleBackground()
            }
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                await RealtimeLifecycleCoordinator.shared.handleForeground()
            }
        }
    }

    private func handleBackground() async {
        isForeground = false
        for reg in registrations.values {
            await reg.teardown()
        }
    }

    private func handleForeground() async {
        isForeground = true
        for reg in registrations.values {
            await reg.hydrate()
        }
    }
}
