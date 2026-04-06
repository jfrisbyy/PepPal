import SwiftUI

struct GroupsListView: View {
    @Bindable var viewModel: GroupsViewModel
    @State private var showCreateGroup: Bool = false
    @State private var selectedGroupID: UUID?
    @State private var navigateToGroup: Bool = false
    @State private var selectedSegment: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

            segmentPicker
                .padding(.horizontal)
                .padding(.vertical, 8)

            if selectedSegment == 0 {
                myGroupsList
            } else {
                discoverGroupsList
            }
        }
        .background(PepTheme.background.ignoresSafeArea())
        .navigationTitle("Groups")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateGroup = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(PepTheme.teal)
                }
                .sensoryFeedback(.impact(weight: .light), trigger: showCreateGroup)
            }
        }
        .sheet(isPresented: $showCreateGroup) {
            CreateGroupSheet(viewModel: viewModel)
        }
        .navigationDestination(isPresented: $navigateToGroup) {
            if let id = selectedGroupID {
                GroupDetailView(viewModel: viewModel, groupID: id)
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)

            TextField("Search groups...", text: $viewModel.searchQuery)
                .font(.subheadline)
                .foregroundStyle(PepTheme.textPrimary)

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(PepTheme.elevated)
        .clipShape(.capsule)
    }

    private var segmentPicker: some View {
        HStack(spacing: 0) {
            segmentButton(title: "My Groups", index: 0)
            segmentButton(title: "Discover", index: 1)
        }
        .background(PepTheme.elevated)
        .clipShape(.capsule)
    }

    private func segmentButton(title: String, index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedSegment = index
            }
        } label: {
            Text(title)
                .font(.system(.subheadline, weight: selectedSegment == index ? .bold : .medium))
                .foregroundStyle(selectedSegment == index ? PepTheme.invertedText : PepTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selectedSegment == index ? PepTheme.teal : .clear)
                .clipShape(.capsule)
        }
        .sensoryFeedback(.selection, trigger: selectedSegment)
    }

    private var myGroupsList: some View {
        ScrollView {
            if viewModel.filteredMyGroups.isEmpty {
                EmptyStateView(
                    icon: "person.3",
                    title: "No Groups Yet",
                    message: "Create a group or discover existing ones to join.",
                    actionTitle: "Create Group"
                )
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.filteredMyGroups) { group in
                        Button {
                            selectedGroupID = group.id
                            navigateToGroup = true
                        } label: {
                            groupCard(group: group)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .scrollIndicators(.hidden)
    }

    private var discoverGroupsList: some View {
        ScrollView {
            if viewModel.filteredDiscoverGroups.isEmpty {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: "No Groups Found",
                    message: "Check back later for new groups to join."
                )
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.filteredDiscoverGroups) { group in
                        discoverGroupCard(group: group)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .scrollIndicators(.hidden)
    }

    private func groupCard(group: FitGroup) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(group.accentColor.opacity(0.15))
                    .frame(width: 52, height: 52)

                Image(systemName: group.iconName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(group.accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(group.name)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(1)

                    if group.privacy == .privateGroup {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }

                if let preview = group.lastMessagePreview {
                    Text(preview)
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                        .lineLimit(1)
                } else {
                    Text("\(group.memberCount) members")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(timeAgo(group.lastActivity))
                    .font(.caption2)
                    .foregroundStyle(PepTheme.textSecondary)

                HStack(spacing: 2) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 9))
                    Text("\(group.memberCount)")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .padding(14)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
        )
    }

    private func discoverGroupCard(group: FitGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(group.accentColor.opacity(0.15))
                        .frame(width: 52, height: 52)

                    Image(systemName: group.iconName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(group.accentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(group.name)
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)

                        if group.privacy == .privateGroup {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }

                    HStack(spacing: 8) {
                        HStack(spacing: 3) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 10))
                            Text("\(group.memberCount)")
                                .font(.caption)
                        }
                        .foregroundStyle(PepTheme.textSecondary)

                        Text("·")
                            .foregroundStyle(PepTheme.textSecondary)

                        Text(group.privacy.rawValue)
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }

                Spacer()
            }

            Text(group.description)
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
                .lineLimit(2)

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    viewModel.joinGroup(group)
                }
            } label: {
                Text(group.privacy == .privateGroup ? "Request to Join" : "Join Group")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.invertedText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(group.accentColor)
                    .clipShape(.capsule)
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.myGroups.count)
        }
        .padding(14)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
        )
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "now" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        if interval < 604800 { return "\(Int(interval / 86400))d" }
        return "\(Int(interval / 604800))w"
    }
}
