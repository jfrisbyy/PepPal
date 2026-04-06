import SwiftUI

struct SwimWorkoutBuilderView: View {
    @Bindable var swimVM: SwimmingViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var workoutName: String = ""
    @State private var intervals: [SwimInterval] = [SwimInterval()]
    @State private var showingSaved: Bool = false

    private let accentColor = Color(red: 0.2, green: 0.6, blue: 1.0)

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
            .navigationTitle("Swim Workouts")
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
                Text("\(swimVM.savedWorkouts.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(accentColor)
            }

            if swimVM.savedWorkouts.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.title2)
                            .foregroundStyle(FrisTheme.textSecondary.opacity(0.4))
                        Text("No saved workouts yet")
                            .font(.caption)
                            .foregroundStyle(FrisTheme.textSecondary)
                    }
                    .padding(.vertical, 14)
                    Spacer()
                }
            } else {
                ForEach(swimVM.savedWorkouts) { workout in
                    savedWorkoutRow(workout)
                }
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private func savedWorkoutRow(_ workout: StructuredSwimWorkout) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 16))
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(workout.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FrisTheme.textPrimary)
                HStack(spacing: 8) {
                    Label("\(workout.totalDistance)m", systemImage: "water.waves")
                    Label("\(workout.intervals.count) sets", systemImage: "repeat")
                    Label("~\(workout.estimatedDurationMinutes) min", systemImage: "clock")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(FrisTheme.textSecondary)
            }

            Spacer()

            Button {
                swimVM.deleteSavedWorkout(workout.id)
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

            ForEach(Array(intervals.enumerated()), id: \.element.id) { index, interval in
                intervalEditor(index: index, interval: interval)
            }

            Button {
                intervals.append(SwimInterval())
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
                HStack(spacing: 16) {
                    let totalDist = intervals.reduce(0) { $0 + $1.totalDistance }
                    let totalSets = intervals.reduce(0) { $0 + $1.repetitions }
                    VStack(spacing: 2) {
                        Text("\(totalDist)m")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(accentColor)
                        Text("Total Distance")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(FrisTheme.textSecondary)
                    }
                    VStack(spacing: 2) {
                        Text("\(totalSets)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(FrisTheme.textPrimary)
                        Text("Total Sets")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(FrisTheme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(FrisTheme.elevated.opacity(0.3))
                .clipShape(.rect(cornerRadius: 10))
            }

            Button {
                guard !workoutName.trimmingCharacters(in: .whitespaces).isEmpty, !intervals.isEmpty else { return }
                let workout = StructuredSwimWorkout(name: workoutName, intervals: intervals)
                swimVM.addSavedWorkout(workout)
                workoutName = ""
                intervals = [SwimInterval()]
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
            .opacity(workoutName.trimmingCharacters(in: .whitespaces).isEmpty || intervals.isEmpty ? 0.5 : 1)
            .disabled(workoutName.trimmingCharacters(in: .whitespaces).isEmpty || intervals.isEmpty)
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private func intervalEditor(index: Int, interval: SwimInterval) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("Set \(index + 1)")
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
                    Text("Distance")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(FrisTheme.textSecondary)
                    Picker("", selection: $intervals[index].distanceMeters) {
                        ForEach([25, 50, 100, 200, 400, 800], id: \.self) { d in
                            Text("\(d)m").tag(d)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(accentColor)
                }
            }

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Stroke")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(FrisTheme.textSecondary)
                    Picker("", selection: $intervals[index].strokeType) {
                        ForEach(SwimStrokeType.allCases) { stroke in
                            Text(stroke.rawValue).tag(stroke)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(accentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Rest")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(FrisTheme.textSecondary)
                    Stepper("\(intervals[index].restSeconds)s", value: $intervals[index].restSeconds, in: 0...120, step: 5)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FrisTheme.textPrimary)
                }
            }

            Text(intervals[index].description + " · \(intervals[index].totalDistance)m total")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(FrisTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(FrisTheme.elevated.opacity(0.3))
        .clipShape(.rect(cornerRadius: 10))
    }

    private func cardBorder() -> some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(
                LinearGradient(colors: [FrisTheme.glassBorderTop, FrisTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 0.5
            )
    }
}
