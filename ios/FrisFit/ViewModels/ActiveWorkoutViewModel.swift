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
    var restTimerDidFire: Bool = false

    var showPlateCalculator: Bool = false
    var plateCalculatorWeight: Double = 135

    var previousBestByExercise: [String: (weight: Double, reps: Int)] = [:]

    var activeNumberInput: NumberInputField? = nil
    var numberInputValue: String = ""

    var showExerciseInfo: Bool = false
    var showExercisePicker: Bool = false
    var showSwapPicker: Bool = false
    var swapTargetIndex: Int? = nil
    var pendingSwap: (oldId: String, newExercise: Exercise, programId: UUID?, dayId: UUID?, programExerciseIndex: Int?)? = nil

    var progressionUpdates: [(exerciseName: String, newWeight: Double, delta: Double, note: String)] = []

    var showEmptyEndConfirmation: Bool = false
    var showCompleteConfirmation: Bool = false

    var hasAnyLoggedSets: Bool {
        exercises.contains { $0.sets.contains(where: { $0.isCompleted }) }
    }

    var hasIncompleteSets: Bool {
        exercises.contains { $0.sets.contains(where: { !$0.isCompleted }) }
    }

    /// Optional anchors to enable "Save to template". Set by the caller that starts the session.
    var sourceProgramId: UUID? = nil
    var sourceDayId: UUID? = nil
    var programExerciseIndices: [UUID: Int] = [:]

    var recentPRs: [PRTracker.PRHit] = []
    var prToastId: UUID = UUID()
    private var sessionPRs: [PRTracker.PRHit] = []

    private var restTimer: Timer?

    init(name: String, exercises: [WorkoutExercise]) {
        self.workoutName = name
        self.exercises = exercises
    }

    func onSessionStart(startDate: Date) {
    }

    var currentExercise: WorkoutExercise? {
        guard currentExerciseIndex < exercises.count else { return nil }
        return exercises[currentExerciseIndex]
    }

    var totalCompletedExercises: Int {
        exercises.filter(\.isCompleted).count
    }

    /// Name of the upcoming exercise — surfaced in the rest timer so users know
    /// what they're advancing into when they skip rest. Returns nil when the
    /// rest is between sets of the same exercise (current isn't done yet) or
    /// when this is the final exercise.
    var nextExerciseName: String? {
        guard currentExerciseIndex < exercises.count else { return nil }
        guard exercises[currentExerciseIndex].isCompleted else { return nil }
        let nextIndex = currentExerciseIndex + 1
        guard nextIndex < exercises.count else { return nil }
        return exercises[nextIndex].exercise.name
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

        let currentExercise = exercises[exerciseIndex].exercise
        let hits = PRTracker.shared.checkAndRecord(
            exerciseId: currentExercise.id,
            exerciseName: currentExercise.name,
            weight: set.effectiveWeight,
            reps: set.effectiveReps
        )
        if !hits.isEmpty {
            recentPRs = hits
            prToastId = UUID()
            sessionPRs.append(contentsOf: hits)
            persistPRs(hits, reps: set.effectiveReps)
            broadcastPRs(hits, reps: set.effectiveReps)
        }

        BuddyWorkoutService.shared.logMySet(exerciseName: currentExercise.name)

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

    /// Marks a previously completed set as not-yet-completed, letting the user
    /// correct a mistake mid-workout. Stops any rest timer that was queued by
    /// completing this exercise.
    func unlogSet(exerciseIndex: Int, setIndex: Int) {
        guard exerciseIndex < exercises.count,
              setIndex < exercises[exerciseIndex].sets.count else { return }
        exercises[exerciseIndex].sets[setIndex].isCompleted = false
        exercises[exerciseIndex].isCompleted = false
        if isRestTimerActive {
            restTimer?.invalidate()
            restTimer = nil
            isRestTimerActive = false
            restSecondsRemaining = 0
            restSecondsTotal = 0
        }
    }

    func startRestTimer(seconds: Int) {
        guard seconds > 0 else { return }
        restSecondsTotal = seconds
        restSecondsRemaining = seconds
        isRestTimerActive = true
        restTimerDidFire = false
        RestTimerAudio.shared.prepare()
        restTimer?.invalidate()
        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            let vm = self
            Task { @MainActor in
                guard let vm else { return }
                if vm.restSecondsRemaining > 1 {
                    vm.restSecondsRemaining -= 1
                } else {
                    vm.restSecondsRemaining = 0
                    vm.fireRestComplete()
                }
            }
        }
    }

    func adjustRestTimer(by seconds: Int) {
        guard isRestTimerActive else { return }
        restSecondsTotal = max(1, restSecondsTotal + seconds)
        restSecondsRemaining = max(1, restSecondsRemaining + seconds)
    }

    private func fireRestComplete() {
        guard !restTimerDidFire else { return }
        restTimerDidFire = true
        RestTimerAudio.shared.fireCompletion()
        restTimer?.invalidate()
        restTimer = nil
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            if self.isRestTimerActive && self.restSecondsRemaining == 0 {
                self.skipRestTimer()
            }
        }
    }

    func skipRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
        isRestTimerActive = false
        restSecondsRemaining = 0
        restSecondsTotal = 0
        restTimerDidFire = false

        guard currentExerciseIndex < exercises.count else { return }
        // Auto-advance to the next exercise whenever the current one is done.
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

    func openSwapPicker(for exerciseIndex: Int) {
        swapTargetIndex = exerciseIndex
        showSwapPicker = true
    }

    /// Replace the exercise at `swapTargetIndex` in the active session only.
    /// Preserves completed sets by carrying over the count; resets reps/weight to blanks with no previous data.
    func swapExercise(with newExercise: Exercise) {
        guard let idx = swapTargetIndex, idx < exercises.count else { return }
        let old = exercises[idx]
        let targetSets = max(old.sets.count, 1)
        var replaced = WorkoutExercise(
            exercise: newExercise,
            targetSets: targetSets,
            previousWeight: nil,
            previousReps: nil
        )
        for (i, set) in old.sets.enumerated() where set.isCompleted && i < replaced.sets.count {
            replaced.sets[i].isCompleted = true
            replaced.sets[i].weight = set.weight
            replaced.sets[i].reps = set.reps
        }
        let allDone = replaced.sets.allSatisfy(\.isCompleted)
        replaced.isCompleted = allDone
        exercises[idx] = replaced

        pendingSwap = (
            oldId: old.exercise.id,
            newExercise: newExercise,
            programId: sourceProgramId,
            dayId: sourceDayId,
            programExerciseIndex: programExerciseIndices[old.id]
        )

        swapTargetIndex = nil
        showSwapPicker = false
    }

    /// Persists the most recent swap to the source template, if one is available.
    func saveLastSwapToTemplate(using trainViewModel: TrainViewModel) {
        guard let swap = pendingSwap,
              let programId = swap.programId,
              let dayId = swap.dayId,
              let exerciseIndex = swap.programExerciseIndex else { return }
        trainViewModel.swapExerciseInProgram(
            programId: programId,
            dayId: dayId,
            exerciseIndex: exerciseIndex,
            newExercise: swap.newExercise
        )
        pendingSwap = nil
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

    func openPlateCalculator(exerciseIndex: Int, setIndex: Int) {
        guard exerciseIndex < exercises.count,
              setIndex < exercises[exerciseIndex].sets.count else { return }
        guard exercises[exerciseIndex].exercise.equipment == .barbell else { return }
        let set = exercises[exerciseIndex].sets[setIndex]
        let w = set.weight > 0 ? set.weight : (set.previousWeight ?? 135)
        plateCalculatorWeight = w
        showPlateCalculator = true
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

    /// Called when user taps End. If no sets were logged, prompts confirmation
    /// and discards the session without saving. Otherwise finishes normally.
    func requestEndWorkout() {
        if hasAnyLoggedSets {
            finishWorkout()
        } else {
            showEmptyEndConfirmation = true
        }
    }

    func discardEmptyWorkout() {
        restTimer?.invalidate()
        restTimer = nil
        isWorkoutActive = false
        showEmptyEndConfirmation = false
        BuddyWorkoutService.shared.endSession()
        WorkoutSessionManager.shared.endSession()
    }

    func finishWorkout() {
        restTimer?.invalidate()
        restTimer = nil
        isWorkoutActive = false

        let totalVolume = exercises.reduce(0.0) { $0 + $1.totalVolume }
        let totalSets = exercises.reduce(0) { $0 + $1.completedSets }
        let durationMinutes = elapsedSeconds / 60
        let calories = estimateCaloriesBurned(durationMinutes: durationMinutes)

        let prs = generateMockPRs()

        summary = WorkoutSummary(
            workoutName: workoutName,
            duration: TimeInterval(elapsedSeconds),
            totalVolume: totalVolume,
            totalSets: totalSets,
            caloriesBurned: calories,
            personalRecords: prs
        )
        isCompleted = true
        BuddyWorkoutService.shared.endSession()
        saveToSupabase(durationMinutes: durationMinutes, caloriesBurned: calories, totalVolume: Int(totalVolume))
        logToActivityLogs(durationMinutes: durationMinutes, caloriesBurned: calories)
        StreakManager.shared.logActivity(type: .workout, durationMinutes: durationMinutes)
        computeProgressionUpdates()
    }

    private func computeProgressionUpdates() {
        var updates: [(exerciseName: String, newWeight: Double, delta: Double, note: String)] = []
        for we in exercises where we.completedSets > 0 {
            let completed = we.sets.filter { $0.isCompleted }
            let topSet = completed.max { $0.effectiveWeight < $1.effectiveWeight } ?? completed.first
            guard let top = topSet, top.effectiveWeight > 0, top.effectiveReps > 0 else { continue }
            updates.append((
                exerciseName: we.exercise.name,
                newWeight: top.effectiveWeight,
                delta: 0,
                note: "Last: \(formatWeight(top.effectiveWeight)) × \(top.effectiveReps)"
            ))
        }
        progressionUpdates = updates
        NotificationCenter.default.post(
            name: .workoutCompletedForProgression,
            object: nil,
            userInfo: [
                "programId": sourceProgramId as Any,
                "dayId": sourceDayId as Any,
                "results": exercises.map { we -> [String: Any] in
                    let completed = we.sets.filter { $0.isCompleted }
                    let top = completed.max { $0.effectiveWeight < $1.effectiveWeight }
                    let allHitMax = !completed.isEmpty && completed.allSatisfy { $0.effectiveReps >= we.sets.first?.previousReps ?? 0 }
                    return [
                        "exerciseId": we.exercise.id,
                        "weight": top?.effectiveWeight ?? 0,
                        "reps": top?.effectiveReps ?? 0,
                        "allSetsCompleted": allHitMax
                    ]
                }
            ]
        )
    }

    private func estimateCaloriesBurned(durationMinutes: Int) -> Int {
        let weightKg = latestWeightKg()
        return METCalculator.caloriesBurned(
            sport: nil,
            workoutType: "strength",
            durationMinutes: durationMinutes,
            weightKg: weightKg,
            intensity: 6
        )
    }

    private func latestWeightKg() -> Double {
        let cached = UserDefaults.standard.double(forKey: "cachedWeightLbs")
        let lbs = cached > 0 ? cached : 175.0
        return lbs * 0.453592
    }

    private func logToActivityLogs(durationMinutes: Int, caloriesBurned: Int) {
        guard AuthService.shared.authState == .signedIn else { return }
        Task {
            do {
                let userId = try AuthService.shared.currentUserId()
                try await ActivityLogService.shared.logActivity(
                    userId: userId,
                    activityType: "workout",
                    sport: nil,
                    durationMinutes: durationMinutes,
                    caloriesBurned: caloriesBurned,
                    metValue: 5.0
                )
                await MainActor.run {
                    NotificationCenter.default.post(name: .supabaseDataChanged, object: nil, userInfo: ["source": "activity"])
                }
            } catch {
                print("[ActiveWorkout] Failed to log activity: \(error)")
            }
        }
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

    private func saveToSupabase(durationMinutes: Int, caloriesBurned: Int, totalVolume: Int) {
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
                    exercises: exerciseDetails
                )
                await MainActor.run {
                    NotificationCenter.default.post(name: .supabaseDataChanged, object: nil, userInfo: ["source": "workout"])
                }
            } catch {
                print("[ActiveWorkout] Failed to save workout: \(error)")
            }
        }
    }

    private func generateMockPRs() -> [PersonalRecord] {
        var byExercise: [String: PRTracker.PRHit] = [:]
        for hit in sessionPRs {
            let existing = byExercise[hit.exerciseId]
            let preferNew: Bool
            if let existing {
                preferNew = rank(existing.kind) < rank(hit.kind)
            } else {
                preferNew = true
            }
            if preferNew { byExercise[hit.exerciseId] = hit }
        }
        return byExercise.values.prefix(5).map { hit in
            PersonalRecord(
                exerciseName: hit.exerciseName,
                recordType: label(for: hit.kind),
                value: valueString(for: hit)
            )
        }
    }

    private func rank(_ kind: PRTracker.PRHit.Kind) -> Int {
        switch kind {
        case .weight: 2
        case .oneRepMax: 3
        case .volume: 1
        }
    }

    private func label(for kind: PRTracker.PRHit.Kind) -> String {
        switch kind {
        case .weight: "Weight PR"
        case .oneRepMax: "Est. 1RM PR"
        case .volume: "Volume PR"
        }
    }

    private func valueString(for hit: PRTracker.PRHit) -> String {
        switch hit.kind {
        case .weight: "\(formatWeight(hit.newValue)) lbs"
        case .oneRepMax: "\(formatWeight(hit.newValue)) lbs 1RM"
        case .volume: "\(formatWeight(hit.newValue)) lbs total"
        }
    }

    private func broadcastPRs(_ hits: [PRTracker.PRHit], reps: Int) {
        // Only broadcast 1RM PRs (the most meaningful) and only if user opted in
        guard let top = hits.first(where: { $0.kind == .oneRepMax }) ?? hits.first else { return }
        let prefs = StatSharingService.shared.currentUserPrefs
        guard prefs.isEnabled, prefs.categories.contains(.prs) else { return }
        let valueText: String
        switch top.kind {
        case .weight: valueText = "\(formatWeight(top.newValue))kg × \(reps)"
        case .oneRepMax: valueText = "\(formatWeight(top.newValue))kg 1RM"
        case .volume: valueText = "\(formatWeight(top.newValue))kg total"
        }
        let title = "New PR: \(top.exerciseName)"
        let subtitle = valueText
        Task {
            await FriendsBackendService.shared.recordActivityEvent(
                type: "pr",
                title: title,
                subtitle: subtitle,
                data: [
                    "exercise_id": top.exerciseId,
                    "exercise_name": top.exerciseName,
                    "kind": top.kind.rawValue
                ]
            )
        }
    }

    private func persistPRs(_ hits: [PRTracker.PRHit], reps: Int) {
        guard AuthService.shared.authState == .signedIn else { return }
        Task {
            do {
                let userId = try AuthService.shared.currentUserId()
                for hit in hits {
                    try? await PersonalRecordService.shared.persist(userId: userId, hit: hit, reps: reps)
                }
            } catch {
                print("[ActiveWorkout] PR persist error: \(error)")
            }
        }
    }

    func previousBest(for exerciseId: String) -> (weight: Double, reps: Int)? {
        let w = PRTracker.shared.bestWeight(for: exerciseId)
        guard w > 0 else { return previousBestByExercise[exerciseId] }
        return (w, 0)
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
