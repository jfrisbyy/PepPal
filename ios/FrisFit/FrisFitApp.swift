import SwiftUI

@main
struct EPTIApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appearanceManager = AppearanceManager.shared

    init() {
        print("APP_INIT: EPTIApp init starting")
        print("APP_INIT: Supabase URL configured: \(!Config.EXPO_PUBLIC_SUPABASE_URL.isEmpty)")
        print("APP_INIT: Supabase Key configured: \(!Config.EXPO_PUBLIC_SUPABASE_ANON_KEY.isEmpty)")
        print("APP_INIT: AI calls route through ai-proxy edge function")
        CrashReportingService.start()
        print("APP_INIT: CrashReportingService started (Sentry DSN configured: \(!Config.EXPO_PUBLIC_SENTRY_DSN.isEmpty))")
        print("APP_INIT: Triggering SupabaseService.shared init")
        _ = SupabaseService.shared
        print("APP_INIT: SupabaseService.shared initialized successfully")
        print("APP_INIT: Triggering AuthService.shared init")
        _ = AuthService.shared
        print("APP_INIT: AuthService.shared initialized successfully")
        PreferencesSyncService.shared.start()
        print("APP_INIT: PreferencesSyncService started")
        Task { @MainActor in
            _ = await CorrelationEngine.shared.run()
        }
        print("APP_INIT: EPTIApp init complete")
    }

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(appearanceManager.colorScheme)
                .onOpenURL { url in
                    DeepLinkRouter.shared.handle(url: url)
                }
                .onAppear {
                    print("APP_INIT: ContentView appeared")
                    Task { await SmartNotificationEngine.shared.replanAll() }
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await SmartNotificationEngine.shared.replanAll() }
            }
        }
    }
}
