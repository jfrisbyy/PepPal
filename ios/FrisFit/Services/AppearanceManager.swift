import SwiftUI

nonisolated enum AppearanceMode: Int, CaseIterable, Sendable {
    case system = 0
    case light = 1
    case dark = 2

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

@Observable
final class AppearanceManager {
    static let shared = AppearanceManager()

    var mode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "appearance_mode")
        }
    }

    var colorScheme: ColorScheme? {
        mode.colorScheme
    }

    private init() {
        let saved = UserDefaults.standard.integer(forKey: "appearance_mode")
        self.mode = AppearanceMode(rawValue: saved) ?? .dark
    }
}
