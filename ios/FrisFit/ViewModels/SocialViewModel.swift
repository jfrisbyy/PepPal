import SwiftUI

@Observable
final class SocialViewModel {
    var posts: [WorkoutPost] = []
    var feedPosts: [FeedPost] = []
    var searchResults: [FriendSearchResult] = []
    var searchQuery: String = ""
    var isSearching: Bool = false

    var feedFilter: FeedFilter = .all
    var selectedTags: Set<FeedTag> = []
    var isTagsExpanded: Bool = false

    var filteredFeedPosts: [FeedPost] {
        switch feedFilter {
        case .all:
            return feedPosts
        case .following:
            return feedPosts.filter { $0.isFollowing }
        case .tags:
            if selectedTags.isEmpty { return feedPosts }
            return feedPosts.filter { post in
                !post.tags.filter { selectedTags.contains($0) }.isEmpty
            }
        }
    }

    private let sampleUsers: [SocialUser] = [
        SocialUser(id: UUID(), name: "Alex Martinez", username: "alexm_fit", avatarInitial: "A", avatarColor: Color(red: 0.2, green: 0.6, blue: 0.9), activeProgramName: "Push Pull Legs", streak: 14, totalFP: 8420),
        SocialUser(id: UUID(), name: "Jordan Kim", username: "jkim_lifts", avatarInitial: "J", avatarColor: Color(red: 0.9, green: 0.4, blue: 0.3), activeProgramName: "Upper Lower", streak: 21, totalFP: 12350),
        SocialUser(id: UUID(), name: "Sam Taylor", username: "samtaylor", avatarInitial: "S", avatarColor: Color(red: 0.4, green: 0.8, blue: 0.5), activeProgramName: nil, streak: 7, totalFP: 5680),
        SocialUser(id: UUID(), name: "Riley Chen", username: "rileyc", avatarInitial: "R", avatarColor: Color(red: 0.8, green: 0.5, blue: 0.9), activeProgramName: "5/3/1", streak: 45, totalFP: 18900),
        SocialUser(id: UUID(), name: "Casey Nguyen", username: "casey_ng", avatarInitial: "C", avatarColor: Color(red: 0.9, green: 0.7, blue: 0.2), activeProgramName: "GZCLP", streak: 10, totalFP: 6750),
        SocialUser(id: UUID(), name: "Morgan Davis", username: "morgfit", avatarInitial: "M", avatarColor: Color(red: 0.3, green: 0.7, blue: 0.8), activeProgramName: "Full Body 3x", streak: 33, totalFP: 15200),
    ]

    init() {
        loadMockData()
        loadMockFeedPosts()
    }

    func toggleHighFive(for postID: UUID) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        posts[index].isHighFived.toggle()
        posts[index].highFiveCount += posts[index].isHighFived ? 1 : -1
    }

    func toggleFeedHighFive(for postID: UUID) {
        guard let index = feedPosts.firstIndex(where: { $0.id == postID }) else { return }
        feedPosts[index].isHighFived.toggle()
        feedPosts[index].highFiveCount += feedPosts[index].isHighFived ? 1 : -1
    }

    func addFeedComment(to postID: UUID, text: String) {
        guard let index = feedPosts.firstIndex(where: { $0.id == postID }) else { return }
        let me = SocialUser(id: UUID(), name: "You", username: "me", avatarInitial: "Y", avatarColor: PepTheme.teal, activeProgramName: "Push Pull Legs", streak: 12, totalFP: 7200)
        let comment = PostComment(id: UUID(), user: me, text: text, timestamp: Date())
        feedPosts[index].comments.append(comment)
    }

    func addFeedPost(_ post: FeedPost) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            feedPosts.insert(post, at: 0)
        }
    }

    func addComment(to postID: UUID, text: String) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        let me = SocialUser(id: UUID(), name: "You", username: "me", avatarInitial: "Y", avatarColor: PepTheme.teal, activeProgramName: "Push Pull Legs", streak: 12, totalFP: 7200)
        let comment = PostComment(id: UUID(), user: me, text: text, timestamp: Date())
        posts[index].comments.append(comment)
    }

    func searchUsers(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        let allSearchable: [SocialUser] = [
            SocialUser(id: UUID(), name: "Taylor Swift", username: "tswift_gym", avatarInitial: "T", avatarColor: .pink, activeProgramName: nil, streak: 3, totalFP: 1200),
            SocialUser(id: UUID(), name: "Chris Evans", username: "capfit", avatarInitial: "C", avatarColor: .blue, activeProgramName: "Superhero Split", streak: 60, totalFP: 25000),
            SocialUser(id: UUID(), name: "Jamie Lee", username: "jamielifts", avatarInitial: "J", avatarColor: .orange, activeProgramName: "Starting Strength", streak: 8, totalFP: 3400),
            SocialUser(id: UUID(), name: "Quinn Roberts", username: "quinnr", avatarInitial: "Q", avatarColor: .purple, activeProgramName: nil, streak: 0, totalFP: 500),
        ] + sampleUsers

        let filtered = allSearchable.filter {
            $0.name.localizedStandardContains(query) || $0.username.localizedStandardContains(query)
        }
        searchResults = filtered.map { user in
            let status: FriendRequestStatus = sampleUsers.contains(where: { $0.id == user.id }) ? .accepted : .none
            return FriendSearchResult(id: user.id, user: user, requestStatus: status)
        }
        isSearching = false
    }

    func sendFriendRequest(to userID: UUID) {
        guard let index = searchResults.firstIndex(where: { $0.id == userID }) else { return }
        searchResults[index].requestStatus = .pending
    }

    private func loadMockData() {
        let now = Date()
        posts = [
            WorkoutPost(
                id: UUID(), user: sampleUsers[0], timestamp: now.addingTimeInterval(-1800),
                workoutName: "Push Day — Chest & Shoulders", duration: 62, totalVolume: 14520, fpEarned: 185,
                exercisesCompleted: 6, highFiveCount: 12, isHighFived: false, comments: [
                    PostComment(id: UUID(), user: sampleUsers[1], text: "Beast mode! 💪", timestamp: now.addingTimeInterval(-900)),
                    PostComment(id: UUID(), user: sampleUsers[2], text: "Nice volume!", timestamp: now.addingTimeInterval(-600)),
                ]),
            WorkoutPost(
                id: UUID(), user: sampleUsers[1], timestamp: now.addingTimeInterval(-7200),
                workoutName: "Pull Day — Back & Biceps", duration: 58, totalVolume: 12800, fpEarned: 172,
                exercisesCompleted: 7, highFiveCount: 8, isHighFived: true, comments: []),
            WorkoutPost(
                id: UUID(), user: sampleUsers[3], timestamp: now.addingTimeInterval(-14400),
                workoutName: "Squat Day — 5/3/1 Week 3", duration: 75, totalVolume: 18200, fpEarned: 220,
                exercisesCompleted: 5, highFiveCount: 24, isHighFived: false, comments: [
                    PostComment(id: UUID(), user: sampleUsers[4], text: "New PR? 🔥", timestamp: now.addingTimeInterval(-10000)),
                ]),
            WorkoutPost(
                id: UUID(), user: sampleUsers[4], timestamp: now.addingTimeInterval(-28800),
                workoutName: "Full Body GZCLP Day A", duration: 55, totalVolume: 9800, fpEarned: 145,
                exercisesCompleted: 4, highFiveCount: 5, isHighFived: false, comments: []),
            WorkoutPost(
                id: UUID(), user: sampleUsers[5], timestamp: now.addingTimeInterval(-43200),
                workoutName: "Upper Body Hypertrophy", duration: 68, totalVolume: 16400, fpEarned: 198,
                exercisesCompleted: 8, highFiveCount: 15, isHighFived: true, comments: []),
        ]
    }

    private func loadMockFeedPosts() {
        let now = Date()
        feedPosts = [
            FeedPost(
                user: sampleUsers[0],
                timestamp: now.addingTimeInterval(-900),
                textContent: "Just hit a new bench PR! 225 for 3 reps. The grind is paying off",
                media: [
                    FeedMediaItem(type: .workoutLog, workoutLog: WorkoutLogAttachment(
                        workoutName: "Push Day — Chest & Shoulders",
                        duration: 62, exerciseCount: 6, totalVolume: 14520, fpEarned: 185, date: now.addingTimeInterval(-900)
                    ))
                ],
                highFiveCount: 18,
                comments: [
                    PostComment(id: UUID(), user: sampleUsers[1], text: "Let's go!! 🔥", timestamp: now.addingTimeInterval(-600)),
                ],
                tags: [.bodybuilding, .prAlert, .progress],
                isFollowing: true
            ),
            FeedPost(
                user: sampleUsers[1],
                timestamp: now.addingTimeInterval(-3600),
                textContent: "Found this amazing program on the market. If you're looking for a solid upper/lower split, highly recommend checking it out",
                media: [
                    FeedMediaItem(type: .marketLink, marketProgram: MarketProgram(
                        title: "Upper Lower Hypertrophy",
                        creatorName: "Coach Mike",
                        creatorId: UUID(),
                        rating: 4.9,
                        reviewCount: 312,
                        itemType: .workoutSplit,
                        difficulty: .intermediate,
                        durationWeeks: 10,
                        daysPerWeek: 4,
                        equipment: "Full Gym",
                        totalFP: 3600,
                        overview: "Balanced hypertrophy program",
                        gradientColors: [GradientColor(0.2, 0.6, 0.9), GradientColor(0.1, 0.4, 0.8)],
                        iconName: "figure.strengthtraining.traditional"
                    ))
                ],
                highFiveCount: 7,
                repostCount: 3,
                tags: [.program, .bodybuilding],
                isFollowing: true
            ),
            FeedPost(
                user: sampleUsers[3],
                timestamp: now.addingTimeInterval(-7200),
                textContent: "Week 3 of 5/3/1 done. Squat is moving like butter. Trust the process",
                highFiveCount: 31,
                comments: [
                    PostComment(id: UUID(), user: sampleUsers[4], text: "5/3/1 never fails", timestamp: now.addingTimeInterval(-5000)),
                    PostComment(id: UUID(), user: sampleUsers[2], text: "What's your TM at?", timestamp: now.addingTimeInterval(-4000)),
                ],
                repostCount: 2,
                tags: [.bodybuilding, .motivation, .progress],
                isFollowing: false
            ),
            FeedPost(
                user: sampleUsers[2],
                timestamp: now.addingTimeInterval(-14400),
                textContent: "Morning cardio voice note — sharing my thoughts on progressive overload and why most people stall",
                media: [
                    FeedMediaItem(type: .voice, voiceDuration: 47)
                ],
                highFiveCount: 14,
                repostCount: 5,
                tags: [.motivation, .running],
                isFollowing: false
            ),
            FeedPost(
                user: sampleUsers[5],
                timestamp: now.addingTimeInterval(-28800),
                textContent: "Full body day was brutal but we made it through. 8 exercises, no shortcuts",
                media: [
                    FeedMediaItem(type: .workoutLog, workoutLog: WorkoutLogAttachment(
                        workoutName: "Full Body Hypertrophy",
                        duration: 68, exerciseCount: 8, totalVolume: 16400, fpEarned: 198, date: now.addingTimeInterval(-28800)
                    ))
                ],
                highFiveCount: 22,
                isHighFived: true,
                comments: [
                    PostComment(id: UUID(), user: sampleUsers[0], text: "Machine! 💪", timestamp: now.addingTimeInterval(-20000)),
                ],
                repostCount: 1,
                tags: [.bodybuilding, .progress],
                isFollowing: true
            ),
        ]
    }
}
