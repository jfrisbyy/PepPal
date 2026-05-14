import SwiftUI

/// Global toggle that hides floating chrome (top action pill, bottom tab bar,
/// the green FAB) so the Home screen can be captured cleanly for marketing
/// screenshots. The scrollable content stays untouched.
@MainActor
@Observable
final class ScreenshotMode {
    static let shared = ScreenshotMode()

    private let storageKey = "screenshotMode.hideChrome"

    var hideChrome: Bool {
        didSet {
            UserDefaults.standard.set(hideChrome, forKey: storageKey)
        }
    }

    private init() {
        self.hideChrome = UserDefaults.standard.bool(forKey: "screenshotMode.hideChrome")
    }
}

/// Nonisolated probe so views deep in the tree (and `nonisolated` callers)
/// can read the flag without hopping to the main actor.
nonisolated enum ScreenshotModeProbe {
    private static let storageKey = "screenshotMode.hideChrome"
    static var hideChrome: Bool { UserDefaults.standard.bool(forKey: storageKey) }
}
