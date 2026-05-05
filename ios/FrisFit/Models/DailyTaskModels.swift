import SwiftUI

nonisolated enum TaskCategory: String, CaseIterable, Identifiable, Sendable, Codable {
    case fitness = "Fitness"
    case nutrition = "Nutrition"
    case wellness = "Wellness"
    case lifestyle = "Lifestyle"
    case custom = "Custom"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .fitness: return "figure.run"
        case .nutrition: return "fork.knife"
        case .wellness: return "heart.fill"
        case .lifestyle: return "sun.max.fill"
        case .custom: return "folder.fill"
        }
    }

    var color: Color {
        switch self {
        case .fitness: return PepTheme.teal
        case .nutrition: return Color(red: 0.3, green: 0.85, blue: 0.4)
        case .wellness: return Color(red: 1.0, green: 0.45, blue: 0.5)
        case .lifestyle: return PepTheme.amber
        case .custom: return PepTheme.violet
        }
    }

    static var builtInCases: [TaskCategory] {
        [.fitness, .nutrition, .wellness, .lifestyle]
    }
}

nonisolated struct CustomTaskCategory: Identifiable, Sendable, Codable, Hashable {
    let id: UUID
    var name: String
    var icon: String
    var colorHex: String

    init(id: UUID = UUID(), name: String, icon: String, colorHex: String = "8B5CF6") {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
    }

    var color: Color {
        Color(hex: colorHex) ?? PepTheme.violet
    }
}

extension Color {
    nonisolated init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6 else { return nil }
        var rgbValue: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgbValue)
        self.init(
            red: Double((rgbValue >> 16) & 0xFF) / 255.0,
            green: Double((rgbValue >> 8) & 0xFF) / 255.0,
            blue: Double(rgbValue & 0xFF) / 255.0
        )
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

nonisolated enum ActionLinkGroup: String, CaseIterable, Identifiable, Sendable {
    case manual = "Manual"
    case fitness = "Fitness"
    case nutrition = "Nutrition"
    case sports = "Sports"

    var id: String { rawValue }

    var links: [TaskActionLink] {
        switch self {
        case .manual: return [.none]
        case .fitness: return [.stepCounter, .workoutCompleted, .waterIntake]
        case .nutrition: return [.proteinGoal, .calorieGoal, .carbGoal, .fatGoal, .fiberGoal, .sugarGoal]
        case .sports: return [.runningSession, .cyclingSession, .swimmingSession, .basketballSession, .soccerSession, .tennisSession, .footballSession, .yogaSession]
        }
    }
}

nonisolated enum TaskActionLink: String, CaseIterable, Identifiable, Sendable, Codable {
    case none = "None"
    case stepCounter = "Step Counter"
    case proteinGoal = "Protein Goal"
    case calorieGoal = "Calorie Goal"
    case carbGoal = "Carb Goal"
    case fatGoal = "Fat Goal"
    case fiberGoal = "Fiber Goal"
    case sugarGoal = "Sugar Goal"
    case workoutCompleted = "Workout Completed"
    case waterIntake = "Water Intake"
    case runningSession = "Running"
    case cyclingSession = "Cycling"
    case swimmingSession = "Swimming"
    case basketballSession = "Basketball"
    case soccerSession = "Soccer"
    case tennisSession = "Tennis"
    case footballSession = "Football"
    case yogaSession = "Yoga"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .none: return "hand.tap"
        case .stepCounter: return "figure.walk"
        case .proteinGoal: return "fish.fill"
        case .calorieGoal: return "flame.fill"
        case .carbGoal: return "carrot.fill"
        case .fatGoal: return "drop.triangle.fill"
        case .fiberGoal: return "leaf.fill"
        case .sugarGoal: return "cube.fill"
        case .workoutCompleted: return "dumbbell.fill"
        case .waterIntake: return "drop.fill"
        case .runningSession: return "figure.run"
        case .cyclingSession: return "figure.outdoor.cycle"
        case .swimmingSession: return "figure.pool.swim"
        case .basketballSession: return "basketball.fill"
        case .soccerSession: return "soccerball"
        case .tennisSession: return "tennis.racket"
        case .footballSession: return "football.fill"
        case .yogaSession: return "figure.yoga"
        }
    }

    var description: String {
        switch self {
        case .none: return "Manual toggle"
        case .stepCounter: return "Auto-completes at step goal"
        case .proteinGoal: return "Auto-completes at protein target"
        case .calorieGoal: return "Auto-completes at calorie target"
        case .carbGoal: return "Auto-completes at carb target"
        case .fatGoal: return "Auto-completes at fat target"
        case .fiberGoal: return "Auto-completes at fiber target"
        case .sugarGoal: return "Auto-completes at sugar limit"
        case .workoutCompleted: return "Auto-completes after a workout"
        case .waterIntake: return "Auto-completes at water goal"
        case .runningSession: return "Auto-completes after a run"
        case .cyclingSession: return "Auto-completes after a ride"
        case .swimmingSession: return "Auto-completes after a swim"
        case .basketballSession: return "Auto-completes after basketball"
        case .soccerSession: return "Auto-completes after soccer"
        case .tennisSession: return "Auto-completes after tennis"
        case .footballSession: return "Auto-completes after football"
        case .yogaSession: return "Auto-completes after yoga"
        }
    }

    var group: ActionLinkGroup {
        switch self {
        case .none: return .manual
        case .stepCounter, .workoutCompleted, .waterIntake: return .fitness
        case .proteinGoal, .calorieGoal, .carbGoal, .fatGoal, .fiberGoal, .sugarGoal: return .nutrition
        case .runningSession, .cyclingSession, .swimmingSession, .basketballSession, .soccerSession, .tennisSession, .footballSession, .yogaSession: return .sports
        }
    }

    var hasCustomTarget: Bool {
        switch self {
        case .stepCounter, .proteinGoal, .calorieGoal, .carbGoal, .fatGoal, .fiberGoal, .sugarGoal, .waterIntake:
            return true
        default:
            return false
        }
    }

    var supportsGoalDescription: Bool {
        switch self {
        case .runningSession, .cyclingSession, .swimmingSession, .basketballSession,
             .soccerSession, .tennisSession, .footballSession, .yogaSession,
             .workoutCompleted:
            return true
        default:
            return false
        }
    }

    var goalPlaceholder: String {
        switch self {
        case .runningSession: return "e.g. Run 1 mile, Run for 30 min"
        case .cyclingSession: return "e.g. Ride 10 miles, Ride for 45 min"
        case .swimmingSession: return "e.g. Swim 20 laps, Swim for 30 min"
        case .basketballSession: return "e.g. Play 1 hour, Shoot 100 free throws"
        case .soccerSession: return "e.g. Play 90 min, Run 3 miles"
        case .tennisSession: return "e.g. Play 3 sets, Hit for 1 hour"
        case .footballSession: return "e.g. Practice 1 hour, Run drills"
        case .yogaSession: return "e.g. 30 min session, Complete flow"
        case .workoutCompleted: return "e.g. Push day, Leg day, Full body"
        default: return "Describe your goal"
        }
    }

    var targetLabel: String {
        switch self {
        case .stepCounter: return "Step Goal"
        case .proteinGoal: return "Protein (g)"
        case .calorieGoal: return "Calories"
        case .carbGoal: return "Carbs (g)"
        case .fatGoal: return "Fat (g)"
        case .fiberGoal: return "Fiber (g)"
        case .sugarGoal: return "Sugar (g)"
        case .waterIntake: return "Water (oz)"
        default: return ""
        }
    }

    var targetPlaceholder: String {
        switch self {
        case .stepCounter: return "10000"
        case .proteinGoal: return "150"
        case .calorieGoal: return "2200"
        case .carbGoal: return "250"
        case .fatGoal: return "70"
        case .fiberGoal: return "30"
        case .sugarGoal: return "50"
        case .waterIntake: return "128"
        default: return ""
        }
    }

    var targetUnit: String {
        switch self {
        case .stepCounter: return "steps"
        case .proteinGoal: return "g"
        case .calorieGoal: return "cal"
        case .carbGoal: return "g"
        case .fatGoal: return "g"
        case .fiberGoal: return "g"
        case .sugarGoal: return "g"
        case .waterIntake: return "oz"
        default: return ""
        }
    }
}

nonisolated enum LinkedTaskQuickAction: Sendable {
    case logMeal
    case logActivity
    case startWorkout
    case viewSteps
    case none

    var label: String {
        switch self {
        case .logMeal: return "Log a Meal"
        case .logActivity: return "Log Activity"
        case .startWorkout: return "Start Workout"
        case .viewSteps: return "View Steps"
        case .none: return ""
        }
    }

    var icon: String {
        switch self {
        case .logMeal: return "fork.knife"
        case .logActivity: return "figure.run"
        case .startWorkout: return "dumbbell.fill"
        case .viewSteps: return "figure.walk"
        case .none: return ""
        }
    }
}

extension TaskActionLink {
    var quickAction: LinkedTaskQuickAction {
        switch self {
        case .proteinGoal, .calorieGoal, .carbGoal, .fatGoal, .fiberGoal, .sugarGoal, .waterIntake:
            return .logMeal
        case .workoutCompleted:
            return .startWorkout
        case .stepCounter:
            return .viewSteps
        case .runningSession, .cyclingSession, .swimmingSession, .basketballSession,
             .soccerSession, .tennisSession, .footballSession, .yogaSession:
            return .logActivity
        case .none:
            return .none
        }
    }

    var autoCompleteMessage: String {
        switch self {
        case .proteinGoal: return "This task auto-completes when you hit your protein target. Log a meal to get closer."
        case .calorieGoal: return "This task auto-completes when you reach your calorie target. Log a meal to update progress."
        case .carbGoal: return "This task auto-completes when you hit your carb target. Log a meal to update progress."
        case .fatGoal: return "This task auto-completes when you hit your fat target. Log a meal to update progress."
        case .fiberGoal: return "This task auto-completes when you hit your fiber target. Log a meal to update progress."
        case .sugarGoal: return "This task auto-completes when you stay under your sugar limit. Log meals to track it."
        case .waterIntake: return "This task auto-completes when you hit your water goal."
        case .workoutCompleted: return "This task auto-completes after you finish today's workout."
        case .stepCounter: return "This task auto-completes when you hit your step goal. Steps are tracked automatically via Apple Health."
        case .runningSession, .cyclingSession, .swimmingSession, .basketballSession,
             .soccerSession, .tennisSession, .footballSession, .yogaSession:
            return "This task auto-completes after you log a matching activity."
        case .none: return ""
        }
    }
}

nonisolated enum TaskSource: String, Sendable, Codable {
    case user
    case scheduled
    case typical
    case aiSuggested
    case protocolDeck

    var label: String {
        switch self {
        case .user: return "You"
        case .scheduled: return "Scheduled"
        case .typical: return "Goal"
        case .aiSuggested: return "AI"
        case .protocolDeck: return "Protocol"
        }
    }

    var icon: String {
        switch self {
        case .user: return "person.fill"
        case .scheduled: return "calendar"
        case .typical: return "target"
        case .aiSuggested: return "sparkles"
        case .protocolDeck: return "pill.fill"
        }
    }

    var color: Color {
        switch self {
        case .user: return PepTheme.textSecondary
        case .scheduled: return PepTheme.blue
        case .typical: return PepTheme.amber
        case .aiSuggested: return PepTheme.violet
        case .protocolDeck: return PepTheme.teal
        }
    }

    var isSynthetic: Bool {
        self != .user
    }
}

struct DailyTask: Identifiable, Sendable {
    let id: UUID
    var name: String
    var icon: String
    var category: TaskCategory
    var customCategoryId: UUID?
    var isCompleted: Bool
    var scheduleType: TaskScheduleType
    var scheduledDays: Set<Weekday>
    var oneTimeDate: Date?
    var actionLink: TaskActionLink
    var actionTarget: Int
    var goalDescription: String
    var isUserCreated: Bool
    var isProtocolRecommended: Bool
    var protocolReason: String
    var source: TaskSource
    var aiUrgency: DeckUrgency?
    var aiEvidence: [EvidencePoint]
    var aiSuggestionId: String?

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        category: TaskCategory,
        customCategoryId: UUID? = nil,
        isCompleted: Bool = false,
        scheduleType: TaskScheduleType = .daily,
        scheduledDays: Set<Weekday> = Set(Weekday.allCases),
        oneTimeDate: Date? = nil,
        actionLink: TaskActionLink = .none,
        actionTarget: Int = 0,
        goalDescription: String = "",
        isUserCreated: Bool = false,
        isProtocolRecommended: Bool = false,
        protocolReason: String = "",
        source: TaskSource = .user,
        aiUrgency: DeckUrgency? = nil,
        aiEvidence: [EvidencePoint] = [],
        aiSuggestionId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.category = category
        self.customCategoryId = customCategoryId
        self.isCompleted = isCompleted
        self.scheduleType = scheduleType
        self.scheduledDays = scheduledDays
        self.oneTimeDate = oneTimeDate
        self.actionLink = actionLink
        self.actionTarget = actionTarget
        self.goalDescription = goalDescription
        self.isUserCreated = isUserCreated
        self.isProtocolRecommended = isProtocolRecommended
        self.protocolReason = protocolReason
        self.source = source
        self.aiUrgency = aiUrgency
        self.aiEvidence = aiEvidence
        self.aiSuggestionId = aiSuggestionId
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

            DailyTask(name: "Drink Gallon of Water", icon: "drop.fill", category: .nutrition, actionLink: .waterIntake, actionTarget: 128),
            DailyTask(name: "Hit Protein Goal", icon: "fish.fill", category: .nutrition, actionLink: .proteinGoal, actionTarget: 150),
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
