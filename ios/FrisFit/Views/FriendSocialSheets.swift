import SwiftUI

struct ReactionPickerSheet: View {
    let target: ReactionTarget
    @Environment(\.dismiss) private var dismiss

    private let social = FriendSocialService.shared

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 2) {
                Text("React to \(target.friendName)'s")
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
                Text(target.statLabel)
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
            }

            HStack(spacing: 14) {
                ForEach(StatReactionEmoji.allCases) { emoji in
                    Button {
                        social.addReaction(friendId: target.friendId, target: "streak", emoji: emoji)
                        dismiss()
                    } label: {
                        Text(emoji.rawValue)
                            .font(.system(size: 36))
                            .frame(width: 56, height: 56)
                            .background(PepTheme.elevated, in: Circle())
                    }
                    .buttonStyle(.scale)
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct NudgeMenuSheet: View {
    let friend: FriendStatSnapshot
    @Environment(\.dismiss) private var dismiss
    @State private var sentKind: NudgeKind?
    @State private var showCooldown: Bool = false

    private let social = FriendSocialService.shared

    private var cooldown: TimeInterval? {
        social.nudgeCooldownRemaining(for: friend.id.uuidString)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if let cooldown {
                        cooldownBanner(remaining: cooldown)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        SectionEyebrow("Choose a Nudge", number: "01", accent: PepTheme.teal)
                        VStack(spacing: 0) {
                            ForEach(Array(NudgeKind.allCases.enumerated()), id: \.element.id) { idx, kind in
                                nudgeRow(kind)
                                if idx < NudgeKind.allCases.count - 1 {
                                    Rectangle().fill(PepTheme.separatorColor).frame(height: 0.5)
                                }
                            }
                        }
                        .overlay(alignment: .top) { Rectangle().fill(PepTheme.separatorColor).frame(height: 0.5) }
                        .overlay(alignment: .bottom) { Rectangle().fill(PepTheme.separatorColor).frame(height: 0.5) }
                    }

                    footnote
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Nudge \(friend.user.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PepTheme.textPrimary)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(PepTheme.elevated)
                    .frame(width: 52, height: 52)
                Circle()
                    .strokeBorder(PepTheme.separatorColor, lineWidth: 0.75)
                    .frame(width: 52, height: 52)
                if let url = friend.user.avatarURL, let u = URL(string: url) {
                    AsyncImage(url: u) { img in img.resizable().aspectRatio(contentMode: .fill) } placeholder: {
                        Text(friend.user.avatarInitial).font(.system(.headline, design: .serif)).foregroundStyle(PepTheme.textPrimary)
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(.circle)
                } else {
                    Text(friend.user.avatarInitial).font(.system(.headline, design: .serif)).foregroundStyle(PepTheme.textPrimary)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("FOR \(friend.user.name.uppercased())")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(PepTheme.textSecondary)
                Text("Send a quick nudge")
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("One tap. A friendly push lands on their phone.")
                    .font(.system(.caption, design: .serif).italic())
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func nudgeRow(_ kind: NudgeKind) -> some View {
        let sent = sentKind == kind
        let disabled = cooldown != nil || sent
        return Button {
            guard !disabled else { return }
            if social.sendNudge(to: friend.id.uuidString, kind: kind) {
                sentKind = kind
                Task {
                    try? await Task.sleep(for: .seconds(0.9))
                    dismiss()
                }
            } else {
                showCooldown = true
            }
        } label: {
            HStack(spacing: 14) {
                Rectangle()
                    .fill(kind.color.opacity(0.7))
                    .frame(width: 2, height: 36)
                VStack(alignment: .leading, spacing: 3) {
                    Text(kind.title)
                        .font(.system(size: 17, weight: .regular, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(kind.body)
                        .font(.system(.caption, design: .serif).italic())
                        .foregroundStyle(PepTheme.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                if sent {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(PepTheme.teal)
                        .transition(.opacity)
                } else {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled && !sent ? 0.55 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: sent)
    }

    private func cooldownBanner(remaining: TimeInterval) -> some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(PepTheme.amber)
                .frame(width: 2, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text("NUDGE SENT RECENTLY")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Try again in \(formatCooldown(remaining)) so it doesn't feel spammy.")
                    .font(.system(.caption, design: .serif).italic())
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
    }

    private var footnote: some View {
        Text("Limited to one nudge every 6 hours per friend.")
            .font(.system(.caption2, design: .serif).italic())
            .foregroundStyle(PepTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
    }

    private func formatCooldown(_ t: TimeInterval) -> String {
        let hours = Int(t) / 3600
        let minutes = (Int(t) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
