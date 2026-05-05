import Foundation

nonisolated enum MarketItemType: String, CaseIterable, Identifiable, Sendable, Codable {
    case workoutSplit = "Workout Split"
    case timedProgram = "Timed Program"
    case nutritionPlan = "Nutrition Plan"
    case bundle = "Bundle"

    var id: String { rawValue }

    var accentColor: String {
        switch self {
        case .workoutSplit: "cyan"
        case .timedProgram: "amber"
        case .nutritionPlan: "green"
        case .bundle: "gradient"
        }
    }
}

nonisolated enum MarketDifficulty: String, CaseIterable, Sendable, Codable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
}

nonisolated struct MarketCreator: Identifiable, Sendable {
    let id: UUID
    let name: String
    let avatarSystemName: String
    let followerCount: Int
    let programsPublished: Int
    let averageRating: Double
    let bio: String

    init(name: String, avatarSystemName: String = "person.crop.circle.fill", followerCount: Int, programsPublished: Int, averageRating: Double, bio: String) {
        self.id = UUID()
        self.name = name
        self.avatarSystemName = avatarSystemName
        self.followerCount = followerCount
        self.programsPublished = programsPublished
        self.averageRating = averageRating
        self.bio = bio
    }
}

nonisolated struct MarketReview: Identifiable, Sendable {
    let id: UUID
    let userName: String
    let rating: Int
    let text: String
    let date: Date

    init(userName: String, rating: Int, text: String, daysAgo: Int) {
        self.id = UUID()
        self.userName = userName
        self.rating = rating
        self.text = text
        self.date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
    }
}

nonisolated struct MarketProgram: Identifiable, Sendable {
    let id: UUID
    let title: String
    let creatorName: String
    let creatorId: UUID
    let rating: Double
    let reviewCount: Int
    let itemType: MarketItemType
    let difficulty: MarketDifficulty
    let durationWeeks: Int
    let daysPerWeek: Int
    let equipment: String
    let overview: String
    let gradientColors: [GradientColor]
    let iconName: String
    let isFeatured: Bool
    let reviews: [MarketReview]
    let scheduleSummary: [ScheduleDay]

    init(
        title: String,
        creatorName: String,
        creatorId: UUID,
        rating: Double,
        reviewCount: Int,
        itemType: MarketItemType,
        difficulty: MarketDifficulty,
        durationWeeks: Int,
        daysPerWeek: Int,
        equipment: String,
        totalFP: Int,
        overview: String,
        gradientColors: [GradientColor],
        iconName: String,
        isFeatured: Bool = false,
        reviews: [MarketReview] = [],
        scheduleSummary: [ScheduleDay] = []
    ) {
        self.id = UUID()
        self.title = title
        self.creatorName = creatorName
        self.creatorId = creatorId
        self.rating = rating
        self.reviewCount = reviewCount
        self.itemType = itemType
        self.difficulty = difficulty
        self.durationWeeks = durationWeeks
        self.daysPerWeek = daysPerWeek
        self.equipment = equipment
        _ = totalFP
        self.overview = overview
        self.gradientColors = gradientColors
        self.iconName = iconName
        self.isFeatured = isFeatured
        self.reviews = reviews
        self.scheduleSummary = scheduleSummary
    }
}

nonisolated struct GradientColor: Sendable {
    let r: Double
    let g: Double
    let b: Double

    init(_ r: Double, _ g: Double, _ b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }
}

nonisolated struct ScheduleDay: Identifiable, Sendable {
    let id: UUID
    let dayName: String
    let focus: String
    let exerciseCount: Int

    init(dayName: String, focus: String, exerciseCount: Int) {
        self.id = UUID()
        self.dayName = dayName
        self.focus = focus
        self.exerciseCount = exerciseCount
    }
}
