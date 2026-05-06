import SwiftUI

struct RunningWorkoutBuilderView: View {
    @Bindable var runVM: RunningViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var workoutName: String = ""
    @State private var workoutType: RunningWorkoutType = .intervalSession
    @State private var intervals: [RunningInterval] = [RunningInterval()]

    private let accentColor = Color(red: 0.0, green: 0.9, blue: 1.0)

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
            .appBackground()
            .navigationTitle("Run Workouts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }

    private var savedWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(
                kicker: "LIBRARY",
                title: "Saved Workouts",
                accent: accentColor,
                trailing: AnyView(
                    Text("\(runVM.savedRunWorkouts.count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(accentColor)
                )
            )

            if runVM.savedRunWorkouts.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "figure.run")
                            .font(.title2)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                        Text("No saved run workouts yet")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .padding(.vertical, 14)
                    Spacer()
                }
            } else {
                ForEach(runVM.savedRunWorkouts) { workout in
                    savedWorkoutRow(workout)
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private func savedWorkoutRow(_ workout: CustomRunWorkout) -> some View {
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
                    .foregroundStyle(PepTheme.textPrimary)
                HStack(spacing: 8) {
                    Label(workout.type.rawValue, systemImage: workout.type.icon)
                    Label("\(workout.intervals.count) sets", systemImage: "repeat")
                    Label("~\(workout.estimatedDurationMinutes) min", systemImage: "clock")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            Button {
                runVM.savedRunWorkouts.removeAll { $0.id == workout.id }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(.red.opacity(0.6))
                    .frame(width: 28, height: 28)
                    .background(PepTheme.elevated.opacity(0.5))
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, 4)
    }

    private var builderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(
                kicker: "BUILD",
                title: "New Workout",
                accent: accentColor,
                trailing: AnyView(
                    Image(systemName: "plus.square.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(accentColor.opacity(0.7))
                )
            )

            TextField("Workout Name", text: $workoutName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(PepTheme.textPrimary)
                .padding(12)
                .background(PepTheme.elevated.opacity(0.5))
                .clipShape(.rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 6) {
                Text("TYPE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .tracking(1)

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(RunningWorkoutType.allCases) { type in
                            Button {
                                withAnimation(.spring(response: 0.25)) { workoutType = type }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: type.icon)
                                        .font(.system(size: 11))
                                    Text(type.rawValue)
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundStyle(workoutType == type ? .black : PepTheme.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(workoutType == type ? accentColor : PepTheme.elevated)
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
                intervals.append(RunningInterval())
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                    Text("Add Interval")
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
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private func intervalEditor(index: Int) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("Interval \(index + 1)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(accentColor)
                Spacer()
                if intervals.count > 1 {
                    Button {
                        intervals.remove(at: index)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                    }
                }
            }

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Reps")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                    Stepper("\(intervals[index].repetitions)x", value: $intervals[index].repetitions, in: 1...20)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Distance")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                    Picker("", selection: $intervals[index].distanceMeters) {
                        ForEach([200, 400, 600, 800, 1000, 1600, 3200], id: \.self) { d in
                            Text("\(d)m").tag(d)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(accentColor)
                }
            }

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Target Pace (min/mi)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                    HStack(spacing: 4) {
                        TextField("Min", value: $intervals[index].targetPaceMin, format: .number)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                            .frame(width: 40)
                            .keyboardType(.decimalPad)
                        Text("-")
                            .foregroundStyle(PepTheme.textSecondary)
                        TextField("Max", value: $intervals[index].targetPaceMax, format: .number)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                            .frame(width: 40)
                            .keyboardType(.decimalPad)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Rest")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                    Stepper("\(intervals[index].restSeconds)s", value: $intervals[index].restSeconds, in: 0...300, step: 15)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                }
            }

            Text(intervals[index].description)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(PepTheme.elevated.opacity(0.3))
        .clipShape(.rect(cornerRadius: 10))
    }

    private var workoutSummary: some View {
        HStack(spacing: 16) {
            let totalDist = intervals.reduce(0) { $0 + $1.distanceMeters * $1.repetitions }
            let totalSets = intervals.reduce(0) { $0 + $1.repetitions }
            VStack(spacing: 2) {
                Text(totalDist >= 1000 ? String(format: "%.1fkm", Double(totalDist) / 1000.0) : "\(totalDist)m")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(accentColor)
                Text("Total Distance")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            VStack(spacing: 2) {
                Text("\(totalSets)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Total Reps")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(PepTheme.elevated.opacity(0.3))
        .clipShape(.rect(cornerRadius: 10))
    }

    private var saveButton: some View {
        let canSave = !workoutName.trimmingCharacters(in: .whitespaces).isEmpty && !intervals.isEmpty
        return Button {
            guard canSave else { return }
            let workout = CustomRunWorkout(name: workoutName, type: workoutType, intervals: intervals)
            runVM.savedRunWorkouts.append(workout)
            workoutName = ""
            intervals = [RunningInterval()]
            workoutType = .intervalSession
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
                LinearGradient(colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 0.5
            )
    }
}
