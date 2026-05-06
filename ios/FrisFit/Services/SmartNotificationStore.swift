import Foundation
import SwiftUI

/// Persisted store for the smart notification system: user settings + a rolling
/// 30-day in-app history of fired/received notifications.
@Observable
final class SmartNotificationStore {
    static let shared = SmartNotificationStore()

    var settings: SmartNotificationSettings {
        didSet { persistSettings() }
    }
    var log: [SmartNotificationLogEntry] = []

    private let settingsKey = "smartNotif.settings.v1"
    private let logKey = "smartNotif.log.v1"
    private let retention: TimeInterval = 30 * 24 * 60 * 60

    var unreadCount: Int { log.filter { !$0.isRead }.count }

    private init() {
        self.settings = Self.loadSettings(key: settingsKey)
        self.log = Self.loadLog(key: logKey)
        pruneExpired()
    }

    // MARK: Settings

    private func persistSettings() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: settingsKey)
    }

    private static func loadSettings(key: String) -> SmartNotificationSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(SmartNotificationSettings.self, from: data)
        else { return .default }
        return s
    }

    // MARK: Log

    func record(_ entry: SmartNotificationLogEntry) {
        guard settings.isCategoryEnabled(entry.category) else { return }
        // De-dup by id
        if log.contains(where: { $0.id == entry.id }) { return }
        log.insert(entry, at: 0)
        pruneExpired()
        persistLog()
    }

    func markRead(_ id: String) {
        guard let idx = log.firstIndex(where: { $0.id == id }) else { return }
        if log[idx].isRead { return }
        log[idx].isRead = true
        persistLog()
    }

    func markAllRead() {
        var changed = false
        for i in log.indices where !log[i].isRead {
            log[i].isRead = true
            changed = true
        }
        if changed { persistLog() }
    }

    func remove(_ id: String) {
        log.removeAll { $0.id == id }
        persistLog()
    }

    func clearAll() {
        log.removeAll()
        persistLog()
    }

    private func pruneExpired() {
        let cutoff = Date().addingTimeInterval(-retention)
        let before = log.count
        log.removeAll { $0.firedAt < cutoff }
        if log.count != before { persistLog() }
    }

    private func persistLog() {
        guard let data = try? JSONEncoder().encode(log) else { return }
        UserDefaults.standard.set(data, forKey: logKey)
    }

    private static func loadLog(key: String) -> [SmartNotificationLogEntry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let l = try? JSONDecoder().decode([SmartNotificationLogEntry].self, from: data)
        else { return [] }
        return l
    }

    // MARK: Frequency cap accounting

    /// Counts entries fired today across all categories — used to enforce daily cap.
    func todayFiredCount(calendar: Calendar = .current) -> Int {
        log.filter { calendar.isDateInToday($0.firedAt) }.count
    }
}
