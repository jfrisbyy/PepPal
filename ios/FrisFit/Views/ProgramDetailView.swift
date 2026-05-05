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

    struct SwapTarget: Identifiable {
        let dayId: UUID
        let exerciseIndex: Int
        var id: String { "\(dayId.uuidString)-\(exerciseIndex)" }
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
        .appBackground()
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
            exercisePickerSheet
        }
        .sheet(item: $progressionSheetTarget) { target in
            ProgressionSchemeSheet(
                dayId: target.dayId,
                exerciseIndex: target.exerciseIndex,
                program: $program,
                onSave: { saveChanges() }
            )
        }
    }

    private var currentSwapSource: Exercise? {
        guard let target = swapTarget,
              let dayIdx = program.days.firstIndex(where: { $0.id == target.dayId }),
              target.exerciseIndex < program.days[dayIdx].exercises.count else { return nil }
        let pe = program.days[dayIdx].exercises[target.exerciseIndex]
        return ExerciseLibrary.all.first { $0.id == pe.exerciseId }
    }

    private var exercisePickerSheet: some View {
        ExercisePickerView(swapSource: currentSwapSource) { exercises in
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

            weekdayEditor(dayIndex: dayIndex)
                .padding(.horizontal, 14)
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

    @State private var progressionSheetTarget: SwapTarget? = nil

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
                if let prescribed = exercise.prescribedWeight, prescribed > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.forward")
                            .font(.system(size: 9, weight: .bold))
                        Text("Next: \(Int(prescribed)) lbs")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(PepTheme.amber)
                }
                if let scheme = exercise.progressionScheme, scheme != .none {
                    Text(scheme.rawValue)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(PepTheme.violet)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(PepTheme.violet.opacity(0.12))
                        .clipShape(Capsule())
                }
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

                Button {
                    progressionSheetTarget = SwapTarget(dayId: dayId, exerciseIndex: exerciseIndex)
                } label: {
                    Label("Progression…", systemImage: "chart.line.uptrend.xyaxis")
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

    // MARK: - Weekday Editor

    private func weekdayEditor(dayIndex: Int) -> some View {
        let selected = program.days[dayIndex].scheduledWeekday
        let sharedWeekday: Int? = {
            guard let wd = selected else { return nil }
            let count = program.days.filter { $0.scheduledWeekday == wd }.count
            return count > 1 ? wd : nil
        }()
        return VStack(alignment: .leading, spacing: 8) {
            Text("SCHEDULED ON")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.8))
                .tracking(0.8)
            HStack(spacing: 6) {
                ForEach(ProgramWeekday.allCases) { weekday in
                    let isSelected = selected == weekday.rawValue
                    let sharedCount = program.days.enumerated().filter { i, d in
                        i != dayIndex && d.scheduledWeekday == weekday.rawValue
                    }.count
                    Button {
                        withAnimation(.spring(duration: 0.2)) {
                            program.days[dayIndex].scheduledWeekday = weekday.rawValue
                            ensureTimeOfDayAssignments(forWeekday: weekday.rawValue)
                            saveChanges()
                        }
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Text(weekday.singleLetter)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(isSelected ? .black : PepTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 34)
                                .background(isSelected ? PepTheme.teal : PepTheme.elevated)
                                .clipShape(.rect(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(
                                            isSelected ? Color.clear : PepTheme.glassBorderTop,
                                            lineWidth: 0.5
                                        )
                                )
                            if sharedCount > 0 {
                                Circle()
                                    .fill(PepTheme.amber)
                                    .frame(width: 6, height: 6)
                                    .offset(x: -4, y: 4)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            if sharedWeekday != nil {
                timeOfDayEditor(dayIndex: dayIndex)
            }
        }
    }

    private func timeOfDayEditor(dayIndex: Int) -> some View {
        let weekday = program.days[dayIndex].scheduledWeekday
        let current = program.days[dayIndex].timeOfDay
        let usedByOther: Set<ProgramTimeOfDay> = Set(
            program.days.enumerated().compactMap { i, d in
                (i != dayIndex && d.scheduledWeekday == weekday) ? d.timeOfDay : nil
            }
        )
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(PepTheme.amber)
                Text("TIME OF DAY")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.8))
                    .tracking(0.8)
            }
            HStack(spacing: 6) {
                ForEach(ProgramTimeOfDay.allCases) { time in
                    let isSelected = current == time
                    let isTaken = usedByOther.contains(time) && !isSelected
                    Button {
                        withAnimation(.spring(duration: 0.2)) {
                            program.days[dayIndex].timeOfDay = isSelected ? nil : time
                            saveChanges()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: time.icon)
                                .font(.system(size: 10))
                            Text(time.label)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(
                            isSelected ? .black : (isTaken ? PepTheme.textSecondary.opacity(0.4) : PepTheme.textPrimary)
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(
                            isSelected
                                ? PepTheme.amber
                                : (isTaken ? PepTheme.elevated.opacity(0.4) : PepTheme.elevated)
                        )
                        .clipShape(.rect(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                    .disabled(isTaken)
                }
            }
        }
        .padding(10)
        .background(PepTheme.amber.opacity(0.06))
        .clipShape(.rect(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(PepTheme.amber.opacity(0.2), lineWidth: 0.5)
        )
    }

    private func ensureTimeOfDayAssignments(forWeekday weekday: Int) {
        let indices = program.days.indices.filter { program.days[$0].scheduledWeekday == weekday }
        if indices.count <= 1 {
            if let only = indices.first {
                program.days[only].timeOfDay = nil
            }
            return
        }
        var used: Set<ProgramTimeOfDay> = []
        for i in indices {
            if let t = program.days[i].timeOfDay, !used.contains(t) {
                used.insert(t)
            } else {
                program.days[i].timeOfDay = nil
            }
        }
        let available = ProgramTimeOfDay.allCases.filter { !used.contains($0) }
        var pool = available
        for i in indices where program.days[i].timeOfDay == nil {
            if let next = pool.first {
                program.days[i].timeOfDay = next
                pool.removeFirst()
            }
        }
    }

    // MARK: - Helpers

    private func saveChanges() {
        viewModel.updateProgram(program)
        hasChanges = true
    }
}
