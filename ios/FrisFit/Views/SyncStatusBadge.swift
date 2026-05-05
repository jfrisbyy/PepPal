import SwiftUI

struct SyncStatusBadge: View {
    @State private var network = NetworkMonitor.shared
    @State private var queue = OfflineQueue.shared
    @State private var showDetails: Bool = false

    var body: some View {
        Button {
            showDetails = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.caption2)
                    .foregroundStyle(iconColor)
                    .symbolEffect(.pulse, options: .repeating, isActive: queue.isFlushing || queue.pendingCount > 0)
                Text(label)
                    .font(.system(.caption2, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(backgroundTint, in: .capsule)
        }
        .buttonStyle(.plain)
        .opacity(showBadge ? 1 : 0)
        .animation(.easeInOut(duration: 0.25), value: showBadge)
        .sheet(isPresented: $showDetails) {
            SyncStatusSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var showBadge: Bool {
        !network.isOnline || queue.pendingCount > 0 || queue.hasFailures
    }

    private var iconName: String {
        if queue.hasFailures { return "exclamationmark.triangle.fill" }
        if !network.isOnline { return "wifi.slash" }
        if queue.isFlushing { return "arrow.triangle.2.circlepath" }
        if queue.pendingCount > 0 { return "clock.arrow.circlepath" }
        return "checkmark.circle.fill"
    }

    private var iconColor: Color {
        if queue.hasFailures { return .red }
        if !network.isOnline { return .orange }
        if queue.pendingCount > 0 { return PepTheme.amber }
        return .green
    }

    private var backgroundTint: Color {
        if queue.hasFailures { return Color.red.opacity(0.15) }
        if !network.isOnline { return Color.orange.opacity(0.15) }
        if queue.pendingCount > 0 { return PepTheme.amber.opacity(0.15) }
        return Color.green.opacity(0.12)
    }

    private var label: String {
        if queue.hasFailures {
            return "\(queue.failedCount) failed"
        }
        if !network.isOnline {
            return queue.pendingCount > 0 ? "Offline · \(queue.pendingCount) pending" : "Offline"
        }
        if queue.isFlushing { return "Syncing…" }
        if queue.pendingCount > 0 { return "\(queue.pendingCount) pending" }
        return "Synced"
    }
}

private struct OutboxItemRow: View {
    let item: QueuedWrite
    @State private var queue = OfflineQueue.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(item.label).font(.subheadline)
                Spacer()
                if item.status == .failed {
                    Text("FAILED")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.red.opacity(0.15), in: .capsule)
                }
            }
            HStack(spacing: 6) {
                Text(item.createdAt, style: .relative)
                if item.attempts > 0 {
                    Text("·")
                    Text("\(item.attempts) \(item.attempts == 1 ? "attempt" : "attempts")")
                        .foregroundStyle(PepTheme.amber)
                }
            }
            .font(.caption2)
            .foregroundStyle(PepTheme.textSecondary)
            if let err = item.lastError {
                Text(err)
                    .font(.caption2)
                    .foregroundStyle(.red.opacity(0.7))
                    .lineLimit(3)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if item.status == .failed {
                Button { queue.retry(itemId: item.id) } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
                .tint(PepTheme.teal)
            }
            Button(role: .destructive) { queue.discard(itemId: item.id) } label: {
                Label("Discard", systemImage: "trash")
            }
        }
    }
}

struct SyncStatusSheet: View {
    @State private var queue = OfflineQueue.shared
    @State private var network = NetworkMonitor.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: network.isOnline ? "wifi" : "wifi.slash")
                            .foregroundStyle(network.isOnline ? .green : .orange)
                        Text(network.isOnline ? "Connected" : "Offline")
                        Spacer()
                        if queue.isFlushing {
                            ProgressView().tint(PepTheme.teal)
                        }
                    }
                }

                if queue.hasFailures {
                    Section {
                        ForEach(queue.pending.filter { $0.status == .failed }) { item in
                            OutboxItemRow(item: item)
                        }
                    } header: {
                        HStack {
                            Text("Failed (\(queue.failedCount))")
                            Spacer()
                            Button("Retry all") { queue.retryAllFailed() }
                                .font(.caption)
                                .foregroundStyle(PepTheme.teal)
                            Button("Discard", role: .destructive) { queue.discardAllFailed() }
                                .font(.caption)
                        }
                    } footer: {
                        Text("These writes gave up after 8 attempts. Retry when you've fixed the issue, or discard.")
                    }
                }

                Section {
                    let pending = queue.pending.filter { $0.status == .pending }
                    if pending.isEmpty && !queue.hasFailures {
                        Text("All caught up")
                            .foregroundStyle(PepTheme.textSecondary)
                    } else if !pending.isEmpty {
                        ForEach(pending) { item in
                            OutboxItemRow(item: item)
                        }
                    }
                } header: {
                    Text("Pending writes (\(queue.pendingCount))")
                } footer: {
                    if network.isOnline {
                        Text("Items sync automatically when you're online. Tap Retry to force.")
                    } else {
                        Text("Writes saved locally — they'll sync when you reconnect.")
                    }
                }

                if queue.pendingCount > 0 && network.isOnline {
                    Section {
                        Button {
                            queue.flush()
                        } label: {
                            Label("Retry sync", systemImage: "arrow.clockwise")
                        }
                    }
                }
            }
            .navigationTitle("Sync Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
