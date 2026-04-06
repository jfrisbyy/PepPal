import SwiftUI

struct CyclingWorkoutBuilderView: View {
    @Bindable var cyclingVM: CyclingViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var workoutName: String = ""
    @State private var workoutType: CyclingWorkoutType = .intervals
    @State private var intervals: [CyclingInterval] = [CyclingInterval()]

    private let accentColor = Color(red: 0.95, green: 0.45, blue: 0.0)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    savedWorkoutsSection
                    builderSection
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(FrisTheme.background.ignoresSafeArea())
            .navigationTitle("Ride Workouts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(FrisTheme.textSecondary)
                }
            }
        }
    }

    private var savedWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tray.full.fill")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Saved Workouts")
                Spacer()
                Text("\(cyclingVM.savedCyclingWorkouts.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(accentColor)
            }

            if cyclingVM.savedCyclingWorkouts.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "figure.outdoor.cycle")
                            .font(.title2)
                            .foregroundStyle(FrisTheme.textSecondary.opacity(0.4))
                        Text("No saved ride workouts yet")
                            .font(.caption)
                            .foregroundStyle(FrisTheme.textSecondary)
                    }
                    .padding(.vertical, 14)
                    Spacer()
                }
            } else {
                ForEach(cyclingVM.savedCyclingWorkouts) { workout in
                    savedWorkoutRow(workout)
                }
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private func savedWorkoutRow(_ workout: CustomCyclingWorkout) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: workout.type.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(workout.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FrisTheme.textPrimary)
                HStack(spacing: 8) {
                    Label(workout.type.rawValue, systemImage: workout.type.icon)
                    Label("\(workout.intervals.count) blocks", systemImage: "repeat")
                    Label("~\(workout.estimatedDurationMinutes) min", systemImage: "clock")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(FrisTheme.textSecondary)
            }

            Spacer()

            Button {
                cyclingVM.savedCyclingWorkouts.removeAll { $0.id == workout.id }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(.red.opacity(0.6))
                    .frame(width: 28, height: 28)
                    .background(FrisTheme.elevated.opacity(0.5))
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, 4)
    }

    private var builderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "plus.square.fill")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Build New Workout")
                Spacer()
            }

            TextField("Workout Name", text: $workoutName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(FrisTheme.textPrimary)
                .padding(12)
                .background(FrisTheme.elevated.opacity(0.5))
                .clipShape(.rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 6) {
                Text("TYPE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(FrisTheme.textSecondary)
                    .tracking(1)

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(CyclingWorkoutType.allCases) { type in
                            Button {
                                withAnimation(.spring(response: 0.25)) { workoutType = type }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: type.icon)
                                        .font(.system(size: 11))
                                    Text(type.rawValue)
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundStyle(workoutType == type ? .black : FrisTheme.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(workoutType == type ? accentColor : FrisTheme.elevated)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .contentMargins(.horizontal, 0)
                .scrollIndicators(.hidden)
            }

            ForEach(Array(intervals.enumerated()), id: \.element.id) { index, _ in
                intervalEditor(index: index)
            }

            Button {
                intervals.append(CyclingInterval())
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                    Text("Add Block")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(accentColor.opacity(0.08))
                .clipShape(.rect(cornerRadius: 10))
            }

            if !intervals.isEmpty {
                workoutSummary
            }

            saveButton
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private func intervalEditor(index: Int) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("Block \(index + 1)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(accentColor)
                Spacer()
                if intervals.count > 1 {
                    Button {
                        intervals.remove(at: index)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(FrisTheme.textSecondary.opacity(0.5))
                    }
                }
            }

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Reps")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(FrisTheme.textSecondary)
                    Stepper("\(intervals[index].repetitions)x", value: $intervals[index].repetitions, in: 1...20)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FrisTheme.textPrimary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Duration")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(FrisTheme.textSecondary)
                    Picker("", selection: $intervals[index].durationMinutes) {
                        ForEach([1, 2, 3, 5, 8, 10, 15, 20, 30], id: \.self) { d in
                            Text("\(d) min").tag(d)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(accentColor)
                }
            }

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Power (W)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(FrisTheme.textSecondary)
                    HStack(spacing: 4) {
                        TextField("Low", value: $intervals[index].targetPowerLow, format: .number)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(FrisTheme.textPrimary)
                            .frame(width: 44)
                            .keyboardType(.numberPad)
                        Text("-")
                            .foregroundStyle(FrisTheme.textSecondary)
                        TextField("High", value: $intervals[index].targetPowerHigh, format: .number)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(FrisTheme.textPrimary)
                            .frame(width: 44)
                            .keyboardType(.numberPad)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Rest")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(FrisTheme.textSecondary)
                    Stepper("\(intervals[index].restMinutes) min", value: $intervals[index].restMinutes, in: 0...10)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FrisTheme.textPrimary)
                }
            }

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Cadence (RPM)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(FrisTheme.textSecondary)
                    HStack(spacing: 4) {
                        TextField("Low", value: $intervals[index].cadenceLow, format: .number)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(FrisTheme.textPrimary)
                            .frame(width: 40)
                            .keyboardType(.numberPad)
                        Text("-")
                            .foregroundStyle(FrisTheme.textSecondary)
                        TextField("High", value: $intervals[index].cadenceHigh, format: .number)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(FrisTheme.textPrimary)
                            .frame(width: 40)
                            .keyboardType(.numberPad)
                    }
                }
                Spacer()
            }

            Text(intervals[index].description)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(FrisTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(FrisTheme.elevated.opacity(0.3))
        .clipShape(.rect(cornerRadius: 10))
    }

    private var workoutSummary: some View {
        HStack(spacing: 16) {
            let totalMin = intervals.reduce(0) { $0 + ($1.durationMinutes + $1.restMinutes) * $1.repetitions }
            let totalSets = intervals.reduce(0) { $0 + $1.repetitions }
            VStack(spacing: 2) {
                Text("~\(totalMin) min")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(accentColor)
                Text("Est. Duration")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(FrisTheme.textSecondary)
            }
            VStack(spacing: 2) {
                Text("\(totalSets)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(FrisTheme.textPrimary)
                Text("Total Reps")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(FrisTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(FrisTheme.elevated.opacity(0.3))
        .clipShape(.rect(cornerRadius: 10))
    }

    private var saveButton: some View {
        let canSave = !workoutName.trimmingCharacters(in: .whitespaces).isEmpty && !intervals.isEmpty
        return Button {
            guard canSave else { return }
            let workout = CustomCyclingWorkout(name: workoutName, type: workoutType, intervals: intervals)
            cyclingVM.savedCyclingWorkouts.append(workout)
            workoutName = ""
            intervals = [CyclingInterval()]
            workoutType = .intervals
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                Text("Save Workout")
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(accentColor)
            .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.scalePrimary)
        .opacity(canSave ? 1 : 0.5)
        .disabled(!canSave)
    }

    private func cardBorder() -> some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(
                LinearGradient(colors: [FrisTheme.glassBorderTop, FrisTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 0.5
            )
    }
}
