import Foundation
import Supabase

nonisolated struct CardioRoutePointJSON: Codable, Sendable {
    let lat: Double
    let lon: Double
    let ele: Double
    let ts: Double
    let speed: Double
}

nonisolated struct CardioSplitJSON: Codable, Sendable {
    let number: Int
    let distance: Double
    let duration: Double
    let pace: Double
    let elevationChange: Double
    let avgHeartRate: Int
}

nonisolated struct CardioSessionInsert: Codable, Sendable {
    let user_id: String
    let sport: String
    let started_at: String
    let ended_at: String
    let distance_m: Double
    let duration_s: Double
    let elevation_gain_m: Double
    let avg_pace: Double
    let avg_speed_mps: Double
    let calories: Int
    let avg_heart_rate: Int
    let max_heart_rate: Int
    let route_points: [CardioRoutePointJSON]
    let splits: [CardioSplitJSON]
    let is_indoor: Bool
}

final class CardioSessionService {
    static let shared = CardioSessionService()

    private var supabase: SupabaseClient { SupabaseService.shared.client }
    private let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private init() {}

    func saveRun(_ run: CompletedRun) async {
        guard let userId = AuthService.shared.session?.user.id.uuidString else { return }
        let start = run.date.addingTimeInterval(-run.durationSeconds)
        let routeJSON: [CardioRoutePointJSON] = run.routeCoordinates.map {
            CardioRoutePointJSON(lat: $0.latitude, lon: $0.longitude, ele: $0.elevation, ts: $0.timestamp.timeIntervalSince1970, speed: 0)
        }
        let splitsJSON: [CardioSplitJSON] = run.splits.map {
            CardioSplitJSON(number: $0.splitNumber, distance: $0.distance, duration: $0.duration, pace: $0.pace, elevationChange: $0.elevationChange, avgHeartRate: $0.avgHeartRate)
        }
        let payload = CardioSessionInsert(
            user_id: userId,
            sport: "running",
            started_at: iso.string(from: start),
            ended_at: iso.string(from: run.date),
            distance_m: run.distanceMiles * 1609.344,
            duration_s: run.durationSeconds,
            elevation_gain_m: run.totalElevationGain / 3.28084,
            avg_pace: run.averagePace,
            avg_speed_mps: run.durationSeconds > 0 ? (run.distanceMiles * 1609.344) / run.durationSeconds : 0,
            calories: run.caloriesBurned,
            avg_heart_rate: run.averageHeartRate,
            max_heart_rate: run.maxHeartRate,
            route_points: routeJSON,
            splits: splitsJSON,
            is_indoor: run.isTreadmill
        )
        do {
            try await supabase.from("cardio_sessions").insert(payload).execute()
        } catch {
            print("CardioSessionService saveRun error: \(error)")
        }
    }

    func saveRide(_ ride: CompletedRide) async {
        guard let userId = AuthService.shared.session?.user.id.uuidString else { return }
        let start = ride.date.addingTimeInterval(-ride.durationSeconds)
        let routeJSON: [CardioRoutePointJSON] = ride.routeCoordinates.map {
            CardioRoutePointJSON(lat: $0.latitude, lon: $0.longitude, ele: $0.elevation, ts: $0.timestamp.timeIntervalSince1970, speed: $0.speed / 2.23694)
        }
        let splitsJSON: [CardioSplitJSON] = ride.segments.map {
            CardioSplitJSON(number: $0.segmentNumber, distance: $0.distanceMiles, duration: $0.duration, pace: 0, elevationChange: $0.elevationChange, avgHeartRate: $0.avgHeartRate)
        }
        let avgSpeedMps = ride.durationSeconds > 0 ? (ride.distanceMiles * 1609.344) / ride.durationSeconds : 0
        let payload = CardioSessionInsert(
            user_id: userId,
            sport: "cycling",
            started_at: iso.string(from: start),
            ended_at: iso.string(from: ride.date),
            distance_m: ride.distanceMiles * 1609.344,
            duration_s: ride.durationSeconds,
            elevation_gain_m: ride.totalElevationGain / 3.28084,
            avg_pace: 0,
            avg_speed_mps: avgSpeedMps,
            calories: ride.caloriesBurned,
            avg_heart_rate: ride.averageHeartRate,
            max_heart_rate: ride.maxHeartRate,
            route_points: routeJSON,
            splits: splitsJSON,
            is_indoor: ride.isIndoor
        )
        do {
            try await supabase.from("cardio_sessions").insert(payload).execute()
        } catch {
            print("CardioSessionService saveRide error: \(error)")
        }
    }
}
