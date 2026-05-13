import SwiftUI

struct PlanBriefHeaderView: View {
    @Bindable var todaysPlanVM: TodaysPlanViewModel
    @Binding var isCollapsed: Bool
    var onRefresh: () -> Void
    var onChatAboutThis: (String) -> Void

    private var isHistorical: Bool { todaysPlanVM.isHistoricalMode }

    private var lines: MorningBriefService.Lines {
        MorningBriefService.shared.buildLines()
    }

    private var narrative: BriefNarrative? {
        todaysPlanVM.activePlan?.narrative
    }

    private var briefDateLabel: String? {
        guard let date = todaysPlanVM.historicalDate else { return nil }
        let f = DateFormatter()
        f.dateFormat = "EEEE \u{00B7} MMM d"
        return f.string(from: date).uppercased()
    }

    private var greeting: String {
        narrative?.greeting ?? MorningBriefService.shared.fallbackGreeting(firstName: InsightsDataStore.shared.firstName)
    }

    private var headline: String {
        if let h = narrative?.headline, !h.isEmpty { return h }
        if isHistorical {
            return todaysPlanVM.activePlan?.summary ?? ""
        }
        return MorningBriefService.shared.fallbackHeadline(from: lines)
    }

    private var body_: String {
        if let b = narrative?.body, !b.isEmpty { return b }
        if isHistorical {
            return ""
        }
        return MorningBriefService.shared.fallbackBody(from: lines)
    }

    private var watchFor: String? {
        if isHistorical { return narrative?.watchFor }
        return narrative?.watchFor ?? lines.watchFor
    }

    private var adaptiveCallout: AdaptiveCallout? {
        narrative?.adaptiveCallout
    }

    /// Today's deterministic bundle — the brief strip renders one row per
    /// `AdaptiveLine`, each with its own Accept / Skip. A bulk Apply All /
    /// Skip All sits at the bottom for the common case.
    private var bundle: AdaptiveAdjustmentService.DailyBundleDecision? {
        AdaptiveAdjustmentService.shared.bundleDecisionForToday()
    }

    @State private var pulsePhase: CGFloat = 0

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
            HStack(spacing: 10) {
                Rectangle()
                    .fill(PepTheme.violet)
                    .frame(width: 2, height: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text("DAILY BRIEF  \u{2014}  NO. 01")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.8)
                        .foregroundStyle(PepTheme.violet.opacity(0.9))
                    Text(collapsedSummary)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 4)

                if (todaysPlanVM.isLoading || todaysPlanVM.isBackgroundRefreshing || todaysPlanVM.isLoadingHistorical) {
                    ProgressView().controlSize(.mini).tint(PepTheme.violet)
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(PepTheme.violet.opacity(0.55))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isCollapsed)
    }

    private var collapsedSummary: String {
        if isHistorical {
            if todaysPlanVM.isLoadingHistorical { return "Loading saved brief…" }
            if narrative == nil && (todaysPlanVM.activePlan?.summary.isEmpty ?? true) {
                return "No saved brief for this day"
            }
        }
        if !isHistorical && narrative == nil {
            if todaysPlanVM.isLoading || todaysPlanVM.isBackgroundRefreshing {
                return "Generating your brief…"
            }
            if todaysPlanVM.errorMessage != nil {
                return "Tap to retry your brief"
            }
        }
        let h = headline
        return h.isEmpty ? greeting : h
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            topBar

            Rectangle()
                .fill(PepTheme.violet.opacity(0.18))
                .frame(height: 0.5)

            if isHistorical && todaysPlanVM.activePlan == nil {
                if todaysPlanVM.isLoadingHistorical {
                    shimmerContent
                } else {
                    emptyHistoricalContent
                }
            } else if !isHistorical && narrative == nil && (todaysPlanVM.isLoading || todaysPlanVM.isBackgroundRefreshing) {
                // Initial AI generation — show shimmer instead of dropping
                // into the local-data fallback copy. The fallback was making
                // every brief look generic until the AI call finished (or
                // worse, if it failed silently).
                shimmerContent
            } else if !isHistorical && narrative == nil && todaysPlanVM.errorMessage != nil {
                errorRetryContent
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(headline)
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(body_)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(PepTheme.textPrimary.opacity(0.78))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let bundle, !bundle.decisions.isEmpty, !isHistorical {
                    adaptiveBundleStrip(bundle: bundle, callout: adaptiveCallout)
                } else if let callout = adaptiveCallout,
                   !callout.trigger.isEmpty,
                   !callout.recommendation.isEmpty,
                   !isHistorical {
                    // Legacy fallback: render the AI callout if no deterministic
                    // bundle was ingested for some reason.
                    legacyCalloutStrip(callout: callout)
                }

                if let watchFor, !isHistorical || !watchFor.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        Rectangle()
                            .fill(PepTheme.violet)
                            .frame(width: 2)
                            .frame(maxHeight: .infinity)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("WATCH FOR")
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .tracking(1.6)
                                .foregroundStyle(PepTheme.violet.opacity(0.85))
                            Text(watchFor)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(PepTheme.violet.opacity(0.06))
                    .clipShape(.rect(cornerRadius: 8))
                }

                if !isHistorical {
                    chatButton
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
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
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("01")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundStyle(PepTheme.violet)
                    Rectangle()
                        .fill(PepTheme.violet.opacity(0.6))
                        .frame(width: 18, height: 1)
                    Text("DAILY BRIEF")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(2.2)
                        .foregroundStyle(PepTheme.violet)
                    Image(systemName: timeOfDayIcon)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(PepTheme.violet.opacity(0.7))
                }
                Text(isHistorical ? (briefDateLabel ?? greeting) : greeting)
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            Spacer()
            if todaysPlanVM.isLoading || todaysPlanVM.isBackgroundRefreshing || todaysPlanVM.isLoadingHistorical {
                ProgressView().controlSize(.mini).tint(PepTheme.violet)
            } else if !isHistorical {
                Button {
                    onRefresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PepTheme.violet.opacity(0.7))
                        .frame(width: 28, height: 28)
                        .background(PepTheme.violet.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            } else {
                Text("ARCHIVE")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(PepTheme.violet.opacity(0.75))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(PepTheme.violet.opacity(0.12))
                    .clipShape(.capsule)
            }
        }
    }

    private var errorRetryContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PepTheme.amber)
                Text("Couldn\u{2019}t generate your brief")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
            }

            if let msg = todaysPlanVM.errorMessage, !msg.isEmpty {
                Text(msg)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                onRefresh()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .bold))
                    Text("Retry")
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .tracking(1.2)
                }
                .foregroundStyle(PepTheme.violet)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(PepTheme.violet.opacity(0.12))
                .clipShape(.capsule)
                .overlay(
                    Capsule().strokeBorder(PepTheme.violet.opacity(0.22), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .light), trigger: todaysPlanVM.isLoading)
        }
    }

    private var emptyHistoricalContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PepTheme.violet.opacity(0.7))
                Text("No brief saved for this day")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
            }
            Text("Briefs generated from now on are kept in your archive automatically.")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(PepTheme.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var chatButton: some View {
        Button {
            onChatAboutThis(buildPlanContextString())
        } label: {
            HStack(spacing: 10) {
                PepNavAvatar(size: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text("DISCUSS")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.violet.opacity(0.7))
                    Text("Chat about this brief")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PepTheme.violet)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(PepTheme.violet.opacity(0.6))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(PepTheme.violet.opacity(0.08))
            .clipShape(.rect(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(PepTheme.violet.opacity(0.18), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func adaptiveBundleStrip(bundle: AdaptiveAdjustmentService.DailyBundleDecision, callout: AdaptiveCallout?) -> some View {
        let pending = bundle.decisions.filter { $0.state == .pending }
        let accepted = bundle.decisions.filter { $0.state == .accepted }
        let allDecided = pending.isEmpty
        let triggerLabel = (callout?.trigger.isEmpty == false ? callout!.trigger : bundle.trigger).uppercased()

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(PepTheme.amber.opacity(0.18))
                        .frame(width: 22, height: 22)
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(PepTheme.amber)
                }
                Text("TODAY’S ADJUSTMENTS")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(PepTheme.amber)
                Rectangle()
                    .fill(PepTheme.amber.opacity(0.45))
                    .frame(height: 1)
                    .frame(maxWidth: 18)
                Text(triggerLabel)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(PepTheme.amber.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }

            VStack(spacing: 6) {
                ForEach(bundle.decisions, id: \.line.id) { row in
                    bundleLineRow(row: row)
                }
            }

            if !allDecided {
                pulsingScanLine()
                HStack(spacing: 8) {
                    Button {
                        AdaptiveAdjustmentService.shared.acceptAll()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .heavy))
                            Text("APPLY ALL")
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .tracking(1.2)
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(PepTheme.amber)
                        .clipShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.success, trigger: accepted.count)

                    Button {
                        AdaptiveAdjustmentService.shared.dismissAll()
                    } label: {
                        Text("SKIP ALL")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .tracking(1.2)
                            .foregroundStyle(PepTheme.amber.opacity(0.85))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .overlay(
                                Capsule().strokeBorder(PepTheme.amber.opacity(0.35), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)
                }
            } else if !accepted.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(PepTheme.amber)
                    Text("\(accepted.count) adjustment\(accepted.count == 1 ? "" : "s") applied to today")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .tracking(0.6)
                        .foregroundStyle(PepTheme.amber.opacity(0.9))
                    Spacer(minLength: 0)
                    Button {
                        AdaptiveAdjustmentService.shared.undo()
                    } label: {
                        Text("UNDO")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .tracking(1.2)
                            .foregroundStyle(PepTheme.amber.opacity(0.8))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .overlay(
                                Capsule().strokeBorder(PepTheme.amber.opacity(0.3), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(PepTheme.amber.opacity(0.7))
                    Text("Skipped — keeping today as planned")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary.opacity(0.78))
                    Spacer(minLength: 0)
                    Button {
                        AdaptiveAdjustmentService.shared.undo()
                    } label: {
                        Text("RECONSIDER")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(1.2)
                            .foregroundStyle(PepTheme.amber.opacity(0.8))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .overlay(
                                Capsule().strokeBorder(PepTheme.amber.opacity(0.3), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(
            LinearGradient(
                colors: [PepTheme.amber.opacity(0.14), PepTheme.amber.opacity(0.04)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(.rect(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(PepTheme.amber.opacity(0.28), lineWidth: 0.5)
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: bundle)
    }

    @ViewBuilder
    private func bundleLineRow(row: AdaptiveAdjustmentService.LineDecision) -> some View {
        let isPending = row.state == .pending
        let isAccepted = row.state == .accepted
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                Circle()
                    .fill(isAccepted ? PepTheme.amber : PepTheme.amber.opacity(0.16))
                    .frame(width: 18, height: 18)
                Image(systemName: domainIcon(row.line.domain))
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(isAccepted ? Color.black : PepTheme.amber)
            }

            Text(row.line.summary)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(
                    row.state == .dismissed
                        ? PepTheme.textPrimary.opacity(0.45)
                        : PepTheme.textPrimary.opacity(0.92)
                )
                .strikethrough(row.state == .dismissed, color: PepTheme.textPrimary.opacity(0.45))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isPending {
                Button {
                    AdaptiveAdjustmentService.shared.acceptLine(id: row.line.id)
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(PepTheme.amber)
                        .frame(width: 26, height: 26)
                        .background(PepTheme.amber.opacity(0.14))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(weight: .light), trigger: row.state)

                Button {
                    AdaptiveAdjustmentService.shared.dismissLine(id: row.line.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(PepTheme.amber.opacity(0.7))
                        .frame(width: 26, height: 26)
                        .overlay(
                            Circle().strokeBorder(PepTheme.amber.opacity(0.3), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func domainIcon(_ domain: AdaptiveDomain) -> String {
        switch domain {
        case .workout: return "dumbbell.fill"
        case .nutrition: return "fork.knife"
        case .water: return "drop.fill"
        case .steps: return "figure.walk"
        case .dose: return "syringe.fill"
        case .sleep: return "moon.fill"
        case .info: return "info"
        }
    }

    @ViewBuilder
    private func legacyCalloutStrip(callout: AdaptiveCallout) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(PepTheme.amber)
                Text(callout.trigger.uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(PepTheme.amber.opacity(0.85))
                Spacer()
            }
            Text(callout.recommendation)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(PepTheme.amber.opacity(0.08))
        .clipShape(.rect(cornerRadius: 10))
    }

    @ViewBuilder
    private func pulsingScanLine() -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(PepTheme.amber.opacity(0.18))
                    .frame(height: 2)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                PepTheme.amber.opacity(0.0),
                                PepTheme.amber.opacity(0.95),
                                PepTheme.amber.opacity(0.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(60, width * 0.35), height: 2)
                    .offset(x: (width + 60) * pulsePhase - 60)
            }
            .onAppear {
                pulsePhase = 0
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: false)) {
                    pulsePhase = 1
                }
            }
        }
        .frame(height: 2)
    }

    private func buildPlanContextString() -> String {
        var parts: [String] = []
        if let n = narrative {
            parts.append("\(n.headline)\n\(n.body)")
        }
        if !todaysPlanVM.activeSummary.isEmpty {
            parts.append("Summary: \(todaysPlanVM.activeSummary)")
        }
        for module in todaysPlanVM.activeModules {
            parts.append("[\(module.title)] \(module.content)")
        }
        let items = todaysPlanVM.activePlan?.actionItems ?? []
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
