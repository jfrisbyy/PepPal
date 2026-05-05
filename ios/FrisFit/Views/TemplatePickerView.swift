import SwiftUI

struct TemplatePickerView: View {
    @Bindable var viewModel: TrainViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTemplate: ProgramTemplateSplit? = nil
    @State private var showDetail: Bool = false
    @State private var hoveredIndex: Int? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerPill

                    ForEach(Array(ProgramTemplateSplit.allCases.enumerated()), id: \.element.id) { index, split in
                        templateCard(split, index: index)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .appBackground()
            .navigationTitle("Program Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            .navigationDestination(isPresented: $showDetail) {
                if let template = selectedTemplate {
                    TemplateDetailView(split: template, viewModel: viewModel) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var headerPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 11))
                .foregroundStyle(.green)
            Text("All templates use exercises from your library")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(PepTheme.elevated)
        .clipShape(Capsule())
        .padding(.top, 8)
    }

    private func templateCard(_ split: ProgramTemplateSplit, index: Int) -> some View {
        Button {
            selectedTemplate = split
            showDetail = true
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: gradientForIndex(index),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 52, height: 52)

                        Image(systemName: split.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(split.rawValue)
                            .font(.headline)
                            .foregroundStyle(PepTheme.textPrimary)

                        Text(split.subtitle)
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)

                        HStack(spacing: 6) {
                            audienceBadge(split.targetAudience)
                            ForEach(split.focusTags.prefix(2), id: \.self) { tag in
                                tagPill(tag, color: gradientForIndex(index)[0])
                            }
                        }
                        .padding(.top, 2)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .padding(.top, 4)
                }
                .padding(16)

                Rectangle()
                    .fill(PepTheme.glassBorderTop)
                    .frame(height: 0.5)
                    .padding(.horizontal, 16)

                Text(split.description)
                    .font(.system(size: 13))
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineSpacing(2)
                    .padding(16)
                    .padding(.top, -4)
            }
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func audienceBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(PepTheme.textPrimary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(PepTheme.elevated)
            .clipShape(Capsule())
    }

    private func tagPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }

    private func gradientForIndex(_ index: Int) -> [Color] {
        let palettes: [[Color]] = [
            [PepTheme.teal, PepTheme.teal.opacity(0.6)],
            [PepTheme.blue, PepTheme.blue.opacity(0.6)],
            [PepTheme.violet, PepTheme.violet.opacity(0.6)],
            [.green, .green.opacity(0.6)],
            [PepTheme.amber, PepTheme.amber.opacity(0.6)],
            [.orange, .orange.opacity(0.6)],
        ]
        return palettes[index % palettes.count]
    }
}
