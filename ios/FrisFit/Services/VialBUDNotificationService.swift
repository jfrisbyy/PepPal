import UserNotifications
import Foundation

nonisolated final class VialBUDNotificationService: Sendable {
    static let shared = VialBUDNotificationService()

    func scheduleBUDReminder(for vial: Vial) {
        guard let bud = vial.budDate else { return }
        let remindAt = Calendar.current.date(byAdding: .day, value: -1, to: bud) ?? bud
        guard remindAt > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Vial expiring tomorrow"
        content.body = "\(vial.compoundName) reaches its beyond-use date in 24h. Plan a swap or discard."
        content.sound = .default
        content.categoryIdentifier = "vial.bud"
        content.threadIdentifier = "vial.bud.\(vial.id.uuidString)"

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: remindAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: "vial.bud.\(vial.id.uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)

        if let exp = vial.expirationDate, exp > Date() {
            let expRemindAt = Calendar.current.date(byAdding: .day, value: -3, to: exp) ?? exp
            if expRemindAt > Date() {
                let c = UNMutableNotificationContent()
                c.title = "Vial expiration approaching"
                c.body = "\(vial.compoundName) (Lot \(vial.lotNumber.isEmpty ? "—" : vial.lotNumber)) expires in 3 days."
                c.sound = .default
                let expComps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: expRemindAt)
                let expTrigger = UNCalendarNotificationTrigger(dateMatching: expComps, repeats: false)
                let expReq = UNNotificationRequest(identifier: "vial.exp.\(vial.id.uuidString)", content: c, trigger: expTrigger)
                UNUserNotificationCenter.current().add(expReq)
            }
        }
    }

    func cancel(for vial: Vial) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "vial.bud.\(vial.id.uuidString)",
            "vial.exp.\(vial.id.uuidString)"
        ])
    }

    @MainActor
    func requestAuthIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
    }
}
