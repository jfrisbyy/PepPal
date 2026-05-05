import SwiftUI

struct PendingSyncDot: View {
    let isPending: Bool
    var isFailed: Bool = false

    var body: some View {
        if isPending || isFailed {
            Image(systemName: isFailed ? "exclamationmark.circle.fill" : "arrow.triangle.2.circlepath")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isFailed ? Color.red : PepTheme.amber)
                .symbolEffect(.pulse, options: .repeating, isActive: !isFailed)
                .help(isFailed ? "Sync failed — tap sync status to retry" : "Pending sync")
        }
    }
}
