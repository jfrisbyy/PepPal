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

    private var dataLoaded: Bool = false

    init() {
        Task { await self.refresh() }
    }

    func refresh() async {
        await loadFromSupabaseAsync(force: true)
    }

    func loadFromSupabase() {
        guard AuthService.shared.authState == .signedIn, !dataLoaded else { return }
        Task { await self.loadFromSupabaseAsync(force: false) }
    }

    private func loadFromSupabaseAsync(force: Bool) async {
        guard AuthService.shared.authState == .signedIn else {
            myCircles = []
            publicCircles = []
            return
        }
        if !force && dataLoaded { return }
        dataLoaded = true
        isLoading = true
        defer { isLoading = false }
        do {
            let userId = try AuthService.shared.currentUserId()
            let myRaw = try await CircleService.shared.fetchMyCircles(userId: userId)
            var myConverted: [FitCircle] = []
            for circle in myRaw {
                guard let cid = circle.id else { continue }
                let members = try await CircleService.shared.fetchMembers(circleId: cid)
                myConverted.append(CircleService.shared.toFitCircle(circle, members: members))
            }
            myCircles = myConverted

            let pubRaw = try await CircleService.shared.fetchPublicCircles(userId: userId)
            var pubConverted: [FitCircle] = []
            for circle in pubRaw {
                guard let cid = circle.id else { continue }
                let members = try await CircleService.shared.fetchMembers(circleId: cid)
                pubConverted.append(CircleService.shared.toFitCircle(circle, members: members))
            }
            publicCircles = pubConverted
        } catch {
            print("CirclesViewModel.loadFromSupabase error: \(error)")
        }
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
        persistCreateCircle(name: createName, description: createDescription, isPrivate: createIsPrivate)
        resetCreateFields()
        showCreateCircle = false
    }

    private func persistCreateCircle(name: String, description: String, isPrivate: Bool) {
        guard AuthService.shared.authState == .signedIn else { return }
        Task {
            do {
                let userId = try AuthService.shared.currentUserId()
                _ = try await CircleService.shared.createCircle(userId: userId, name: name, description: description, isPrivate: isPrivate, accentColor: nil)
            } catch {}
        }
    }

    func joinCircle(_ circle: FitCircle) {
        var joined = circle
        let newMember = CircleMember(id: UUID(), user: meUser, role: .member, joinedAt: Date(), totalPoints: 0, weeklyPoints: 0, goalStreak: 0, longestStreak: 0)
        joined.members.append(newMember)
        myCircles.append(joined)
        publicCircles.removeAll { $0.id == circle.id }
        if AuthService.shared.authState == .signedIn {
            Task {
                do {
                    let userId = try AuthService.shared.currentUserId()
                    try await CircleService.shared.joinCircle(circleId: circle.id.uuidString, userId: userId)
                } catch {}
            }
        }
    }

    func leaveCircle(_ circle: FitCircle) {
        myCircles.removeAll { $0.id == circle.id }
        if selectedCircle?.id == circle.id {
            selectedCircle = nil
        }
        if AuthService.shared.authState == .signedIn {
            Task {
                do {
                    let userId = try AuthService.shared.currentUserId()
                    try await CircleService.shared.leaveCircle(circleId: circle.id.uuidString, userId: userId)
                } catch {}
            }
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
        // Real per-circle data starts empty until backed by Supabase tables.
        // The leaderboard is derived live from the members we already have.
        circleTasks = []
        messages = []
        posts = []
        badges = []
        awards = []
        competitions = []
        taskRequests = []

        leaderboard = circle.members
            .sorted(by: { $0.totalPoints > $1.totalPoints })
            .enumerated()
            .map { idx, member in
                LeaderboardMember(
                    id: member.id,
                    user: member.user,
                    rank: idx + 1,
                    totalPoints: member.totalPoints,
                    goalStreak: member.goalStreak,
                    longestStreak: member.longestStreak,
                    weeklyHistory: [],
                    topTasks: []
                )
            }
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
