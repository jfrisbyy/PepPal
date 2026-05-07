import SwiftUI

nonisolated enum StatShareCategory: String, CaseIterable, Identifiable, Sendable, Codable {
    case workouts
    case volume
    case steps
    case calories
    case water
    case prs
    case nutrition
    case protocols
    case programs
    case sets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workouts: return "Workouts"
        case .volume: return "Training Volume"
        case .steps: return "Steps"
        case .calories: return "Calories Burned"
        case .water: return "Water Intake"
        case .prs: return "Personal Records"
        case .nutrition: return "Nutrition"
        case .protocols: return "Active Protocols"
        case .programs: return "Active Programs"
        case .sets: return "Set & Rep Details"
        }
    }

    var icon: String {
        switch self {
        case .workouts: return "dumbbell.fill"
        case .volume: return "chart.bar.fill"
        case .steps: return "figure.walk"
        case .calories: return "bolt.fill"
        case .water: return "drop.fill"
        case .prs: return "trophy.fill"
        case .nutrition: return "fork.knife"
        case .protocols: return "syringe.fill"
        case .programs: return "list.clipboard.fill"
        case .sets: return "list.number"
        }
    }

    var color: Color {
        switch self {
        case .workouts: return PepTheme.violet
        case .volume: return PepTheme.teal
        case .steps: return PepTheme.teal
        case .calories: return .orange
        case .water: return PepTheme.blue
        case .prs: return PepTheme.amber
        case .nutrition: return .green
        case .protocols: return .pink
        case .programs: return PepTheme.violet
        case .sets: return PepTheme.teal
        }
    }

    var group: StatShareGroup {
        switch self {
        case .workouts, .volume, .prs, .programs, .sets: return .training
        case .steps, .calories, .water: return .activity
        case .nutrition: return .nutritionGroup
        case .protocols: return .protocolsGroup
        }
    }
}

nonisolated enum StatShareGroup: String, CaseIterable, Sendable {
    case training = "Training"
    case activity = "Activity"
    case nutritionGroup = "Nutrition"
    case protocolsGroup = "Protocols"

    var categories: [StatShareCategory] {
        StatShareCategory.allCases.filter { $0.group == self }
    }
}

nonisolated enum ShareAudience: String, CaseIterable, Identifiable, Sendable, Codable {
    case friends
    case followers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .friends: return "Friends Only"
        case .followers: return "All Followers"
        }
    }

    var subtitle: String {
        switch self {
        case .friends: return "Only people who follow you back can see your stats"
        case .followers: return "Anyone who follows you can see your stats"
        }
    }
}

nonisolated struct StatSharingPrefs: Codable, Sendable {
    var isEnabled: Bool
    var audience: ShareAudience
    var categories: Set<StatShareCategory>

    static let `default` = StatSharingPrefs(
        isEnabled: false,
        audience: .friends,
        categories: Set(StatShareCategory.allCases)
    )

    func isSharing(_ category: StatShareCategory) -> Bool {
        isEnabled && categories.contains(category)
    }
}

nonisolated struct FriendStatSnapshot: Identifiable, Hashable, Sendable {
    nonisolated static func == (lhs: FriendStatSnapshot, rhs: FriendStatSnapshot) -> Bool {
        lhs.id == rhs.id
    }
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    let id: UUID
    let user: SocialUser
    let isSharing: Bool
    let streak: Int
    let weeklyWorkouts: Int
    let totalWorkouts: Int
    let weeklyVolume: Int
    let weeklySteps: Int
    let weeklyCalories: Int
    let weeklyWaterMl: Int
    let latestPR: String?
    let activeProgram: String?
    let activeProtocol: String?
    let sharedCategories: Set<StatShareCategory>
    var lastActivityTitle: String? = nil
    var lastActivityAt: Date? = nil
    var phase: String? = nil

    var highlightMetric: (label: String, value: String, icon: String, color: Color)? {
        if let pr = latestPR, sharedCategories.contains(.prs) {
            return ("Recent PR", pr, "trophy.fill", PepTheme.amber)
        }
        if weeklyWorkouts > 0, sharedCategories.contains(.workouts) {
            return ("This week", "\(weeklyWorkouts) workouts", "dumbbell.fill", PepTheme.violet)
        }
        if weeklySteps > 0, sharedCategories.contains(.steps) {
            return ("Steps", "\(weeklySteps / 1000)k this wk", "figure.walk", PepTheme.teal)
        }
        return nil
    }

    /// Derive a coarse training phase from program/goal text.
    static func derivePhase(programName: String?, goalText: String? = nil) -> String? {
        let haystack = [(programName ?? ""), (goalText ?? "")].joined(separator: " ").lowercased()
        guard !haystack.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        if haystack.contains("recomp") { return "Recomp" }
        if haystack.contains("cut") || haystack.contains("deficit") || haystack.contains("lose") || haystack.contains("weight loss") || haystack.contains("fat loss") {
            return "Cutting"
        }
        if haystack.contains("bulk") || haystack.contains("gain") || haystack.contains("mass") || haystack.contains("surplus") {
            return "Bulking"
        }
        if haystack.contains("maintain") || haystack.contains("maintenance") {
            return "Maintaining"
        }
        if haystack.contains("rebuild") || haystack.contains("postpartum") || haystack.contains("return") {
            return "Rebuilding"
        }
        if haystack.contains("marathon") || haystack.contains("hybrid") || haystack.contains("endurance") {
            return "Endurance"
        }
        if haystack.contains("strength") || haystack.contains("5/3/1") || haystack.contains("powerlift") {
            return "Strength"
        }
        return nil
    }
}

nonisolated enum FriendActivityEventType: Sendable {
    case workout
    case pr
    case streakMilestone
    case goalHit
    case programStart
    case protocolStart

    var icon: String {
        switch self {
        case .workout: return "dumbbell.fill"
        case .pr: return "trophy.fill"
        case .streakMilestone: return "flame.fill"
        case .goalHit: return "checkmark.seal.fill"
        case .programStart: return "list.clipboard.fill"
        case .protocolStart: return "syringe.fill"
        }
    }

    var color: Color {
        switch self {
        case .workout: return PepTheme.violet
        case .pr: return PepTheme.amber
        case .streakMilestone: return PepTheme.amber
        case .goalHit: return .green
        case .programStart: return PepTheme.teal
        case .protocolStart: return .pink
        }
    }
}

nonisolated struct FriendActivityEvent: Identifiable, Sendable {
    let id: UUID
    let user: SocialUser
    let type: FriendActivityEventType
    let title: String
    let subtitle: String?
    let timestamp: Date
}
