import SwiftUI
import Auth

@Observable
final class ProfileViewModel {
    var profile: UserProfile = UserProfile(
        displayName: "",
        username: "",
        initials: "",
        bio: "",
        isCurrentUser: true
    )

    var isLoadingProfile: Bool = false
    var profileError: String?
    var isSaving: Bool = false

    var userPosts: [UserPost] = []
    var userMarketItems: [MarketProgram] = []

    var weeklyVolumes: [WeeklyVolume] = {
        let labels = ["W1", "W2", "W3", "W4", "W5", "W6", "W7", "W8"]
        let values: [Double] = [32_400, 35_100, 28_900, 38_200, 41_500, 36_800, 44_200, 47_600]
        return zip(labels, values).map { WeeklyVolume(weekLabel: $0, volume: $1) }
    }()

    var muscleHeatData: [MuscleHeatData] = [
        MuscleHeatData(muscle: .chest, intensity: 0.85),
        MuscleHeatData(muscle: .back, intensity: 0.72),
        MuscleHeatData(muscle: .shoulders, intensity: 0.68),
        MuscleHeatData(muscle: .biceps, intensity: 0.55),
        MuscleHeatData(muscle: .triceps, intensity: 0.62),
        MuscleHeatData(muscle: .quadriceps, intensity: 0.90),
        MuscleHeatData(muscle: .hamstrings, intensity: 0.48),
        MuscleHeatData(muscle: .glutes, intensity: 0.65),
        MuscleHeatData(muscle: .calves, intensity: 0.30),
        MuscleHeatData(muscle: .core, intensity: 0.75),
        MuscleHeatData(muscle: .forearms, intensity: 0.25),
    ]

    var personalRecords: [PersonalRecordEntry] = [
        PersonalRecordEntry(exerciseName: "Barbell Bench Press", bestWeight: 225, dateAchieved: Calendar.current.date(byAdding: .day, value: -3, to: Date())!),
        PersonalRecordEntry(exerciseName: "Barbell Back Squat", bestWeight: 315, dateAchieved: Calendar.current.date(byAdding: .day, value: -7, to: Date())!),
        PersonalRecordEntry(exerciseName: "Conventional Deadlift", bestWeight: 365, dateAchieved: Calendar.current.date(byAdding: .day, value: -14, to: Date())!),
        PersonalRecordEntry(exerciseName: "Overhead Press", bestWeight: 155, dateAchieved: Calendar.current.date(byAdding: .day, value: -10, to: Date())!),
        PersonalRecordEntry(exerciseName: "Barbell Row", bestWeight: 205, dateAchieved: Calendar.current.date(byAdding: .day, value: -5, to: Date())!),
        PersonalRecordEntry(exerciseName: "Incline Dumbbell Press", bestWeight: 80, dateAchieved: Calendar.current.date(byAdding: .day, value: -21, to: Date())!),
    ]

    var achievements: [Achievement] = [
        Achievement(name: "First Workout", icon: "figure.run", description: "Complete your first workout", isUnlocked: true, unlockedDate: Calendar.current.date(byAdding: .month, value: -5, to: Date()), accentColor: .cyan),
        Achievement(name: "Century Club", icon: "100.circle.fill", description: "Complete 100 workouts", isUnlocked: true, unlockedDate: Calendar.current.date(byAdding: .month, value: -1, to: Date()), accentColor: .amber),
        Achievement(name: "Iron Will", icon: "flame.fill", description: "Maintain a 30-day streak", isUnlocked: true, unlockedDate: Calendar.current.date(byAdding: .day, value: -12, to: Date()), accentColor: .amber),
        Achievement(name: "2 Plate Club", icon: "trophy.fill", description: "Bench press 225 lbs", isUnlocked: true, unlockedDate: Calendar.current.date(byAdding: .day, value: -3, to: Date()), accentColor: .amber),
        Achievement(name: "Social Butterfly", icon: "person.2.fill", description: "Add 10 friends", isUnlocked: true, unlockedDate: Calendar.current.date(byAdding: .month, value: -2, to: Date()), accentColor: .cyan),
        Achievement(name: "Volume King", icon: "chart.bar.fill", description: "Log 1,000,000 lbs total volume", isUnlocked: true, unlockedDate: Calendar.current.date(byAdding: .day, value: -20, to: Date()), accentColor: .violet),
        Achievement(name: "Early Bird", icon: "sunrise.fill", description: "Complete 10 workouts before 7 AM", isUnlocked: false, unlockedDate: nil, accentColor: .cyan),
        Achievement(name: "3 Plate Squat", icon: "medal.fill", description: "Squat 315 lbs", isUnlocked: true, unlockedDate: Calendar.current.date(byAdding: .day, value: -7, to: Date()), accentColor: .amber),
        Achievement(name: "Marathon Month", icon: "calendar", description: "Work out 25+ days in a month", isUnlocked: false, unlockedDate: nil, accentColor: .violet),
        Achievement(name: "5K FP Week", icon: "star.fill", description: "Earn 5,000 FP in a single week", isUnlocked: false, unlockedDate: nil, accentColor: .amber),
        Achievement(name: "Program Master", icon: "checkmark.seal.fill", description: "Complete an entire program", isUnlocked: false, unlockedDate: nil, accentColor: .cyan),
        Achievement(name: "Leg Day Legend", icon: "figure.step.training", description: "Never skip leg day for 8 weeks", isUnlocked: false, unlockedDate: nil, accentColor: .violet),
    ]

    var workoutHistory: [WorkoutHistoryDetail] = {
        let cal = Calendar.current
        let now = Date()
        return [
            WorkoutHistoryDetail(name: "Push Day — Chest, Shoulders, Triceps", date: cal.date(byAdding: .day, value: -1, to: now)!, durationMinutes: 54, totalVolume: 18_450, fpEarned: 340, exercises: [
                WorkoutHistoryExerciseDetail(exerciseName: "Barbell Bench Press", sets: [
                    WorkoutHistorySetDetail(setNumber: 1, weight: 185, reps: 10),
                    WorkoutHistorySetDetail(setNumber: 2, weight: 205, reps: 8),
                    WorkoutHistorySetDetail(setNumber: 3, weight: 225, reps: 5),
                ]),
                WorkoutHistoryExerciseDetail(exerciseName: "Incline Dumbbell Press", sets: [
                    WorkoutHistorySetDetail(setNumber: 1, weight: 70, reps: 10),
                    WorkoutHistorySetDetail(setNumber: 2, weight: 75, reps: 8),
                    WorkoutHistorySetDetail(setNumber: 3, weight: 80, reps: 7),
                ]),
                WorkoutHistoryExerciseDetail(exerciseName: "Overhead Press", sets: [
                    WorkoutHistorySetDetail(setNumber: 1, weight: 115, reps: 10),
                    WorkoutHistorySetDetail(setNumber: 2, weight: 135, reps: 8),
                    WorkoutHistorySetDetail(setNumber: 3, weight: 155, reps: 5),
                ]),
            ]),
            WorkoutHistoryDetail(name: "Pull Day — Back & Biceps", date: cal.date(byAdding: .day, value: -3, to: now)!, durationMinutes: 48, totalVolume: 15_200, fpEarned: 310, exercises: [
                WorkoutHistoryExerciseDetail(exerciseName: "Barbell Row", sets: [
                    WorkoutHistorySetDetail(setNumber: 1, weight: 165, reps: 10),
                    WorkoutHistorySetDetail(setNumber: 2, weight: 185, reps: 8),
                    WorkoutHistorySetDetail(setNumber: 3, weight: 205, reps: 6),
                ]),
                WorkoutHistoryExerciseDetail(exerciseName: "Lat Pulldown", sets: [
                    WorkoutHistorySetDetail(setNumber: 1, weight: 130, reps: 12),
                    WorkoutHistorySetDetail(setNumber: 2, weight: 145, reps: 10),
                    WorkoutHistorySetDetail(setNumber: 3, weight: 160, reps: 8),
                ]),
            ]),
            WorkoutHistoryDetail(name: "Leg Day", date: cal.date(byAdding: .day, value: -5, to: now)!, durationMinutes: 62, totalVolume: 22_800, fpEarned: 380, exercises: [
                WorkoutHistoryExerciseDetail(exerciseName: "Barbell Back Squat", sets: [
                    WorkoutHistorySetDetail(setNumber: 1, weight: 225, reps: 10),
                    WorkoutHistorySetDetail(setNumber: 2, weight: 275, reps: 8),
                    WorkoutHistorySetDetail(setNumber: 3, weight: 315, reps: 5),
                ]),
                WorkoutHistoryExerciseDetail(exerciseName: "Romanian Deadlift", sets: [
                    WorkoutHistorySetDetail(setNumber: 1, weight: 185, reps: 10),
                    WorkoutHistorySetDetail(setNumber: 2, weight: 225, reps: 8),
                    WorkoutHistorySetDetail(setNumber: 3, weight: 245, reps: 6),
                ]),
            ]),
            WorkoutHistoryDetail(name: "Push Day — Chest, Shoulders, Triceps", date: cal.date(byAdding: .day, value: -7, to: now)!, durationMinutes: 51, totalVolume: 17_600, fpEarned: 330, exercises: [
                WorkoutHistoryExerciseDetail(exerciseName: "Barbell Bench Press", sets: [
                    WorkoutHistorySetDetail(setNumber: 1, weight: 185, reps: 10),
                    WorkoutHistorySetDetail(setNumber: 2, weight: 200, reps: 8),
                    WorkoutHistorySetDetail(setNumber: 3, weight: 215, reps: 6),
                ]),
            ]),
            WorkoutHistoryDetail(name: "Upper Body", date: cal.date(byAdding: .day, value: -9, to: now)!, durationMinutes: 45, totalVolume: 14_300, fpEarned: 290, exercises: [
                WorkoutHistoryExerciseDetail(exerciseName: "Dumbbell Bench Press", sets: [
                    WorkoutHistorySetDetail(setNumber: 1, weight: 75, reps: 10),
                    WorkoutHistorySetDetail(setNumber: 2, weight: 80, reps: 8),
                ]),
            ]),
            WorkoutHistoryDetail(name: "Leg Day", date: cal.date(byAdding: .day, value: -12, to: now)!, durationMinutes: 58, totalVolume: 21_400, fpEarned: 360, exercises: [
                WorkoutHistoryExerciseDetail(exerciseName: "Barbell Back Squat", sets: [
                    WorkoutHistorySetDetail(setNumber: 1, weight: 225, reps: 10),
                    WorkoutHistorySetDetail(setNumber: 2, weight: 275, reps: 7),
                    WorkoutHistorySetDetail(setNumber: 3, weight: 305, reps: 4),
                ]),
            ]),
        ]
    }()

    var sportSessions: [SportSession] = [
        SportSession(sport: .basketball, sessionType: .game, durationMinutes: 90, intensity: 8, date: Date().addingTimeInterval(-150000), specificStats: .basketball(BasketballStats(points: 18, assists: 5, rebounds: 7))),
        SportSession(sport: .running, sessionType: .training, durationMinutes: 35, intensity: 7, date: Date().addingTimeInterval(-250000), specificStats: .running(RunningStats(distanceMiles: 3.2, paceMinutesPerMile: 8.5))),
        SportSession(sport: .basketball, sessionType: .practice, durationMinutes: 60, intensity: 6, date: Date().addingTimeInterval(-400000), specificStats: .basketball(BasketballStats(points: 12, assists: 3, rebounds: 5))),
        SportSession(sport: .swimming, sessionType: .practice, durationMinutes: 45, intensity: 6, date: Date().addingTimeInterval(-500000), specificStats: .swimming(SwimmingStats(laps: 30, stroke: .freestyle))),
        SportSession(sport: .running, sessionType: .training, durationMinutes: 50, intensity: 8, date: Date().addingTimeInterval(-600000), specificStats: .running(RunningStats(distanceMiles: 5.0, paceMinutesPerMile: 8.0))),
        SportSession(sport: .soccer, sessionType: .game, durationMinutes: 90, intensity: 9, date: Date().addingTimeInterval(-700000)),
    ]

    var sportAnalytics: [SportAnalyticsData] {
        let grouped = Dictionary(grouping: sportSessions, by: \.sport)
        return grouped.map { sport, sessions in
            let totalMinutes = sessions.reduce(0) { $0 + $1.durationMinutes }
            let avgIntensity = sessions.isEmpty ? 0 : Double(sessions.reduce(0) { $0 + $1.intensity }) / Double(sessions.count)
            return SportAnalyticsData(sport: sport, sessionCount: sessions.count, totalMinutes: totalMinutes, averageIntensity: avgIntensity)
        }.sorted { $0.sessionCount > $1.sessionCount }
    }

    var isLoadingPosts: Bool = false

    let streakManager = StreakManager.shared
    let notificationService = NotificationService.shared
    private let socialService = SocialService.shared

    var weightUnit: WeightUnit = .lbs
    var defaultRestSeconds: Int = 90
    var notificationsEnabled: Bool = true
    var workoutReminders: Bool = true
    var isDarkMode: Bool = true
    var reminderTime: Date = {
        var components = DateComponents()
        components.hour = 18
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }()

    var friendWorkoutNotifs: Bool = true
    var highFiveNotifs: Bool = true
    var streakMilestoneNotifs: Bool = true
    var weeklyProgressNotifs: Bool = true
    var restDayRecoveryNotifs: Bool = true
    var streakWarningNotifs: Bool = true

    var memberSinceFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return "Joined \(formatter.string(from: profile.memberSince))"
    }

    var unlockedCount: Int {
        allAchievements.filter(\.isUnlocked).count
    }

    var allAchievements: [Achievement] {
        var all = achievements
        let streakAchievements = streakBadges
        for badge in streakAchievements {
            if !all.contains(where: { $0.name == badge.name }) {
                all.append(badge)
            }
        }
        return all
    }

    private var streakBadges: [Achievement] {
        StreakMilestone.allCases.map { milestone in
            let reached = streakManager.streakMilestonesReached.contains(milestone)
            return Achievement(
                name: milestone.badgeName,
                icon: milestone.badgeIcon,
                description: milestone.badgeDescription,
                isUnlocked: reached,
                unlockedDate: reached ? Date() : nil,
                accentColor: .amber
            )
        }
    }

    init() {
        loadMockMarketItems()
    }

    func loadProfile() async {
        guard let session = AuthService.shared.session else { return }
        let userId = session.user.id.uuidString
        isLoadingProfile = true
        profileError = nil

        do {
            let sp = try await ProfileService.shared.fetchProfile(userId: userId)
            let name = sp.display_name ?? "User"
            let uname = sp.username ?? "user"
            let initials = Self.computeInitials(from: name)
            let color = Self.parseAvatarColor(sp.avatar_color)

            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let memberDate = sp.member_since.flatMap { iso.date(from: $0) } ?? Date()

            profile = UserProfile(
                id: UUID(uuidString: sp.id) ?? UUID(),
                displayName: name,
                username: uname,
                initials: initials,
                bio: sp.bio ?? "",
                avatarUrl: sp.avatar_url,
                avatarColor: color,
                activeProgram: sp.active_program,
                totalFP: sp.total_fp ?? 0,
                currentStreak: sp.current_streak ?? 0,
                totalWorkouts: sp.total_workouts ?? 0,
                memberSince: memberDate,
                followerCount: sp.follower_count ?? 0,
                followingCount: sp.following_count ?? 0,
                friendCount: sp.friend_count ?? 0,
                isCurrentUser: true
            )

            loadMockMarketItems()
            isLoadingProfile = false
            await loadUserPosts()
        } catch {
            profileError = error.localizedDescription
            isLoadingProfile = false
        }
    }

    func saveProfileEdits(displayName: String, username: String, bio: String, activeProgram: String?, avatarColor: String?) async {
        guard let session = AuthService.shared.session else { return }
        let userId = session.user.id.uuidString
        isSaving = true

        let update = ProfileUpdate(
            display_name: displayName,
            username: username,
            bio: bio,
            avatar_url: nil,
            avatar_color: avatarColor,
            active_program: activeProgram
        )

        do {
            try await ProfileService.shared.updateProfile(userId: userId, update: update)
            await loadProfile()
        } catch {
            profileError = error.localizedDescription
        }
        isSaving = false
    }

    func uploadAvatar(imageData: Data) async -> String? {
        guard let session = AuthService.shared.session else { return nil }
        let userId = session.user.id.uuidString
        isSaving = true
        do {
            let url = try await ProfileService.shared.uploadAvatar(userId: userId, imageData: imageData)
            await loadProfile()
            isSaving = false
            return url
        } catch {
            profileError = error.localizedDescription
            isSaving = false
            return nil
        }
    }

    func loadUserPosts() async {
        guard let session = AuthService.shared.session else { return }
        let userId = session.user.id.uuidString
        isLoadingPosts = true

        do {
            let supabasePosts = try await socialService.fetchUserPosts(userId: userId)
            let postIds = supabasePosts.map { $0.id }
            let likedIds = try await socialService.fetchLikedPostIds(userId: userId, postIds: postIds)

            userPosts = supabasePosts.map { sp in
                UserPost(
                    id: UUID(uuidString: sp.id) ?? UUID(),
                    authorId: UUID(uuidString: sp.user_id) ?? UUID(),
                    content: sp.text_content ?? "",
                    timestamp: socialService.parseDate(sp.created_at),
                    likeCount: sp.high_five_count ?? 0,
                    isLiked: likedIds.contains(sp.id),
                    commentCount: 0
                )
            }
        } catch {
            userPosts = []
        }

        isLoadingPosts = false
    }

    func togglePostLike(_ postId: UUID) {
        guard let index = userPosts.firstIndex(where: { $0.id == postId }) else { return }
        let wasLiked = userPosts[index].isLiked
        userPosts[index].isLiked.toggle()
        userPosts[index].likeCount += userPosts[index].isLiked ? 1 : -1

        Task {
            do {
                let userId = try AuthService.shared.currentUserId()
                let supabaseId = postId.uuidString.lowercased()
                if wasLiked {
                    try await socialService.unlikePost(postId: supabaseId, userId: userId)
                } else {
                    try await socialService.likePost(postId: supabaseId, userId: userId)
                }
            } catch {
                guard let idx = userPosts.firstIndex(where: { $0.id == postId }) else { return }
                userPosts[idx].isLiked = wasLiked
                userPosts[idx].likeCount += wasLiked ? 1 : -1
            }
        }
    }

    func toggleFollow() {
        profile.isFollowing.toggle()
    }

    func sendFriendRequest() {
        guard profile.friendRequestStatus == .none else { return }
        profile.friendRequestStatus = .pending
    }

    func updateNotificationPreference(_ type: NotificationType, enabled: Bool) {
        if enabled {
            notificationService.preferences.enabledTypes.insert(type)
        } else {
            notificationService.preferences.enabledTypes.remove(type)
        }
        notificationService.scheduleAllNotifications()
    }

    func updateReminderTime(_ time: Date) {
        reminderTime = time
        notificationService.updateReminderTime(time)
    }

    var maxVolume: Double {
        weeklyVolumes.map(\.volume).max() ?? 1
    }

    func postsForUser(_ userId: UUID) -> [UserPost] {
        userPosts.filter { $0.authorId == userId }
    }

    static func computeInitials(from name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1)).uppercased() + String(parts[1].prefix(1)).uppercased()
        } else if let first = parts.first {
            return String(first.prefix(2)).uppercased()
        }
        return "U"
    }

    static func parseAvatarColor(_ hex: String?) -> Color {
        guard let hex, !hex.isEmpty else {
            return Color(red: 0, green: 229/255, blue: 255/255)
        }
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6, let val = UInt64(cleaned, radix: 16) else {
            return Color(red: 0, green: 229/255, blue: 255/255)
        }
        let r = Double((val >> 16) & 0xFF) / 255.0
        let g = Double((val >> 8) & 0xFF) / 255.0
        let b = Double(val & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }



    private func loadMockMarketItems() {
        let profileId = profile.id
        let creatorName = profile.displayName.isEmpty ? "You" : profile.displayName
        userMarketItems = [
            MarketProgram(
                title: "\(creatorName)'s PPL Hypertrophy",
                creatorName: creatorName,
                creatorId: profileId,
                rating: 4.8,
                reviewCount: 234,
                itemType: .workoutSplit,
                difficulty: .intermediate,
                durationWeeks: 12,
                daysPerWeek: 6,
                equipment: "Full Gym",
                totalFP: 11520,
                overview: "My personal PPL split optimized for hypertrophy. Progressive overload with volume cycling.",
                gradientColors: [GradientColor(0, 0.9, 1), GradientColor(0.1, 0.2, 0.6)],
                iconName: "dumbbell.fill"
            ),
            MarketProgram(
                title: "Beginner Strength Foundations",
                creatorName: creatorName,
                creatorId: profileId,
                rating: 4.9,
                reviewCount: 567,
                itemType: .workoutSplit,
                difficulty: .beginner,
                durationWeeks: 8,
                daysPerWeek: 3,
                equipment: "Barbell & Rack",
                totalFP: 3840,
                overview: "The program I wish I had when I started. Simple, effective, and proven.",
                gradientColors: [GradientColor(0.55, 0.36, 0.96), GradientColor(0.2, 0.1, 0.5)],
                iconName: "figure.strengthtraining.traditional"
            ),
        ]
    }
}
