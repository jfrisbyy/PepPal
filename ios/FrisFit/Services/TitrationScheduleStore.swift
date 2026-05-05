import Foundation
import UserNotifications

@Observable
final class TitrationScheduleStore {
    static let shared = TitrationScheduleStore()

    private(set) var schedules: [TitrationSchedule] = []
    var stepUpRemindersEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(stepUpRemindersEnabled, forKey: Self.stepUpKey)
            rescheduleAllNotifications()
        }
    }

    private static let schedulesKey = "titration_schedules_v1"
    private static let stepUpKey = "titration_stepup_reminders_enabled"
    private static let reminderPrefix = "titration_reminder_"

    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard

    private init() {
        loadFromDisk()
        if defaults.object(forKey: Self.stepUpKey) != nil {
            stepUpRemindersEnabled = defaults.bool(forKey: Self.stepUpKey)
        }
    }

    // MARK: - Queries

    func schedule(for protocolId: UUID) -> TitrationSchedule? {
        schedules.first(where: { $0.protocolId == protocolId })
    }

    // MARK: - Mutations

    func save(_ schedule: TitrationSchedule) {
        if let idx = schedules.firstIndex(where: { $0.protocolId == schedule.protocolId }) {
            schedules[idx] = schedule
        } else {
            schedules.append(schedule)
        }
        saveToDisk()
        scheduleNotifications(for: schedule)
    }

    func remove(protocolId: UUID) {
        schedules.removeAll(where: { $0.protocolId == protocolId })
        saveToDisk()
        cancelNotifications(protocolId: protocolId)
    }

    // MARK: - Computed helpers

    func currentStep(for protocolId: UUID) -> TitrationScheduleStep? {
        schedule(for: protocolId)?.currentStep()
    }

    func nextStepInfo(for protocolId: UUID) -> (step: TitrationScheduleStep, date: Date)? {
        guard let sched = schedule(for: protocolId),
              let next = sched.nextStep() else { return nil }
        return (next, sched.startDate(for: next))
    }

    // MARK: - Persistence

    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(schedules)
            defaults.set(data, forKey: Self.schedulesKey)
        } catch {
            print("[TitrationStore] Save failed: \(error)")
        }
    }

    private func loadFromDisk() {
        guard let data = defaults.data(forKey: Self.schedulesKey) else { return }
        do {
            schedules = try JSONDecoder().decode([TitrationSchedule].self, from: data)
        } catch {
            print("[TitrationStore] Load failed: \(error)")
        }
    }

    // MARK: - Notifications

    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional: return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        default: return false
        }
    }

    func rescheduleAllNotifications() {
        for sched in schedules {
            scheduleNotifications(for: sched)
        }
    }

    private func identifierPrefix(_ protocolId: UUID) -> String {
        "\(Self.reminderPrefix)\(protocolId.uuidString)_"
    }

    func cancelNotifications(protocolId: UUID) {
        let prefix = identifierPrefix(protocolId)
        center.getPendingNotificationRequests { [weak self] requests in
            let ids = requests.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier)
            self?.center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    private func scheduleNotifications(for schedule: TitrationSchedule) {
        cancelNotifications(protocolId: schedule.protocolId)
        guard schedule.remindersEnabled, stepUpRemindersEnabled else { return }

        let prefix = identifierPrefix(schedule.protocolId)
        let cal = Calendar.current
        let now = Date()

        for step in schedule.sortedSteps {
            let stepStart = schedule.startDate(for: step)
            guard stepStart > now else { continue }
            var comps = cal.dateComponents([.year, .month, .day], from: stepStart)
            comps.hour = schedule.reminderHour
            comps.minute = schedule.reminderMinute

            let content = UNMutableNotificationContent()
            content.title = "Titration Step-Up"
            let doseStr = CompoundUnitHelper.displayDoseShort(step.doseMcg, for: schedule.compoundName)
            let labelSuffix = step.label.isEmpty ? "" : " — \(step.label)"
            content.body = "Time to step up your \(schedule.compoundName) to \(doseStr)\(labelSuffix)."
            content.sound = .default
            content.userInfo = ["type": "titration_step_up", "protocol_id": schedule.protocolId.uuidString]

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let id = "\(prefix)\(step.id.uuidString)"
            let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            center.add(req)
        }
    }
}
