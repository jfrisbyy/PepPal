import SwiftUI

struct AIMemoryView: View {
    @State private var memory = AIMemoryStore.shared
    @State private var showClearConfirm: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerCard
                toggleCard
                factsSection
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .appBackground()
        .navigationTitle("AI Memory")
        .navigationBarTitleDisplayMode(.large)
        .alert("Clear AI memory?", isPresented: $showClearConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Clear everything", role: .destructive) { memory.clearAll() }
        } message: {
            Text("This erases every pattern, correlation, and preference the app has learned about you. The app will rebuild memory over time as you keep logging.")
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "brain")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PepTheme.violet)
                    .frame(width: 32, height: 32)
                    .background(PepTheme.violet.opacity(0.12))
                    .clipShape(Circle())
                Text("What the app remembers")
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            Text("Every pattern, correlation, and preference learned about you. Pin what matters, mute what doesn't. Memory persists across devices and app rebuilds.")
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

    private var toggleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: Binding(
                get: { memory.isEnabled },
                set: { memory.setEnabled($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI memory enabled")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Disabling stops the app from learning new patterns.")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            .tint(PepTheme.teal)

            Divider().overlay(PepTheme.glassBorderTop)

            Button(role: .destructive) {
                showClearConfirm = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Clear all memory")
                    Spacer()
                }
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(.red)
            }
        }
        .padding(14)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private var factsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MEMORY (\(memory.allFacts().count))")
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))

            if memory.allFacts().isEmpty {
                Text("No memory yet. The app learns as you log data.")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PepTheme.cardSurface)
                    .clipShape(.rect(cornerRadius: 14))
            } else {
                ForEach(memory.allFacts()) { fact in
                    factRow(fact)
                }
            }
        }
    }

    private func factRow(_ fact: AIMemoryFact) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: fact.kind.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PepTheme.violet)
                Text(fact.kind.label)
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.5)
                    .foregroundStyle(PepTheme.textSecondary)
                Text("·")
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                Text(fact.domain.capitalized)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                if fact.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(PepTheme.amber)
                }
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
                Button { memory.pin(fact.id, pinned: !fact.isPinned) } label: {
                    Text(fact.isPinned ? "Unpin" : "Pin")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PepTheme.violet)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(PepTheme.violet.opacity(0.1))
                        .clipShape(.capsule)
                }
                .buttonStyle(.plain)
                Button { memory.delete(fact.id) } label: {
                    Text("Forget")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .clipShape(.capsule)
                }
                .buttonStyle(.plain)
                Spacer()
                Text("\(Int(fact.confidence * 100))% · \(fact.reinforceCount)x")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .padding(12)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }
}
