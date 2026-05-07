import SwiftUI

struct FriendsStatsView<TopHeader: View>: View {
    @ViewBuilder var topHeader: () -> TopHeader

    init(@ViewBuilder topHeader: @escaping () -> TopHeader = { EmptyView() }) {
        self.topHeader = topHeader
    }

    @State private var viewModel = FriendsStatsViewModel()
    @State private var profileViewModel = ProfileViewModel()
    @State private var groupsViewModel = GroupsViewModel()
    @State private var showOnboarding: Bool = false
    @State private var showSettings: Bool = false
    @State private var selectedFriend: FriendStatSnapshot?
    @State private var hasEnabledSharing: Bool = false
    @State private var reactionTarget: ReactionTarget?
    @State private var nudgeTarget: FriendStatSnapshot?
    @State private var isGroupsExpanded: Bool = true
    @State private var selectedGroupID: UUID?
    @State private var showCreateGroup: Bool = false
    @State private var showDiscoverGroups: Bool = false

    private let social = FriendSocialService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                topHeader()

                groupsSection
                    .padding(.horizontal)

                header

                if let recap = viewModel.weeklyRecap {
                    NavigationLink(value: recap.id) {
                        WeeklyRecapCard(recap: recap)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }

                if !hasEnabledSharing {
                    shareCTA
                        .padding(.horizontal)
                }

                if viewModel.isLoading {
                    loadingGrid
                        .padding(.horizontal)
                } else if viewModel.friends.isEmpty {
                    EmptyStateView(
                        icon: "person.2",
                        title: "No friends yet",
                        message: "Follow people back to see their stats here. Stats only appear for mutual friends who have opted in."
                    )
                } else {
                    friendsGrid
                        .padding(.horizontal)

                    if !viewModel.activityEvents.isEmpty {
                        activitySection
                            .padding(.horizontal)
                    }
                }

                Color.clear.frame(height: 80)
            }
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .refreshable { await viewModel.load() }
        .sheet(isPresented: $showOnboarding, onDismiss: { refreshOptIn() }) {
            StatSharingOnboardingSheet()
        }
        .sheet(isPresented: $showSettings, onDismiss: { refreshOptIn() }) {
            NavigationStack { StatSharingSettingsView() }
        }
        .navigationDestination(item: $selectedFriend) { friend in
            FriendDashboardView(friend: friend, mySnapshot: viewModel.mySnapshot())
        }
        .navigationDestination(item: $selectedGroupID) { id in
            GroupDetailView(viewModel: groupsViewModel, groupID: id)
        }
        .navigationDestination(isPresented: $showDiscoverGroups) {
            GroupsListView(viewModel: groupsViewModel)
        }
        .sheet(isPresented: $showCreateGroup) {
            CreateGroupSheet(viewModel: groupsViewModel)
        }
        .navigationDestination(for: String.self) { recapId in
            if let recap = viewModel.weeklyRecap, recap.id == recapId {
                WeeklyRecapDetailView(recap: recap)
            } else {
                EmptyView()
            }
        }
        .sheet(item: $reactionTarget) { target in
            ReactionPickerSheet(target: target)
                .presentationDetents([.height(180)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(item: $nudgeTarget) { friend in
            NudgeMenuSheet(friend: friend)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .task {
            refreshOptIn()
            if !viewModel.hasSeenOnboarding {
                showOnboarding = true
            }
            await viewModel.load()
            await groupsViewModel.refresh()
        }
    }

    // MARK: - Groups Section

    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    isGroupsExpanded.toggle()
                }
            } label: {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text("00")
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundStyle(PepTheme.amber.opacity(0.9))
                            Text("\u{2014}")
                                .font(.system(size: 9))
                                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                            Text("THE COLLECTIVE")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(1.6)
                                .foregroundStyle(PepTheme.textSecondary.opacity(0.85))
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("Groups")
                                .font(.system(.title2, design: .serif, weight: .regular))
                                .foregroundStyle(PepTheme.textPrimary)
                            if !groupsViewModel.myGroups.isEmpty {
                                Text("\(groupsViewModel.myGroups.count)")
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(PepTheme.textSecondary)
                        .rotationEffect(.degrees(isGroupsExpanded ? 0 : -90))
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: isGroupsExpanded)

            if isGroupsExpanded {
                groupsExpandedContent
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
            }

            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(height: 0.5)
                .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var groupsExpandedContent: some View {
        if groupsViewModel.isLoading && groupsViewModel.myGroups.isEmpty {
            HStack(spacing: 12) {
                ForEach(0..<2, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 14)
                        .fill(PepTheme.elevated)
                        .frame(height: 78)
                        .shimmering()
                }
            }
        } else if groupsViewModel.myGroups.isEmpty {
            groupsEmptyState
        } else {
            VStack(spacing: 0) {
                ForEach(Array(groupsViewModel.myGroups.enumerated()), id: \.element.id) { idx, group in
                    Button {
                        selectedGroupID = group.id
                    } label: {
                        groupRow(group)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: selectedGroupID)

                    if idx < groupsViewModel.myGroups.count - 1 {
                        Rectangle()
                            .fill(PepTheme.separatorColor.opacity(0.6))
                            .frame(height: 0.5)
                            .padding(.leading, 56)
                    }
                }
            }
            .background(PepTheme.cardSurface, in: .rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
            )

            groupsActionRow
        }
    }

    private func groupRow(_ group: FitGroup) -> some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(PepTheme.elevated)
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(group.accentColor.opacity(0.45), lineWidth: 0.6)
                Text(groupMonogram(group.name))
                    .font(.system(.subheadline, design: .serif, weight: .regular))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(group.name)
                        .font(.system(.subheadline, design: .serif, weight: .regular))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(1)
                    if group.privacy == .privateGroup {
                        Image(systemName: "lock")
                            .font(.system(size: 9, weight: .regular))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                    }
                }
                if let preview = group.lastMessagePreview {
                    Text(preview)
                        .font(.system(.caption, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary)
                        .lineLimit(1)
                } else {
                    Text("\(group.memberCount) member\(group.memberCount == 1 ? "" : "s")")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.8))
                }
            }

            Spacer(minLength: 6)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(.rect)
    }

    private var groupsEmptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No groups yet")
                .font(.system(.subheadline, design: .serif, weight: .regular))
                .foregroundStyle(PepTheme.textPrimary)
            Text("Train alongside a private circle, or join a public collective.")
                .font(.system(.caption, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button {
                    showCreateGroup = true
                } label: {
                    Text("CREATE GROUP")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(PepTheme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .overlay(Capsule().strokeBorder(PepTheme.textPrimary.opacity(0.6), lineWidth: 0.5))
                }
                .buttonStyle(.scale)

                Button {
                    showDiscoverGroups = true
                } label: {
                    Text("DISCOVER")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(PepTheme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .overlay(Capsule().strokeBorder(PepTheme.separatorColor, lineWidth: 0.5))
                }
                .buttonStyle(.scale)
            }
            .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.cardSurface, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
        )
    }

    private var groupsActionRow: some View {
        HStack(spacing: 14) {
            Button {
                showCreateGroup = true
            } label: {
                Label {
                    Text("NEW GROUP")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.5)
                } icon: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(PepTheme.textPrimary)
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(width: 0.5, height: 14)

            Button {
                showDiscoverGroups = true
            } label: {
                Label {
                    Text("DISCOVER")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.5)
                } icon: {
                    Image(systemName: "safari")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(PepTheme.textSecondary)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.top, 4)
        .padding(.horizontal, 4)
    }

    private func groupMonogram(_ name: String) -> String {
        let words = name.split(separator: " ").prefix(2)
        return words.compactMap { $0.first }.map { String($0) }.joined().uppercased()
    }

    private func refreshOptIn() {
        hasEnabledSharing = viewModel.hasEnabledSharing
    }

    private var _socialObserver: Int { social.reactions.count + social.sentNudges.count + social.friendPresences.count }

    private var header: some View {
        SectionEyebrow("Friends", number: "00", accent: PepTheme.teal)
            .padding(.horizontal)
    }

    private var shareCTA: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Share your progress with friends")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
            Text("Turn on stat sharing to see your friends' stats and let them see yours. You control what's visible.")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                showOnboarding = true
            } label: {
                Text("ENABLE SHARING")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(PepTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .overlay(
                        Capsule().strokeBorder(PepTheme.textPrimary.opacity(0.6), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.scale)
            .padding(.top, 4)
        }
        .padding(16)
        .background(PepTheme.cardSurface, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
        )
    }

    private var loadingGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16)
                    .fill(PepTheme.elevated)
                    .frame(height: 160)
                    .shimmering()
            }
        }
    }

    private var friendsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionEyebrow("Your Friends", number: "01", accent: PepTheme.teal) {
                Text("\(viewModel.friends.count)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(viewModel.friends) { friend in
                    Button {
                        selectedFriend = friend
                    } label: {
                        FriendStatCard(
                            friend: friend,
                            isLeaderStreak: friend.id == viewModel.friends.first?.id,
                            onLongPress: { target in reactionTarget = target },
                            onNudge: { nudgeTarget = friend }
                        )
                    }
                    .buttonStyle(.scale)
                    .disabled(!hasEnabledSharing)
                    .opacity(hasEnabledSharing ? 1 : 0.55)
                }
            }
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionEyebrow("Activity", number: "02", accent: PepTheme.violet)
                .padding(.top, 8)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.activityEvents.enumerated()), id: \.element.id) { index, event in
                    FriendActivityRow(event: event)
                    if index < viewModel.activityEvents.count - 1 {
                        Divider().overlay(PepTheme.separatorColor).padding(.leading, 52)
                    }
                }
            }
            .background(PepTheme.cardSurface, in: .rect(cornerRadius: 16))
        }
    }
}

struct ReactionTarget: Identifiable, Hashable {
    let id: String
    let friendId: String
    let friendName: String
    let statLabel: String
}

struct FriendStatCard: View {
    let friend: FriendStatSnapshot
    var isLeaderStreak: Bool = false
    var onLongPress: ((ReactionTarget) -> Void)? = nil
    var onNudge: (() -> Void)? = nil

    @State private var burstEmoji: StatReactionEmoji?
    @State private var burstId: UUID = UUID()

    private let social = FriendSocialService.shared

    private var presence: FriendPresence? {
        social.presence(for: friend.id.uuidString)
    }

    private var reactions: [StatReaction] {
        social.reactions(forTarget: "streak", friendId: friend.id.uuidString)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                avatar
                VStack(alignment: .leading, spacing: 1) {
                    Text(friend.user.name)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(1)
                    if let presence {
                        presencePill(presence)
                    } else {
                        Text("@\(friend.user.username)")
                            .font(.caption2)
                            .foregroundStyle(PepTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }

            if friend.isSharing {
                sharingBody
            } else {
                lockedBody
            }

            if !reactions.isEmpty {
                reactionStack
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                PepTheme.cardSurface
                if isLeaderStreak {
                    LinearGradient(
                        colors: [PepTheme.amber.opacity(0.1), Color.clear],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                }
            }
            .clipShape(.rect(cornerRadius: 16))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(presence != nil ? PepTheme.teal.opacity(0.5) : PepTheme.separatorColor, lineWidth: presence != nil ? 1 : 0.5)
        )
        .overlay(alignment: .topTrailing) {
            if burstEmoji != nil {
                ReactionBurst(emoji: burstEmoji!)
                    .id(burstId)
                    .padding(10)
                    .allowsHitTesting(false)
            }
        }
        .onLongPressGesture(minimumDuration: 0.35) {
            guard friend.isSharing else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            let label = presence != nil ? "workout" : (friend.lastActivityTitle ?? "progress")
            onLongPress?(ReactionTarget(
                id: "\(friend.id.uuidString)-progress",
                friendId: friend.id.uuidString,
                friendName: friend.user.name,
                statLabel: label
            ))
        }
        .onChange(of: reactions.count) { oldValue, newValue in
            if newValue > oldValue, let last = reactions.last {
                burstEmoji = last.emoji
                burstId = UUID()
                Task {
                    try? await Task.sleep(for: .seconds(1.4))
                    burstEmoji = nil
                }
            }
        }
    }

    private func presencePill(_ presence: FriendPresence) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(PepTheme.teal)
                .frame(width: 6, height: 6)
                .overlay(
                    Circle()
                        .stroke(PepTheme.teal.opacity(0.4), lineWidth: 3)
                        .scaleEffect(1.6)
                        .opacity(0.5)
                )
            Text(presence.activity)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PepTheme.teal)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(PepTheme.teal.opacity(0.12), in: Capsule())
    }

    private var reactionStack: some View {
        HStack(spacing: -4) {
            ForEach(Array(Set(reactions.map { $0.emoji })).prefix(3), id: \.self) { e in
                Text(e.rawValue)
                    .font(.system(size: 12))
                    .frame(width: 20, height: 20)
                    .background(PepTheme.elevated, in: Circle())
                    .overlay(Circle().strokeBorder(PepTheme.cardSurface, lineWidth: 1.5))
            }
            if reactions.count > 1 {
                Text("\(reactions.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .padding(.leading, 6)
            }
        }
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(colors: [friend.user.avatarColor, friend.user.avatarColor.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 40, height: 40)
            if let url = friend.user.avatarURL, let u = URL(string: url) {
                AsyncImage(url: u) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Text(friend.user.avatarInitial).font(.system(.subheadline, design: .rounded, weight: .bold)).foregroundStyle(.white)
                }
                .frame(width: 40, height: 40)
                .clipShape(.circle)
            } else {
                Text(friend.user.avatarInitial).font(.system(.subheadline, design: .rounded, weight: .bold)).foregroundStyle(.white)
            }
        }
    }

    private var sharingBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Eyebrow label
            Text(friend.lastActivityTitle != nil ? "LAST" : "STATUS")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)

            // Primary headline = last activity (or graceful fallback)
            Text(lastActivityHeadline)
                .font(.system(.callout, design: .serif, weight: .regular))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            // Time ago, if known
            if let when = friend.lastActivityAt {
                Text(when, style: .relative)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer(minLength: 0)

            // Phase chip — shows the goal phase (Bulking / Cutting / etc.)
            if let phase = friend.phase, !phase.isEmpty {
                phaseChip(phase)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
    }

    private var lastActivityHeadline: String {
        if let raw = friend.lastActivityTitle, !raw.isEmpty {
            // Strip leading "<Name> completed " prefix for compactness
            let name = friend.user.name
            let prefixes = ["\(name) completed ", "\(name) hit a PR: ", "\(name) is running ", "\(name) is on "]
            for p in prefixes where raw.hasPrefix(p) {
                return String(raw.dropFirst(p.count))
            }
            return raw
        }
        return "No recent activity"
    }

    private func phaseChip(_ phase: String) -> some View {
        let color = phaseColor(phase)
        return HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(phase.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.35), lineWidth: 0.5))
    }

    private func phaseColor(_ phase: String) -> Color {
        switch phase.lowercased() {
        case "cutting": return PepTheme.teal
        case "bulking": return PepTheme.amber
        case "recomp": return PepTheme.violet
        case "maintaining": return .green
        case "rebuilding": return .pink
        case "endurance": return PepTheme.blue
        case "strength": return .orange
        default: return PepTheme.textSecondary
        }
    }

    private var lockedBody: some View {
        VStack(spacing: 8) {
            Text("Private")
                .font(.system(.caption, design: .serif).italic())
                .foregroundStyle(PepTheme.textSecondary)
            if let onNudge {
                Button(action: onNudge) {
                    Text("NUDGE")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .overlay(
                            Capsule().strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 60)
    }
}

private struct ReactionBurst: View {
    let emoji: StatReactionEmoji
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1
    @State private var scale: CGFloat = 0.3

    var body: some View {
        Text(emoji.rawValue)
            .font(.system(size: 36))
            .scaleEffect(scale)
            .offset(y: offset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                    scale = 1.3
                }
                withAnimation(.easeOut(duration: 1.2)) {
                    offset = -60
                    opacity = 0
                }
                withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                    scale = 1.0
                }
            }
    }
}

struct FriendActivityRow: View {
    let event: FriendActivityEvent

    private let social = FriendSocialService.shared

    private var isMilestone: Bool {
        switch event.type {
        case .pr, .streakMilestone, .goalHit: return true
        default: return false
        }
    }

    private var seenCount: Int {
        social.simulateSeenCount(for: event.id.uuidString, seed: event.user.id.hashValue)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(event.type.color.opacity(0.7))
                .frame(width: 2)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(2)
                if let sub = event.subtitle {
                    Text(sub)
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                if isMilestone && seenCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                        Text("Seen by \(seenCount) \(seenCount == 1 ? "friend" : "friends")")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.8))
                    }
                    .padding(.top, 2)
                }
            }

            Spacer(minLength: 8)

            Text(event.timestamp, style: .relative)
                .font(.caption2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .onAppear {
            if isMilestone, let myId = try? AuthService.shared.currentUserId() {
                social.markSeen(milestoneId: event.id.uuidString, friendId: myId)
            }
        }
    }
}

private struct FriendStatsShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [Color.clear, PepTheme.shimmerHighlight, Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase * 200)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

private extension View {
    func shimmering() -> some View { modifier(FriendStatsShimmerModifier()) }
}
