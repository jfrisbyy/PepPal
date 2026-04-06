import SwiftUI

nonisolated enum TaskCategory: String, CaseIterable, Identifiable, Sendable {
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

struct DailyTask: Identifiable, Sendable {
    let id: UUID
    let name: String
    let icon: String
    let points: Int
    let category: TaskCategory
    var isCompleted: Bool

    init(id: UUID = UUID(), name: String, icon: String, points: Int, category: TaskCategory, isCompleted: Bool = false) {
        self.id = id
        self.name = name
        self.icon = icon
        self.points = points
        self.category = category
        self.isCompleted = isCompleted
    }
}

enum DailyTaskLibrary {
    static func defaultTasks() -> [DailyTask] {
        [
            DailyTask(name: "Complete Workout", icon: "dumbbell.fill", points: 150, category: .fitness),
            DailyTask(name: "10,000 Steps", icon: "figure.walk", points: 100, category: .fitness),
            DailyTask(name: "30 Min Cardio", icon: "figure.run", points: 120, category: .fitness),
            DailyTask(name: "Stretch 15 Min", icon: "figure.flexibility", points: 50, category: .fitness),
            DailyTask(name: "Log Sport Session", icon: "sportscourt.fill", points: 130, category: .fitness),

            DailyTask(name: "Drink Gallon of Water", icon: "drop.fill", points: 80, category: .nutrition),
            DailyTask(name: "Hit Protein Goal", icon: "fish.fill", points: 100, category: .nutrition),
            DailyTask(name: "Log All Meals", icon: "list.clipboard.fill", points: 60, category: .nutrition),
            DailyTask(name: "No Processed Sugar", icon: "leaf.fill", points: 70, category: .nutrition),
            DailyTask(name: "Eat 5 Servings Veggies", icon: "carrot.fill", points: 60, category: .nutrition),

            DailyTask(name: "8 Hours Sleep", icon: "moon.fill", points: 100, category: .wellness),
            DailyTask(name: "Meditate 10 Min", icon: "brain.head.profile.fill", points: 60, category: .wellness),
            DailyTask(name: "Cold Shower", icon: "snowflake", points: 80, category: .wellness),
            DailyTask(name: "Journal Entry", icon: "book.fill", points: 50, category: .wellness),
            DailyTask(name: "No Alcohol", icon: "xmark.circle.fill", points: 40, category: .wellness),

            DailyTask(name: "Read 20 Pages", icon: "text.book.closed.fill", points: 50, category: .lifestyle),
            DailyTask(name: "No Social Media 1hr", icon: "iphone.slash", points: 40, category: .lifestyle),
            DailyTask(name: "Wake Before 7 AM", icon: "alarm.fill", points: 60, category: .lifestyle),
            DailyTask(name: "Take Vitamins", icon: "pills.fill", points: 30, category: .lifestyle),
            DailyTask(name: "Walk the Dog", icon: "dog.fill", points: 50, category: .lifestyle),
        ]
    }
}
