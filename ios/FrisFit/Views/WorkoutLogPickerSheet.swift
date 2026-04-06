import SwiftUI

struct WorkoutLogPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (WorkoutLogAttachment) -> Void

    private let recentWorkouts: [WorkoutLogAttachment] = [
        WorkoutLogAttachment(workoutName: "Push Day — Chest & Shoulders", duration: 62, exerciseCount: 6, totalVolume: 14520, fpEarned: 185, date: Date().addingTimeInterval(-3600)),
        WorkoutLogAttachment(workoutName: "Pull Day — Back & Biceps", duration: 58, exerciseCount: 7, totalVolume: 12800, fpEarned: 172, date: Date().addingTimeInterval(-86400)),
        WorkoutLogAttachment(workoutName: "Leg Day — Squat Focus", duration: 75, exerciseCount: 5, totalVolume: 18200, fpEarned: 220, date: Date().addingTimeInterval(-172800)),
        WorkoutLogAttachment(workoutName: "Upper Body Hypertrophy", duration: 68, exerciseCount: 8, totalVolume: 16400, fpEarned: 198, date: Date().addingTimeInterval(-259200)),
        WorkoutLogAttachment(workoutName: "Full Body GZCLP Day A", duration: 55, exerciseCount: 4, totalVolume: 9800, fpEarned: 145, date: Date().addingTimeInterval(-345600)),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(recentWorkouts.enumerated()), id: \.offset) { _, workout in
                        Button {
                            onSelect(workout)
                            dismiss()
                        } label: {
                            workoutRow(workout)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(PepTheme.background)
            .navigationTitle("Attach Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }

    private func workoutRow(_ workout: WorkoutLogAttachment) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(PepTheme.teal.opacity(0.12))
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.title3)
                        .foregroundStyle(PepTheme.teal)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(workout.workoutName)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label("\(workout.duration)m", systemImage: "clock")
                    Label("\(workout.exerciseCount) ex", systemImage: "dumbbell")
                    Label("\(workout.fpEarned) FP", systemImage: "bolt.fill")
                }
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(workout.date.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.caption2)
                    .foregroundStyle(PepTheme.textSecondary)
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(PepTheme.teal)
            }
        }
        .padding(12)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 12))
    }
}
