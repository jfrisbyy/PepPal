import SwiftUI

@main
struct PepPalApp: App {
    @State private var appearanceManager = AppearanceManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(appearanceManager.colorScheme)
        }
    }
}
