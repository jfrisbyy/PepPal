import SwiftUI

struct FriendDashboardView: View {
    let friend: FriendStatSnapshot
    let mySnapshot: FriendStatSnapshot?

    @State private var profileViewModel = ProfileViewModel()
    private let messagesViewModel = MessagesViewModel.shared
    @State private var showCompare: Bool = false
    @State private var showSportPicker: Bool = false
    @State private var pendingSport: BuddySport?
    @State private var showBuddyInvite: Bool = false
    @State private var showNudge: Bool = false
    @State private var showBorrow: Bool = false
    @State private var showProfile: Bool = false
    @State private var showShareConfirm: Bool = false
    @State private var pendingChatID: UUID?
    @State private var statDetail: StatShareCategory?
    @State private var expandedProtocol: String?
    @State private var expandedWorkout: UUID?
    @State private var liveSport: BuddySport?
    @State private var mealsExpanded: Bool = false
    @State private var protocolDetail: MockFriendsService.MockProtocol?
    @Environment(\.dismiss) private var dismiss

    private var profile: MockFriendsService.MockFriendProfile? {
        MockFriendsService.shared.profile(byId: friend.id.uuidString)
    }

    private var firstName: String {
        friend.user.name.components(separatedBy: " ").first ?? friend.user.name
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                heroHeader
                if shares(.protocols), let protos = profile?.activeProtocols, !protos.isEmpty {
                    protocolBannerStrip(protos)
                }
                quickActions
                miniComparison
                if let today = profile?.today, hasAnyTodayShare {
                    todayCard(today)
                }
                weeklyStatsGrid
                if shares(.workouts), let workouts = profile?.recentWorkouts, !workouts.isEmpty {
                    recentWorkoutsSection(workouts)
                }
                if shares(.prs), let pr = profile?.latestPR ?? friend.latestPR, !pr.isEmpty {
                    prCard(pr)
                }
                activityTimeline
                Color.clear.frame(height: 80)
            }
            .padding(.top, 52)
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .navigationTitle(firstName)
        .navigationBarTitleDisplayMode(.inline)
        .floatingTopBar {
            FloatingNavButton(systemImage: "chevron.left") { dismiss() }
        } trailing: {
            FloatingNavButton(systemImage: "square.and.arrow.up", action: { showShareConfirm = true }, tint: PepTheme.teal)
        }
        .navigationDestination(isPresented: $showCompare) {
            FriendComparisonView(friend: friend, mySnapshot: mySnapshot)
        }
        .navigationDestination(isPresented: $showProfile) {
            UserProfileView(user: friend.user, viewModel: profileViewModel)
        }
        .navigationDestination(item: $pendingChatID) { chatID in
            ChatConversationView(viewModel: messagesViewModel, conversationID: chatID)
        }
        .sheet(isPresented: $showSportPicker) {
            TrainTogetherSportPickerSheet(friend: friend) { sport in
                pendingSport = sport
                showBuddyInvite = true
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.scrolls)
        }
        .sheet(isPresented: $showBuddyInvite) {
            BuddyInviteSheet(friend: friend, sport: pendingSport ?? .strength) { sport in
                liveSport = (sport == .run || sport == .cycle) ? sport : nil
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showNudge) {
            NudgeMenuSheet(friend: friend)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showBorrow) {
            BorrowProgramSheet(friend: friend)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $statDetail) { category in
            FriendStatDetailSheet(friend: friend, mySnapshot: mySnapshot, category: category)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
        .sheet(item: $protocolDetail) { proto in
            ProtocolDetailMockSheet(proto: proto)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
        .fullScreenCover(item: $liveSport) { sport in
            liveSportView(sport)
        }
        .alert("Snapshot shared", isPresented: $showShareConfirm) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("A summary of \(firstName)'s shared stats was added to your chat.")
        }
    }

    // MARK: - Hero

    private var heroHeader: some View {
        VStack(spacing: 14) {
            ZStack {
                LinearGradient(
                    colors: [friend.user.avatarColor.opacity(0.28), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 140)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(PepTheme.separatorColor).frame(height: 0.5)
                }

                VStack(spacing: 8) {
                    Button {
                        showProfile = true
                    } label: {
                        avatar
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 14)
            }
            .padding(.horizontal)

            VStack(spacing: 3) {
                Text(friend.user.name)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("@\(friend.user.username)")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }

            if let bio = profile?.bio, !bio.isEmpty {
                Text(bio)
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            if let goal = profile?.goal, !goal.isEmpty {
                Text(goal.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(PepTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 32)
            }

            HStack(spacing: 8) {
                if let program = friend.activeProgram, !program.isEmpty, shares(.programs) {
                    statChip(value: program, label: nil)
                }
            }
            .padding(.horizontal)
        }
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [friend.user.avatarColor, friend.user.avatarColor.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 96, height: 96)
            if let url = friend.user.avatarURL, let u = URL(string: url) {
                AsyncImage(url: u) { img in
                    img.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Text(friend.user.avatarInitial)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 96, height: 96)
                .clipShape(.circle)
            } else {
                Text(friend.user.avatarInitial)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .overlay(
            Circle().strokeBorder(PepTheme.background, lineWidth: 4)
        )
        .shadow(color: friend.user.avatarColor.opacity(0.3), radius: 12, x: 0, y: 4)
    }

    private func statChip(value: String, label: String?) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
            if let label {
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.3)
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .overlay(Capsule().strokeBorder(PepTheme.separatorColor, lineWidth: 0.5))
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                actionPill(icon: "bubble.left.fill", label: "Message", color: PepTheme.teal) {
                    let id = messagesViewModel.startConversation(with: friend.user)
                    pendingChatID = id
                }
                actionPill(icon: "chart.bar.xaxis", label: "Compare", color: PepTheme.violet) {
                    showCompare = true
                }
                actionPill(icon: "figure.2", label: "Train", color: PepTheme.amber) {
                    showSportPicker = true
                }
                actionPill(icon: "hand.wave.fill", label: "Nudge", color: .pink) {
                    showNudge = true
                }
                if shares(.programs), friend.activeProgram != nil {
                    actionPill(icon: "arrow.down.doc.fill", label: "Borrow", color: .green) {
                        showBorrow = true
                    }
                }
                actionPill(icon: "square.and.arrow.up", label: "Share", color: .blue) {
                    showShareConfirm = true
                }
            }
            .padding(.horizontal)
        }
        .scrollClipDisabled()
    }

    private func actionPill(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
                        .frame(width: 46, height: 46)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(PepTheme.textPrimary)
                }
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .frame(width: 64)
        }
        .buttonStyle(.scale)
    }

    // MARK: - Mini comparison

    private var miniComparison: some View {
        Button {
            showCompare = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                SectionEyebrow("You vs \(firstName)", number: "01", accent: PepTheme.violet) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                }

                HStack(spacing: 10) {
                    miniRow(label: "Workouts", mine: Double(mySnapshot?.weeklyWorkouts ?? 0), theirs: Double(friend.weeklyWorkouts), formatter: { "\(Int($0))" }, share: shares(.workouts))
                    miniRow(label: "Volume", mine: Double(mySnapshot?.weeklyVolume ?? 0), theirs: Double(friend.weeklyVolume), formatter: { v in
                        v >= 1000 ? String(format: "%.1fk", v / 1000) : "\(Int(v))"
                    }, share: shares(.volume))
                    miniRow(label: "Steps", mine: Double(mySnapshot?.weeklySteps ?? 0), theirs: Double(friend.weeklySteps), formatter: { v in
                        v >= 1000 ? String(format: "%.1fk", v / 1000) : "\(Int(v))"
                    }, share: shares(.steps))
                }
            }
            .padding(14)
            .background(PepTheme.cardSurface, in: .rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    private func miniRow(label: String, mine: Double, theirs: Double, formatter: (Double) -> String, share: Bool) -> some View {
        let leadMine = mine > theirs && share
        let leadThem = theirs > mine && share
        return VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(PepTheme.textSecondary)
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("You")
                        .font(.system(size: 9))
                        .foregroundStyle(PepTheme.textSecondary)
                    Text(formatter(mine))
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(leadMine ? PepTheme.teal : PepTheme.textPrimary)
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(firstName)
                        .font(.system(size: 9))
                        .foregroundStyle(PepTheme.textSecondary)
                        .lineLimit(1)
                    Text(share ? formatter(theirs) : "—")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(leadThem ? PepTheme.violet : PepTheme.textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(PepTheme.elevated, in: .rect(cornerRadius: 10))
    }

    // MARK: - Weekly stats grid

    private var weeklyStatsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionEyebrow("This Week", number: "02", accent: PepTheme.teal)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                if shares(.workouts) {
                    statTile(.workouts, value: "\(friend.weeklyWorkouts)", subtitle: "workouts")
                }
                if shares(.volume) {
                    statTile(.volume, value: friend.weeklyVolume >= 1000 ? String(format: "%.1fk", Double(friend.weeklyVolume) / 1000) : "\(friend.weeklyVolume)", subtitle: "kg lifted")
                }
                if shares(.steps) {
                    statTile(.steps, value: friend.weeklySteps >= 1000 ? String(format: "%.0fk", Double(friend.weeklySteps) / 1000) : "\(friend.weeklySteps)", subtitle: "steps")
                }
                if shares(.calories) {
                    statTile(.calories, value: "\(friend.weeklyCalories)", subtitle: "calories")
                }
                if shares(.water) {
                    statTile(.water, value: String(format: "%.1fL", Double(friend.weeklyWaterMl) / 1000), subtitle: "water")
                }
            }
        }
        .padding(.horizontal)
    }

    private func statTile(_ category: StatShareCategory, value: String, subtitle: String) -> some View {
        Button {
            statDetail = category
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(subtitle.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.3)
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
                }
                Text(value)
                    .font(.system(size: 28, weight: .light, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(PepTheme.cardSurface, in: .rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
            )
        }
        .buttonStyle(.scale)
    }

    // MARK: - Protocols

    private func protocolsSection(_ protos: [MockFriendsService.MockProtocol]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionEyebrow("Active Protocols", accent: .pink)

            VStack(spacing: 8) {
                ForEach(protos, id: \.name) { proto in
                    protocolCard(proto)
                }
            }
        }
        .padding(.horizontal)
    }

    private func protocolCard(_ proto: MockFriendsService.MockProtocol) -> some View {
        let progress = max(0, min(1, Double(proto.week) / Double(max(proto.totalWeeks, 1))))
        let isExpanded = expandedProtocol == proto.name
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                expandedProtocol = isExpanded ? nil : proto.name
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.pink.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: "syringe.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.pink)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(proto.name)
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("Week \(proto.week) of \(proto.totalWeeks)")
                            .font(.caption2)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(PepTheme.elevated)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.pink)
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 5)

                if isExpanded {
                    HStack(spacing: 14) {
                        protocolDetail(label: "Dosage", value: proto.dosage)
                        protocolDetail(label: "Frequency", value: proto.frequency)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(12)
            .background(PepTheme.cardSurface, in: .rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func protocolDetail(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(PepTheme.textSecondary)
            Text(value)
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Recent workouts

    private func recentWorkoutsSection(_ workouts: [MockFriendsService.MockWorkout]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionEyebrow("Recent Workouts", number: "03", accent: PepTheme.amber)

            VStack(spacing: 8) {
                ForEach(Array(workouts.enumerated()), id: \.offset) { _, workout in
                    workoutRow(workout)
                }
            }
        }
        .padding(.horizontal)
    }

    private func workoutRow(_ w: MockFriendsService.MockWorkout) -> some View {
        let key = UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", abs(w.name.hashValue) % 1_000_000_000_000))") ?? UUID()
        let isExpanded = expandedWorkout == key
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                expandedWorkout = isExpanded ? nil : key
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(sportColor(w.sport).opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: sportIcon(w.sport))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(sportColor(w.sport))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(w.name)
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                            .lineLimit(1)
                        Text(w.date, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary)
                }
                if isExpanded {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            miniMetric(icon: "clock.fill", value: "\(w.durationMin)m")
                            if w.volumeKg > 0 {
                                miniMetric(icon: "scalemass.fill", value: "\(w.volumeKg)kg")
                            }
                            miniMetric(icon: "flame.fill", value: "\(w.calories) cal")
                        }
                        if shares(.sets) && !w.exercises.isEmpty {
                            Divider().overlay(PepTheme.separatorColor)
                            expandedExerciseList(w.exercises)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(12)
            .background(PepTheme.cardSurface, in: .rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func miniMetric(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(PepTheme.textSecondary)
            Text(value)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(PepTheme.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(PepTheme.elevated, in: Capsule())
    }

    private func sportIcon(_ sport: String) -> String {
        switch sport.lowercased() {
        case "run": return "figure.run"
        case "cycle": return "figure.outdoor.cycle"
        case "hiit": return "figure.highintensity.intervaltraining"
        case "walk": return "figure.hiking"
        default: return "dumbbell.fill"
        }
    }

    private func sportColor(_ sport: String) -> Color {
        switch sport.lowercased() {
        case "run": return PepTheme.amber
        case "cycle": return PepTheme.violet
        case "hiit": return .red
        case "walk": return .green
        default: return PepTheme.teal
        }
    }

    // MARK: - PR card

    private func prCard(_ pr: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LATEST PR")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(PepTheme.amber)
            Text(pr)
                .font(.system(size: 22, weight: .light, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(PepTheme.cardSurface, in: .rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
        )
        .padding(.horizontal)
    }

    // MARK: - Activity timeline

    private var activityTimeline: some View {
        let events = MockFriendsService.shared.activityEvents().filter { $0.user.id == friend.user.id }
        return Group {
            if !events.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionEyebrow("Activity", number: "04", accent: PepTheme.violet)

                    VStack(spacing: 0) {
                        ForEach(Array(events.prefix(6).enumerated()), id: \.element.id) { idx, event in
                            FriendActivityRow(event: event)
                            if idx < min(events.count, 6) - 1 {
                                Divider().overlay(PepTheme.separatorColor).padding(.leading, 52)
                            }
                        }
                    }
                    .background(PepTheme.cardSurface, in: .rect(cornerRadius: 14))
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Protocol banner strip

    private func protocolBannerStrip(_ protos: [MockFriendsService.MockProtocol]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(protos, id: \.name) { proto in
                    Button {
                        protocolDetail = proto
                    } label: {
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.pink.opacity(0.18))
                                    .frame(width: 26, height: 26)
                                Image(systemName: "syringe.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.pink)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(proto.name)
                                    .font(.system(.caption, weight: .semibold))
                                    .foregroundStyle(PepTheme.textPrimary)
                                    .lineLimit(1)
                                Text("wk \(proto.week)/\(proto.totalWeeks)")
                                    .font(.system(size: 9))
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(PepTheme.cardSurface, in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.pink.opacity(0.25), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .scrollClipDisabled()
    }

    // MARK: - Today card

    private var hasAnyTodayShare: Bool {
        shares(.steps) || shares(.calories) || shares(.water) || shares(.nutrition) || shares(.workouts)
    }

    private func todayCard(_ today: MockFriendsService.MockTodaySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionEyebrow("Today", accent: PepTheme.teal) {
                Text(Date().formatted(.dateTime.month(.abbreviated).day()))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            HStack(spacing: 10) {
                if shares(.steps) {
                    todayMetricChip(
                        icon: "figure.walk",
                        value: "\(today.stepsSoFar)",
                        sub: "/ \(today.stepsGoal)",
                        color: PepTheme.teal,
                        progress: min(1.0, Double(today.stepsSoFar) / Double(max(today.stepsGoal, 1)))
                    )
                }
                if shares(.calories) {
                    todayMetricChip(
                        icon: "flame.fill",
                        value: "\(today.caloriesBurned)",
                        sub: "cal burned",
                        color: .orange,
                        progress: nil
                    )
                }
            }

            if shares(.water) {
                waterBar(ml: today.waterMl, goal: today.waterGoalMl)
            }

            if shares(.nutrition) && !today.meals.isEmpty {
                mealsBlock(today.meals)
            }

            if !today.recentActivity.isEmpty {
                Divider().overlay(PepTheme.separatorColor).padding(.vertical, 2)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .textCase(.uppercase)
                    ForEach(today.recentActivity.prefix(3)) { entry in
                        HStack(spacing: 8) {
                            Image(systemName: entry.icon)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(PepTheme.teal)
                                .frame(width: 22, height: 22)
                                .background(PepTheme.teal.opacity(0.12), in: Circle())
                            Text(entry.title)
                                .font(.caption)
                                .foregroundStyle(PepTheme.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text(entry.time, style: .relative)
                                .font(.system(size: 10))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(PepTheme.cardSurface, in: .rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
        )
        .padding(.horizontal)
    }

    private func todayMetricChip(icon: String, value: String, sub: String, color: Color, progress: Double?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(color)
                Text(sub)
                    .font(.system(size: 10))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(PepTheme.textPrimary)
            if let progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(PepTheme.elevated)
                        RoundedRectangle(cornerRadius: 2).fill(color).frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(PepTheme.elevated, in: .rect(cornerRadius: 10))
    }

    private func waterBar(ml: Int, goal: Int) -> some View {
        let progress = min(1.0, Double(ml) / Double(max(goal, 1)))
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PepTheme.blue)
                    Text("Water")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Spacer()
                Text(String(format: "%.1fL / %.1fL", Double(ml) / 1000, Double(goal) / 1000))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(PepTheme.elevated)
                    RoundedRectangle(cornerRadius: 3).fill(PepTheme.blue).frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 5)
        }
    }

    private func mealsBlock(_ meals: [MockFriendsService.MockMeal]) -> some View {
        let totalCal = meals.reduce(0) { $0 + $1.calories }
        let totalProtein = meals.reduce(0) { $0 + $1.protein }
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    mealsExpanded.toggle()
                }
            } label: {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.green)
                        Text("Meals")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                            .textCase(.uppercase)
                    }
                    Spacer()
                    Text("\(totalCal) cal · \(totalProtein)g P")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Image(systemName: mealsExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            .buttonStyle(.plain)

            if mealsExpanded {
                VStack(spacing: 6) {
                    ForEach(Array(meals.enumerated()), id: \.offset) { _, meal in
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(meal.mealTime)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.green)
                                    .textCase(.uppercase)
                                Text(meal.name)
                                    .font(.system(.caption, weight: .semibold))
                                    .foregroundStyle(PepTheme.textPrimary)
                                    .lineLimit(1)
                                Text("P \(meal.protein)g · C \(meal.carbs)g · F \(meal.fat)g")
                                    .font(.system(size: 10))
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                            Spacer()
                            Text("\(meal.calories)")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(PepTheme.textPrimary)
                                .monospacedDigit()
                        }
                        .padding(8)
                        .background(PepTheme.elevated, in: .rect(cornerRadius: 8))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Expanded exercise list

    private func expandedExerciseList(_ exercises: [MockFriendsService.MockExerciseLog]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sets")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(PepTheme.textSecondary)
                .textCase(.uppercase)
            ForEach(Array(exercises.enumerated()), id: \.offset) { _, ex in
                VStack(alignment: .leading, spacing: 3) {
                    Text(ex.name)
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(formatSets(ex.sets))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }

    private func formatSets(_ sets: [MockFriendsService.MockSet]) -> String {
        guard !sets.isEmpty else { return "" }
        let weight = sets.first?.weightKg ?? 0
        let allSameWeight = sets.allSatisfy { $0.weightKg == weight }
        let allSameRPE: Bool = {
            guard let first = sets.first?.rpe else { return sets.allSatisfy { $0.rpe == nil } }
            return sets.allSatisfy { $0.rpe == first }
        }()
        if allSameWeight {
            let reps = sets.map { "\($0.reps)" }.joined(separator: ", ")
            let rpePart: String = {
                if allSameRPE, let r = sets.first?.rpe {
                    return " @ RPE \(formatRPE(r))"
                }
                return ""
            }()
            let weightPart = weight > 0 ? "\(weight)kg × " : ""
            return "\(weightPart)\(reps)\(rpePart)"
        }
        return sets.map { s in
            let rpe = s.rpe.map { " @\(formatRPE($0))" } ?? ""
            return s.weightKg > 0 ? "\(s.weightKg)×\(s.reps)\(rpe)" : "\(s.reps)\(rpe)"
        }.joined(separator: " · ")
    }

    private func formatRPE(_ r: Double) -> String {
        r.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(r))" : String(format: "%.1f", r)
    }

    // MARK: - Live sport fullscreen

    @ViewBuilder
    private func liveSportView(_ sport: BuddySport) -> some View {
        switch sport {
        case .run:
            NavigationStack {
                LiveRunView(runVM: RunningViewModel.shared)
                    .safeAreaInset(edge: .top) {
                        BuddyProgressOverlay()
                            .padding(.horizontal)
                            .padding(.bottom, 6)
                            .background(PepTheme.background.opacity(0.0))
                    }
            }
        case .cycle:
            NavigationStack {
                LiveRideView(cyclingVM: CyclingViewModel.shared)
                    .safeAreaInset(edge: .top) {
                        BuddyProgressOverlay()
                            .padding(.horizontal)
                            .padding(.bottom, 6)
                            .background(PepTheme.background.opacity(0.0))
                    }
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Helpers

    private func shares(_ category: StatShareCategory) -> Bool {
        friend.sharedCategories.contains(category)
    }

    private func formatThousands(_ v: Int) -> String {
        if v >= 1000 { return String(format: "%.1fk", Double(v) / 1000) }
        return "\(v)"
    }
}

private struct ProtocolDetailMockSheet: View {
    let proto: MockFriendsService.MockProtocol
    @Environment(\.dismiss) private var dismiss

    private var matchedCompound: CompoundProfile? {
        let lower = proto.name.lowercased()
        if let exact = CompoundDatabase.all.first(where: { $0.name.lowercased() == lower }) {
            return exact
        }
        return CompoundDatabase.all.first { c in
            let n = c.name.lowercased()
            return lower.contains(n) || n.contains(lower)
        }
    }

    private var progress: Double {
        max(0, min(1, Double(proto.week) / Double(max(proto.totalWeeks, 1))))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    progressBlock
                    detailsBlock
                    if let compound = matchedCompound {
                        learnMoreBlock(compound)
                    }
                    Color.clear.frame(height: 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: CompoundProfile.self) { compound in
                CompoundDetailView(compound: compound)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                }
            }
        }
    }

    // MARK: - Editorial sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("PROTOCOL")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.9))
                Rectangle()
                    .fill(PepTheme.separatorColor)
                    .frame(height: 0.5)
            }

            Text(proto.name)
                .font(.system(size: 34, weight: .light, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            Text("Week \(proto.week) of \(proto.totalWeeks)".uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(PepTheme.textSecondary)
        }
    }

    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionEyebrow("Progress", number: "01", accent: PepTheme.teal) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(PepTheme.separatorColor)
                        .frame(height: 0.5)
                    Rectangle()
                        .fill(PepTheme.textPrimary)
                        .frame(width: geo.size.width * progress, height: 1.5)
                }
            }
            .frame(height: 6)
        }
    }

    private var detailsBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionEyebrow("Details", number: "02", accent: PepTheme.violet)
                .padding(.bottom, 12)
            editorialRow(label: "Dosage", value: proto.dosage)
            Rectangle().fill(PepTheme.separatorColor).frame(height: 0.5)
            editorialRow(label: "Frequency", value: proto.frequency)
            Rectangle().fill(PepTheme.separatorColor).frame(height: 0.5)
            editorialRow(label: "Duration", value: "\(proto.totalWeeks) weeks")
            Rectangle().fill(PepTheme.separatorColor).frame(height: 0.5)
            editorialRow(label: "Current", value: "Week \(proto.week)")
        }
    }

    private func editorialRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(PepTheme.textSecondary)
            Spacer(minLength: 16)
            Text(value)
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 14)
    }

    private func learnMoreBlock(_ compound: CompoundProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionEyebrow("Learn More", number: "03", accent: .pink)

            NavigationLink(value: compound) {
                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(compound.name)
                            .font(.system(size: 22, weight: .light, design: .serif))
                            .foregroundStyle(PepTheme.textPrimary)
                            .lineLimit(1)
                        Text(compound.peptideType.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.4)
                            .foregroundStyle(PepTheme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    HStack(spacing: 6) {
                        Text("VIEW")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.6)
                            .foregroundStyle(PepTheme.textPrimary)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                    }
                }
                .padding(.vertical, 18)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)

            Text("Open the discover page to read about pharmacology, protocols, side effects and sourcing.")
                .font(.system(.footnote, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
                .padding(.horizontal, 2)
        }
    }
}
