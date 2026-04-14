import Foundation
import Supabase

nonisolated struct SupabaseWorkout: Codable, Sendable {
    let id: String?
    let user_id: String
    let date: String?
    let name: String
    let sport: String?
    let workout_type: String?
    let duration_minutes: Int?
    let calories_burned: Int?
    let distance: Double?
    let exercises: String?
    let notes: String?
    let fp_earned: Int?
    let started_at: String?
    let completed_at: String?
    let created_at: String?
}

nonisolated struct CreateWorkoutPayload: Codable, Sendable {
    let user_id: String
    let date: String
    let name: String
    let sport: String?
    let workout_type: String?
    let duration_minutes: Int?
    let calories_burned: Int?
    let distance: Double?
    let exercises: String?
    let notes: String?
    let fp_earned: Int?
    let started_at: String?
    let completed_at: String
}

nonisolated struct WorkoutExerciseJSON: Codable, Sendable {
    let name: String
    let sets: [WorkoutSetJSON]
}

nonisolated struct WorkoutSetJSON: Codable, Sendable {
    let setNumber: Int
    let weight: Double
    let reps: Int
}

nonisolated struct SportSessionJSON: Codable, Sendable {
    let sport: String
    let sessionType: String
    let intensity: Int
    let customSportName: String?
    let basketballPoints: Int?
    let basketballAssists: Int?
    let basketballRebounds: Int?
    let runningDistanceMiles: Double?
    let runningPace: Double?
    let swimmingLaps: Int?
    let swimmingStroke: String?
    let cyclingDistanceMiles: Double?
    let cyclingAvgSpeed: Double?
    let cyclingElevationGain: Double?
    let soccerGoals: Int?
    let soccerAssists: Int?
    let soccerDistanceKm: Double?
    let tennisAces: Int?
    let tennisDoubleFaults: Int?
    let tennisWinners: Int?
    let tennisUnforcedErrors: Int?
    let tennisFirstServePercentage: Double?
}

final class WorkoutService {
    static let shared = WorkoutService()

    private var supabase: SupabaseClient {
        SupabaseService.shared.client
    }

    private init() {}

    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private let iso8601Basic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private func parseDate(_ string: String?) -> Date {
        guard let string else { return Date() }
        return iso8601.date(from: string) ?? iso8601Basic.date(from: string) ?? Date()
    }

    func fetchWorkouts(userId: String, limit: Int = 50) async throws -> [SupabaseWorkout] {
        let response: [SupabaseWorkout] = try await supabase
            .from("workouts")
            .select()
            .eq("user_id", value: userId)
            .order("completed_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return response
    }

    func createWorkout(
        userId: String,
        name: String,
        workoutType: String?,
        sport: String? = nil,
        durationMinutes: Int?,
        caloriesBurned: Int?,
        distance: Double? = nil,
        exercisesJSON: String? = nil,
        notes: String? = nil,
        fpEarned: Int? = nil
    ) async throws -> SupabaseWorkout {
        let now = Date()
        let startedAt: Date
        if let mins = durationMinutes {
            startedAt = now.addingTimeInterval(-Double(mins) * 60)
        } else {
            startedAt = now
        }
        let payload = CreateWorkoutPayload(
            user_id: userId,
            date: dateOnlyFormatter.string(from: now),
            name: name,
            sport: sport,
            workout_type: workoutType,
            duration_minutes: durationMinutes,
            calories_burned: caloriesBurned,
            distance: distance,
            exercises: exercisesJSON,
            notes: notes,
            fp_earned: fpEarned,
            started_at: iso8601.string(from: startedAt),
            completed_at: iso8601.string(from: now)
        )

        let created: SupabaseWorkout = try await supabase
            .from("workouts")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
        return created
    }

    func createWorkoutWithDetails(
        userId: String,
        name: String,
        type: String?,
        durationMinutes: Int?,
        caloriesBurned: Int?,
        totalVolume: Int,
        fpEarned: Int,
        exercises: [WorkoutHistoryExerciseDetail]
    ) async throws -> SupabaseWorkout {
        let exerciseJSON = exercises.map { ex in
            WorkoutExerciseJSON(
                name: ex.exerciseName,
                sets: ex.sets.map { s in
                    WorkoutSetJSON(setNumber: s.setNumber, weight: s.weight, reps: s.reps)
                }
            )
        }
        let exercisesString = (try? String(data: JSONEncoder().encode(exerciseJSON), encoding: .utf8)) ?? nil
        let notesJSON: [String: Int] = ["totalVolume": totalVolume]
        let notesString = (try? String(data: JSONEncoder().encode(notesJSON), encoding: .utf8)) ?? nil

        return try await createWorkout(
            userId: userId,
            name: name,
            workoutType: type,
            durationMinutes: durationMinutes,
            caloriesBurned: caloriesBurned,
            exercisesJSON: exercisesString,
            notes: notesString,
            fpEarned: fpEarned
        )
    }

    func createSportSession(
        userId: String,
        session: SportSession
    ) async throws -> SupabaseWorkout {
        let sportJSON = encodeSportSession(session)
        let notesString = (try? String(data: JSONEncoder().encode(sportJSON), encoding: .utf8)) ?? nil

        return try await createWorkout(
            userId: userId,
            name: session.displayName,
            workoutType: "sport",
            sport: session.sport.rawValue,
            durationMinutes: session.durationMinutes,
            caloriesBurned: nil,
            notes: notesString,
            fpEarned: session.fpEarned
        )
    }

    func deleteWorkout(workoutId: String) async throws {
        try await supabase
            .from("workouts")
            .delete()
            .eq("id", value: workoutId)
            .execute()
    }

    func toWorkoutHistoryDetail(_ workout: SupabaseWorkout) -> WorkoutHistoryDetail {
        let date = parseDate(workout.completed_at)
        let durationMinutes = workout.duration_minutes ?? 0
        let fpEarned = workout.fp_earned ?? ((durationMinutes * 5) + ((workout.calories_burned ?? 0) / 10))

        var exercises: [WorkoutHistoryExerciseDetail] = []
        var totalVolume = 0

        if let exercisesStr = workout.exercises,
           let exercisesData = exercisesStr.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([WorkoutExerciseJSON].self, from: exercisesData) {
            exercises = decoded.map { ex in
                WorkoutHistoryExerciseDetail(
                    exerciseName: ex.name,
                    sets: ex.sets.map { s in
                        WorkoutHistorySetDetail(setNumber: s.setNumber, weight: s.weight, reps: s.reps)
                    }
                )
            }
            for ex in exercises {
                for s in ex.sets {
                    totalVolume += Int(s.weight) * s.reps
                }
            }
        }

        if let notesStr = workout.notes,
           let notesData = notesStr.data(using: .utf8),
           let meta = try? JSONDecoder().decode([String: Int].self, from: notesData),
           let vol = meta["totalVolume"] {
            totalVolume = vol
        }

        return WorkoutHistoryDetail(
            name: workout.name,
            date: date,
            durationMinutes: durationMinutes,
            totalVolume: totalVolume,
            caloriesBurned: workout.calories_burned ?? 0,
            fpEarned: fpEarned,
            exercises: exercises
        )
    }

    func toSportSession(_ workout: SupabaseWorkout) -> SportSession? {
        let isSport = workout.workout_type == "sport" || (workout.workout_type?.hasPrefix("sport_") == true)
        guard isSport || workout.sport != nil else { return nil }

        guard let notesStr = workout.notes,
              let notesData = notesStr.data(using: .utf8),
              let json = try? JSONDecoder().decode(SportSessionJSON.self, from: notesData) else {
            let sportName = workout.sport ?? ""
            let sport = Sport.allCases.first { $0.rawValue.lowercased() == sportName.lowercased() } ?? .custom
            let sessionType = SportSessionType.allCases.first { $0.rawValue == "Training" } ?? .training
            return SportSession(
                sport: sport,
                sessionType: sessionType,
                durationMinutes: workout.duration_minutes ?? 0,
                intensity: 5,
                date: parseDate(workout.completed_at)
            )
        }

        let sport = Sport.allCases.first { $0.rawValue == json.sport } ?? .custom
        let sessionType = SportSessionType.allCases.first { $0.rawValue == json.sessionType } ?? .training

        var stats: SportSpecificStats = .none
        switch sport {
        case .basketball:
            if let pts = json.basketballPoints {
                stats = .basketball(BasketballStats(points: pts, assists: json.basketballAssists ?? 0, rebounds: json.basketballRebounds ?? 0))
            }
        case .running:
            if let dist = json.runningDistanceMiles {
                stats = .running(RunningStats(distanceMiles: dist, paceMinutesPerMile: json.runningPace ?? 0))
            }
        case .swimming:
            if let laps = json.swimmingLaps {
                let stroke = SwimmingStroke.allCases.first { $0.rawValue == json.swimmingStroke } ?? .freestyle
                stats = .swimming(SwimmingStats(laps: laps, stroke: stroke))
            }
        case .cycling:
            if let dist = json.cyclingDistanceMiles {
                stats = .cycling(CyclingStats(distanceMiles: dist, averageSpeed: json.cyclingAvgSpeed ?? 0, elevationGain: json.cyclingElevationGain ?? 0))
            }
        case .soccer:
            if let goals = json.soccerGoals {
                stats = .soccer(SoccerSessionStats(goals: goals, assists: json.soccerAssists ?? 0, distanceKm: json.soccerDistanceKm ?? 0))
            }
        case .tennis:
            if let aces = json.tennisAces {
                stats = .tennis(TennisSessionStats(aces: aces, doubleFaults: json.tennisDoubleFaults ?? 0, winners: json.tennisWinners ?? 0, unforcedErrors: json.tennisUnforcedErrors ?? 0, firstServePercentage: json.tennisFirstServePercentage ?? 0))
            }
        default:
            break
        }

        return SportSession(
            sport: sport,
            sessionType: sessionType,
            durationMinutes: workout.duration_minutes ?? 0,
            intensity: json.intensity,
            date: parseDate(workout.completed_at),
            specificStats: stats,
            customSportName: json.customSportName
        )
    }

    private func encodeSportSession(_ session: SportSession) -> SportSessionJSON {
        var json = SportSessionJSON(
            sport: session.sport.rawValue,
            sessionType: session.sessionType.rawValue,
            intensity: session.intensity,
            customSportName: session.customSportName,
            basketballPoints: nil, basketballAssists: nil, basketballRebounds: nil,
            runningDistanceMiles: nil, runningPace: nil,
            swimmingLaps: nil, swimmingStroke: nil,
            cyclingDistanceMiles: nil, cyclingAvgSpeed: nil, cyclingElevationGain: nil,
            soccerGoals: nil, soccerAssists: nil, soccerDistanceKm: nil,
            tennisAces: nil, tennisDoubleFaults: nil, tennisWinners: nil,
            tennisUnforcedErrors: nil, tennisFirstServePercentage: nil
        )

        switch session.specificStats {
        case .basketball(let s):
            json = SportSessionJSON(
                sport: json.sport, sessionType: json.sessionType, intensity: json.intensity, customSportName: json.customSportName,
                basketballPoints: s.points, basketballAssists: s.assists, basketballRebounds: s.rebounds,
                runningDistanceMiles: nil, runningPace: nil,
                swimmingLaps: nil, swimmingStroke: nil,
                cyclingDistanceMiles: nil, cyclingAvgSpeed: nil, cyclingElevationGain: nil,
                soccerGoals: nil, soccerAssists: nil, soccerDistanceKm: nil,
                tennisAces: nil, tennisDoubleFaults: nil, tennisWinners: nil,
                tennisUnforcedErrors: nil, tennisFirstServePercentage: nil
            )
        case .running(let s):
            json = SportSessionJSON(
                sport: json.sport, sessionType: json.sessionType, intensity: json.intensity, customSportName: json.customSportName,
                basketballPoints: nil, basketballAssists: nil, basketballRebounds: nil,
                runningDistanceMiles: s.distanceMiles, runningPace: s.paceMinutesPerMile,
                swimmingLaps: nil, swimmingStroke: nil,
                cyclingDistanceMiles: nil, cyclingAvgSpeed: nil, cyclingElevationGain: nil,
                soccerGoals: nil, soccerAssists: nil, soccerDistanceKm: nil,
                tennisAces: nil, tennisDoubleFaults: nil, tennisWinners: nil,
                tennisUnforcedErrors: nil, tennisFirstServePercentage: nil
            )
        case .swimming(let s):
            json = SportSessionJSON(
                sport: json.sport, sessionType: json.sessionType, intensity: json.intensity, customSportName: json.customSportName,
                basketballPoints: nil, basketballAssists: nil, basketballRebounds: nil,
                runningDistanceMiles: nil, runningPace: nil,
                swimmingLaps: s.laps, swimmingStroke: s.stroke.rawValue,
                cyclingDistanceMiles: nil, cyclingAvgSpeed: nil, cyclingElevationGain: nil,
                soccerGoals: nil, soccerAssists: nil, soccerDistanceKm: nil,
                tennisAces: nil, tennisDoubleFaults: nil, tennisWinners: nil,
                tennisUnforcedErrors: nil, tennisFirstServePercentage: nil
            )
        case .cycling(let s):
            json = SportSessionJSON(
                sport: json.sport, sessionType: json.sessionType, intensity: json.intensity, customSportName: json.customSportName,
                basketballPoints: nil, basketballAssists: nil, basketballRebounds: nil,
                runningDistanceMiles: nil, runningPace: nil,
                swimmingLaps: nil, swimmingStroke: nil,
                cyclingDistanceMiles: s.distanceMiles, cyclingAvgSpeed: s.averageSpeed, cyclingElevationGain: s.elevationGain,
                soccerGoals: nil, soccerAssists: nil, soccerDistanceKm: nil,
                tennisAces: nil, tennisDoubleFaults: nil, tennisWinners: nil,
                tennisUnforcedErrors: nil, tennisFirstServePercentage: nil
            )
        case .soccer(let s):
            json = SportSessionJSON(
                sport: json.sport, sessionType: json.sessionType, intensity: json.intensity, customSportName: json.customSportName,
                basketballPoints: nil, basketballAssists: nil, basketballRebounds: nil,
                runningDistanceMiles: nil, runningPace: nil,
                swimmingLaps: nil, swimmingStroke: nil,
                cyclingDistanceMiles: nil, cyclingAvgSpeed: nil, cyclingElevationGain: nil,
                soccerGoals: s.goals, soccerAssists: s.assists, soccerDistanceKm: s.distanceKm,
                tennisAces: nil, tennisDoubleFaults: nil, tennisWinners: nil,
                tennisUnforcedErrors: nil, tennisFirstServePercentage: nil
            )
        case .tennis(let s):
            json = SportSessionJSON(
                sport: json.sport, sessionType: json.sessionType, intensity: json.intensity, customSportName: json.customSportName,
                basketballPoints: nil, basketballAssists: nil, basketballRebounds: nil,
                runningDistanceMiles: nil, runningPace: nil,
                swimmingLaps: nil, swimmingStroke: nil,
                cyclingDistanceMiles: nil, cyclingAvgSpeed: nil, cyclingElevationGain: nil,
                soccerGoals: nil, soccerAssists: nil, soccerDistanceKm: nil,
                tennisAces: s.aces, tennisDoubleFaults: s.doubleFaults, tennisWinners: s.winners,
                tennisUnforcedErrors: s.unforcedErrors, tennisFirstServePercentage: s.firstServePercentage
            )
        case .none:
            break
        }

        return json
    }
}
