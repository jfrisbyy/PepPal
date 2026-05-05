import SwiftUI

struct LogSideEffectSheet: View {
    @Bindable var viewModel: ProtocolDetailViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Common Side Effects")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)

                        FlowLayout(spacing: 8) {
                            ForEach(viewModel.commonSideEffects, id: \.self) { effect in
                                let isSelected = viewModel.newEffectName == effect
                                Button {
                                    viewModel.newEffectName = effect
                                } label: {
                                    Text(effect)
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

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Or enter custom")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)

                        TextField("Side effect name...", text: $viewModel.newEffectName)
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textPrimary)
                            .padding(12)
                            .background(PepTheme.elevated)
                            .clipShape(.rect(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Severity")
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(PepTheme.textSecondary)
                            Spacer()
                            Text(severityLabel)
                                .font(.system(.caption, weight: .bold))
                                .foregroundStyle(severityColor)
                        }

                        HStack(spacing: 6) {
                            ForEach(1...4, id: \.self) { level in
                                let isSelected = viewModel.newEffectSeverity == level
                                Button {
                                    viewModel.newEffectSeverity = level
                                } label: {
                                    VStack(spacing: 4) {
                                        Circle()
                                            .fill(isSelected ? colorForSeverity(level) : PepTheme.elevated)
                                            .frame(width: 36, height: 36)
                                            .overlay {
                                                Text("\(level)")
                                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                                    .foregroundStyle(isSelected ? .white : PepTheme.textSecondary)
                                            }
                                        Text(labelForSeverity(level))
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(PepTheme.textSecondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes (Optional)")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)

                        TextField("Any additional details...", text: $viewModel.newEffectNotes, axis: .vertical)
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textPrimary)
                            .lineLimit(3...5)
                            .padding(12)
                            .background(PepTheme.elevated)
                            .clipShape(.rect(cornerRadius: 12))
                    }

                    Button {
                        viewModel.logSideEffect()
                    } label: {
                        Text("Log Side Effect")
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(PepTheme.invertedText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(PepTheme.amber, in: .rect(cornerRadius: 12))
                    }
                    .buttonStyle(.scalePrimary)
                    .disabled(viewModel.newEffectName.isEmpty)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .navigationTitle("Log Side Effect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }

    private var severityLabel: String {
        labelForSeverity(viewModel.newEffectSeverity)
    }

    private var severityColor: Color {
        colorForSeverity(viewModel.newEffectSeverity)
    }

    private func labelForSeverity(_ level: Int) -> String {
        switch level {
        case 1: return "Mild"
        case 2: return "Moderate"
        case 3: return "Significant"
        default: return "Severe"
        }
    }

    private func colorForSeverity(_ level: Int) -> Color {
        switch level {
        case 1: return .green
        case 2: return .yellow
        case 3: return .orange
        default: return .red
        }
    }
}

struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
