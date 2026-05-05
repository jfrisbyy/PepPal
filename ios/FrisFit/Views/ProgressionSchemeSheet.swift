import SwiftUI

struct ProgressionSchemeSheet: View {
    let dayId: UUID
    let exerciseIndex: Int
    @Binding var program: TrainingProgram
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedScheme: ProgressionScheme = .none
    @State private var increment: Double = 5
    @State private var targetRPE: Double = 8

    private var dayIdx: Int? {
        program.days.firstIndex(where: { $0.id == dayId })
    }

    private var exercise: ProgramExercise? {
        guard let d = dayIdx, exerciseIndex < program.days[d].exercises.count else { return nil }
        return program.days[d].exercises[exerciseIndex]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let ex = exercise {
                        header(ex)
                    }
                    schemePicker
                    if selectedScheme == .linear || selectedScheme == .doubleProgression {
                        incrementPicker
                    }
                    if selectedScheme == .rpe {
                        rpePicker
                    }
                }
                .padding()
            }
            .appBackground()
            .navigationTitle("Progression")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear { loadCurrent() }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func header(_ ex: ProgramExercise) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(ex.exerciseName)
                .font(.title3.weight(.bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text("\(ex.targetSets)×\(ex.targetRepsMin)-\(ex.targetRepsMax) reps")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
    }

    private var schemePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SCHEME")
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundStyle(PepTheme.textSecondary)

            ForEach(ProgressionScheme.allCases) { scheme in
                Button {
                    withAnimation(.spring(duration: 0.2)) {
                        selectedScheme = scheme
                    }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: selectedScheme == scheme ? "largecircle.fill.circle" : "circle")
                            .font(.system(size: 20))
                            .foregroundStyle(selectedScheme == scheme ? PepTheme.teal : PepTheme.textSecondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(scheme.rawValue)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                            Text(scheme.description)
                                .font(.caption)
                                .foregroundStyle(PepTheme.textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(selectedScheme == scheme ? PepTheme.teal.opacity(0.08) : PepTheme.cardSurface)
                    .clipShape(.rect(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                selectedScheme == scheme ? PepTheme.teal.opacity(0.4) : Color.clear,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var incrementPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("INCREMENT (LBS)")
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundStyle(PepTheme.textSecondary)

            HStack(spacing: 8) {
                ForEach([2.5, 5.0, 10.0], id: \.self) { val in
                    Button {
                        increment = val
                    } label: {
                        Text(val.truncatingRemainder(dividingBy: 1) == 0 ? "+\(Int(val))" : "+\(val, specifier: "%.1f")")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(increment == val ? .black : PepTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(increment == val ? PepTheme.teal : PepTheme.elevated)
                            .clipShape(.rect(cornerRadius: 10))
                    }
                }
            }
        }
    }

    private var rpePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TARGET RPE")
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundStyle(PepTheme.textSecondary)

            HStack {
                Text("\(targetRPE, specifier: "%.1f")")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.teal)
                Spacer()
                Stepper("", value: $targetRPE, in: 6...10, step: 0.5)
                    .labelsHidden()
            }
            .padding()
            .background(PepTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 12))
        }
    }

    private func loadCurrent() {
        guard let ex = exercise else { return }
        selectedScheme = ex.progressionScheme ?? .none
        increment = ex.progressionIncrement ?? 5
        targetRPE = ex.progressionTargetRPE ?? 8
    }

    private func save() {
        guard let d = dayIdx, exerciseIndex < program.days[d].exercises.count else {
            dismiss()
            return
        }
        program.days[d].exercises[exerciseIndex].progressionScheme = selectedScheme
        program.days[d].exercises[exerciseIndex].progressionIncrement = increment
        program.days[d].exercises[exerciseIndex].progressionTargetRPE = targetRPE
        onSave()
        dismiss()
    }
}
