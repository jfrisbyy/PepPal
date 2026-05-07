import SwiftUI
import AVFoundation

/// Dense, edge-to-edge feed row in the spirit of X/Threads.
/// Avatar on a left rail; username, timestamp, text, media, and actions
/// stacked tightly in a single right-hand column. Rows are separated by a
/// hairline divider drawn by the parent container — no card chrome.
struct FeedPostCard: View {
    let post: FeedPost
    let onLike: () -> Void
    let onComment: () -> Void
    let onRepost: () -> Void
    var onTap: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onReport: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onBlock: (() -> Void)? = nil
    var onMute: (() -> Void)? = nil
    var onOpenMention: ((String) -> Void)? = nil
    var onOpenHashtag: ((String) -> Void)? = nil
    var onAppear: (() -> Void)? = nil
    var onUserTap: ((SocialUser) -> Void)? = nil

    @State private var likeBounce: Int = 0
    @State private var showShareSheet: Bool = false
    @State private var revealFiltered: Bool = false
    @State private var moderation = LocalModerationStore.shared
    @State private var repostBounce: Int = 0
    @State private var showDeleteConfirm: Bool = false
    @State private var showReportSheet: Bool = false
    @State private var showBlockConfirm: Bool = false
    private var audioPlayer: AudioPlayerService { AudioPlayerService.shared }
    private let likeManager = LikeManager.shared

    private let avatarSize: CGFloat = 36
    private let railSpacing: CGFloat = 10

    private var postSupabaseId: String {
        post.supabaseId ?? post.id.uuidString.lowercased()
    }

    private var isOwnPost: Bool {
        guard let userId = try? AuthService.shared.currentUserId() else { return false }
        return post.user.id.uuidString.lowercased() == userId.lowercased()
    }

    var body: some View {
        HStack(alignment: .top, spacing: railSpacing) {
            avatarButton
            VStack(alignment: .leading, spacing: 6) {
                metaRow
                contentBody
                actionBar
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(.rect)
        .onTapGesture { onTap?() }
        .onAppear { onAppear?() }
    }

    // MARK: - Header / meta

    private var avatarButton: some View {
        Button {
            onUserTap?(post.user)
        } label: {
            Circle()
                .fill(post.user.avatarColor.opacity(0.2))
                .frame(width: avatarSize, height: avatarSize)
                .overlay {
                    if let urlString = post.user.avatarURL,
                       let url = URL(string: urlString),
                       !urlString.isEmpty {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().aspectRatio(contentMode: .fill)
                            default:
                                Text(post.user.avatarInitial)
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                    .foregroundStyle(post.user.avatarColor)
                            }
                        }
                        .clipShape(Circle())
                        .allowsHitTesting(false)
                    } else {
                        Text(post.user.avatarInitial)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(post.user.avatarColor)
                    }
                }
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var metaRow: some View {
        HStack(spacing: 4) {
            Button {
                onUserTap?(post.user)
            } label: {
                HStack(spacing: 4) {
                    Text(post.user.name)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(1)
                    Text("@\(post.user.username)")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                        .lineLimit(1)
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                    Text(post.timestamp.formattedPostDate())
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                        .lineLimit(1)
                    if post.editedAt != nil {
                        Circle()
                            .fill(PepTheme.textSecondary.opacity(0.6))
                            .frame(width: 3, height: 3)
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 4)

            postMenu
        }
    }

    private var postMenu: some View {
        Menu {
            if isOwnPost {
                Button {
                    onEdit?()
                } label: {
                    Label("Edit Post", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete Post", systemImage: "trash")
                }
            }
            if !isOwnPost {
                Button {
                    showReportSheet = true
                } label: {
                    Label("Report Post", systemImage: "flag")
                }
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        moderation.muteUser(post.user.id.uuidString)
                    }
                    onMute?()
                } label: {
                    Label("Mute @\(post.user.username)", systemImage: "speaker.slash.fill")
                }
                Button(role: .destructive) {
                    showBlockConfirm = true
                } label: {
                    Label("Block @\(post.user.username)", systemImage: "hand.raised.fill")
                }
            }
            Button {
                UIPasteboard.general.string = post.textContent
            } label: {
                Label("Copy Text", systemImage: "doc.on.doc")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12))
                .foregroundStyle(PepTheme.textSecondary)
                .frame(width: 24, height: 20)
                .contentShape(.rect)
        }
        .alert("Delete Post?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { onDelete?() }
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Block @\(post.user.username)?", isPresented: $showBlockConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Block", role: .destructive) { onBlock?() }
        } message: {
            Text("You won't see their posts, comments, or messages. They won't be notified.")
        }
        .sheet(isPresented: $showReportSheet) {
            ReportContentSheet(targetType: "post", targetId: post.supabaseId ?? post.id.uuidString.lowercased())
        }
    }

    // MARK: - Body

    @ViewBuilder
    private var contentBody: some View {
        if !post.textContent.isEmpty {
            if let matched = moderation.matchedKeyword(in: post.textContent), !revealFiltered {
                filteredBanner(keyword: matched)
            } else {
                RichText(
                    text: post.textContent,
                    onMention: { handle in onOpenMention?(handle) },
                    onHashtag: { tag in onOpenHashtag?(tag) }
                )
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        if !post.photoMedia.isEmpty {
            photoGridSection
                .padding(.top, 2)
        }
        if let voice = post.voiceMedia {
            voiceMessageSection(voice)
                .padding(.top, 2)
        }
        if let market = post.marketLink, let program = market.marketProgram {
            marketLinkSection(program)
                .padding(.top, 2)
        }
        if let workout = post.workoutAttachment, let log = workout.workoutLog {
            workoutLogSection(log)
                .padding(.top, 2)
        }
    }

    @ViewBuilder
    private var photoGridSection: some View {
        let photos = post.photoMedia
        if photos.count == 1, let photo = photos.first {
            // Single photo: shorter cap (5:4) instead of letterbox 16:9.
            Color(.tertiarySystemFill)
                .aspectRatio(5.0/4.0, contentMode: .fit)
                .overlay { photoImage(for: photo) }
                .clipShape(.rect(cornerRadius: 12))
        } else {
            let columns = 2
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: columns),
                spacing: 2
            ) {
                ForEach(photos) { photo in
                    Color(.tertiarySystemFill)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay { photoImage(for: photo) }
                        .clipShape(.rect(cornerRadius: 8))
                }
            }
        }
    }

    @ViewBuilder
    private func photoImage(for photo: FeedMediaItem) -> some View {
        if let urlString = photo.imageURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                case .empty:
                    ProgressView()
                        .tint(PepTheme.teal)
                @unknown default:
                    EmptyView()
                }
            }
            .allowsHitTesting(false)
        } else {
            Image(systemName: "photo")
                .font(.title3)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
        }
    }

    private func voiceMessageSection(_ voice: FeedMediaItem) -> some View {
        let voiceURL = voice.imageURL ?? ""
        let isPlaying = audioPlayer.isPlayingURL(voiceURL)
        let progress = audioPlayer.progressForURL(voiceURL)
        let duration = voice.voiceDuration ?? 0

        return HStack(spacing: 10) {
            Button {
                guard !voiceURL.isEmpty else { return }
                audioPlayer.play(urlString: voiceURL, duration: duration)
            } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(PepTheme.teal)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    waveformBars(width: geo.size.width, height: geo.size.height)
                    Rectangle()
                        .fill(PepTheme.teal)
                        .frame(width: geo.size.width * progress)
                        .mask { waveformBars(width: geo.size.width, height: geo.size.height) }
                }
            }
            .frame(height: 18)

            Text(formatVoiceDuration(duration))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(PepTheme.elevated)
        .clipShape(.rect(cornerRadius: 10))
    }

    private func waveformBars(width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<Int(width / 4.5), id: \.self) { i in
                let seed = Double(i * 7 + 3)
                let h = (sin(seed) * 0.4 + 0.6) * height
                RoundedRectangle(cornerRadius: 1)
                    .fill(PepTheme.textSecondary.opacity(0.35))
                    .frame(width: 2.5, height: max(3, h))
            }
        }
    }

    private func marketLinkSection(_ program: MarketProgram) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: program.gradientColors.map { Color(red: $0.r, green: $0.g, blue: $0.b) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: program.iconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(program.title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(program.creatorName)
                        .lineLimit(1)
                    Text("·")
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(PepTheme.amber)
                    Text(String(format: "%.1f", program.rating))
                }
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer(minLength: 6)

            Text("View")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(PepTheme.teal)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(PepTheme.teal.opacity(0.1))
                .clipShape(.capsule)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(PepTheme.elevated)
        .clipShape(.rect(cornerRadius: 10))
    }

    private func workoutLogSection(_ log: WorkoutLogAttachment) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(PepTheme.teal)
                .frame(width: 28, height: 28)
                .background(PepTheme.teal.opacity(0.12), in: .rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(log.workoutName)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Label("\(log.duration)m", systemImage: "clock")
                    Label("\(log.exerciseCount)", systemImage: "dumbbell")
                    Label(formatVolume(log.totalVolume), systemImage: "scalemass")
                }
                .labelStyle(.compactStat)
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(PepTheme.elevated)
        .clipShape(.rect(cornerRadius: 10))
    }

    // MARK: - Action bar

    private var actionBar: some View {
        HStack(spacing: 0) {
            actionButton(
                icon: likeManager.isLiked(postId: postSupabaseId) ? "heart.fill" : "heart",
                count: likeManager.likeCount(postId: postSupabaseId, fallback: post.likeCount),
                tint: likeManager.isLiked(postId: postSupabaseId) ? .red : PepTheme.textSecondary,
                bounce: likeBounce
            ) {
                onLike()
                likeBounce += 1
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: likeBounce)

            Spacer(minLength: 0)

            actionButton(
                icon: "bubble.left",
                count: post.commentCount,
                tint: PepTheme.textSecondary
            ) {
                onComment()
            }

            Spacer(minLength: 0)

            actionButton(
                icon: "arrow.2.squarepath",
                count: post.repostCount,
                tint: post.isReposted ? PepTheme.teal : PepTheme.textSecondary,
                bounce: repostBounce
            ) {
                onRepost()
                repostBounce += 1
            }
            .sensoryFeedback(.impact(weight: .light), trigger: repostBounce)

            Spacer(minLength: 0)

            Button {
                showShareSheet = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 13))
                    .foregroundStyle(PepTheme.textSecondary)
                    .frame(width: 28, height: 24)
                    .contentShape(.rect)
            }
            .buttonStyle(.scale)
            .sheet(isPresented: $showShareSheet) {
                SharePostSheet(post: post)
            }
        }
        .padding(.trailing, 4)
    }

    private func actionButton(
        icon: String,
        count: Int,
        tint: Color,
        bounce: Int = 0,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(tint)
                    .symbolEffect(.bounce, value: bounce)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .foregroundStyle(tint)
                        .monospacedDigit()
                }
            }
            .frame(minHeight: 24)
            .contentShape(.rect)
        }
        .buttonStyle(.scale)
    }

    @ViewBuilder
    private func filteredBanner(keyword: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) { revealFiltered = true }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 12, weight: .semibold))
                Text("Hidden by your filter (\"\(keyword)\") · tap to show")
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .foregroundStyle(PepTheme.textSecondary)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PepTheme.elevated)
            .clipShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func formatVolume(_ volume: Int) -> String {
        if volume >= 1000 {
            let k = Double(volume) / 1000.0
            return String(format: "%.1fk", k)
        }
        return "\(volume) lbs"
    }

    private func formatVoiceDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Compact stat label style for workout meta row

private struct CompactStatLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
                .font(.system(size: 9))
            configuration.title
        }
    }
}

private extension LabelStyle where Self == CompactStatLabelStyle {
    static var compactStat: CompactStatLabelStyle { CompactStatLabelStyle() }
}
