import SwiftUI

/// "Patterns about you" — long-lived memory facts the app has accumulated,
/// surfaced on the Insights tab. Pinning a pattern keeps it in the briefing
/// loop forever; muting it stops the AI from referencing it.
struct PatternsSection: View {
    @State private var memory = AIMemoryStore.shared
    @State private var selectedKinds: Set<AIMemoryFact.Kind> = []

    private var filteredFacts: [AIMemoryFact] {
        let all = memory.allFacts()
        guard !selectedKinds.isEmpty else { return all }
        return all.filter { selectedKinds.contains($0.kind) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader
            if memory.allFacts().isEmpty {
                emptyState
            } else {
                kindsFilter
                VStack(spacing: 8) {
                    ForEach(filteredFacts) { fact in
                        PatternCard(fact: fact, onPin: {
                            memory.pin(fact.id, pinned: !fact.isPinned)
                        }, onMute: {
                            memory.mute(fact.id, muted: true)
                        })
                    }
                }
            }
        }
    }

    private var sectionHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "brain")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PepTheme.violet)
            Text("PATTERNS ABOUT YOU")
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.8))
            Spacer()
            Button {
                Task { _ = await CorrelationEngine.shared.run(force: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PepTheme.violet.opacity(0.7))
                    .frame(width: 22, height: 22)
                    .background(PepTheme.violet.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var kindsFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(AIMemoryFact.Kind.allCases, id: \.self) { kind in
                    let isSelected = selectedKinds.contains(kind)
                    Button {
                        if isSelected { selectedKinds.remove(kind) }
                        else { selectedKinds.insert(kind) }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: kind.icon)
                                .font(.system(size: 9, weight: .semibold))
                            Text(kind.label)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(isSelected ? PepTheme.invertedText : PepTheme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isSelected ? PepTheme.violet : PepTheme.elevated)
                        .clipShape(.capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .contentMargins(.horizontal, 2)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No patterns yet")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
            Text("As you log data over the coming weeks, the app will surface patterns it notices about you here — patterns that persist across app rebuilds.")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }
}

private struct PatternCard: View {
    let fact: AIMemoryFact
    let onPin: () -> Void
    let onMute: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: fact.kind.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PepTheme.violet)
                    .frame(width: 24, height: 24)
                    .background(PepTheme.violet.opacity(0.12))
                    .clipShape(Circle())
                Text(fact.kind.label.uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.6)
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                if fact.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(PepTheme.amber)
                }
                Spacer()
                Text("\(Int(fact.confidence * 100))%")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Text(fact.headline)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if !fact.detail.isEmpty {
                Text(fact.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Button {
                    onPin()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: fact.isPinned ? "pin.slash" : "pin")
                            .font(.system(size: 10, weight: .semibold))
                        Text(fact.isPinned ? "Unpin" : "Pin")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(PepTheme.violet)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(PepTheme.violet.opacity(0.1))
                    .clipShape(.capsule)
                }
                .buttonStyle(.plain)

                Button {
                    onMute()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                        Text("Not useful")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(PepTheme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(PepTheme.elevated)
                    .clipShape(.capsule)
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(12)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }
}
