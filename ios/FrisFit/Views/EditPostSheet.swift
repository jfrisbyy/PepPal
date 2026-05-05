import SwiftUI

struct EditPostSheet: View {
    let post: FeedPost
    let viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var textContent: String
    @State private var selectedTags: Set<FeedTag>
    @State private var isSaving: Bool = false

    init(post: FeedPost, viewModel: SocialViewModel) {
        self.post = post
        self.viewModel = viewModel
        self._textContent = State(initialValue: post.textContent)
        self._selectedTags = State(initialValue: Set(post.tags))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("TEXT")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .tracking(0.8)
                    TextEditor(text: $textContent)
                        .font(.body)
                        .foregroundStyle(PepTheme.textPrimary)
                        .frame(minHeight: 140)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .background(PepTheme.elevated)
                        .clipShape(.rect(cornerRadius: 12))

                    Text("TAGS")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .tracking(0.8)
                        .padding(.top, 4)

                    ForEach(TagCategory.allCases) { category in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(category.rawValue)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PepTheme.textSecondary)
                            FlowTagsView(
                                tags: category.tags,
                                selected: $selectedTags
                            )
                        }
                    }
                }
                .padding(16)
            }
            .appBackground()
            .navigationTitle("Edit Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Save").fontWeight(.semibold)
                        }
                    }
                    .disabled(isSaving || textContent.trimmingCharacters(in: .whitespaces).isEmpty)
                    .tint(PepTheme.teal)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        let success = await viewModel.updatePost(
            postID: post.id,
            textContent: textContent.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: Array(selectedTags)
        )
        isSaving = false
        if success { dismiss() }
    }
}

private struct FlowTagsView: View {
    let tags: [FeedTag]
    @Binding var selected: Set<FeedTag>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags) { tag in
                    let isSelected = selected.contains(tag)
                    Button {
                        if isSelected { selected.remove(tag) } else { selected.insert(tag) }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: tag.icon)
                                .font(.system(size: 10))
                            Text(tag.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(isSelected ? PepTheme.invertedText : PepTheme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isSelected ? AnyShapeStyle(PepTheme.teal) : AnyShapeStyle(PepTheme.elevated))
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }
}
