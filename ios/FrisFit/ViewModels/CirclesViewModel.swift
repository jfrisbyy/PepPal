import SwiftUI

@Observable
final class CirclesViewModel {
    var myCircles: [FitCircle] = []
    var publicCircles: [FitCircle] = []
    var selectedCircle: FitCircle?
    var selectedTab: CircleDetailTab = .tasks
    var searchQuery: String = ""
    var isLoading: Bool = false
    var showCreateCircle: Bool = false
    var showSettings: Bool = false
    var showInviteCode: Bool = false
    var showCompetitionChallenge: Bool = false
    var pendingInvites: [CircleInvite] = []
    var showMemberInvite: Bool = false
    var cheerlines: [Cheerline] = []

    var circleTasks: [CircleTask] = []
    var leaderboard: [LeaderboardMember] = []
    var messages: [CircleMessage] = []
    var posts: [CirclePost] = []
    var badges: [CircleBadge] = []
    var awards: [CircleAward] = []
    var competitions: [CircleCompetition] = []
    var taskRequests: [CircleTaskRequest] = []

    var newMessageText: String = ""
    var newPostText: String = ""

    var createName: String = ""
    var createDescription: String = ""
    var createDailyGoal: String = ""
    var createWeeklyGoal: String = ""
    var createIsPrivate: Bool = false

    var challengeInviteCode: String = ""
    var challengeName: String = ""
    var challengeDescription: String = ""
    var challengeType: CompetitionType = .targetPoints
    var challengeTargetPoints: String = ""
    var challengeEndDate: Date = Date().addingTimeInterval(7 * 86400)

    private let sampleUsers: [SocialUser] = [
        SocialUser(id: UUID(), name: "Alex Martinez", username: "alexm_fit", avatarInitial: "A", avatarColor: Color(red: 0.2, green: 0.6, blue: 0.9), activeProgramName: "Push Pull Legs", streak: 14, totalFP: 8420),
        SocialUser(id: UUID(), name: "Jordan Kim", username: "jkim_lifts", avatarInitial: "J", avatarColor: Color(red: 0.9, green: 0.4, blue: 0.3), activeProgramName: "Upper Lower", streak: 21, totalFP: 12350),
        SocialUser(id: UUID(), name: "Sam Taylor", username: "samtaylor", avatarInitial: "S", avatarColor: Color(red: 0.4, green: 0.8, blue: 0.5), activeProgramName: nil, streak: 7, totalFP: 5680),
        SocialUser(id: UUID(), name: "Riley Chen", username: "rileyc", avatarInitial: "R", avatarColor: Color(red: 0.8, green: 0.5, blue: 0.9), activeProgramName: "5/3/1", streak: 45, totalFP: 18900),
        SocialUser(id: UUID(), name: "Casey Nguyen", username: "casey_ng", avatarInitial: "C", avatarColor: Color(red: 0.9, green: 0.7, blue: 0.2), activeProgramName: "GZCLP", streak: 10, totalFP: 6750),
        SocialUser(id: UUID(), name: "Morgan Davis", username: "morgfit", avatarInitial: "M", avatarColor: Color(red: 0.3, green: 0.7, blue: 0.8), activeProgramName: "Full Body 3x", streak: 33, totalFP: 15200),
    ]

    private let meUser = SocialUser(id: UUID(), name: "You", username: "me", avatarInitial: "Y", avatarColor: PepTheme.teal, activeProgramName: "Push Pull Legs", streak: 12, totalFP: 7200)

    init() {
        loadMockData()
    }

    var filteredPublicCircles: [FitCircle] {
        guard !searchQuery.isEmpty else { return publicCircles }
        return publicCircles.filter {
            $0.name.localizedStandardContains(searchQuery) ||
            $0.description.localizedStandardContains(searchQuery)
        }
    }

    var currentUserRole: CircleRole? {
        selectedCircle?.members.first(where: { $0.user.id == meUser.id })?.role
    }

    var isAdminOrOwner: Bool {
        guard let role = currentUserRole else { return false }
        return role == .owner || role == .admin
    }

    var circleWeeklyPoints: Int {
        selectedCircle?.members.reduce(0) { $0 + $1.weeklyPoints } ?? 0
    }

    func selectCircle(_ circle: FitCircle) {
        selectedCircle = circle
        loadCircleData(for: circle)
    }

    func createCircle() {
        guard !createName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let members = [
            CircleMember(id: UUID(), user: meUser, role: .owner, joinedAt: Date(), totalPoints: 7200, weeklyPoints: 1850, goalStreak: 12, longestStreak: 18)
        ]
        let circle = FitCircle(
            id: UUID(),
            name: createName,
            description: createDescription,
            ownerId: meUser.id,
            isPrivate: createIsPrivate,
            dailyPointGoal: Int(createDailyGoal),
            weeklyPointGoal: Int(createWeeklyGoal),
            totalCirclePoints: 0,
            inviteCode: String(UUID().uuidString.prefix(8)).uppercased(),
            createdAt: Date(),
            members: members,
            accentColor: [PepTheme.teal, PepTheme.violet, PepTheme.amber, Color.green, Color.pink].randomElement()!
        )
        myCircles.append(circle)
        resetCreateFields()
        showCreateCircle = false
    }

    func joinCircle(_ circle: FitCircle) {
        var joined = circle
        let newMember = CircleMember(id: UUID(), user: meUser, role: .member, joinedAt: Date(), totalPoints: 0, weeklyPoints: 0, goalStreak: 0, longestStreak: 0)
        joined.members.append(newMember)
        myCircles.append(joined)
        publicCircles.removeAll { $0.id == circle.id }
    }

    func leaveCircle(_ circle: FitCircle) {
        myCircles.removeAll { $0.id == circle.id }
        if selectedCircle?.id == circle.id {
            selectedCircle = nil
        }
    }

    func toggleTaskCompletion(_ task: CircleTask) {
        guard let idx = circleTasks.firstIndex(where: { $0.id == task.id }) else { return }
        circleTasks[idx].isCompletedToday.toggle()
    }

    func sendMessage() {
        let trimmed = newMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let msg = CircleMessage(id: UUID(), sender: meUser, content: trimmed, imageUrl: nil, createdAt: Date())
        messages.append(msg)
        newMessageText = ""
    }

    func createPost() {
        let trimmed = newPostText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let post = CirclePost(id: UUID(), author: meUser, content: trimmed, imageUrl: nil, createdAt: Date(), likeCount: 0, isLiked: false, comments: [])
        posts.insert(post, at: 0)
        newPostText = ""
    }

    func togglePostLike(_ post: CirclePost) {
        guard let idx = posts.firstIndex(where: { $0.id == post.id }) else { return }
        posts[idx].isLiked.toggle()
        posts[idx].likeCount += posts[idx].isLiked ? 1 : -1
    }

    func addPostComment(_ post: CirclePost, text: String) {
        guard let idx = posts.firstIndex(where: { $0.id == post.id }) else { return }
        let comment = CirclePostComment(id: UUID(), author: meUser, content: text, createdAt: Date(), likeCount: 0, isLiked: false)
        posts[idx].comments.append(comment)
    }

    func approveTaskRequest(_ request: CircleTaskRequest) {
        taskRequests.removeAll { $0.id == request.id }
        let newTask = CircleTask(id: UUID(), name: request.taskName, value: request.taskValue, category: "Custom", taskType: .perPerson, createdBy: request.requester, isPenalty: false, isCompletedToday: false)
        circleTasks.append(newTask)
    }

    func rejectTaskRequest(_ request: CircleTaskRequest) {
        taskRequests.removeAll { $0.id == request.id }
    }

    func sendCheerline(to user: SocialUser, message: String) {
        let cheerline = Cheerline(id: UUID(), sender: meUser, message: message, expiresAt: Date().addingTimeInterval(86400), read: false, createdAt: Date())
        cheerlines.append(cheerline)
    }

    private func resetCreateFields() {
        createName = ""
        createDescription = ""
        createDailyGoal = ""
        createWeeklyGoal = ""
        createIsPrivate = false
    }

    private func loadCircleData(for circle: FitCircle) {
        circleTasks = [
            CircleTask(id: UUID(), name: "Complete Workout", value: 150, category: "Strength", taskType: .perPerson, createdBy: sampleUsers[0], isPenalty: false, isCompletedToday: true),
            CircleTask(id: UUID(), name: "10,000 Steps", value: 100, category: "Cardio", taskType: .perPerson, createdBy: sampleUsers[1], isPenalty: false, isCompletedToday: false),
            CircleTask(id: UUID(), name: "Hit Protein Goal", value: 80, category: "Nutrition", taskType: .perPerson, createdBy: sampleUsers[0], isPenalty: false, isCompletedToday: true),
            CircleTask(id: UUID(), name: "Group 5K Run", value: 200, category: "Cardio", taskType: .circleTask, createdBy: sampleUsers[2], isPenalty: false, isCompletedToday: false),
            CircleTask(id: UUID(), name: "Drink Gallon Water", value: 60, category: "Nutrition", taskType: .perPerson, createdBy: sampleUsers[0], isPenalty: false, isCompletedToday: false),
            CircleTask(id: UUID(), name: "Skip Workout (Penalty)", value: -50, category: "Lifestyle", taskType: .perPerson, createdBy: sampleUsers[1], isPenalty: true, isCompletedToday: false),
        ]

        leaderboard = circle.members.sorted(by: { $0.totalPoints > $1.totalPoints }).enumerated().map { idx, member in
            LeaderboardMember(
                id: member.id,
                user: member.user,
                rank: idx + 1,
                totalPoints: member.totalPoints,
                goalStreak: member.goalStreak,
                longestStreak: member.longestStreak,
                weeklyHistory: (0..<12).map { _ in Int.random(in: 500...2500) },
                topTasks: [
                    TaskTotal(taskName: "Complete Workout", count: Int.random(in: 8...30)),
                    TaskTotal(taskName: "10,000 Steps", count: Int.random(in: 5...25)),
                    TaskTotal(taskName: "Hit Protein Goal", count: Int.random(in: 10...28)),
                ]
            )
        }

        let now = Date()
        messages = [
            CircleMessage(id: UUID(), sender: sampleUsers[0], content: "Just crushed a new deadlift PR! 💪", imageUrl: nil, createdAt: now.addingTimeInterval(-3600)),
            CircleMessage(id: UUID(), sender: sampleUsers[1], content: "Nice! What did you hit?", imageUrl: nil, createdAt: now.addingTimeInterval(-3000)),
            CircleMessage(id: UUID(), sender: sampleUsers[0], content: "405 for a clean double", imageUrl: nil, createdAt: now.addingTimeInterval(-2700)),
            CircleMessage(id: UUID(), sender: sampleUsers[2], content: "Beast mode 🔥", imageUrl: nil, createdAt: now.addingTimeInterval(-1800)),
            CircleMessage(id: UUID(), sender: meUser, content: "Congrats! I'm going for mine tomorrow", imageUrl: nil, createdAt: now.addingTimeInterval(-900)),
        ]

        posts = [
            CirclePost(id: UUID(), author: sampleUsers[3], content: "Week 3 of our cut is going strong. Down 4lbs collectively as a group. Keep pushing everyone! 🏋️‍♂️", imageUrl: nil, createdAt: now.addingTimeInterval(-7200), likeCount: 8, isLiked: true, comments: [
                CirclePostComment(id: UUID(), author: sampleUsers[0], content: "Let's gooo!", createdAt: now.addingTimeInterval(-5000), likeCount: 2, isLiked: false),
            ]),
            CirclePost(id: UUID(), author: sampleUsers[1], content: "New challenge idea: first to log 20 workouts this month gets bragging rights. Who's in?", imageUrl: nil, createdAt: now.addingTimeInterval(-86400), likeCount: 5, isLiked: false, comments: []),
        ]

        badges = [
            CircleBadge(id: UUID(), name: "Iron Streak", description: "Complete a 30-day workout streak", icon: "flame.fill", required: 30, progress: 22, earned: false, rewardType: .points, rewardPoints: 500, rewardGift: nil),
            CircleBadge(id: UUID(), name: "Protein King", description: "Hit protein goal 20 times", icon: "fish.fill", required: 20, progress: 20, earned: true, rewardType: .both, rewardPoints: 200, rewardGift: "Custom shaker bottle"),
            CircleBadge(id: UUID(), name: "5K Warrior", description: "Complete 10 group runs", icon: "figure.run", required: 10, progress: 6, earned: false, rewardType: .gift, rewardPoints: nil, rewardGift: "Team t-shirt"),
            CircleBadge(id: UUID(), name: "Early Bird", description: "Log 15 workouts before 7 AM", icon: "sunrise.fill", required: 15, progress: 3, earned: false, rewardType: .points, rewardPoints: 300, rewardGift: nil),
        ]

        awards = [
            CircleAward(id: UUID(), name: "First to 10K", description: "First member to reach 10,000 total points", type: .firstTo, target: 10000, category: nil, winnerId: sampleUsers[3].id, winnerName: sampleUsers[3].name, rewardType: .both, rewardPoints: 1000, rewardGift: "Gold star pin"),
            CircleAward(id: UUID(), name: "Cardio King", description: "Most cardio completions this month", type: .mostInCategory, target: nil, category: "Cardio", winnerId: nil, winnerName: nil, rewardType: .points, rewardPoints: 500, rewardGift: nil),
            CircleAward(id: UUID(), name: "Weekly Champion", description: "Highest points in a single week", type: .weeklyChampion, target: nil, category: nil, winnerId: sampleUsers[0].id, winnerName: sampleUsers[0].name, rewardType: .points, rewardPoints: 250, rewardGift: nil),
        ]

        let opponentCircle = CompetitionCircleInfo(id: UUID(), name: "Iron Warriors", memberCount: 5)
        let thisCircle = CompetitionCircleInfo(id: circle.id, name: circle.name, memberCount: circle.memberCount)
        competitions = [
            CircleCompetition(id: UUID(), name: "January Showdown", description: "Most total points in January", competitionType: .timed, circleOne: thisCircle, circleTwo: opponentCircle, startDate: now.addingTimeInterval(-604800), endDate: now.addingTimeInterval(604800 * 3), targetPoints: nil, circleOnePoints: 12450, circleTwoPoints: 11800, winnerId: nil, status: .active),
            CircleCompetition(id: UUID(), name: "Race to 50K", description: "First circle to 50,000 points wins", competitionType: .targetPoints, circleOne: thisCircle, circleTwo: CompetitionCircleInfo(id: UUID(), name: "Flex Factory", memberCount: 4), startDate: now.addingTimeInterval(-86400 * 14), endDate: nil, targetPoints: 50000, circleOnePoints: 32100, circleTwoPoints: 28700, winnerId: nil, status: .active),
        ]

        taskRequests = [
            CircleTaskRequest(id: UUID(), requester: sampleUsers[4], type: "add", taskName: "Morning Yoga", taskValue: 40, status: "pending", createdAt: now.addingTimeInterval(-43200)),
        ]
    }

    private func loadMockData() {
        let circleColors: [Color] = [
            Color(red: 0.0, green: 0.7, blue: 1.0),
            Color(red: 0.9, green: 0.3, blue: 0.5),
            Color(red: 0.3, green: 0.85, blue: 0.4),
        ]

        let circle1Members = [
            CircleMember(id: UUID(), user: meUser, role: .owner, joinedAt: Date().addingTimeInterval(-86400 * 30), totalPoints: 7200, weeklyPoints: 1850, goalStreak: 12, longestStreak: 18),
            CircleMember(id: UUID(), user: sampleUsers[0], role: .admin, joinedAt: Date().addingTimeInterval(-86400 * 28), totalPoints: 8420, weeklyPoints: 2100, goalStreak: 14, longestStreak: 22),
            CircleMember(id: UUID(), user: sampleUsers[1], role: .member, joinedAt: Date().addingTimeInterval(-86400 * 25), totalPoints: 12350, weeklyPoints: 2800, goalStreak: 21, longestStreak: 21),
            CircleMember(id: UUID(), user: sampleUsers[2], role: .member, joinedAt: Date().addingTimeInterval(-86400 * 20), totalPoints: 5680, weeklyPoints: 1200, goalStreak: 7, longestStreak: 15),
            CircleMember(id: UUID(), user: sampleUsers[3], role: .member, joinedAt: Date().addingTimeInterval(-86400 * 15), totalPoints: 18900, weeklyPoints: 3200, goalStreak: 45, longestStreak: 45),
        ]

        let circle2Members = [
            CircleMember(id: UUID(), user: meUser, role: .member, joinedAt: Date().addingTimeInterval(-86400 * 10), totalPoints: 3200, weeklyPoints: 1100, goalStreak: 5, longestStreak: 8),
            CircleMember(id: UUID(), user: sampleUsers[4], role: .owner, joinedAt: Date().addingTimeInterval(-86400 * 45), totalPoints: 6750, weeklyPoints: 1600, goalStreak: 10, longestStreak: 16),
            CircleMember(id: UUID(), user: sampleUsers[5], role: .admin, joinedAt: Date().addingTimeInterval(-86400 * 40), totalPoints: 15200, weeklyPoints: 2900, goalStreak: 33, longestStreak: 33),
        ]

        myCircles = [
            FitCircle(id: UUID(), name: "Gym Bros", description: "Daily accountability for strength training", ownerId: meUser.id, isPrivate: false, dailyPointGoal: 300, weeklyPointGoal: 2000, totalCirclePoints: 52550, inviteCode: "GYMBR0S1", createdAt: Date().addingTimeInterval(-86400 * 30), members: circle1Members, accentColor: circleColors[0]),
            FitCircle(id: UUID(), name: "Cut Season", description: "Summer shred accountability crew", ownerId: sampleUsers[4].id, isPrivate: true, dailyPointGoal: 250, weeklyPointGoal: 1500, totalCirclePoints: 25150, inviteCode: "CUTS3ASN", createdAt: Date().addingTimeInterval(-86400 * 45), members: circle2Members, accentColor: circleColors[1]),
        ]

        let pub1Members = [
            CircleMember(id: UUID(), user: sampleUsers[0], role: .owner, joinedAt: Date().addingTimeInterval(-86400 * 60), totalPoints: 22000, weeklyPoints: 3100, goalStreak: 30, longestStreak: 42),
            CircleMember(id: UUID(), user: sampleUsers[3], role: .member, joinedAt: Date().addingTimeInterval(-86400 * 50), totalPoints: 18000, weeklyPoints: 2700, goalStreak: 20, longestStreak: 28),
        ]
        let pub2Members = [
            CircleMember(id: UUID(), user: sampleUsers[5], role: .owner, joinedAt: Date().addingTimeInterval(-86400 * 90), totalPoints: 30000, weeklyPoints: 3500, goalStreak: 55, longestStreak: 55),
        ]

        publicCircles = [
            FitCircle(id: UUID(), name: "Iron Warriors", description: "Powerlifting focused group. Heavy weights, big gains.", ownerId: sampleUsers[0].id, isPrivate: false, dailyPointGoal: 400, weeklyPointGoal: 2500, totalCirclePoints: 40000, inviteCode: "IR0NWAR1", createdAt: Date().addingTimeInterval(-86400 * 60), members: pub1Members, accentColor: Color(red: 0.9, green: 0.6, blue: 0.1)),
            FitCircle(id: UUID(), name: "Morning Grind", description: "5 AM workout crew. No excuses.", ownerId: sampleUsers[5].id, isPrivate: false, dailyPointGoal: 200, weeklyPointGoal: 1200, totalCirclePoints: 30000, inviteCode: "MRNGRND1", createdAt: Date().addingTimeInterval(-86400 * 90), members: pub2Members, accentColor: Color(red: 0.5, green: 0.3, blue: 0.9)),
        ]

        pendingInvites = [
            CircleInvite(id: UUID(), circleId: UUID(), circleName: "Flex Factory", inviter: sampleUsers[2], status: "pending", createdAt: Date().addingTimeInterval(-3600)),
        ]

        cheerlines = [
            Cheerline(id: UUID(), sender: sampleUsers[0], message: "You're killing it this week! Keep going! 🔥", expiresAt: Date().addingTimeInterval(43200), read: false, createdAt: Date().addingTimeInterval(-1800)),
        ]
    }
}

nonisolated enum CircleDetailTab: String, CaseIterable, Sendable {
    case tasks = "Tasks"
    case posts = "Posts"
    case chat = "Chat"
    case compete = "Compete"
    case badges = "Badges"

    var icon: String {
        switch self {
        case .tasks: return "checkmark.circle"
        case .posts: return "text.bubble"
        case .chat: return "bubble.left.and.bubble.right"
        case .compete: return "flag.2.crossed"
        case .badges: return "medal"
        }
    }
}
