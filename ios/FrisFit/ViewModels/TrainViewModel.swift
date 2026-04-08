import SwiftUI

@Observable
final class TrainViewModel {
    var activeProgram: TrainingProgram? = nil
    var showProgramBuilder: Bool = false
    var showExerciseLibrary: Bool = false

    var currentMode: TrainMode = TrainMode(type: .main)
    var availableModes: [TrainMode] = [TrainMode(type: .main)]
    var showModeSelectorSheet: Bool = false
    var showCreateModeSheet: Bool = false

    private static let modesKey = "savedTrainModes"
    private static let lastModeKey = "lastActiveTrainModeId"
    private static let programKey = "savedActiveProgram"

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
            items.append(CombinedHistoryItem(id: entry.id, name: entry.name, date: entry.date, durationMinutes: entry.durationMinutes, fpEarned: entry.fpEarned, totalVolume: entry.totalVolume, sportSession: nil, exercises: entry.exercises))
        }
        for session in sportSessions {
            items.append(CombinedHistoryItem(id: session.id, name: session.displayName, date: session.date, durationMinutes: session.durationMinutes, fpEarned: session.fpEarned, totalVolume: 0, sportSession: session, exercises: []))
        }
        return items.sorted { $0.date > $1.date }
    }

    var todayDayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date())
    }

    var todayWorkoutDay: ProgramDay? {
        guard let program = activeProgram else { return nil }
        let dayOfWeek = Calendar.current.component(.weekday, from: Date())
        let dayIndex = (dayOfWeek + 5) % 7
        guard dayIndex < program.days.count else { return nil }
        return program.days[dayIndex]
    }

    var isRestDay: Bool {
        guard let program = activeProgram else { return false }
        let dayOfWeek = Calendar.current.component(.weekday, from: Date())
        let dayIndex = (dayOfWeek + 5) % 7
        return dayIndex >= program.days.count
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
        let fp = thisWeek.reduce(0) { $0 + $1.fpEarned } + sportSessions.filter { $0.date >= weekStart }.reduce(0) { $0 + $1.fpEarned }
        let cal_burn = thisWeek.reduce(0) { $0 + $1.durationMinutes * 8 }
        return TrainingInsight(totalSessions: sessions, totalVolume: vol, avgDuration: dur, totalFP: fp, totalCaloriesBurned: cal_burn)
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

    func loadAllData() {
        loadSavedModes()
        loadSavedProgram()
        loadDataFromSupabase()
    }

    func loadDataFromSupabase() {
        guard AuthService.shared.authState == .signedIn, !dataLoaded else { return }
        dataLoaded = true
        Task {
            do {
                let userId = try AuthService.shared.currentUserId()
                let workouts = try await WorkoutService.shared.fetchWorkouts(userId: userId)

                var history: [WorkoutHistoryDetail] = []
                var sports: [SportSession] = []

                for workout in workouts {
                    if let typeStr = workout.type, typeStr.hasPrefix("sport_") {
                        if let session = WorkoutService.shared.toSportSession(workout) {
                            sports.append(session)
                        }
                    } else {
                        let detail = WorkoutService.shared.toWorkoutHistoryDetail(workout)
                        history.append(detail)
                    }
                }

                workoutHistory = history
                sportSessions = sports
                computePersonalRecords()
            } catch {}
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
                _ = try await WorkoutService.shared.createWorkout(
                    userId: userId, name: name, type: type,
                    durationMinutes: durationMinutes, caloriesBurned: caloriesBurned, notes: notes
                )
            } catch {}
        }
    }

    func saveWorkoutWithDetailsToSupabase(
        name: String,
        type: String?,
        durationMinutes: Int?,
        caloriesBurned: Int?,
        totalVolume: Int,
        fpEarned: Int,
        exercises: [WorkoutHistoryExerciseDetail]
    ) {
        guard AuthService.shared.authState == .signedIn else { return }
        Task {
            do {
                let userId = try AuthService.shared.currentUserId()
                _ = try await WorkoutService.shared.createWorkoutWithDetails(
                    userId: userId,
                    name: name,
                    type: type,
                    durationMinutes: durationMinutes,
                    caloriesBurned: caloriesBurned,
                    totalVolume: totalVolume,
                    fpEarned: fpEarned,
                    exercises: exercises
                )
            } catch {}
        }
    }

    func addWorkoutToHistory(_ detail: WorkoutHistoryDetail) {
        workoutHistory.insert(detail, at: 0)
        computePersonalRecords()
    }

    func addSportSession(_ session: SportSession) {
        sportSessions.insert(session, at: 0)
        guard AuthService.shared.authState == .signedIn else { return }
        Task {
            do {
                let userId = try AuthService.shared.currentUserId()
                _ = try await WorkoutService.shared.createSportSession(userId: userId, session: session)
            } catch {}
        }
        StreakManager.shared.logActivity(type: .sportSession, sport: session.sport, durationMinutes: session.durationMinutes)
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
        programDays = (0..<daysPerWeek).map { i in
            ProgramDay(name: dayNames[i])
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
        activeProgram = program
        saveProgram()
    }

    var canProceedFromSetup: Bool {
        !programName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var canProceedFromSchedule: Bool {
        programDays.allSatisfy { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty && !$0.exercises.isEmpty }
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

    private func saveProgram() {
        guard let program = activeProgram else {
            UserDefaults.standard.removeObject(forKey: Self.programKey)
            return
        }
        if let data = try? JSONEncoder().encode(program) {
            UserDefaults.standard.set(data, forKey: Self.programKey)
        }
    }

    func loadSavedProgram() {
        guard let data = UserDefaults.standard.data(forKey: Self.programKey),
              let program = try? JSONDecoder().decode(TrainingProgram.self, from: data) else { return }
        activeProgram = program
    }

    func deleteProgram() {
        activeProgram = nil
        UserDefaults.standard.removeObject(forKey: Self.programKey)
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
