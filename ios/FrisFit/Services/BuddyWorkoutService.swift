import SwiftUI
import UIKit

@MainActor
@Observable
final class BuddyWorkoutService {
    static let shared = BuddyWorkoutService()

    private(set) var session: BuddySession?
    private(set) var recentEvents: [BuddySetEvent] = []

    var isActive: Bool { session?.state == .active }

    private var simulationTimer: Timer?
    private var buddyPaceSeconds: TimeInterval = 75

    private init() {}

    // MARK: - Start

    func startSession(
        workoutName: String,
        totalSetsTarget: Int,
        firstExerciseName: String?,
        buddy: FriendStatSnapshot
    ) {
        stopSimulation()

        let myId = (try? AuthService.shared.currentUserId()) ?? "me"
        let myName = ProfileService.shared.cachedDisplayName ?? "You"
        let myAvatarURL = ProfileService.shared.cachedAvatarUrl

        let me = BuddyParticipant(
            id: myId,
            name: myName,
            avatarInitial: String(myName.prefix(1)).uppercased(),
            avatarURL: myAvatarURL,
            totalSetsTarget: totalSetsTarget,
            setsCompleted: 0,
            currentExerciseName: firstExerciseName,
            lastSetAt: nil,
            isFinished: false
        )

        let theirs = BuddyParticipant(
            id: buddy.id.uuidString,
            name: buddy.user.name,
            avatarInitial: buddy.user.avatarInitial,
            avatarURL: buddy.user.avatarURL,
            totalSetsTarget: totalSetsTarget,
            setsCompleted: 0,
            currentExerciseName: firstExerciseName,
            lastSetAt: nil,
            isFinished: false
        )

        session = BuddySession(
            id: UUID(),
            workoutName: workoutName,
            state: .active,
            startedAt: Date(),
            me: me,
            buddy: theirs,
            buddyUserId: buddy.id.uuidString
        )
        recentEvents = []

        FriendSocialService.shared.setPresence(friendId: buddy.id.uuidString, activity: "Workout")
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        startBuddySimulation()
    }

    func endSession() {
        stopSimulation()
        if let id = session?.buddyUserId {
            FriendSocialService.shared.clearPresence(friendId: id)
        }
        session = nil
        recentEvents = []
    }

    // MARK: - Events

    func logMySet(exerciseName: String?) {
        guard var s = session else { return }
        s.me.setsCompleted = min(s.me.setsCompleted + 1, s.me.totalSetsTarget)
        s.me.currentExerciseName = exerciseName ?? s.me.currentExerciseName
        s.me.lastSetAt = Date()
        if s.me.setsCompleted >= s.me.totalSetsTarget {
            s.me.isFinished = true
        }
        session = s
        recentEvents.append(BuddySetEvent(
            id: UUID(),
            participantId: s.me.id,
            exerciseName: exerciseName ?? s.me.currentExerciseName ?? "Set",
            timestamp: Date()
        ))
        trimEvents()
    }

    private func logBuddySet() {
        guard var s = session, !s.buddy.isFinished else { return }
        s.buddy.setsCompleted = min(s.buddy.setsCompleted + 1, s.buddy.totalSetsTarget)
        s.buddy.lastSetAt = Date()
        if s.buddy.setsCompleted >= s.buddy.totalSetsTarget {
            s.buddy.isFinished = true
        }
        let exerciseName = s.buddy.currentExerciseName ?? s.me.currentExerciseName ?? "Set"
        session = s
        recentEvents.append(BuddySetEvent(
            id: UUID(),
            participantId: s.buddy.id,
            exerciseName: exerciseName,
            timestamp: Date()
        ))
        trimEvents()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func trimEvents() {
        if recentEvents.count > 40 {
            recentEvents.removeFirst(recentEvents.count - 40)
        }
    }

    // MARK: - Simulation

    private func startBuddySimulation() {
        buddyPaceSeconds = Double.random(in: 55...95)
        scheduleNextBuddySet()
    }

    private func scheduleNextBuddySet() {
        simulationTimer?.invalidate()
        let jitter = Double.random(in: 0.7...1.3)
        let delay = buddyPaceSeconds * jitter
        simulationTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, let s = self.session, s.state == .active, !s.buddy.isFinished else { return }
                self.logBuddySet()
                self.scheduleNextBuddySet()
            }
        }
    }

    private func stopSimulation() {
        simulationTimer?.invalidate()
        simulationTimer = nil
    }
}
