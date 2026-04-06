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

    var workoutHistory: [WorkoutHistoryDetail] = {
        let cal = Calendar.current
        let now = Date()
        return [
            WorkoutHistoryDetail(name: "Push Day — Chest Focus", date: cal.date(byAdding: .day, value: -1, to: now)!, durationMinutes: 58, totalVolume: 12450, fpEarned: 340, exercises: [
                WorkoutHistoryExerciseDetail(exerciseName: "Barbell Bench Press", sets: [
                    WorkoutHistorySetDetail(setNumber: 1, weight: 185, reps: 10),
                    WorkoutHistorySetDetail(setNumber: 2, weight: 205, reps: 8),
                    WorkoutHistorySetDetail(setNumber: 3, weight: 225, reps: 5),
                ]),
                WorkoutHistoryExerciseDetail(exerciseName: "Incline Dumbbell Press", sets: [
                    WorkoutHistorySetDetail(setNumber: 1, weight: 70, reps: 10),
                    WorkoutHistorySetDetail(setNumber: 2, weight: 75, reps: 8),
                    WorkoutHistorySetDetail(setNumber: 3, weight: 80, reps: 7),
                ]),
                WorkoutHistoryExerciseDetail(exerciseName: "Overhead Press", sets: [
                    WorkoutHistorySetDetail(setNumber: 1, weight: 115, reps: 10),
                    WorkoutHistorySetDetail(setNumber: 2, weight: 135, reps: 8),
                    WorkoutHistorySetDetail(setNumber: 3, weight: 155, reps: 5),
                ]),
                WorkoutHistoryExerciseDetail(exerciseName: "Cable Flyes", sets: [
                    WorkoutHistorySetDetail(setNumber: 1, weight: 30, reps: 12),
                    WorkoutHistorySetDetail(setNumber: 2, weight: 35, reps: 10),
                ]),
            ]),
            WorkoutHistoryDetail(name: "Pull Day — Back & Biceps", date: cal.date(byAdding: .day, value: -2, to: now)!, durationMinutes: 52, totalVolume: 10800, fpEarned: 310, exercises: [
                WorkoutHistoryExerciseDetail(exerciseName: "Barbell Row", sets: [
                    WorkoutHistorySetDetail(setNumber: 1, weight: 165, reps: 10),
                    WorkoutHistorySetDetail(setNumber: 2, weight: 185, reps: 8),
                    WorkoutHistorySetDetail(setNumber: 3, weight: 205, reps: 6),
                ]),
                WorkoutHistoryExerciseDetail(exerciseName: "Lat Pulldown", sets: [
                    WorkoutHistorySetDetail(setNumber: 1, weight: 130, reps: 12),
                    WorkoutHistorySetDetail(setNumber: 2, weight: 145, reps: 10),
                    WorkoutHistorySetDetail(setNumber: 3, weight: 160, reps: 8),
                ]),
                WorkoutHistoryExerciseDetail(exerciseName: "Dumbbell Curl", sets: [
                    WorkoutHistorySetDetail(setNumber: 1, weight: 35, reps: 12),
                    WorkoutHistorySetDetail(setNumber: 2, weight: 40, reps: 10),
                ]),
            ]),
            WorkoutHistoryDetail(name: "Leg Day Destroyer", date: cal.date(byAdding: .day, value: -4, to: now)!, durationMinutes: 65, totalVolume: 18200, fpEarned: 380, exercises: [
                WorkoutHistoryExerciseDetail(exerciseName: "Barbell Back Squat", sets: [
                    WorkoutHistorySetDetail(setNumber: 1, weight: 225, reps: 10),
                    WorkoutHistorySetDetail(setNumber: 2, weight: 275, reps: 8),
                    WorkoutHistorySetDetail(setNumber: 3, weight: 315, reps: 5),
                ]),
                WorkoutHistoryExerciseDetail(exerciseName: "Romanian Deadlift", sets: [
                    WorkoutHistorySetDetail(setNumber: 1, weight: 185, reps: 10),
                    WorkoutHistorySetDetail(setNumber: 2, weight: 225, reps: 8),
                    WorkoutHistorySetDetail(setNumber: 3, weight: 245, reps: 6),
                ]),
                WorkoutHistoryExerciseDetail(exerciseName: "Leg Press", sets: [
                    WorkoutHistorySetDetail(setNumber: 1, weight: 360, reps: 12),
                    WorkoutHistorySetDetail(setNumber: 2, weight: 450, reps: 10),
                ]),
            ]),
            WorkoutHistoryDetail(name: "Push Day — Shoulders", date: cal.date(byAdding: .day, value: -6, to: now)!, durationMinutes: 48, totalVolume: 9600, fpEarned: 290, exercises: [
                WorkoutHistoryExerciseDetail(exerciseName: "Overhead Press", sets: [
                    WorkoutHistorySetDetail(setNumber: 1, weight: 115, reps: 10),
                    WorkoutHistorySetDetail(setNumber: 2, weight: 135, reps: 8),
                    WorkoutHistorySetDetail(setNumber: 3, weight: 145, reps: 5),
                ]),
                WorkoutHistoryExerciseDetail(exerciseName: "Dumbbell Bench Press", sets: [
                    WorkoutHistorySetDetail(setNumber: 1, weight: 75, reps: 10),
                    WorkoutHistorySetDetail(setNumber: 2, weight: 80, reps: 8),
                ]),
            ]),
            WorkoutHistoryDetail(name: "Pull Day — Heavy", date: cal.date(byAdding: .day, value: -8, to: now)!, durationMinutes: 55, totalVolume: 14200, fpEarned: 320, exercises: [
                WorkoutHistoryExerciseDetail(exerciseName: "Barbell Row", sets: [
                    WorkoutHistorySetDetail(setNumber: 1, weight: 175, reps: 8),
                    WorkoutHistorySetDetail(setNumber: 2, weight: 195, reps: 6),
                    WorkoutHistorySetDetail(setNumber: 3, weight: 215, reps: 5),
                ]),
            ]),
            WorkoutHistoryDetail(name: "Active Recovery", date: cal.date(byAdding: .day, value: -9, to: now)!, durationMinutes: 30, totalVolume: 0, fpEarned: 120, exercises: []),
        ]
    }()

    var sportSessions: [SportSession] = [
        SportSession(sport: .basketball, sessionType: .game, durationMinutes: 90, intensity: 8, date: Date().addingTimeInterval(-150000), specificStats: .basketball(BasketballStats(points: 18, assists: 5, rebounds: 7))),
        SportSession(sport: .running, sessionType: .training, durationMinutes: 35, intensity: 7, date: Date().addingTimeInterval(-350000), specificStats: .running(RunningStats(distanceMiles: 3.2, paceMinutesPerMile: 8.5))),
        SportSession(sport: .swimming, sessionType: .practice, durationMinutes: 45, intensity: 6, date: Date().addingTimeInterval(-500000), specificStats: .swimming(SwimmingStats(laps: 30, stroke: .freestyle))),
    ]

    var personalRecords: [TrainPersonalRecord] = {
        let cal = Calendar.current
        let now = Date()
        return [
            TrainPersonalRecord(exerciseName: "Barbell Bench Press", weight: 225, reps: 5, dateAchieved: cal.date(byAdding: .day, value: -1, to: now)!, isNew: true, previousBest: 215),
            TrainPersonalRecord(exerciseName: "Barbell Back Squat", weight: 315, reps: 5, dateAchieved: cal.date(byAdding: .day, value: -4, to: now)!, isNew: true, previousBest: 305),
            TrainPersonalRecord(exerciseName: "Barbell Row", weight: 215, reps: 5, dateAchieved: cal.date(byAdding: .day, value: -8, to: now)!, isNew: false, previousBest: 205),
            TrainPersonalRecord(exerciseName: "Overhead Press", weight: 155, reps: 5, dateAchieved: cal.date(byAdding: .day, value: -1, to: now)!, isNew: true, previousBest: 145),
        ]
    }()

    var weeklyWorkoutGoal: Int = 5
    var workoutsCompletedThisWeek: Int = 4

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
        let cal = Calendar.current
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
        let cal = Calendar.current
        let now = Date()
        let weekStart = cal.date(byAdding: .day, value: -7, to: now)!
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
        let cal = Calendar.current
        let now = Date()
        let weekStart = cal.date(byAdding: .day, value: -7, to: now)!
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

    func addSportSession(_ session: SportSession) {
        sportSessions.insert(session, at: 0)
    }

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

    func addMode(_ mode: TrainMode) {
        availableModes.append(mode)
        currentMode = mode
    }

    func removeMode(_ mode: TrainMode) {
        guard mode.type != .main else { return }
        availableModes.removeAll { $0.id == mode.id }
        if currentMode.id == mode.id {
            currentMode = availableModes.first ?? TrainMode(type: .main)
        }
    }

    func switchMode(_ mode: TrainMode) {
        currentMode = mode
    }

    func progressiveOverloadTrend(for exerciseName: String) -> String {
        let matching = workoutHistory.flatMap { entry in
            entry.exercises.filter { $0.exerciseName == exerciseName }
        }
        guard matching.count >= 2 else { return "→" }
        let recent = matching.first?.sets.map { $0.weight }.max() ?? 0
        let previous = matching.dropFirst().first?.sets.map { $0.weight }.max() ?? 0
        if recent > previous { return "↑" }
        if recent < previous { return "↓" }
        return "→"
    }
}
