import SwiftUI

struct ProgramScheduleStep: View {
    @Bindable var viewModel: TrainViewModel
    @State private var showExercisePicker: Bool = false
    @State private var pickerDayIndex: Int = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                scheduleHeader
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

    private var scheduleHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WEEKLY SCHEDULE")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(PepTheme.textSecondary)
                .tracking(1)
            Text("Pick the day of the week for each workout and add your exercises.")
                .font(.system(size: 12))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dayCard(index: Int, day: ProgramDay) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("DAY \(index + 1)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PepTheme.teal)
                    .tracking(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(PepTheme.teal.opacity(0.12))
                    .clipShape(Capsule())

                Spacer()

                if !day.exercises.isEmpty {
                    Text("\(day.exercises.count) exercise\(day.exercises.count == 1 ? "" : "s")")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }

            TextField("", text: Binding(
                get: { viewModel.programDays[index].name },
                set: { viewModel.programDays[index].name = $0 }
            ), prompt: Text("Day name (e.g. Push Day)").foregroundStyle(PepTheme.textSecondary.opacity(0.4)))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .padding(12)
                .background(PepTheme.elevated)
                .clipShape(.rect(cornerRadius: 10))

            weekdaySelector(dayIndex: index)

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
                .foregroundStyle(PepTheme.teal)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(PepTheme.teal.opacity(0.08))
                .clipShape(.rect(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(PepTheme.teal.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .padding(14)
        .background(PepTheme.cardSurface)
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

    private func weekdaySelector(dayIndex: Int) -> some View {
        let selected = viewModel.programDays[dayIndex].scheduledWeekday
        let sharedWeekday: Int? = {
            guard let wd = selected else { return nil }
            let count = viewModel.programDays.filter { $0.scheduledWeekday == wd }.count
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
                    let sharedCount = viewModel.programDays.filter { $0.scheduledWeekday == weekday.rawValue && $0.id != viewModel.programDays[dayIndex].id }.count
                    Button {
                        withAnimation(.spring(duration: 0.2)) {
                            viewModel.setWeekday(weekday.rawValue, forDayAt: dayIndex)
                        }
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Text(weekday.singleLetter)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(isSelected ? .black : PepTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .background(isSelected ? PepTheme.teal : PepTheme.elevated)
                                .clipShape(.rect(cornerRadius: 9))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 9)
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
                }
            }
            if sharedWeekday != nil {
                timeOfDaySelector(dayIndex: dayIndex)
            }
        }
    }

    private func timeOfDaySelector(dayIndex: Int) -> some View {
        let weekday = viewModel.programDays[dayIndex].scheduledWeekday
        let current = viewModel.programDays[dayIndex].timeOfDay
        let usedByOther: Set<ProgramTimeOfDay> = Set(
            viewModel.programDays.enumerated().compactMap { i, d in
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
                            viewModel.setTimeOfDay(isSelected ? nil : time, forDayAt: dayIndex)
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
                        .frame(height: 32)
                        .background(
                            isSelected
                                ? PepTheme.amber
                                : (isTaken ? PepTheme.elevated.opacity(0.4) : PepTheme.elevated)
                        )
                        .clipShape(.rect(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(
                                    isSelected ? Color.clear : PepTheme.glassBorderTop,
                                    lineWidth: 0.5
                                )
                        )
                    }
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
                        .background(PepTheme.glassBorderTop)
                }
            }
        }
        .background(PepTheme.elevated)
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
                        .foregroundStyle(PepTheme.teal)
                        .frame(width: 28, height: 28)
                        .background(PepTheme.teal.opacity(0.1))
                        .clipShape(.rect(cornerRadius: 7))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.exerciseName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                            .lineLimit(1)
                        Text("\(exercise.targetSets) sets × \(exercise.targetRepsMin)-\(exercise.targetRepsMax) reps")
                            .font(.system(size: 11))
                            .foregroundStyle(PepTheme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary)
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
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                HStack(spacing: 8) {
                    Button {
                        if exercise.restSeconds > 15 { exercise.restSeconds -= 15 }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(PepTheme.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(PepTheme.elevated)
                            .clipShape(Circle())
                    }
                    Text("\(exercise.restSeconds)s")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .frame(width: 48)
                    Button {
                        if exercise.restSeconds < 300 { exercise.restSeconds += 15 }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(PepTheme.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(PepTheme.elevated)
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
                .foregroundStyle(PepTheme.textSecondary)
            HStack(spacing: 4) {
                Button {
                    if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(PepTheme.elevated)
                        .clipShape(Circle())
                }
                Text("\(value.wrappedValue)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .frame(width: 28)
                Button {
                    if value.wrappedValue < range.upperBound { value.wrappedValue += 1 }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(PepTheme.elevated)
                        .clipShape(Circle())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 8))
    }
}
