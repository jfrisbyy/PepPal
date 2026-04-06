import SwiftUI
import HealthKit

nonisolated enum StepTimePeriod: String, CaseIterable, Identifiable {
    case day = "D"
    case week = "W"
    case month = "M"
    case sixMonths = "6M"
    case year = "Y"

    nonisolated var id: String { rawValue }
}

nonisolated struct HourlyStepData: Identifiable, Sendable {
    let id = UUID()
    let hour: Int
    let steps: Int

    var hourLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        let cal = Calendar.current
        let date = cal.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date).lowercased()
    }
}

nonisolated struct DailyStepData: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let steps: Int

    var shortLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

nonisolated struct WeeklyStepData: Identifiable, Sendable {
    let id = UUID()
    let weekStart: Date
    let steps: Int

    var label: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: weekStart)
    }
}

nonisolated struct MonthlyStepData: Identifiable, Sendable {
    let id = UUID()
    let monthStart: Date
    let steps: Int

    var label: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: monthStart)
    }

    var fullLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: monthStart)
    }
}

@Observable
final class StepDetailViewModel {
    let healthKit = HealthKitService.shared

    var selectedPeriod: StepTimePeriod = .day
    var isLoading: Bool = true

    var hourlySteps: [HourlyStepData] = []
    var dailySteps: [DailyStepData] = []
    var weeklySteps: [WeeklyStepData] = []
    var monthlySteps: [MonthlyStepData] = []

    var todayDistance: Double = 0
    var todayFlights: Int = 0

    var todaySteps: Int { healthKit.steps }

    var stepGoal: Int {
        get { UserDefaults.standard.integer(forKey: "step_goal").clamped(to: 1000...100000, default: 10000) }
        set { UserDefaults.standard.set(newValue, forKey: "step_goal") }
    }

    var todayProgress: Double {
        guard stepGoal > 0 else { return 0 }
        return min(Double(todaySteps) / Double(stepGoal), 1.0)
    }

    var averageSteps: Int {
        switch selectedPeriod {
        case .day:
            let nonZero = hourlySteps.filter { $0.steps > 0 }
            guard !nonZero.isEmpty else { return todaySteps }
            return todaySteps
        case .week:
            let last7 = dailySteps.suffix(7)
            guard !last7.isEmpty else { return 0 }
            return last7.reduce(0) { $0 + $1.steps } / last7.count
        case .month:
            let last30 = dailySteps.suffix(30)
            guard !last30.isEmpty else { return 0 }
            return last30.reduce(0) { $0 + $1.steps } / last30.count
        case .sixMonths:
            guard !weeklySteps.isEmpty else { return 0 }
            let totalDays = weeklySteps.count * 7
            let totalSteps = weeklySteps.reduce(0) { $0 + $1.steps }
            return totalDays > 0 ? totalSteps / totalDays : 0
        case .year:
            guard !monthlySteps.isEmpty else { return 0 }
            let totalSteps = monthlySteps.reduce(0) { $0 + $1.steps }
            let totalMonths = monthlySteps.count
            return totalMonths > 0 ? totalSteps / (totalMonths * 30) : 0
        }
    }

    var totalStepsInPeriod: Int {
        switch selectedPeriod {
        case .day: return todaySteps
        case .week: return dailySteps.suffix(7).reduce(0) { $0 + $1.steps }
        case .month: return dailySteps.suffix(30).reduce(0) { $0 + $1.steps }
        case .sixMonths: return weeklySteps.reduce(0) { $0 + $1.steps }
        case .year: return monthlySteps.reduce(0) { $0 + $1.steps }
        }
    }

    var maxStepsInPeriod: Int {
        switch selectedPeriod {
        case .day: return hourlySteps.map(\.steps).max() ?? 0
        case .week: return dailySteps.suffix(7).map(\.steps).max() ?? 0
        case .month: return dailySteps.suffix(30).map(\.steps).max() ?? 0
        case .sixMonths: return weeklySteps.map(\.steps).max() ?? 0
        case .year: return monthlySteps.map(\.steps).max() ?? 0
        }
    }

    var minStepsInPeriod: Int {
        switch selectedPeriod {
        case .day: return hourlySteps.filter { $0.steps > 0 }.map(\.steps).min() ?? 0
        case .week: return dailySteps.suffix(7).filter { $0.steps > 0 }.map(\.steps).min() ?? 0
        case .month: return dailySteps.suffix(30).filter { $0.steps > 0 }.map(\.steps).min() ?? 0
        case .sixMonths: return weeklySteps.filter { $0.steps > 0 }.map(\.steps).min() ?? 0
        case .year: return monthlySteps.filter { $0.steps > 0 }.map(\.steps).min() ?? 0
        }
    }

    var distanceMiles: Double {
        todayDistance / 1609.344
    }

    func loadData() async {
        isLoading = true

        async let hourly = healthKit.fetchHourlySteps(for: Date())
        async let daily = healthKit.fetchDailySteps(days: 90)
        async let weekly = healthKit.fetchWeeklySteps(weeks: 26)
        async let monthly = healthKit.fetchMonthlySteps(months: 12)
        async let dist = healthKit.fetchDistanceWalking(for: Date())
        async let flights = healthKit.fetchFlightsClimbed(for: Date())

        let (h, d, w, m, di, fl) = await (hourly, daily, weekly, monthly, dist, flights)

        hourlySteps = h.map { HourlyStepData(hour: $0.hour, steps: $0.steps) }
        dailySteps = d.map { DailyStepData(date: $0.date, steps: $0.steps) }
        weeklySteps = w.map { WeeklyStepData(weekStart: $0.weekStart, steps: $0.steps) }
        monthlySteps = m.map { MonthlyStepData(monthStart: $0.monthStart, steps: $0.steps) }
        todayDistance = di
        todayFlights = fl

        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            isLoading = false
        }
    }

    func refreshSteps() async {
        await healthKit.fetchAllData()
        await loadData()
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>, default defaultValue: Int) -> Int {
        if self == 0 { return defaultValue }
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
