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
            .background(PepTheme.background.ignoresSafeArea())
            .navigationTitle("Edit Split")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(PepTheme.teal)
                }
            }
            .onAppear {
                let plan = viewModel.todaysPlan
                editedDays = plan.splitDays
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(PepTheme.background)
    }

    private var splitOverview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.teal)
                Text("Weekly Split")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
            }

            VStack(spacing: 8) {
                ForEach(Array(editedDays.enumerated()), id: \.element.id) { index, day in
                    splitDayEditRow(day: day, index: index)
                }
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

    private func splitDayEditRow(day: SplitDay, index: Int) -> some View {
        HStack(spacing: 12) {
            Text("Day \(index + 1)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(day.isToday ? PepTheme.teal : PepTheme.textSecondary)
                .frame(width: 44, alignment: .leading)

            if day.isToday {
                Circle()
                    .fill(PepTheme.teal)
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
                        .foregroundStyle(day.isRest ? PepTheme.textSecondary.opacity(0.5) : PepTheme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(PepTheme.elevated)
                .clipShape(.rect(cornerRadius: 10))
            }
        }
    }

    private var exercisesList: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "dumbbell.fill")
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.teal)
                Text("Today's Exercises")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                Text("\(viewModel.todaysPlan.planExercises.count) total")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }

            ForEach(Array(viewModel.todaysPlan.planExercises.enumerated()), id: \.element.id) { index, exercise in
                exerciseEditRow(exercise, index: index + 1)
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

    private func exerciseEditRow(_ exercise: PlanExercise, index: Int) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(PepTheme.teal.opacity(0.12))
                    .frame(width: 32, height: 32)
                Text("\(index)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.teal)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(exercise.muscle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                    Text("·")
                        .foregroundStyle(PepTheme.textSecondary)
                    Text(exercise.equipment)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(exercise.sets) sets")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("\(exercise.repsMin)-\(exercise.repsMax) reps")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(PepTheme.teal.opacity(0.7))
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(PepTheme.elevated.opacity(0.4))
        .clipShape(.rect(cornerRadius: 10))
    }
}
