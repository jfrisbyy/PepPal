import SwiftUI

struct DailyTasksDetailView: View {
    @Bindable var viewModel: HomeViewModel
    @State private var selectedCategory: TaskCategory? = nil
    @State private var toggleTrigger: Int = 0
    @State private var collapsedCategories: Set<TaskCategory> = []
    @State private var showAddTask: Bool = false
    @State private var editingTask: DailyTask? = nil

    private var filteredCategories: [TaskCategory] {
        if let selected = selectedCategory {
            return [selected]
        }
        return TaskCategory.allCases
    }

    private var todaysTasks: [DailyTask] {
        viewModel.todaysTasks
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ringSection
                categoryFilter
                tasksList
            }
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(PepTheme.background.ignoresSafeArea())
        .navigationTitle("Daily Deck")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddTask = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PepTheme.teal)
                }
            }
        }
        .sheet(isPresented: $showAddTask) {
            AddEditTaskView(viewModel: viewModel)
        }
        .sheet(item: $editingTask) { task in
            AddEditTaskView(viewModel: viewModel, editingTask: task)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: toggleTrigger)
    }

    private var ringSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(PepTheme.teal.opacity(0.15), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: todaysTasks.isEmpty ? 0 : Double(todaysTasks.filter(\.isCompleted).count) / Double(todaysTasks.count))
                    .stroke(PepTheme.teal, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(todaysTasks.filter(\.isCompleted).count)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(PepTheme.teal)
                    Text("/ \(todaysTasks.count)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            .frame(width: 180, height: 180)

            Text("\(todaysTasks.filter(\.isCompleted).count) of \(todaysTasks.count) tasks completed")
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                categoryPill(title: "All", category: nil)
                ForEach(TaskCategory.allCases) { category in
                    categoryPill(title: category.rawValue, category: category)
                }
            }
        }
        .contentMargins(.horizontal, 16)
    }

    private func categoryPill(title: String, category: TaskCategory?) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedCategory = category
            }
        } label: {
            Text(title)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(isSelected ? PepTheme.background : PepTheme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? PepTheme.teal : PepTheme.elevated)
                .clipShape(.capsule)
        }
        .buttonStyle(.scale)
    }

    private var tasksList: some View {
        VStack(spacing: 20) {
            ForEach(filteredCategories) { category in
                let tasks = viewModel.todaysTasks(for: category)
                if !tasks.isEmpty {
                    categorySection(category, tasks: tasks)
                }
            }
        }
        .padding(.horizontal)
    }

    private func categorySection(_ category: TaskCategory, tasks: [DailyTask]) -> some View {
        let isCollapsed = collapsedCategories.contains(category)
        let completed = tasks.filter(\.isCompleted).count

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if isCollapsed {
                        collapsedCategories.remove(category)
                    } else {
                        collapsedCategories.insert(category)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: category.icon)
                        .font(.subheadline)
                        .foregroundStyle(category.color)
                    Text(category.rawValue)
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)

                    Spacer()

                    Text("\(completed)/\(tasks.count)")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(category.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(category.color.opacity(0.15))
                        .clipShape(.capsule)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                        .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if !isCollapsed {
                VStack(spacing: 0) {
                    ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                        taskRow(task: task, color: category.color)

                        if index < tasks.count - 1 {
                            Divider()
                                .overlay(PepTheme.cardOverlay)
                                .padding(.leading, 44)
                        }
                    }
                }
            }
        }
        .background(PepTheme.cardSurface)
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
    }

    private func taskRow(task: DailyTask, color: Color) -> some View {
        Button {
            if task.actionLink == .none {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    viewModel.toggleTask(task)
                }
                toggleTrigger += 1
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(task.isCompleted ? color : Color.clear)
                        .frame(width: 26, height: 26)
                        .overlay(
                            Circle()
                                .strokeBorder(task.isCompleted ? color : PepTheme.textSecondary.opacity(0.4), lineWidth: 1.5)
                        )

                    if task.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(PepTheme.invertedText)
                    }
                }

                Image(systemName: task.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(task.isCompleted ? color : PepTheme.textSecondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.name)
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(task.isCompleted ? PepTheme.textPrimary : PepTheme.textPrimary.opacity(0.7))
                        .strikethrough(task.isCompleted, color: PepTheme.textSecondary.opacity(0.4))

                    if task.actionLink != .none {
                        HStack(spacing: 3) {
                            Image(systemName: "link")
                                .font(.system(size: 8))
                            Text(task.actionLink.rawValue)
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(PepTheme.teal.opacity(0.6))
                    }

                    if task.scheduleType != .daily {
                        Text(scheduleLabel(for: task))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                    }
                }

                Spacer()

                if task.isUserCreated {
                    Button {
                        editingTask = task
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                            .frame(width: 28, height: 28)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func scheduleLabel(for task: DailyTask) -> String {
        switch task.scheduleType {
        case .daily:
            return ""
        case .customDays:
            let dayNames = task.scheduledDays.sorted(by: { $0.rawValue < $1.rawValue }).map(\.shortName)
            return dayNames.joined(separator: ", ")
        case .oneTime:
            guard let date = task.oneTimeDate else { return "One time" }
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}
