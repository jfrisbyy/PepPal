import SwiftUI

@Observable
@MainActor
final class FriendsStatsViewModel {
    var friends: [FriendStatSnapshot] = []
    var activityEvents: [FriendActivityEvent] = []
    var weeklyRecap: WeeklyRecapSummary?
    var isLoading: Bool = true
    var error: String?

    var hasEnabledSharing: Bool {
        StatSharingService.shared.currentUserPrefs.isEnabled
    }

    var hasSeenOnboarding: Bool {
        guard let id = try? AuthService.shared.currentUserId() else { return true }
        return StatSharingService.shared.hasSeenOnboarding(for: id)
    }

    private let messagingService = MessagingService.shared
    private let socialService = SocialService.shared
    private let activityService = ActivityLogService.shared
    private let backend = FriendsBackendService.shared

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        // Fetch real backend feed first
        var snapshots: [FriendStatSnapshot] = []
        var events: [FriendActivityEvent] = []

        if let feed = try? await backend.fetchFeed() {
            for friend in feed.friends ?? [] {
                let user = socialService.socialUserFromAuthor(friend.profile)
                let cats: Set<StatShareCategory> = Set((friend.prefs?.categories ?? []).compactMap {
                    StatShareCategory(rawValue: $0)
                })
                let snap = friend.snapshot
                snapshots.append(FriendStatSnapshot(
                    id: user.id,
                    user: user,
                    isSharing: true,
                    streak: snap?.streak ?? user.streak,
                    weeklyWorkouts: snap?.weekly_workouts ?? 0,
                    totalWorkouts: 0,
                    weeklyVolume: snap?.weekly_volume_kg ?? 0,
                    weeklySteps: snap?.weekly_steps ?? 0,
                    weeklyCalories: snap?.weekly_calories ?? 0,
                    weeklyWaterMl: snap?.weekly_water_ml ?? 0,
                    latestPR: snap?.latest_pr,
                    activeProgram: snap?.active_program ?? user.activeProgramName,
                    activeProtocol: snap?.active_protocol,
                    sharedCategories: cats.isEmpty ? Set(StatShareCategory.allCases) : cats
                ))
            }

            for ev in feed.events ?? [] {
                if let user = snapshots.first(where: { $0.id.uuidString.lowercased() == ev.user_id.lowercased() })?.user {
                    events.append(FriendActivityEvent(
                        id: UUID(uuidString: ev.id) ?? UUID(),
                        user: user,
                        type: mapEventType(ev.type),
                        title: ev.title,
                        subtitle: ev.subtitle,
                        timestamp: messagingService.parseDate(ev.created_at)
                    ))
                }
            }

            if let recap = feed.myRecap {
                self.weeklyRecap = WeeklyRecapSummary(from: recap)
            }
        }

        // Fall back to derived activity from real follows when backend is empty
        if snapshots.isEmpty {
            await loadDerivedFromFollows(into: &snapshots, events: &events)
        }

        // Top up with mock profiles in dev (only if no real friends found)
        if snapshots.isEmpty {
            for mockSnap in MockFriendsService.shared.snapshots() {
                snapshots.append(mockSnap)
            }
            for mockEvent in MockFriendsService.shared.activityEvents() {
                events.append(mockEvent)
            }
        }

        snapshots.sort { $0.streak > $1.streak }
        events.sort { $0.timestamp > $1.timestamp }

        self.friends = snapshots
        self.activityEvents = Array(events.prefix(40))

        FriendSocialService.shared.seedMockPresence(friendIds: snapshots.map { $0.id.uuidString })
    }

    private func loadDerivedFromFollows(
        into snapshots: inout [FriendStatSnapshot],
        events: inout [FriendActivityEvent]
    ) async {
        do {
            let myId = try AuthService.shared.currentUserId()
            let audience = StatSharingService.shared.currentUserPrefs.audience
            let following = (try? await messagingService.fetchFollowing(userId: myId)) ?? []
            let followers = (try? await messagingService.fetchFollowers(userId: myId)) ?? []
            let friendIds: [String]
            switch audience {
            case .friends:
                let followersSet = Set(followers.map { $0.lowercased() })
                friendIds = following.filter { followersSet.contains($0.lowercased()) }
            case .followers:
                friendIds = Array(Set(followers))
            }

            let profiles = try await messagingService.fetchProfilesByIds(friendIds)
            for profile in profiles {
                let user = socialService.socialUserFromAuthor(profile)
                let weekActivities = (try? await activityService.fetchWeekActivities(userId: profile.id)) ?? []
                let workoutLogs = weekActivities.filter { $0.activity_type == "workout" }
                snapshots.append(FriendStatSnapshot(
                    id: user.id,
                    user: user,
                    isSharing: true,
                    streak: user.streak,
                    weeklyWorkouts: workoutLogs.count,
                    totalWorkouts: 0,
                    weeklyVolume: 0,
                    weeklySteps: 0,
                    weeklyCalories: workoutLogs.reduce(0) { $0 + ($1.calories_burned ?? 0) },
                    weeklyWaterMl: 0,
                    latestPR: nil,
                    activeProgram: user.activeProgramName,
                    activeProtocol: nil,
                    sharedCategories: Set(StatShareCategory.allCases)
                ))
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func mapEventType(_ raw: String) -> FriendActivityEventType {
        switch raw {
        case "pr": return .pr
        case "protocol_started", "protocol_finished": return .protocolStart
        case "program_started": return .programStart
        case "streak_milestone": return .streakMilestone
        case "sharing_on": return .goalHit
        case "weekly_recap": return .goalHit
        default: return .workout
        }
    }

    func mySnapshot() -> FriendStatSnapshot? {
        guard let myId = try? AuthService.shared.currentUserId(),
              let uuid = UUID(uuidString: myId) else { return nil }
        let prefs = StatSharingService.shared.currentUserPrefs
        let user = SocialUser(
            id: uuid,
            name: ProfileService.shared.cachedDisplayName ?? "You",
            username: "you",
            avatarInitial: String((ProfileService.shared.cachedDisplayName ?? "Y").prefix(1)).uppercased(),
            avatarColor: PepTheme.teal,
            avatarURL: ProfileService.shared.cachedAvatarUrl,
            activeProgramName: nil,
            streak: StreakManager.shared.streakData.currentStreak,
            totalFP: 0
        )
        return FriendStatSnapshot(
            id: uuid,
            user: user,
            isSharing: prefs.isEnabled,
            streak: user.streak,
            weeklyWorkouts: 0,
            totalWorkouts: 0,
            weeklyVolume: 0,
            weeklySteps: 0,
            weeklyCalories: 0,
            weeklyWaterMl: 0,
            latestPR: nil,
            activeProgram: nil,
            activeProtocol: nil,
            sharedCategories: prefs.categories
        )
    }
}

// MARK: - Weekly recap summary (decoded from `friend_activity_events` row)

struct WeeklyRecapSummary: Identifiable, Sendable {
    let id: String
    let weekStart: String?
    let workouts: Int
    let volumeKg: Int
    let steps: Int
    let calories: Int
    let waterMl: Int
    let streak: Int
    let latestPR: String?
    let prevWorkouts: Int
    let prevVolumeKg: Int
    let prevSteps: Int
    let createdAt: Date

    init?(from event: FriendsFeedEvent) {
        guard event.type == "weekly_recap" else { return nil }
        self.id = event.id
        self.createdAt = MessagingService.shared.parseDate(event.created_at)
        // The data field is opaque AnyCodable; we re-parse the JSON dict if present.
        let data = WeeklyRecapSummary.dict(from: event.data)
        self.weekStart = data["week_start"] as? String
        self.workouts = (data["weekly_workouts"] as? Int) ?? 0
        self.volumeKg = (data["weekly_volume_kg"] as? Int) ?? 0
        self.steps = (data["weekly_steps"] as? Int) ?? 0
        self.calories = (data["weekly_calories"] as? Int) ?? 0
        self.waterMl = (data["weekly_water_ml"] as? Int) ?? 0
        self.streak = (data["streak"] as? Int) ?? 0
        self.latestPR = data["latest_pr"] as? String
        self.prevWorkouts = (data["prev_workouts"] as? Int) ?? 0
        self.prevVolumeKg = (data["prev_volume_kg"] as? Int) ?? 0
        self.prevSteps = (data["prev_steps"] as? Int) ?? 0
    }

    private static func dict(from any: AnyCodable?) -> [String: Any] {
        guard let any else { return [:] }
        if let d = any.value as? [String: Any] { return d }
        return [:]
    }

    var workoutsDelta: Int { workouts - prevWorkouts }
    var volumeDelta: Int { volumeKg - prevVolumeKg }
    var stepsDelta: Int { steps - prevSteps }
}
