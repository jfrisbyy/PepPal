import SwiftUI

struct GlobalSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm = GlobalSearchViewModel()
    @State private var selectedUser: SocialUser?
    @State private var selectedExercise: Exercise?
    @State private var selectedCompound: CompoundProfile?
    @State private var selectedPostAuthor: SocialUser?
    @State private var profileViewModel = ProfileViewModel()
    @State private var exerciseLibraryVM = ExerciseLibraryViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                scopePicker
                content
            }
            .appBackground()
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $vm.query, prompt: "Search exercises, foods, people…")
            .onChange(of: vm.query) { _, _ in vm.search() }
            .onChange(of: vm.scope) { _, _ in vm.search() }
            .onSubmit(of: .search) { vm.commitRecent() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if vm.isSearching {
                        ProgressView()
                            .controlSize(.small)
                            .tint(PepTheme.teal)
                    }
                }
            }
            .navigationDestination(item: $selectedUser) { user in
                UserProfileView(user: user, viewModel: profileViewModel)
            }
            .navigationDestination(item: $selectedExercise) { ex in
                ExerciseDetailView(exercise: ex, viewModel: exerciseLibraryVM)
            }
            .navigationDestination(item: $selectedCompound) { c in
                CompoundDetailView(compound: c)
            }
            .navigationDestination(item: $selectedPostAuthor) { user in
                UserProfileView(user: user, viewModel: profileViewModel)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.query.trimmingCharacters(in: .whitespaces).isEmpty {
            recentsOrEmpty
        } else if vm.results.isEmpty && !vm.isSearching {
            noResults
        } else {
            resultsList
        }
    }

    private var scopePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(GlobalSearchScope.allCases) { scope in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            vm.scope = scope
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: scope.icon)
                                .font(.system(size: 11))
                            Text(scope.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(vm.scope == scope ? .white : PepTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(vm.scope == scope ? PepTheme.teal : PepTheme.elevated)
                        .clipShape(.capsule)
                    }
                    .sensoryFeedback(.selection, trigger: vm.scope)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private var recentsOrEmpty: some View {
        if vm.recents.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 44))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                Text("Search everything")
                    .font(.headline)
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Exercises, foods, compounds, people, circles, and posts — all in one place.")
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Spacer()
            }
        } else {
            List {
                Section {
                    ForEach(vm.recents, id: \.self) { q in
                        Button {
                            vm.query = q
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 14))
                                    .foregroundStyle(PepTheme.textSecondary)
                                Text(q)
                                    .foregroundStyle(PepTheme.textPrimary)
                                Spacer()
                                Button {
                                    vm.removeRecent(q)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(PepTheme.textSecondary)
                                        .padding(6)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Recent")
                        Spacer()
                        Button("Clear") { vm.clearRecents() }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PepTheme.teal)
                            .textCase(nil)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
    }

    private var noResults: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: vm.scope.emptyIcon)
                .font(.system(size: 42))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
            Text("No results for \"\(vm.query)\"")
                .font(.headline)
                .foregroundStyle(PepTheme.textPrimary)
            Text("Try a different keyword or switch scopes.")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
            Spacer()
        }
    }

    @ViewBuilder
    private var resultsList: some View {
        let grouped = Dictionary(grouping: vm.results, by: { $0.scope })
        let orderedScopes: [GlobalSearchScope] = [.exercises, .foods, .compounds, .users, .circles, .posts]

        List {
            ForEach(orderedScopes, id: \.self) { scope in
                if let items = grouped[scope], !items.isEmpty {
                    Section {
                        ForEach(items) { result in
                            resultRow(result)
                        }
                        if vm.scope == .all && items.count >= 3 {
                            Button {
                                withAnimation { vm.scope = scope }
                            } label: {
                                HStack {
                                    Text("See all in \(scope.rawValue)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(PepTheme.teal)
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(PepTheme.teal)
                                }
                            }
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: scope.icon)
                                .font(.caption2)
                            Text(scope.rawValue)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func resultRow(_ r: GlobalSearchResult) -> some View {
        Button {
            handleTap(r)
        } label: {
            HStack(spacing: 12) {
                iconBadge(for: r)
                VStack(alignment: .leading, spacing: 2) {
                    Text(r.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(1)
                    Text(r.subtitle)
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func iconBadge(for r: GlobalSearchResult) -> some View {
        switch r {
        case .user(let u):
            ZStack {
                Circle().fill(u.avatarColor)
                Text(u.avatarInitial)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 32, height: 32)
        case .post(_, _, let author, _, _):
            ZStack {
                Circle().fill(author.avatarColor)
                Text(author.avatarInitial)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 32, height: 32)
        case .circle(let c):
            Image(systemName: "person.3.fill")
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(c.accentColor)
                .clipShape(.rect(cornerRadius: 8))
        default:
            Image(systemName: r.icon)
                .font(.system(size: 14))
                .foregroundStyle(PepTheme.teal)
                .frame(width: 32, height: 32)
                .background(PepTheme.teal.opacity(0.12))
                .clipShape(.rect(cornerRadius: 8))
        }
    }

    private func handleTap(_ r: GlobalSearchResult) {
        vm.commitRecent()
        switch r {
        case .exercise(let e):
            selectedExercise = e
        case .compound(let c):
            selectedCompound = c
        case .user(let u):
            selectedUser = u
        case .post(_, _, let author, _, _):
            selectedPostAuthor = author
        case .circle:
            break
        case .food:
            break
        }
    }
}
