import Foundation
import HealthKit

nonisolated enum UnifiedActivitySource: String, Sendable {
    case appleWatch
    case manual
}

nonisolated struct UnifiedActivity: Identifiable, Sendable {
    let id: String
    let source: UnifiedActivitySource
    let sport: String
    let durationMinutes: Int
    let calories: Int
    let date: Date
    let startDate: Date?
    let endDate: Date?
    let notes: String?
}

nonisolated enum ActivityReconciliation: Sendable {

    static func unify(
        manual: [EnergyActivityLog],
        watchWorkouts: [HKWorkout],
        supabaseWorkouts: [SupabaseWorkout] = []
    ) -> (unified: [UnifiedActivity], suppressedManualIds: Set<String>) {
        var result: [UnifiedActivity] = []
        var suppressed: Set<String> = []

        struct WatchEntry {
            let normalizedSport: String
            let duration: Int
        }
        var watchEntries: [WatchEntry] = []

        for w in watchWorkouts {
            let sport = sportName(for: w.workoutActivityType)
            let duration = Int(w.duration / 60)
            let cals: Int = {
                if let stats = w.statistics(for: HKQuantityType(.activeEnergyBurned)),
                   let sum = stats.sumQuantity() {
                    return Int(sum.doubleValue(for: .kilocalorie()))
                }
                return 0
            }()
            result.append(UnifiedActivity(
                id: "hk-\(w.uuid.uuidString)",
                source: .appleWatch,
                sport: sport,
                durationMinutes: max(duration, 1),
                calories: cals,
                date: w.startDate,
                startDate: w.startDate,
                endDate: w.endDate,
                notes: nil
            ))
            watchEntries.append(WatchEntry(normalizedSport: normalize(sport), duration: duration))
        }

        let countedTypes: Set<String> = ["workout", "sportSession", "activity", "cardio", "run", "ride", "swim"]
        for log in manual {
            guard countedTypes.contains(log.activity_type), let dur = log.duration_minutes else { continue }
            let sport = log.sport ?? log.activity_type.capitalized
            let normalized = normalize(sport)
            let overlaps = watchEntries.contains { entry in
                sportsMatch(entry.normalizedSport, normalized) && abs(entry.duration - dur) <= 10
            }
            if overlaps {
                if let id = log.id { suppressed.insert(id) }
                continue
            }
            result.append(UnifiedActivity(
                id: log.id ?? UUID().uuidString,
                source: .manual,
                sport: sport,
                durationMinutes: dur,
                calories: log.calories_burned ?? 0,
                date: parseLogDate(log.activity_date) ?? Date(),
                startDate: nil,
                endDate: nil,
                notes: log.notes
            ))
        }

        let todayStr: String = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.locale = Locale(identifier: "en_US_POSIX")
            return f.string(from: Date())
        }()

        for w in supabaseWorkouts where w.date == todayStr {
            let sportLabel = w.sport ?? w.workout_type ?? w.name
            let normalized = normalize(sportLabel)
            let dur = w.duration_minutes ?? 0
            let overlaps = watchEntries.contains { entry in
                sportsMatch(entry.normalizedSport, normalized) && abs(entry.duration - dur) <= 10
            }
            if overlaps { continue }
            let startDate: Date? = {
                guard let s = w.started_at else { return nil }
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let fBasic = ISO8601DateFormatter()
                fBasic.formatOptions = [.withInternetDateTime]
                return f.date(from: s) ?? fBasic.date(from: s)
            }()
            let endDate: Date? = {
                guard let s = w.completed_at else { return nil }
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let fBasic = ISO8601DateFormatter()
                fBasic.formatOptions = [.withInternetDateTime]
                return f.date(from: s) ?? fBasic.date(from: s)
            }()
            result.append(UnifiedActivity(
                id: "wk-\(w.id ?? UUID().uuidString)",
                source: .manual,
                sport: sportLabel,
                durationMinutes: max(dur, 1),
                calories: w.calories_burned ?? 0,
                date: endDate ?? startDate ?? parseLogDate(todayStr) ?? Date(),
                startDate: startDate,
                endDate: endDate,
                notes: w.notes
            ))
        }

        let sorted = result.sorted { ($0.startDate ?? $0.date) > ($1.startDate ?? $1.date) }
        return (sorted, suppressed)
    }

    static func sportsMatch(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        if a.contains(b) || b.contains(a) { return true }
        let runningAliases: Set<String> = ["running", "run", "jog", "jogging"]
        let walkingAliases: Set<String> = ["walking", "walk"]
        let cyclingAliases: Set<String> = ["cycling", "bike", "biking", "ride"]
        let strengthAliases: Set<String> = ["strength", "weights", "weight training", "lifting", "resistance"]
        for aliases in [runningAliases, walkingAliases, cyclingAliases, strengthAliases] {
            if aliases.contains(a) && aliases.contains(b) { return true }
        }
        return false
    }

    static func normalize(_ s: String) -> String {
        s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func sportName(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .yoga: return "Yoga"
        case .hiking: return "Hiking"
        case .highIntensityIntervalTraining: return "HIIT"
        case .functionalStrengthTraining, .traditionalStrengthTraining, .coreTraining: return "Strength"
        case .rowing: return "Rowing"
        case .elliptical: return "Elliptical"
        case .jumpRope: return "Jump Rope"
        case .stairClimbing, .stairs, .stepTraining: return "Stair Climbing"
        case .boxing, .kickboxing: return "Boxing"
        case .martialArts: return "Martial Arts"
        case .pilates: return "Pilates"
        case .climbing: return "Rock Climbing"
        case .basketball: return "Basketball"
        case .soccer: return "Soccer"
        case .tennis: return "Tennis"
        case .americanFootball: return "Football"
        case .baseball: return "Baseball"
        case .dance, .socialDance, .cardioDance: return "Dancing"
        case .flexibility, .preparationAndRecovery: return "Stretching"
        case .mixedCardio: return "Cardio"
        default: return "Workout"
        }
    }

    private static let logDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static func parseLogDate(_ s: String) -> Date? {
        logDateFormatter.date(from: s)
    }
}
