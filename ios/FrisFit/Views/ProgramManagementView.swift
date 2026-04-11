import SwiftUI

struct ProgramManagementView: View {
    @Bindable var viewModel: TrainViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm: Bool = false
    @State private var programToDelete: TrainingProgram? = nil
    @State private var selectedProgram: TrainingProgram? = nil
    @State private var showProgramDetail: Bool = false
    @State private var showProgramCreation: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let active = viewModel.activeProgram {
                        activeProgramSection(active)
                    }

                    if !viewModel.inactivePrograms.isEmpty {
                        savedProgramsSection
                    }

                    addProgramSection
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .background(PepTheme.background.ignoresSafeArea())
            .navigationTitle("My Programs")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
            }
            .navigationDestination(isPresented: $showProgramDetail) {
                if let program = selectedProgram {
                    ProgramDetailView(
                        program: program,
                        viewModel: viewModel,
                        isActive: viewModel.activeProgram?.id == program.id
                    )
                }
            }
            .sheet(isPresented: $showProgramCreation) {
                ProgramCreationView(viewModel: viewModel)
                    .presentationDetents([.large])
            }
            .fullScreenCover(isPresented: $viewModel.showProgramBuilder) {
                ProgramBuilderView(viewModel: viewModel)
            }
            .alert("Delete Program", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let p = programToDelete {
                        withAnimation(.spring(response: 0.35)) {
                            viewModel.deleteProgramById(p.id)
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to delete \"\(programToDelete?.name ?? "")\"? This can't be undone.")
            }
        }
    }

    // MARK: - Active Program

    private func activeProgramSection(_ program: TrainingProgram) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(PepTheme.teal)
                Text("ACTIVE PROGRAM")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PepTheme.teal)
                    .tracking(1.2)
            }
            .padding(.top, 4)

            programCard(program, isActive: true)
        }
    }

    // MARK: - Saved Programs

    private var savedProgramsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(PepTheme.textSecondary)
                Text("SAVED PROGRAMS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .tracking(1.2)
            }

            ForEach(viewModel.inactivePrograms) { program in
                programCard(program, isActive: false)
            }
        }
    }

    // MARK: - Program Card

    private func programCard(_ program: TrainingProgram, isActive: Bool) -> some View {
        Button {
            selectedProgram = program
            showProgramDetail = true
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isActive ? PepTheme.teal.opacity(0.15) : PepTheme.elevated)
                            .frame(width: 48, height: 48)
                        Image(systemName: program.type.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(isActive ? PepTheme.teal : PepTheme.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(program.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                                .lineLimit(1)

                            if isActive {
                                Text("Active")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(PepTheme.teal)
                                    .clipShape(Capsule())
                            }
                        }

                        HStack(spacing: 8) {
                            Label("\(program.daysPerWeek) days/wk", systemImage: "calendar")
                            Label("\(program.days.flatMap(\.exercises).count) exercises", systemImage: "dumbbell")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .padding(14)

                Divider().opacity(0.3)

                HStack(spacing: 0) {
                    if !isActive {
                        cardActionButton(icon: "play.fill", label: "Activate", color: PepTheme.teal) {
                            withAnimation(.spring(response: 0.35)) {
                                viewModel.switchToProgram(program)
                            }
                        }

                        cardDivider
                    }

                    cardActionButton(icon: "doc.on.doc", label: "Duplicate", color: PepTheme.blue) {
                        withAnimation(.spring(response: 0.35)) {
                            viewModel.duplicateProgram(program)
                        }
                    }

                    cardDivider

                    cardActionButton(icon: "trash", label: "Delete", color: .red.opacity(0.8)) {
                        programToDelete = program
                        showDeleteConfirm = true
                    }
                }
                .padding(.vertical, 6)
            }
            .background(PepTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: isActive
                                ? [PepTheme.teal.opacity(0.25), PepTheme.teal.opacity(0.1)]
                                : [PepTheme.glassBorderTop, PepTheme.glassBorderBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isActive ? 1 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: showProgramDetail)
        .contextMenu {
            if !isActive {
                Button {
                    viewModel.switchToProgram(program)
                } label: {
                    Label("Set as Active", systemImage: "star.fill")
                }
            }

            Button {
                selectedProgram = program
                showProgramDetail = true
            } label: {
                Label("View Program", systemImage: "eye")
            }

            Button {
                viewModel.duplicateProgram(program)
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
            }

            Divider()

            Button(role: .destructive) {
                programToDelete = program
                showDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func cardActionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private var cardDivider: some View {
        Rectangle()
            .fill(PepTheme.glassBorderTop)
            .frame(width: 0.5, height: 28)
    }

    // MARK: - Add Program

    private var addProgramSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(PepTheme.textSecondary)
                Text("ADD PROGRAM")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .tracking(1.2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            addOptionButton(
                icon: "square.grid.2x2.fill",
                title: "Choose a Template",
                subtitle: "PPL, Upper/Lower, Full Body & more",
                color: PepTheme.teal
            ) {
                showProgramCreation = true
            }

            HStack(spacing: 10) {
                addOptionSmall(icon: "sparkles", title: "Build with AI", color: PepTheme.violet) {
                    showProgramCreation = true
                }
                addOptionSmall(icon: "doc.badge.plus", title: "From Scratch", color: PepTheme.amber) {
                    viewModel.resetBuilder()
                    viewModel.showProgramBuilder = true
                }
            }
        }
    }

    private func addOptionButton(icon: String, title: String, subtitle: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(color)
                    .clipShape(.rect(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(PepTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(12)
            .background(color.opacity(0.06))
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(color.opacity(0.15), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func addOptionSmall(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.06))
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(color.opacity(0.15), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
