import Foundation
import Supabase

nonisolated struct BasketballStatsJSON: Codable, Sendable {
    let points: Int
    let fieldGoalsMade: Int
    let fieldGoalsAttempted: Int
    let threePointersMade: Int
    let threePointersAttempted: Int
    let freeThrowsMade: Int
    let freeThrowsAttempted: Int
    let offensiveRebounds: Int
    let defensiveRebounds: Int
    let assists: Int
    let steals: Int
    let blocks: Int
    let turnovers: Int
    let minutesPlayed: Int
}

nonisolated struct ShotChartJSON: Codable, Sendable {
    let zone: String
    let made: Bool
}

nonisolated struct SupabaseBasketballGame: Codable, Sendable {
    let id: String?
    let user_id: String?
    let client_id: String
    let played_at: String
    let session_type: String
    let result: String?
    let team_score: Int?
    let opponent_score: Int?
    let duration_minutes: Int
    let confidence_rating: Int
    let performance_rating: Int
    let notes: String?
    let stats: BasketballStatsJSON
    let shot_chart: [ShotChartJSON]
}

nonisolated struct SupabaseBasketballGameInsert: Codable, Sendable {
    let user_id: String
    let client_id: String
    let played_at: String
    let session_type: String
    let result: String?
    let team_score: Int?
    let opponent_score: Int?
    let duration_minutes: Int
    let confidence_rating: Int
    let performance_rating: Int
    let notes: String?
    let stats: BasketballStatsJSON
    let shot_chart: [ShotChartJSON]
}

final class BasketballGameService {
    static let shared = BasketballGameService()
    private init() {}

    private var supabase: SupabaseClient { SupabaseService.shared.client }

    private let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private let isoBasic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private func parse(_ s: String) -> Date {
        iso.date(from: s) ?? isoBasic.date(from: s) ?? Date()
    }

    private func userId() async -> String? {
        guard let session = try? await supabase.auth.session else { return nil }
        return session.user.id.uuidString.lowercased()
    }

    private func toJSON(_ stats: BasketballGameStats) -> BasketballStatsJSON {
        BasketballStatsJSON(
            points: stats.points,
            fieldGoalsMade: stats.fieldGoalsMade,
            fieldGoalsAttempted: stats.fieldGoalsAttempted,
            threePointersMade: stats.threePointersMade,
            threePointersAttempted: stats.threePointersAttempted,
            freeThrowsMade: stats.freeThrowsMade,
            freeThrowsAttempted: stats.freeThrowsAttempted,
            offensiveRebounds: stats.offensiveRebounds,
            defensiveRebounds: stats.defensiveRebounds,
            assists: stats.assists,
            steals: stats.steals,
            blocks: stats.blocks,
            turnovers: stats.turnovers,
            minutesPlayed: stats.minutesPlayed
        )
    }

    private func fromJSON(_ json: BasketballStatsJSON) -> BasketballGameStats {
        var s = BasketballGameStats()
        s.points = json.points
        s.fieldGoalsMade = json.fieldGoalsMade
        s.fieldGoalsAttempted = json.fieldGoalsAttempted
        s.threePointersMade = json.threePointersMade
        s.threePointersAttempted = json.threePointersAttempted
        s.freeThrowsMade = json.freeThrowsMade
        s.freeThrowsAttempted = json.freeThrowsAttempted
        s.offensiveRebounds = json.offensiveRebounds
        s.defensiveRebounds = json.defensiveRebounds
        s.assists = json.assists
        s.steals = json.steals
        s.blocks = json.blocks
        s.turnovers = json.turnovers
        s.minutesPlayed = json.minutesPlayed
        return s
    }

    func fetchAll() async -> [BasketballGame] {
        guard let uid = await userId() else { return [] }
        do {
            let rows: [SupabaseBasketballGame] = try await supabase
                .from("basketball_games")
                .select()
                .eq("user_id", value: uid)
                .order("played_at", ascending: false)
                .execute()
                .value
            return rows.map { row in
                let chart = row.shot_chart.compactMap { item -> ShotChartEntry? in
                    guard let zone = ShotZone.allCases.first(where: { $0.rawValue == item.zone }) else { return nil }
                    return ShotChartEntry(zone: zone, made: item.made)
                }
                let sessionType = BasketballSessionType.allCases.first { $0.rawValue == row.session_type } ?? .pickupGame
                let result = row.result.flatMap { r in GameResult.allCases.first { $0.rawValue == r } }
                return BasketballGame(
                    date: parse(row.played_at),
                    sessionType: sessionType,
                    stats: fromJSON(row.stats),
                    result: result,
                    teamScore: row.team_score,
                    opponentScore: row.opponent_score,
                    durationMinutes: row.duration_minutes,
                    shotChart: chart,
                    confidenceRating: row.confidence_rating,
                    performanceRating: row.performance_rating,
                    notes: row.notes ?? ""
                )
            }
        } catch {
            print("[BasketballGameService] fetch error: \(error)")
            return []
        }
    }

    func insert(_ game: BasketballGame) async {
        guard let uid = await userId() else { return }
        let chart = game.shotChart.map { ShotChartJSON(zone: $0.zone.rawValue, made: $0.made) }
        let payload = SupabaseBasketballGameInsert(
            user_id: uid,
            client_id: game.id.uuidString.lowercased(),
            played_at: iso.string(from: game.date),
            session_type: game.sessionType.rawValue,
            result: game.result?.rawValue,
            team_score: game.teamScore,
            opponent_score: game.opponentScore,
            duration_minutes: game.durationMinutes,
            confidence_rating: game.confidenceRating,
            performance_rating: game.performanceRating,
            notes: game.notes.isEmpty ? nil : game.notes,
            stats: toJSON(game.stats),
            shot_chart: chart
        )
        do {
            try await supabase
                .from("basketball_games")
                .upsert(payload, onConflict: "user_id,client_id")
                .execute()
        } catch {
            print("[BasketballGameService] insert error: \(error)")
        }
    }

    func delete(clientId: UUID) async {
        guard let uid = await userId() else { return }
        do {
            try await supabase
                .from("basketball_games")
                .delete()
                .eq("user_id", value: uid)
                .eq("client_id", value: clientId.uuidString.lowercased())
                .execute()
        } catch {
            print("[BasketballGameService] delete error: \(error)")
        }
    }
}
