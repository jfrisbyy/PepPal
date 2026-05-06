import SwiftUI

/// Full-screen in-app notification center surfacing the rolling 30-day log
/// of fired/received smart notifications. Grouped by Today / This Week /
/// Earlier with swipe-to-dismiss and deep-linking.
struct SmartNotificationCenterView: View {
    @State private var store = SmartNotificationStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    if store.log.isEmpty {
                        emptyState
                            .padding(.top, 80)
                    } else {
                        ForEach(groups, id: \.label) { group in
                            sectionHeader(group.label, count: group.items.count)
                            VStack(spacing: 10) {
                                ForEach(group.items) { entry in
                                    row(entry)
                                }
                            }
                        }
                    }

                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .scrollIndicators(.hidden)
            .appBackground(accent: PepTheme.teal, intensity: 0.6)
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            store.markAllRead()
                        } label: {
                            Label("Mark all read", systemImage: "checkmark.circle")
                        }
                        Button(role: .destructive) {
                            store.clearAll()
                        } label: {
                            Label("Clear all", systemImage: "trash")
                        }
                        NavigationLink {
                            SmartNotificationSettingsView()
                        } label: {
                            Label("Settings", systemImage: "gear")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private struct Group {
        let label: String
        let items: [SmartNotificationLogEntry]
    }

    private var groups: [Group] {
        let cal = Calendar.current
        let now = Date()
        var today: [SmartNotificationLogEntry] = []
        var week: [SmartNotificationLogEntry] = []
        var earlier: [SmartNotificationLogEntry] = []

        for n in store.log {
            if cal.isDateInToday(n.firedAt) {
                today.append(n)
            } else if let days = cal.dateComponents([.day], from: n.firedAt, to: now).day, days < 7 {
                week.append(n)
            } else {
                earlier.append(n)
            }
        }

        var out: [Group] = []
        if !today.isEmpty { out.append(.init(label: "Today", items: today)) }
        if !week.isEmpty { out.append(.init(label: "This week", items: week)) }
        if !earlier.isEmpty { out.append(.init(label: "Earlier", items: earlier)) }
        return out
    }

    private func sectionHeader(_ label: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(height: 0.5)
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
        }
        .padding(.top, 10)
        .padding(.bottom, 2)
    }

    // MARK: - Row

    private func row(_ entry: SmartNotificationLogEntry) -> some View {
        Button {
            handleTap(entry)
        } label: {
            HStack(alignment: .top, spacing: 0) {
                // Left accent strip
                Rectangle()
                    .fill(entry.category.accent)
                    .frame(width: 3)
                    .opacity(entry.isRead ? 0.35 : 1.0)

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: entry.category.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(entry.category.accent)
                        .frame(width: 28, height: 28)
                        .background(entry.category.accent.opacity(0.12), in: Circle())
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(entry.category.title.uppercased())
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .tracking(1.4)
                                .foregroundStyle(entry.category.accent.opacity(0.85))
                            if !entry.isRead {
                                Circle().fill(entry.category.accent).frame(width: 5, height: 5)
                            }
                            Spacer(minLength: 0)
                            Text(entry.firedAt.timeAgoDisplay())
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                        }

                        Text(entry.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        if !entry.body.isEmpty {
                            Text(entry.body)
                                .font(.system(size: 13))
                                .foregroundStyle(PepTheme.textSecondary)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
        .buttonStyle(.plain)
        .surfaceCard(cornerRadius: 16)
        .opacity(entry.isRead ? 0.78 : 1.0)
        .swipeAction { store.remove(entry.id) }
    }

    private func handleTap(_ entry: SmartNotificationLogEntry) {
        store.markRead(entry.id)
        if let dl = entry.deepLink {
            DeepLinkRouter.shared.handle(userInfo: dl as [AnyHashable: Any])
            dismiss()
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(PepTheme.teal.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "bell")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(PepTheme.teal)
                    .symbolEffect(.pulse, options: .repeating)
            }
            Text("You're all caught up")
                .font(.system(size: 22, weight: .regular, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
            Text("Smart nudges, reminders, and friend activity will land here.")
                .font(.system(size: 13))
                .foregroundStyle(PepTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Helpers

private extension View {
    @ViewBuilder
    func swipeAction(_ action: @escaping () -> Void) -> some View {
        // Wrap in a List-like swipeActions via gesture-based fallback for plain VStack rows.
        // We attach a long-press + horizontal drag affordance using contextMenu instead so
        // it still feels native without forcing List.
        self.contextMenu {
            Button(role: .destructive) { action() } label: {
                Label("Dismiss", systemImage: "trash")
            }
        }
    }
}
