import SwiftUI

struct RoutineDetailView: View {
    let routine: Routine
    var trainViewModel: TrainViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var store = RoutineStore.shared
    @State private var sessionManager = WorkoutSessionManager.shared
    @State private var showEditor: Bool = false

    private var current: Routine {
        store.routines.first { $0.id == routine.id } ?? routine
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if !current.muscleGroups.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(current.muscleGroups, id: \.self) { muscle in
                                HStack(spacing: 4) {
                                    Image(systemName: muscle.icon)
                                        .font(.system(size: 10))
                                    Text(muscle.rawValue)
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundStyle(PepTheme.teal)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(PepTheme.teal.opacity(0.1))
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Exercises")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(PepTheme.textPrimary)

                    if current.exercises.isEmpty {
                        Text("No exercises yet. Tap Edit to add some.")
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textSecondary)
                            .padding(.vertical, 20)
                            .frame(maxWidth: .infinity)
                    } else {
                        ForEach(current.exercises) { ex in
                            exerciseRow(ex)
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, 100)
        }
        .appBackground()
        .navigationTitle(current.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    showEditor = true
                }
                .foregroundStyle(PepTheme.teal)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                startWorkout()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("Start Workout")
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(PepTheme.teal)
                .clipShape(.rect(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(current.exercises.isEmpty)
            .opacity(current.exercises.isEmpty ? 0.5 : 1)
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .sheet(isPresented: $showEditor) {
            RoutineEditorView(existing: current)
                .presentationDetents([.large])
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 14) {
                statBubble(value: "\(current.exercises.count)", label: "Exercises")
                statBubble(value: "\(totalSets)", label: "Sets")
                statBubble(value: "\(current.estimatedMinutes)m", label: "Est.")
            }
        }
    }

    private var totalSets: Int {
        current.exercises.reduce(0) { $0 + $1.targetSets }
    }

    private func statBubble(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private func exerciseRow(_ pe: ProgramExercise) -> some View {
        HStack(spacing: 12) {
            Image(systemName: pe.primaryMuscle.icon)
                .font(.system(size: 13))
                .foregroundStyle(PepTheme.teal)
                .frame(width: 34, height: 34)
                .background(PepTheme.teal.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(pe.exerciseName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)
                Text("\(pe.targetSets) sets × \(pe.targetRepsMin)-\(pe.targetRepsMax) reps")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()
            if let weight = pe.prescribedWeight, weight > 0 {
                Text("\(Int(weight)) lbs")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(PepTheme.amber)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(PepTheme.amber.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private func startWorkout() {
        let r = current
        let exercises: [WorkoutExercise] = r.exercises.map { pe in
            let exercise = ExerciseLibrary.all.first { $0.id == pe.exerciseId } ?? ExerciseLibrary.all[0]
            return WorkoutExercise(
                exercise: exercise,
                targetSets: pe.targetSets,
                previousWeight: pe.prescribedWeight,
                previousReps: pe.targetRepsMax
            )
        }
        sessionManager.startSession(name: r.name, exercises: exercises)
        store.markPerformed(r.id)
        dismiss()
    }
}
