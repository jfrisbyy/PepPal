import SwiftUI

struct SwapExerciseSheet: View {
    @Bindable var viewModel: ActiveWorkoutViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var libraryVM = ExerciseLibraryViewModel()
    @State private var selectedEquipment: Equipment? = nil
    @State private var showSaveToTemplatePrompt: Bool = false

    private var source: Exercise? {
        guard let idx = viewModel.swapTargetIndex, idx < viewModel.exercises.count else { return nil }
        return viewModel.exercises[idx].exercise
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let source {
                        header(for: source)
                        equipmentFilter(for: source)
                        alternativesList(for: source)
                    } else {
                        Text("No exercise selected")
                            .foregroundStyle(PepTheme.textSecondary)
                            .padding(.top, 40)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .appBackground()
            .navigationTitle("Swap Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
        .presentationDetents([.large])
        .presentationContentInteraction(.scrolls)
    }

    private func header(for source: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Replacing")
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(PepTheme.textSecondary)
            Text(source.name)
                .font(.title3.weight(.bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text("This change applies to your active session only, unless you save it to the template.")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func equipmentFilter(for source: Exercise) -> some View {
        let options: [Equipment] = [.barbell, .dumbbell, .machine, .cable, .bodyweight, .band]
        return VStack(alignment: .leading, spacing: 10) {
            Text("Equipment")
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(PepTheme.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip(title: "All", systemImage: "square.grid.2x2.fill", isSelected: selectedEquipment == nil) {
                        selectedEquipment = nil
                    }
                    ForEach(options, id: \.self) { eq in
                        chip(title: eq.rawValue, systemImage: eq.icon, isSelected: selectedEquipment == eq) {
                            selectedEquipment = (selectedEquipment == eq) ? nil : eq
                        }
                    }
                }
            }
            .contentMargins(.horizontal, 0)
        }
    }

    private func chip(title: String, systemImage: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage).font(.system(size: 12))
                Text(title).font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(isSelected ? PepTheme.invertedText : PepTheme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? AnyShapeStyle(PepTheme.teal) : AnyShapeStyle(PepTheme.elevated))
            .clipShape(Capsule())
        }
    }

    private func alternativesList(for source: Exercise) -> some View {
        let results: [Exercise] = {
            if let eq = selectedEquipment {
                return libraryVM.alternatives(for: source, equipment: eq)
            }
            return libraryVM.alternatives(for: source).isEmpty
                ? libraryVM.similarExercises(for: source)
                : libraryVM.alternatives(for: source)
        }()

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Substitutes")
                    .font(.caption.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                Text("\(results.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            if results.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundStyle(PepTheme.textSecondary)
                    Text("No matches. Try another equipment filter.")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                VStack(spacing: 8) {
                    ForEach(results) { alt in
                        Button {
                            viewModel.swapExercise(with: alt)
                            dismiss()
                        } label: {
                            row(for: alt)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func row(for exercise: Exercise) -> some View {
        HStack(spacing: 12) {
            Image(systemName: exercise.equipment.icon)
                .font(.system(size: 14))
                .foregroundStyle(PepTheme.teal)
                .frame(width: 36, height: 36)
                .background(PepTheme.teal.opacity(0.1))
                .clipShape(.rect(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                HStack(spacing: 6) {
                    Text(exercise.equipment.rawValue)
                    Text("·")
                    Text(exercise.difficulty.rawValue)
                }
                .font(.system(size: 11))
                .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            Image(systemName: "arrow.right.circle.fill")
                .font(.title3)
                .foregroundStyle(PepTheme.teal)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(PepTheme.glassBorderTop.opacity(0.4), lineWidth: 0.5)
        )
    }
}
