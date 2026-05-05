import SwiftUI
import Supabase

@Observable
final class GroupsViewModel {
    var myGroups: [FitGroup] = []
    var discoverGroups: [FitGroup] = []
    var searchQuery: String = ""
    var isSearching: Bool = false
    var pendingRequestGroupIDs: Set<UUID> = []

    var filteredMyGroups: [FitGroup] {
        if searchQuery.isEmpty { return myGroups }
        return myGroups.filter {
            $0.name.localizedStandardContains(searchQuery) ||
            $0.description.localizedStandardContains(searchQuery)
        }
    }

    var filteredDiscoverGroups: [FitGroup] {
        if searchQuery.isEmpty { return discoverGroups }
        return discoverGroups.filter {
            $0.name.localizedStandardContains(searchQuery) ||
            $0.description.localizedStandardContains(searchQuery)
        }
    }

    private let myID = UUID()

    private let sampleUsers: [SocialUser] = [
        SocialUser(id: UUID(), name: "Alex Martinez", username: "alexm_fit", avatarInitial: "A", avatarColor: Color(red: 0.2, green: 0.6, blue: 0.9), activeProgramName: "Push Pull Legs", streak: 14, totalFP: 8420),
        SocialUser(id: UUID(), name: "Jordan Kim", username: "jkim_lifts", avatarInitial: "J", avatarColor: Color(red: 0.9, green: 0.4, blue: 0.3), activeProgramName: "Upper Lower", streak: 21, totalFP: 12350),
        SocialUser(id: UUID(), name: "Sam Taylor", username: "samtaylor", avatarInitial: "S", avatarColor: Color(red: 0.4, green: 0.8, blue: 0.5), activeProgramName: nil, streak: 7, totalFP: 5680),
        SocialUser(id: UUID(), name: "Riley Chen", username: "rileyc", avatarInitial: "R", avatarColor: Color(red: 0.8, green: 0.5, blue: 0.9), activeProgramName: "5/3/1", streak: 45, totalFP: 18900),
        SocialUser(id: UUID(), name: "Casey Nguyen", username: "casey_ng", avatarInitial: "C", avatarColor: Color(red: 0.9, green: 0.7, blue: 0.2), activeProgramName: "GZCLP", streak: 10, totalFP: 6750),
        SocialUser(id: UUID(), name: "Morgan Davis", username: "morgfit", avatarInitial: "M", avatarColor: Color(red: 0.3, green: 0.7, blue: 0.8), activeProgramName: "Full Body 3x", streak: 33, totalFP: 15200),
    ]

    private var meUser: SocialUser {
        SocialUser(id: myID, name: "You", username: "me", avatarInitial: "Y", avatarColor: PepTheme.teal, activeProgramName: "Push Pull Legs", streak: 12, totalFP: 7200)
    }

    init() {
        loadMockData()
    }

    var uploadingAttachment: Bool = false

    func sendMessage(to groupID: UUID, text: String, attachments: [DirectMessageAttachment] = []) {
        guard let index = myGroups.firstIndex(where: { $0.id == groupID }) else { return }
        let message = GroupMessage(sender: meUser, text: text, attachments: attachments)
        myGroups[index].messages.append(message)
    }

    func sendImage(to groupID: UUID, data: Data) async {
        let att = await uploadLocalImage(data: data)
        sendMessage(to: groupID, text: "", attachments: [att])
    }

    func sendVideo(to groupID: UUID, data: Data, duration: Double?) async {
        let att = await uploadLocalVideo(data: data, duration: duration)
        sendMessage(to: groupID, text: "", attachments: [att])
    }

    func sendVoice(to groupID: UUID, data: Data, duration: Double?) async {
        let att = await uploadLocalVoice(data: data, duration: duration)
        sendMessage(to: groupID, text: "", attachments: [att])
    }

    private func uploadLocalImage(data: Data) async -> DirectMessageAttachment {
        uploadingAttachment = true
        defer { uploadingAttachment = false }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("groupimg_\(UUID().uuidString).jpg")
        try? data.write(to: url)
        return DirectMessageAttachment(kind: .image, url: url.absoluteString)
    }

    private func uploadLocalVideo(data: Data, duration: Double?) async -> DirectMessageAttachment {
        uploadingAttachment = true
        defer { uploadingAttachment = false }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("groupvid_\(UUID().uuidString).mp4")
        try? data.write(to: url)
        return DirectMessageAttachment(kind: .video, url: url.absoluteString, durationSeconds: duration)
    }

    private func uploadLocalVoice(data: Data, duration: Double?) async -> DirectMessageAttachment {
        uploadingAttachment = true
        defer { uploadingAttachment = false }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("groupvoice_\(UUID().uuidString).m4a")
        try? data.write(to: url)
        return DirectMessageAttachment(kind: .voice, url: url.absoluteString, durationSeconds: duration)
    }

    func toggleMessageLike(groupID: UUID, messageID: UUID) {
        guard let gIndex = myGroups.firstIndex(where: { $0.id == groupID }),
              let mIndex = myGroups[gIndex].messages.firstIndex(where: { $0.id == messageID }) else { return }
        myGroups[gIndex].messages[mIndex].isLiked.toggle()
        myGroups[gIndex].messages[mIndex].likeCount += myGroups[gIndex].messages[mIndex].isLiked ? 1 : -1
    }

    func joinGroup(_ group: FitGroup) {
        if group.privacy == .privateGroup {
            pendingRequestGroupIDs.insert(group.id)
            sendJoinRequestNotification(for: group)
        } else {
            var joined = group
            let member = GroupMember(id: UUID(), user: meUser, role: .member, joinedAt: Date())
            joined.members.append(member)
            joined.memberCount += 1
            myGroups.append(joined)
            discoverGroups.removeAll { $0.id == group.id }
        }
    }

    func isRequestPending(for groupID: UUID) -> Bool {
        pendingRequestGroupIDs.contains(groupID)
    }

    private func sendJoinRequestNotification(for group: FitGroup) {
        Task {
            do {
                let _ = try AuthService.shared.currentUserId()
                let payload = CreateGroupJoinRequestNotification(
                    user_id: group.creatorID.uuidString.lowercased(),
                    type: "group_join_request",
                    title: "Group Join Request",
                    body: "\(meUser.name) has requested to join \(group.name)"
                )
                try await SupabaseService.shared.client
                    .from("notifications")
                    .insert(payload)
                    .execute()
            } catch {}
        }
    }

    func updateStatsConfig(groupID: UUID, config: GroupStatsConfig) {
        guard let index = myGroups.firstIndex(where: { $0.id == groupID }) else { return }
        myGroups[index].statsConfig = config
    }

    func toggleStatsEnabled(groupID: UUID) {
        guard let index = myGroups.firstIndex(where: { $0.id == groupID }) else { return }
        myGroups[index].statsConfig.isEnabled.toggle()
        if myGroups[index].statsConfig.isEnabled && myGroups[index].statsConfig.enabledMetrics.isEmpty {
            myGroups[index].statsConfig.enabledMetrics = [.steps, .workouts]
        }
    }

    func toggleStatsMetric(groupID: UUID, metric: GroupStatMetric) {
        guard let index = myGroups.firstIndex(where: { $0.id == groupID }) else { return }
        if myGroups[index].statsConfig.enabledMetrics.contains(metric) {
            myGroups[index].statsConfig.enabledMetrics.remove(metric)
        } else {
            myGroups[index].statsConfig.enabledMetrics.insert(metric)
        }
    }

    func setStatsPeriod(groupID: UUID, period: GroupStatsPeriod) {
        guard let index = myGroups.firstIndex(where: { $0.id == groupID }) else { return }
        myGroups[index].statsConfig.period = period
    }

    func toggleMyStatsSharing(groupID: UUID) {
        guard let gIndex = myGroups.firstIndex(where: { $0.id == groupID }),
              let mIndex = myGroups[gIndex].members.firstIndex(where: { $0.user.username == "me" }) else { return }
        myGroups[gIndex].members[mIndex].isSharingStats.toggle()
    }

    func isCurrentUserAdmin(groupID: UUID) -> Bool {
        guard let group = myGroups.first(where: { $0.id == groupID }),
              let member = group.members.first(where: { $0.user.username == "me" }) else { return false }
        return member.role == .owner || member.role == .admin
    }

    func leaveGroup(_ groupID: UUID) {
        guard let group = myGroups.first(where: { $0.id == groupID }) else { return }
        myGroups.removeAll { $0.id == groupID }
        discoverGroups.append(group)
    }

    func createGroup(name: String, description: String, privacy: GroupPrivacy, iconName: String, accentColor: Color) {
        let member = GroupMember(id: UUID(), user: meUser, role: .owner, joinedAt: Date())
        let group = FitGroup(
            id: UUID(),
            name: name,
            description: description,
            privacy: privacy,
            accentColor: accentColor,
            iconName: iconName,
            memberCount: 1,
            members: [member],
            messages: [],
            createdAt: Date(),
            creatorID: myID
        )
        myGroups.insert(group, at: 0)
    }

    func group(for id: UUID) -> FitGroup? {
        myGroups.first { $0.id == id }
    }

    private func mockStats(steps: Double, workouts: Double, miles: Double, active: Double, calories: Double, streak: Double) -> GroupMemberStats {
        GroupMemberStats(values: [
            .steps: steps,
            .workouts: workouts,
            .runMiles: miles,
            .activeMinutes: active,
            .calories: calories,
            .streak: streak,
        ])
    }

    private func loadMockData() {
        let now = Date()

        myGroups = [
            FitGroup(
                id: UUID(),
                name: "Morning Lifters",
                description: "Early birds who get their gains before sunrise. Share tips, PRs, and morning routines.",
                privacy: .privateGroup,
                accentColor: PepTheme.teal,
                iconName: "sunrise.fill",
                memberCount: 8,
                members: [
                    GroupMember(id: UUID(), user: meUser, role: .owner, joinedAt: now.addingTimeInterval(-604800), stats: mockStats(steps: 48230, workouts: 5, miles: 12.4, active: 312, calories: 3420, streak: 12)),
                    GroupMember(id: UUID(), user: sampleUsers[0], role: .admin, joinedAt: now.addingTimeInterval(-518400), stats: mockStats(steps: 62410, workouts: 6, miles: 18.2, active: 410, calories: 4180, streak: 14)),
                    GroupMember(id: UUID(), user: sampleUsers[1], role: .member, joinedAt: now.addingTimeInterval(-432000), stats: mockStats(steps: 38120, workouts: 4, miles: 8.6, active: 240, calories: 2890, streak: 21)),
                    GroupMember(id: UUID(), user: sampleUsers[3], role: .member, joinedAt: now.addingTimeInterval(-345600), stats: mockStats(steps: 71240, workouts: 7, miles: 22.1, active: 480, calories: 5120, streak: 45)),
                ],
                messages: [
                    GroupMessage(sender: sampleUsers[0], text: "5AM squad checking in! Hit a new squat PR today 🏋️", timestamp: now.addingTimeInterval(-7200), likeCount: 4),
                    GroupMessage(sender: sampleUsers[1], text: "Nice! What weight?", timestamp: now.addingTimeInterval(-6800)),
                    GroupMessage(sender: sampleUsers[0], text: "315 for a clean triple", timestamp: now.addingTimeInterval(-6500), likeCount: 6),
                    GroupMessage(sender: sampleUsers[3], text: "Beast mode 💪 I'm working up to 275 this week", timestamp: now.addingTimeInterval(-3600), likeCount: 2),
                    GroupMessage(sender: sampleUsers[1], text: "Tomorrow we're doing pull day right? Who's in?", timestamp: now.addingTimeInterval(-1800)),
                ],
                createdAt: now.addingTimeInterval(-604800),
                creatorID: myID,
                statsConfig: GroupStatsConfig(isEnabled: true, enabledMetrics: [.workouts, .activeMinutes, .streak], period: .week)
            ),
            FitGroup(
                id: UUID(),
                name: "Running Club NYC",
                description: "Runners in New York City. Weekly group runs, race updates, and route sharing.",
                privacy: .publicGroup,
                accentColor: PepTheme.blue,
                iconName: "figure.run",
                memberCount: 124,
                members: [
                    GroupMember(id: UUID(), user: meUser, role: .member, joinedAt: now.addingTimeInterval(-259200), stats: mockStats(steps: 52310, workouts: 3, miles: 16.8, active: 280, calories: 3120, streak: 12)),
                    GroupMember(id: UUID(), user: sampleUsers[2], role: .owner, joinedAt: now.addingTimeInterval(-2592000), stats: mockStats(steps: 89420, workouts: 5, miles: 34.2, active: 620, calories: 6240, streak: 87)),
                    GroupMember(id: UUID(), user: sampleUsers[4], role: .admin, joinedAt: now.addingTimeInterval(-1728000), stats: mockStats(steps: 64210, workouts: 4, miles: 24.6, active: 410, calories: 4380, streak: 28)),
                    GroupMember(id: UUID(), user: sampleUsers[5], role: .member, joinedAt: now.addingTimeInterval(-864000), stats: mockStats(steps: 71820, workouts: 4, miles: 28.9, active: 510, calories: 4920, streak: 33)),
                ],
                messages: [
                    GroupMessage(sender: sampleUsers[2], text: "Saturday morning run at Central Park, 7AM. Meet at the Bethesda Fountain. All paces welcome!", timestamp: now.addingTimeInterval(-14400), likeCount: 18),
                    GroupMessage(sender: sampleUsers[4], text: "I'll be there! Aiming for a 5 miler", timestamp: now.addingTimeInterval(-12000), likeCount: 3),
                    GroupMessage(sender: sampleUsers[5], text: "Count me in! Perfect weather this weekend", timestamp: now.addingTimeInterval(-10800), likeCount: 2),
                    GroupMessage(sender: sampleUsers[2], text: "Brooklyn Half registration is open btw — who's signing up? 🏃", timestamp: now.addingTimeInterval(-3600), likeCount: 8),
                ],
                createdAt: now.addingTimeInterval(-2592000),
                creatorID: sampleUsers[2].id,
                statsConfig: GroupStatsConfig(isEnabled: true, enabledMetrics: [.runMiles, .steps, .activeMinutes], period: .week)
            ),
            FitGroup(
                id: UUID(),
                name: "Accountability Partners",
                description: "Stay on track together. Daily check-ins and support.",
                privacy: .privateGroup,
                accentColor: PepTheme.violet,
                iconName: "checkmark.shield.fill",
                memberCount: 4,
                members: [
                    GroupMember(id: UUID(), user: meUser, role: .member, joinedAt: now.addingTimeInterval(-172800), stats: mockStats(steps: 48230, workouts: 5, miles: 12.4, active: 312, calories: 3420, streak: 12)),
                    GroupMember(id: UUID(), user: sampleUsers[1], role: .owner, joinedAt: now.addingTimeInterval(-604800), stats: mockStats(steps: 38120, workouts: 4, miles: 8.6, active: 240, calories: 2890, streak: 21)),
                    GroupMember(id: UUID(), user: sampleUsers[3], role: .member, joinedAt: now.addingTimeInterval(-518400), stats: mockStats(steps: 71240, workouts: 7, miles: 22.1, active: 480, calories: 5120, streak: 45)),
                    GroupMember(id: UUID(), user: sampleUsers[5], role: .member, joinedAt: now.addingTimeInterval(-432000), stats: mockStats(steps: 49810, workouts: 5, miles: 14.2, active: 320, calories: 3580, streak: 33)),
                ],
                messages: [
                    GroupMessage(sender: sampleUsers[1], text: "Day 21 check-in ✅ Upper body + 30 min cardio done", timestamp: now.addingTimeInterval(-28800), likeCount: 3),
                    GroupMessage(sender: sampleUsers[3], text: "✅ Legs day complete. Feeling destroyed but proud", timestamp: now.addingTimeInterval(-25200), likeCount: 2),
                    GroupMessage(sender: sampleUsers[5], text: "Rest day for me but hit my protein goal 🎯", timestamp: now.addingTimeInterval(-21600), likeCount: 1),
                    GroupMessage(sender: sampleUsers[1], text: "Everyone on track this week! Let's keep it going 🔥", timestamp: now.addingTimeInterval(-7200), likeCount: 4),
                ],
                createdAt: now.addingTimeInterval(-604800),
                creatorID: sampleUsers[1].id,
                statsConfig: GroupStatsConfig(isEnabled: false, enabledMetrics: [.workouts, .streak], period: .week)
            ),
        ]

        discoverGroups = [
            FitGroup(
                id: UUID(),
                name: "Powerlifting Hub",
                description: "For serious powerlifters. Programming discussion, meet prep, and technique tips.",
                privacy: .publicGroup,
                accentColor: .red,
                iconName: "figure.strengthtraining.traditional",
                memberCount: 342,
                members: [
                    GroupMember(id: UUID(), user: sampleUsers[3], role: .owner, joinedAt: now.addingTimeInterval(-5184000)),
                    GroupMember(id: UUID(), user: sampleUsers[0], role: .admin, joinedAt: now.addingTimeInterval(-4320000)),
                ],
                messages: [
                    GroupMessage(sender: sampleUsers[3], text: "New meet PR on deadlift: 585! Time to aim for 600", timestamp: now.addingTimeInterval(-1800), likeCount: 42),
                ],
                createdAt: now.addingTimeInterval(-5184000),
                creatorID: sampleUsers[3].id
            ),
            FitGroup(
                id: UUID(),
                name: "Swim Squad",
                description: "Open water and pool swimmers. Technique, workouts, and swim gear reviews.",
                privacy: .publicGroup,
                accentColor: Color(red: 0.0, green: 0.6, blue: 0.9),
                iconName: "figure.pool.swim",
                memberCount: 89,
                members: [
                    GroupMember(id: UUID(), user: sampleUsers[2], role: .owner, joinedAt: now.addingTimeInterval(-3456000)),
                ],
                messages: [
                    GroupMessage(sender: sampleUsers[2], text: "Anyone tried the new Speedo Fastskin? Worth the price?", timestamp: now.addingTimeInterval(-7200), likeCount: 6),
                ],
                createdAt: now.addingTimeInterval(-3456000),
                creatorID: sampleUsers[2].id
            ),
            FitGroup(
                id: UUID(),
                name: "Nutrition Nerds",
                description: "Meal prep ideas, macro tracking, supplement reviews, and nutrition science.",
                privacy: .publicGroup,
                accentColor: PepTheme.amber,
                iconName: "fork.knife",
                memberCount: 215,
                members: [
                    GroupMember(id: UUID(), user: sampleUsers[4], role: .owner, joinedAt: now.addingTimeInterval(-4320000)),
                ],
                messages: [
                    GroupMessage(sender: sampleUsers[4], text: "High protein meal prep Sunday! Sharing my 2000 cal/180g protein plan", timestamp: now.addingTimeInterval(-14400), likeCount: 24),
                ],
                createdAt: now.addingTimeInterval(-4320000),
                creatorID: sampleUsers[4].id
            ),
            FitGroup(
                id: UUID(),
                name: "Cycling Collective",
                description: "Road cycling enthusiasts. Routes, gear, and weekend ride planning.",
                privacy: .privateGroup,
                accentColor: Color(red: 0.2, green: 0.8, blue: 0.4),
                iconName: "bicycle",
                memberCount: 56,
                members: [
                    GroupMember(id: UUID(), user: sampleUsers[5], role: .owner, joinedAt: now.addingTimeInterval(-2592000)),
                ],
                messages: [
                    GroupMessage(sender: sampleUsers[5], text: "Century ride next month — who's training?", timestamp: now.addingTimeInterval(-21600), likeCount: 11),
                ],
                createdAt: now.addingTimeInterval(-2592000),
                creatorID: sampleUsers[5].id
            ),
        ]
    }
}
