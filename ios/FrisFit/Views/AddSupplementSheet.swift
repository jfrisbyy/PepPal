import SwiftUI

struct AddSupplementSheet: View {
    @Bindable var viewModel: ProtocolDetailViewModel
    @Environment(\.dismiss) private var dismiss

    private let frequencies = ["Daily", "Twice Daily", "Weekly", "As Needed"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Supplement Name")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)

                    TextField("e.g., NAC, Vitamin D3...", text: $viewModel.newSupplementName)
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textPrimary)
                        .padding(12)
                        .background(PepTheme.elevated)
                        .clipShape(.rect(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Dose")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)

                    TextField("e.g., 600mg, 5000 IU...", text: $viewModel.newSupplementDose)
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textPrimary)
                        .padding(12)
                        .background(PepTheme.elevated)
                        .clipShape(.rect(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Frequency")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)

                    HStack(spacing: 8) {
                        ForEach(frequencies, id: \.self) { freq in
                            let isSelected = viewModel.newSupplementFrequency == freq
                            Button {
                                viewModel.newSupplementFrequency = freq
                            } label: {
                                Text(freq)
                                    .font(.system(.caption, weight: .semibold))
                                    .foregroundStyle(isSelected ? PepTheme.invertedText : PepTheme.textPrimary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(isSelected ? PepTheme.teal : PepTheme.elevated)
                                    .clipShape(.capsule)
                            }
                        }
                    }
                }

                Spacer()

                Button {
                    viewModel.addSupplement()
                } label: {
                    Text("Add Supplement")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(PepTheme.invertedText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PepTheme.teal, in: .rect(cornerRadius: 12))
                }
                .buttonStyle(.scalePrimary)
                .disabled(viewModel.newSupplementName.isEmpty)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .background(PepTheme.background.ignoresSafeArea())
            .navigationTitle("Add Supplement")
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
