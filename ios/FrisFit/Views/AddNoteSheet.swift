import SwiftUI

struct AddNoteSheet: View {
    @Bindable var viewModel: ProtocolDetailViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Note")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                        Spacer()
                        Text(Date(), style: .date)
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }

                    TextEditor(text: $viewModel.newNoteText)
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 120)
                        .padding(12)
                        .background(PepTheme.elevated)
                        .clipShape(.rect(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Templates")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)

                    FlowLayout(spacing: 8) {
                        ForEach(quickTemplates, id: \.self) { template in
                            Button {
                                if viewModel.newNoteText.isEmpty {
                                    viewModel.newNoteText = template
                                } else {
                                    viewModel.newNoteText += "\n\(template)"
                                }
                            } label: {
                                Text(template)
                                    .font(.system(.caption2, weight: .medium))
                                    .foregroundStyle(PepTheme.textPrimary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(PepTheme.elevated)
                                    .clipShape(.capsule)
                            }
                        }
                    }
                }

                Spacer()

                Button {
                    viewModel.addNote()
                } label: {
                    Text("Save Note")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(PepTheme.invertedText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PepTheme.violet, in: .rect(cornerRadius: 12))
                }
                .buttonStyle(.scalePrimary)
                .disabled(viewModel.newNoteText.isEmpty)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .background(PepTheme.background.ignoresSafeArea())
            .navigationTitle("Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }

    private let quickTemplates = [
        "Felt warmth at injection site",
        "Energy levels higher than usual",
        "Good sleep last night",
        "Appetite noticeably reduced",
        "Slight nausea post-injection",
        "Mood improved",
        "Increased thirst",
    ]
}
