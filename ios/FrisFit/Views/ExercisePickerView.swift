import SwiftUI

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ExerciseLibraryViewModel()
    @State private var selectedExercises: [Exercise] = []
    let onDone: ([Exercise]) -> Void

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 0) {
                        muscleGroupFilters
                        exerciseList
                    }
                    .padding(.bottom, selectedExercises.isEmpty ? 0 : 80)
                }
                .background(PepTheme.background.ignoresSafeArea())

                if !selectedExercises.isEmpty {
                    selectionBar
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search exercises...")
            .navigationTitle("Add Exercises")
            .navigationBarTitleDisplayMode(.inline)
            
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(PepTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.selectedMuscleGroup != nil {
                        Button("Clear") {
                            viewModel.clearFilters()
                        }
                        .foregroundStyle(PepTheme.teal)
                    }
                }
            }
        }
    }

    private var muscleGroupFilters: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(MuscleGroup.allCases) { group in
                    PickerMuscleChip(
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
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(PepTheme.textSecondary)
                    Text("No exercises found")
                        .font(.headline)
                        .foregroundStyle(PepTheme.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
            } else {
                ForEach(sortedKeys) { muscle in
                    if let exercises = grouped[muscle] {
                        Section {
                            ForEach(exercises) { exercise in
                                pickerRow(exercise)
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

    private func pickerRow(_ exercise: Exercise) -> some View {
        let isSelected = selectedExercises.contains(where: { $0.id == exercise.id })

        return Button {
            withAnimation(.spring(duration: 0.2)) {
                if isSelected {
                    selectedExercises.removeAll { $0.id == exercise.id }
                } else {
                    selectedExercises.append(exercise)
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: exercise.primaryMuscle.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(PepTheme.teal)
                    .frame(width: 36, height: 36)
                    .background(PepTheme.teal.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(exercise.equipment.rawValue)
                        Text("·")
                        Text(exercise.exerciseType.rawValue)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(PepTheme.textSecondary)
                }

                Spacer()

                ZStack {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(PepTheme.teal)
                    } else {
                        Image(systemName: "plus.circle")
                            .font(.title3)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? PepTheme.teal.opacity(0.06) : PepTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? PepTheme.teal.opacity(0.3) : PepTheme.glassBorderTop.opacity(0.4),
                        lineWidth: isSelected ? 1 : 0.5
                    )
            )
            .padding(.vertical, 2)
        }
    }

    private var selectionBar: some View {
        Button {
            onDone(selectedExercises)
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Text("\(selectedExercises.count) exercise\(selectedExercises.count == 1 ? "" : "s") selected")
                    .font(.subheadline.weight(.medium))

                Spacer()

                Text("Done")
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.3))
                    .clipShape(Capsule())
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(PepTheme.teal)
            .clipShape(.rect(cornerRadius: 16))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

private struct PickerMuscleChip: View {
    let group: MuscleGroup
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: group.icon)
                    .font(.system(size: 12))
                Text(group.rawValue)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isSelected ? PepTheme.teal : PepTheme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? PepTheme.teal.opacity(0.15) : PepTheme.elevated)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? PepTheme.teal.opacity(0.5) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
    }
}
