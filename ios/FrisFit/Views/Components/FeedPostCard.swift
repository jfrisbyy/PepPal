import SwiftUI

struct FeedPostCard: View {
    let post: FeedPost
    let onHighFive: () -> Void
    let onComment: () -> Void

    @State private var highFiveBounce: Int = 0
    @State private var isPlayingVoice: Bool = false
    @State private var voiceProgress: Double = 0

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                userHeader
                if !post.textContent.isEmpty {
                    Text(post.textContent)
                        .font(.system(.body))
                        .foregroundStyle(FrisTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
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
                Divider().overlay(FrisTheme.separatorColor)
                actionBar
            }
        }
    }

    private var userHeader: some View {
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
                        .foregroundStyle(FrisTheme.textPrimary)
                    Text("@\(post.user.username)")
                        .font(.caption)
                        .foregroundStyle(FrisTheme.textSecondary)
                }
                Text(post.timestamp.timeAgoDisplay())
                    .font(.caption2)
                    .foregroundStyle(FrisTheme.textSecondary)
            }

            Spacer()

            Button { } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14))
                    .foregroundStyle(FrisTheme.textSecondary)
                    .frame(width: 32, height: 32)
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
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(FrisTheme.textSecondary.opacity(0.4))
                    }
                    .clipShape(.rect(cornerRadius: 10))
            }
        }
    }

    private func voiceMessageSection(_ voice: FeedMediaItem) -> some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isPlayingVoice.toggle()
                }
            } label: {
                Image(systemName: isPlayingVoice ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(FrisTheme.cyan)
            }

            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        waveformBars(width: geo.size.width, height: geo.size.height)
                        Rectangle()
                            .fill(FrisTheme.cyan)
                            .frame(width: geo.size.width * voiceProgress)
                            .mask { waveformBars(width: geo.size.width, height: geo.size.height) }
                    }
                }
                .frame(height: 28)

                HStack {
                    Text(formatVoiceDuration(voiceProgress * (voice.voiceDuration ?? 0)))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(FrisTheme.textSecondary)
                    Spacer()
                    Text(formatVoiceDuration(voice.voiceDuration ?? 0))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(FrisTheme.textSecondary)
                }
            }
        }
        .padding(12)
        .background(FrisTheme.elevated)
        .clipShape(.rect(cornerRadius: 14))
    }

    private func waveformBars(width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<Int(width / 4.5), id: \.self) { i in
                let seed = Double(i * 7 + 3)
                let h = (sin(seed) * 0.4 + 0.6) * height
                RoundedRectangle(cornerRadius: 1)
                    .fill(FrisTheme.textSecondary.opacity(0.35))
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
                    .foregroundStyle(FrisTheme.textPrimary)
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
                            .foregroundStyle(FrisTheme.amber)
                        Text(String(format: "%.1f", program.rating))
                            .font(.caption)
                    }
                }
                .foregroundStyle(FrisTheme.textSecondary)
            }

            Spacer()

            Text("View")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(FrisTheme.cyan)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(FrisTheme.cyan.opacity(0.1))
                .clipShape(.capsule)
        }
        .padding(12)
        .background(FrisTheme.elevated)
        .clipShape(.rect(cornerRadius: 14))
    }

    private func workoutLogSection(_ log: WorkoutLogAttachment) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FrisTheme.cyan)
                Text(log.workoutName)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(FrisTheme.textPrimary)
                    .lineLimit(1)
            }

            HStack(spacing: 16) {
                workoutStat(icon: "clock", value: "\(log.duration)m", label: "Duration")
                workoutStat(icon: "dumbbell", value: "\(log.exerciseCount)", label: "Exercises")
                workoutStat(icon: "scalemass", value: formatVolume(log.totalVolume), label: "Volume")
            }

            HStack(spacing: 0) {
                Image(systemName: "bolt.fill")
                    .font(.caption)
                    .foregroundStyle(FrisTheme.cyan)
                Text(" \(log.fpEarned) FP earned")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(FrisTheme.cyan)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(FrisTheme.cyan.opacity(0.08))
            .clipShape(.capsule)
        }
        .padding(12)
        .background(FrisTheme.elevated)
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
            .foregroundStyle(FrisTheme.textPrimary)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(FrisTheme.textSecondary)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 0) {
            Button {
                onHighFive()
                highFiveBounce += 1
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: post.isHighFived ? "hand.raised.fill" : "hand.raised")
                        .font(.system(size: 17))
                        .foregroundStyle(post.isHighFived ? FrisTheme.amber : FrisTheme.textSecondary)
                        .symbolEffect(.bounce, value: highFiveBounce)
                    Text("\(post.highFiveCount)")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(post.isHighFived ? FrisTheme.amber : FrisTheme.textSecondary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.scale)
            .sensoryFeedback(.impact(weight: .medium), trigger: highFiveBounce)

            Spacer()

            Button {
                onComment()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 15))
                    Text("\(post.comments.count)")
                        .font(.system(.subheadline, weight: .medium))
                }
                .foregroundStyle(FrisTheme.textSecondary)
                .contentShape(.rect)
            }
            .buttonStyle(.scale)

            Spacer()

            Button { } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.2.squarepath")
                        .font(.system(size: 15))
                    Text("\(post.repostCount)")
                        .font(.system(.subheadline, weight: .medium))
                }
                .foregroundStyle(FrisTheme.textSecondary)
                .contentShape(.rect)
            }
            .buttonStyle(.scale)

            Spacer()

            Button { } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15))
                    .foregroundStyle(FrisTheme.textSecondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.scale)
        }
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
