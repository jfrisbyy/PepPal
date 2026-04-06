import SwiftUI

struct ProgramSetupStep: View {
    @Bindable var viewModel: TrainViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("PROGRAM NAME")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(FrisTheme.textSecondary)
                        .tracking(1)

                    TextField("", text: $viewModel.programName, prompt: Text("e.g. Push Pull Legs").foregroundStyle(FrisTheme.textSecondary.opacity(0.5)))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(FrisTheme.textPrimary)
                        .padding(16)
                        .background(FrisTheme.elevated)
                        .clipShape(.rect(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(
                                    viewModel.programName.isEmpty ? FrisTheme.glassBorderTop : FrisTheme.cyan.opacity(0.4),
                                    lineWidth: 1
                                )
                        )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("PROGRAM TYPE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(FrisTheme.textSecondary)
                        .tracking(1)

                    ForEach(ProgramType.allCases) { type in
                        programTypeCard(type)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("DAYS PER WEEK")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(FrisTheme.textSecondary)
                        .tracking(1)

                    daysSelector
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func programTypeCard(_ type: ProgramType) -> some View {
        let isSelected = viewModel.programType == type
        return Button {
            withAnimation(.spring(duration: 0.25)) {
                viewModel.programType = type
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: type.icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? FrisTheme.cyan : FrisTheme.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? FrisTheme.cyan.opacity(0.12) : FrisTheme.elevated)
                    .clipShape(.rect(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    Text(type.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(FrisTheme.textPrimary)
                    Text(type.description)
                        .font(.caption)
                        .foregroundStyle(FrisTheme.textSecondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? FrisTheme.cyan : FrisTheme.textSecondary.opacity(0.4))
            }
            .padding(14)
            .background(isSelected ? FrisTheme.cyan.opacity(0.05) : FrisTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        isSelected ? FrisTheme.cyan.opacity(0.4) : FrisTheme.glassBorderTop,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
        }
    }

    private var daysSelector: some View {
        HStack(spacing: 8) {
            ForEach(2...7, id: \.self) { count in
                let isSelected = viewModel.daysPerWeek == count
                Button {
                    withAnimation(.spring(duration: 0.2)) {
                        viewModel.daysPerWeek = count
                    }
                } label: {
                    Text("\(count)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(isSelected ? .black : FrisTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(isSelected ? FrisTheme.cyan : FrisTheme.elevated)
                        .clipShape(.rect(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    isSelected ? Color.clear : FrisTheme.glassBorderTop,
                                    lineWidth: 0.5
                                )
                        )
                }
            }
        }
    }
}
