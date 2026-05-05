import Foundation
import Supabase
import Realtime

@MainActor
final class RealtimeFeedService {
    static let shared = RealtimeFeedService()
    private init() {}

    private var channel: RealtimeChannelV2?
    private var insertSub: RealtimeSubscription?
    private var updateSub: RealtimeSubscription?
    private var deleteSub: RealtimeSubscription?

    typealias InsertHandler = (SupabaseFeedPost) -> Void
    typealias UpdateHandler = (SupabaseFeedPost) -> Void
    typealias DeleteHandler = (String) -> Void

    private var onInsert: InsertHandler?
    private var onUpdate: UpdateHandler?
    private var onDelete: DeleteHandler?

    func subscribe(
        onInsert: @escaping InsertHandler,
        onUpdate: @escaping UpdateHandler,
        onDelete: @escaping DeleteHandler
    ) async {
        await unsubscribe()
        self.onInsert = onInsert
        self.onUpdate = onUpdate
        self.onDelete = onDelete

        let supabase = SupabaseService.shared.client
        let ch = supabase.realtimeV2.channel("feed-posts-global")

        insertSub = ch.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "feed_posts"
        ) { [weak self] change in
            guard let self else { return }
            if let decoded = try? change.decodeRecord(as: SupabaseFeedPost.self, decoder: JSONDecoder()) {
                Task { @MainActor in self.onInsert?(decoded) }
            }
        }

        updateSub = ch.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "feed_posts"
        ) { [weak self] change in
            guard let self else { return }
            if let decoded = try? change.decodeRecord(as: SupabaseFeedPost.self, decoder: JSONDecoder()) {
                Task { @MainActor in self.onUpdate?(decoded) }
            }
        }

        deleteSub = ch.onPostgresChange(
            DeleteAction.self,
            schema: "public",
            table: "feed_posts"
        ) { [weak self] change in
            guard let self else { return }
            if let idValue = change.oldRecord["id"],
               case let .string(idStr) = idValue {
                Task { @MainActor in self.onDelete?(idStr) }
            }
        }

        await ch.subscribe()
        self.channel = ch
    }

    func unsubscribe() async {
        insertSub = nil
        updateSub = nil
        deleteSub = nil
        if let ch = channel {
            await ch.unsubscribe()
        }
        channel = nil
        onInsert = nil
        onUpdate = nil
        onDelete = nil
    }
}
