import SwiftUI

nonisolated struct MentionSuggestion: Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    let username: String
    let avatarInitial: String
}

nonisolated struct HashtagSuggestion: Identifiable, Hashable, Sendable {
    var id: String { tag }
    let tag: String
    let postCount: Int
}

@Observable
final class MentionHashtagSuggestionController {
    var activeTrigger: Character?
    var activeQuery: String = ""
    var activeRange: Range<String.Index>?
    var mentionResults: [MentionSuggestion] = []
    var hashtagResults: [HashtagSuggestion] = []
    private var searchTask: Task<Void, Never>?

    var isActive: Bool { activeTrigger != nil }

    func handleTextChange(_ text: String, caret: Int) {
        guard let info = RichTextParser.activeAutocompleteQuery(in: text, caret: caret) else {
            reset()
            return
        }
        activeTrigger = info.trigger
        activeQuery = info.query
        activeRange = info.range
        searchTask?.cancel()
        let trig = info.trigger
        let q = info.query
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            await self?.performSearch(trigger: trig, query: q)
        }
    }

    func reset() {
        activeTrigger = nil
        activeQuery = ""
        activeRange = nil
        mentionResults = []
        hashtagResults = []
        searchTask?.cancel()
    }

    func insertMention(_ suggestion: MentionSuggestion, into text: inout String) {
        guard let range = activeRange else { return }
        let replacement = "@\(suggestion.username) "
        text.replaceSubrange(range, with: replacement)
        reset()
    }

    func insertHashtag(_ suggestion: HashtagSuggestion, into text: inout String) {
        guard let range = activeRange else { return }
        let replacement = "#\(suggestion.tag) "
        text.replaceSubrange(range, with: replacement)
        reset()
    }

    private func performSearch(trigger: Character, query: String) async {
        if trigger == "@" {
            await searchUsers(query: query)
        } else {
            await searchTags(query: query)
        }
    }

    private func searchUsers(query: String) async {
        do {
            let userId = try AuthService.shared.currentUserId()
            let q = query.isEmpty ? "a" : query
            let profiles = try await MessagingService.shared.searchUsers(query: q, excludeUserId: userId)
            let results = profiles.prefix(8).map { p in
                MentionSuggestion(
                    id: p.id,
                    displayName: p.display_name ?? p.username ?? "User",
                    username: p.username ?? "user",
                    avatarInitial: String((p.display_name ?? p.username ?? "U").prefix(1)).uppercased()
                )
            }
            mentionResults = Array(results)
        } catch {
            mentionResults = []
        }
    }

    private func searchTags(query: String) async {
        let q = query.lowercased()
        var suggestions: [HashtagSuggestion] = FeedTag.allCases
            .filter { q.isEmpty || $0.rawValue.lowercased().contains(q) }
            .map { HashtagSuggestion(tag: $0.rawValue.lowercased().replacingOccurrences(of: " ", with: "-"), postCount: 0) }

        do {
            let page = try await SocialService.shared.fetchPostsPage(before: nil, pageSize: 40)
            var counts: [String: Int] = [:]
            for sp in page {
                for t in (sp.tags ?? []) { counts[t.lowercased(), default: 0] += 1 }
                for h in RichTextParser.extractHashtags(sp.text_content ?? "") { counts[h, default: 0] += 1 }
            }
            let matching = counts
                .filter { q.isEmpty || $0.key.contains(q) }
                .sorted { $0.value > $1.value }
                .map { HashtagSuggestion(tag: $0.key, postCount: $0.value) }
            var seen = Set<String>()
            var combined: [HashtagSuggestion] = []
            for s in matching + suggestions where !seen.contains(s.tag) {
                seen.insert(s.tag)
                combined.append(s)
            }
            hashtagResults = Array(combined.prefix(8))
        } catch {
            hashtagResults = Array(suggestions.prefix(8))
        }
    }
}

struct MentionHashtagSuggestionView: View {
    @Bindable var controller: MentionHashtagSuggestionController
    let onPickMention: (MentionSuggestion) -> Void
    let onPickHashtag: (HashtagSuggestion) -> Void

    var body: some View {
        Group {
            if controller.activeTrigger == "@" {
                if controller.mentionResults.isEmpty {
                    emptyRow("No people match")
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(controller.mentionResults) { s in
                                Button { onPickMention(s) } label: { mentionRow(s) }
                                    .buttonStyle(.plain)
                                Divider().overlay(PepTheme.separatorColor.opacity(0.4))
                            }
                        }
                    }
                }
            } else if controller.activeTrigger == "#" {
                if controller.hashtagResults.isEmpty {
                    emptyRow("Type to create a new tag")
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(controller.hashtagResults) { s in
                                Button { onPickHashtag(s) } label: { hashtagRow(s) }
                                    .buttonStyle(.plain)
                                Divider().overlay(PepTheme.separatorColor.opacity(0.4))
                            }
                        }
                    }
                }
            }
        }
        .frame(maxHeight: 220)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(PepTheme.separatorColor),
            alignment: .top
        )
    }

    private func mentionRow(_ s: MentionSuggestion) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(PepTheme.teal.opacity(0.2))
                .frame(width: 34, height: 34)
                .overlay {
                    Text(s.avatarInitial)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.teal)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(s.displayName)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("@\(s.username)")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(.rect)
    }

    private func hashtagRow(_ s: HashtagSuggestion) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(PepTheme.teal.opacity(0.18))
                    .frame(width: 34, height: 34)
                Image(systemName: "number")
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(PepTheme.teal)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("#\(s.tag)")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                if s.postCount > 0 {
                    Text("\(s.postCount) post\(s.postCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                } else {
                    Text("New tag")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(.rect)
    }

    private func emptyRow(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }
}
