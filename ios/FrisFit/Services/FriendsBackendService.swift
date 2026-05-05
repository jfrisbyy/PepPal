import Foundation
import Supabase

// MARK: - Wire types

nonisolated struct FriendsFeedResponse: Codable, Sendable {
    let ok: Bool?
    let friends: [FriendsFeedFriend]?
    let events: [FriendsFeedEvent]?
    let myRecap: FriendsFeedEvent?
}

nonisolated struct FriendsFeedFriend: Codable, Sendable {
    let profile: SupabasePostAuthor
    let prefs: FriendsFeedPrefs?
    let snapshot: FriendsFeedSnapshot?
}

nonisolated struct FriendsFeedPrefs: Codable, Sendable {
    let audience: String?
    let categories: [String]?
}

nonisolated struct FriendsFeedSnapshot: Codable, Sendable {
    let user_id: String?
    let week_start: String?
    let weekly_workouts: Int?
    let weekly_volume_kg: Int?
    let weekly_steps: Int?
    let weekly_calories: Int?
    let weekly_water_ml: Int?
    let streak: Int?
    let latest_pr: String?
    let active_program: String?
    let active_protocol: String?
}

nonisolated struct FriendsFeedEvent: Codable, Sendable, Identifiable {
    let id: String
    let user_id: String
    let type: String
    let title: String
    let subtitle: String?
    let created_at: String?
    let data: AnyCodable?
}

nonisolated struct EmptyFriendsResponse: Codable, Sendable {
    let ok: Bool?
    let error: String?
}

// MARK: - Service

@MainActor
final class FriendsBackendService {
    static let shared = FriendsBackendService()
    private init() {}

    private var supabase: SupabaseClient { SupabaseService.shared.client }

    // MARK: Feed

    func fetchFeed() async throws -> FriendsFeedResponse {
        let body: [String: AnyJSON] = ["action": .string("friendsFeed")]
        let res: FriendsFeedResponse = try await supabase.functions
            .invoke("super-action", options: FunctionInvokeOptions(body: body))
        return res
    }

    // MARK: Sharing prefs

    func upsertSharingPrefs(_ prefs: StatSharingPrefs) async {
        let payload: [String: AnyJSON] = [
            "action": .string("upsertSharingPrefs"),
            "payload": .object([
                "is_enabled": .bool(prefs.isEnabled),
                "audience": .string(prefs.audience.rawValue),
                "categories": .array(prefs.categories.map { .string($0.rawValue) })
            ])
        ]
        do {
            let _: EmptyFriendsResponse = try await supabase.functions
                .invoke("super-action", options: FunctionInvokeOptions(body: payload))
        } catch {
            print("FriendsBackend: upsertSharingPrefs failed: \(error)")
        }
    }

    // MARK: Weekly snapshot

    func upsertWeeklySnapshot(
        weekStart: String? = nil,
        workouts: Int,
        volumeKg: Int,
        steps: Int,
        calories: Int,
        waterMl: Int,
        streak: Int,
        latestPR: String?,
        activeProgram: String?,
        activeProtocol: String?
    ) async {
        var payload: [String: AnyJSON] = [
            "weekly_workouts": .integer(workouts),
            "weekly_volume_kg": .integer(volumeKg),
            "weekly_steps": .integer(steps),
            "weekly_calories": .integer(calories),
            "weekly_water_ml": .integer(waterMl),
            "streak": .integer(streak)
        ]
        if let weekStart { payload["week_start"] = .string(weekStart) }
        if let latestPR { payload["latest_pr"] = .string(latestPR) }
        if let activeProgram { payload["active_program"] = .string(activeProgram) }
        if let activeProtocol { payload["active_protocol"] = .string(activeProtocol) }

        let body: [String: AnyJSON] = [
            "action": .string("upsertWeeklySnapshot"),
            "payload": .object(payload)
        ]
        do {
            let _: EmptyFriendsResponse = try await supabase.functions
                .invoke("super-action", options: FunctionInvokeOptions(body: body))
        } catch {
            print("FriendsBackend: upsertWeeklySnapshot failed: \(error)")
        }
    }

    // MARK: Activity events

    func recordActivityEvent(
        type: String,
        title: String,
        subtitle: String?,
        data: [String: String] = [:],
        fanout: Bool = true
    ) async {
        var payloadObj: [String: AnyJSON] = [
            "type": .string(type),
            "title": .string(title),
            "fanout": .bool(fanout),
            "data": .object(data.mapValues { .string($0) })
        ]
        if let subtitle { payloadObj["subtitle"] = .string(subtitle) }

        let body: [String: AnyJSON] = [
            "action": .string("recordActivityEvent"),
            "payload": .object(payloadObj)
        ]
        do {
            let _: EmptyFriendsResponse = try await supabase.functions
                .invoke("super-action", options: FunctionInvokeOptions(body: body))
        } catch {
            print("FriendsBackend: recordActivityEvent failed: \(error)")
        }
    }

    // MARK: Nudge

    func sendNudge(receiverId: String, kind: NudgeKind) async throws {
        let body: [String: AnyJSON] = [
            "action": .string("sendNudge"),
            "payload": .object([
                "receiver_id": .string(receiverId),
                "kind": .string(kind.rawValue),
                "title": .string(kind.title),
                "body": .string(kind.body)
            ])
        ]
        let _: EmptyFriendsResponse = try await supabase.functions
            .invoke("super-action", options: FunctionInvokeOptions(body: body))
    }

    // MARK: Reaction

    func sendReaction(receiverId: String, target: String, emoji: StatReactionEmoji) async {
        let body: [String: AnyJSON] = [
            "action": .string("sendReaction"),
            "payload": .object([
                "receiver_id": .string(receiverId),
                "target": .string(target),
                "emoji": .string(emoji.rawValue)
            ])
        ]
        do {
            let _: EmptyFriendsResponse = try await supabase.functions
                .invoke("super-action", options: FunctionInvokeOptions(body: body))
        } catch {
            print("FriendsBackend: sendReaction failed: \(error)")
        }
    }

    // MARK: Weekly recap

    func generateMyRecap() async {
        let body: [String: AnyJSON] = ["action": .string("weeklyRecap")]
        do {
            let _: EmptyFriendsResponse = try await supabase.functions
                .invoke("super-action", options: FunctionInvokeOptions(body: body))
        } catch {
            print("FriendsBackend: weeklyRecap failed: \(error)")
        }
    }

    // MARK: Buddy invite (uses notifications table directly via messaging service)

    func sendBuddyInvite(receiverId: String, sport: String, message: String?) async {
        // Send a notification + activity event for the buddy invite.
        await recordActivityEvent(
            type: "buddy_invite",
            title: "Buddy workout invite",
            subtitle: message ?? "Wants to train together — \(sport)",
            data: ["sport": sport, "to": receiverId],
            fanout: false
        )
        let body: [String: AnyJSON] = [
            "action": .string("sendPush"),
            "payload": .object([
                "user_ids": .array([.string(receiverId)]),
                "title": .string("Buddy workout invite"),
                "body": .string(message ?? "Wants to train together — \(sport)"),
                "data": .object(["type": .string("buddy_invite"), "sport": .string(sport)])
            ])
        ]
        do {
            let _: EmptyFriendsResponse = try await supabase.functions
                .invoke("super-action", options: FunctionInvokeOptions(body: body))
        } catch {
            print("FriendsBackend: buddy push failed: \(error)")
        }
    }
}
