import SwiftUI

struct ModerationSettingsView: View {
    @State private var moderation = LocalModerationStore.shared
    @State private var newKeyword: String = ""
    @State private var blockedProfiles: [SocialUser] = []
    @State private var mutedProfiles: [SocialUser] = []
    @State private var isLoadingBlocks: Bool = false
    @FocusState private var keywordFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                summaryCard

                keywordsCard
                mutedTagsCard
                mutedUsersCard
                blockedUsersCard
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
            .padding(.top, 8)
        }
        .appBackground()
        .navigationTitle("Moderation & Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadProfiles() }
    }

    private var summaryCard: some View {
        HStack(spacing: 12) {
            summaryStat(value: moderation.mutedUserIds.count + blockedProfiles.count, label: "Users", icon: "person.slash.fill", color: PepTheme.violet)
            summaryStat(value: moderation.mutedTags.count, label: "Tags", icon: "number", color: PepTheme.teal)
            summaryStat(value: moderation.keywordFilters.count, label: "Keywords", icon: "character.textbox", color: .orange)
        }
    }

    private func summaryStat(value: Int, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
            Text("\(value)")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
    }

    private var keywordsCard: some View {
        sectionCard(title: "Keyword Filters", subtitle: "Hide posts, comments, or messages containing these words.") {
            HStack(spacing: 8) {
                TextField("Add a word or phrase", text: $newKeyword)
                    .font(.subheadline)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($keywordFocused)
                    .submitLabel(.done)
                    .onSubmit { addKeyword() }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(PepTheme.elevated)
                    .clipShape(.capsule)

                Button(action: addKeyword) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(newKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? PepTheme.textSecondary.opacity(0.4) : PepTheme.teal)
                }
                .disabled(newKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if moderation.keywordFilters.isEmpty {
                emptyRow("No filters yet")
            } else {
                ModerationFlowLayout(spacing: 6) {
                    ForEach(moderation.keywordFilters, id: \.self) { kw in
                        keywordChip(kw)
                    }
                }
            }
        }
    }

    private func keywordChip(_ word: String) -> some View {
        HStack(spacing: 6) {
            Text(word)
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
            Button {
                withAnimation(.spring(response: 0.25)) {
                    moderation.removeKeyword(word)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(PepTheme.elevated)
        .clipShape(.capsule)
    }

    private var mutedTagsCard: some View {
        sectionCard(title: "Muted Tags", subtitle: "Hide posts with these hashtags.") {
            if moderation.mutedTags.isEmpty {
                emptyRow("No muted tags")
            } else {
                ModerationFlowLayout(spacing: 6) {
                    ForEach(Array(moderation.mutedTags).sorted(), id: \.self) { tag in
                        HStack(spacing: 6) {
                            Text("#\(tag)")
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(PepTheme.teal)
                            Button {
                                withAnimation(.spring(response: 0.25)) {
                                    moderation.unmuteTag(tag)
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(PepTheme.teal.opacity(0.12))
                        .clipShape(.capsule)
                    }
                }
            }
        }
    }

    private var mutedUsersCard: some View {
        sectionCard(title: "Muted Users", subtitle: "Their posts and comments are hidden. They aren't notified.") {
            if moderation.mutedUserIds.isEmpty {
                emptyRow("No muted users")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(moderation.mutedUserIds).sorted(), id: \.self) { userId in
                        userRow(
                            profile: mutedProfiles.first(where: { $0.id.uuidString.lowercased() == userId }),
                            fallbackId: userId,
                            actionLabel: "Unmute"
                        ) {
                            withAnimation(.spring(response: 0.25)) {
                                moderation.unmuteUser(userId)
                            }
                        }
                        if userId != Array(moderation.mutedUserIds).sorted().last {
                            Divider().overlay(PepTheme.separatorColor.opacity(0.5))
                        }
                    }
                }
            }
        }
    }

    private var blockedUsersCard: some View {
        sectionCard(title: "Blocked Users", subtitle: "You won't see their posts, comments, or messages.") {
            if isLoadingBlocks {
                ProgressView().tint(PepTheme.teal).padding(.vertical, 8)
            } else if blockedProfiles.isEmpty {
                emptyRow("No blocked users")
            } else {
                VStack(spacing: 0) {
                    ForEach(blockedProfiles) { user in
                        userRow(
                            profile: user,
                            fallbackId: user.id.uuidString.lowercased(),
                            actionLabel: "Unblock"
                        ) {
                            Task {
                                do {
                                    let myId = try AuthService.shared.currentUserId()
                                    try await ModerationService.shared.unblock(blockerId: myId, blockedId: user.id.uuidString)
                                    withAnimation(.spring(response: 0.25)) {
                                        blockedProfiles.removeAll { $0.id == user.id }
                                    }
                                } catch {}
                            }
                        }
                        if user.id != blockedProfiles.last?.id {
                            Divider().overlay(PepTheme.separatorColor.opacity(0.5))
                        }
                    }
                }
            }
        }
    }

    private func userRow(profile: SocialUser?, fallbackId: String, actionLabel: String, onAction: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill((profile?.avatarColor ?? PepTheme.textSecondary).opacity(0.2))
                .frame(width: 38, height: 38)
                .overlay {
                    Text(profile?.avatarInitial ?? String(fallbackId.prefix(1)).uppercased())
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(profile?.avatarColor ?? PepTheme.textSecondary)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(profile?.name ?? "User")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)
                Text(profile.map { "@\($0.username)" } ?? fallbackId.prefix(12) + "…")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onAction) {
                Text(actionLabel)
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(PepTheme.teal)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(PepTheme.teal.opacity(0.12))
                    .clipShape(.capsule)
            }
        }
        .padding(.vertical, 10)
    }

    private func sectionCard<Content: View>(title: String, subtitle: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 16))
    }

    private func emptyRow(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private func addKeyword() {
        let trimmed = newKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation(.spring(response: 0.3)) {
            moderation.addKeyword(trimmed)
            newKeyword = ""
        }
    }

    private func loadProfiles() async {
        isLoadingBlocks = true
        defer { isLoadingBlocks = false }
        do {
            let myId = try AuthService.shared.currentUserId()
            let blockedIds = try await ModerationService.shared.blockedUserIds(blockerId: myId)
            var profiles: [SocialUser] = []
            for id in blockedIds {
                if let p = try? await MessagingService.shared.fetchProfile(userId: id) {
                    profiles.append(MessagingService.shared.socialUserFromAuthor(p))
                }
            }
            blockedProfiles = profiles

            var muted: [SocialUser] = []
            for id in moderation.mutedUserIds {
                if let p = try? await MessagingService.shared.fetchProfile(userId: id) {
                    muted.append(MessagingService.shared.socialUserFromAuthor(p))
                }
            }
            mutedProfiles = muted
        } catch {}
    }
}

// MARK: - Simple flow layout for chips

struct ModerationFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
