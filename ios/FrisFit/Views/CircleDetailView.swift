import SwiftUI

struct CircleDetailView: View {
    @Bindable var viewModel: CirclesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showPostComments: CirclePost?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                circleHeader
                tabBar
                tabContent
            }
            .appBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Circles")
                                .font(.subheadline)
                        }
                        .foregroundStyle(PepTheme.teal)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isAdminOrOwner {
                        Button {
                            viewModel.showSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.subheadline)
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                }
            }
            .sheet(item: $showPostComments) { post in
                CirclePostCommentsSheet(post: post) { text in
                    viewModel.addPostComment(post, text: text)
                    if let updated = viewModel.posts.first(where: { $0.id == post.id }) {
                        showPostComments = updated
                    }
                }
            }
            .sheet(isPresented: $viewModel.showSettings) {
                if let circle = viewModel.selectedCircle {
                    CircleSettingsSheet(viewModel: viewModel, circle: circle)
                }
            }
            .sheet(isPresented: $viewModel.showCompetitionChallenge) {
                CompetitionChallengeSheet(viewModel: viewModel)
            }
        }
    }

    private var circleHeader: some View {
        VStack(spacing: 10) {
            if let circle = viewModel.selectedCircle {
                HStack(spacing: 14) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [circle.accentColor, circle.accentColor.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .overlay {
                            Text(String(circle.name.prefix(1)))
                                .font(.system(.title2, design: .rounded, weight: .bold))
                                .foregroundStyle(.white)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(circle.name)
                            .font(.system(.title3, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)

                        HStack(spacing: 12) {
                            Label("\(circle.memberCount)", systemImage: "person.2.fill")
                            if let role = viewModel.currentUserRole {
                                HStack(spacing: 3) {
                                    Image(systemName: role.icon)
                                    Text(role.rawValue)
                                }
                                .foregroundStyle(role.color)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(viewModel.circleWeeklyPoints)")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(circle.accentColor)
                        Text("this week")
                            .font(.caption2)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var tabBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(CircleDetailTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 12))
                            Text(tab.rawValue)
                                .font(.system(.caption, weight: .semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.selectedTab == tab
                                ? PepTheme.teal.opacity(0.15)
                                : PepTheme.elevated.opacity(0.5)
                        )
                        .foregroundStyle(
                            viewModel.selectedTab == tab
                                ? PepTheme.teal
                                : PepTheme.textSecondary
                        )
                        .clipShape(.capsule)
                    }
                    .sensoryFeedback(.selection, trigger: viewModel.selectedTab)
                }
            }
        }
        .contentMargins(.horizontal, 16)
        .scrollIndicators(.hidden)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.selectedTab {
        case .tasks:
            CircleTasksTab(viewModel: viewModel)
        case .posts:
            CirclePostsTab(viewModel: viewModel, showPostComments: $showPostComments)
        case .chat:
            CircleChatTab(viewModel: viewModel)
        case .compete:
            CircleCompeteTab(viewModel: viewModel)
        case .badges:
            CircleBadgesTab(viewModel: viewModel)
        }
    }
}

// MARK: - Tasks Tab

struct CircleTasksTab: View {
    @Bindable var viewModel: CirclesViewModel

    private var tasksByCategory: [(String, [CircleTask])] {
        let grouped = Dictionary(grouping: viewModel.circleTasks, by: { $0.category })
        return grouped.sorted { $0.key < $1.key }
    }

    private var completedPoints: Int {
        viewModel.circleTasks.filter(\.isCompletedToday).reduce(0) { $0 + $1.value }
    }

    private var totalPoints: Int {
        viewModel.circleTasks.filter { !$0.isPenalty }.reduce(0) { $0 + $1.value }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text("\(completedPoints)")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.teal)
                        Text("earned today")
                            .font(.caption2)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(PepTheme.teal.opacity(0.06))
                    .clipShape(.rect(cornerRadius: 12))

                    VStack(spacing: 4) {
                        Text("\(totalPoints)")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("available")
                            .font(.caption2)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(PepTheme.elevated.opacity(0.5))
                    .clipShape(.rect(cornerRadius: 12))
                }

                if viewModel.isAdminOrOwner && !viewModel.taskRequests.isEmpty {
                    taskRequestsSection
                }

                ForEach(tasksByCategory, id: \.0) { category, tasks in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(category)
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        ForEach(tasks) { task in
                            CircleTaskRow(task: task) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    viewModel.toggleTaskCompletion(task)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    private var taskRequestsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "bell.badge.fill")
                    .font(.caption)
                    .foregroundStyle(PepTheme.amber)
                Text("Pending Requests")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.amber)
            }

            ForEach(viewModel.taskRequests) { request in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(request.taskName)
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("by \(request.requester.name) · \(request.taskValue) pts")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    Spacer()
                    Button {
                        viewModel.approveTaskRequest(request)
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                    }
                    Button {
                        viewModel.rejectTaskRequest(request)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.red.opacity(0.7))
                    }
                }
                .padding(12)
                .background(PepTheme.amber.opacity(0.06))
                .clipShape(.rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(PepTheme.amber.opacity(0.15), lineWidth: 0.5)
                )
            }
        }
    }
}

struct CircleTaskRow: View {
    let task: CircleTask
    let onToggle: () -> Void

    @State private var toggleTap: Int = 0

    var body: some View {
        Button {
            onToggle()
            toggleTap += 1
        } label: {
            HStack(spacing: 12) {
                Image(systemName: task.isCompletedToday ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompletedToday ? PepTheme.teal : PepTheme.textSecondary.opacity(0.4))
                    .contentTransition(.symbolEffect(.replace))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(task.name)
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundStyle(task.isCompletedToday ? PepTheme.textPrimary.opacity(0.5) : PepTheme.textPrimary)
                            .strikethrough(task.isCompletedToday, color: PepTheme.textSecondary)

                        if task.taskType == .circleTask {
                            Text("GROUP")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(PepTheme.violet)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(PepTheme.violet.opacity(0.15), in: .capsule)
                        }
                    }
                }

                Spacer()

                Text(task.isPenalty ? "\(task.value)" : "+\(task.value)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(task.isPenalty ? .red.opacity(0.7) : PepTheme.teal)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                task.isCompletedToday
                    ? PepTheme.teal.opacity(0.04)
                    : PepTheme.cardSurface
            )
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        task.isCompletedToday ? PepTheme.teal.opacity(0.15) : PepTheme.glassBorderTop,
                        lineWidth: 0.5
                    )
            )
        }
        .sensoryFeedback(.impact(weight: .light), trigger: toggleTap)
    }
}

struct StatPill: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(PepTheme.elevated.opacity(0.7))
        .clipShape(.rect(cornerRadius: 8))
    }
}

// MARK: - Posts Tab

struct CirclePostsTab: View {
    @Bindable var viewModel: CirclesViewModel
    @Binding var showPostComments: CirclePost?
    @FocusState private var isPostFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(viewModel.posts) { post in
                        CirclePostCard(post: post, onLike: {
                            viewModel.togglePostLike(post)
                        }, onComment: {
                            showPostComments = post
                        })
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 80)
            }

            Divider().overlay(PepTheme.separatorColor)

            HStack(spacing: 10) {
                TextField("Share an update...", text: $viewModel.newPostText)
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(PepTheme.elevated)
                    .clipShape(.capsule)
                    .focused($isPostFocused)
                    .onSubmit { viewModel.createPost() }

                Button {
                    viewModel.createPost()
                    isPostFocused = false
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(viewModel.newPostText.isEmpty ? PepTheme.textSecondary.opacity(0.3) : PepTheme.teal)
                }
                .disabled(viewModel.newPostText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(PepTheme.cardSurface)
        }
    }
}

struct CirclePostCard: View {
    let post: CirclePost
    let onLike: () -> Void
    let onComment: () -> Void

    @State private var likeTap: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(post.author.avatarColor.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Text(post.author.avatarInitial)
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(post.author.avatarColor)
                    }

                VStack(alignment: .leading, spacing: 1) {
                    Text(post.author.name)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(post.createdAt.timeAgoDisplay())
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Spacer()
            }

            Text(post.content)
                .font(.subheadline)
                .foregroundStyle(PepTheme.textPrimary.opacity(0.9))
                .lineSpacing(3)

            HStack(spacing: 20) {
                Button {
                    onLike()
                    likeTap += 1
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: post.isLiked ? "heart.fill" : "heart")
                            .contentTransition(.symbolEffect(.replace))
                        Text("\(post.likeCount)")
                    }
                    .font(.caption)
                    .foregroundStyle(post.isLiked ? .red : PepTheme.textSecondary)
                }
                .sensoryFeedback(.impact(weight: .light), trigger: likeTap)

                Button {
                    onComment()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left")
                        Text("\(post.comments.count)")
                    }
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
        .padding(14)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }
}

// MARK: - Chat Tab

struct CircleChatTab: View {
    @Bindable var viewModel: CirclesViewModel
    @FocusState private var isChatFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(viewModel.messages) { message in
                        ChatBubble(message: message, isMe: message.sender.username == "me")
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .defaultScrollAnchor(.bottom)

            Divider().overlay(PepTheme.separatorColor)

            HStack(spacing: 10) {
                TextField("Message...", text: $viewModel.newMessageText)
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(PepTheme.elevated)
                    .clipShape(.capsule)
                    .focused($isChatFocused)
                    .onSubmit { viewModel.sendMessage() }

                Button {
                    viewModel.sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(viewModel.newMessageText.isEmpty ? PepTheme.textSecondary.opacity(0.3) : PepTheme.teal)
                }
                .disabled(viewModel.newMessageText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(PepTheme.cardSurface)
        }
    }
}

struct ChatBubble: View {
    let message: CircleMessage
    let isMe: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isMe { Spacer(minLength: 60) }

            if !isMe {
                Circle()
                    .fill(message.sender.avatarColor.opacity(0.2))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Text(message.sender.avatarInitial)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(message.sender.avatarColor)
                    }
            }

            VStack(alignment: isMe ? .trailing : .leading, spacing: 2) {
                if !isMe {
                    Text(message.sender.name)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                }

                Text(message.content)
                    .font(.subheadline)
                    .foregroundStyle(isMe ? .white : PepTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        isMe ? PepTheme.teal : PepTheme.elevated,
                        in: .rect(
                            topLeadingRadius: 16,
                            bottomLeadingRadius: isMe ? 16 : 4,
                            bottomTrailingRadius: isMe ? 4 : 16,
                            topTrailingRadius: 16
                        )
                    )

                Text(message.createdAt, style: .time)
                    .font(.system(size: 9))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
            }

            if !isMe { Spacer(minLength: 60) }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Compete Tab

struct CircleCompeteTab: View {
    @Bindable var viewModel: CirclesViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Button {
                    viewModel.showCompetitionChallenge = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "flag.2.crossed.fill")
                            .font(.headline)
                            .foregroundStyle(PepTheme.teal)
                        Text("Challenge a Circle")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                    }
                    .padding(14)
                    .background(PepTheme.teal.opacity(0.06))
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(PepTheme.teal.opacity(0.15), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.scale)

                if viewModel.competitions.isEmpty {
                    EmptyStateView(
                        icon: "flag.2.crossed",
                        title: "No Competitions",
                        message: "Challenge another circle to a head-to-head competition."
                    )
                    .padding(.top, 30)
                } else {
                    ForEach(viewModel.competitions) { comp in
                        CompetitionCard(competition: comp, myCircleId: viewModel.selectedCircle?.id)
                    }
                }

                if !viewModel.awards.isEmpty {
                    awardsSection
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    private var awardsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HeadlineText(text: "Awards")

            ForEach(viewModel.awards) { award in
                AwardCard(award: award)
            }
        }
    }
}

struct CompetitionCard: View {
    let competition: CircleCompetition
    let myCircleId: UUID?

    private var isMyCircleOne: Bool {
        guard let myId = myCircleId else { return true }
        return competition.circleOne.id == myId
    }

    private var myPoints: Int { isMyCircleOne ? competition.circleOnePoints : competition.circleTwoPoints }
    private var theirPoints: Int { isMyCircleOne ? competition.circleTwoPoints : competition.circleOnePoints }
    private var opponentName: String { isMyCircleOne ? competition.circleTwo.name : competition.circleOne.name }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(competition.name)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(competition.competitionType.rawValue)
                        .font(.caption2)
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.12), in: .capsule)
                }
                Spacer()
                Text(competition.status.rawValue)
                    .font(.system(.caption2, weight: .semibold))
                    .foregroundStyle(statusColor)
            }

            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("Us")
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary)
                    Text("\(myPoints.formatted())")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(myPoints >= theirPoints ? PepTheme.teal : PepTheme.textPrimary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 2) {
                    Text("VS")
                        .font(.system(.caption2, design: .rounded, weight: .black))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                }
                .frame(width: 40)

                VStack(spacing: 4) {
                    Text(opponentName)
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary)
                        .lineLimit(1)
                    Text("\(theirPoints.formatted())")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(theirPoints > myPoints ? .red.opacity(0.7) : PepTheme.textPrimary)
                }
                .frame(maxWidth: .infinity)
            }

            if let target = competition.targetPoints {
                let leading = max(myPoints, theirPoints)
                let progress = min(Double(leading) / Double(target), 1.0)
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(PepTheme.elevated).frame(height: 6)
                            Capsule().fill(PepTheme.teal).frame(width: geo.size.width * progress, height: 6)
                        }
                    }
                    .frame(height: 6)
                    Text("\(leading.formatted()) / \(target.formatted()) pts")
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
        .padding(14)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private var statusColor: Color {
        switch competition.status {
        case .active: return .green
        case .pending: return PepTheme.amber
        case .completed: return PepTheme.textSecondary
        }
    }
}

struct AwardCard: View {
    let award: CircleAward

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: awardIcon)
                .font(.title3)
                .foregroundStyle(award.winnerId != nil ? PepTheme.amber : PepTheme.textSecondary)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(award.name)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(award.description)
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineLimit(2)
                if let winner = award.winnerName {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(PepTheme.amber)
                        Text(winner)
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(PepTheme.amber)
                    }
                }
            }

            Spacer()

            if let pts = award.rewardPoints {
                Text("+\(pts)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.teal)
            }
        }
        .padding(12)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private var awardIcon: String {
        switch award.type {
        case .firstTo: return "flag.checkered"
        case .mostInCategory: return "chart.bar.fill"
        case .weeklyChampion: return "star.circle.fill"
        }
    }
}

// MARK: - Badges Tab

struct CircleBadgesTab: View {
    @Bindable var viewModel: CirclesViewModel

    let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(viewModel.badges) { badge in
                    BadgeCard(badge: badge)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }
}

struct BadgeCard: View {
    let badge: CircleBadge

    private var progress: Double {
        guard badge.required > 0 else { return 0 }
        return min(Double(badge.progress) / Double(badge.required), 1.0)
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(badge.earned ? PepTheme.amber.opacity(0.15) : PepTheme.elevated)
                    .frame(width: 52, height: 52)

                Image(systemName: badge.icon)
                    .font(.title2)
                    .foregroundStyle(badge.earned ? PepTheme.amber : PepTheme.textSecondary)
                    .symbolEffect(.bounce, options: .speed(0.5), isActive: badge.earned)
            }

            Text(badge.name)
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)

            Text(badge.description)
                .font(.system(size: 10))
                .foregroundStyle(PepTheme.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(PepTheme.elevated).frame(height: 5)
                        Capsule().fill(badge.earned ? PepTheme.amber : PepTheme.teal).frame(width: geo.size.width * progress, height: 5)
                    }
                }
                .frame(height: 5)
                Text("\(badge.progress)/\(badge.required)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            if badge.earned {
                Text("EARNED")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(PepTheme.amber)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(PepTheme.amber.opacity(0.12), in: .capsule)
            } else if let pts = badge.rewardPoints {
                Text("+\(pts) pts")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.teal)
            }
        }
        .padding(14)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    badge.earned ? PepTheme.amber.opacity(0.2) : PepTheme.glassBorderTop,
                    lineWidth: 0.5
                )
        )
    }
}

// MARK: - Post Comments Sheet

struct CirclePostCommentsSheet: View {
    let post: CirclePost
    let onAddComment: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var commentText: String = ""
    @State private var showReportAlert: Bool = false
    @FocusState private var isCommentFocused: Bool

    private var currentUserId: String? {
        try? AuthService.shared.currentUserId()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if post.comments.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 40))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                        Text("No comments yet")
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            ForEach(post.comments) { comment in
                                HStack(alignment: .top, spacing: 10) {
                                    Circle()
                                        .fill(comment.author.avatarColor.opacity(0.2))
                                        .frame(width: 30, height: 30)
                                        .overlay {
                                            Text(comment.author.avatarInitial)
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(comment.author.avatarColor)
                                        }
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 6) {
                                            Text(comment.author.name)
                                                .font(.system(.caption, weight: .semibold))
                                                .foregroundStyle(PepTheme.textPrimary)
                                            Text(comment.createdAt.timeAgoDisplay())
                                                .font(.caption2)
                                                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                                        }
                                        Text(comment.content)
                                            .font(.subheadline)
                                            .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                                    }
                                }
                                .contextMenu {
                                    Button {
                                        UIPasteboard.general.string = comment.content
                                    } label: {
                                        Label("Copy", systemImage: "doc.on.doc")
                                    }

                                    if comment.author.id.uuidString.lowercased() != currentUserId?.lowercased() {
                                        Button {
                                            showReportAlert = true
                                        } label: {
                                            Label("Report", systemImage: "exclamationmark.triangle")
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }

                Divider().overlay(PepTheme.separatorColor)

                HStack(spacing: 12) {
                    TextField("Add a comment...", text: $commentText)
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(PepTheme.elevated)
                        .clipShape(.capsule)
                        .focused($isCommentFocused)
                        .onSubmit { sendComment() }

                    Button { sendComment() } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(commentText.isEmpty ? PepTheme.textSecondary.opacity(0.3) : PepTheme.teal)
                    }
                    .disabled(commentText.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(PepTheme.cardSurface)
            }
            .background(PepTheme.background)
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PepTheme.teal)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(PepTheme.background)
        .presentationContentInteraction(.scrolls)
        .alert("Comment Reported", isPresented: $showReportAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Thanks for letting us know. We'll review this comment.")
        }
    }

    private func sendComment() {
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onAddComment(trimmed)
        commentText = ""
    }
}
