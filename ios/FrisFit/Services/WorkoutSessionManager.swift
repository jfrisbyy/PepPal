import SwiftUI

@Observable
final class WorkoutSessionManager {
    static let shared = WorkoutSessionManager()

    var isSessionActive: Bool = false
    var activeViewModel: ActiveWorkoutViewModel?
    var showActiveWorkout: Bool = false

    private var startDate: Date?
    private var elapsedTimer: Timer?
    private static let startDateKey = "activeWorkoutStartDate"
    private static let workoutNameKey = "activeWorkoutName"
    private static let isActiveKey = "activeWorkoutIsActive"

    var elapsedSeconds: Int = 0

    var formattedElapsedTime: String {
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        let seconds = elapsedSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var workoutName: String {
        activeViewModel?.workoutName ?? UserDefaults.standard.string(forKey: Self.workoutNameKey) ?? ""
    }

    private init() {
        restoreSession()
    }

    func startSession(
        name: String,
        exercises: [WorkoutExercise],
        programId: UUID? = nil,
        dayId: UUID? = nil,
        programExerciseIndices: [UUID: Int] = [:]
    ) {
        let vm = ActiveWorkoutViewModel(name: name, exercises: exercises)
        vm.sourceProgramId = programId
        vm.sourceDayId = dayId
        vm.programExerciseIndices = programExerciseIndices
        activeViewModel = vm
        startDate = Date()
        elapsedSeconds = 0
        isSessionActive = true
        showActiveWorkout = true

        persistSession(name: name)
        startTimer()
        vm.onSessionStart(startDate: startDate!)

        WorkoutState.shared.isWorkoutActive = true
        WorkoutState.shared.workoutName = name

        if let myId = try? AuthService.shared.currentUserId() {
            FriendSocialService.shared.setPresence(friendId: myId, activity: "Workout")
        }
    }

    func resumeActiveWorkout() {
        guard isSessionActive else { return }
        showActiveWorkout = true
    }

    func minimizeWorkout() {
        showActiveWorkout = false
    }

    func endSession() {
        stopTimer()
        isSessionActive = false
        showActiveWorkout = false
        activeViewModel = nil
        startDate = nil
        elapsedSeconds = 0
        clearPersistedSession()

        WorkoutState.shared.isWorkoutActive = false
        WorkoutState.shared.workoutProgress = 0

        if let myId = try? AuthService.shared.currentUserId() {
            FriendSocialService.shared.clearPresence(friendId: myId)
        }
    }

    func updateProgress(_ exerciseIndex: Int, total: Int) {
        WorkoutState.shared.workoutProgress = Double(exerciseIndex) / Double(max(1, total))
    }

    func startTimer() {
        stopTimer()
        recalculateElapsed()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            let mgr = self
            Task { @MainActor in
                mgr?.recalculateElapsed()
                mgr?.activeViewModel?.elapsedSeconds = mgr?.elapsedSeconds ?? 0
            }
        }
    }

    func stopTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    private func recalculateElapsed() {
        guard let start = startDate else { return }
        elapsedSeconds = Int(Date().timeIntervalSince(start))
    }

    private func persistSession(name: String) {
        UserDefaults.standard.set(startDate, forKey: Self.startDateKey)
        UserDefaults.standard.set(name, forKey: Self.workoutNameKey)
        UserDefaults.standard.set(true, forKey: Self.isActiveKey)
    }

    private func clearPersistedSession() {
        UserDefaults.standard.removeObject(forKey: Self.startDateKey)
        UserDefaults.standard.removeObject(forKey: Self.workoutNameKey)
        UserDefaults.standard.set(false, forKey: Self.isActiveKey)
    }

    private func restoreSession() {
        guard UserDefaults.standard.bool(forKey: Self.isActiveKey),
              let savedStart = UserDefaults.standard.object(forKey: Self.startDateKey) as? Date else {
            return
        }
        let elapsed = Int(Date().timeIntervalSince(savedStart))
        guard elapsed < 14400 else {
            clearPersistedSession()
            return
        }
        startDate = savedStart
        elapsedSeconds = elapsed
        isSessionActive = true

        WorkoutState.shared.isWorkoutActive = true
        WorkoutState.shared.workoutName = UserDefaults.standard.string(forKey: Self.workoutNameKey) ?? "Workout"

        startTimer()
    }
}
