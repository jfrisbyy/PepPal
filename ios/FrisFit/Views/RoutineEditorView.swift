import SwiftUI

struct RoutineEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = RoutineStore.shared
    @State private var name: String
    @State private var exercises: [ProgramExercise]
    @State private var notes: String
    @State private var showExercisePicker: Bool = false

    private let existingId: UUID?
    private let existingCreatedAt: Date
    private let existingLastPerformed: Date?
    private let existingTimesPerformed: Int

    init(existing: Routine? = nil) {
        if let r = existing {
            _name = State(initialValue: r.name)
            _exercises = State(initialValue: r.exercises)
            _notes = State(initialValue: r.notes)
            self.existingId = r.id
            self.existingCreatedAt = r.createdAt
            self.existingLastPerformed = r.lastPerformedAt
            self.existingTimesPerformed = r.timesPerformed
        } else {
            _name = State(initialValue: "")
            _exercises = State(initialValue: [])
            _notes = State(initialValue: "")
            self.existingId = nil
            self.existingCreatedAt = Date()
            self.existingLastPerformed = nil
            self.existingTimesPerformed = 0
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    editorialHeader
                    nameSection
                    exercisesSection
                    notesSection
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .appBackground(accent: PepTheme.teal)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(canSave ? PepTheme.teal : PepTheme.textSecondary)
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView { picked in
                    for ex in picked {
                        exercises.append(ProgramExercise(exercise: ex))
                    }
                    showExercisePicker = false
                }
            }
        }
    }

    private var editorialHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text((existingId == nil ? "New Routine" : "Edit Routine").uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.0)
                    .foregroundStyle(PepTheme.teal.opacity(0.9))
                Spacer()
                Text("STUDIO")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.4)
                    .foregroundStyle(PepTheme.textTertiary)
            }

            Text("Compose a Lift.")
                .font(.system(size: 34, weight: .semibold, design: .serif))
                .kerning(-0.6)
                .foregroundStyle(PepTheme.textPrimary)

            Text("A routine you can launch with one tap. Sequence movements, set the work, save it for forever.")
                .font(.system(size: 14, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
                .lineSpacing(2)

            LinearGradient(
                colors: [PepTheme.textPrimary.opacity(0.18), PepTheme.textPrimary.opacity(0.0)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 0.5)
        }
    }

    private func sectionEyebrow(_ number: String, _ title: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(number)
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.0)
                .foregroundStyle(PepTheme.teal.opacity(0.9))
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
        }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionEyebrow("01 — NAME", "Title this Lift")
            TextField("e.g. Push Day, Morning Lift", text: $name)
                .textInputAutocapitalization(.words)
                .font(.system(size: 17, weight: .medium, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
                .clipShape(.rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
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
    }

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                sectionEyebrow("02 — MOVEMENTS", "The Sequence")
                Spacer()
                if !exercises.isEmpty {
                    Text("\(exercises.count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(PepTheme.elevated)
                        .clipShape(Capsule())
                }
            }

            if exercises.isEmpty {
                Button {
                    showExercisePicker = true
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(PepTheme.teal)
                        Text("Add Exercises")
                            .font(.system(size: 15, weight: .semibold, design: .serif))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("Search the library, build your sequence")
                            .font(.system(size: 12))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(PepTheme.teal.opacity(0.25), style: StrokeStyle(lineWidth: 0.8, dash: [4, 4]))
                    )
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(exercises.enumerated()), id: \.element.id) { idx, pe in
                        exerciseCard(pe, index: idx)
                    }

                    Button {
                        showExercisePicker = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Add Movement")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(PepTheme.teal)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(PepTheme.teal.opacity(0.1))
                        .clipShape(.rect(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(PepTheme.teal.opacity(0.3), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func exerciseCard(_ pe: ProgramExercise, index: Int) -> some View {
        HStack(spacing: 14) {
            Text(String(format: "%02d", index + 1))
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundStyle(PepTheme.textTertiary)
                .frame(width: 24, alignment: .leading)

            ZStack {
                Circle()
                    .fill(PepTheme.teal.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: pe.primaryMuscle.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PepTheme.teal)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(pe.exerciseName)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)
                Text("\(pe.targetSets) sets · \(pe.targetRepsMin)–\(pe.targetRepsMax) reps")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(0.4)
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            HStack(spacing: 6) {
                Button {
                    if exercises[index].targetSets > 1 {
                        exercises[index].targetSets -= 1
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 26, height: 26)
                        .background(PepTheme.elevated)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Text("\(exercises[index].targetSets)")
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                    .frame(minWidth: 16)

                Button {
                    if exercises[index].targetSets < 10 {
                        exercises[index].targetSets += 1
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PepTheme.teal)
                        .frame(width: 26, height: 26)
                        .background(PepTheme.teal.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            Button {
                exercises.remove(at: index)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
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

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionEyebrow("03 — NOTES", "Marginalia")
            TextField("Cues, tempo, intent…", text: $notes, axis: .vertical)
                .lineLimit(3...8)
                .font(.system(size: 14, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
                .clipShape(.rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
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
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !exercises.isEmpty
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let id = existingId {
            let updated = Routine(
                id: id,
                name: trimmed,
                exercises: exercises,
                notes: notes,
                createdAt: existingCreatedAt,
                updatedAt: Date(),
                lastPerformedAt: existingLastPerformed,
                timesPerformed: existingTimesPerformed
            )
            store.update(updated)
        } else {
            let newRoutine = Routine(name: trimmed, exercises: exercises, notes: notes)
            store.add(newRoutine)
        }
        dismiss()
    }
}

struct SaveAsRoutineSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = RoutineStore.shared
    @State private var name: String
    let exercises: [WorkoutExercise]
    var onSaved: () -> Void = {}

    init(defaultName: String, exercises: [WorkoutExercise], onSaved: @escaping () -> Void = {}) {
        _name = State(initialValue: defaultName)
        self.exercises = exercises
        self.onSaved = onSaved
    }

    private var previewRoutine: Routine {
        RoutineStore.routine(from: name.isEmpty ? "Workout" : name, exercises: exercises)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Name") {
                    TextField("Routine name", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section("Exercises") {
                    ForEach(previewRoutine.exercises) { pe in
                        HStack(spacing: 10) {
                            Image(systemName: pe.primaryMuscle.icon)
                                .foregroundStyle(PepTheme.teal)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pe.exerciseName)
                                    .font(.subheadline.weight(.semibold))
                                Text("\(pe.targetSets) × \(pe.targetRepsMin)-\(pe.targetRepsMax)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if !previewRoutine.muscleGroups.isEmpty {
                    Section("Muscle Groups") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(previewRoutine.muscleGroups, id: \.self) { muscle in
                                    HStack(spacing: 4) {
                                        Image(systemName: muscle.icon)
                                            .font(.system(size: 10))
                                        Text(muscle.rawValue)
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    .foregroundStyle(PepTheme.teal)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(PepTheme.teal.opacity(0.1))
                                    .clipShape(Capsule())
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                    }
                }
            }
            .navigationTitle("Save as Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let routine = Routine(
                            name: name.trimmingCharacters(in: .whitespaces).isEmpty ? "Workout" : name,
                            exercises: previewRoutine.exercises
                        )
                        store.add(routine)
                        onSaved()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(PepTheme.teal)
                    .disabled(previewRoutine.exercises.isEmpty)
                }
            }
        }
    }
}
