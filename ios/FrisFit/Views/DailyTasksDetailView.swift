import SwiftUI

struct DailyTasksDetailView: View {
    @Bindable var viewModel: HomeViewModel
    @State private var selectedCategory: TaskCategory? = nil
    @State private var toggleTrigger: Int = 0

    private var filteredCategories: [TaskCategory] {
        if let selected = selectedCategory {
            return [selected]
        }
        return TaskCategory.allCases
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
        .navigationTitle("Daily Points")
        .navigationBarTitleDisplayMode(.inline)
        
        .sensoryFeedback(.impact(weight: .medium), trigger: toggleTrigger)
    }

    private var ringSection: some View {
        VStack(spacing: 12) {
            FPProgressRing(
                currentFP: viewModel.earnedPoints,
                targetFP: viewModel.totalPoints,
                progress: viewModel.pointsProgress,
                size: 180,
                lineWidth: 14,
                fontSize: 42
            )

            Text("\(viewModel.completedCount) of \(viewModel.dailyTasks.count) tasks completed")
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
                categorySection(category)
            }
        }
        .padding(.horizontal)
    }

    private func categorySection(_ category: TaskCategory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.subheadline)
                    .foregroundStyle(category.color)
                Text(category.rawValue)
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)

                Spacer()

                let tasks = viewModel.tasks(for: category)
                let completed = tasks.filter(\.isCompleted).count
                Text("\(completed)/\(tasks.count)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(category.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(category.color.opacity(0.15))
                    .clipShape(.capsule)
            }

            VStack(spacing: 0) {
                let tasks = viewModel.tasks(for: category)
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                    taskRow(task: task, color: category.color)

                    if index < tasks.count - 1 {
                        Divider()
                            .overlay(PepTheme.cardOverlay)
                            .padding(.leading, 44)
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
    }

    private func taskRow(task: DailyTask, color: Color) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                viewModel.toggleTask(task)
            }
            toggleTrigger += 1
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

                Text(task.name)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(task.isCompleted ? PepTheme.textPrimary : PepTheme.textPrimary.opacity(0.7))
                    .strikethrough(task.isCompleted, color: PepTheme.textSecondary.opacity(0.4))

                Spacer()

                Text("+\(task.points)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(task.isCompleted ? color : PepTheme.textSecondary.opacity(0.6))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
