import SwiftUI

struct InsightsView: View {
    @State private var viewModel = InsightsViewModel.shared
    @State private var selectedInsight: AgentInsight?
    @FocusState private var askFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerCaption
                    if viewModel.isInvestigating && viewModel.investigation == nil {
                        loadingState
                    } else if let hero = viewModel.hero {
                        HeroInsightCard(insight: hero) {
                            selectedInsight = hero
                        }
                    } else if viewModel.lastError != nil {
                        errorState
                    } else {
                        emptyHero
                    }

                    if !viewModel.impact.isEmpty {
                        protocolImpactSection
                    }

                    if !viewModel.patterns.isEmpty {
                        patternsSection
                    }

                    ForecastSection()

                    PatternsSection()

                    askSection
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .refreshable {
                viewModel.refreshIfNeeded(force: true)
                try? await Task.sleep(for: .milliseconds(600))
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.refreshIfNeeded(force: true)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                            .frame(width: 32, height: 32)
                            .background(PepTheme.cardSurface)
                            .clipShape(.circle)
                            .overlay(Circle().strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5))
                            .opacity(viewModel.isInvestigating ? 0.5 : 1)
                    }
                    .disabled(viewModel.isInvestigating)
                }
            }
            .onAppear {
                viewModel.refreshIfNeeded()
            }
            .sheet(item: $selectedInsight) { insight in
                InsightDetailSheet(insight: insight)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: viewModel.investigation?.generatedAt)
        }
    }

    private var headerCaption: some View {
        HStack(spacing: 8) {
            if viewModel.isInvestigating && viewModel.investigation != nil {
                ProgressView().controlSize(.mini).tint(PepTheme.teal)
                Text("Refreshing insights…")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            } else if viewModel.dataPointsChecked > 0 {
                Text("\(viewModel.dataPointsChecked) data point\(viewModel.dataPointsChecked == 1 ? "" : "s") checked across your protocol, training, nutrition and recovery.")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            } else {
                Text("Cross-domain insights from your protocol, training, nutrition and Apple Health.")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()
        }
        .padding(.top, 4)
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView().tint(PepTheme.teal)
            Text("Investigating your data…")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
            Text("Pulling HRV trends, training volume, nutrition patterns, and protocol timing.")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 20))
    }

    private var errorState: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.orange)
            Text(viewModel.lastError ?? "Insights unavailable.")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textPrimary)
            Button("Try again") {
                viewModel.refreshIfNeeded(force: true)
            }
            .buttonStyle(.borderedProminent)
            .tint(PepTheme.teal)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 20))
    }

    private var emptyHero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Log your first day of data")
                .font(.headline)
                .foregroundStyle(PepTheme.textPrimary)
            Text("Once you have a logged meal, a workout, and a dose, the AI can start surfacing cross-domain insights.")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 20))
    }

    private var protocolImpactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeader(eyebrow: "Protocol Impact")
            VStack(spacing: 10) {
                ForEach(viewModel.impact) { metric in
                    ProtocolImpactRow(metric: metric)
                }
            }
        }
    }

    private var patternsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeader(eyebrow: "Patterns")
            VStack(spacing: 10) {
                ForEach(viewModel.patterns) { insight in
                    Button {
                        selectedInsight = insight
                    } label: {
                        PatternRow(insight: insight)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var askSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeader(eyebrow: "Ask")
            HStack(spacing: 10) {
                TextField("Am I losing muscle? Is my deficit too aggressive?", text: $viewModel.askInput, axis: .vertical)
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1...3)
                    .focused($askFocused)
                    .submitLabel(.send)
                    .onSubmit { Task { await viewModel.ask() } }
                Button {
                    Task { await viewModel.ask() }
                    askFocused = false
                } label: {
                    Image(systemName: viewModel.isAsking ? "ellipsis.circle.fill" : "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(viewModel.askInput.trimmingCharacters(in: .whitespaces).isEmpty ? PepTheme.textSecondary.opacity(0.5) : PepTheme.teal)
                }
                .disabled(viewModel.askInput.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isAsking)
            }
            .padding(14)
            .background(PepTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
            )

            if !viewModel.askTurns.isEmpty {
                VStack(spacing: 10) {
                    ForEach(viewModel.askTurns) { turn in
                        AskTurnCard(turn: turn)
                    }
                }
            }
        }
    }
}

struct HeroInsightCard: View {
    let insight: AgentInsight
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                        Text("AI INSIGHT")
                            .font(.system(.caption2, design: .rounded, weight: .heavy))
                            .tracking(1.2)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(insight.domain.color)
                    .clipShape(.capsule)

                    Spacer()

                    Text(insight.domain.label.uppercased())
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(insight.domain.color)
                }

                Text(insight.headline)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(insight.body)
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if !insight.evidence.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(insight.domain.color)
                        Text("\(insight.evidence.count) data point\(insight.evidence.count == 1 ? "" : "s") checked")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                        Spacer()
                        HStack(spacing: 4) {
                            Text("View evidence")
                                .font(.caption.weight(.semibold))
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                        }
                        .foregroundStyle(insight.domain.color)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [insight.domain.color.opacity(0.18), insight.domain.color.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background(PepTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(insight.domain.color.opacity(0.35), lineWidth: 0.8)
            )
            .shadow(color: insight.domain.color.opacity(0.15), radius: 16, y: 6)
        }
        .buttonStyle(.plain)
    }
}

private struct ProtocolImpactRow: View {
    let metric: ProtocolImpactMetric

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 2)
                .fill(metric.domain.color)
                .frame(width: 3, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(metric.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(metric.takeaway)
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Text(metric.baselineValue)
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(PepTheme.textSecondary)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
                    Text(metric.currentValue)
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(PepTheme.textPrimary)
                }
                if let d = metric.deltaPercent {
                    Text(String(format: "%+.1f%%", d))
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(deltaColor(direction: metric.direction))
                }
            }
        }
        .padding(14)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private func deltaColor(direction: ProtocolImpactMetric.Direction) -> Color {
        switch direction {
        case .up: return .green
        case .down: return .red
        case .mixed: return PepTheme.amber
        case .flat: return PepTheme.textSecondary
        }
    }
}

private struct PatternRow: View {
    let insight: AgentInsight
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(insight.domain.color)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.headline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                Text(insight.body)
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }
}

private struct AskTurnCard: View {
    let turn: AgentAskTurn
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.fill")
                    .foregroundStyle(PepTheme.textSecondary)
                Text(turn.question)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            if turn.isStreaming {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.mini).tint(PepTheme.teal)
                    Text("Investigating…")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            } else {
                Text(turn.answer)
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if !turn.evidence.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Based on:")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                        ForEach(turn.evidence) { e in
                            HStack(spacing: 6) {
                                Circle().fill(PepTheme.teal).frame(width: 4, height: 4)
                                Text("\(e.label): ")
                                    .font(.caption2)
                                    .foregroundStyle(PepTheme.textSecondary) +
                                Text(e.value)
                                    .font(.caption2.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(PepTheme.textPrimary)
                            }
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PepTheme.teal.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 10))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }
}

struct InsightDetailSheet: View {
    let insight: AgentInsight
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 8) {
                        Image(systemName: insight.domain.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(insight.domain.color)
                        Text(insight.domain.label.uppercased())
                            .font(.system(.caption, design: .rounded, weight: .heavy))
                            .tracking(1.4)
                            .foregroundStyle(insight.domain.color)
                    }

                    Text(insight.headline)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(insight.body)
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !insight.evidence.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Evidence")
                                .font(.system(.headline, design: .rounded))
                                .foregroundStyle(PepTheme.textPrimary)
                            ForEach(insight.evidence) { e in
                                EvidenceRow(point: e, tint: insight.domain.color)
                            }
                        }
                    }

                    if !insight.actions.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("What to try")
                                .font(.system(.headline, design: .rounded))
                                .foregroundStyle(PepTheme.textPrimary)
                            ForEach(Array(insight.actions.enumerated()), id: \.offset) { _, a in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "arrow.up.right.circle.fill")
                                        .foregroundStyle(insight.domain.color)
                                        .padding(.top, 2)
                                    Text(a)
                                        .font(.subheadline)
                                        .foregroundStyle(PepTheme.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(insight.domain.color.opacity(0.08))
                                .clipShape(.rect(cornerRadius: 12))
                            }
                        }
                    }

                    if insight.providerFlag {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "stethoscope")
                                .foregroundStyle(.red)
                            Text("This is something worth discussing with your healthcare provider.")
                                .font(.caption)
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.08))
                        .clipShape(.rect(cornerRadius: 12))
                    }
                }
                .padding(20)
            }
            .appBackground()
            .navigationTitle("Insight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .tint(PepTheme.teal)
                }
            }
        }
    }
}

private struct EvidenceRow: View {
    let point: EvidencePoint
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            VStack {
                Circle().fill(tint).frame(width: 8, height: 8)
                Rectangle().fill(tint.opacity(0.2)).frame(width: 1)
            }
            .frame(width: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(point.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                Text(point.value)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                if let d = point.detail {
                    Text(d)
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.8))
                }
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }
}

