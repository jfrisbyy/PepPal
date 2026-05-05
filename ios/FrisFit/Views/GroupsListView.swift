import SwiftUI

struct GroupsListView: View {
    @Bindable var viewModel: GroupsViewModel
    @State private var showCreateGroup: Bool = false
    @State private var selectedGroupID: UUID?
    @State private var navigateToGroup: Bool = false
    @State private var selectedSegment: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            editorialHeader
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 12)

            searchField
                .padding(.horizontal)
                .padding(.bottom, 14)

            segmentToggle
                .padding(.horizontal)
                .padding(.bottom, 6)

            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(height: 0.5)

            if selectedSegment == 0 {
                myGroupsList
            } else {
                discoverGroupsList
            }
        }
        .appBackground()
        .navigationTitle("Groups")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateGroup = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(PepTheme.textPrimary)
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

    // MARK: - Editorial Header

    private var editorialHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("THE")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(PepTheme.amber.opacity(0.9))
                Text("—")
                    .font(.system(size: 10))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                Text("COLLECTIVE")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.9))
                Spacer()
            }

            Text("Groups")
                .font(.system(.largeTitle, design: .serif, weight: .regular))
                .foregroundStyle(PepTheme.textPrimary)

            Text("Train together, share protocols, exchange progress.")
                .font(.system(.footnote, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))

            TextField("Search groups", text: $viewModel.searchQuery)
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(height: 0.5)
        }
    }

    // MARK: - Segment Toggle

    private var segmentToggle: some View {
        HStack(spacing: 28) {
            segmentButton(title: "My Groups", number: "01", index: 0)
            segmentButton(title: "Discover", number: "02", index: 1)
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func segmentButton(title: String, number: String, index: Int) -> some View {
        let isActive = selectedSegment == index
        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                selectedSegment = index
            }
        } label: {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Text(number)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle((isActive ? PepTheme.amber : PepTheme.textSecondary).opacity(0.8))
                    Text(title.uppercased())
                        .font(.system(size: 11, weight: isActive ? .bold : .semibold))
                        .tracking(1.6)
                        .foregroundStyle(isActive ? PepTheme.textPrimary : PepTheme.textSecondary.opacity(0.75))
                }

                Rectangle()
                    .fill(isActive ? PepTheme.textPrimary : Color.clear)
                    .frame(height: 1)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selectedSegment)
    }

    // MARK: - My Groups

    private var myGroupsList: some View {
        ScrollView {
            if viewModel.filteredMyGroups.isEmpty {
                editorialEmpty(
                    eyebrow: "EMPTY SHELF",
                    title: "No groups yet",
                    body: "Found a circle, or start your own."
                )
                .padding(.top, 60)
                .padding(.horizontal, 24)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.filteredMyGroups.enumerated()), id: \.element.id) { index, group in
                        Button {
                            selectedGroupID = group.id
                            navigateToGroup = true
                        } label: {
                            myGroupRow(group: group, index: index)
                        }
                        .buttonStyle(.plain)

                        if index < viewModel.filteredMyGroups.count - 1 {
                            Rectangle()
                                .fill(PepTheme.separatorColor)
                                .frame(height: 0.5)
                                .padding(.leading, 60)
                        }
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
        }
        .scrollIndicators(.hidden)
    }

    private func myGroupRow(group: FitGroup, index: Int) -> some View {
        HStack(alignment: .top, spacing: 16) {
            monogramTile(group: group)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(group.name)
                        .font(.system(.title3, design: .serif, weight: .regular))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(1)

                    if group.privacy == .privateGroup {
                        Image(systemName: "lock")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                    }

                    Spacer(minLength: 8)

                    Text(timeAgo(group.lastActivity))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                }

                if let preview = group.lastMessagePreview {
                    Text(preview)
                        .font(.system(.footnote, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary)
                        .lineLimit(2)
                } else {
                    Text("No recent activity")
                        .font(.system(.footnote, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                }

                HStack(spacing: 10) {
                    metaLabel(text: "\(group.memberCount) members")
                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                    metaLabel(text: group.privacy.rawValue.uppercased())
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .contentShape(.rect)
    }

    // MARK: - Discover

    private var discoverGroupsList: some View {
        ScrollView {
            if viewModel.filteredDiscoverGroups.isEmpty {
                editorialEmpty(
                    eyebrow: "NOTHING FOUND",
                    title: "No groups match",
                    body: "Try a broader query, or check back soon."
                )
                .padding(.top, 60)
                .padding(.horizontal, 24)
            } else {
                LazyVStack(spacing: 18) {
                    ForEach(Array(viewModel.filteredDiscoverGroups.enumerated()), id: \.element.id) { index, group in
                        discoverGroupCard(group: group, rank: index + 1)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 40)
            }
        }
        .scrollIndicators(.hidden)
    }

    private func discoverGroupCard(group: FitGroup, rank: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                monogramTile(group: group)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(String(format: "%02d", rank))
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(group.accentColor.opacity(0.9))
                        Text("—")
                            .font(.system(size: 9))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                        Text(group.privacy.rawValue.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.4)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.85))
                    }

                    HStack(spacing: 6) {
                        Text(group.name)
                            .font(.system(.title3, design: .serif, weight: .regular))
                            .foregroundStyle(PepTheme.textPrimary)
                            .lineLimit(1)

                        if group.privacy == .privateGroup {
                            Image(systemName: "lock")
                                .font(.system(size: 10))
                                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                        }
                    }

                    Text("\(group.memberCount) members")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.8))
                        .padding(.top, 2)
                }

                Spacer(minLength: 0)
            }

            Text(group.description)
                .font(.system(.footnote, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(height: 0.5)

            joinAction(for: group)
        }
        .padding(18)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
        )
    }

    private func joinAction(for group: FitGroup) -> some View {
        Group {
            if viewModel.isRequestPending(for: group.id) {
                HStack(spacing: 8) {
                    Text("REQUEST")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.9))
                    Text("—")
                        .font(.system(size: 10))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                    Text("Pending")
                        .font(.system(.subheadline, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                }
                .padding(.vertical, 6)
            } else {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        viewModel.joinGroup(group)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(group.privacy == .privateGroup ? "REQUEST TO JOIN" : "JOIN")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.6)
                            .foregroundStyle(PepTheme.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(PepTheme.textPrimary)
                    }
                    .padding(.vertical, 8)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.myGroups.count)
            }
        }
    }

    // MARK: - Shared bits

    private func monogramTile(group: FitGroup) -> some View {
        let initials = monogram(for: group.name)
        return ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(PepTheme.elevated)
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(group.accentColor.opacity(0.4), lineWidth: 0.6)
            Text(initials)
                .font(.system(.title3, design: .serif, weight: .regular))
                .foregroundStyle(PepTheme.textPrimary)
        }
        .frame(width: 44, height: 44)
    }

    private func monogram(for name: String) -> String {
        let words = name.split(separator: " ").prefix(2)
        let chars = words.compactMap { $0.first }.map { String($0) }
        return chars.joined().uppercased()
    }

    private func metaLabel(text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .tracking(1.0)
            .foregroundStyle(PepTheme.textSecondary.opacity(0.75))
    }

    private func editorialEmpty(eyebrow: String, title: String, body: String) -> some View {
        VStack(alignment: .center, spacing: 12) {
            Text(eyebrow)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.8)
                .foregroundStyle(PepTheme.amber.opacity(0.9))
            Text(title)
                .font(.system(.title2, design: .serif, weight: .regular))
                .foregroundStyle(PepTheme.textPrimary)
                .multilineTextAlignment(.center)
            Text(body)
                .font(.system(.footnote, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
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
