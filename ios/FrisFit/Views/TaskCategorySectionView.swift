import SwiftUI

struct TaskCategorySectionView: View {
    let name: String
    let icon: String
    let color: Color
    let tasks: [DailyTask]
    let key: String
    let isCollapsed: Bool
    let showProtocolReason: UUID?
    let onToggleCollapse: () -> Void
    let onToggleTask: (DailyTask) -> Void
    let onToggleReason: (DailyTask) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerButton
            if !isCollapsed {
                taskRows
            }
        }
    }

    private var headerButton: some View {
        let catCompleted = tasks.filter(\.isCompleted).count

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                onToggleCollapse()
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
            .padding(.top, 8)
            .padding(.bottom, 4)
            .padding(.horizontal, 4)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var taskRows: some View {
        ForEach(tasks) { task in
            DailyTaskRowView(
                task: task,
                showReason: showProtocolReason == task.id,
                onToggle: { onToggleTask(task) },
                onToggleReason: { onToggleReason(task) }
            )
        }
    }
}
