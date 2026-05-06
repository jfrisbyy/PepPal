import SwiftUI

@Observable
final class TrainViewModel {
    var activeProgram: TrainingProgram? = nil
    var savedPrograms: [TrainingProgram] = []
    var showProgramBuilder: Bool = false
    var showExerciseLibrary: Bool = false
    var showProgramManagement: Bool = false

    var currentMode: TrainMode = TrainMode(type: .main)
    var availableModes: [TrainMode] = [TrainMode(type: .main)]
    var showModeSelectorSheet: Bool = false
    var showCreateModeSheet: Bool = false

    private static let modesKey = "savedTrainModes"
    private static let lastModeKey = "lastActiveTrainModeId"
    private static let programKey = "savedActiveProgram"
    private static let allProgramsKey = "savedAllPrograms"
    private static let programStartDayKey = "programStartDayOffset"
    private static let multiActiveKey = "multiActiveProgramsEnabled"

    var multiActiveEnabled: Bool = UserDefaults.standard.bool(forKey: "multiActiveProgramsEnabled") {
        didSet { UserDefaults.standard.set(multiActiveEnabled, forKey: Self.multiActiveKey) }
    }

    var activePrograms: [TrainingProgram] {
        savedPrograms.filter { $0.isActive }
    }

    var programSupabaseIds: [UUID: String] = [:]
    private var programsLoadedFromSupabase: Bool = false
    private var loadedForUserId: String? = nil
    private var authObserver: NSObjectProtocol?
    /// Programs that have not been confirmed synced to Supabase yet.
    /// Either created offline, or last persist attempt failed.
    private var pendingSyncProgramIds: Set<UUID> = []
    /// Tracks the in-flight Supabase fetch so concurrent callers (onAppear +
    /// auth listener) don't both run `fetchPrograms` and stomp each other.
    private var loadProgramsTask: Task<Void, Never>?

    var programName: String = ""
    var programType: ProgramType = .recurringSplit
    var daysPerWeek: Int = 4
    var programDays: [ProgramDay] = []
    var currentBuilderStep: Int = 0
    var editingDayIndex: Int? = nil

    var templates: [WorkoutTemplate] = [
        WorkoutTemplate(name: "Push Day", exerciseCount: 6, muscleGroups: [.chest, .shoulders, .triceps], estimatedMinutes: 55),
        WorkoutTemplate(name: "Pull Day", exerciseCount: 6, muscleGroups: [.back, .biceps, .forearms], estimatedMinutes: 50),
        WorkoutTemplate(name: "Leg Day", exerciseCount: 7, muscleGroups: [.quadriceps, .hamstrings, .glutes, .calves], estimatedMinutes: 60),
    ]

    private var dataLoaded: Bool = false

    var workoutHistory: [WorkoutHistoryDetail] = []
    var sportSessions: [SportSession] = []
    var personalRecords: [TrainPersonalRecord] = []

    var weeklyWorkoutGoal: Int = 5

    var progressionNotices: [ProgressionNotice] = []

    var workoutsCompletedThisWeek: Int {
        let cal = Calendar.current
        let weekStart = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let workoutCount = workoutHistory.filter { $0.date >= weekStart }.count
        let sportCount = sportSessions.filter { $0.date >= weekStart }.count
        return workoutCount + sportCount
    }

    var combinedHistory: [CombinedHistoryItem] {
        var items: [CombinedHistoryItem] = []
        for entry in workoutHistory {
            items.append(CombinedHistoryItem(id: entry.id, name: entry.name, date: entry.date, durationMinutes: entry.durationMinutes, totalVolume: entry.totalVolume, sportSession: nil, exercises: entry.exercises))
        }
        for session in sportSessions {
            items.append(CombinedHistoryItem(id: session.id, name: session.displayName, date: session.date, durationMinutes: session.durationMinutes, totalVolume: 0, sportSession: session, exercises: []))
        }
        return items.sorted { $0.date > $1.date }
    }

    var todayDayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date())
    }

    var todayWorkoutDay: ProgramDay? {
        todayWorkoutDays.first
    }

    var todayWorkoutDays: [ProgramDay] {
        guard let program = activeProgram else { return [] }
        let weekday = currentMondayBasedWeekday()
        if program.days.contains(where: { $0.scheduledWeekday != nil }) {
            let matches = program.days.filter { $0.scheduledWeekday == weekday }
            return matches.sorted { ($0.timeOfDay?.sortOrder ?? 0) < ($1.timeOfDay?.sortOrder ?? 0) }
        }
        let startOffset = UserDefaults.standard.integer(forKey: Self.programStartDayKey)
        let adjusted = (weekday - startOffset + 7) % 7
        guard adjusted < program.days.count else { return [] }
        return [program.days[adjusted]]
    }

    var isRestDay: Bool {
        guard activeProgram != nil else { return false }
        return todayWorkoutDay == nil
    }

    private func currentMondayBasedWeekday() -> Int {
        let dayOfWeek = Calendar.current.component(.weekday, from: Date())
        return (dayOfWeek + 5) % 7
    }

    var todayScheduledDayName: String? {
        todayWorkoutDay?.name
    }

    var muscleRecoveryItems: [MuscleRecoveryItem] {
        let now = Date()
        var muscleLastWorked: [MuscleGroup: Date] = [:]

        for entry in workoutHistory {
            for exercise in entry.exercises {
                if let ex = ExerciseLibrary.all.first(where: { $0.name == exercise.exerciseName }) {
                    if let existing = muscleLastWorked[ex.primaryMuscle] {
                        if entry.date > existing {
                            muscleLastWorked[ex.primaryMuscle] = entry.date
                        }
                    } else {
                        muscleLastWorked[ex.primaryMuscle] = entry.date
                    }
                }
            }
        }

        let tracked: [MuscleGroup] = [.chest, .back, .shoulders, .quadriceps, .hamstrings, .biceps, .triceps, .glutes]
        return tracked.map { muscle in
            let lastDate = muscleLastWorked[muscle]
            let hoursSince = lastDate.map { Int(now.timeIntervalSince($0) / 3600) } ?? 999
            let status: MuscleRecoveryStatus
            let hoursRemaining: Int
            if hoursSince >= 72 {
                status = .recovered
                hoursRemaining = 0
            } else if hoursSince >= 48 {
                status = .recovering
                hoursRemaining = 72 - hoursSince
            } else {
                status = .fatigued
                hoursRemaining = 48 - hoursSince
            }
            return MuscleRecoveryItem(muscle: muscle, status: status, lastWorked: lastDate, hoursRemaining: hoursRemaining)
        }.sorted { a, b in
            let order: [MuscleRecoveryStatus] = [.recovered, .recovering, .fatigued]
            let ai = order.firstIndex(of: a.status) ?? 0
            let bi = order.firstIndex(of: b.status) ?? 0
            return ai < bi
        }
    }

    var weeklyMuscleVolumes: [WeeklyMuscleVolume] {
        let now = Date()
        let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        var muscleSets: [MuscleGroup: Int] = [:]

        let thisWeek = workoutHistory.filter { $0.date >= weekStart }
        for entry in thisWeek {
            for exercise in entry.exercises {
                if let ex = ExerciseLibrary.all.first(where: { $0.name == exercise.exerciseName }) {
                    muscleSets[ex.primaryMuscle, default: 0] += exercise.sets.count
                }
            }
        }

        let targets: [MuscleGroup: Int] = [
            .chest: 16, .back: 18, .shoulders: 14, .quadriceps: 16,
            .hamstrings: 12, .biceps: 10, .triceps: 10, .glutes: 12
        ]

        return targets.map { muscle, target in
            WeeklyMuscleVolume(muscle: muscle, setsCompleted: muscleSets[muscle] ?? 0, targetSets: target)
        }.sorted { $0.muscle.rawValue < $1.muscle.rawValue }
    }

    var weeklyInsight: TrainingInsight {
        let now = Date()
        let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let thisWeek = workoutHistory.filter { $0.date >= weekStart }
        let sessions = thisWeek.count + sportSessions.filter { $0.date >= weekStart }.count
        let vol = thisWeek.reduce(0) { $0 + $1.totalVolume }
        let dur = thisWeek.isEmpty ? 0 : thisWeek.reduce(0) { $0 + $1.durationMinutes } / max(thisWeek.count, 1)
        let cal_burn = thisWeek.reduce(0) { $0 + $1.caloriesBurned }
        let sportCalBurn = sportSessions.filter { $0.date >= weekStart }.reduce(0) { acc, session in
            let weightKg = latestWeightKg()
            return acc + METCalculator.caloriesBurned(
                sport: session.sport.rawValue,
                workoutType: "sport",
                durationMinutes: session.durationMinutes,
                weightKg: weightKg,
                intensity: session.intensity
            )
        }
        return TrainingInsight(totalSessions: sessions, totalVolume: vol, avgDuration: dur, totalCaloriesBurned: cal_burn + sportCalBurn)
    }

    var warmupExercises: [WarmupExercise] {
        guard let day = todayWorkoutDay else {
            return defaultWarmup
        }
        let muscles = Set(day.exercises.map(\.primaryMuscle))
        var warmups: [WarmupExercise] = []

        if muscles.contains(.chest) || muscles.contains(.shoulders) || muscles.contains(.triceps) {
            warmups.append(contentsOf: [
                WarmupExercise(name: "Arm Circles", icon: "figure.arms.open", durationOrReps: "20 each", type: .dynamic),
                WarmupExercise(name: "Band Pull-Aparts", icon: "circle.dotted", durationOrReps: "15 reps", type: .activation),
                WarmupExercise(name: "Shoulder Dislocates", icon: "figure.flexibility", durationOrReps: "10 reps", type: .mobility),
            ])
        }
        if muscles.contains(.back) || muscles.contains(.biceps) {
            warmups.append(contentsOf: [
                WarmupExercise(name: "Cat-Cow Stretch", icon: "figure.flexibility", durationOrReps: "30 sec", type: .mobility),
                WarmupExercise(name: "Scapular Push-ups", icon: "figure.strengthtraining.traditional", durationOrReps: "12 reps", type: .activation),
            ])
        }
        if muscles.contains(.quadriceps) || muscles.contains(.hamstrings) || muscles.contains(.glutes) {
            warmups.append(contentsOf: [
                WarmupExercise(name: "Leg Swings", icon: "figure.walk", durationOrReps: "15 each", type: .dynamic),
                WarmupExercise(name: "Glute Bridges", icon: "figure.pilates", durationOrReps: "15 reps", type: .activation),
                WarmupExercise(name: "Hip 90/90 Stretch", icon: "figure.flexibility", durationOrReps: "30 sec", type: .mobility),
            ])
        }
        if warmups.isEmpty {
            return defaultWarmup
        }
        return warmups
    }

    private var defaultWarmup: [WarmupExercise] {
        [
            WarmupExercise(name: "Jumping Jacks", icon: "figure.jumprope", durationOrReps: "30 sec", type: .dynamic),
            WarmupExercise(name: "Arm Circles", icon: "figure.arms.open", durationOrReps: "20 each", type: .dynamic),
            WarmupExercise(name: "Bodyweight Squats", icon: "figure.step.training", durationOrReps: "15 reps", type: .activation),
        ]
    }

    // MARK: - Data Loading

    init() {
        NotificationCenter.default.addObserver(
            forName: .workoutCompletedForProgression,
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in
                self?.handleWorkoutCompleted(note: note)
            }
        }
        authObserver = NotificationCenter.default.addObserver(
            forName: .authUserChanged,
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in
                let newUserId = note.userInfo?["userId"] as? String
                self?.handleAuthUserChanged(newUserId: newUserId)
            }
        }
    }

    private func handleAuthUserChanged(newUserId: String?) {
        if newUserId == nil {
            // Signed out — wipe all local program state so the next account starts clean.
            loadProgramsTask?.cancel()
            loadProgramsTask = nil
            savedPrograms = []
            activeProgram = nil
            programSupabaseIds = [:]
            programsLoadedFromSupabase = false
            loadedForUserId = nil
            UserDefaults.standard.removeObject(forKey: Self.programKey)
            UserDefaults.standard.removeObject(forKey: Self.allProgramsKey)
            UserDefaults.standard.removeObject(forKey: Self.programStartDayKey)
            return
        }
        if newUserId != loadedForUserId {
            // First-ever sign-in for this VM: a load is likely already in-flight
            // (kicked off by onAppear → loadAllData while auth was resolving).
            // Don't wipe + restart — let the in-flight fetch populate state, otherwise
            // we'll race two concurrent fetches and re-persist the same program
            // as a brand new row on every launch.
            if loadedForUserId == nil && (loadProgramsTask != nil || programsLoadedFromSupabase) {
                return
            }
            // True user switch — clear cached state and re-fetch from Supabase.
            loadProgramsTask?.cancel()
            loadProgramsTask = nil
            savedPrograms = []
            activeProgram = nil
            programSupabaseIds = [:]
            programsLoadedFromSupabase = false
            UserDefaults.standard.removeObject(forKey: Self.programKey)
            UserDefaults.standard.removeObject(forKey: Self.allProgramsKey)
            UserDefaults.standard.removeObject(forKey: Self.programStartDayKey)
            loadProgramsFromSupabase()
        }
    }

    private func handleWorkoutCompleted(note: Notification) {
        guard let info = note.userInfo,
              let programId = info["programId"] as? UUID,
              let dayId = info["dayId"] as? UUID,
              let results = info["results"] as? [[String: Any]],
              let pIdx = savedPrograms.firstIndex(where: { $0.id == programId }),
              let dIdx = savedPrograms[pIdx].days.firstIndex(where: { $0.id == dayId }) else { return }

        var program = savedPrograms[pIdx]
        var notices: [ProgressionNotice] = []

        for (exIdx, pe) in program.days[dIdx].exercises.enumerated() {
            guard let result = results.first(where: { ($0["exerciseId"] as? String) == pe.exerciseId }),
                  let weight = result["weight"] as? Double,
                  let reps = result["reps"] as? Int,
                  let hitAll = result["allSetsCompleted"] as? Bool,
                  weight > 0, reps > 0 else { continue }
            guard let scheme = pe.progressionScheme, scheme != .none else { continue }
            let increment = pe.progressionIncrement ?? 5
            let suggestion = ProgressionEngine.suggestNext(
                scheme: scheme,
                lastWeight: weight,
                lastReps: reps,
                targetRepsLow: pe.targetRepsMin,
                targetRepsHigh: pe.targetRepsMax,
                incrementLbs: increment,
                hitAllSets: hitAll,
                lastRPE: nil,
                targetRPE: pe.progressionTargetRPE ?? 8
            )
            let delta = suggestion.suggestedWeight - weight
            program.days[dIdx].exercises[exIdx].prescribedWeight = suggestion.suggestedWeight
            notices.append(ProgressionNotice(
                exerciseName: pe.exerciseName,
                previousWeight: weight,
                nextWeight: suggestion.suggestedWeight,
                delta: delta,
                note: suggestion.note
            ))
        }

        guard !notices.isEmpty else { return }
        savedPrograms[pIdx] = program
        if activeProgram?.id == program.id {
            activeProgram = program
            saveProgram()
        }
        saveAllPrograms()
        persistProgramToSupabase(program)
        progressionNotices = notices
    }

    func loadAllData() {
        loadSavedModes()
        loadSavedProgram()
        loadDataFromSupabase()
        loadProgramsFromSupabase()
    }

    func loadProgramsFromSupabase() {
        // Coalesce concurrent calls — onAppear and the auth listener both invoke this.
        // Without this guard, two fetches race and the second sees the first's freshly
        // loaded program as "unsynced" (UUIDs are regenerated on each fetch), so it
        // re-persists it as a brand-new row in Supabase on every launch.
        if loadProgramsTask != nil { return }
        if programsLoadedFromSupabase { return }
        programsLoadedFromSupabase = true
        let task = Task { [weak self] in
            await self?.runLoadProgramsFromSupabase()
            await MainActor.run { self?.loadProgramsTask = nil }
        }
        loadProgramsTask = task
    }

    private func runLoadProgramsFromSupabase() async {
        var attempts = 0
        while AuthService.shared.authState == .loading && attempts < 40 {
            try? await Task.sleep(for: .milliseconds(250))
            attempts += 1
        }
        guard AuthService.shared.authState == .signedIn else {
            programsLoadedFromSupabase = false
            return
        }
        let currentUid = (try? AuthService.shared.currentUserId()) ?? ""
        // If local cache belongs to a different user, drop it before fetching.
        if let prior = loadedForUserId, prior != currentUid {
            savedPrograms = []
            activeProgram = nil
            programSupabaseIds = [:]
            UserDefaults.standard.removeObject(forKey: Self.programKey)
            UserDefaults.standard.removeObject(forKey: Self.allProgramsKey)
        }
        do {
            let results = try await TrainingProgramService.shared.fetchPrograms()
            var idMap: [UUID: String] = [:]
            var programs: [TrainingProgram] = []
            var activeStartOffset: Int? = nil
            for entry in results {
                idMap[entry.program.id] = entry.supabaseId
                programs.append(entry.program)
                if entry.program.isActive {
                    activeStartOffset = entry.startDayOffset
                }
            }
            // Only preserve local programs we KNOW failed to sync (pendingSyncProgramIds).
            // Previously we kept anything missing from the fetch, but fetchPrograms
            // assigns fresh UUIDs to every row, so legitimately-synced programs would be
            // mis-classified as unsynced and re-persisted as duplicates on every launch.
            let priorLocal = savedPrograms
            let remoteIds = Set(programs.map(\.id))
            let unsynced = priorLocal.filter {
                pendingSyncProgramIds.contains($0.id) && !remoteIds.contains($0.id)
            }
            if !unsynced.isEmpty {
                print("[TrainVM] Preserving \(unsynced.count) unsynced local program(s) after fetch")
            }
            savedPrograms = programs + unsynced
            programSupabaseIds = idMap
            activeProgram = savedPrograms.first { $0.isActive }
            loadedForUserId = currentUid
            // Retry persistence only for programs we actually failed to sync earlier.
            let toRetry = savedPrograms.filter { pendingSyncProgramIds.contains($0.id) }
            for prog in toRetry {
                persistProgramToSupabase(prog)
            }
            if let offset = activeStartOffset {
                UserDefaults.standard.set(offset, forKey: Self.programStartDayKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.programStartDayKey)
            }
            if let data = try? JSONEncoder().encode(savedPrograms) {
                UserDefaults.standard.set(data, forKey: Self.allProgramsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.allProgramsKey)
            }
            if let program = activeProgram, let data = try? JSONEncoder().encode(program) {
                UserDefaults.standard.set(data, forKey: Self.programKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.programKey)
            }
            stampCacheUserId()
            NotificationCenter.default.post(name: .activeProgramsChanged, object: nil)
        } catch {
            print("[TrainVM] Failed to load programs from Supabase: \(error)")
            programsLoadedFromSupabase = false
            DebugBanner.shared.log(.error, "Program load failed", "\(error.localizedDescription)\n\nRaw: \(error)")
        }
    }

    private func persistProgramToSupabase(_ program: TrainingProgram, startDayOffset: Int? = nil) {
        let offset = startDayOffset ?? UserDefaults.standard.integer(forKey: Self.programStartDayKey)
        Task {
            var attempts = 0
            while AuthService.shared.authState == .loading && attempts < 40 {
                try? await Task.sleep(for: .milliseconds(250))
                attempts += 1
            }
            guard AuthService.shared.authState == .signedIn else {
                print("[TrainVM] Skipping program persist — not signed in (state=\(AuthService.shared.authState))")
                await MainActor.run {
                    DebugBanner.shared.log(.error, "Program not saved", "You must be signed in to sync programs to Supabase.")
                }
                return
            }
            // Mark as pending until we confirm a successful round-trip.
            pendingSyncProgramIds.insert(program.id)
            do {
                if let sid = programSupabaseIds[program.id] {
                    try await TrainingProgramService.shared.updateProgram(id: sid, program: program, startDayOffset: offset)
                    if program.isActive {
                        try? await TrainingProgramService.shared.deactivateAll(exceptId: sid)
                    }
                    pendingSyncProgramIds.remove(program.id)
                    print("[TrainVM] Updated program '\(program.name)' in Supabase: \(sid)")
                    await MainActor.run {
                        DebugBanner.shared.log(.success, "Program synced", "Updated '\(program.name)' in Supabase.")
                    }
                } else {
                    let sid = try await TrainingProgramService.shared.createProgram(program, startDayOffset: offset)
                    programSupabaseIds[program.id] = sid
                    if program.isActive {
                        try? await TrainingProgramService.shared.deactivateAll(exceptId: sid)
                    }
                    pendingSyncProgramIds.remove(program.id)
                    print("[TrainVM] Created program '\(program.name)' in Supabase: \(sid)")
                    await MainActor.run {
                        DebugBanner.shared.log(.success, "Program saved", "Created '\(program.name)' in Supabase (id: \(sid.prefix(8))…).")
                    }
                }
            } catch {
                // Keep marked as pending so a later launch / refresh retries.
                print("[TrainVM] Failed to persist program '\(program.name)': \(error) — will retry on next launch")
                await MainActor.run {
                    DebugBanner.shared.log(.error, "Program save failed", "\(error.localizedDescription)\n\nWill retry automatically.")
                }
            }
        }
    }

    private func deleteProgramFromSupabase(_ programId: UUID) {
        guard let sid = programSupabaseIds[programId] else { return }
        programSupabaseIds.removeValue(forKey: programId)
        Task {
            try? await TrainingProgramService.shared.deleteProgram(id: sid)
        }
    }

    func loadDataFromSupabase(force: Bool = false) {
        guard AuthService.shared.authState == .signedIn else {
            print("[TrainVM] loadDataFromSupabase skipped — user not signed in")
            return
        }
        if !force && dataLoaded { return }
        dataLoaded = true
        Task {
            do {
                let userId = try AuthService.shared.currentUserId()
                let workouts = try await WorkoutService.shared.fetchWorkouts(userId: userId)

                var history: [WorkoutHistoryDetail] = []
                var sports: [SportSession] = []

                for workout in workouts {
                    if let session = WorkoutService.shared.toSportSession(workout) {
                        sports.append(session)
                    } else {
                        let detail = WorkoutService.shared.toWorkoutHistoryDetail(workout)
                        history.append(detail)
                    }
                }

                workoutHistory = history
                sportSessions = sports
                computePersonalRecords()
                print("[TrainVM] Loaded \(history.count) workouts and \(sports.count) sport sessions from Supabase")
            } catch {
                print("[TrainVM] ERROR loading workouts from Supabase: \(error.localizedDescription) — \(error)")
            }
        }
    }

    private func computePersonalRecords() {
        var bestByExercise: [String: (weight: Double, reps: Int, date: Date)] = [:]

        for entry in workoutHistory {
            for exercise in entry.exercises {
                for set in exercise.sets where set.weight > 0 {
                    let key = exercise.exerciseName
                    if let existing = bestByExercise[key] {
                        if set.weight > existing.weight {
                            bestByExercise[key] = (set.weight, set.reps, entry.date)
                        }
                    } else {
                        bestByExercise[key] = (set.weight, set.reps, entry.date)
                    }
                }
            }
        }

        personalRecords = bestByExercise.map { name, record in
            TrainPersonalRecord(
                exerciseName: name,
                weight: record.weight,
                reps: record.reps,
                dateAchieved: record.date,
                isNew: Calendar.current.dateComponents([.day], from: record.date, to: Date()).day ?? 999 <= 7,
                previousBest: nil
            )
        }.sorted { $0.dateAchieved > $1.dateAchieved }
    }

    func saveWorkoutToSupabase(name: String, type: String?, durationMinutes: Int?, caloriesBurned: Int?, notes: String?) {
        guard AuthService.shared.authState == .signedIn else { return }
        Task {
            do {
                let userId = try AuthService.shared.currentUserId()
                let created = try await WorkoutService.shared.createWorkout(
                    userId: userId, name: name, workoutType: type,
                    durationMinutes: durationMinutes, caloriesBurned: caloriesBurned, notes: notes
                )
                print("[TrainVM] Workout saved to Supabase: \(created.id ?? "nil")")
                loadDataFromSupabase(force: true)
            } catch {
                print("[TrainVM] ERROR saving workout: \(error.localizedDescription) — \(error)")
            }
        }
    }

    func saveWorkoutWithDetailsToSupabase(
        name: String,
        type: String?,
        durationMinutes: Int?,
        caloriesBurned: Int?,
        totalVolume: Int,
        fpEarned: Int = 0,
        exercises: [WorkoutHistoryExerciseDetail]
    ) {
        guard AuthService.shared.authState == .signedIn else { return }
        Task {
            do {
                let userId = try AuthService.shared.currentUserId()
                let created = try await WorkoutService.shared.createWorkoutWithDetails(
                    userId: userId,
                    name: name,
                    type: type,
                    durationMinutes: durationMinutes,
                    caloriesBurned: caloriesBurned,
                    totalVolume: totalVolume,
                    exercises: exercises
                )
                print("[TrainVM] Workout with details saved to Supabase: \(created.id ?? "nil") — \(exercises.count) exercises")
                loadDataFromSupabase(force: true)
            } catch {
                print("[TrainVM] ERROR saving workout details: \(error.localizedDescription) — \(error)")
            }
        }
    }

    func addWorkoutToHistory(_ detail: WorkoutHistoryDetail) {
        workoutHistory.insert(detail, at: 0)
        computePersonalRecords()
        Task { @MainActor in _ = await CorrelationEngine.shared.run() }
    }

    func addSportSession(_ session: SportSession) {
        sportSessions.insert(session, at: 0)
        BasketballViewModel.shared.ingestSportSession(session)
        guard AuthService.shared.authState == .signedIn else {
            NotificationCenter.default.post(name: .supabaseDataChanged, object: nil, userInfo: ["source": "sportSession"])
            StreakManager.shared.logActivity(type: .sportSession, sport: session.sport, durationMinutes: session.durationMinutes)
            return
        }
        let weightKg = latestWeightKg()
        let calories = METCalculator.caloriesBurned(
            sport: session.sport.rawValue,
            workoutType: "sport",
            durationMinutes: session.durationMinutes,
            weightKg: weightKg,
            intensity: session.intensity
        )
        Task {
            do {
                let userId = try AuthService.shared.currentUserId()
                let created = try await WorkoutService.shared.createSportSession(userId: userId, session: session)
                try await ActivityLogService.shared.logActivity(
                    userId: userId,
                    activityType: "sportSession",
                    sport: session.sport.rawValue,
                    durationMinutes: session.durationMinutes,
                    caloriesBurned: calories,
                    metValue: nil
                )
                print("[TrainVM] Sport session saved to Supabase: \(created.id ?? "nil")")
                NotificationCenter.default.post(name: .supabaseDataChanged, object: nil, userInfo: ["source": "sportSession"])
                loadDataFromSupabase(force: true)
            } catch {
                print("[TrainVM] ERROR saving sport session: \(error.localizedDescription) — \(error)")
            }
        }
        StreakManager.shared.logActivity(type: .sportSession, sport: session.sport, durationMinutes: session.durationMinutes)
    }

    private func latestWeightKg() -> Double {
        let cached = UserDefaults.standard.double(forKey: "cachedWeightLbs")
        let lbs = cached > 0 ? cached : 175.0
        return lbs * 0.453592
    }

    // MARK: - Program Builder

    func resetBuilder() {
        programName = ""
        programType = .recurringSplit
        daysPerWeek = 4
        programDays = []
        currentBuilderStep = 0
        editingDayIndex = nil
    }

    func initializeDays() {
        let dayNames = ["Day 1", "Day 2", "Day 3", "Day 4", "Day 5", "Day 6", "Day 7"]
        let defaultWeekdays: [Int] = defaultWeekdayAssignments(for: daysPerWeek)
        if programDays.count == daysPerWeek {
            for i in 0..<daysPerWeek where programDays[i].scheduledWeekday == nil {
                programDays[i].scheduledWeekday = defaultWeekdays[i]
            }
            return
        }
        programDays = (0..<daysPerWeek).map { i in
            ProgramDay(name: dayNames[i], scheduledWeekday: defaultWeekdays[i])
        }
    }

    private func defaultWeekdayAssignments(for count: Int) -> [Int] {
        switch count {
        case 2: return [0, 3]
        case 3: return [0, 2, 4]
        case 4: return [0, 1, 3, 4]
        case 5: return [0, 1, 2, 3, 4]
        case 6: return [0, 1, 2, 3, 4, 5]
        case 7: return [0, 1, 2, 3, 4, 5, 6]
        default: return Array(0..<min(count, 7))
        }
    }

    func addExercisesToDay(at index: Int, exercises: [Exercise]) {
        for exercise in exercises {
            let programExercise = ProgramExercise(exercise: exercise)
            programDays[index].exercises.append(programExercise)
        }
    }

    func removeExercise(from dayIndex: Int, at offsets: IndexSet) {
        programDays[dayIndex].exercises.remove(atOffsets: offsets)
    }

    func moveExercise(in dayIndex: Int, from source: IndexSet, to destination: Int) {
        programDays[dayIndex].exercises.move(fromOffsets: source, toOffset: destination)
    }

    func createProgram() {
        let program = TrainingProgram(
            name: programName,
            type: programType,
            daysPerWeek: daysPerWeek,
            days: programDays,
            isActive: true
        )
        if !multiActiveEnabled {
            deactivateOtherPrograms(except: program.id)
        }
        activeProgram = program
        saveProgram()
        persistProgramToSupabase(program)
    }

    func activateTemplateProgram(_ program: TrainingProgram, startDayOffset: Int) {
        if !multiActiveEnabled {
            deactivateOtherPrograms(except: program.id)
        }
        activeProgram = program
        UserDefaults.standard.set(startDayOffset, forKey: Self.programStartDayKey)
        saveProgram()
        persistProgramToSupabase(program, startDayOffset: startDayOffset)
    }

    private func deactivateOtherPrograms(except keepId: UUID) {
        for i in savedPrograms.indices where savedPrograms[i].id != keepId && savedPrograms[i].isActive {
            savedPrograms[i].isActive = false
            persistProgramToSupabase(savedPrograms[i])
        }
        if var old = activeProgram, old.id != keepId, old.isActive {
            old.isActive = false
            persistProgramToSupabase(old)
        }
    }

    var canProceedFromSetup: Bool {
        !programName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var canProceedFromSchedule: Bool {
        let hasContent = programDays.allSatisfy { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty && !$0.exercises.isEmpty }
        let allAssigned = programDays.allSatisfy { $0.scheduledWeekday != nil }
        let grouped = Dictionary(grouping: programDays, by: { $0.scheduledWeekday ?? -1 })
        let timesDistinct = grouped.allSatisfy { _, days in
            guard days.count > 1 else { return true }
            let times = days.compactMap { $0.timeOfDay }
            return times.count == days.count && Set(times).count == days.count
        }
        return hasContent && allAssigned && timesDistinct
    }

    func setWeekday(_ weekday: Int, forDayAt index: Int) {
        guard index < programDays.count else { return }
        programDays[index].scheduledWeekday = weekday
        ensureTimeOfDayAssignments(forWeekday: weekday)
    }

    func setTimeOfDay(_ time: ProgramTimeOfDay?, forDayAt index: Int) {
        guard index < programDays.count else { return }
        programDays[index].timeOfDay = time
    }

    private func ensureTimeOfDayAssignments(forWeekday weekday: Int) {
        let indices = programDays.indices.filter { programDays[$0].scheduledWeekday == weekday }
        if indices.count <= 1 {
            if let only = indices.first {
                programDays[only].timeOfDay = nil
            }
            return
        }
        var used: Set<ProgramTimeOfDay> = []
        for i in indices {
            if let t = programDays[i].timeOfDay, !used.contains(t) {
                used.insert(t)
            } else {
                programDays[i].timeOfDay = nil
            }
        }
        let available = ProgramTimeOfDay.allCases.filter { !used.contains($0) }
        var pool = available
        for i in indices where programDays[i].timeOfDay == nil {
            if let next = pool.first {
                programDays[i].timeOfDay = next
                pool.removeFirst()
            }
        }
    }

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

    func formattedVolume(_ volume: Int) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk lbs", Double(volume) / 1000.0)
        }
        return "\(volume) lbs"
    }

    var sportAnalytics: [SportAnalyticsData] {
        let grouped = Dictionary(grouping: sportSessions, by: \.sport)
        return grouped.map { sport, sessions in
            let totalMinutes = sessions.reduce(0) { $0 + $1.durationMinutes }
            let avgIntensity = sessions.isEmpty ? 0 : Double(sessions.reduce(0) { $0 + $1.intensity }) / Double(sessions.count)
            return SportAnalyticsData(sport: sport, sessionCount: sessions.count, totalMinutes: totalMinutes, averageIntensity: avgIntensity)
        }.sorted { $0.sessionCount > $1.sessionCount }
    }

    var consistencyProgress: Double {
        guard weeklyWorkoutGoal > 0 else { return 0 }
        return min(Double(workoutsCompletedThisWeek) / Double(weeklyWorkoutGoal), 1.0)
    }

    func sessionsForSport(_ sport: Sport) -> [SportSession] {
        sportSessions.filter { $0.sport == sport }
    }

    func recentSessionsForSport(_ sport: Sport, limit: Int = 5) -> [SportSession] {
        Array(sessionsForSport(sport).sorted { $0.date > $1.date }.prefix(limit))
    }

    func sportTotalTime(_ sport: Sport) -> Int {
        sessionsForSport(sport).reduce(0) { $0 + $1.durationMinutes }
    }

    func sportAvgIntensity(_ sport: Sport) -> Double {
        let sessions = sessionsForSport(sport)
        guard !sessions.isEmpty else { return 0 }
        return Double(sessions.reduce(0) { $0 + $1.intensity }) / Double(sessions.count)
    }

    func sportThisWeek(_ sport: Sport) -> [SportSession] {
        let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return sessionsForSport(sport).filter { $0.date >= weekStart }
    }

    // MARK: - Modes

    func addMode(_ mode: TrainMode) {
        availableModes.append(mode)
        currentMode = mode
        saveModes()
    }

    func removeMode(_ mode: TrainMode) {
        guard mode.type != .main else { return }
        availableModes.removeAll { $0.id == mode.id }
        if currentMode.id == mode.id {
            currentMode = availableModes.first ?? TrainMode(type: .main)
        }
        saveModes()
    }

    func switchMode(_ mode: TrainMode) {
        currentMode = mode
        UserDefaults.standard.set(mode.id.uuidString, forKey: Self.lastModeKey)
    }

    func loadSavedModes() {
        guard let data = UserDefaults.standard.data(forKey: Self.modesKey),
              let decoded = try? JSONDecoder().decode([TrainMode].self, from: data) else { return }
        let hasMain = decoded.contains { $0.type == .main }
        availableModes = hasMain ? decoded : [TrainMode(type: .main)] + decoded
        if let lastId = UserDefaults.standard.string(forKey: Self.lastModeKey),
           let lastUUID = UUID(uuidString: lastId),
           let saved = availableModes.first(where: { $0.id == lastUUID }) {
            currentMode = saved
        } else {
            currentMode = availableModes.first ?? TrainMode(type: .main)
        }
    }

    private func saveModes() {
        if let data = try? JSONEncoder().encode(availableModes) {
            UserDefaults.standard.set(data, forKey: Self.modesKey)
        }
        UserDefaults.standard.set(currentMode.id.uuidString, forKey: Self.lastModeKey)
    }

    // MARK: - Program Persistence

    private func stampCacheUserId() {
        if let uid = try? AuthService.shared.currentUserId() {
            UserDefaults.standard.set(uid, forKey: "trainVM.cacheUserId")
        }
    }

    private func saveProgram() {
        guard let program = activeProgram else {
            UserDefaults.standard.removeObject(forKey: Self.programKey)
            return
        }
        if let data = try? JSONEncoder().encode(program) {
            UserDefaults.standard.set(data, forKey: Self.programKey)
        }
        stampCacheUserId()
        syncActiveProgramToList()
    }

    private func saveAllPrograms() {
        if let data = try? JSONEncoder().encode(savedPrograms) {
            UserDefaults.standard.set(data, forKey: Self.allProgramsKey)
        }
        stampCacheUserId()
    }

    private func syncActiveProgramToList() {
        guard let program = activeProgram else { return }
        if let idx = savedPrograms.firstIndex(where: { $0.id == program.id }) {
            savedPrograms[idx] = program
        } else {
            savedPrograms.append(program)
        }
        saveAllPrograms()
    }

    func loadSavedProgram() {
        // Only trust the local cache if it belongs to the currently-signed-in user.
        // Otherwise wait for Supabase to populate state to avoid leaking another account's programs.
        guard AuthService.shared.authState == .signedIn else {
            savedPrograms = []
            activeProgram = nil
            return
        }
        let currentUid = (try? AuthService.shared.currentUserId()) ?? ""
        // If we've already hydrated state for this user this session (either from cache or Supabase),
        // don't re-run — otherwise we may wipe a freshly-loaded activeProgram on subsequent onAppear calls.
        if loadedForUserId == currentUid && (activeProgram != nil || !savedPrograms.isEmpty) {
            return
        }
        let cachedUid = UserDefaults.standard.string(forKey: "trainVM.cacheUserId")
        guard cachedUid == currentUid else {
            // Cache belongs to a different user (or was never stamped). Don't wipe in-memory state
            // that may have already been populated from Supabase — just skip the cache read.
            if activeProgram == nil && savedPrograms.isEmpty {
                UserDefaults.standard.removeObject(forKey: Self.programKey)
                UserDefaults.standard.removeObject(forKey: Self.allProgramsKey)
            }
            return
        }
        if let data = UserDefaults.standard.data(forKey: Self.allProgramsKey),
           let programs = try? JSONDecoder().decode([TrainingProgram].self, from: data) {
            savedPrograms = programs
        }
        if let data = UserDefaults.standard.data(forKey: Self.programKey),
           let program = try? JSONDecoder().decode(TrainingProgram.self, from: data) {
            activeProgram = program
        }
        loadedForUserId = currentUid
    }

    func deleteProgram() {
        guard let program = activeProgram else { return }
        savedPrograms.removeAll { $0.id == program.id }
        deleteProgramFromSupabase(program.id)
        activeProgram = nil
        UserDefaults.standard.removeObject(forKey: Self.programKey)
        saveAllPrograms()
    }

    func deleteProgramById(_ id: UUID) {
        let wasActive = activeProgram?.id == id
        savedPrograms.removeAll { $0.id == id }
        deleteProgramFromSupabase(id)
        if wasActive {
            activeProgram = nil
            UserDefaults.standard.removeObject(forKey: Self.programKey)
        }
        saveAllPrograms()
    }

    func switchToProgram(_ program: TrainingProgram) {
        var updated = program
        updated.isActive = true
        if !multiActiveEnabled {
            deactivateOtherPrograms(except: program.id)
        }
        activeProgram = updated
        if let idx = savedPrograms.firstIndex(where: { $0.id == updated.id }) {
            savedPrograms[idx] = updated
        } else {
            savedPrograms.append(updated)
        }
        saveProgram()
        saveAllPrograms()
        persistProgramToSupabase(updated)
    }

    func setProgramActive(_ program: TrainingProgram, active: Bool) {
        guard let idx = savedPrograms.firstIndex(where: { $0.id == program.id }) else { return }
        if active && !multiActiveEnabled {
            deactivateOtherPrograms(except: program.id)
        }
        savedPrograms[idx].isActive = active
        let updated = savedPrograms[idx]
        if active {
            activeProgram = updated
            saveProgram()
        } else if activeProgram?.id == updated.id {
            activeProgram = activePrograms.first
            if let primary = activeProgram, let data = try? JSONEncoder().encode(primary) {
                UserDefaults.standard.set(data, forKey: Self.programKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.programKey)
            }
        }
        saveAllPrograms()
        persistProgramToSupabase(updated)
        NotificationCenter.default.post(name: .activeProgramsChanged, object: nil)
    }

    func setMultiActiveEnabled(_ enabled: Bool) {
        multiActiveEnabled = enabled
        if !enabled {
            // Collapse to a single active program — keep activeProgram, deactivate others.
            if let primary = activeProgram ?? activePrograms.first {
                deactivateOtherPrograms(except: primary.id)
                if let idx = savedPrograms.firstIndex(where: { $0.id == primary.id }) {
                    savedPrograms[idx].isActive = true
                    activeProgram = savedPrograms[idx]
                    persistProgramToSupabase(savedPrograms[idx])
                }
                saveProgram()
                saveAllPrograms()
            }
        }
        NotificationCenter.default.post(name: .activeProgramsChanged, object: nil)
    }

    func addProgramToLibrary(_ program: TrainingProgram) {
        var p = program
        p.isActive = false
        savedPrograms.append(p)
        saveAllPrograms()
        persistProgramToSupabase(p)
    }

    func duplicateProgram(_ program: TrainingProgram) {
        let copy = TrainingProgram(
            name: program.name + " (Copy)",
            type: program.type,
            daysPerWeek: program.daysPerWeek,
            days: program.days,
            isActive: false
        )
        savedPrograms.append(copy)
        saveAllPrograms()
        persistProgramToSupabase(copy)
    }

    func updateProgram(_ program: TrainingProgram) {
        if let idx = savedPrograms.firstIndex(where: { $0.id == program.id }) {
            savedPrograms[idx] = program
        }
        if activeProgram?.id == program.id {
            activeProgram = program
            saveProgram()
        }
        saveAllPrograms()
        persistProgramToSupabase(program)
    }

    func swapExerciseInProgram(programId: UUID, dayId: UUID, exerciseIndex: Int, newExercise: Exercise) {
        guard let pIdx = savedPrograms.firstIndex(where: { $0.id == programId }),
              let dIdx = savedPrograms[pIdx].days.firstIndex(where: { $0.id == dayId }),
              exerciseIndex < savedPrograms[pIdx].days[dIdx].exercises.count else { return }
        let old = savedPrograms[pIdx].days[dIdx].exercises[exerciseIndex]
        savedPrograms[pIdx].days[dIdx].exercises[exerciseIndex] = ProgramExercise(
            exercise: newExercise,
            targetSets: old.targetSets,
            targetRepsMin: old.targetRepsMin,
            targetRepsMax: old.targetRepsMax,
            restSeconds: old.restSeconds
        )
        if activeProgram?.id == programId {
            activeProgram = savedPrograms[pIdx]
            saveProgram()
        }
        saveAllPrograms()
        persistProgramToSupabase(savedPrograms[pIdx])
    }

    var inactivePrograms: [TrainingProgram] {
        savedPrograms.filter { $0.id != activeProgram?.id }
    }

    func progressiveOverloadTrend(for exerciseName: String) -> String {
        let matching = workoutHistory.flatMap { entry in
            entry.exercises.filter { $0.exerciseName == exerciseName }
        }
        guard matching.count >= 2 else { return "\u{2192}" }
        let recent = matching.first?.sets.map { $0.weight }.max() ?? 0
        let previous = matching.dropFirst().first?.sets.map { $0.weight }.max() ?? 0
        if recent > previous { return "\u{2191}" }
        if recent < previous { return "\u{2193}" }
        return "\u{2192}"
    }
}
