import Foundation
import UIKit
import UserNotifications
import Supabase

nonisolated struct DeviceTokenPayload: Codable, Sendable {
    let user_id: String
    let token: String
    let platform: String
    let updated_at: String
}

@Observable
final class PushNotificationService {
    static let shared = PushNotificationService()

    var currentToken: String?

    private var supabase: SupabaseClient { SupabaseService.shared.client }

    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private init() {}

    func registerIfAuthorized() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            Task { @MainActor in
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func requestAndRegister() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
            return granted
        } catch {
            return false
        }
    }

    func handleRegistered(token: String) {
        currentToken = token
        Task {
            await upload(token: token)
        }
    }

    private func upload(token: String) async {
        guard let userId = try? AuthService.shared.currentUserId() else { return }
        let payload = DeviceTokenPayload(
            user_id: userId,
            token: token,
            platform: "ios",
            updated_at: iso8601.string(from: Date())
        )
        do {
            try await supabase
                .from("device_tokens")
                .upsert(payload, onConflict: "token")
                .execute()
        } catch {
            print("PUSH: Failed to upload device token: \(error)")
        }
    }

    func unregister() async {
        guard let token = currentToken else { return }
        do {
            try await supabase
                .from("device_tokens")
                .delete()
                .eq("token", value: token)
                .execute()
        } catch {
            print("PUSH: Failed to remove device token: \(error)")
        }
        currentToken = nil
    }
}
