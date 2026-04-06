import SwiftUI

struct TrainModeSelectorSheet: View {
    @Bindable var viewModel: TrainViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showAddMode: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    activeModesSection
                    addNewSection
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(PepTheme.background.ignoresSafeArea())
            .navigationTitle("Training Modes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(PepTheme.teal)
                }
            }
            .sheet(isPresented: $showAddMode) {
                CreateTrainModeSheet(viewModel: viewModel)
            }
        }
    }

    private var activeModesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR MODES")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(PepTheme.textSecondary)
                .tracking(1.2)

            ForEach(viewModel.availableModes) { mode in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        viewModel.switchMode(mode)
                    }
                    dismiss()
                } label: {
                    modeRow(mode)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    if mode.type != .main {
                        Button(role: .destructive) {
                            withAnimation { viewModel.removeMode(mode) }
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private func modeRow(_ mode: TrainMode) -> some View {
        let isActive = viewModel.currentMode.id == mode.id

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(mode.type.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: mode.type.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(mode.type.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(mode.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PepTheme.textPrimary)

                if mode.type == .main {
                    Text("Overview of all training")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                } else if let sport = mode.type.sport {
                    let count = viewModel.sessionsForSport(sport).count
                    Text("\(count) session\(count == 1 ? "" : "s") logged")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                } else {
                    Text("Custom sport view")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }

            Spacer()

            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(mode.type.color)
            } else {
                Image(systemName: "circle")
                    .font(.title3)
                    .foregroundStyle(PepTheme.glassBorderTop)
            }
        }
        .padding(14)
        .background(
            isActive
                ? mode.type.color.opacity(0.06)
                : PepTheme.cardSurface
        )
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    isActive ? mode.type.color.opacity(0.25) : PepTheme.glassBorderTop,
                    lineWidth: isActive ? 1 : 0.5
                )
        )
    }

    private var addNewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ADD NEW MODE")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(PepTheme.textSecondary)
                .tracking(1.2)

            let availableTypes = TrainModeType.allCases.filter { type in
                type != .main && type != .custom && !viewModel.availableModes.contains(where: { $0.type == type })
            }

            if !availableTypes.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(availableTypes) { type in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                viewModel.addMode(TrainMode(type: type))
                            }
                            dismiss()
                        } label: {
                            sportQuickAddTile(type)
                        }
                        .buttonStyle(.scale)
                    }
                }
            }

            Button {
                showAddMode = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(PepTheme.violet)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Create Custom Mode")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("Build a view for any sport or activity")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .padding(14)
                .background(PepTheme.cardSurface)
                .clipShape(.rect(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            LinearGradient(
                                colors: [PepTheme.violet.opacity(0.2), PepTheme.glassBorderBottom],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
            }
            .buttonStyle(.scale)
        }
    }

    private func sportQuickAddTile(_ type: TrainModeType) -> some View {
        VStack(spacing: 10) {
            Image(systemName: type.icon)
                .font(.system(size: 24))
                .foregroundStyle(type.color)
            Text(type.rawValue)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(type.color.opacity(0.06))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(type.color.opacity(0.15), lineWidth: 0.5)
        )
    }
}
