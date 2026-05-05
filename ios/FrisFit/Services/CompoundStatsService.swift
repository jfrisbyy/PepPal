import Foundation
import Supabase

nonisolated struct CompoundUsageStat: Codable, Sendable, Hashable {
    let compound_name: String
    let active_users: Int
    let recent_users: Int
    let new_starts_7d: Int
    let trending_score: Int
}

nonisolated struct CompoundPublicUserRow: Codable, Sendable {
    let id: String
    let display_name: String?
    let username: String?
    let avatar_url: String?
    let avatar_color: String?
    let active_program: String?
    let total_fp: Int?
    let current_streak: Int?
    let dose_mcg: Double?
    let frequency: String?
    let started_at: String?
    let total_weeks: Int?
}

@MainActor
final class CompoundStatsService {
    static let shared = CompoundStatsService()

    private var supabase: SupabaseClient { SupabaseService.shared.client }

    // Cached aggregate stats keyed by lowercased compound name.
    private(set) var stats: [String: CompoundUsageStat] = [:]
    private var lastFetched: Date?
    private let cacheTTL: TimeInterval = 5 * 60 // 5 minutes
    private var inflightAggregate: Task<Void, Never>?

    private init() {}

    // MARK: - Aggregate stats

    func stat(for compoundName: String) -> CompoundUsageStat? {
        stats[compoundName.lowercased()]
    }

    /// Returns the live active+recent user count, or nil if we have no real data yet.
    func liveUserCount(for compoundName: String) -> Int? {
        guard let s = stat(for: compoundName) else { return nil }
        return max(s.recent_users, 0) > 0 ? s.recent_users : nil
    }

    func loadIfNeeded() async {
        if let last = lastFetched, Date().timeIntervalSince(last) < cacheTTL, !stats.isEmpty {
            return
        }
        await refresh()
    }

    func refresh() async {
        if let task = inflightAggregate {
            await task.value
            return
        }
        let task: Task<Void, Never> = Task { [weak self] in
            await self?.fetchAggregateStats()
        }
        inflightAggregate = task
        await task.value
        inflightAggregate = nil
    }

    private func fetchAggregateStats() async {
        do {
            let rows: [CompoundUsageStat] = try await supabase
                .rpc("compound_usage_stats")
                .execute()
                .value
            var map: [String: CompoundUsageStat] = [:]
            map.reserveCapacity(rows.count)
            for r in rows {
                map[r.compound_name.lowercased()] = r
            }
            stats = map
            lastFetched = Date()
        } catch {
            // keep prior cache on failure
        }
    }

    // MARK: - Public users for a compound

    nonisolated struct PublicProtocolUser: Identifiable, Sendable, Hashable {
        let id: UUID
        let displayName: String
        let username: String
        let avatarInitial: String
        let avatarColorHex: String?
        let avatarURL: String?
        let activeProgram: String?
        let streak: Int
        let totalFP: Int
        let doseMcg: Double?
        let frequency: String?
        let startedAt: Date?
        let totalWeeks: Int?
    }

    func fetchPublicUsers(for compoundName: String, limit: Int = 24) async -> [PublicProtocolUser] {
        do {
            let params = ["p_compound": compoundName]
            let rows: [CompoundPublicUserRow] = try await supabase
                .rpc("compound_public_users", params: params)
                .execute()
                .value
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let isoBasic = ISO8601DateFormatter()
            isoBasic.formatOptions = [.withInternetDateTime]
            return rows.prefix(limit).map { row in
                let name = row.display_name ?? row.username ?? "User"
                let initial = String(name.prefix(1)).uppercased()
                let started: Date? = row.started_at.flatMap { iso.date(from: $0) ?? isoBasic.date(from: $0) }
                return PublicProtocolUser(
                    id: UUID(uuidString: row.id) ?? UUID(),
                    displayName: name,
                    username: row.username ?? "user",
                    avatarInitial: initial,
                    avatarColorHex: row.avatar_color,
                    avatarURL: row.avatar_url,
                    activeProgram: row.active_program,
                    streak: row.current_streak ?? 0,
                    totalFP: row.total_fp ?? 0,
                    doseMcg: row.dose_mcg,
                    frequency: row.frequency,
                    startedAt: started,
                    totalWeeks: row.total_weeks
                )
            }
        } catch {
            return []
        }
    }
}
