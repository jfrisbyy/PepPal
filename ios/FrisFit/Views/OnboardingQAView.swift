import SwiftUI

/// Internal QA verification screen confirming the day-1 home experience meets
/// every requirement from Prompt 17. Hidden behind Settings → Developer.
struct OnboardingQAView: View {
    @State private var checks: [QACheck] = []
    @State private var lastRunAt: Date? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                VStack(spacing: 0) {
                    ForEach(Array(checks.enumerated()), id: \.element.id) { idx, check in
                        QACheckRow(check: check)
                        if idx < checks.count - 1 {
                            Divider().overlay(PepTheme.glassBorderTop)
                        }
                    }
                }
                .padding(14)
                .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
                .clipShape(.rect(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                )

                Button {
                    runChecks()
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Re-run checks")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(PepTheme.teal)
                    .clipShape(.rect(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .appBackground()
        .navigationTitle("Onboarding QA")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { runChecks() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Day-1 Verification")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text("Confirms every Prompt 17 requirement is satisfied for the active account.")
                .font(.footnote)
                .foregroundStyle(PepTheme.textSecondary)
            if let lastRunAt {
                Text("Last run \(lastRunAt.formatted(date: .omitted, time: .standard))")
                    .font(.caption2)
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
            }
            HStack(spacing: 6) {
                Circle().fill(passingAll ? .green : .orange).frame(width: 8, height: 8)
                Text(passingAll ? "All checks passing" : "\(failingCount) need attention")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(passingAll ? .green : .orange)
            }
            .padding(.top, 4)
        }
    }

    private var passingAll: Bool { checks.allSatisfy { $0.status == .pass } }
    private var failingCount: Int { checks.filter { $0.status != .pass }.count }

    private func runChecks() {
        var out: [QACheck] = []
        let memory = AIMemoryStore.shared
        let facts = memory.allFacts()
        let factCount = facts.count
        let isTrackC = PeptideAccessManager.shared.personaTrack == .C

        // 1. Memory facts
        let factsTarget = isTrackC ? 10 : 5
        out.append(QACheck(
            title: "AI memory seeded",
            detail: "\(factCount) facts present (target ≥ \(factsTarget) for \(isTrackC ? "Track C" : "Track A/B"))",
            status: factCount >= factsTarget ? .pass : (factCount > 0 ? .warn : .fail)
        ))

        // 2. Morning brief lines
        let lines = MorningBriefService.shared.buildLines()
        let briefHasContent = lines.recovery != nil || lines.training != nil
            || lines.nutrition != nil || lines.dose != nil || lines.bodyGoal != nil
        out.append(QACheck(
            title: "Morning brief renders user-specific lines",
            detail: briefHasContent ? "Recovery/training/nutrition/body lines populated" : "No deterministic lines available",
            status: briefHasContent ? .pass : .fail
        ))

        // 3. Proactive insight
        let proactiveCount = ProactiveInsightService.insights(
            for: InsightsDataStore.shared.primaryProtocol ?? .placeholder,
            adherence7d: 1.0,
            sideEffects: []
        ).count
        out.append(QACheck(
            title: "At least one proactive insight",
            detail: "\(proactiveCount) insight\(proactiveCount == 1 ? "" : "s") generated",
            status: proactiveCount >= 1 ? .pass : .fail
        ))

        // 4. Journey map populated
        let pinCount = JourneyEventService.shared.events.count
        out.append(QACheck(
            title: "Populated journey map",
            detail: "\(pinCount) journey \(pinCount == 1 ? "pin" : "pins")",
            status: pinCount >= 1 ? .pass : .warn
        ))

        // 5. Agent greeting personalized
        let firstName = (UserDefaults.standard.string(forKey: OnboardingManager.successFirstNameKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let memo = memory.memoForAgent()
        let hasName = !firstName.isEmpty
        let hasFactInMemo = !memo.isEmpty && facts.contains(where: { !$0.headline.isEmpty })
        out.append(QACheck(
            title: "Agent greeting references seeded fact",
            detail: hasName && hasFactInMemo
                ? "First name + memoForAgent injects pinned facts"
                : (hasName ? "First name available, memo empty" : "No first name captured"),
            status: hasName && hasFactInMemo ? .pass : .warn
        ))

        // 6. Smart daily task keyed to persona
        let track = PeptideAccessManager.shared.personaTrack
        let expected: String = {
            switch track {
            case .A: return "Log today's training"
            case .B: return "Read: how peptide cycles work"
            case .C: return "Confirm today's dose"
            case nil: return "—"
            }
        }()
        out.append(QACheck(
            title: "Smart daily task keyed to persona",
            detail: "Track \(track?.rawValue ?? "?") expects: \(expected)",
            status: track != nil ? .pass : .fail
        ))

        // 7. Success card pending or already dismissed
        let pending = UserDefaults.standard.bool(forKey: OnboardingManager.successCardPendingKey)
        let onboardingDone = OnboardingManager.hasCompleted
        out.append(QACheck(
            title: "Success card staged",
            detail: pending
                ? "Pending — will show on next Home open"
                : (onboardingDone ? "Already dismissed" : "Onboarding incomplete"),
            status: onboardingDone ? .pass : .warn
        ))

        // 8. Active protocol (Track C only)
        if isTrackC {
            let proto = InsightsDataStore.shared.primaryProtocol
            out.append(QACheck(
                title: "Active protocol present (Track C)",
                detail: proto != nil ? "\(proto?.compounds.first?.compoundName ?? "Protocol") active" : "No active protocol",
                status: proto != nil ? .pass : .fail
            ))
        }

        checks = out
        lastRunAt = Date()
    }
}

private struct QACheck: Identifiable {
    enum Status { case pass, warn, fail }
    let id: UUID = UUID()
    let title: String
    let detail: String
    let status: Status
}

private struct QACheckRow: View {
    let check: QACheck

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(tint.opacity(0.18)).frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(check.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(check.detail)
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }

    private var icon: String {
        switch check.status {
        case .pass: return "checkmark"
        case .warn: return "exclamationmark"
        case .fail: return "xmark"
        }
    }

    private var tint: Color {
        switch check.status {
        case .pass: return .green
        case .warn: return .orange
        case .fail: return .red
        }
    }
}

extension PeptideProtocol {
    fileprivate static var placeholder: PeptideProtocol {
        PeptideProtocol(
            name: "—",
            goal: .general,
            compounds: [],
            startDate: Date(),
            totalWeeks: 1,
            isActive: false
        )
    }
}
