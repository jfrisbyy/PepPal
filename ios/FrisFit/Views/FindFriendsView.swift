import SwiftUI

struct FindFriendsView: View {
    @State private var viewModel: SocialViewModel
    @State private var localQuery: String = ""
    @Environment(\.dismiss) private var dismiss

    init(viewModel: SocialViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.searchResults.isEmpty && localQuery.isEmpty {
                emptyState
            } else if viewModel.searchResults.isEmpty && !localQuery.isEmpty {
                noResultsState
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(viewModel.searchResults) { result in
                            FriendSearchRow(result: result) {
                                viewModel.sendFriendRequest(to: result.id)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .appBackground()
        .navigationTitle("Find Friends")
        .navigationBarTitleDisplayMode(.inline)
        
        .searchable(text: $localQuery, prompt: "Search by name or username")
        .onChange(of: localQuery) { _, newValue in
            viewModel.searchUsers(query: newValue)
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "person.badge.plus",
            title: "Find Your Gym Crew",
            message: "Search by name or username to connect with friends."
        )
    }

    private var noResultsState: some View {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "No Results",
            message: "No one found matching \"\(localQuery)\". Try a different search."
        )
    }
}

private struct FriendSearchRow: View {
    let result: FriendSearchResult
    let onSendRequest: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(result.user.avatarColor.opacity(0.2))
                .frame(width: 48, height: 48)
                .overlay {
                    Text(result.user.avatarInitial)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(result.user.avatarColor)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(result.user.name)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)

                Text("@\(result.user.username)")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)

                if let program = result.user.activeProgramName {
                    Text(program)
                        .font(.caption2)
                        .foregroundStyle(PepTheme.teal.opacity(0.8))
                }
            }

            Spacer()

            switch result.requestStatus {
            case .none:
                Button {
                    onSendRequest()
                } label: {
                    Text("Add")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(PepTheme.teal)
                        .clipShape(.capsule)
                }
                .buttonStyle(.scale)
                .sensoryFeedback(.impact(weight: .light), trigger: result.requestStatus)
            case .pending:
                Text("Pending")
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(PepTheme.elevated)
                    .clipShape(.capsule)
            case .accepted:
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                    Text("Friends")
                        .font(.system(.caption, weight: .medium))
                }
                .foregroundStyle(PepTheme.teal.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(PepTheme.teal.opacity(0.1))
                .clipShape(.capsule)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
