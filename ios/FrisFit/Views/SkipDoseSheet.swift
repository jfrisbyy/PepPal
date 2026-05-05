import SwiftUI

struct SkipDoseSheet: View {
    @Bindable var viewModel: ProtocolDetailViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "forward.fill")
                            .font(.title3)
                            .foregroundStyle(PepTheme.amber)
                        Text("Skip this dose?")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                    }
                    Text("Skipping still counts for adherence tracking — it won't look like you forgot.")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Reason")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)

                    FlowLayout(spacing: 8) {
                        ForEach(viewModel.skipReasons, id: \.self) { reason in
                            let isSelected = viewModel.skipReason == reason
                            Button {
                                viewModel.skipReason = reason
                            } label: {
                                Text(reason)
                                    .font(.system(.caption, weight: .semibold))
                                    .foregroundStyle(isSelected ? PepTheme.invertedText : PepTheme.textPrimary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(isSelected ? PepTheme.amber : PepTheme.elevated)
                                    .clipShape(.capsule)
                            }
                        }
                    }
                }

                Spacer()

                Button {
                    viewModel.skipDose()
                } label: {
                    Text("Mark as Skipped")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(PepTheme.invertedText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PepTheme.amber, in: .rect(cornerRadius: 12))
                }
                .buttonStyle(.scalePrimary)
                .disabled(viewModel.skipReason.isEmpty)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .appBackground()
            .navigationTitle("Skip Dose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }
}
