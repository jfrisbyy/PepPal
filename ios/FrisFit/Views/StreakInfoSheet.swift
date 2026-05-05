import SwiftUI

struct StreakInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let streakManager = StreakManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerCard

                    section(title: "What keeps it alive") {
                        rule(icon: "syringe.fill", color: PepTheme.violet, text: "Logging a peptide pin or dose")
                        rule(icon: "scalemass.fill", color: PepTheme.teal, text: "Logging a weight")
                        rule(icon: "figure.run", color: PepTheme.amber, text: "A workout or sport session")
                        rule(icon: "fork.knife", color: .green, text: "A food or meal entry")
                        rule(icon: "face.smiling", color: .pink, text: "A mood or daily check-in")
                        Text("Any **one** of these per day keeps the flame going.")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                            .padding(.top, 4)
                    }

                    section(title: "If you miss a day") {
                        bullet("Auto-freeze. You get 1 free Streak Freeze per rolling 7 days. It applies automatically the next morning — no streak lost.")
                        bullet("Paused (last chance). If your freeze is spent, the streak pauses for 24 hours. Log anything in that window to save it.")
                        bullet("Backdate. You can log yesterday from any entry screen within 24h to repair the streak.")
                        bullet("Reset. If the paused day passes empty, the streak rolls to 0 — and we celebrate your longest before starting a new one.")
                    }

                    section(title: "Day boundary") {
                        Text("A day ends at midnight in your phone's local timezone. Night-owl note: log anything before midnight and you're good.")
                            .font(.callout)
                            .foregroundStyle(PepTheme.textPrimary)
                    }
                }
                .padding(20)
            }
            .appBackground()
            .navigationTitle("How streaks work")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var headerCard: some View {
        let s = streakManager.streakData
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [.orange, PepTheme.amber], startPoint: .top, endPoint: .bottom))
                Text("\(s.currentStreak)")
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("day streak")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
            }
            HStack(spacing: 14) {
                Label("Longest \(s.longestStreak)", systemImage: "trophy.fill")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                if let days = streakManager.freezeAvailableInDays {
                    Label("Freeze in \(days)d", systemImage: "snowflake")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                } else {
                    Label("Freeze ready", systemImage: "snowflake")
                        .font(.caption)
                        .foregroundStyle(PepTheme.teal)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5))
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(PepTheme.textSecondary)
            content()
        }
    }

    private func rule(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 32, height: 32)
                Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(color)
            }
            Text(text).font(.callout).foregroundStyle(PepTheme.textPrimary)
            Spacer(minLength: 0)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(PepTheme.amber).frame(width: 5, height: 5).padding(.top, 8)
            Text(.init(text)).font(.callout).foregroundStyle(PepTheme.textPrimary)
            Spacer(minLength: 0)
        }
    }
}
