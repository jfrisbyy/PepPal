import Foundation
import Supabase
import Realtime

@MainActor
final class NotificationsRealtimeService {
    static let shared = NotificationsRealtimeService()
    private init() {}

    private var channel: RealtimeChannelV2?
    private var token: RealtimeSubscription?
    private var subscribedUserId: String?

    typealias Handler = (SupabaseNotification) -> Void
    private var handler: Handler?

    func subscribe(userId: String, onInsert: @escaping Handler) async {
        if subscribedUserId == userId, channel != nil { handler = onInsert; return }
        await unsubscribe()

        subscribedUserId = userId
        handler = onInsert

        let supabase = SupabaseService.shared.client
        let ch = supabase.realtimeV2.channel("notifications-\(userId)")
        let t = ch.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "notifications",
            filter: "user_id=eq.\(userId)"
        ) { [weak self] change in
            guard let self else { return }
            if let decoded = try? change.decodeRecord(as: SupabaseNotification.self, decoder: JSONDecoder()) {
                Task { @MainActor in
                    self.handler?(decoded)
                }
            }
        }
        token = t
        await ch.subscribe()
        channel = ch
    }

    func unsubscribe() async {
        token = nil
        if let ch = channel { await ch.unsubscribe() }
        channel = nil
        subscribedUserId = nil
        handler = nil
    }
}
