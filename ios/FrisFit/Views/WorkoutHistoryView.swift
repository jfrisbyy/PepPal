import SwiftUI

struct WorkoutHistoryView: View {
    let viewModel: ProfileViewModel

    var body: some View {
        ScrollView {
            if viewModel.workoutHistory.isEmpty {
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: "No Workouts Yet",
                    message: "Complete your first workout to start building your history."
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.workoutHistory) { workout in
                        NavigationLink(value: ProfileDestination.historyDetail(workout)) {
                            WorkoutHistoryRow(workout: workout)
                        }
                        .buttonStyle(.scale)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
        .background(PepTheme.background.ignoresSafeArea())
        .navigationTitle("Workout History")
        .navigationBarTitleDisplayMode(.large)
        
    }
}

private struct WorkoutHistoryRow: View {
    let workout: WorkoutHistoryDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(workout.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }

            HStack(spacing: 16) {
                HistoryStatPill(icon: "clock", value: "\(workout.durationMinutes)m")
                HistoryStatPill(icon: "scalemass", value: "\(formatVolume(workout.totalVolume)) lbs")
                HistoryStatPill(icon: "bolt.fill", value: "\(workout.fpEarned) FP", color: PepTheme.teal)
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

    private func formatVolume(_ v: Int) -> String {
        if v >= 1000 {
            return String(format: "%.1fk", Double(v) / 1000.0)
        }
        return "\(v)"
    }
}

private struct HistoryStatPill: View {
    let icon: String
    let value: String
    var color: Color = PepTheme.textSecondary

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color)
        }
    }
}
