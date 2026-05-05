import SwiftUI
import AVFoundation

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
    @State private var revealFiltered: Bool = false
    @State private var moderation = LocalModerationStore.shared
    @State private var repostBounce: Int = 0
    @State private var showDeleteConfirm: Bool = false
    @State private var showReportSheet: Bool = false
    @State private var showBlockConfirm: Bool = false
    private var audioPlayer: AudioPlayerService { AudioPlayerService.shared }
    private let likeManager = LikeManager.shared

    private var postSupabaseId: String {
        post.supabaseId ?? post.id.uuidString.lowercased()
    }

    private var isOwnPost: Bool {
        guard let userId = try? AuthService.shared.currentUserId() else { return false }
        return post.user.id.uuidString.lowercased() == userId.lowercased()
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                contentArea
                Divider().overlay(PepTheme.separatorColor)
                actionBar
            }
        }
        .onAppear { onAppear?() }
    }

    private var contentArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            userHeader
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
            }
            if let voice = post.voiceMedia {
                voiceMessageSection(voice)
            }
            if let market = post.marketLink, let program = market.marketProgram {
                marketLinkSection(program)
            }
            if let workout = post.workoutAttachment, let log = workout.workoutLog {
                workoutLogSection(log)
            }
        }
        .contentShape(.rect)
        .onTapGesture {
            onTap?()
        }
    }

    private var userHeader: some View {
        HStack(spacing: 12) {
            Button {
                onUserTap?(post.user)
            } label: {
                HStack(spacing: 12) {
                    Circle()
                        .fill(post.user.avatarColor.opacity(0.2))
                        .frame(width: 42, height: 42)
                        .overlay {
                            Text(post.user.avatarInitial)
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .foregroundStyle(post.user.avatarColor)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(post.user.name)
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                            Text("@\(post.user.username)")
                                .font(.caption)
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        HStack(spacing: 4) {
                            Text(post.timestamp.formattedPostDate())
                                .font(.caption2)
                                .foregroundStyle(PepTheme.textSecondary)
                            if post.editedAt != nil {
                                Text("· edited")
                                    .font(.caption2)
                                    .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                            }
                        }
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            Spacer()

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
                    .font(.system(size: 14))
                    .foregroundStyle(PepTheme.textSecondary)
                    .frame(width: 32, height: 32)
            }
            .alert("Delete Post?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    onDelete?()
                }
            } message: {
                Text("This action cannot be undone.")
            }
            .alert("Block @\(post.user.username)?", isPresented: $showBlockConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Block", role: .destructive) {
                    onBlock?()
                }
            } message: {
                Text("You won't see their posts, comments, or messages. They won't be notified.")
            }
            .sheet(isPresented: $showReportSheet) {
                ReportContentSheet(targetType: "post", targetId: post.supabaseId ?? post.id.uuidString.lowercased())
            }
        }
    }

    @ViewBuilder
    private var photoGridSection: some View {
        let photos = post.photoMedia
        let columns = photos.count == 1 ? 1 : 2
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: columns),
            spacing: 3
        ) {
            ForEach(photos) { photo in
                Color(.tertiarySystemFill)
                    .aspectRatio(photos.count == 1 ? 16/9 : 1, contentMode: .fit)
                    .overlay {
                        if let urlString = photo.imageURL, let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                case .failure:
                                    Image(systemName: "photo")
                                        .font(.title2)
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
                                .font(.title2)
                                .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                        }
                    }
                    .clipShape(.rect(cornerRadius: 10))
            }
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
                    .font(.system(size: 32))
                    .foregroundStyle(PepTheme.teal)
            }

            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        waveformBars(width: geo.size.width, height: geo.size.height)
                        Rectangle()
                            .fill(PepTheme.teal)
                            .frame(width: geo.size.width * progress)
                            .mask { waveformBars(width: geo.size.width, height: geo.size.height) }
                    }
                }
                .frame(height: 28)

                HStack {
                    Text(formatVoiceDuration(progress * duration))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                    Text(formatVoiceDuration(duration))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
        .padding(12)
        .background(PepTheme.elevated)
        .clipShape(.rect(cornerRadius: 14))
    }

    private func waveformBars(width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<Int(width / 4.5), id: \.self) { i in
                let seed = Double(i * 7 + 3)
                let h = (sin(seed) * 0.4 + 0.6) * height
                RoundedRectangle(cornerRadius: 1)
                    .fill(PepTheme.textSecondary.opacity(0.35))
                    .frame(width: 2.5, height: max(4, h))
            }
        }
    }

    private func marketLinkSection(_ program: MarketProgram) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: program.gradientColors.map { Color(red: $0.r, green: $0.g, blue: $0.b) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: program.iconName)
                        .font(.title3)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(program.title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "bag.fill")
                        .font(.system(size: 9))
                    Text(program.creatorName)
                        .font(.caption)
                    Text("·")
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(PepTheme.amber)
                        Text(String(format: "%.1f", program.rating))
                            .font(.caption)
                    }
                }
                .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            Text("View")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(PepTheme.teal)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(PepTheme.teal.opacity(0.1))
                .clipShape(.capsule)
        }
        .padding(12)
        .background(PepTheme.elevated)
        .clipShape(.rect(cornerRadius: 14))
    }

    private func workoutLogSection(_ log: WorkoutLogAttachment) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PepTheme.teal)
                Text(log.workoutName)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)
            }

            HStack(spacing: 16) {
                workoutStat(icon: "clock", value: "\(log.duration)m", label: "Duration")
                workoutStat(icon: "dumbbell", value: "\(log.exerciseCount)", label: "Exercises")
                workoutStat(icon: "scalemass", value: formatVolume(log.totalVolume), label: "Volume")
            }


        }
        .padding(12)
        .background(PepTheme.elevated)
        .clipShape(.rect(cornerRadius: 14))
    }

    private func workoutStat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(value)
                    .font(.system(.caption, weight: .semibold))
            }
            .foregroundStyle(PepTheme.textPrimary)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(PepTheme.textSecondary)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 0) {
            Button {
                onLike()
                likeBounce += 1
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: likeManager.isLiked(postId: postSupabaseId) ? "heart.fill" : "heart")
                        .font(.system(size: 17))
                        .foregroundStyle(likeManager.isLiked(postId: postSupabaseId) ? .red : PepTheme.textSecondary)
                        .symbolEffect(.bounce, value: likeBounce)
                    Text("\(likeManager.likeCount(postId: postSupabaseId, fallback: post.likeCount))")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(likeManager.isLiked(postId: postSupabaseId) ? .red : PepTheme.textSecondary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.scale)
            .sensoryFeedback(.impact(weight: .medium), trigger: likeBounce)

            Spacer()

            Button {
                onComment()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 15))
                    Text("\(post.commentCount)")
                        .font(.system(.subheadline, weight: .medium))
                }
                .foregroundStyle(PepTheme.textSecondary)
                .contentShape(.rect)
            }
            .buttonStyle(.scale)

            Spacer()

            Button {
                onRepost()
                repostBounce += 1
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: post.isReposted ? "arrow.2.squarepath" : "arrow.2.squarepath")
                        .font(.system(size: 15))
                        .foregroundStyle(post.isReposted ? PepTheme.teal : PepTheme.textSecondary)
                        .symbolEffect(.bounce, value: repostBounce)
                    Text("\(post.repostCount)")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(post.isReposted ? PepTheme.teal : PepTheme.textSecondary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.scale)
            .sensoryFeedback(.impact(weight: .light), trigger: repostBounce)

            Spacer()

            Button { } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15))
                    .foregroundStyle(PepTheme.textSecondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.scale)
        }
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
            .padding(12)
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
