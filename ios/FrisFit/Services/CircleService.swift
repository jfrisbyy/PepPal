import Foundation
import Supabase
import SwiftUI

nonisolated struct SupabaseCircle: Codable, Sendable {
    let id: String?
    let owner_id: String
    let name: String
    let description: String?
    let is_private: Bool?
    let goals: [String]?
    let accent_color: String?
    let invite_code: String?
    let created_at: String?
}

nonisolated struct SupabaseCircleMember: Codable, Sendable {
    let id: String?
    let circle_id: String
    let user_id: String
    let role: String?
    let joined_at: String?
}

nonisolated struct SupabaseCircleMemberWithProfile: Codable, Sendable {
    let id: String?
    let circle_id: String
    let user_id: String
    let role: String?
    let joined_at: String?
    let profiles: SupabasePostAuthor?
}

nonisolated struct CreateCirclePayload: Codable, Sendable {
    let owner_id: String
    let name: String
    let description: String?
    let is_private: Bool
    let goals: [String]?
    let accent_color: String?
    let invite_code: String
}

nonisolated struct CreateCircleMemberPayload: Codable, Sendable {
    let circle_id: String
    let user_id: String
    let role: String
}

final class CircleService {
    static let shared = CircleService()

    private var supabase: SupabaseClient {
        SupabaseService.shared.client
    }

    private init() {}

    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    func fetchMyCircles(userId: String) async throws -> [SupabaseCircle] {
        let memberships: [SupabaseCircleMember] = try await supabase
            .from("circle_members")
            .select("id, circle_id, user_id, role, joined_at")
            .eq("user_id", value: userId)
            .limit(500)
            .execute()
            .value

        guard !memberships.isEmpty else { return [] }
        let circleIds = memberships.map { $0.circle_id }

        let circles: [SupabaseCircle] = try await supabase
            .from("circles")
            .select()
            .in("id", values: circleIds)
            .order("created_at", ascending: false)
            .limit(500)
            .execute()
            .value
        return circles
    }

    func fetchPublicCircles(userId: String) async throws -> [SupabaseCircle] {
        let myCircles = try await fetchMyCircles(userId: userId)
        let myIds = Set(myCircles.map { $0.id ?? "" })

        let circles: [SupabaseCircle] = try await supabase
            .from("circles")
            .select()
            .eq("is_private", value: false)
            .order("created_at", ascending: false)
            .limit(50)
            .execute()
            .value
        return circles.filter { !myIds.contains($0.id ?? "") }
    }

    func fetchMembers(circleId: String, limit: Int = 200) async throws -> [SupabaseCircleMemberWithProfile] {
        // Membership listing goes through the SECURITY DEFINER RPC
        // `list_circle_members` so the caller can see other members of
        // private circles they belong to without the table policy needing
        // to query itself (which would recurse). The RPC returns plain
        // circle_members rows; we hydrate the profile column with a
        // follow-up `in()` query.
        struct RPCArgs: Encodable { let p_circle_id: String }
        let baseRows: [SupabaseCircleMember] = (try? await supabase
            .rpc("list_circle_members", params: RPCArgs(p_circle_id: circleId))
            .execute()
            .value) ?? []

        if baseRows.isEmpty {
            // Either the caller isn't a member / circle isn't public,
            // or the RPC isn't available yet — fall back to the direct
            // table read which under the new policy still surfaces the
            // caller's own row + any rows in public circles.
            let fallback: [SupabaseCircleMemberWithProfile] = (try? await supabase
                .from("circle_members")
                .select("*, profiles!circle_members_user_id_fkey(id, display_name, username, avatar_url, avatar_color, active_program, total_fp, current_streak)")
                .eq("circle_id", value: circleId)
                .limit(limit)
                .execute()
                .value) ?? []
            return fallback
        }

        let userIds = Array(Set(baseRows.map { $0.user_id })).prefix(limit)
        let profiles: [SupabasePostAuthor] = (try? await supabase
            .from("profiles")
            .select("id, display_name, username, avatar_url, avatar_color, active_program, total_fp, current_streak")
            .in("id", values: Array(userIds))
            .execute()
            .value) ?? []
        let profileById: [String: SupabasePostAuthor] = Dictionary(
            uniqueKeysWithValues: profiles.map { ($0.id, $0) }
        )

        return Array(baseRows.prefix(limit)).map { row in
            SupabaseCircleMemberWithProfile(
                id: row.id,
                circle_id: row.circle_id,
                user_id: row.user_id,
                role: row.role,
                joined_at: row.joined_at,
                profiles: profileById[row.user_id]
            )
        }
    }

    func createCircle(userId: String, name: String, description: String, isPrivate: Bool, accentColor: String?) async throws -> SupabaseCircle {
        let inviteCode = String(UUID().uuidString.prefix(8)).uppercased()
        let payload = CreateCirclePayload(
            owner_id: userId,
            name: name,
            description: description.isEmpty ? nil : description,
            is_private: isPrivate,
            goals: nil,
            accent_color: accentColor,
            invite_code: inviteCode
        )

        let created: SupabaseCircle = try await supabase
            .from("circles")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        guard let circleId = created.id else { return created }

        let memberPayload = CreateCircleMemberPayload(
            circle_id: circleId,
            user_id: userId,
            role: "owner"
        )
        try await supabase
            .from("circle_members")
            .insert(memberPayload)
            .execute()

        return created
    }

    func joinCircle(circleId: String, userId: String) async throws {
        let payload = CreateCircleMemberPayload(
            circle_id: circleId,
            user_id: userId,
            role: "member"
        )
        try await supabase
            .from("circle_members")
            .insert(payload)
            .execute()
    }

    func leaveCircle(circleId: String, userId: String) async throws {
        try await supabase
            .from("circle_members")
            .delete()
            .eq("circle_id", value: circleId)
            .eq("user_id", value: userId)
            .execute()
    }

    func deleteCircle(circleId: String) async throws {
        try await supabase
            .from("circle_members")
            .delete()
            .eq("circle_id", value: circleId)
            .execute()

        try await supabase
            .from("circles")
            .delete()
            .eq("id", value: circleId)
            .execute()
    }

    func searchCircles(query: String, userId: String, limit: Int = 20) async throws -> [FitCircle] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        let escaped = q.replacingOccurrences(of: ",", with: "")
        let circles: [SupabaseCircle] = try await supabase
            .from("circles")
            .select()
            .or("name.ilike.%\(escaped)%,description.ilike.%\(escaped)%")
            .limit(limit * 2)
            .execute()
            .value

        let myMemberships: [SupabaseCircleMember] = (try? await supabase
            .from("circle_members")
            .select("id, circle_id, user_id, role, joined_at")
            .eq("user_id", value: userId)
            .execute()
            .value) ?? []
        let myCircleIds = Set(myMemberships.map { $0.circle_id })

        let visible = circles.filter { circle in
            guard let cid = circle.id else { return false }
            return !(circle.is_private ?? false) || myCircleIds.contains(cid)
        }.prefix(limit)

        var results: [FitCircle] = []
        for c in visible {
            guard let cid = c.id else { continue }
            let members = (try? await fetchMembers(circleId: cid)) ?? []
            results.append(toFitCircle(c, members: members))
        }
        return results
    }

    func joinByInviteCode(code: String, userId: String) async throws -> SupabaseCircle? {
        let circles: [SupabaseCircle] = try await supabase
            .from("circles")
            .select()
            .eq("invite_code", value: code.uppercased())
            .limit(1)
            .execute()
            .value

        guard let circle = circles.first, let circleId = circle.id else { return nil }
        try await joinCircle(circleId: circleId, userId: userId)
        return circle
    }

    func toFitCircle(_ circle: SupabaseCircle, members: [SupabaseCircleMemberWithProfile]) -> FitCircle {
        let circleMembers = members.map { m -> CircleMember in
            let user = SocialService.shared.socialUserFromAuthor(m.profiles)
            let role = CircleRole(rawValue: (m.role ?? "member").capitalized) ?? .member
            let joinedAt: Date
            if let dateStr = m.joined_at {
                joinedAt = iso8601.date(from: dateStr) ?? Date()
            } else {
                joinedAt = Date()
            }
            return CircleMember(
                id: UUID(uuidString: m.id ?? "") ?? UUID(),
                user: user,
                role: role,
                joinedAt: joinedAt,
                totalPoints: 0,
                weeklyPoints: 0,
                goalStreak: user.streak,
                longestStreak: user.streak
            )
        }

        let accentColor = parseColor(circle.accent_color)
        let createdAt: Date
        if let dateStr = circle.created_at {
            createdAt = iso8601.date(from: dateStr) ?? Date()
        } else {
            createdAt = Date()
        }

        return FitCircle(
            id: UUID(uuidString: circle.id ?? "") ?? UUID(),
            name: circle.name,
            description: circle.description ?? "",
            ownerId: UUID(uuidString: circle.owner_id) ?? UUID(),
            isPrivate: circle.is_private ?? false,
            dailyPointGoal: nil,
            weeklyPointGoal: nil,
            totalCirclePoints: circleMembers.reduce(0) { $0 + $1.totalPoints },
            inviteCode: circle.invite_code ?? "",
            createdAt: createdAt,
            members: circleMembers,
            accentColor: accentColor
        )
    }

    private func parseColor(_ hex: String?) -> Color {
        guard let hex, !hex.isEmpty else { return Color(red: 0.0, green: 0.7, blue: 1.0) }
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6, let num = UInt64(cleaned, radix: 16) else {
            return Color(red: 0.0, green: 0.7, blue: 1.0)
        }
        return Color(
            red: Double((num >> 16) & 0xFF) / 255.0,
            green: Double((num >> 8) & 0xFF) / 255.0,
            blue: Double(num & 0xFF) / 255.0
        )
    }
}
