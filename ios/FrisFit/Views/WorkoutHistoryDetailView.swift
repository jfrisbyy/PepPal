import SwiftUI

struct WorkoutHistoryDetailView: View {
    let workout: WorkoutHistoryDetail

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                summaryHeader
                exercisesList
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(PepTheme.background.ignoresSafeArea())
        .navigationTitle("Workout Details")
        .navigationBarTitleDisplayMode(.inline)
        
    }

    private var summaryHeader: some View {
        VStack(spacing: 16) {
            Text(workout.name)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
                .multilineTextAlignment(.center)

            Text(workout.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)

            HStack(spacing: 0) {
                SummaryStatItem(value: "\(workout.durationMinutes)", unit: "min", label: "Duration")
                SummaryStatItem(value: formatVolume(workout.totalVolume), unit: "lbs", label: "Volume")
                SummaryStatItem(value: "\(workout.fpEarned)", unit: "FP", label: "Earned", valueColor: PepTheme.teal)
                SummaryStatItem(value: "\(workout.exercises.count)", unit: "", label: "Exercises")
            }
            .padding(.vertical, 14)
            .background(PepTheme.elevated)
            .clipShape(.rect(cornerRadius: 12))
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    private var exercisesList: some View {
        VStack(spacing: 12) {
            ForEach(workout.exercises) { exercise in
                ExerciseDetailCard(exercise: exercise)
            }
        }
    }

    private func formatVolume(_ v: Int) -> String {
        if v >= 1000 {
            return String(format: "%.1fk", Double(v) / 1000.0)
        }
        return "\(v)"
    }
}

private struct SummaryStatItem: View {
    let value: String
    let unit: String
    let label: String
    var valueColor: Color = PepTheme.textPrimary

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(valueColor)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ExerciseDetailCard: View {
    let exercise: WorkoutHistoryExerciseDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(exercise.exerciseName)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)

            HStack {
                Text("SET")
                    .frame(width: 36)
                Text("WEIGHT")
                    .frame(maxWidth: .infinity)
                Text("REPS")
                    .frame(maxWidth: .infinity)
                Text("VOL")
                    .frame(maxWidth: .infinity)
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(PepTheme.textSecondary)

            ForEach(exercise.sets) { set in
                HStack {
                    Text("\(set.setNumber)")
                        .frame(width: 36)
                    Text("\(Int(set.weight)) lbs")
                        .frame(maxWidth: .infinity)
                    Text("\(set.reps)")
                        .frame(maxWidth: .infinity)
                    Text("\(Int(set.weight) * set.reps)")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(PepTheme.teal.opacity(0.8))
                }
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(PepTheme.textPrimary)
            }
        }
        .padding(14)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }
}
