import SwiftUI

struct WorkoutPostCard: View {
    let post: WorkoutPost
    let onHighFive: () -> Void
    let onComment: () -> Void
    var onUserTap: (() -> Void)? = nil

    @State private var highFiveBounce: Int = 0

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Button {
                        onUserTap?()
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(post.user.avatarColor.opacity(0.2))
                                .frame(width: 44, height: 44)
                                .overlay {
                                    Text(post.user.avatarInitial)
                                        .font(.system(.headline, design: .rounded, weight: .bold))
                                        .foregroundStyle(post.user.avatarColor)
                                }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(post.user.name)
                                    .font(.system(.subheadline, weight: .semibold))
                                    .foregroundStyle(PepTheme.textPrimary)

                                Text("@\(post.user.username) · \(post.timestamp.timeAgoDisplay())")
                                    .font(.caption)
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    if let program = post.user.activeProgramName {
                        Text(program)
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(PepTheme.teal)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(PepTheme.teal.opacity(0.1))
                            .clipShape(.capsule)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(post.workoutName)
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)

                    HStack(spacing: 16) {
                        WorkoutStatPill(icon: "clock", value: "\(post.duration)m")
                        WorkoutStatPill(icon: "scalemass", value: "\(formatVolume(post.totalVolume)) lbs")
                        WorkoutStatPill(icon: "dumbbell", value: "\(post.exercisesCompleted)")
                    }
                }

                HStack(spacing: 0) {
                    Image(systemName: "bolt.fill")
                        .font(.caption)
                        .foregroundStyle(PepTheme.teal)
                    Text(" \(post.fpEarned) FP earned")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.teal)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(PepTheme.teal.opacity(0.08))
                .clipShape(.capsule)

                Divider()
                    .overlay(PepTheme.separatorColor)

                HStack(spacing: 24) {
                    Button {
                        onHighFive()
                        highFiveBounce += 1
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: post.isHighFived ? "hand.raised.fill" : "hand.raised")
                                .font(.system(size: 18))
                                .foregroundStyle(post.isHighFived ? PepTheme.amber : PepTheme.textSecondary)
                                .symbolEffect(.bounce, value: highFiveBounce)

                            Text("\(post.highFiveCount)")
                                .font(.system(.subheadline, weight: .medium))
                                .foregroundStyle(post.isHighFived ? PepTheme.amber : PepTheme.textSecondary)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.scale)
                    .sensoryFeedback(.impact(weight: .medium), trigger: highFiveBounce)

                    Button {
                        onComment()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 16))
                            Text("\(post.comments.count)")
                                .font(.system(.subheadline, weight: .medium))
                        }
                        .foregroundStyle(PepTheme.textSecondary)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.scale)
                    .sensoryFeedback(.impact(weight: .light), trigger: post.comments.count)

                    Spacer()
                }
            }
        }
    }

    private func formatVolume(_ volume: Int) -> String {
        if volume >= 1000 {
            let k = Double(volume) / 1000.0
            return String(format: "%.1fk", k)
        }
        return "\(volume)"
    }
}

private struct WorkoutStatPill: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(value)
                .font(.system(.caption, weight: .medium))
        }
        .foregroundStyle(PepTheme.textSecondary)
    }
}

extension Date {
    func timeAgoDisplay() -> String {
        let seconds = Int(-timeIntervalSinceNow)
        if seconds < 60 { return "Just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        if days < 7 { return "\(days)d ago" }
        return "\(days / 7)w ago"
    }

    func formattedPostDate() -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        if calendar.isDateInToday(self) {
            formatter.dateFormat = "h:mm a"
            return "Today, \(formatter.string(from: self))"
        } else if calendar.isDateInYesterday(self) {
            formatter.dateFormat = "h:mm a"
            return "Yesterday, \(formatter.string(from: self))"
        } else if calendar.isDate(self, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "MMM d, h:mm a"
            return formatter.string(from: self)
        } else {
            formatter.dateFormat = "MMM d, yyyy, h:mm a"
            return formatter.string(from: self)
        }
    }
}
