import SwiftUI

/// Builds curated demo groups so the Community → Groups section is populated
/// for every demo account screenshot.
@MainActor
final class MockGroupsService {
    static let shared = MockGroupsService()
    private init() {}

    // Stable group IDs so navigation/state keep working across reloads.
    private let recompLabID = UUID(uuidString: "AAAA0001-0000-0000-0000-000000000001")!
    private let hybridSquadID = UUID(uuidString: "AAAA0002-0000-0000-0000-000000000002")!
    private let peptideID = UUID(uuidString: "AAAA0003-0000-0000-0000-000000000003")!
    private let comebackID = UUID(uuidString: "AAAA0004-0000-0000-0000-000000000004")!
    private let sleepID = UUID(uuidString: "AAAA0005-0000-0000-0000-000000000005")!

    // Extra background members (beyond the MockFriends roster) for fullness.
    private lazy var extraMembers: [SocialUser] = [
        SocialUser(id: UUID(uuidString: "B1B1B1B1-0000-0000-0000-000000000001")!, name: "Hana Cole", username: "hanac", avatarInitial: "H", avatarColor: PepTheme.violet, activeProgramName: "PPL 5x", streak: 22),
        SocialUser(id: UUID(uuidString: "B1B1B1B1-0000-0000-0000-000000000002")!, name: "Owen Park", username: "owen", avatarInitial: "O", avatarColor: PepTheme.teal, activeProgramName: "5/3/1", streak: 38),
        SocialUser(id: UUID(uuidString: "B1B1B1B1-0000-0000-0000-000000000003")!, name: "Lena Volkov", username: "lenav", avatarInitial: "L", avatarColor: PepTheme.amber, activeProgramName: "Hybrid", streak: 14),
        SocialUser(id: UUID(uuidString: "B1B1B1B1-0000-0000-0000-000000000004")!, name: "Kai Mensah", username: "kaim", avatarInitial: "K", avatarColor: PepTheme.blue, activeProgramName: "Bulk", streak: 9),
        SocialUser(id: UUID(uuidString: "B1B1B1B1-0000-0000-0000-000000000005")!, name: "Iris Yamada", username: "irisy", avatarInitial: "I", avatarColor: PepTheme.violet, activeProgramName: "Recomp", streak: 31),
        SocialUser(id: UUID(uuidString: "B1B1B1B1-0000-0000-0000-000000000006")!, name: "Bryce Allen", username: "brycea", avatarInitial: "B", avatarColor: PepTheme.teal, activeProgramName: "Push/Pull", streak: 6),
        SocialUser(id: UUID(uuidString: "B1B1B1B1-0000-0000-0000-000000000007")!, name: "Coach Reyes", username: "creyes", avatarInitial: "C", avatarColor: PepTheme.amber, activeProgramName: "Coach", streak: 96),
        SocialUser(id: UUID(uuidString: "B1B1B1B1-0000-0000-0000-000000000008")!, name: "Sofia Greer", username: "sofiag", avatarInitial: "S", avatarColor: PepTheme.blue, activeProgramName: "Marathon", streak: 27),
    ]

    private func friendUsers() -> [SocialUser] {
        MockFriendsService.shared.profiles.map { $0.user }
    }

    private func t(_ minutesAgo: Double) -> Date {
        Date().addingTimeInterval(-minutesAgo * 60)
    }

    private func member(_ user: SocialUser, role: GroupMemberRole = .member, joinedDaysAgo: Double = 30) -> GroupMember {
        GroupMember(
            id: UUID(),
            user: user,
            role: role,
            joinedAt: Date().addingTimeInterval(-joinedDaysAgo * 86400),
            stats: GroupMemberStats(),
            isSharingStats: true
        )
    }

    /// Returns the demo current user as a SocialUser (best effort).
    private func meAsSocialUser() -> SocialUser {
        let name = ProfileService.shared.cachedDisplayName ?? (DemoModeProbe.activeScenario?.fullName ?? "You")
        let initial = String(name.prefix(1)).uppercased()
        let uid: UUID = {
            if let id = try? AuthService.shared.currentUserId(), let u = UUID(uuidString: id) { return u }
            return UUID()
        }()
        return SocialUser(
            id: uid,
            name: name,
            username: name.split(separator: " ").first.map { String($0).lowercased() } ?? "you",
            avatarInitial: initial,
            avatarColor: DemoModeProbe.activeScenario.map { _ in PepTheme.teal } ?? PepTheme.teal,
            avatarURL: ProfileService.shared.cachedAvatarUrl,
            activeProgramName: nil,
            streak: StreakManager.shared.streakData.currentStreak
        )
    }

    // MARK: - Public

    func groups(for scenario: DemoScenario) -> [FitGroup] {
        let friends = friendUsers()
        let me = meAsSocialUser()

        // Pull named friends from the mock roster by username so we always
        // hit the same persona across scenarios.
        func friend(_ username: String) -> SocialUser? {
            friends.first { $0.username == username }
        }

        let marcus = friend("marcus")
        let finn = friend("finn")
        let sara = friend("sarap")
        let diego = friend("diegor")
        let avery = friend("averyk")
        let jordan = friend("jblake")
        let riley = friend("rileyt")
        let nadia = friend("nadiab")

        // ----- Recomp Lab -----
        let recompLab = FitGroup(
            id: recompLabID,
            name: "Recomp Lab",
            description: "Lean recomp data — sleep, lifts, macros, peptides.",
            privacy: .privateGroup,
            accentColor: PepTheme.violet,
            iconName: "chart.bar.fill",
            memberCount: 9,
            members: [
                member(me, role: .member, joinedDaysAgo: 18),
                marcus.map { member($0, role: .owner, joinedDaysAgo: 142) },
                avery.map { member($0, role: .admin, joinedDaysAgo: 96) },
                riley.map { member($0, joinedDaysAgo: 64) },
                jordan.map { member($0, joinedDaysAgo: 42) },
                member(extraMembers[0], joinedDaysAgo: 38),
                member(extraMembers[4], joinedDaysAgo: 21),
                member(extraMembers[6], role: .admin, joinedDaysAgo: 180),
                member(extraMembers[1], joinedDaysAgo: 11),
            ].compactMap { $0 },
            messages: [
                marcus.map { GroupMessage(sender: $0, text: "Bumped protein floor to 200g this week — strength holding even at -300 deficit.", timestamp: t(58)) },
                avery.map { GroupMessage(sender: $0, text: "Week 8 of cut: pull-up +20kg×6 still moving. Sleep is the variable.", timestamp: t(34)) },
                riley.map { GroupMessage(sender: $0, text: "HRV trend: anyone else seeing dips on bench days? Mine drops 12% the morning after.", timestamp: t(12)) },
            ].compactMap { $0 },
            createdAt: Date().addingTimeInterval(-142 * 86400),
            creatorID: marcus?.id ?? me.id,
            statsConfig: GroupStatsConfig(isEnabled: true, enabledMetrics: [.workouts, .calories], period: .week)
        )

        // ----- Hybrid Squad -----
        let hybridSquad = FitGroup(
            id: hybridSquadID,
            name: "Hybrid Squad",
            description: "Lift + run + recover. Marathon block in progress.",
            privacy: .publicGroup,
            accentColor: PepTheme.teal,
            iconName: "figure.run",
            memberCount: 12,
            members: [
                member(me, joinedDaysAgo: 31),
                sara.map { member($0, role: .owner, joinedDaysAgo: 120) },
                extraMembers.last.map { member($0, role: .admin, joinedDaysAgo: 78) }, // Sofia
                finn.map { member($0, joinedDaysAgo: 56) },
                riley.map { member($0, joinedDaysAgo: 41) },
                member(extraMembers[2], joinedDaysAgo: 28),
                member(extraMembers[5], joinedDaysAgo: 19),
                member(extraMembers[3], joinedDaysAgo: 12),
                member(extraMembers[0], joinedDaysAgo: 8),
                member(extraMembers[4], joinedDaysAgo: 6),
                member(extraMembers[6], joinedDaysAgo: 220),
                member(extraMembers[1], joinedDaysAgo: 4),
            ].compactMap { $0 },
            messages: [
                sara.map { GroupMessage(sender: $0, text: "Tempo run 8mi done — 6:42 pace. Legs felt heavy until mile 4.", timestamp: t(72)) },
                extraMembers.last.map { GroupMessage(sender: $0, text: "Long run Sunday — anyone up for 14? Meeting at the bridge at 6:30am.", timestamp: t(41)) },
                finn.map { GroupMessage(sender: $0, text: "How are you all handling lift volume on long run weeks? I'm cutting bench down to 1 day.", timestamp: t(18)) },
                riley.map { GroupMessage(sender: $0, text: "Magnesium pre-bed has been a game changer for recovery between sessions.", timestamp: t(7)) },
            ].compactMap { $0 },
            createdAt: Date().addingTimeInterval(-120 * 86400),
            creatorID: sara?.id ?? me.id,
            statsConfig: GroupStatsConfig(isEnabled: true, enabledMetrics: [.runMiles, .activeMinutes], period: .week)
        )

        // ----- Peptide Practitioners -----
        let peptide = FitGroup(
            id: peptideID,
            name: "Peptide Practitioners",
            description: "BPC-157, TB-500, GLP-1, GH stacks. Data over bro-science.",
            privacy: .privateGroup,
            accentColor: PepTheme.amber,
            iconName: "syringe.fill",
            memberCount: 8,
            members: [
                member(me, joinedDaysAgo: 22),
                marcus.map { member($0, role: .owner, joinedDaysAgo: 210) },
                jordan.map { member($0, role: .admin, joinedDaysAgo: 88) },
                avery.map { member($0, joinedDaysAgo: 60) },
                riley.map { member($0, joinedDaysAgo: 51) },
                diego.map { member($0, joinedDaysAgo: 28) },
                member(extraMembers[6], role: .admin, joinedDaysAgo: 300),
                member(extraMembers[2], joinedDaysAgo: 14),
            ].compactMap { $0 },
            messages: [
                jordan.map { GroupMessage(sender: $0, text: "Retatrutide week 4 — appetite stable, no nausea. Down 1.8kg, lifts holding.", timestamp: t(95)) },
                marcus.map { GroupMessage(sender: $0, text: "Last panel: ALT 68. Talking to my doc before the next block. Will share what we adjust.", timestamp: t(46)) },
                avery.map { GroupMessage(sender: $0, text: "Tirz dose day always wrecks me until ~36h post. Low-FODMAP plan helps a lot.", timestamp: t(22)) },
                diego.map { GroupMessage(sender: $0, text: "Semaglutide 0.5mg week 5 — first week I'm not constantly hungry. Logging meals helps me eat enough.", timestamp: t(9)) },
            ].compactMap { $0 },
            createdAt: Date().addingTimeInterval(-210 * 86400),
            creatorID: marcus?.id ?? me.id,
            statsConfig: GroupStatsConfig(isEnabled: false, enabledMetrics: [], period: .week)
        )

        // ----- Comeback Crew -----
        let comeback = FitGroup(
            id: comebackID,
            name: "Comeback Crew",
            description: "No-shame restart. Streaks reset, comebacks count.",
            privacy: .publicGroup,
            accentColor: PepTheme.blue,
            iconName: "arrow.uturn.up",
            memberCount: 11,
            members: [
                member(me, joinedDaysAgo: 9),
                diego.map { member($0, role: .owner, joinedDaysAgo: 88) },
                nadia.map { member($0, role: .admin, joinedDaysAgo: 60) },
                finn.map { member($0, joinedDaysAgo: 40) },
                member(extraMembers[3], joinedDaysAgo: 24),
                member(extraMembers[5], joinedDaysAgo: 21),
                member(extraMembers[1], joinedDaysAgo: 15),
                member(extraMembers[0], joinedDaysAgo: 9),
                member(extraMembers[4], joinedDaysAgo: 6),
                member(extraMembers[2], joinedDaysAgo: 4),
                member(extraMembers[6], role: .admin, joinedDaysAgo: 150),
            ].compactMap { $0 },
            messages: [
                diego.map { GroupMessage(sender: $0, text: "Week 2 back in the gym. Bench 80kg×5 felt like the first time. Onwards.", timestamp: t(120)) },
                nadia.map { GroupMessage(sender: $0, text: "Comeback day 1 after travel killed my streak. 10min mobility + a real breakfast. Done.", timestamp: t(48)) },
                finn.map { GroupMessage(sender: $0, text: "Don't measure the comeback by the streak number. Measure by the next session.", timestamp: t(15)) },
            ].compactMap { $0 },
            createdAt: Date().addingTimeInterval(-88 * 86400),
            creatorID: diego?.id ?? me.id,
            statsConfig: GroupStatsConfig(isEnabled: true, enabledMetrics: [.workouts, .steps], period: .week)
        )

        // ----- Sleep & Recovery Stack -----
        let sleep = FitGroup(
            id: sleepID,
            name: "Sleep & Recovery Stack",
            description: "HRV, REM, magnesium, apigenin, DSIP. Nerds welcome.",
            privacy: .privateGroup,
            accentColor: .indigo,
            iconName: "moon.stars.fill",
            memberCount: 7,
            members: [
                member(me, joinedDaysAgo: 14),
                riley.map { member($0, role: .owner, joinedDaysAgo: 198) },
                marcus.map { member($0, joinedDaysAgo: 130) },
                sara.map { member($0, joinedDaysAgo: 70) },
                member(extraMembers[6], role: .admin, joinedDaysAgo: 280),
                member(extraMembers[0], joinedDaysAgo: 28),
                member(extraMembers[4], joinedDaysAgo: 11),
            ].compactMap { $0 },
            messages: [
                riley.map { GroupMessage(sender: $0, text: "Recovery score 88 this morning. Mag + apigenin stack is the most consistent move I've made.", timestamp: t(62)) },
                marcus.map { GroupMessage(sender: $0, text: "Dropped Ipamorelin dose by 25% — REM bumped 18 min. Less is more for me.", timestamp: t(28)) },
                sara.map { GroupMessage(sender: $0, text: "HRV trend over marathon block: down -8 the week before tempo, recovers in 48h. Patterning is real.", timestamp: t(6)) },
            ].compactMap { $0 },
            createdAt: Date().addingTimeInterval(-198 * 86400),
            creatorID: riley?.id ?? me.id,
            statsConfig: GroupStatsConfig(isEnabled: true, enabledMetrics: [.activeMinutes], period: .week)
        )

        // Per-scenario picks (3 groups each).
        switch scenario {
        case .marcus:
            return [peptide, recompLab, sleep]
        case .priya:
            return [comeback, peptide, hybridSquad]
        case .theo:
            return [recompLab, peptide, comeback]
        case .maya:
            return [recompLab, hybridSquad, sleep]
        case .ava:
            return [hybridSquad, sleep, recompLab]
        case .shayla:
            return [comeback, recompLab, peptide]
        }
    }
}
