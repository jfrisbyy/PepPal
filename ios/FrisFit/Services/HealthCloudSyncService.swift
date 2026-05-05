import Foundation
import HealthKit
import Supabase

// MARK: - Row shapes

nonisolated struct HealthDailySnapshotRow: Codable, Sendable {
    let user_id: String
    let day: String
    let steps: Int
    let active_calories: Double
    let resting_calories: Double
    let distance_meters: Double
    let flights_climbed: Int
    let exercise_minutes: Double
    let stand_hours: Int
    let sleep_hours: Double
    let sleep_deep_hours: Double?
    let sleep_rem_hours: Double?
    let sleep_core_hours: Double?
    let heart_rate: Double?
    let resting_heart_rate: Double?
    let walking_heart_rate: Double?
    let hrv: Double?
    let respiratory_rate: Double?
    let oxygen_saturation: Double?
    let vo2_max: Double?
    let body_weight: Double?
    let body_fat_percentage: Double?
    let lean_body_mass: Double?
    let waist_circumference: Double?
    let bmi: Double?
    let mindful_minutes: Double
    let dietary_energy: Double
    let dietary_protein: Double
    let dietary_carbs: Double
    let dietary_fat: Double
    let dietary_water: Double
    let blood_glucose: Double?
    let blood_pressure_systolic: Double?
    let blood_pressure_diastolic: Double?
    let body_temperature: Double?
    let captured_at: String
}

nonisolated struct HealthSeriesPointRow: Codable, Sendable {
    let user_id: String
    let metric: String
    let day: String
    let value: Double
    let min_value: Double?
    let max_value: Double?
    let captured_at: String
}

nonisolated struct HealthSleepNightRow: Codable, Sendable {
    let user_id: String
    let night: String
    let asleep_hours: Double
    let deep_hours: Double
    let rem_hours: Double
    let core_hours: Double
    let captured_at: String
}

nonisolated struct HealthWorkoutCloudRow: Codable, Sendable {
    let id: String
    let user_id: String
    let activity_type: Int
    let activity_name: String
    let start_at: String
    let end_at: String
    let duration_seconds: Double
    let distance_meters: Double
    let calories: Double
    let average_heart_rate: Double?
    let max_heart_rate: Double?
    let source_name: String?
    let captured_at: String
}

nonisolated struct HealthSyncStateRow: Codable, Sendable {
    let user_id: String
    let last_full_sync_at: String?
    let last_delta_sync_at: String?
    let last_backfill_at: String?
    let days_stored: Int
    let workouts_stored: Int
    let updated_at: String
}

// MARK: - Service

@Observable
final class HealthCloudSyncService {
    static let shared = HealthCloudSyncService()

    /// Last completed sync timestamp (any kind).
    var lastSyncedAt: Date? = nil
    var isSyncing: Bool = false
    var lastError: String? = nil
    var daysStored: Int = 0
    var workoutsStored: Int = 0

    private var supabase: SupabaseClient { SupabaseService.shared.client }

    private static let lastSyncKey = "health.cloud.lastSyncedAt"
    private static let didBackfillKey = "health.cloud.didBackfill90"
    private static let syncDebounceSeconds: TimeInterval = 60 * 60 // 1h

    private init() {
        if let ts = UserDefaults.standard.object(forKey: Self.lastSyncKey) as? Date {
            lastSyncedAt = ts
        }
    }

    // MARK: - Public API

    /// Foreground sync: pushes today's snapshot + new workouts, debounced to once / hour.
    func syncIfNeeded(force: Bool = false) async {
        guard HealthKitService.shared.isAuthorized else { return }
        guard UserDefaults.standard.bool(forKey: "healthkit_enabled") else { return }
        if !force, let last = lastSyncedAt, Date().timeIntervalSince(last) < Self.syncDebounceSeconds {
            return
        }
        await performDeltaSync()
    }

    /// First-time backfill of last 90 days. Runs once after connect.
    func backfillIfNeeded() async {
        guard HealthKitService.shared.isAuthorized else { return }
        guard !UserDefaults.standard.bool(forKey: Self.didBackfillKey) else { return }
        await backfill(days: 90)
        UserDefaults.standard.set(true, forKey: Self.didBackfillKey)
    }

    /// User-triggered re-backfill from the settings screen.
    func resyncRecent(days: Int = 90) async {
        await backfill(days: days)
    }

    /// User-triggered cloud wipe.
    func deleteAllCloudData() async {
        guard let userId = await currentUserId() else { return }
        do {
            try await supabase.from("health_daily_snapshots").delete().eq("user_id", value: userId).execute()
            try await supabase.from("health_series_points").delete().eq("user_id", value: userId).execute()
            try await supabase.from("health_sleep_nights").delete().eq("user_id", value: userId).execute()
            try await supabase.from("health_workouts").delete().eq("user_id", value: userId).execute()
            try await supabase.from("health_sync_state").delete().eq("user_id", value: userId).execute()
            UserDefaults.standard.removeObject(forKey: Self.didBackfillKey)
            UserDefaults.standard.removeObject(forKey: Self.lastSyncKey)
            lastSyncedAt = nil
            daysStored = 0
            workoutsStored = 0
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Hydrate observable counters from the cloud state row.
    func refreshState() async {
        guard let userId = await currentUserId() else { return }
        struct StateOnly: Codable { let days_stored: Int?; let workouts_stored: Int?; let last_delta_sync_at: String? }
        do {
            let rows: [StateOnly] = try await supabase
                .from("health_sync_state")
                .select("days_stored,workouts_stored,last_delta_sync_at")
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value
            if let row = rows.first {
                daysStored = row.days_stored ?? 0
                workoutsStored = row.workouts_stored ?? 0
            }
        } catch {
            // ignore
        }
    }

    // MARK: - Read helpers (for summaries / AI / empty states)

    func fetchDailySnapshots(days: Int) async -> [HealthDailySnapshotRow] {
        guard let userId = await currentUserId() else { return [] }
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -days, to: cal.startOfDay(for: Date())) else { return [] }
        let startStr = isoDay(start)
        do {
            let rows: [HealthDailySnapshotRow] = try await supabase
                .from("health_daily_snapshots")
                .select()
                .eq("user_id", value: userId)
                .gte("day", value: startStr)
                .order("day", ascending: false)
                .execute()
                .value
            return rows
        } catch {
            return []
        }
    }

    func fetchLatestSnapshot() async -> HealthDailySnapshotRow? {
        guard let userId = await currentUserId() else { return nil }
        do {
            let rows: [HealthDailySnapshotRow] = try await supabase
                .from("health_daily_snapshots")
                .select()
                .eq("user_id", value: userId)
                .order("day", ascending: false)
                .limit(1)
                .execute()
                .value
            return rows.first
        } catch {
            return nil
        }
    }

    // MARK: - Internal sync flows

    private func performDeltaSync() async {
        guard let userId = await currentUserId() else { return }
        isSyncing = true
        defer { isSyncing = false }

        let hk = HealthKitService.shared
        let today = Date()

        // Today's daily snapshot
        if let row = await buildSnapshotRow(userId: userId, date: today, hk: hk) {
            do {
                try await supabase.from("health_daily_snapshots")
                    .upsert(row, onConflict: "user_id,day")
                    .execute()
            } catch {
                lastError = error.localizedDescription
            }
        }

        // Today's sleep night
        if let sleep = await buildSleepNightRow(userId: userId, date: today, hk: hk) {
            try? await supabase.from("health_sleep_nights")
                .upsert(sleep, onConflict: "user_id,night")
                .execute()
        }

        // Today's workouts
        let workouts = await hk.fetchWorkouts(for: today)
        let workoutRows = workouts.map { workoutRow(userId: userId, workout: $0) }
        if !workoutRows.isEmpty {
            try? await supabase.from("health_workouts")
                .upsert(workoutRows, onConflict: "id")
                .execute()
        }

        // Series point for today's primary metrics
        let seriesRows = makeTodaySeriesRows(userId: userId, hk: hk, date: today)
        if !seriesRows.isEmpty {
            try? await supabase.from("health_series_points")
                .upsert(seriesRows, onConflict: "user_id,metric,day")
                .execute()
        }

        await updateState(userId: userId, isFull: false)
        lastSyncedAt = Date()
        UserDefaults.standard.set(lastSyncedAt, forKey: Self.lastSyncKey)
    }

    private func backfill(days: Int) async {
        guard let userId = await currentUserId() else { return }
        isSyncing = true
        defer { isSyncing = false }

        let hk = HealthKitService.shared
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())

        var snapshotRows: [HealthDailySnapshotRow] = []
        var sleepRows: [HealthSleepNightRow] = []
        var seriesRows: [HealthSeriesPointRow] = []
        var workoutRows: [HealthWorkoutCloudRow] = []

        for offset in 0..<days {
            guard let date = cal.date(byAdding: .day, value: -offset, to: startOfToday) else { continue }
            if let snap = await buildSnapshotRow(userId: userId, date: date, hk: hk) {
                snapshotRows.append(snap)
                seriesRows.append(contentsOf: snapshotToSeriesRows(snap))
            }
            if let sleep = await buildSleepNightRow(userId: userId, date: date, hk: hk) {
                sleepRows.append(sleep)
            }
            let workouts = await hk.fetchWorkouts(for: date)
            workoutRows.append(contentsOf: workouts.map { workoutRow(userId: userId, workout: $0) })
        }

        // Upload in chunks
        await uploadInChunks(snapshotRows, table: "health_daily_snapshots", conflict: "user_id,day", chunk: 50)
        await uploadInChunks(sleepRows, table: "health_sleep_nights", conflict: "user_id,night", chunk: 50)
        await uploadInChunks(workoutRows, table: "health_workouts", conflict: "id", chunk: 50)
        await uploadInChunks(seriesRows, table: "health_series_points", conflict: "user_id,metric,day", chunk: 100)

        await updateState(userId: userId, isFull: true, backfill: true)
        lastSyncedAt = Date()
        UserDefaults.standard.set(lastSyncedAt, forKey: Self.lastSyncKey)
    }

    private func uploadInChunks<T: Encodable & Sendable>(_ rows: [T], table: String, conflict: String, chunk: Int) async {
        guard !rows.isEmpty else { return }
        var index = 0
        while index < rows.count {
            let end = min(index + chunk, rows.count)
            let batch = Array(rows[index..<end])
            do {
                try await supabase.from(table).upsert(batch, onConflict: conflict).execute()
            } catch {
                lastError = error.localizedDescription
            }
            index = end
        }
    }

    private func updateState(userId: String, isFull: Bool, backfill: Bool = false) async {
        let now = isoTimestamp(Date())

        // Count days + workouts in cloud (cheap head requests)
        var daysCount = 0
        var workoutsCount = 0
        do {
            let response = try await supabase.from("health_daily_snapshots")
                .select("day", head: true, count: .exact)
                .eq("user_id", value: userId)
                .execute()
            daysCount = response.count ?? 0
        } catch { }
        do {
            let response = try await supabase.from("health_workouts")
                .select("id", head: true, count: .exact)
                .eq("user_id", value: userId)
                .execute()
            workoutsCount = response.count ?? 0
        } catch { }

        daysStored = daysCount
        workoutsStored = workoutsCount

        let row = HealthSyncStateRow(
            user_id: userId,
            last_full_sync_at: isFull ? now : nil,
            last_delta_sync_at: now,
            last_backfill_at: backfill ? now : nil,
            days_stored: daysCount,
            workouts_stored: workoutsCount,
            updated_at: now
        )
        try? await supabase.from("health_sync_state")
            .upsert(row, onConflict: "user_id")
            .execute()
    }

    // MARK: - Builders

    private func buildSnapshotRow(userId: String, date: Date, hk: HealthKitService) async -> HealthDailySnapshotRow? {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        guard let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) else { return nil }
        let bpm = HKUnit.count().unitDivided(by: .minute())

        async let stepsV = hk.fetchSteps(for: date)
        async let activeV = hk.fetchActiveCalories(for: date)
        async let restingV = hk.fetchRestingCalories(for: date)
        async let distV = hk.fetchDistanceWalking(for: date)
        async let flightsV = hk.fetchFlightsClimbed(for: date)
        async let exV = hk.fetchExerciseMinutes(for: date)
        async let sleepV = hk.fetchSleepHours(for: date)
        async let hrV = hk.fetchAverageHeartRate(for: date)

        async let hrvV = hk.fetchDayAverage(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), date: date)
        async let rhrV = hk.fetchDayAverage(.restingHeartRate, unit: bpm, date: date)
        async let whrV = hk.fetchDayAverage(.walkingHeartRateAverage, unit: bpm, date: date)
        async let rrV = hk.fetchDayAverage(.respiratoryRate, unit: bpm, date: date)
        async let o2V = hk.fetchDayAverage(.oxygenSaturation, unit: .percent(), date: date)
        async let vo2V = hk.fetchDayAverage(.vo2Max, unit: HKUnit(from: "ml/kg*min"), date: date)
        async let weightV = hk.fetchDayAverage(.bodyMass, unit: .pound(), date: date)
        async let bfV = hk.fetchDayAverage(.bodyFatPercentage, unit: .percent(), date: date)
        async let lbmV = hk.fetchDayAverage(.leanBodyMass, unit: .pound(), date: date)
        async let waistV = hk.fetchDayAverage(.waistCircumference, unit: .inch(), date: date)
        async let bmiV = hk.fetchDayAverage(.bodyMassIndex, unit: .count(), date: date)
        async let glucV = hk.fetchDayAverage(.bloodGlucose, unit: HKUnit(from: "mg/dL"), date: date)
        async let bpsV = hk.fetchDayAverage(.bloodPressureSystolic, unit: .millimeterOfMercury(), date: date)
        async let bpdV = hk.fetchDayAverage(.bloodPressureDiastolic, unit: .millimeterOfMercury(), date: date)
        async let tempV = hk.fetchDayAverage(.bodyTemperature, unit: .degreeFahrenheit(), date: date)

        async let dECV = hk.fetchCumulativeSum(for: .dietaryEnergyConsumed, unit: .kilocalorie(), start: startOfDay, end: endOfDay)
        async let dPV = hk.fetchCumulativeSum(for: .dietaryProtein, unit: .gram(), start: startOfDay, end: endOfDay)
        async let dCV = hk.fetchCumulativeSum(for: .dietaryCarbohydrates, unit: .gram(), start: startOfDay, end: endOfDay)
        async let dFV = hk.fetchCumulativeSum(for: .dietaryFatTotal, unit: .gram(), start: startOfDay, end: endOfDay)
        async let dWV = hk.fetchCumulativeSum(for: .dietaryWater, unit: .literUnit(with: .milli), start: startOfDay, end: endOfDay)

        let steps = await stepsV
        let active = await activeV
        let resting = await restingV
        let dist = await distV
        let flights = await flightsV
        let ex = await exV
        let sleep = await sleepV
        let hr = await hrV
        let hrv = await hrvV
        let rhr = await rhrV
        let whr = await whrV
        let rr = await rrV
        let o2raw = await o2V
        let vo2 = await vo2V
        let weight = await weightV
        let bfRaw = await bfV
        let lbm = await lbmV
        let waist = await waistV
        let bmiVal = await bmiV
        let gluc = await glucV
        let bps = await bpsV
        let bpd = await bpdV
        let temp = await tempV
        let dEC = await dECV
        let dP = await dPV
        let dC = await dCV
        let dF = await dFV
        let dW = await dWV

        // Skip days with literally no data to avoid empty cloud rows.
        let hasAny = steps > 0 || active > 0 || sleep > 0 || hr > 0 || hrv != nil || rhr != nil || weight != nil || dEC > 0
        guard hasAny else { return nil }

        return HealthDailySnapshotRow(
            user_id: userId,
            day: isoDay(date),
            steps: steps,
            active_calories: active,
            resting_calories: resting,
            distance_meters: dist,
            flights_climbed: flights,
            exercise_minutes: ex,
            stand_hours: 0,
            sleep_hours: sleep,
            sleep_deep_hours: nil,
            sleep_rem_hours: nil,
            sleep_core_hours: nil,
            heart_rate: hr > 0 ? hr : nil,
            resting_heart_rate: rhr,
            walking_heart_rate: whr,
            hrv: hrv,
            respiratory_rate: rr,
            oxygen_saturation: o2raw.map { $0 * 100 },
            vo2_max: vo2,
            body_weight: weight,
            body_fat_percentage: bfRaw.map { $0 * 100 },
            lean_body_mass: lbm,
            waist_circumference: waist,
            bmi: bmiVal,
            mindful_minutes: 0,
            dietary_energy: dEC,
            dietary_protein: dP,
            dietary_carbs: dC,
            dietary_fat: dF,
            dietary_water: dW,
            blood_glucose: gluc,
            blood_pressure_systolic: bps,
            blood_pressure_diastolic: bpd,
            body_temperature: temp,
            captured_at: isoTimestamp(Date())
        )
    }

    private func buildSleepNightRow(userId: String, date: Date, hk: HealthKitService) async -> HealthSleepNightRow? {
        let asleep = await hk.fetchSleepHours(for: date)
        guard asleep > 0 else { return nil }
        return HealthSleepNightRow(
            user_id: userId,
            night: isoDay(date),
            asleep_hours: asleep,
            deep_hours: 0,
            rem_hours: 0,
            core_hours: 0,
            captured_at: isoTimestamp(Date())
        )
    }

    private func workoutRow(userId: String, workout: HKWorkout) -> HealthWorkoutCloudRow {
        let kcal = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
        let meters = workout.statistics(for: HKQuantityType(.distanceWalkingRunning))?
            .sumQuantity()?.doubleValue(for: .meter()) ?? 0
        return HealthWorkoutCloudRow(
            id: workout.uuid.uuidString,
            user_id: userId,
            activity_type: Int(workout.workoutActivityType.rawValue),
            activity_name: String(describing: workout.workoutActivityType),
            start_at: isoTimestamp(workout.startDate),
            end_at: isoTimestamp(workout.endDate),
            duration_seconds: workout.duration,
            distance_meters: meters,
            calories: kcal,
            average_heart_rate: nil,
            max_heart_rate: nil,
            source_name: workout.sourceRevision.source.name,
            captured_at: isoTimestamp(Date())
        )
    }

    private func makeTodaySeriesRows(userId: String, hk: HealthKitService, date: Date) -> [HealthSeriesPointRow] {
        let day = isoDay(date)
        let now = isoTimestamp(Date())
        var rows: [HealthSeriesPointRow] = []
        func add(_ metric: String, _ value: Double?) {
            guard let v = value, v > 0 else { return }
            rows.append(HealthSeriesPointRow(user_id: userId, metric: metric, day: day, value: v, min_value: nil, max_value: nil, captured_at: now))
        }
        add("steps", Double(hk.steps))
        add("active_calories", hk.activeCalories)
        add("resting_calories", hk.restingCalories)
        add("distance_meters", hk.distanceWalking)
        add("exercise_minutes", hk.exerciseMinutes)
        add("sleep_hours", hk.sleepHours)
        add("hrv", hk.hrv)
        add("resting_heart_rate", hk.restingHeartRate)
        add("heart_rate", hk.heartRate)
        add("body_weight", hk.bodyWeight)
        add("body_fat_percentage", hk.bodyFatPercentage)
        add("vo2_max", hk.vo2Max)
        add("dietary_energy", hk.dietaryEnergyConsumed)
        add("dietary_water", hk.dietaryWater)
        return rows
    }

    private func snapshotToSeriesRows(_ snap: HealthDailySnapshotRow) -> [HealthSeriesPointRow] {
        let now = isoTimestamp(Date())
        var rows: [HealthSeriesPointRow] = []
        func add(_ metric: String, _ value: Double?) {
            guard let v = value, v > 0 else { return }
            rows.append(HealthSeriesPointRow(user_id: snap.user_id, metric: metric, day: snap.day, value: v, min_value: nil, max_value: nil, captured_at: now))
        }
        add("steps", Double(snap.steps))
        add("active_calories", snap.active_calories)
        add("resting_calories", snap.resting_calories)
        add("distance_meters", snap.distance_meters)
        add("exercise_minutes", snap.exercise_minutes)
        add("sleep_hours", snap.sleep_hours)
        add("hrv", snap.hrv)
        add("resting_heart_rate", snap.resting_heart_rate)
        add("heart_rate", snap.heart_rate)
        add("body_weight", snap.body_weight)
        add("body_fat_percentage", snap.body_fat_percentage)
        add("vo2_max", snap.vo2_max)
        add("dietary_energy", snap.dietary_energy)
        add("dietary_water", snap.dietary_water)
        return rows
    }

    // MARK: - Helpers

    private func currentUserId() async -> String? {
        do {
            let session = try await supabase.auth.session
            return session.user.id.uuidString
        } catch {
            return nil
        }
    }

    private func isoDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func isoTimestamp(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }
}
