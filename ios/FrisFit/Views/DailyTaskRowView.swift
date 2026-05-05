import SwiftUI

struct DailyTaskRowView: View {
    let task: DailyTask
    let showReason: Bool
    let onToggle: () -> Void
    let onToggleReason: () -> Void

    @State private var localToggleTrigger: Int = 0
    @State private var showLinkedInfo: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                if task.actionLink != .none {
                    showLinkedInfo = true
                    return
                }
                if task.isProtocolRecommended && !task.protocolReason.isEmpty {
                    onToggleReason()
                }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    onToggle()
                    localToggleTrigger += 1
                }
            } label: {
                rowContent
            }
            .sensoryFeedback(.impact(weight: .light), trigger: localToggleTrigger)

            if showReason && task.isProtocolRecommended && !task.protocolReason.isEmpty {
                reasonRow
            }
        }
        .confirmationDialog(linkedDialogTitle, isPresented: $showLinkedInfo, titleVisibility: .visible) {
            let quick = task.actionLink.quickAction
            if quick != .none {
                Button {
                    NotificationCenter.default.post(name: .linkedTaskQuickAction, object: nil, userInfo: ["action": quick.label])
                } label: {
                    Text(quick.label)
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(task.actionLink.autoCompleteMessage)
        }
    }

    private var linkedDialogTitle: String {
        task.isCompleted ? "\(task.name) — Completed" : task.name
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .stroke(task.isCompleted ? PepTheme.teal : PepTheme.textSecondary.opacity(0.35), lineWidth: 1)
                    .frame(width: 18, height: 18)

                if task.isCompleted {
                    Circle()
                        .fill(PepTheme.teal)
                        .frame(width: 9, height: 9)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.name)
                    .font(.system(size: 15, weight: task.isCompleted ? .regular : .medium, design: .serif))
                    .foregroundStyle(task.isCompleted ? PepTheme.textSecondary.opacity(0.5) : PepTheme.textPrimary)
                    .strikethrough(task.isCompleted, color: PepTheme.textSecondary.opacity(0.3))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if task.actionLink != .none && !task.goalDescription.isEmpty {
                    Text(task.goalDescription.uppercased())
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(PepTheme.teal.opacity(0.75))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                if task.source.isSynthetic {
                    sourceBadge
                } else if task.isProtocolRecommended {
                    Image(systemName: "pill.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(PepTheme.teal.opacity(0.5))
                }

                if task.actionLink != .none {
                    Image(systemName: "link")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(PepTheme.teal.opacity(0.5))
                }
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
        .background(
            task.isCompleted
                ? PepTheme.teal.opacity(0.03)
                : (task.isProtocolRecommended ? PepTheme.teal.opacity(0.02) : Color.clear)
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PepTheme.textSecondary.opacity(0.08))
                .frame(height: 0.5)
        }
    }

    private var sourceBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: task.source.icon)
                .font(.system(size: 7, weight: .bold))
            Text(task.source.label.uppercased())
                .font(.system(size: 8, weight: .heavy))
                .tracking(0.4)
        }
        .foregroundStyle(task.source.color)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(task.source.color.opacity(0.12))
        .clipShape(.capsule)
    }

    private var reasonRow: some View {
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
