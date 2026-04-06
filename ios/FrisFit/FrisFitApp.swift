import SwiftUI

@main
struct FrisFitApp: App {
    @State private var appearanceManager = AppearanceManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(appearanceManager.colorScheme)
        }
    }
}
