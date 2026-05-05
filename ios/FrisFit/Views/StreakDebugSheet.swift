import SwiftUI

#if DEBUG
struct StreakDebugSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var manager = StreakManager.shared
    @State private var seedDays: Double = 14

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusCard

                    VStack(spacing: 0) {
                        row(icon: "calendar.badge.minus", color: .orange, title: "Simulate missed day", subtitle: "Shifts logs back 1 day; streak rechecks") {
                            manager.qa_simulateMissedDay(days: 1)
                        }
                        Divider().overlay(PepTheme.glassBorderTop).padding(.vertical, 6)
                        row(icon: "snowflake", color: PepTheme.teal, title: "Force freeze used (yesterday)", subtitle: "Inserts a freeze log for yesterday") {
                            manager.qa_forceFreezeUsed()
                        }
                        Divider().overlay(PepTheme.glassBorderTop).padding(.vertical, 6)
                        row(icon: "pause.circle.fill", color: PepTheme.amber, title: "Force paused state", subtitle: "Burns the freeze + clears today/yesterday, opens 24h window") {
                            manager.qa_forcePaused()
                        }
                        Divider().overlay(PepTheme.glassBorderTop).padding(.vertical, 6)
                        row(icon: "arrow.counterclockwise", color: .red, title: "Reset streak", subtitle: "Wipes activity log + resets to 0") {
                            manager.qa_resetStreak()
                        }
                    }
                    .padding(16)
                    .background(PepTheme.cardSurface)
                    .clipShape(.rect(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5))

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Seed N-day streak")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Slider(value: $seedDays, in: 1...365, step: 1)
                        HStack {
                            Text("\(Int(seedDays)) days")
                                .font(.system(.body, design: .rounded, weight: .semibold))
                                .foregroundStyle(PepTheme.amber)
                            Spacer()
                            Button {
                                manager.qa_seedStreak(days: Int(seedDays))
                            } label: {
                                Text("Seed")
                                    .font(.system(.subheadline, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(PepTheme.teal)
                                    .clipShape(.capsule)
                            }
                        }
                    }
                    .padding(16)
                    .background(PepTheme.cardSurface)
                    .clipShape(.rect(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5))
                }
                .padding(20)
            }
            .appBackground()
            .navigationTitle("Streak Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var statusCard: some View {
        let s = manager.streakData
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Current")
                    .font(.caption).foregroundStyle(PepTheme.textSecondary)
                Spacer()
                Text("\(s.currentStreak) days")
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.amber)
            }
            HStack {
                Text("State")
                    .font(.caption).foregroundStyle(PepTheme.textSecondary)
                Spacer()
                Text(manager.streakState.rawValue)
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            HStack {
                Text("Freeze")
                    .font(.caption).foregroundStyle(PepTheme.textSecondary)
                Spacer()
                if let d = manager.freezeAvailableInDays {
                    Text("locked, \(d)d").font(.caption).foregroundStyle(PepTheme.textSecondary)
                } else {
                    Text("ready").font(.caption).foregroundStyle(PepTheme.teal)
                }
            }
            if let hours = manager.pausedHoursRemaining {
                HStack {
                    Text("Paused for")
                        .font(.caption).foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                    Text("\(hours)h").font(.caption).foregroundStyle(PepTheme.amber)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5))
    }

    private func row(icon: String, color: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(color)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body).foregroundStyle(PepTheme.textPrimary)
                    Text(subtitle).font(.caption).foregroundStyle(PepTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "play.fill").font(.caption).foregroundStyle(PepTheme.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}
#endif
