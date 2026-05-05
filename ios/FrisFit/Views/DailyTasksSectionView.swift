import SwiftUI

struct DailyTasksSectionView: View {
    @Bindable var viewModel: HomeViewModel
    @Binding var isDailyTasksCollapsed: Bool
    @Binding var collapsedTaskCategories: Set<String>
    @Binding var showAddTask: Bool
    @Binding var showProtocolReason: UUID?

    @AppStorage("dailyTasksLastOpenedDate") private var lastOpenedDateString: String = ""
    @State private var pulse: Bool = false

    private var todayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private var hasBeenOpenedToday: Bool {
        lastOpenedDateString == todayKey
    }

    var body: some View {
        let tasks = viewModel.todaysTasks
        let completedCount = tasks.filter(\.isCompleted).count
        let totalCount = tasks.count

        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(completedCount: completedCount, totalCount: totalCount)

            if !isDailyTasksCollapsed {
                expandedContent
            }
        }
    }

    private func sectionHeader(completedCount: Int, totalCount: Int) -> some View {
        let isComplete = completedCount == totalCount && totalCount > 0
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                isDailyTasksCollapsed.toggle()
            }
            if !isDailyTasksCollapsed {
                lastOpenedDateString = todayKey
            }
        } label: {
            HStack(spacing: 8) {
                Text("04")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(PepTheme.amber)
                Rectangle()
                    .fill(PepTheme.amber.opacity(0.55))
                    .frame(width: 14, height: 1)
                Text("DAILY TASKS")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(2.0)
                    .foregroundStyle(PepTheme.amber)

                Text("\(completedCount)/\(totalCount)")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(isComplete ? PepTheme.teal : PepTheme.textSecondary.opacity(0.55))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((isComplete ? PepTheme.teal : PepTheme.textSecondary).opacity(0.1))
                    .clipShape(.capsule)

                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(PepTheme.teal)
                }

                if isDailyTasksCollapsed {
                    Text("\u{2014}")
                        .font(.system(size: 10))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                    Text(collapsedHint(completed: completedCount, total: totalCount))
                        .font(.system(size: 12, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 4)

                if !hasBeenOpenedToday && isDailyTasksCollapsed {
                    pulsingDot
                        .padding(.trailing, 4)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(PepTheme.amber.opacity(0.5))
                    .rotationEffect(.degrees(isDailyTasksCollapsed ? 0 : 90))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var pulsingDot: some View {
        ZStack {
            Circle()
                .fill(PepTheme.teal.opacity(0.35))
                .frame(width: 14, height: 14)
                .scaleEffect(pulse ? 1.4 : 0.8)
                .opacity(pulse ? 0 : 0.9)
            Circle()
                .fill(PepTheme.teal)
                .frame(width: 7, height: 7)
                .shadow(color: PepTheme.teal.opacity(0.7), radius: pulse ? 4 : 1)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }

    private var expandedContent: some View {
        VStack(spacing: 0) {
            if viewModel.hasProtocolDeck && !viewModel.protocolDeckFocus.isEmpty {
                protocolFocusStrip
                    .padding(.horizontal, 14)
                    .padding(.bottom, 6)
            }

            ForEach(TaskCategory.builtInCases) { category in
                let catTasks = viewModel.todaysTasks(for: category)
                if !catTasks.isEmpty {
                    TaskCategorySectionView(
                        name: category.rawValue,
                        icon: category.icon,
                        color: category.color,
                        tasks: catTasks,
                        key: category.rawValue,
                        isCollapsed: collapsedTaskCategories.contains(category.rawValue),
                        showProtocolReason: showProtocolReason,
                        onToggleCollapse: { toggleCategory(category.rawValue) },
                        onToggleTask: { viewModel.toggleTask($0) },
                        onToggleReason: { toggleReason($0) }
                    )
                }
            }

            ForEach(viewModel.customCategories) { custom in
                let catTasks = viewModel.todaysTasks(forCustom: custom.id)
                if !catTasks.isEmpty {
                    TaskCategorySectionView(
                        name: custom.name,
                        icon: custom.icon,
                        color: custom.color,
                        tasks: catTasks,
                        key: custom.id.uuidString,
                        isCollapsed: collapsedTaskCategories.contains(custom.id.uuidString),
                        showProtocolReason: showProtocolReason,
                        onToggleCollapse: { toggleCategory(custom.id.uuidString) },
                        onToggleTask: { viewModel.toggleTask($0) },
                        onToggleReason: { toggleReason($0) }
                    )
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
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: showAddTask)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var protocolFocusStrip: some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(PepTheme.teal)
                .frame(width: 2)
                .frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("PROTOCOL-TUNED")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(PepTheme.teal)
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(PepTheme.teal.opacity(0.7))
                }
                Text(viewModel.protocolDeckFocus)
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary.opacity(0.88))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.teal.opacity(0.05))
        .clipShape(.rect(cornerRadius: 8))
    }

    private func collapsedHint(completed: Int, total: Int) -> String {
        if total == 0 {
            return "Tap to add your first task"
        }
        if completed == total {
            return "All done — nice work"
        }
        let remaining = viewModel.todaysTasks.filter { !$0.isCompleted }
        if let next = remaining.first {
            let extras = remaining.count - 1
            if extras > 0 {
                return "Next: \(next.name) +\(extras) more"
            }
            return "Next: \(next.name)"
        }
        return "\(total - completed) left"
    }

    private func toggleCategory(_ key: String) {
        if collapsedTaskCategories.contains(key) {
            collapsedTaskCategories.remove(key)
        } else {
            collapsedTaskCategories.insert(key)
        }
    }

    private func toggleReason(_ task: DailyTask) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showProtocolReason = showProtocolReason == task.id ? nil : task.id
        }
    }
}
