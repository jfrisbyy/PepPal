import SwiftUI

struct EditSplitSheet: View {
    @Bindable var viewModel: HomeViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var editedDays: [SplitDay] = []
    @State private var selectedDayIndex: Int? = nil

    private let dayNames = ["Push", "Pull", "Legs", "Upper", "Lower", "Chest & Back", "Arms", "Full Body", "Cardio", "Rest"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    splitOverview
                    exercisesList
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(FrisTheme.background.ignoresSafeArea())
            .navigationTitle("Edit Split")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(FrisTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.todaysPlan = WorkoutPlan(
                            name: viewModel.todaysPlan.name,
                            exercises: viewModel.todaysPlan.exercises,
                            estimatedMinutes: viewModel.todaysPlan.estimatedMinutes,
                            isRestDay: viewModel.todaysPlan.isRestDay,
                            recoveryTip: viewModel.todaysPlan.recoveryTip,
                            planExercises: viewModel.todaysPlan.planExercises,
                            splitDays: editedDays
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(FrisTheme.cyan)
                }
            }
            .onAppear {
                editedDays = viewModel.todaysPlan.splitDays
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(FrisTheme.background)
    }

    private var splitOverview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.subheadline)
                    .foregroundStyle(FrisTheme.cyan)
                Text("Weekly Split")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(FrisTheme.textPrimary)
            }

            VStack(spacing: 8) {
                ForEach(Array(editedDays.enumerated()), id: \.element.id) { index, day in
                    splitDayEditRow(day: day, index: index)
                }
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
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

    private func splitDayEditRow(day: SplitDay, index: Int) -> some View {
        HStack(spacing: 12) {
            Text("Day \(index + 1)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(day.isToday ? FrisTheme.cyan : FrisTheme.textSecondary)
                .frame(width: 44, alignment: .leading)

            if day.isToday {
                Circle()
                    .fill(FrisTheme.cyan)
                    .frame(width: 6, height: 6)
            }

            Menu {
                ForEach(dayNames, id: \.self) { name in
                    Button(name) {
                        editedDays[index] = SplitDay(
                            dayIndex: day.dayIndex,
                            name: name,
                            isToday: day.isToday,
                            isRest: name == "Rest"
                        )
                    }
                }
            } label: {
                HStack {
                    Text(day.name)
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(day.isRest ? FrisTheme.textSecondary.opacity(0.5) : FrisTheme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(FrisTheme.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(FrisTheme.elevated)
                .clipShape(.rect(cornerRadius: 10))
            }
        }
    }

    private var exercisesList: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "dumbbell.fill")
                    .font(.subheadline)
                    .foregroundStyle(FrisTheme.cyan)
                Text("Today's Exercises")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(FrisTheme.textPrimary)
                Spacer()
                Text("\(viewModel.todaysPlan.planExercises.count) total")
                    .font(.caption)
                    .foregroundStyle(FrisTheme.textSecondary)
            }

            ForEach(Array(viewModel.todaysPlan.planExercises.enumerated()), id: \.element.id) { index, exercise in
                exerciseEditRow(exercise, index: index + 1)
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
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

    private func exerciseEditRow(_ exercise: PlanExercise, index: Int) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(FrisTheme.cyan.opacity(0.12))
                    .frame(width: 32, height: 32)
                Text("\(index)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(FrisTheme.cyan)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(FrisTheme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(exercise.muscle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(FrisTheme.textSecondary)
                    Text("·")
                        .foregroundStyle(FrisTheme.textSecondary)
                    Text(exercise.equipment)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(FrisTheme.textSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(exercise.sets) sets")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(FrisTheme.textPrimary)
                Text("\(exercise.repsMin)-\(exercise.repsMax) reps")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(FrisTheme.cyan.opacity(0.7))
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(FrisTheme.elevated.opacity(0.4))
        .clipShape(.rect(cornerRadius: 10))
    }
}
