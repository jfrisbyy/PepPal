import Foundation
import SwiftUI

nonisolated enum BiologicalSex: String, CaseIterable, Identifiable, Sendable, Codable {
    case male = "male"
    case female = "female"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        }
    }
}

nonisolated struct UserProfile: Sendable {
    let id: UUID
    let displayName: String
    let username: String
    let initials: String
    let bio: String
    let avatarUrl: String?
    let bannerUrl: String?
    let avatarColor: Color
    let activeProgram: String?
    let currentStreak: Int
    let totalWorkouts: Int
    let memberSince: Date
    let followerCount: Int
    let followingCount: Int
    let friendCount: Int
    var isFollowing: Bool
    var friendRequestStatus: FriendRequestStatus
    let isCurrentUser: Bool
    let dateOfBirth: Date?
    let biologicalSex: BiologicalSex?
    let heightCm: Double?
    var isPrivate: Bool

    init(
        id: UUID = UUID(),
        displayName: String,
        username: String,
        initials: String,
        bio: String = "",
        avatarUrl: String? = nil,
        bannerUrl: String? = nil,
        avatarColor: Color = Color(red: 0, green: 229/255, blue: 255/255),
        activeProgram: String? = nil,
        totalFP: Int = 0,
        currentStreak: Int = 0,
        totalWorkouts: Int = 0,
        memberSince: Date = Date(),
        followerCount: Int = 0,
        followingCount: Int = 0,
        friendCount: Int = 0,
        isFollowing: Bool = false,
        friendRequestStatus: FriendRequestStatus = .none,
        isCurrentUser: Bool = false,
        dateOfBirth: Date? = nil,
        biologicalSex: BiologicalSex? = nil,
        heightCm: Double? = nil,
        isPrivate: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.username = username
        self.initials = initials
        self.bio = bio
        self.avatarUrl = avatarUrl
        self.bannerUrl = bannerUrl
        self.avatarColor = avatarColor
        self.activeProgram = activeProgram
        _ = totalFP
        self.currentStreak = currentStreak
        self.totalWorkouts = totalWorkouts
        self.memberSince = memberSince
        self.followerCount = followerCount
        self.followingCount = followingCount
        self.friendCount = friendCount
        self.isFollowing = isFollowing
        self.friendRequestStatus = friendRequestStatus
        self.isCurrentUser = isCurrentUser
        self.dateOfBirth = dateOfBirth
        self.biologicalSex = biologicalSex
        self.heightCm = heightCm
        self.isPrivate = isPrivate
    }

    var isBiometricProfileComplete: Bool {
        dateOfBirth != nil && biologicalSex != nil && heightCm != nil
    }
}

nonisolated struct UserPost: Identifiable, Sendable {
    let id: UUID
    let authorId: UUID
    let content: String
    let timestamp: Date
    var likeCount: Int
    var isLiked: Bool
    var commentCount: Int
    let mediaUrls: [String]
    let audioUrl: String?
    let audioDuration: Double?
    let workoutAttachment: WorkoutPostAttachment?

    init(
        id: UUID = UUID(),
        authorId: UUID,
        content: String,
        timestamp: Date = Date(),
        likeCount: Int = 0,
        isLiked: Bool = false,
        commentCount: Int = 0,
        mediaUrls: [String] = [],
        audioUrl: String? = nil,
        audioDuration: Double? = nil,
        workoutAttachment: WorkoutPostAttachment? = nil
    ) {
        self.id = id
        self.authorId = authorId
        self.content = content
        self.timestamp = timestamp
        self.likeCount = likeCount
        self.isLiked = isLiked
        self.commentCount = commentCount
        self.mediaUrls = mediaUrls
        self.audioUrl = audioUrl
        self.audioDuration = audioDuration
        self.workoutAttachment = workoutAttachment
    }
}

nonisolated struct WorkoutPostAttachment: Sendable {
    let workoutName: String
    let duration: Int
    let exerciseCount: Int
}

nonisolated struct WeeklyVolume: Identifiable, Sendable {
    let id = UUID()
    let weekLabel: String
    let volume: Double
}

nonisolated struct MuscleHeatData: Identifiable, Sendable {
    let id = UUID()
    let muscle: MuscleGroup
    let intensity: Double
}

nonisolated struct PersonalRecordEntry: Identifiable, Sendable {
    let id = UUID()
    let exerciseName: String
    let bestWeight: Double
    let dateAchieved: Date
}

nonisolated struct Achievement: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let icon: String
    let description: String
    let isUnlocked: Bool
    let unlockedDate: Date?
    let accentColor: AchievementColor
}

nonisolated enum AchievementColor: String, Sendable {
    case cyan, amber, violet, green
}

nonisolated enum WeightUnit: String, CaseIterable, Sendable {
    case lbs = "lbs"
    case kg = "kg"
}

nonisolated struct WorkoutHistoryDetail: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let date: Date
    let durationMinutes: Int
    let totalVolume: Int
    let caloriesBurned: Int
    let exercises: [WorkoutHistoryExerciseDetail]

    init(name: String, date: Date, durationMinutes: Int, totalVolume: Int, caloriesBurned: Int, fpEarned: Int = 0, exercises: [WorkoutHistoryExerciseDetail]) {
        self.name = name
        self.date = date
        self.durationMinutes = durationMinutes
        self.totalVolume = totalVolume
        self.caloriesBurned = caloriesBurned
        _ = fpEarned
        self.exercises = exercises
    }
}

nonisolated struct WorkoutHistoryExerciseDetail: Identifiable, Sendable {
    let id = UUID()
    let exerciseName: String
    let sets: [WorkoutHistorySetDetail]
}

nonisolated struct WorkoutHistorySetDetail: Identifiable, Sendable {
    let id = UUID()
    let setNumber: Int
    let weight: Double
    let reps: Int
}
