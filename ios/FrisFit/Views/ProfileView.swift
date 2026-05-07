import SwiftUI
import PhotosUI

struct ProfileView: View {
    @State private var viewModel = ProfileViewModel()
    @State private var socialViewModel = SocialViewModel()
    @State private var isLoading: Bool = true
    @State private var selectedTab: ProfileTab = .posts
    @State private var showEditProfile: Bool = false
    @State private var showReconCalculator: Bool = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUploadingAvatar: Bool = false
    @State private var navigateToPost: FeedPost?
    @State private var selectedHashtag: String?
    @State private var bannerStore = ProfileBannerStore.shared
    @State private var scrollOffset: CGFloat = 0
    @State private var navigateToSettings: Bool = false

    enum ProfileTab: String, CaseIterable {
        case posts = "Posts"
        case health = "Health"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    SkeletonProfileView()
                        .padding(.top, 8)
                        .transition(.opacity)
                } else {
                    VStack(spacing: 0) {
                        unifiedHeader
                        tabSection
                            .padding(.top, 22)
                    }
                    .padding(.bottom, 32)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .scrollIndicators(.hidden)
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { _, newValue in
                scrollOffset = newValue
            }
            .appBackground(accent: PepTheme.teal)
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .topTrailing) {
                profileFloatingPill
                    .padding(.trailing, 16)
                    .padding(.top, 8)
            }
            .navigationDestination(isPresented: $navigateToSettings) {
                SettingsView(viewModel: viewModel)
            }
            .task {
                await viewModel.loadProfile()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    isLoading = false
                }
            }
            .sheet(isPresented: $showEditProfile, onDismiss: {
                Task { await viewModel.loadProfile() }
            }) {
                EditProfileView(viewModel: viewModel)
            }
            .sheet(isPresented: $showReconCalculator) {
                ReconstitutionCalculatorView()
            }
            .navigationDestination(for: ProfileDestination.self) { destination in
                switch destination {
                case .analytics:
                    WorkoutAnalyticsView(viewModel: viewModel)
                case .achievements:
                    AchievementsView(viewModel: viewModel)
                case .settings:
                    SettingsView(viewModel: viewModel)
                case .workoutHistory:
                    WorkoutHistoryView(viewModel: viewModel)
                case .historyDetail(let workout):
                    WorkoutHistoryDetailView(workout: workout)
                case .userProfile(let user):
                    UserProfileView(user: user, viewModel: viewModel)
                case .bloodwork:
                    BloodworkTrackingView()
                case .progressPhotos:
                    ProgressPhotosView()
                case .protocolHistory:
                    ProtocolHistoryView()
                case .biomarkerTrends:
                    BiomarkerTrackingView()
                case .stackBuilder:
                    PeptideStackBuilderView()
                case .appleHealth:
                    AppleHealthSyncView()
                }
            }
            .navigationDestination(for: FeedPost.self) { post in
                PostDetailView(post: post, viewModel: socialViewModel)
            }
            .navigationDestination(item: $navigateToPost) { post in
                PostDetailView(post: post, viewModel: socialViewModel)
            }
            .navigationDestination(item: Binding(get: { selectedHashtag.map(HashtagDestination.init) }, set: { selectedHashtag = $0?.tag })) { dest in
                HashtagFeedView(tag: dest.tag)
            }
            .navigationDestination(for: FollowListDestination.self) { destination in
                FollowListView(destination: destination, profileViewModel: viewModel)
            }
        }
    }

    private var profileFloatingPill: some View {
        FloatingNavPill(scrollOffset: scrollOffset) {
            FloatingPillIconButton(systemName: "gearshape") {
                navigateToSettings = true
            }
        }
    }

    private var unifiedHeader: some View {
        UnifiedProfileHeader(
            bannerImage: bannerStore.bannerImage,
            bannerUrl: viewModel.profile.bannerUrl,
            avatarUrl: viewModel.profile.avatarUrl,
            avatarInitials: viewModel.profile.initials,
            avatarColor: viewModel.profile.avatarColor,
            displayName: viewModel.profile.displayName,
            username: viewModel.profile.username,
            userIdString: viewModel.profile.id.uuidString,
            followingCount: viewModel.profile.followingCount,
            followerCount: viewModel.profile.followerCount,
            friendCount: viewModel.profile.friendCount,
            isUploadingAvatar: isUploadingAvatar
        ) {
            Button {
                showEditProfile = true
            } label: {
                Text("Edit Profile")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(PepTheme.elevated)
                    .clipShape(.capsule)
                    .overlay(
                        Capsule().strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                    )
            }
        } avatarBadge: {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Image(systemName: "camera")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(PepTheme.textSecondary)
                    .frame(width: 26, height: 26)
                    .background(PepTheme.background)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(PepTheme.separatorColor, lineWidth: 0.5))
            }
            .onChange(of: selectedPhoto) { _, newValue in
                guard let newValue else { return }
                Task {
                    guard let data = try? await newValue.loadTransferable(type: Data.self) else { return }
                    isUploadingAvatar = true
                    _ = await viewModel.uploadAvatar(imageData: data)
                    isUploadingAvatar = false
                    selectedPhoto = nil
                }
            }
        }
    }

    private var contextStrip: some View {
        let entries: [(SocialPlatform, String?)] = [
            (.instagram, viewModel.profile.instagramHandle),
            (.twitter, viewModel.profile.twitterHandle),
            (.tiktok, viewModel.profile.tiktokHandle),
            (.facebook, viewModel.profile.facebookHandle)
        ]
        let links = entries.compactMap { item -> ProfileContextStrip.SocialLinkEntry? in
            guard let url = SocialLink.url(for: item.0, handle: item.1) else { return nil }
            return ProfileContextStrip.SocialLinkEntry(platform: item.0, url: url)
        }
        return ProfileContextStrip(
            bio: viewModel.profile.bio,
            activeProgram: viewModel.profile.activeProgram,
            phase: nil,
            memberSinceText: viewModel.memberSinceFormatted,
            socialLinks: links
        )
    }

    private var statsBar: some View {
        HStack(spacing: 0) {
            ProfileQuickStat(value: "\(viewModel.streakManager.streakData.currentStreak)", label: "Day Streak", icon: "flame.fill", color: PepTheme.amber)
            ProfileQuickStat(value: "\(viewModel.profile.totalWorkouts)", label: "Workouts", icon: "dumbbell.fill", color: PepTheme.violet)
        }
        .padding(.vertical, 14)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    private var tabSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(ProfileTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Text(tab.rawValue)
                                .font(.system(.subheadline, weight: selectedTab == tab ? .bold : .medium))
                                .foregroundStyle(selectedTab == tab ? PepTheme.textPrimary : PepTheme.textSecondary)
                                .frame(maxWidth: .infinity)

                            Rectangle()
                                .fill(selectedTab == tab ? PepTheme.textPrimary : .clear)
                                .frame(height: 1)
                        }
                    }
                    .sensoryFeedback(.selection, trigger: selectedTab)
                }
            }
            .padding(.horizontal, 16)

            Divider()
                .overlay(PepTheme.separatorColor)

            switch selectedTab {
            case .posts:
                postsTab
            case .health:
                healthTab
            }
        }
    }

    private var postsTab: some View {
        LazyVStack(spacing: 0) {
            contextStrip
            let posts = viewModel.postsForUser(viewModel.profile.id)
            if posts.isEmpty {
                profileEmptyState(icon: "text.bubble", title: "No Posts Yet", message: "Share your workouts and thoughts with the community.")
            } else {
                ForEach(posts) { post in
                    ProfilePostRow(post: post, profile: viewModel.profile, onTap: {
                        navigateToPost = feedPostFromUserPost(post)
                    }, onLike: {
                        viewModel.togglePostLike(post.id)
                    }, onDelete: {
                        deletePost(post)
                    }, onOpenHashtag: { tag in
                        selectedHashtag = tag
                    })
                    Divider().overlay(PepTheme.separatorColor)
                }
            }
        }
    }

    private func feedPostFromUserPost(_ post: UserPost) -> FeedPost {
        let user = SocialUser(
            id: viewModel.profile.id,
            name: viewModel.profile.displayName,
            username: viewModel.profile.username,
            avatarInitial: viewModel.profile.initials,
            avatarColor: viewModel.profile.avatarColor,
            avatarURL: viewModel.profile.avatarUrl,
            activeProgramName: viewModel.profile.activeProgram,
            streak: viewModel.profile.currentStreak
        )
        let mediaItems: [FeedMediaItem] = post.mediaUrls.map { url in
            FeedMediaItem(type: .photo, imageURL: url)
        }
        let pid = post.id.uuidString.lowercased()
        return FeedPost(
            id: post.id,
            user: user,
            timestamp: post.timestamp,
            textContent: post.content,
            media: mediaItems,
            likeCount: LikeManager.shared.likeCount(postId: pid, fallback: post.likeCount),
            isLiked: LikeManager.shared.isLiked(postId: pid),
            supabaseId: pid
        )
    }

    private var healthTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionEyebrow("Health", number: "01", accent: PepTheme.teal)
                .padding(.horizontal, 4)
                .padding(.bottom, 6)

            NavigationLink(value: ProfileDestination.bloodwork) {
                ProfileMenuRow(icon: "drop.fill", title: "Bloodwork Tracking", subtitle: "Log and track your lab results over time")
            }
            .buttonStyle(.scale)

            NavigationLink(value: ProfileDestination.progressPhotos) {
                ProfileMenuRow(icon: "camera.fill", title: "Progress Photos", subtitle: "Document your journey with side-by-side comparisons")
            }
            .buttonStyle(.scale)

            NavigationLink(value: ProfileDestination.protocolHistory) {
                ProfileMenuRow(icon: "pill.fill", title: "Protocol History", subtitle: "View past and current peptide protocols")
            }
            .buttonStyle(.scale)

            Button {
                showReconCalculator = true
            } label: {
                ProfileMenuRow(icon: "function", title: "Reconstitution Calculator", subtitle: "Vial presets, syringe picker, BUD tracking")
            }
            .buttonStyle(.scale)

            NavigationLink(value: ProfileDestination.biomarkerTrends) {
                ProfileMenuRow(icon: "chart.xyaxis.line", title: "Biomarker Trends", subtitle: "Weight, HbA1c, sleep & more against your protocol")
            }
            .buttonStyle(.scale)

            NavigationLink(value: ProfileDestination.stackBuilder) {
                ProfileMenuRow(icon: "square.stack.3d.up.fill", title: "Stack Builder", subtitle: "Combine peptides with conflict & synergy checks")
            }
            .buttonStyle(.scale)

            NavigationLink(value: ProfileDestination.appleHealth) {
                ProfileMenuRow(icon: "heart.text.square.fill", title: "Apple Health Sync", subtitle: "Auto-import weight, HR, HRV, sleep into your trends")
            }
            .buttonStyle(.scale)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private func profileEmptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
            Text(title)
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 48)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }

    private func deletePost(_ post: UserPost) {
        let supabaseId = post.id.uuidString.lowercased()
        Task {
            do {
                try await SocialService.shared.deletePost(postId: supabaseId)
                await viewModel.loadUserPosts()
            } catch {}
        }
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        }
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000)
        }
        return "\(count)"
    }
}

enum ProfileDestination: Hashable {
    case analytics
    case achievements
    case settings
    case workoutHistory
    case historyDetail(WorkoutHistoryDetail)
    case userProfile(SocialUser)
    case bloodwork
    case progressPhotos
    case protocolHistory
    case biomarkerTrends
    case stackBuilder
    case appleHealth
}

extension WorkoutHistoryDetail: Hashable {
    nonisolated static func == (lhs: WorkoutHistoryDetail, rhs: WorkoutHistoryDetail) -> Bool {
        lhs.id == rhs.id
    }
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct ProfileQuickStat: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ProfilePostRow: View {
    let post: UserPost
    let profile: UserProfile
    var onTap: (() -> Void)? = nil
    let onLike: () -> Void
    var onDelete: (() -> Void)? = nil
    var onOpenHashtag: ((String) -> Void)? = nil

    @State private var likeBounce: Int = 0
    @State private var showDeleteConfirm: Bool = false
    @State private var showReportConfirm: Bool = false
    private let likeManager = LikeManager.shared

    private var postSupabaseId: String {
        post.id.uuidString.lowercased()
    }

    private var isOwnPost: Bool {
        guard let userId = try? AuthService.shared.currentUserId() else { return false }
        return post.authorId.uuidString.lowercased() == userId.lowercased()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ProfileAvatarView(
                avatarUrl: profile.avatarUrl,
                initials: profile.initials,
                avatarColor: profile.avatarColor,
                size: 40
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(profile.displayName)
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)

                    Text("@\(profile.username)")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)

                    Text("·")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)

                    Text(post.timestamp.formattedPostDate())
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)

                    Spacer()

                    Menu {
                        if isOwnPost {
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Label("Delete Post", systemImage: "trash")
                            }
                        }
                        Button {
                            showReportConfirm = true
                        } label: {
                            Label("Report", systemImage: "flag")
                        }
                        Button {
                            UIPasteboard.general.string = post.content
                        } label: {
                            Label("Copy Text", systemImage: "doc.on.doc")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14))
                            .foregroundStyle(PepTheme.textSecondary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .alert("Delete Post?", isPresented: $showDeleteConfirm) {
                        Button("Cancel", role: .cancel) {}
                        Button("Delete", role: .destructive) {
                            onDelete?()
                        }
                    } message: {
                        Text("This action cannot be undone.")
                    }
                    .alert("Report Post?", isPresented: $showReportConfirm) {
                        Button("Cancel", role: .cancel) {}
                        Button("Report", role: .destructive) {}
                    } message: {
                        Text("This post will be flagged for review.")
                    }
                }

                if !post.content.isEmpty {
                    RichText(
                        text: post.content,
                        font: .subheadline,
                        onHashtag: { tag in onOpenHashtag?(tag) }
                    )
                    .lineSpacing(3)
                }

                if !post.mediaUrls.isEmpty {
                    ProfilePostMediaGrid(mediaUrls: post.mediaUrls)
                }

                if post.audioUrl != nil {
                    ProfilePostAudioBadge(duration: post.audioDuration ?? 0)
                }

                if let attachment = post.workoutAttachment {
                    workoutCard(attachment)
                }

                HStack(spacing: 24) {
                    Button {
                        onLike()
                        likeBounce += 1
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: likeManager.isLiked(postId: postSupabaseId) ? "heart.fill" : "heart")
                                .font(.system(size: 14))
                                .foregroundStyle(likeManager.isLiked(postId: postSupabaseId) ? .red : PepTheme.textSecondary)
                                .symbolEffect(.bounce, value: likeBounce)
                            Text("\(likeManager.likeCount(postId: postSupabaseId, fallback: post.likeCount))")
                                .font(.caption)
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.impact(weight: .light), trigger: likeBounce)

                    HStack(spacing: 5) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 14))
                        Text("\(post.commentCount)")
                            .font(.caption)
                    }
                    .foregroundStyle(PepTheme.textSecondary)

                    HStack(spacing: 5) {
                        Image(systemName: "arrow.2.squarepath")
                            .font(.system(size: 14))
                    }
                    .foregroundStyle(PepTheme.textSecondary)

                    Spacer()
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }

    private func workoutCard(_ attachment: WorkoutPostAttachment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(attachment.workoutName)
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)

            HStack(spacing: 14) {
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text("\(attachment.duration)m")
                        .font(.caption2)
                }
                HStack(spacing: 3) {
                    Image(systemName: "dumbbell")
                        .font(.system(size: 10))
                    Text("\(attachment.exerciseCount)")
                        .font(.caption2)
                }
            }
            .foregroundStyle(PepTheme.textSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.elevated.opacity(0.6))
        .clipShape(.rect(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }
}

struct ProfileMarketCard: View {
    let program: MarketProgram

    var body: some View {
        HStack(spacing: 14) {
            let colors = program.gradientColors.map { Color(red: $0.r, green: $0.g, blue: $0.b) }
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(colors: colors, startPoint: .topTrailing, endPoint: .bottomLeading)
                )
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: program.iconName)
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.9))
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(program.title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", program.rating))
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }

                    Text("·")
                        .foregroundStyle(PepTheme.textSecondary)

                    Text("\(program.reviewCount) reviews")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)

                    Text("·")
                        .foregroundStyle(PepTheme.textSecondary)

                    Text(program.difficulty.rawValue)
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }

                Text("\(program.durationWeeks) weeks · \(program.daysPerWeek)x/week")
                    .font(.caption2)
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .padding(14)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }
}

private struct ProfileMenuRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(PepTheme.textSecondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.body, weight: .medium))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(height: 0.5)
        }
    }
}
