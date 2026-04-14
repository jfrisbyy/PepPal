import SwiftUI

struct DailyDeckBannerView: View {
    @Bindable var viewModel: HomeViewModel
    @State private var isExpanded: Bool = false
    @State private var toggleTrigger: Int = 0
    @State private var collapsedCategories: Set<String> = []
    @State private var showAddTask: Bool = false
    @State private var showProtocolReason: UUID? = nil

    private var todaysTasks: [DailyTask] {
        viewModel.todaysTasks
    }

    private var completedCount: Int {
        todaysTasks.filter(\.isCompleted).count
    }

    private var totalCount: Int {
        todaysTasks.count
    }

    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    private var protocolTaskCount: Int {
        todaysTasks.filter(\.isProtocolRecommended).count
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                    isExpanded.toggle()
                }
            } label: {
                bannerContent
            }
            .buttonStyle(.scale)
            .sensoryFeedback(.selection, trigger: isExpanded)

            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .sheet(isPresented: $showAddTask) {
            AddEditTaskView(viewModel: viewModel)
        }
    }

    private var bannerContent: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(PepTheme.elevated, lineWidth: 3)
                    .frame(width: 36, height: 36)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        progressGradient,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))

                Image(systemName: progress >= 1.0 ? "checkmark" : "sparkles")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(progress >= 1.0 ? PepTheme.teal : PepTheme.amber)
                    .contentTransition(.symbolEffect(.replace))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text("Daily Deck")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)

                    if viewModel.hasProtocolDeck {
                        protocolBadge
                    }
                }

                HStack(spacing: 4) {
                    Text("\(completedCount)/\(totalCount) completed")
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)

                    if completedCount == totalCount && totalCount > 0 {
                        Text("·")
                            .foregroundStyle(PepTheme.textSecondary)
                        Text("All done!")
                            .font(.system(.caption2, weight: .semibold))
                            .foregroundStyle(PepTheme.teal)
                    }
                }
            }

            Spacer()

            progressPills

            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            PepTheme.cardSurface
                .overlay(PepTheme.cardOverlay)
        )
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(
                        colors: viewModel.hasProtocolDeck
                            ? [PepTheme.teal.opacity(0.3), PepTheme.glassBorderBottom]
                            : [PepTheme.glassBorderTop, PepTheme.glassBorderBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 3)
    }

    private var protocolBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "pill.fill")
                .font(.system(size: 7, weight: .bold))
            Text("RX")
                .font(.system(size: 8, weight: .heavy))
        }
        .foregroundStyle(PepTheme.teal)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(PepTheme.teal.opacity(0.12))
        .clipShape(.capsule)
    }

    private var progressPills: some View {
        HStack(spacing: 2) {
            ForEach(0..<min(totalCount, 10), id: \.self) { index in
                let tasksPerPill = max(1, totalCount / 10)
                let pillCompleted = completedCount > index * tasksPerPill
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(pillCompleted ? PepTheme.teal : PepTheme.elevated)
                    .frame(width: 3, height: 10)
            }
        }
    }

    private var expandedContent: some View {
        VStack(spacing: 0) {
            if viewModel.hasProtocolDeck && !viewModel.protocolDeckFocus.isEmpty {
                protocolFocusStrip
            }

            ForEach(TaskCategory.builtInCases) { category in
                let tasks = viewModel.todaysTasks(for: category)
                if !tasks.isEmpty {
                    categorySection(name: category.rawValue, icon: category.icon, color: category.color, tasks: tasks, key: category.rawValue)
                }
            }

            ForEach(viewModel.customCategories) { custom in
                let tasks = viewModel.todaysTasks(forCustom: custom.id)
                if !tasks.isEmpty {
                    categorySection(name: custom.name, icon: custom.icon, color: custom.color, tasks: tasks, key: custom.id.uuidString)
                }
            }

            Button {
                showAddTask = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                    Text("Add Task")
                        .font(.system(.caption, weight: .semibold))
                }
                .foregroundStyle(PepTheme.teal)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: showAddTask)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            PepTheme.cardSurface
                .overlay(PepTheme.cardOverlay)
        )
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(
                        colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 3)
        .padding(.top, -6)
    }

    private var protocolFocusStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(PepTheme.teal)
                Text("PROTOCOL-TUNED")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(PepTheme.teal)
                    .tracking(0.5)
            }

            Text(viewModel.protocolDeckFocus)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PepTheme.textPrimary.opacity(0.8))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [PepTheme.teal.opacity(0.06), PepTheme.teal.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(.rect(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(PepTheme.teal.opacity(0.12), lineWidth: 0.5)
        )
        .padding(.bottom, 6)
    }

    private func categorySection(name: String, icon: String, color: Color, tasks: [DailyTask], key: String) -> some View {
        let isCollapsed = collapsedCategories.contains(key)
        let catCompleted = tasks.filter(\.isCompleted).count

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if isCollapsed {
                        collapsedCategories.remove(key)
                    } else {
                        collapsedCategories.insert(key)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(color)
                    Text(name.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                        .tracking(0.5)

                    Text("\(catCompleted)/\(tasks.count)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(catCompleted == tasks.count ? PepTheme.teal : PepTheme.textSecondary.opacity(0.5))

                    if catCompleted == tasks.count && !tasks.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(PepTheme.teal)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                        .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                }
                .padding(.top, 10)
                .padding(.bottom, 6)
                .padding(.horizontal, 4)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if !isCollapsed {
                ForEach(tasks) { task in
                    taskRow(task)
                }
            }
        }
    }

    private func taskRow(_ task: DailyTask) -> some View {
        VStack(spacing: 0) {
            Button {
                if task.isProtocolRecommended && !task.protocolReason.isEmpty {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showProtocolReason = showProtocolReason == task.id ? nil : task.id
                    }
                }
                guard task.actionLink == .none else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    viewModel.toggleTask(task)
                    toggleTrigger += 1
                }
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(task.isCompleted ? PepTheme.teal : PepTheme.textSecondary.opacity(0.3), lineWidth: 1.5)
                            .frame(width: 20, height: 20)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(task.isCompleted ? PepTheme.teal : Color.clear)
                            )

                        if task.isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(PepTheme.invertedText)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                    Image(systemName: task.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(task.isCompleted ? PepTheme.teal.opacity(0.5) : PepTheme.textSecondary)
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(task.name)
                            .font(.system(.subheadline, weight: task.isCompleted ? .medium : .semibold))
                            .foregroundStyle(task.isCompleted ? PepTheme.textSecondary.opacity(0.5) : PepTheme.textPrimary)
                            .strikethrough(task.isCompleted, color: PepTheme.textSecondary.opacity(0.3))
                            .lineLimit(1)
                    }

                    Spacer()

                    if task.isProtocolRecommended {
                        Image(systemName: "pill.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(PepTheme.teal.opacity(0.5))
                    }

                    if task.actionLink != .none {
                        if !task.goalDescription.isEmpty {
                            Text(task.goalDescription)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(PepTheme.teal.opacity(0.6))
                                .lineLimit(1)
                        }
                        Image(systemName: "link")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(PepTheme.teal.opacity(0.5))
                    }
                }
                .padding(.vertical, 7)
                .padding(.horizontal, 8)
                .background(
                    task.isCompleted
                        ? PepTheme.teal.opacity(0.04)
                        : (task.isProtocolRecommended ? PepTheme.teal.opacity(0.02) : Color.clear)
                )
                .clipShape(.rect(cornerRadius: 8))
            }
            .sensoryFeedback(.impact(weight: .light), trigger: toggleTrigger)
            .allowsHitTesting(task.actionLink == .none || task.isProtocolRecommended)
            .opacity(task.actionLink != .none && !task.isCompleted && !task.isProtocolRecommended ? 0.85 : 1)

            if showProtocolReason == task.id && task.isProtocolRecommended && !task.protocolReason.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(PepTheme.teal.opacity(0.6))
                    Text(task.protocolReason)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                        .lineSpacing(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .padding(.leading, 38)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PepTheme.teal.opacity(0.03))
                .clipShape(.rect(cornerRadius: 6))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var progressGradient: LinearGradient {
        if progress >= 1.0 {
            return LinearGradient(colors: [PepTheme.teal, PepTheme.teal], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        return LinearGradient(colors: [PepTheme.amber, PepTheme.teal], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
