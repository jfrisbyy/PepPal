import Foundation
import UserNotifications

nonisolated enum ReminderStyle: String, Codable, CaseIterable, Sendable {
    case gentle
    case firm
    case off

    var title: String {
        switch self {
        case .gentle: return "Gentle"
        case .firm: return "Firm"
        case .off: return "Off"
        }
    }

    var subtitle: String {
        switch self {
        case .gentle: return "Soft nudges. One reminder per dose, friendly tone."
        case .firm: return "Direct alerts. Repeats if missed for 5 minutes."
        case .off: return "No reminders. You'll log everything manually."
        }
    }

    var icon: String {
        switch self {
        case .gentle: return "leaf.fill"
        case .firm: return "bell.badge.fill"
        case .off: return "bell.slash.fill"
        }
    }
}

private func _makeTime(hour: Int, minute: Int) -> Date {
    var components = DateComponents()
    components.hour = hour
    components.minute = minute
    return Calendar.current.date(from: components) ?? Date()
}

@Observable
final class ReminderManager {
    static let shared = ReminderManager()

    var isAuthorized: Bool = false
    var authorizationDenied: Bool = false

    var doseEnabled: Bool = true { didSet { saveToDisk(); scheduleDoseReminders() } }
    var workoutEnabled: Bool = false { didSet { saveToDisk(); scheduleWorkoutReminder() } }
    var weighInEnabled: Bool = false { didSet { saveToDisk(); scheduleWeighInReminder() } }
    var mealLoggingEnabled: Bool = false { didSet { saveToDisk(); scheduleMealReminders() } }
    var bloodworkEnabled: Bool = false { didSet { saveToDisk(); scheduleBloodworkReminder() } }
    var hydrationEnabled: Bool = false { didSet { saveToDisk(); scheduleHydrationReminders() } }
    var restDayEnabled: Bool = false { didSet { saveToDisk(); scheduleRestDayReminder() } }
    var weeklyCheckInEnabled: Bool = false { didSet { saveToDisk(); scheduleWeeklyCheckInReminder() } }

    var hydrationTimes: [Date] = [
        _makeTime(hour: 9, minute: 0),
        _makeTime(hour: 12, minute: 0),
        _makeTime(hour: 15, minute: 0),
        _makeTime(hour: 18, minute: 0)
    ] { didSet { saveToDisk(); scheduleHydrationReminders() } }

    var restDayCheckTime: Date = _makeTime(hour: 20, minute: 0) {
        didSet { saveToDisk(); scheduleRestDayReminder() }
    }

    var weeklyCheckInDay: WeighInDay = .sunday {
        didSet { saveToDisk(); scheduleWeeklyCheckInReminder() }
    }
    var weeklyCheckInTime: Date = _makeTime(hour: 10, minute: 0) {
        didSet { saveToDisk(); scheduleWeeklyCheckInReminder() }
    }

    var reminderStyle: ReminderStyle = .gentle {
        didSet {
            saveToDisk()
            doseEnabled = (reminderStyle != .off)
        }
    }
    var morningBriefTime: Date = _makeTime(hour: 7, minute: 0) {
        didSet { saveToDisk() }
    }
    var doseReminderTime: Date = _makeTime(hour: 6, minute: 30) {
        didSet { saveToDisk() }
    }

    var workoutTime: Date = _makeTime(hour: 18, minute: 0) {
        didSet { saveToDisk(); scheduleWorkoutReminder() }
    }
    var weighInDay: WeighInDay = .monday {
        didSet { saveToDisk(); scheduleWeighInReminder() }
    }
    var weighInTime: Date = _makeTime(hour: 9, minute: 0) {
        didSet { saveToDisk(); scheduleWeighInReminder() }
    }
    var breakfastTime: Date = _makeTime(hour: 8, minute: 0) {
        didSet { saveToDisk(); scheduleMealReminders() }
    }
    var lunchTime: Date = _makeTime(hour: 12, minute: 0) {
        didSet { saveToDisk(); scheduleMealReminders() }
    }
    var dinnerTime: Date = _makeTime(hour: 19, minute: 0) {
        didSet { saveToDisk(); scheduleMealReminders() }
    }
    var bloodworkInterval: BloodworkInterval = .days30 {
        didSet { saveToDisk(); scheduleBloodworkReminder() }
    }
    var bloodworkTime: Date = _makeTime(hour: 9, minute: 0) {
        didSet { saveToDisk(); scheduleBloodworkReminder() }
    }

    private var activeCompounds: [ProtocolCompound] = []
    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard

    private static let dosePrefix = "dose_reminder_"
    private static let workoutId = "workout_reminder"
    private static let weighInId = "weighin_reminder"
    private static let mealPrefix = "meal_reminder_"
    private static let bloodworkId = "bloodwork_reminder"
    private static let hydrationPrefix = "hydration_reminder_"
    private static let restDayId = "rest_day_reminder"
    private static let weeklyCheckInId = "weekly_checkin_reminder"

    private init() {
        loadFromDisk()
        checkAuthorizationStatus()
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            isAuthorized = true
            authorizationDenied = false
            return true
        case .denied:
            isAuthorized = false
            authorizationDenied = true
            return false
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                isAuthorized = granted
                authorizationDenied = !granted
                return granted
            } catch {
                return false
            }
        default:
            return false
        }
    }

    func checkAuthorizationStatus() {
        center.getNotificationSettings { settings in
            Task { @MainActor in
                self.isAuthorized = settings.authorizationStatus == .authorized
                self.authorizationDenied = settings.authorizationStatus == .denied
            }
        }
    }

    func updateActiveProtocolCompounds(_ compounds: [ProtocolCompound]) {
        activeCompounds = compounds
        if doseEnabled {
            scheduleDoseReminders()
        }
    }

    func cancelDoseForCompound(_ compoundName: String) {
        let safeName = compoundName.lowercased().replacingOccurrences(of: " ", with: "_")
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            let idsToRemove = requests
                .filter { $0.identifier.hasPrefix(Self.dosePrefix + safeName) }
                .map(\.identifier)
            if !idsToRemove.isEmpty {
                self.center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
            }
        }
    }

    func rescheduleAll() {
        scheduleDoseReminders()
        scheduleWorkoutReminder()
        scheduleWeighInReminder()
        scheduleMealReminders()
        scheduleBloodworkReminder()
        scheduleHydrationReminders()
        scheduleRestDayReminder()
        scheduleWeeklyCheckInReminder()
    }

    // MARK: - Hydration

    func scheduleHydrationReminders() {
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            let ids = requests.filter { $0.identifier.hasPrefix(Self.hydrationPrefix) }.map(\.identifier)
            self.center.removePendingNotificationRequests(withIdentifiers: ids)

            guard self.hydrationEnabled, self.isAuthorized else { return }

            for (index, time) in self.hydrationTimes.enumerated() {
                let content = UNMutableNotificationContent()
                content.title = "Time to hydrate"
                content.body = "Keep your intake on track \u{2014} a glass of water now goes a long way."
                content.sound = .default
                content.categoryIdentifier = ReminderCategory.hydration.rawValue
                content.userInfo = ["type": "hydration"]

                let components = Calendar.current.dateComponents([.hour, .minute], from: time)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let id = "\(Self.hydrationPrefix)\(index)"
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                self.center.add(request)
            }
        }
    }

    func addHydrationTime(_ time: Date) {
        hydrationTimes.append(time)
        hydrationTimes.sort { a, b in
            let cal = Calendar.current
            let ac = cal.dateComponents([.hour, .minute], from: a)
            let bc = cal.dateComponents([.hour, .minute], from: b)
            if ac.hour != bc.hour { return (ac.hour ?? 0) < (bc.hour ?? 0) }
            return (ac.minute ?? 0) < (bc.minute ?? 0)
        }
    }

    func removeHydrationTime(at index: Int) {
        guard index >= 0 && index < hydrationTimes.count else { return }
        hydrationTimes.remove(at: index)
    }

    func updateHydrationTime(at index: Int, to newTime: Date) {
        guard index >= 0 && index < hydrationTimes.count else { return }
        hydrationTimes[index] = newTime
    }

    // MARK: - Rest Day

    func scheduleRestDayReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.restDayId])
        guard restDayEnabled, isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Didn't train today?"
        content.body = "That's okay \u{2014} rest is part of training. Tap to log a recovery activity."
        content.sound = .default
        content.categoryIdentifier = ReminderCategory.restDay.rawValue
        content.userInfo = ["type": "rest_day"]

        let components = Calendar.current.dateComponents([.hour, .minute], from: restDayCheckTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: Self.restDayId, content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Weekly Check-In

    func scheduleWeeklyCheckInReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.weeklyCheckInId])
        guard weeklyCheckInEnabled, isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Weekly check-in"
        content.body = "Time for your weigh-in and progress photos."
        content.sound = .default
        content.categoryIdentifier = ReminderCategory.weeklyCheckIn.rawValue
        content.userInfo = ["type": "weekly_check_in"]

        var components = Calendar.current.dateComponents([.hour, .minute], from: weeklyCheckInTime)
        components.weekday = weeklyCheckInDay.rawValue
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: Self.weeklyCheckInId, content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Dose Reminders

    func scheduleDoseReminders() {
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            let doseIds = requests.filter { $0.identifier.hasPrefix(Self.dosePrefix) }.map(\.identifier)
            self.center.removePendingNotificationRequests(withIdentifiers: doseIds)

            guard self.doseEnabled, self.isAuthorized else { return }

            for compound in self.activeCompounds {
                let times = self.doseTimes(for: compound)
                for (index, time) in times.enumerated() {
                    let components = Calendar.current.dateComponents([.hour, .minute], from: time)
                    let routeName = compound.injectionRoute.rawValue.lowercased()
                    let doseStr = CompoundUnitHelper.displayDoseShort(compound.doseMcg, for: compound.compoundName)

                    let content = UNMutableNotificationContent()
                    content.title = "Time for your \(compound.compoundName) dose"
                    content.body = "\(doseStr) \(routeName)"
                    content.sound = .default
                    content.categoryIdentifier = ReminderCategory.dose.rawValue

                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                    let safeName = compound.compoundName.lowercased().replacingOccurrences(of: " ", with: "_")
                    let id = "\(Self.dosePrefix)\(safeName)_\(index)"

                    let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                    self.center.add(request)
                }
            }
        }
    }

    // MARK: - Workout Reminder

    func scheduleWorkoutReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.workoutId])
        guard workoutEnabled, isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time to train!"
        content.body = "Don't skip today \u{2014} every session counts toward your goals."
        content.sound = .default
        content.categoryIdentifier = ReminderCategory.workout.rawValue

        let components = Calendar.current.dateComponents([.hour, .minute], from: workoutTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(identifier: Self.workoutId, content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Weigh-In Reminder

    func scheduleWeighInReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.weighInId])
        guard weighInEnabled, isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Weekly weigh-in day!"
        content.body = "Log your weight to track your progress."
        content.sound = .default
        content.categoryIdentifier = ReminderCategory.weighIn.rawValue

        var components = Calendar.current.dateComponents([.hour, .minute], from: weighInTime)
        components.weekday = weighInDay.rawValue
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(identifier: Self.weighInId, content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Meal Logging Reminders

    func scheduleMealReminders() {
        let mealIds = ["breakfast", "lunch", "dinner"].map { "\(Self.mealPrefix)\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: mealIds)
        guard mealLoggingEnabled, isAuthorized else { return }

        let meals: [(String, String, Date)] = [
            ("breakfast", "Don't forget to log your breakfast!", breakfastTime),
            ("lunch", "Don't forget to log your lunch!", lunchTime),
            ("dinner", "Don't forget to log your dinner!", dinnerTime),
        ]

        for (name, body, time) in meals {
            let content = UNMutableNotificationContent()
            content.title = "Meal Reminder"
            content.body = body
            content.sound = .default
            content.categoryIdentifier = ReminderCategory.mealLogging.rawValue

            let components = Calendar.current.dateComponents([.hour, .minute], from: time)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

            let request = UNNotificationRequest(identifier: "\(Self.mealPrefix)\(name)", content: content, trigger: trigger)
            center.add(request)
        }
    }

    // MARK: - Bloodwork Reminder

    func scheduleBloodworkReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.bloodworkId])
        guard bloodworkEnabled, isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time to schedule your bloodwork"
        content.body = "It's been \(bloodworkInterval.rawValue) days since your last panel."
        content.sound = .default
        content.categoryIdentifier = ReminderCategory.bloodwork.rawValue

        let interval = TimeInterval(bloodworkInterval.rawValue * 86400)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, interval), repeats: true)

        let request = UNNotificationRequest(identifier: Self.bloodworkId, content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Helpers

    private func doseTimes(for compound: ProtocolCompound) -> [Date] {
        let freq = compound.frequency.lowercased()
        let baseTime = compound.timeOfDay

        if freq.contains("twice") || freq.contains("2x") || freq.contains("bid") {
            let cal = Calendar.current
            let morningComponents = cal.dateComponents([.hour, .minute], from: baseTime)
            let morning = cal.date(from: morningComponents) ?? baseTime

            var eveningComponents = morningComponents
            eveningComponents.hour = (morningComponents.hour ?? 8) + 12
            if (eveningComponents.hour ?? 20) >= 24 {
                eveningComponents.hour = (eveningComponents.hour ?? 20) - 24
            }
            let evening = cal.date(from: eveningComponents) ?? baseTime

            return [morning, evening]
        }

        return [baseTime]
    }

    private func formatDose(_ mcg: Double, compoundName: String = "") -> String {
        CompoundUnitHelper.displayDoseShort(mcg, for: compoundName)
    }

    // MARK: - Persistence

    private func saveToDisk() {
        defaults.set(hydrationEnabled, forKey: "reminder_hydration_enabled")
        defaults.set(restDayEnabled, forKey: "reminder_restday_enabled")
        defaults.set(weeklyCheckInEnabled, forKey: "reminder_weekly_checkin_enabled")
        defaults.set(hydrationTimes.map { $0.timeIntervalSinceReferenceDate }, forKey: "reminder_hydration_times")
        defaults.set(restDayCheckTime.timeIntervalSinceReferenceDate, forKey: "reminder_restday_time")
        defaults.set(weeklyCheckInDay.rawValue, forKey: "reminder_weekly_checkin_day")
        defaults.set(weeklyCheckInTime.timeIntervalSinceReferenceDate, forKey: "reminder_weekly_checkin_time")
        defaults.set(doseEnabled, forKey: "reminder_dose_enabled")
        defaults.set(workoutEnabled, forKey: "reminder_workout_enabled")
        defaults.set(weighInEnabled, forKey: "reminder_weighin_enabled")
        defaults.set(mealLoggingEnabled, forKey: "reminder_meal_enabled")
        defaults.set(bloodworkEnabled, forKey: "reminder_bloodwork_enabled")
        defaults.set(workoutTime.timeIntervalSinceReferenceDate, forKey: "reminder_workout_time")
        defaults.set(weighInDay.rawValue, forKey: "reminder_weighin_day")
        defaults.set(weighInTime.timeIntervalSinceReferenceDate, forKey: "reminder_weighin_time")
        defaults.set(breakfastTime.timeIntervalSinceReferenceDate, forKey: "reminder_breakfast_time")
        defaults.set(lunchTime.timeIntervalSinceReferenceDate, forKey: "reminder_lunch_time")
        defaults.set(dinnerTime.timeIntervalSinceReferenceDate, forKey: "reminder_dinner_time")
        defaults.set(bloodworkInterval.rawValue, forKey: "reminder_bloodwork_interval")
        defaults.set(bloodworkTime.timeIntervalSinceReferenceDate, forKey: "reminder_bloodwork_time")
        defaults.set(reminderStyle.rawValue, forKey: "reminder_style")
        defaults.set(morningBriefTime.timeIntervalSinceReferenceDate, forKey: "reminder_morning_brief_time")
        defaults.set(doseReminderTime.timeIntervalSinceReferenceDate, forKey: "reminder_dose_reminder_time")
    }

    private func loadFromDisk() {
        if defaults.object(forKey: "reminder_dose_enabled") != nil {
            doseEnabled = defaults.bool(forKey: "reminder_dose_enabled")
        }
        if defaults.object(forKey: "reminder_workout_enabled") != nil {
            workoutEnabled = defaults.bool(forKey: "reminder_workout_enabled")
        }
        if defaults.object(forKey: "reminder_weighin_enabled") != nil {
            weighInEnabled = defaults.bool(forKey: "reminder_weighin_enabled")
        }
        if defaults.object(forKey: "reminder_meal_enabled") != nil {
            mealLoggingEnabled = defaults.bool(forKey: "reminder_meal_enabled")
        }
        if defaults.object(forKey: "reminder_bloodwork_enabled") != nil {
            bloodworkEnabled = defaults.bool(forKey: "reminder_bloodwork_enabled")
        }

        if defaults.object(forKey: "reminder_workout_time") != nil {
            workoutTime = Date(timeIntervalSinceReferenceDate: defaults.double(forKey: "reminder_workout_time"))
        }
        if defaults.object(forKey: "reminder_weighin_day") != nil {
            weighInDay = WeighInDay(rawValue: defaults.integer(forKey: "reminder_weighin_day")) ?? .monday
        }
        if defaults.object(forKey: "reminder_weighin_time") != nil {
            weighInTime = Date(timeIntervalSinceReferenceDate: defaults.double(forKey: "reminder_weighin_time"))
        }
        if defaults.object(forKey: "reminder_breakfast_time") != nil {
            breakfastTime = Date(timeIntervalSinceReferenceDate: defaults.double(forKey: "reminder_breakfast_time"))
        }
        if defaults.object(forKey: "reminder_lunch_time") != nil {
            lunchTime = Date(timeIntervalSinceReferenceDate: defaults.double(forKey: "reminder_lunch_time"))
        }
        if defaults.object(forKey: "reminder_dinner_time") != nil {
            dinnerTime = Date(timeIntervalSinceReferenceDate: defaults.double(forKey: "reminder_dinner_time"))
        }
        if defaults.object(forKey: "reminder_bloodwork_interval") != nil {
            bloodworkInterval = BloodworkInterval(rawValue: defaults.integer(forKey: "reminder_bloodwork_interval")) ?? .days30
        }
        if defaults.object(forKey: "reminder_bloodwork_time") != nil {
            bloodworkTime = Date(timeIntervalSinceReferenceDate: defaults.double(forKey: "reminder_bloodwork_time"))
        }
        if defaults.object(forKey: "reminder_hydration_enabled") != nil {
            hydrationEnabled = defaults.bool(forKey: "reminder_hydration_enabled")
        }
        if defaults.object(forKey: "reminder_restday_enabled") != nil {
            restDayEnabled = defaults.bool(forKey: "reminder_restday_enabled")
        }
        if defaults.object(forKey: "reminder_weekly_checkin_enabled") != nil {
            weeklyCheckInEnabled = defaults.bool(forKey: "reminder_weekly_checkin_enabled")
        }
        if let arr = defaults.array(forKey: "reminder_hydration_times") as? [Double], !arr.isEmpty {
            hydrationTimes = arr.map { Date(timeIntervalSinceReferenceDate: $0) }
        }
        if defaults.object(forKey: "reminder_restday_time") != nil {
            restDayCheckTime = Date(timeIntervalSinceReferenceDate: defaults.double(forKey: "reminder_restday_time"))
        }
        if defaults.object(forKey: "reminder_weekly_checkin_day") != nil {
            weeklyCheckInDay = WeighInDay(rawValue: defaults.integer(forKey: "reminder_weekly_checkin_day")) ?? .sunday
        }
        if defaults.object(forKey: "reminder_weekly_checkin_time") != nil {
            weeklyCheckInTime = Date(timeIntervalSinceReferenceDate: defaults.double(forKey: "reminder_weekly_checkin_time"))
        }
        if let raw = defaults.string(forKey: "reminder_style"),
           let style = ReminderStyle(rawValue: raw) {
            reminderStyle = style
        }
        if defaults.object(forKey: "reminder_morning_brief_time") != nil {
            morningBriefTime = Date(timeIntervalSinceReferenceDate: defaults.double(forKey: "reminder_morning_brief_time"))
        }
        if defaults.object(forKey: "reminder_dose_reminder_time") != nil {
            doseReminderTime = Date(timeIntervalSinceReferenceDate: defaults.double(forKey: "reminder_dose_reminder_time"))
        }
    }
}
