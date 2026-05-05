import Foundation

nonisolated struct TitrationScheduleStep: Codable, Sendable, Identifiable, Hashable {
    var id: UUID
    var week: Int
    var doseMcg: Double
    var label: String

    init(id: UUID = UUID(), week: Int, doseMcg: Double, label: String = "") {
        self.id = id
        self.week = week
        self.doseMcg = doseMcg
        self.label = label
    }
}

nonisolated struct TitrationSchedule: Codable, Sendable, Identifiable {
    var id: UUID
    var protocolId: UUID
    var compoundName: String
    var startDate: Date
    var steps: [TitrationScheduleStep]
    var remindersEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int
    var autoAdvanceDose: Bool

    init(
        id: UUID = UUID(),
        protocolId: UUID,
        compoundName: String,
        startDate: Date = Date(),
        steps: [TitrationScheduleStep],
        remindersEnabled: Bool = true,
        reminderHour: Int = 9,
        reminderMinute: Int = 0,
        autoAdvanceDose: Bool = true
    ) {
        self.id = id
        self.protocolId = protocolId
        self.compoundName = compoundName
        self.startDate = startDate
        self.steps = steps.sorted(by: { $0.week < $1.week })
        self.remindersEnabled = remindersEnabled
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.autoAdvanceDose = autoAdvanceDose
    }

    var sortedSteps: [TitrationScheduleStep] { steps.sorted { $0.week < $1.week } }

    func currentStep(on date: Date = Date()) -> TitrationScheduleStep? {
        let days = max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: startDate), to: Calendar.current.startOfDay(for: date)).day ?? 0)
        let weeksElapsed = days / 7 + 1
        let active = sortedSteps.last(where: { $0.week <= weeksElapsed })
        return active ?? sortedSteps.first
    }

    func nextStep(after date: Date = Date()) -> TitrationScheduleStep? {
        guard let current = currentStep(on: date) else { return nil }
        return sortedSteps.first(where: { $0.week > current.week })
    }

    func startDate(for step: TitrationScheduleStep) -> Date {
        let cal = Calendar.current
        let base = cal.startOfDay(for: startDate)
        return cal.date(byAdding: .day, value: (step.week - 1) * 7, to: base) ?? base
    }
}
