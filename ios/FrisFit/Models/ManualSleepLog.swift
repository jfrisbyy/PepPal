import Foundation

nonisolated struct ManualSleepLog: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    var night: Date
    var bedtime: Date?
    var wakeTime: Date?
    var hours: Double
    var quality: Int?       // 1...10
    var notes: String?
    var supabaseId: String?

    init(
        id: UUID = UUID(),
        night: Date,
        bedtime: Date? = nil,
        wakeTime: Date? = nil,
        hours: Double,
        quality: Int? = nil,
        notes: String? = nil,
        supabaseId: String? = nil
    ) {
        self.id = id
        self.night = night
        self.bedtime = bedtime
        self.wakeTime = wakeTime
        self.hours = hours
        self.quality = quality
        self.notes = notes
        self.supabaseId = supabaseId
    }

    var qualityLabel: String? {
        guard let q = quality else { return nil }
        switch q {
        case ...2: return "Restless"
        case 3...4: return "Poor"
        case 5...6: return "OK"
        case 7...8: return "Good"
        default: return "Excellent"
        }
    }
}
