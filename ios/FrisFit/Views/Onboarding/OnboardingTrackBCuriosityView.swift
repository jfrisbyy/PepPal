import SwiftUI
import UIKit

/// Track B equivalent of the protocol chapter — captures research interests so the
/// agent has user-specific seed material on day-1 instead of generic copy.
struct OnboardingTrackBCuriosityView: View {
    let firstName: String
    let onComplete: () -> Void

    @State private var selected: Set<String> = []
    @State private var customTopic: String = ""

    private let suggested: [String] = [
        "GLP-1s & weight loss",
        "Recovery peptides (BPC-157, TB-500)",
        "Growth hormone secretagogues",
        "Longevity protocols",
        "Sleep & HRV optimization",
        "Healing & injury recovery",
        "Cognitive enhancement",
        "How peptide cycles work"
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    chipGrid
                    customField
                    if !pickedTopics.isEmpty {
                        summary
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            }

            footer
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(headline)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text("Pick anything you'd want to dig into. We'll seed your home with starting points so day one isn't generic.")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headline: String {
        let name = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return "What are you curious about?" }
        return "What are you curious about, \(name)?"
    }

    private var chipGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(suggested, id: \.self) { topic in
                chip(topic)
            }
        }
    }

    private func chip(_ topic: String) -> some View {
        let isOn = selected.contains(topic)
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                if isOn { selected.remove(topic) } else { selected.insert(topic) }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(isOn ? PepTheme.teal : PepTheme.textSecondary.opacity(0.4))
                Text(topic)
                    .font(.system(.footnote, weight: .medium))
                    .foregroundStyle(PepTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(isOn ? PepTheme.teal.opacity(0.15) : PepTheme.cardSurface.opacity(0.85))
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isOn ? PepTheme.teal.opacity(0.5) : PepTheme.elevated, lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    private var customField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add your own")
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
            HStack {
                TextField("e.g. tirzepatide microdosing", text: $customTopic)
                    .submitLabel(.done)
                    .onSubmit { commitCustomTopic() }
                if !customTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        commitCustomTopic()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(PepTheme.teal)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(PepTheme.elevated)
            .clipShape(.rect(cornerRadius: 12))
            .foregroundStyle(PepTheme.textPrimary)
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Seeding into your AI memory")
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
            Text(pickedTopics.joined(separator: " · "))
                .font(.footnote)
                .foregroundStyle(PepTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PepTheme.cardSurface.opacity(0.6))
                .clipShape(.rect(cornerRadius: 12))
        }
    }

    private var footer: some View {
        Button {
            commit()
        } label: {
            Text(pickedTopics.isEmpty ? "Skip" : "Save & continue")
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(pickedTopics.isEmpty ? PepTheme.elevated : PepTheme.teal)
                .clipShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var pickedTopics: [String] {
        var all = Array(selected)
        let trimmed = customTopic.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, !all.contains(trimmed) { all.append(trimmed) }
        return all
    }

    private func commitCustomTopic() {
        let trimmed = customTopic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        selected.insert(trimmed)
        customTopic = ""
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func commit() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let topics = pickedTopics
        if !topics.isEmpty {
            OnboardingMemorySeeder.seedTrackBCuriosity(topics: topics, firstName: firstName)
        }
        onComplete()
    }
}
