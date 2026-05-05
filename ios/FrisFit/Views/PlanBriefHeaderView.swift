import SwiftUI

struct PlanBriefHeaderView: View {
    @Bindable var todaysPlanVM: TodaysPlanViewModel
    @Binding var isCollapsed: Bool
    var onRefresh: () -> Void
    var onChatAboutThis: (String) -> Void

    private var lines: MorningBriefService.Lines {
        MorningBriefService.shared.buildLines()
    }

    private var narrative: BriefNarrative? {
        todaysPlanVM.planResponse?.narrative
    }

    private var greeting: String {
        narrative?.greeting ?? MorningBriefService.shared.fallbackGreeting(firstName: InsightsDataStore.shared.firstName)
    }

    private var headline: String {
        if let h = narrative?.headline, !h.isEmpty { return h }
        return MorningBriefService.shared.fallbackHeadline(from: lines)
    }

    private var body_: String {
        if let b = narrative?.body, !b.isEmpty { return b }
        return MorningBriefService.shared.fallbackBody(from: lines)
    }

    private var watchFor: String? {
        narrative?.watchFor ?? lines.watchFor
    }

    var body: some View {
        Group {
            if isCollapsed {
                collapsedHeader
            } else {
                expandedContent
            }
        }
    }

    private var collapsedHeader: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                isCollapsed = false
            }
        } label: {
            HStack(spacing: 6) {
                Text("DAILY BRIEF")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                    .tracking(0.5)

                Text("·")
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.5))

                Text(collapsedSummary)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 4)

                if todaysPlanVM.isLoading || todaysPlanVM.isBackgroundRefreshing {
                    ProgressView().controlSize(.mini).tint(PepTheme.violet)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isCollapsed)
    }

    private var collapsedSummary: String {
        if todaysPlanVM.isLoading && narrative == nil { return "Generating your brief…" }
        let h = headline
        return h.isEmpty ? greeting : h
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            topBar

            if todaysPlanVM.isLoading && narrative == nil {
                shimmerContent
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(headline)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(body_)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(PepTheme.textPrimary.opacity(0.82))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let watchFor {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(PepTheme.violet.opacity(0.7))
                            .padding(.top, 1)
                        Text("Watch for: \(watchFor)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                    .padding(10)
                    .background(PepTheme.violet.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 10))
                }

                chatButton
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [
                    PepTheme.violet.opacity(0.14),
                    PepTheme.violet.opacity(0.04),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .topTrailing) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                    isCollapsed = true
                }
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PepTheme.violet.opacity(0.55))
                    .frame(width: 26, height: 26)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
            .padding(.trailing, 8)
            .sensoryFeedback(.selection, trigger: isCollapsed)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var timeOfDayIcon: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return "sunrise.fill"
        case 11..<17: return "sun.max.fill"
        case 17..<22: return "sun.horizon.fill"
        default: return "moon.stars.fill"
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [PepTheme.violet, PepTheme.teal.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 30, height: 30)
                Image(systemName: timeOfDayIcon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("DAILY BRIEF")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(PepTheme.violet)
                Text(greeting)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            Spacer()
            if todaysPlanVM.isLoading || todaysPlanVM.isBackgroundRefreshing {
                ProgressView().controlSize(.mini).tint(PepTheme.violet)
            } else {
                Button {
                    onRefresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PepTheme.violet.opacity(0.6))
                        .frame(width: 26, height: 26)
                        .background(PepTheme.violet.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var chatButton: some View {
        Button {
            onChatAboutThis(buildPlanContextString())
        } label: {
            HStack(spacing: 8) {
                PepNavAvatar(size: 22)
                Text("Chat about this")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PepTheme.violet)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(PepTheme.violet.opacity(0.5))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(PepTheme.violet.opacity(0.08))
            .clipShape(.capsule)
        }
        .buttonStyle(.plain)
    }

    private func buildPlanContextString() -> String {
        var parts: [String] = []
        if let n = narrative {
            parts.append("\(n.headline)\n\(n.body)")
        }
        if !todaysPlanVM.summary.isEmpty {
            parts.append("Summary: \(todaysPlanVM.summary)")
        }
        for module in todaysPlanVM.modules {
            parts.append("[\(module.title)] \(module.content)")
        }
        let items = todaysPlanVM.planResponse?.actionItems ?? []
        for item in items {
            parts.append("Action: \(item.title)\(item.reason.map { " — \($0)" } ?? "")")
        }
        return parts.joined(separator: "\n\n")
    }

    private var shimmerContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
                .fill(PepTheme.shimmerHighlight)
                .frame(height: 18)
                .frame(maxWidth: 260)
            VStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(PepTheme.shimmerHighlight)
                        .frame(height: 12)
                }
            }
        }
    }
}
