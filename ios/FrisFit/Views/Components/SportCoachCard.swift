import SwiftUI

struct SportCoachCard: View {
    let sport: SportCoachSport
    let accent: Color

    @State private var brief: SportCoachBrief = SportCoachBrief(
        headline: "Preparing your session…",
        recovery: .unknown,
        tips: []
    )
    @State private var showChat: Bool = false
    @State private var refreshTick: Int = 0

    var body: some View {
        PepSportCard(accent: accent) {
            VStack(alignment: .leading, spacing: 14) {
                header
                headline
                if !brief.tips.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(brief.tips) { tip in
                            tipRow(tip)
                        }
                    }
                }
                actionRow
            }
        }
        .onAppear { refresh() }
        .sheet(isPresented: $showChat) {
            NavigationStack {
                PepChatView(planContext: coachPlanContext)
                    .navigationTitle(sportTitle)
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.14))
                    .frame(width: 32, height: 32)
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accent)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("AI COACH")
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.4)
                    .foregroundStyle(accent)
                Text(sportTitle + " insight")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()
            recoveryPill
        }
    }

    private var recoveryPill: some View {
        let signal = brief.recovery
        let color: Color = switch signal {
            case .green: .green
            case .amber: .orange
            case .red: .red
            case .unknown: PepTheme.textSecondary
        }
        let label: String = switch signal {
            case .green: "Recovered"
            case .amber: "Caution"
            case .red: "Rest"
            case .unknown: "No data"
        }
        let icon: String = switch signal {
            case .green: "checkmark.seal.fill"
            case .amber: "exclamationmark.triangle.fill"
            case .red: "xmark.octagon.fill"
            case .unknown: "questionmark.circle.fill"
        }
        return HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(label)
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private var headline: some View {
        Text(brief.headline)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(PepTheme.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func tipRow(_ tip: SportCoachTip) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: tip.icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 22, height: 22)
                .background(accent.opacity(0.12))
                .clipShape(Circle())
            Text(tip.text)
                .font(.system(size: 13))
                .foregroundStyle(PepTheme.textPrimary.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                showChat = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("Ask coach")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(accent)
                .clipShape(.rect(cornerRadius: 10))
            }
            .buttonStyle(.scale)

            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    refreshTick += 1
                    refresh()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .bold))
                    Text("Refresh")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(accent.opacity(0.1))
                .clipShape(.rect(cornerRadius: 10))
            }
            .buttonStyle(.scale)
            .sensoryFeedback(.selection, trigger: refreshTick)
        }
    }

    // MARK: - Helpers

    private var sportTitle: String {
        switch sport {
        case .main: "Lifting"
        case .running: "Running"
        case .cycling: "Cycling"
        case .basketball: "Basketball"
        }
    }

    private var coachPlanContext: String {
        var out = "User opened Ask Coach from the \(sportTitle) tab.\n\n"
        out += "Today's snapshot:\n"
        out += "- Headline: \(brief.headline)\n"
        out += "- Recovery signal: \(brief.recovery.rawValue)\n"
        if !brief.tips.isEmpty {
            out += "- Suggested focus:\n"
            for t in brief.tips { out += "  • \(t.text)\n" }
        }
        out += "\nKeep your answer scoped to \(sportTitle.lowercased()) training — the user is in that tab right now. Do not pivot to unrelated topics like peptides or bloodwork unless asked."
        return out
    }

    private func refresh() {
        brief = SportCoachService.brief(for: sport)
    }
}
