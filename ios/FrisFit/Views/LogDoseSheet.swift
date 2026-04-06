import SwiftUI

struct LogDoseSheet: View {
    @Bindable var viewModel: ProtocolDetailViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.protocolData.compounds.count > 1 {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Compound")
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(PepTheme.textSecondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(viewModel.protocolData.compounds) { compound in
                                        let isSelected = viewModel.newDoseCompound == compound.compoundName
                                        Button {
                                            viewModel.newDoseCompound = compound.compoundName
                                            viewModel.newDoseMcg = "\(Int(compound.doseMcg))"
                                        } label: {
                                            Text(compound.compoundName)
                                                .font(.system(.subheadline, weight: .semibold))
                                                .foregroundStyle(isSelected ? PepTheme.invertedText : PepTheme.textPrimary)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(isSelected ? PepTheme.teal : PepTheme.elevated)
                                                .clipShape(.capsule)
                                        }
                                    }
                                }
                            }
                            .contentMargins(.horizontal, 0)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Dose Amount")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)

                        HStack {
                            TextField("250", text: $viewModel.newDoseMcg)
                                .font(.system(.title2, design: .rounded, weight: .bold))
                                .foregroundStyle(PepTheme.textPrimary)
                                .keyboardType(.decimalPad)
                            Text("mcg")
                                .font(.system(.subheadline, weight: .medium))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        .padding(14)
                        .background(PepTheme.elevated)
                        .clipShape(.rect(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Injection Site")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(InjectionSite.allCases) { site in
                                let isSelected = viewModel.newDoseSite == site
                                let recency = viewModel.siteRecency(site)
                                Button {
                                    viewModel.newDoseSite = site
                                } label: {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(recency.color)
                                            .frame(width: 8, height: 8)
                                        Text(site.shortName)
                                            .font(.system(.caption, weight: .semibold))
                                            .foregroundStyle(isSelected ? PepTheme.invertedText : PepTheme.textPrimary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(isSelected ? PepTheme.teal : PepTheme.elevated)
                                    .clipShape(.rect(cornerRadius: 10))
                                }
                            }
                        }

                        HStack(spacing: 6) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(PepTheme.teal)
                            Text("Suggested: \(viewModel.suggestedNextSite.rawValue)")
                                .font(.system(.caption2, weight: .medium))
                                .foregroundStyle(PepTheme.teal)
                        }
                        .padding(.top, 4)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes (Optional)")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)

                        TextField("e.g., felt slight warmth at site...", text: $viewModel.newDoseNotes, axis: .vertical)
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textPrimary)
                            .lineLimit(3...5)
                            .padding(12)
                            .background(PepTheme.elevated)
                            .clipShape(.rect(cornerRadius: 12))
                    }

                    Button {
                        viewModel.logDose()
                    } label: {
                        Text("Log Dose")
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(PepTheme.invertedText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(PepTheme.teal, in: .rect(cornerRadius: 12))
                    }
                    .buttonStyle(.scalePrimary)
                    .disabled(viewModel.newDoseMcg.isEmpty)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(PepTheme.background.ignoresSafeArea())
            .navigationTitle("Log Dose")
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
