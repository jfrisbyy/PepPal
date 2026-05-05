import SwiftUI

/// Debug-only view that lists every fact currently in AIMemoryStore for the
/// active user, including muted/expired ones. Used to verify the onboarding
/// memory seeder wrote the expected facts before the home screen renders.
struct AIMemoryDebugView: View {
    @State private var memory = AIMemoryStore.shared
    @State private var query: String = ""

    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    Label("\(memory.facts.count) total facts", systemImage: "brain")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(memory.allFacts().count) active")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(filteredFacts) { fact in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: fact.kind.icon)
                            .font(.caption2)
                            .foregroundStyle(.tint)
                        Text(fact.kind.label)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tint)
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(fact.domain)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if fact.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                        if fact.isMuted {
                            Image(systemName: "speaker.slash.fill")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                        Text("\(Int(fact.confidence * 100))%")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Text(fact.headline)
                        .font(.subheadline.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                    if !fact.detail.isEmpty {
                        Text(fact.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(spacing: 8) {
                        if let exp = fact.expiresAt {
                            Text("exp \(exp, format: .dateTime.month().day())")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text("×\(fact.reinforceCount)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .searchable(text: $query, prompt: "Search facts")
        .navigationTitle("AI Memory Debug")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        memory.clearAll()
                    } label: {
                        Label("Clear all facts", systemImage: "trash")
                    }
                    Button {
                        Task { _ = await CorrelationEngine.shared.run(force: true) }
                    } label: {
                        Label("Run correlations now", systemImage: "arrow.triangle.2.circlepath")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private var filteredFacts: [AIMemoryFact] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return memory.facts }
        return memory.facts.filter {
            $0.headline.lowercased().contains(q)
            || $0.detail.lowercased().contains(q)
            || $0.domain.lowercased().contains(q)
        }
    }
}
