import SwiftUI

@Observable
final class ActiveWorkoutViewModel {
    var workoutName: String
    var exercises: [WorkoutExercise]
    var currentExerciseIndex: Int = 0
    var elapsedSeconds: Int = 0
    var isWorkoutActive: Bool = true
    var isCompleted: Bool = false
    var summary: WorkoutSummary?

    var isRestTimerActive: Bool = false
    var restSecondsRemaining: Int = 0
    var restSecondsTotal: Int = 0

    var activeNumberInput: NumberInputField? = nil
    var numberInputValue: String = ""

    var showExerciseInfo: Bool = false
    var showExercisePicker: Bool = false

    private var elapsedTimer: Timer?
    private var restTimer: Timer?
    private let startDate = Date()

    init(name: String, exercises: [WorkoutExercise]) {
        self.workoutName = name
        self.exercises = exercises
    }

    var currentExercise: WorkoutExercise? {
        guard currentExerciseIndex < exercises.count else { return nil }
        return exercises[currentExerciseIndex]
    }

    var totalCompletedExercises: Int {
        exercises.filter(\.isCompleted).count
    }

    var formattedElapsedTime: String {
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        let seconds = elapsedSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var formattedRestTime: String {
        let minutes = restSecondsRemaining / 60
        let seconds = restSecondsRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    func startElapsedTimer() {
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            let vm = self
            Task { @MainActor in
                vm?.elapsedSeconds += 1
            }
        }
    }

    func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    func logSet(exerciseIndex: Int, setIndex: Int) {
        guard exerciseIndex < exercises.count,
              setIndex < exercises[exerciseIndex].sets.count else { return }

        var set = exercises[exerciseIndex].sets[setIndex]
        if set.weight == 0, let prev = set.previousWeight {
            set.weight = prev
        }
        if set.reps == 0, let prev = set.previousReps {
            set.reps = prev
        }
        if set.reps == 0 { set.reps = 10 }
        set.isCompleted = true
        exercises[exerciseIndex].sets[setIndex] = set

        let allDone = exercises[exerciseIndex].sets.allSatisfy(\.isCompleted)
        if allDone {
            exercises[exerciseIndex].isCompleted = true
            if currentExerciseIndex < exercises.count - 1 {
                startRestTimer(seconds: exercises[exerciseIndex].exercise.defaultRestSeconds)
            } else {
                finishWorkout()
            }
        } else {
            startRestTimer(seconds: exercises[exerciseIndex].exercise.defaultRestSeconds)
        }
    }

    func startRestTimer(seconds: Int) {
        restSecondsTotal = seconds
        restSecondsRemaining = seconds
        isRestTimerActive = true
        restTimer?.invalidate()
        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            let vm = self
            Task { @MainActor in
                guard let vm else { return }
                if vm.restSecondsRemaining > 0 {
                    vm.restSecondsRemaining -= 1
                } else {
                    vm.skipRestTimer()
                }
            }
        }
    }

    func skipRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
        isRestTimerActive = false

        if exercises[currentExerciseIndex].isCompleted && currentExerciseIndex < exercises.count - 1 {
            currentExerciseIndex += 1
        }
    }

    func addExtraSet(exerciseIndex: Int) {
        guard exerciseIndex < exercises.count else { return }
        let exercise = exercises[exerciseIndex]
        let prevWeight = exercise.sets.last?.previousWeight
        let prevReps = exercise.sets.last?.previousReps
        let newSet = WorkoutSet(previousWeight: prevWeight, previousReps: prevReps)
        exercises[exerciseIndex].sets.append(newSet)
    }

    func addExercises(_ newExercises: [Exercise]) {
        for exercise in newExercises {
            let workoutExercise = WorkoutExercise(
                exercise: exercise,
                targetSets: 3,
                previousWeight: nil,
                previousReps: nil
            )
            exercises.append(workoutExercise)
        }
    }

    func openNumberInput(field: NumberInputField) {
        activeNumberInput = field
        switch field {
        case .weight(let ei, let si):
            let w = exercises[ei].sets[si].weight
            numberInputValue = w > 0 ? formatWeight(w) : ""
        case .reps(let ei, let si):
            let r = exercises[ei].sets[si].reps
            numberInputValue = r > 0 ? "\(r)" : ""
        }
    }

    func applyNumberInput() {
        guard let field = activeNumberInput else { return }
        let value = Double(numberInputValue) ?? 0
        switch field {
        case .weight(let ei, let si):
            exercises[ei].sets[si].weight = value
        case .reps(let ei, let si):
            exercises[ei].sets[si].reps = Int(value)
        }
        activeNumberInput = nil
        numberInputValue = ""
    }

    func incrementInput(by amount: Double) {
        let current = Double(numberInputValue) ?? 0
        let newVal = max(0, current + amount)
        if let field = activeNumberInput {
            switch field {
            case .weight:
                numberInputValue = formatWeight(newVal)
            case .reps:
                numberInputValue = "\(Int(newVal))"
            }
        }
    }

    func finishWorkout() {
        stopElapsedTimer()
        restTimer?.invalidate()
        restTimer = nil
        isWorkoutActive = false

        let totalVolume = exercises.reduce(0.0) { $0 + $1.totalVolume }
        let totalSets = exercises.reduce(0) { $0 + $1.completedSets }
        let fp = calculateFP(totalSets: totalSets, totalVolume: totalVolume, duration: elapsedSeconds)

        let prs = generateMockPRs()

        summary = WorkoutSummary(
            workoutName: workoutName,
            duration: TimeInterval(elapsedSeconds),
            totalVolume: totalVolume,
            totalSets: totalSets,
            fpEarned: fp,
            personalRecords: prs
        )
        isCompleted = true
        saveToSupabase(durationMinutes: elapsedSeconds / 60, caloriesBurned: (elapsedSeconds / 60) * 8, totalVolume: Int(totalVolume), fpEarned: fp)
        StreakManager.shared.logActivity(type: .workout, durationMinutes: elapsedSeconds / 60)
    }

    var completedExerciseDetails: [WorkoutHistoryExerciseDetail] {
        exercises.filter { $0.completedSets > 0 }.enumerated().map { _, we in
            let completedSets = we.sets.filter { $0.isCompleted }
            return WorkoutHistoryExerciseDetail(
                exerciseName: we.exercise.name,
                sets: completedSets.enumerated().map { idx, s in
                    WorkoutHistorySetDetail(setNumber: idx + 1, weight: s.weight, reps: s.effectiveReps)
                }
            )
        }
    }

    private func saveToSupabase(durationMinutes: Int, caloriesBurned: Int, totalVolume: Int, fpEarned: Int) {
        guard AuthService.shared.authState == .signedIn else { return }
        let exerciseDetails = completedExerciseDetails
        Task {
            do {
                let userId = try AuthService.shared.currentUserId()
                _ = try await WorkoutService.shared.createWorkoutWithDetails(
                    userId: userId,
                    name: workoutName,
                    type: "strength",
                    durationMinutes: durationMinutes,
                    caloriesBurned: caloriesBurned,
                    totalVolume: totalVolume,
                    fpEarned: fpEarned,
                    exercises: exerciseDetails
                )
            } catch {
                print("[ActiveWorkout] Failed to save workout: \(error)")
            }
        }
    }

    private func calculateFP(totalSets: Int, totalVolume: Double, duration: Int) -> Int {
        let setPoints = totalSets * 15
        let volumePoints = Int(totalVolume / 100)
        let durationPoints = (duration / 60) * 2
        return setPoints + volumePoints + durationPoints
    }

    private func generateMockPRs() -> [PersonalRecord] {
        var prs: [PersonalRecord] = []
        for exercise in exercises where exercise.completedSets > 0 {
            if let bestSet = exercise.sets.filter({ $0.isCompleted }).max(by: { $0.weight < $1.weight }) {
                if bestSet.weight >= 100 {
                    prs.append(PersonalRecord(
                        exerciseName: exercise.exercise.name,
                        recordType: "Weight PR",
                        value: "\(formatWeight(bestSet.weight)) lbs × \(bestSet.effectiveReps)"
                    ))
                }
            }
        }
        return Array(prs.prefix(3))
    }

    func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(w))" : String(format: "%.1f", w)
    }

    func formattedDuration(_ interval: TimeInterval) -> String {
        let mins = Int(interval) / 60
        let secs = Int(interval) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
