import SwiftUI

struct StreakInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let streakManager = StreakManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 36) {
                    heroHeader

                    chapter(
                        number: "I",
                        kicker: "Chapter One · Status",
                        title: stateHeadline
                    ) {
                        statusCard
                    }

                    chapter(
                        number: "II",
                        kicker: "Chapter Two · Milestones",
                        title: "The road ahead"
                    ) {
                        milestonesStrip
                    }

                    chapter(
                        number: "III",
                        kicker: "Chapter Three · Ritual",
                        title: "What keeps it alive"
                    ) {
                        ritualList
                    }

                    chapter(
                        number: "IV",
                        kicker: "Chapter Four · Safeguards",
                        title: "If you miss a day"
                    ) {
                        safeguardsList
                    }

                    chapter(
                        number: "V",
                        kicker: "Chapter Five · The day",
                        title: "When a day begins"
                    ) {
                        Text("A day closes at midnight in your local timezone. Log anything before then and the flame holds.")
                            .font(.system(size: 15, design: .serif))
                            .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                            .lineSpacing(3)
                    }

                    colophon
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 48)
            }
            .appBackground(accent: PepTheme.amber, intensity: 0.6)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("THE STREAK")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.4)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Text("Close")
                            .font(.system(size: 14, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(PepTheme.textPrimary)
                    }
                }
            }
        }
    }

    // MARK: - Hero

    private var heroHeader: some View {
        let s = streakManager.streakData
        return VStack(alignment: .leading, spacing: 18) {
            Text("AN ONGOING PRACTICE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.4)
                .foregroundStyle(PepTheme.textSecondary)

            HStack(alignment: .lastTextBaseline, spacing: 14) {
                Text("\(s.currentStreak)")
                    .font(.system(size: 96, weight: .light, design: .serif))
                    .kerning(-3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [PepTheme.textPrimary, PepTheme.textPrimary.opacity(0.78)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .contentTransition(.numericText(value: Double(s.currentStreak)))
                    .animation(.snappy, value: s.currentStreak)

                VStack(alignment: .leading, spacing: 2) {
                    Text("days")
                        .font(.system(size: 18, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary)
                    Text("unbroken")
                        .font(.system(size: 18, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .padding(.bottom, 14)

                Spacer()

                flameMark
                    .padding(.bottom, 18)
            }

            // Hairline rule
            Rectangle()
                .fill(PepTheme.textPrimary.opacity(0.18))
                .frame(height: 0.5)

            HStack(spacing: 0) {
                metaItem(label: "Longest", value: "\(s.longestStreak)")
                divider
                metaItem(label: "Freeze", value: freezeLabel)
                divider
                metaItem(label: "Status", value: stateLabel)
            }
            .frame(height: 44)
        }
    }

    private var flameMark: some View {
        let active = streakManager.streakState == .active || streakManager.streakState == .grace
        return Image(systemName: "flame.fill")
            .font(.system(size: 28, weight: .regular))
            .foregroundStyle(
                LinearGradient(
                    colors: active ? [PepTheme.amber, .orange] : [PepTheme.textTertiary, PepTheme.textTertiary.opacity(0.6)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .symbolEffect(.pulse, options: .repeating, isActive: active)
    }

    private var divider: some View {
        Rectangle()
            .fill(PepTheme.textPrimary.opacity(0.10))
            .frame(width: 0.5)
            .padding(.vertical, 6)
    }

    private func metaItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(PepTheme.textTertiary)
            Text(value)
                .font(.system(size: 16, weight: .regular, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var freezeLabel: String {
        if let days = streakManager.freezeAvailableInDays {
            return "in \(days)d"
        }
        return "ready"
    }

    private var stateLabel: String {
        switch streakManager.streakState {
        case .active: "Lit"
        case .grace: "Holding"
        case .paused: "Paused"
        case .broken: "At rest"
        case .dormant: "Dormant"
        }
    }

    private var stateHeadline: String {
        switch streakManager.streakState {
        case .active: return "The flame is lit today."
        case .grace: return "Your streak is intact — log anything by midnight."
        case .paused:
            if let h = streakManager.pausedHoursRemaining {
                return "Paused. \(h) hours to save it."
            }
            return "Paused. A small log will revive it."
        case .broken: return "A new chapter begins with one log."
        case .dormant: return "Your first log starts the streak."
        }
    }

    // MARK: - Chapter

    private func chapter<Content: View>(
        number: String,
        kicker: String,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(number)
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.amber)
                    .frame(width: 18, alignment: .leading)
                Text(kicker.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.0)
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Text(title)
                .font(.system(size: 26, weight: .regular, design: .serif))
                .kerning(-0.4)
                .foregroundStyle(PepTheme.textPrimary)
                .lineSpacing(2)
                .padding(.leading, 32)

            LinearGradient(
                colors: [PepTheme.textPrimary.opacity(0.16), PepTheme.textPrimary.opacity(0.0)],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 0.5)
            .padding(.leading, 32)

            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .padding(.leading, 32)
            .padding(.top, 4)
        }
    }

    // MARK: - Status card

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if streakManager.streakState == .paused, let hours = streakManager.pausedHoursRemaining {
                Label {
                    Text("\(hours) hours remaining in the grace window.")
                        .font(.system(size: 14, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                } icon: {
                    Image(systemName: "hourglass")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(PepTheme.amber)
                }
            } else if streakManager.freezeRecentlyUsed {
                Label {
                    Text("A streak freeze covered yesterday — quietly applied.")
                        .font(.system(size: 14, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                } icon: {
                    Image(systemName: "snowflake")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(PepTheme.teal)
                }
            } else if streakManager.streakState == .active {
                Label {
                    Text("Today's log is in. Return tomorrow.")
                        .font(.system(size: 14, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                } icon: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PepTheme.success)
                }
            } else {
                Label {
                    Text("One small log keeps the flame alive.")
                        .font(.system(size: 14, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                } icon: {
                    Image(systemName: "circle.dotted")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - Milestones

    private var milestonesStrip: some View {
        let current = streakManager.streakData.currentStreak
        let longest = streakManager.streakData.longestStreak
        return VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(StreakMilestone.allCases.enumerated()), id: \.element.rawValue) { idx, m in
                let reached = current >= m.rawValue || longest >= m.rawValue
                let isCurrentTarget = !reached && (idx == 0 || (StreakMilestone.allCases[max(idx-1,0)].rawValue <= current))
                HStack(alignment: .center, spacing: 14) {
                    Text(romanNumeral(idx + 1))
                        .font(.system(size: 11, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(reached ? PepTheme.amber : PepTheme.textTertiary)
                        .frame(width: 22, alignment: .leading)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.badgeName)
                            .font(.system(size: 16, weight: .regular, design: .serif))
                            .foregroundStyle(reached ? PepTheme.textPrimary : PepTheme.textPrimary.opacity(0.6))
                        Text("\(m.rawValue) days")
                            .font(.system(size: 11, weight: .medium))
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .foregroundStyle(PepTheme.textTertiary)
                    }

                    Spacer()

                    if reached {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(PepTheme.amber)
                    } else if isCurrentTarget {
                        Text("\(max(0, m.rawValue - current))d to go")
                            .font(.system(size: 12, design: .serif))
                            .italic()
                            .foregroundStyle(PepTheme.textSecondary)
                    } else {
                        Text("—")
                            .font(.system(size: 12))
                            .foregroundStyle(PepTheme.textTertiary)
                    }
                }
                if idx != StreakMilestone.allCases.count - 1 {
                    Rectangle()
                        .fill(PepTheme.textPrimary.opacity(0.06))
                        .frame(height: 0.5)
                }
            }
        }
    }

    private func romanNumeral(_ n: Int) -> String {
        switch n {
        case 1: "I"; case 2: "II"; case 3: "III"; case 4: "IV"; case 5: "V"
        default: "\(n)"
        }
    }

    // MARK: - Ritual

    private var ritualList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ritualRow(icon: "syringe", text: "A peptide pin or dose")
            ritualRow(icon: "scalemass", text: "A weigh-in")
            ritualRow(icon: "figure.run", text: "A workout or sport session")
            ritualRow(icon: "fork.knife", text: "A meal or food entry")
            ritualRow(icon: "face.smiling", text: "A mood or daily check-in", last: true)

            Text("Any one of these per day is enough.")
                .font(.system(size: 13, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
                .padding(.top, 14)
        }
    }

    private func ritualRow(icon: String, text: String, last: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(PepTheme.textSecondary)
                    .frame(width: 22, alignment: .leading)
                Text(text)
                    .font(.system(size: 15, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
            }
            .padding(.vertical, 12)

            if !last {
                Rectangle()
                    .fill(PepTheme.textPrimary.opacity(0.06))
                    .frame(height: 0.5)
            }
        }
    }

    // MARK: - Safeguards

    private var safeguardsList: some View {
        VStack(alignment: .leading, spacing: 18) {
            safeguardEntry(
                term: "Auto-freeze.",
                definition: "One free Streak Freeze every rolling seven days. It applies the next morning — no streak lost."
            )
            safeguardEntry(
                term: "Paused.",
                definition: "If your freeze is spent, the streak pauses for twenty-four hours. Log anything in that window to save it."
            )
            safeguardEntry(
                term: "Backdate.",
                definition: "You can log yesterday from any entry screen within twenty-four hours to repair the streak."
            )
            safeguardEntry(
                term: "Reset.",
                definition: "If the paused day passes empty, the streak rolls to zero — and we celebrate your longest before starting a new one."
            )
        }
    }

    private func safeguardEntry(term: String, definition: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(term)
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
            Text(definition)
                .font(.system(size: 14, design: .serif))
                .foregroundStyle(PepTheme.textSecondary)
                .lineSpacing(3)
        }
    }

    // MARK: - Colophon

    private var colophon: some View {
        VStack(alignment: .center, spacing: 8) {
            Rectangle()
                .fill(PepTheme.textPrimary.opacity(0.12))
                .frame(width: 24, height: 0.5)
            Text("FIN.")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.4)
                .foregroundStyle(PepTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }
}

#Preview {
    StreakInfoSheet()
}
