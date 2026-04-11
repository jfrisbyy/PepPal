import SwiftUI

struct ProgramDetailView: View {
    @State private var program: TrainingProgram
    @Bindable var viewModel: TrainViewModel
    let isActive: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var editingDayId: UUID? = nil
    @State private var showExercisePicker: Bool = false
    @State private var swapTarget: SwapTarget? = nil
    @State private var showRenameDay: Bool = false
    @State private var renameDayId: UUID? = nil
    @State private var renameDayText: String = ""
    @State private var showRenameProgramAlert: Bool = false
    @State private var renameProgramText: String = ""
    @State private var showDeleteConfirm: Bool = false
    @State private var hasChanges: Bool = false

    struct SwapTarget {
        let dayId: UUID
        let exerciseIndex: Int
    }

    init(program: TrainingProgram, viewModel: TrainViewModel, isActive: Bool) {
        self._program = State(initialValue: program)
        self.viewModel = viewModel
        self.isActive = isActive
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                programHeader
                programScheduleOverview
                daysList
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(PepTheme.background.ignoresSafeArea())
        .navigationTitle(program.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        renameProgramText = program.name
                        showRenameProgramAlert = true
                    } label: {
                        Label("Rename Program", systemImage: "pencil")
                    }

                    if !isActive {
                        Button {
                            viewModel.switchToProgram(program)
                            dismiss()
                        } label: {
                            Label("Set as Active", systemImage: "star.fill")
                        }
                    }

                    Button {
                        viewModel.duplicateProgram(program)
                    } label: {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }

                    Divider()

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Program", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
        .alert("Rename Program", isPresented: $showRenameProgramAlert) {
            TextField("Program name", text: $renameProgramText)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                let trimmed = renameProgramText.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                program.name = trimmed
                saveChanges()
            }
        }
        .alert("Rename Day", isPresented: $showRenameDay) {
            TextField("Day name", text: $renameDayText)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                let trimmed = renameDayText.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty, let dayId = renameDayId,
                      let idx = program.days.firstIndex(where: { $0.id == dayId }) else { return }
                program.days[idx].name = trimmed
                saveChanges()
            }
        }
        .alert("Delete Program", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteProgramById(program.id)
                dismiss()
            }
        } message: {
            Text("Are you sure? This can't be undone.")
        }
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerView { exercises in
                if let target = swapTarget,
                   let dayIdx = program.days.firstIndex(where: { $0.id == target.dayId }),
                   let first = exercises.first {
                    let old = program.days[dayIdx].exercises[target.exerciseIndex]
                    program.days[dayIdx].exercises[target.exerciseIndex] = ProgramExercise(
                        exercise: first,
                        targetSets: old.targetSets,
                        targetRepsMin: old.targetRepsMin,
                        targetRepsMax: old.targetRepsMax,
                        restSeconds: old.restSeconds
                    )
                    saveChanges()
                } else if let dayId = editingDayId,
                          let dayIdx = program.days.firstIndex(where: { $0.id == dayId }) {
                    for exercise in exercises {
                        program.days[dayIdx].exercises.append(ProgramExercise(exercise: exercise))
                    }
                    saveChanges()
                }
                swapTarget = nil
                editingDayId = nil
            }
        }
    }

    // MARK: - Header

    private var programHeader: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [PepTheme.teal.opacity(0.2), PepTheme.teal.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    Image(systemName: program.type.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(PepTheme.teal)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(program.type.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(PepTheme.teal)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(PepTheme.teal.opacity(0.12))
                            .clipShape(Capsule())

                        if isActive {
                            Text("Active")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(PepTheme.teal)
                                .clipShape(Capsule())
                        }
                    }

                    Text("Week \(program.currentWeek)")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }

                Spacer()
            }

            HStack(spacing: 16) {
                statPill(value: "\(program.daysPerWeek)", label: "Days/Wk", icon: "calendar")
                statPill(value: "\(program.days.flatMap(\.exercises).count)", label: "Exercises", icon: "dumbbell")
                statPill(value: program.createdAt.formatted(.dateTime.month(.abbreviated).day()), label: "Created", icon: "clock")
            }
        }
        .padding(16)
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

    private func statPill(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(PepTheme.teal.opacity(0.7))
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(PepTheme.elevated.opacity(0.5))
        .clipShape(.rect(cornerRadius: 10))
    }

    // MARK: - Schedule Overview

    private var programScheduleOverview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(PepTheme.violet)
                HeadlineText(text: "Weekly Schedule")
                Spacer()
            }

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                    ForEach(0..<7, id: \.self) { i in
                        let isTrainingDay = i < program.days.count
                        let dayName = isTrainingDay ? program.days[i].name : "Rest"
                        VStack(spacing: 6) {
                            Text(weekdays[i])
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(isTrainingDay ? PepTheme.teal : PepTheme.textSecondary)
                            Circle()
                                .fill(isTrainingDay ? PepTheme.teal : PepTheme.elevated)
                                .frame(width: 8, height: 8)
                            Text(dayName)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(isTrainingDay ? PepTheme.textPrimary : PepTheme.textSecondary)
                                .lineLimit(1)
                        }
                        .frame(width: 52)
                        .padding(.vertical, 8)
                        .background(isTrainingDay ? PepTheme.teal.opacity(0.06) : Color.clear)
                        .clipShape(.rect(cornerRadius: 8))
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Days List

    private var daysList: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundStyle(PepTheme.teal)
                HeadlineText(text: "Training Days")
                Spacer()
            }

            ForEach(Array(program.days.enumerated()), id: \.element.id) { dayIndex, day in
                dayCard(day: day, dayIndex: dayIndex)
            }
        }
    }

    private func dayCard(day: ProgramDay, dayIndex: Int) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Day \(dayIndex + 1)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PepTheme.teal)
                        .tracking(0.8)
                    Text(day.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                }

                Spacer()

                Menu {
                    Button {
                        renameDayId = day.id
                        renameDayText = day.name
                        showRenameDay = true
                    } label: {
                        Label("Rename Day", systemImage: "pencil")
                    }

                    Button {
                        editingDayId = day.id
                        swapTarget = nil
                        showExercisePicker = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(PepTheme.elevated)
                        .clipShape(Circle())
                }

                Text("\(day.exercises.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.teal)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(PepTheme.teal.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            ForEach(Array(day.exercises.enumerated()), id: \.element.id) { exIdx, exercise in
                exerciseRow(exercise: exercise, dayId: day.id, dayIndex: dayIndex, exerciseIndex: exIdx)
            }

            Spacer().frame(height: 8)
        }
        .background(PepTheme.cardSurface)
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

    private func exerciseRow(exercise: ProgramExercise, dayId: UUID, dayIndex: Int, exerciseIndex: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: exercise.primaryMuscle.icon)
                .font(.system(size: 11))
                .foregroundStyle(PepTheme.teal.opacity(0.7))
                .frame(width: 26, height: 26)
                .background(PepTheme.teal.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(exercise.exerciseName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)
                Text("\(exercise.targetSets)×\(exercise.targetRepsMin)-\(exercise.targetRepsMax) · \(exercise.restSeconds)s rest")
                    .font(.system(size: 10))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            Menu {
                Button {
                    swapTarget = SwapTarget(dayId: dayId, exerciseIndex: exerciseIndex)
                    editingDayId = nil
                    showExercisePicker = true
                } label: {
                    Label("Swap Exercise", systemImage: "arrow.triangle.swap")
                }

                Button(role: .destructive) {
                    withAnimation(.spring(response: 0.35)) {
                        if let dIdx = program.days.firstIndex(where: { $0.id == dayId }) {
                            program.days[dIdx].exercises.remove(at: exerciseIndex)
                            saveChanges()
                        }
                    }
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .frame(width: 28, height: 28)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
    }

    // MARK: - Helpers

    private func saveChanges() {
        viewModel.updateProgram(program)
        hasChanges = true
    }
}
