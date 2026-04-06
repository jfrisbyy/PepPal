import SwiftUI

nonisolated enum TaskCategory: String, CaseIterable, Identifiable, Sendable, Codable {
    case fitness = "Fitness"
    case nutrition = "Nutrition"
    case wellness = "Wellness"
    case lifestyle = "Lifestyle"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .fitness: return "figure.run"
        case .nutrition: return "fork.knife"
        case .wellness: return "heart.fill"
        case .lifestyle: return "sun.max.fill"
        }
    }

    var color: Color {
        switch self {
        case .fitness: return PepTheme.teal
        case .nutrition: return Color(red: 0.3, green: 0.85, blue: 0.4)
        case .wellness: return Color(red: 1.0, green: 0.45, blue: 0.5)
        case .lifestyle: return PepTheme.amber
        }
    }
}

nonisolated enum TaskScheduleType: String, CaseIterable, Identifiable, Sendable, Codable {
    case daily = "Daily"
    case customDays = "Custom Days"
    case oneTime = "One Time"

    var id: String { rawValue }
}

nonisolated enum Weekday: Int, CaseIterable, Identifiable, Sendable, Codable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }

    var initial: String {
        switch self {
        case .sunday: return "S"
        case .monday: return "M"
        case .tuesday: return "T"
        case .wednesday: return "W"
        case .thursday: return "T"
        case .friday: return "F"
        case .saturday: return "S"
        }
    }
}

nonisolated enum TaskActionLink: String, CaseIterable, Identifiable, Sendable, Codable {
    case none = "None"
    case stepCounter = "Step Counter"
    case proteinGoal = "Protein Goal"
    case calorieGoal = "Calorie Goal"
    case workoutCompleted = "Workout Completed"
    case waterIntake = "Water Intake"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .none: return "hand.tap"
        case .stepCounter: return "figure.walk"
        case .proteinGoal: return "fish.fill"
        case .calorieGoal: return "flame.fill"
        case .workoutCompleted: return "dumbbell.fill"
        case .waterIntake: return "drop.fill"
        }
    }

    var description: String {
        switch self {
        case .none: return "Manual toggle"
        case .stepCounter: return "Auto-completes when step goal is reached"
        case .proteinGoal: return "Auto-completes when protein target is hit"
        case .calorieGoal: return "Auto-completes when calorie target is hit"
        case .workoutCompleted: return "Auto-completes after a workout"
        case .waterIntake: return "Auto-completes when water goal is met"
        }
    }
}

struct DailyTask: Identifiable, Sendable {
    let id: UUID
    var name: String
    var icon: String
    var category: TaskCategory
    var isCompleted: Bool
    var scheduleType: TaskScheduleType
    var scheduledDays: Set<Weekday>
    var oneTimeDate: Date?
    var actionLink: TaskActionLink
    var actionTarget: Int
    var isUserCreated: Bool

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        category: TaskCategory,
        isCompleted: Bool = false,
        scheduleType: TaskScheduleType = .daily,
        scheduledDays: Set<Weekday> = Set(Weekday.allCases),
        oneTimeDate: Date? = nil,
        actionLink: TaskActionLink = .none,
        actionTarget: Int = 0,
        isUserCreated: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.category = category
        self.isCompleted = isCompleted
        self.scheduleType = scheduleType
        self.scheduledDays = scheduledDays
        self.oneTimeDate = oneTimeDate
        self.actionLink = actionLink
        self.actionTarget = actionTarget
        self.isUserCreated = isUserCreated
    }

    func isScheduledForToday() -> Bool {
        let calendar = Calendar.current
        switch scheduleType {
        case .daily:
            return true
        case .customDays:
            let todayComponent = calendar.component(.weekday, from: Date())
            guard let todayWeekday = Weekday(rawValue: todayComponent) else { return false }
            return scheduledDays.contains(todayWeekday)
        case .oneTime:
            guard let date = oneTimeDate else { return false }
            return calendar.isDateInToday(date)
        }
    }
}

enum DailyTaskLibrary {
    static func defaultTasks() -> [DailyTask] {
        [
            DailyTask(name: "Complete Workout", icon: "dumbbell.fill", category: .fitness, actionLink: .workoutCompleted),
            DailyTask(name: "10,000 Steps", icon: "figure.walk", category: .fitness, actionLink: .stepCounter, actionTarget: 10000),
            DailyTask(name: "30 Min Cardio", icon: "figure.run", category: .fitness),
            DailyTask(name: "Stretch 15 Min", icon: "figure.flexibility", category: .fitness),

            DailyTask(name: "Drink Gallon of Water", icon: "drop.fill", category: .nutrition, actionLink: .waterIntake),
            DailyTask(name: "Hit Protein Goal", icon: "fish.fill", category: .nutrition, actionLink: .proteinGoal),
            DailyTask(name: "Log All Meals", icon: "list.clipboard.fill", category: .nutrition),
            DailyTask(name: "No Processed Sugar", icon: "leaf.fill", category: .nutrition),

            DailyTask(name: "8 Hours Sleep", icon: "moon.fill", category: .wellness),
            DailyTask(name: "Meditate 10 Min", icon: "brain.head.profile.fill", category: .wellness),
            DailyTask(name: "Cold Shower", icon: "snowflake", category: .wellness),
            DailyTask(name: "Journal Entry", icon: "book.fill", category: .wellness),

            DailyTask(name: "Read 20 Pages", icon: "text.book.closed.fill", category: .lifestyle),
            DailyTask(name: "No Social Media 1hr", icon: "iphone.slash", category: .lifestyle),
            DailyTask(name: "Take Vitamins", icon: "pills.fill", category: .lifestyle),
        ]
    }
}
