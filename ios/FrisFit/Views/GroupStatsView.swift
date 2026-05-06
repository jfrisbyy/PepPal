import SwiftUI

struct GroupStatsView: View {
    @Bindable var viewModel: GroupsViewModel
    let groupID: UUID

    @State private var selectedMetric: GroupStatMetric?
    @State private var showAdminSheet: Bool = false
    @State private var showSharingInfo: Bool = false

    private var group: FitGroup? {
        viewModel.group(for: groupID)
    }

    private var isAdmin: Bool {
        viewModel.isCurrentUserAdmin(groupID: groupID)
    }

    private var primaryMetric: GroupStatMetric? {
        selectedMetric ?? group?.statsConfig.enabledMetrics.sorted(by: { $0.rawValue < $1.rawValue }).first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if let group {
                    if !group.statsConfig.isEnabled {
                        disabledState(group)
                    } else if group.statsConfig.enabledMetrics.isEmpty {
                        emptyMetricsState(group)
                    } else {
                        enabledContent(group)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 60)
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .sheet(isPresented: $showAdminSheet) {
            GroupStatsAdminSheet(viewModel: viewModel, groupID: groupID)
        }
        .sheet(isPresented: $showSharingInfo) {
            GroupStatsMySharingSheet(viewModel: viewModel, groupID: groupID)
        }
    }

    // MARK: - States

    private func disabledState(_ group: FitGroup) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("STATS SHARING")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(group.accentColor.opacity(0.9))

            Text("Quiet for now.")
                .font(.system(size: 30, weight: .regular, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)

            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(height: 0.6)
                .padding(.vertical, 4)

            Text("This group hasn't turned on member stats. When admins enable it, training data the group cares about — steps, runs, workouts — will show up here.")
                .font(.system(size: 14))
                .foregroundStyle(PepTheme.textSecondary)
                .lineSpacing(3)

            if isAdmin {
                Button {
                    showAdminSheet = true
                } label: {
                    Text("Configure stats")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(1.6)
                        .textCase(.uppercase)
                        .foregroundStyle(PepTheme.invertedText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(PepTheme.textPrimary))
                }
                .padding(.top, 12)
            }
        }
        .padding(.top, 24)
    }

    private func emptyMetricsState(_ group: FitGroup) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionEyebrow("No Metrics", number: "—", accent: group.accentColor)
            Text("Pick what to track.")
                .font(.system(size: 24, weight: .regular, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
            Text("Stats are enabled but no metrics have been chosen yet.")
                .font(.system(size: 14))
                .foregroundStyle(PepTheme.textSecondary)
            if isAdmin {
                Button {
                    showAdminSheet = true
                } label: {
                    Text("Choose metrics")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(1.6)
                        .textCase(.uppercase)
                        .foregroundStyle(PepTheme.invertedText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(PepTheme.textPrimary))
                }
                .padding(.top, 8)
            }
        }
        .padding(.top, 24)
    }

    @ViewBuilder
    private func enabledContent(_ group: FitGroup) -> some View {
        header(group)
        periodAndMetricSelector(group)

        if let metric = primaryMetric {
            leaderboard(group: group, metric: metric)
        }

        myParticipationCard(group)

        if isAdmin {
            adminFooter(group)
        }
    }

    // MARK: - Header

    private func header(_ group: FitGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("MEMBER STATS")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(group.accentColor.opacity(0.9))
                Spacer()
                if isAdmin {
                    Button {
                        showAdminSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 11, weight: .regular))
                            Text("Manage")
                                .font(.system(size: 11, weight: .medium))
                                .tracking(0.4)
                        }
                        .foregroundStyle(PepTheme.textSecondary)
                    }
                }
            }

            Text(headerLine(group))
                .font(.system(size: 28, weight: .regular, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(height: 0.6)
        }
    }

    private func headerLine(_ group: FitGroup) -> String {
        let count = activeContributors(group)
        let total = group.members.count
        return "\(count) of \(total) members\nshared \(group.statsConfig.period.rawValue.lowercased())."
    }

    // MARK: - Period + metric selector

    private func periodAndMetricSelector(_ group: FitGroup) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 0) {
                ForEach(GroupStatsPeriod.allCases) { period in
                    Button {
                        viewModel.setStatsPeriod(groupID: groupID, period: period)
                    } label: {
                        VStack(spacing: 6) {
                            Text(period.shortLabel.uppercased())
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(1.4)
                                .foregroundStyle(group.statsConfig.period == period ? PepTheme.textPrimary : PepTheme.textSecondary.opacity(0.8))
                            Rectangle()
                                .fill(group.statsConfig.period == period ? PepTheme.textPrimary : Color.clear)
                                .frame(height: 1)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(group.statsConfig.enabledMetrics).sorted(by: { $0.rawValue < $1.rawValue })) { metric in
                        let isActive = (primaryMetric == metric)
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                selectedMetric = metric
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: metric.icon)
                                    .font(.system(size: 11, weight: .regular))
                                Text(metric.shortLabel)
                                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                            }
                            .foregroundStyle(isActive ? PepTheme.textPrimary : PepTheme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .overlay(
                                Capsule()
                                    .stroke(isActive ? PepTheme.textPrimary.opacity(0.6) : PepTheme.separatorColor, lineWidth: 0.6)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .contentMargins(.horizontal, 0)
        }
    }

    // MARK: - Leaderboard

    private func leaderboard(group: FitGroup, metric: GroupStatMetric) -> some View {
        let sharing = group.members.filter { $0.isSharingStats }
        let ranked = sharing.sorted { $0.stats.value(for: metric) > $1.stats.value(for: metric) }
        let max = ranked.first?.stats.value(for: metric) ?? 1

        return VStack(alignment: .leading, spacing: 14) {
            SectionEyebrow(metric.rawValue, number: "01", accent: group.accentColor) {
                Text(group.statsConfig.period.shortLabel.uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(PepTheme.textTertiary)
            }

            VStack(spacing: 0) {
                ForEach(Array(ranked.enumerated()), id: \.element.id) { idx, member in
                    leaderboardRow(
                        rank: idx + 1,
                        member: member,
                        metric: metric,
                        max: max == 0 ? 1 : max,
                        accent: group.accentColor
                    )
                    if idx < ranked.count - 1 {
                        Divider().overlay(PepTheme.separatorColor)
                    }
                }
            }
        }
    }

    private func leaderboardRow(rank: Int, member: GroupMember, metric: GroupStatMetric, max: Double, accent: Color) -> some View {
        let value = member.stats.value(for: metric)
        let pct = max > 0 ? value / max : 0
        let isMe = member.user.username == "me"

        return HStack(alignment: .center, spacing: 14) {
            Text(String(format: "%02d", rank))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(rank <= 3 ? accent : PepTheme.textTertiary)
                .frame(width: 22, alignment: .leading)

            Circle()
                .fill(member.user.avatarColor.opacity(0.18))
                .frame(width: 32, height: 32)
                .overlay {
                    Text(member.user.avatarInitial)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(member.user.avatarColor)
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(isMe ? "You" : member.user.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    if isMe {
                        Text("· you")
                            .font(.system(size: 11))
                            .foregroundStyle(PepTheme.textTertiary)
                    }
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(PepTheme.separatorColor.opacity(0.6))
                            .frame(height: 3)
                        Capsule()
                            .fill(accent.opacity(0.85))
                            .frame(width: proxy.size.width * CGFloat(pct), height: 3)
                    }
                }
                .frame(height: 3)
            }

            VStack(alignment: .trailing, spacing: 1) {
                Text(metric.format(value))
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(metric.unit.uppercased())
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(PepTheme.textTertiary)
            }
            .frame(width: 76, alignment: .trailing)
        }
        .padding(.vertical, 14)
    }

    // MARK: - My participation

    private func myParticipationCard(_ group: FitGroup) -> some View {
        let me = group.members.first { $0.user.username == "me" }
        let isSharing = me?.isSharingStats ?? true

        return VStack(alignment: .leading, spacing: 12) {
            SectionEyebrow("Your Sharing", number: "02", accent: group.accentColor)

            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isSharing ? "Visible to the group" : "Hidden from the group")
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(isSharing
                        ? "Your data shows on the leaderboard for the metrics enabled here."
                        : "You're paused. The group can't see your numbers in this room.")
                        .font(.system(size: 12))
                        .foregroundStyle(PepTheme.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Toggle("", isOn: Binding(
                    get: { isSharing },
                    set: { _ in viewModel.toggleMyStatsSharing(groupID: groupID) }
                ))
                .labelsHidden()
                .tint(group.accentColor)
            }
            .padding(.vertical, 14)

            Button {
                showSharingInfo = true
            } label: {
                Text("What gets shared")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
    }

    private func adminFooter(_ group: FitGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(height: 0.6)

            HStack {
                Text("Admin tools")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundStyle(PepTheme.textTertiary)
                Spacer()
                Button {
                    showAdminSheet = true
                } label: {
                    Text("Manage")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(group.accentColor)
                }
            }
            .padding(.top, 4)
        }
        .padding(.top, 12)
    }

    private func activeContributors(_ group: FitGroup) -> Int {
        group.members.filter { $0.isSharingStats }.count
    }
}

// MARK: - Admin sheet

struct GroupStatsAdminSheet: View {
    @Bindable var viewModel: GroupsViewModel
    let groupID: UUID
    @Environment(\.dismiss) private var dismiss

    private var group: FitGroup? {
        viewModel.group(for: groupID)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let group {
                    VStack(alignment: .leading, spacing: 26) {
                        hero(group)

                        VStack(alignment: .leading, spacing: 12) {
                            SectionEyebrow("Sharing", number: "01", accent: group.accentColor)

                            HStack(alignment: .top, spacing: 14) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Member stats")
                                        .font(.system(.subheadline, weight: .semibold))
                                        .foregroundStyle(PepTheme.textPrimary)
                                    Text(group.statsConfig.isEnabled
                                        ? "On — chosen metrics appear in the Stats tab."
                                        : "Off — only chat is visible to members.")
                                        .font(.caption2)
                                        .foregroundStyle(PepTheme.textSecondary)
                                }
                                Spacer(minLength: 8)
                                Toggle("", isOn: Binding(
                                    get: { group.statsConfig.isEnabled },
                                    set: { _ in viewModel.toggleStatsEnabled(groupID: groupID) }
                                ))
                                .labelsHidden()
                                .tint(group.accentColor)
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(PepTheme.separatorColor, lineWidth: 0.6)
                            )
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            SectionEyebrow("Window", number: "02", accent: group.accentColor)
                            HStack(spacing: 8) {
                                ForEach(GroupStatsPeriod.allCases) { period in
                                    let active = group.statsConfig.period == period
                                    Button {
                                        viewModel.setStatsPeriod(groupID: groupID, period: period)
                                    } label: {
                                        Text(period.rawValue)
                                            .font(.system(size: 12, weight: active ? .semibold : .regular))
                                            .foregroundStyle(active ? PepTheme.textPrimary : PepTheme.textSecondary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 11)
                                            .overlay(
                                                Capsule()
                                                    .stroke(active ? PepTheme.textPrimary.opacity(0.6) : PepTheme.separatorColor, lineWidth: 0.6)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!group.statsConfig.isEnabled)
                                    .opacity(group.statsConfig.isEnabled ? 1 : 0.5)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 0) {
                            SectionEyebrow("Metrics", number: "03", accent: group.accentColor)
                                .padding(.bottom, 6)

                            ForEach(Array(GroupStatMetric.allCases.enumerated()), id: \.element.id) { idx, metric in
                                let on = group.statsConfig.enabledMetrics.contains(metric)
                                Button {
                                    viewModel.toggleStatsMetric(groupID: groupID, metric: metric)
                                } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: metric.icon)
                                            .font(.system(size: 14))
                                            .foregroundStyle(on ? group.accentColor : PepTheme.textTertiary)
                                            .frame(width: 22)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(metric.rawValue)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(PepTheme.textPrimary)
                                            Text(metric.unit)
                                                .font(.caption2)
                                                .foregroundStyle(PepTheme.textSecondary)
                                        }
                                        Spacer()
                                        Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 18))
                                            .foregroundStyle(on ? group.accentColor : PepTheme.textTertiary.opacity(0.6))
                                    }
                                    .padding(.vertical, 14)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .disabled(!group.statsConfig.isEnabled)
                                .opacity(group.statsConfig.isEnabled ? 1 : 0.55)

                                if idx < GroupStatMetric.allCases.count - 1 {
                                    Divider().overlay(PepTheme.separatorColor)
                                }
                            }
                        }

                        Text("Members can pause their own sharing at any time. Data only appears here for members who keep sharing on.")
                            .font(.system(size: 12))
                            .foregroundStyle(PepTheme.textSecondary)
                            .lineSpacing(2)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("MANAGE STATS")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.8)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PepTheme.textPrimary)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func hero(_ group: FitGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ADMIN")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(group.accentColor.opacity(0.9))
            Text("Decide what the group\nshares together.")
                .font(.system(size: 26, weight: .regular, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(height: 0.6)
                .padding(.top, 4)
            Text("Pick the metrics that fit \(group.name)'s vibe — for a run club it might be miles and active minutes, for a lift crew it could be workouts and volume.")
                .font(.system(size: 13))
                .foregroundStyle(PepTheme.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - My sharing info sheet

struct GroupStatsMySharingSheet: View {
    @Bindable var viewModel: GroupsViewModel
    let groupID: UUID
    @Environment(\.dismiss) private var dismiss

    private var group: FitGroup? {
        viewModel.group(for: groupID)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let group {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("WHAT GETS SHARED")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .tracking(2)
                                .foregroundStyle(group.accentColor.opacity(0.9))
                            Text("Only the metrics this\ngroup turned on.")
                                .font(.system(size: 26, weight: .regular, design: .serif))
                                .foregroundStyle(PepTheme.textPrimary)
                                .lineSpacing(2)
                            Rectangle()
                                .fill(PepTheme.separatorColor)
                                .frame(height: 0.6)
                                .padding(.top, 4)
                        }

                        VStack(alignment: .leading, spacing: 0) {
                            SectionEyebrow("Currently Visible", number: "01", accent: group.accentColor)
                                .padding(.bottom, 6)

                            if group.statsConfig.enabledMetrics.isEmpty {
                                Text("Nothing yet — admins haven't picked any metrics.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(PepTheme.textSecondary)
                                    .padding(.vertical, 14)
                            } else {
                                ForEach(Array(group.statsConfig.enabledMetrics).sorted(by: { $0.rawValue < $1.rawValue })) { metric in
                                    HStack(spacing: 12) {
                                        Image(systemName: metric.icon)
                                            .font(.system(size: 13))
                                            .foregroundStyle(group.accentColor)
                                            .frame(width: 22)
                                        Text(metric.rawValue)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(PepTheme.textPrimary)
                                        Spacer()
                                        Text(group.statsConfig.period.shortLabel.uppercased())
                                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                            .tracking(1.4)
                                            .foregroundStyle(PepTheme.textTertiary)
                                    }
                                    .padding(.vertical, 12)
                                    Divider().overlay(PepTheme.separatorColor)
                                }
                            }
                        }

                        Text("You can pause sharing for this group at any time from the Stats tab — the rest of your apps and other groups stay untouched.")
                            .font(.system(size: 13))
                            .foregroundStyle(PepTheme.textSecondary)
                            .lineSpacing(2)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("YOUR DATA")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.8)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PepTheme.textPrimary)
                }
            }
        }
    }
}
