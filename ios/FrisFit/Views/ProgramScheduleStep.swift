import SwiftUI

struct ProgramScheduleStep: View {
    @Bindable var viewModel: TrainViewModel
    @State private var showExercisePicker: Bool = false
    @State private var pickerDayIndex: Int = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(Array(viewModel.programDays.enumerated()), id: \.element.id) { index, day in
                    dayCard(index: index, day: day)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerView { selectedExercises in
                viewModel.addExercisesToDay(at: pickerDayIndex, exercises: selectedExercises)
            }
        }
    }

    private func dayCard(index: Int, day: ProgramDay) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("DAY \(index + 1)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(FrisTheme.cyan)
                    .tracking(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(FrisTheme.cyan.opacity(0.12))
                    .clipShape(Capsule())

                Spacer()

                if !day.exercises.isEmpty {
                    Text("\(day.exercises.count) exercise\(day.exercises.count == 1 ? "" : "s")")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(FrisTheme.textSecondary)
                }
            }

            TextField("", text: Binding(
                get: { viewModel.programDays[index].name },
                set: { viewModel.programDays[index].name = $0 }
            ), prompt: Text("Day name (e.g. Push Day)").foregroundStyle(FrisTheme.textSecondary.opacity(0.4)))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FrisTheme.textPrimary)
                .padding(12)
                .background(FrisTheme.elevated)
                .clipShape(.rect(cornerRadius: 10))

            if !day.exercises.isEmpty {
                exercisesList(dayIndex: index)
            }

            Button {
                pickerDayIndex = index
                showExercisePicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.subheadline)
                    Text("Add Exercises")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(FrisTheme.cyan)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(FrisTheme.cyan.opacity(0.08))
                .clipShape(.rect(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(FrisTheme.cyan.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .padding(14)
        .background(FrisTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [FrisTheme.glassBorderTop, FrisTheme.glassBorderBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }

    private func exercisesList(dayIndex: Int) -> some View {
        VStack(spacing: 0) {
            let exercises = viewModel.programDays[dayIndex].exercises
            ForEach(Array(exercises.enumerated()), id: \.element.id) { exIndex, exercise in
                ScheduleExerciseRow(
                    exercise: Binding(
                        get: { viewModel.programDays[dayIndex].exercises[exIndex] },
                        set: { viewModel.programDays[dayIndex].exercises[exIndex] = $0 }
                    ),
                    onDelete: {
                        withAnimation(.spring(duration: 0.25)) {
                            let idx: Int = exIndex
                            viewModel.programDays[dayIndex].exercises.remove(at: idx)
                        }
                    }
                )

                if exIndex < exercises.count - 1 {
                    Divider()
                        .background(FrisTheme.glassBorderTop)
                }
            }
        }
        .background(FrisTheme.elevated)
        .clipShape(.rect(cornerRadius: 10))
    }
}

private struct ScheduleExerciseRow: View {
    @Binding var exercise: ProgramExercise
    let onDelete: () -> Void
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: exercise.primaryMuscle.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(FrisTheme.cyan)
                        .frame(width: 28, height: 28)
                        .background(FrisTheme.cyan.opacity(0.1))
                        .clipShape(.rect(cornerRadius: 7))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.exerciseName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(FrisTheme.textPrimary)
                            .lineLimit(1)
                        Text("\(exercise.targetSets) sets × \(exercise.targetRepsMin)-\(exercise.targetRepsMax) reps")
                            .font(.system(size: 11))
                            .foregroundStyle(FrisTheme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(FrisTheme.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }

            if isExpanded {
                expandedConfig
            }
        }
    }

    private var expandedConfig: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                configStepper(label: "Sets", value: $exercise.targetSets, range: 1...10)
                configStepper(label: "Min Reps", value: $exercise.targetRepsMin, range: 1...50)
                configStepper(label: "Max Reps", value: $exercise.targetRepsMax, range: 1...50)
            }

            HStack {
                Text("Rest")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FrisTheme.textSecondary)
                Spacer()
                HStack(spacing: 8) {
                    Button {
                        if exercise.restSeconds > 15 { exercise.restSeconds -= 15 }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(FrisTheme.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(FrisTheme.elevated)
                            .clipShape(Circle())
                    }
                    Text("\(exercise.restSeconds)s")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(FrisTheme.textPrimary)
                        .frame(width: 48)
                    Button {
                        if exercise.restSeconds < 300 { exercise.restSeconds += 15 }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(FrisTheme.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(FrisTheme.elevated)
                            .clipShape(Circle())
                    }
                }
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                    Text("Remove")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.red.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(.red.opacity(0.08))
                .clipShape(.rect(cornerRadius: 8))
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private func configStepper(label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(FrisTheme.textSecondary)
            HStack(spacing: 4) {
                Button {
                    if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(FrisTheme.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(FrisTheme.elevated)
                        .clipShape(Circle())
                }
                Text("\(value.wrappedValue)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(FrisTheme.textPrimary)
                    .frame(width: 28)
                Button {
                    if value.wrappedValue < range.upperBound { value.wrappedValue += 1 }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(FrisTheme.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(FrisTheme.elevated)
                        .clipShape(Circle())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(FrisTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 8))
    }
}
