import SwiftUI

struct ExerciseLibraryView: View {
    @State private var viewModel = ExerciseLibraryViewModel()
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 0) {
                    muscleGroupFilters
                    exerciseList
                }
            }
            .background(PepTheme.background.ignoresSafeArea())
            .searchable(text: $viewModel.searchText, prompt: "Search exercises...")
            .navigationTitle("Exercise Library")
            
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.selectedMuscleGroup != nil || viewModel.selectedEquipment != nil {
                        Button("Clear") {
                            viewModel.clearFilters()
                        }
                        .foregroundStyle(PepTheme.teal)
                    }
                }
            }
            .navigationDestination(for: Exercise.self) { exercise in
                ExerciseDetailView(exercise: exercise, viewModel: viewModel)
            }
        }
    }

    private var muscleGroupFilters: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(MuscleGroup.allCases) { group in
                    MuscleGroupChip(
                        group: group,
                        isSelected: viewModel.selectedMuscleGroup == group
                    ) {
                        withAnimation(.spring(duration: 0.25)) {
                            viewModel.selectMuscleGroup(group)
                        }
                    }
                }
            }
        }
        .contentMargins(.horizontal, 16)
        .scrollIndicators(.hidden)
        .padding(.vertical, 12)
    }

    private var exerciseList: some View {
        LazyVStack(spacing: 0) {
            let grouped = Dictionary(grouping: viewModel.filteredExercises) { $0.primaryMuscle }
            let sortedKeys = MuscleGroup.allCases.filter { grouped[$0] != nil }

            if viewModel.filteredExercises.isEmpty {
                emptyState
            } else {
                ForEach(sortedKeys) { muscle in
                    if let exercises = grouped[muscle] {
                        Section {
                            ForEach(exercises) { exercise in
                                NavigationLink(value: exercise) {
                                    ExerciseRow(exercise: exercise)
                                }
                            }
                        } header: {
                            sectionHeader(muscle)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    private func sectionHeader(_ muscle: MuscleGroup) -> some View {
        HStack(spacing: 8) {
            Image(systemName: muscle.icon)
                .font(.caption)
                .foregroundStyle(PepTheme.teal)
            Text(muscle.rawValue.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(PepTheme.textSecondary)
                .tracking(1.2)
            Spacer()
        }
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(PepTheme.textSecondary)
            Text("No exercises found")
                .font(.headline)
                .foregroundStyle(PepTheme.textPrimary)
            Text("Try adjusting your search or filters")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

private struct MuscleGroupChip: View {
    let group: MuscleGroup
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: group.icon)
                    .font(.system(size: 18))
                    .frame(width: 44, height: 44)
                    .background(
                        isSelected
                            ? PepTheme.teal.opacity(0.2)
                            : PepTheme.elevated
                    )
                    .foregroundStyle(isSelected ? PepTheme.teal : PepTheme.textSecondary)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isSelected ? PepTheme.teal.opacity(0.6) : Color.clear,
                                lineWidth: 1.5
                            )
                    )

                Text(group.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isSelected ? PepTheme.teal : PepTheme.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: 64)
        }
    }
}

private struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: exercise.primaryMuscle.icon)
                .font(.system(size: 16))
                .foregroundStyle(PepTheme.teal)
                .frame(width: 40, height: 40)
                .background(PepTheme.teal.opacity(0.1))
                .clipShape(.rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PepTheme.textPrimary)

                HStack(spacing: 8) {
                    Label(exercise.equipment.rawValue, systemImage: exercise.equipment.icon)
                    Text("·")
                    Text(exercise.exerciseType.rawValue)
                }
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            DifficultyBadge(difficulty: exercise.difficulty)

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(PepTheme.glassBorderTop.opacity(0.4), lineWidth: 0.5)
        )
        .padding(.vertical, 3)
    }
}

struct DifficultyBadge: View {
    let difficulty: Difficulty

    private var badgeColor: Color {
        switch difficulty {
        case .beginner: .green
        case .intermediate: .orange
        case .advanced: .red
        }
    }

    var body: some View {
        Text(difficulty.rawValue)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(badgeColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(badgeColor.opacity(0.15))
            .clipShape(Capsule())
    }
}
