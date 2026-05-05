import SwiftUI

struct TitrationTemplatePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let compoundName: String?
    let onSelectTemplate: (TitrationTemplate) -> Void
    let onBuildCustom: () -> Void

    init(
        compoundName: String? = nil,
        onSelectTemplate: @escaping (TitrationTemplate) -> Void,
        onBuildCustom: @escaping () -> Void = {}
    ) {
        self.compoundName = compoundName
        self.onSelectTemplate = onSelectTemplate
        self.onBuildCustom = onBuildCustom
    }

    private var filtered: [TitrationTemplate] {
        guard let name = compoundName, !name.isEmpty else { return TitrationTemplateLibrary.all }
        let match = TitrationTemplateLibrary.templates(for: name)
        return match.isEmpty ? TitrationTemplateLibrary.all : match
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Titration Schedule")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("Pick a ladder or build your own — we'll save it, remind you, and step you up.")
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        onBuildCustom()
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(PepTheme.teal)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Build Custom Schedule")
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                    .foregroundStyle(PepTheme.textPrimary)
                                Text("Set your own weeks, doses, and hold periods")
                                    .font(.caption)
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption).foregroundStyle(PepTheme.textSecondary.opacity(0.6))
                        }
                        .padding(14)
                        .background(PepTheme.teal.opacity(0.12), in: .rect(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(PepTheme.teal.opacity(0.35), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    ForEach(filtered) { template in
                        Button {
                            onSelectTemplate(template)
                            dismiss()
                        } label: {
                            templateCard(template)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .navigationTitle("Titration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func templateCard(_ t: TitrationTemplate) -> some View {
        GlassCard(accent: PepTheme.teal) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(t.name)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                    Text(t.compound)
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(PepTheme.teal)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(PepTheme.teal.opacity(0.15), in: .capsule)
                }
                HStack(spacing: 0) {
                    ForEach(Array(t.steps.enumerated()), id: \.offset) { idx, step in
                        VStack(spacing: 4) {
                            Text("W\(step.week)")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(PepTheme.textSecondary)
                            Text(formatDose(step.doseMcg, for: t.compound))
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .foregroundStyle(PepTheme.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        if idx < t.steps.count - 1 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                        }
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
                .background(PepTheme.elevated.opacity(0.5), in: .rect(cornerRadius: 10))

                Text(t.notes)
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)

                HStack(spacing: 8) {
                    Text("Tap to apply")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(PepTheme.teal)
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.caption)
                        .foregroundStyle(PepTheme.teal)
                }
            }
        }
    }

    private func formatDose(_ mcg: Double, for compound: String) -> String {
        CompoundUnitHelper.displayDoseShort(mcg, for: compound)
    }
}
