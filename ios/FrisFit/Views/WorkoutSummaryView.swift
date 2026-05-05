import SwiftUI

struct WorkoutSummaryView: View {
    let summary: WorkoutSummary
    var exercises: [WorkoutExercise] = []
    var sourceProgramId: UUID? = nil
    let onDone: () -> Void

    @State private var showStats: Bool = false
    @State private var showPRs: Bool = false
    @State private var showSaveAsRoutine: Bool = false
    @State private var didSaveRoutine: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 20)

                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(PepTheme.teal)
                        .symbolEffect(.bounce, value: showStats)

                    Text("Workout Complete")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(PepTheme.textPrimary)

                    Text(summary.workoutName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }

                if showStats {
                    statsGrid
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if showPRs && !summary.personalRecords.isEmpty {
                    prSection
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer().frame(height: 8)

                VStack(spacing: 12) {
                    if canSaveAsRoutine {
                        Button {
                            showSaveAsRoutine = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: didSaveRoutine ? "checkmark.circle.fill" : "bookmark.fill")
                                    .font(.subheadline.weight(.semibold))
                                Text(didSaveRoutine ? "Saved as Routine" : "Save as Routine")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(didSaveRoutine ? .green : PepTheme.amber)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background((didSaveRoutine ? Color.green : PepTheme.amber).opacity(0.12))
                            .clipShape(.rect(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder((didSaveRoutine ? Color.green : PepTheme.amber).opacity(0.3), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.scale)
                        .disabled(didSaveRoutine)
                    }

                    Button {
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.subheadline.weight(.semibold))
                            Text("Share Workout")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(PepTheme.teal)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(PepTheme.teal.opacity(0.12))
                        .clipShape(.rect(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(PepTheme.teal.opacity(0.3), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.scale)

                    Button(action: onDone) {
                        Text("Done")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(PepTheme.teal)
                            .clipShape(.rect(cornerRadius: 14))
                    }
                    .buttonStyle(.scalePrimary)
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .appBackground()
        .onAppear {
            animateIn()
            WorkoutState.shared.isWorkoutActive = false
            WorkoutState.shared.workoutProgress = 0
        }
        .sensoryFeedback(.success, trigger: showStats)
        .sheet(isPresented: $showSaveAsRoutine) {
            SaveAsRoutineSheet(
                defaultName: defaultRoutineName,
                exercises: exercises
            ) {
                didSaveRoutine = true
            }
            .presentationDetents([.large])
        }
    }

    private var canSaveAsRoutine: Bool {
        guard sourceProgramId == nil else { return false }
        return exercises.contains { ex in ex.sets.contains { $0.isCompleted } }
    }

    private var defaultRoutineName: String {
        if !summary.workoutName.isEmpty && summary.workoutName != "Workout" {
            return summary.workoutName
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return "\(formatter.string(from: Date())) Workout"
    }

    private var statsGrid: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statCard(icon: "clock.fill", label: "Duration", value: formattedDuration)
                caloriesCard
                statCard(icon: "scalemass.fill", label: "Volume", value: formattedVolume)
                statCard(icon: "checkmark.circle.fill", label: "Sets", value: "\(summary.totalSets)")
            }

            let exerciseCount = summary.totalSets > 0 ? summary.totalSets / 3 : 0
            statCard(icon: "figure.strengthtraining.traditional", label: "Exercises", value: "\(exerciseCount)")
        }
        .padding(.horizontal, 4)
    }

    private var caloriesCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.title3)
                .foregroundStyle(.orange)

            Text("\(summary.caloriesBurned)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(PepTheme.textPrimary)

            Text("Calories")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.08), Color.orange.opacity(0.03)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.orange.opacity(0.25), lineWidth: 0.5)
        )
    }

    private func statCard(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(PepTheme.teal.opacity(0.8))

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(PepTheme.textPrimary)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private var prSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(PepTheme.amber)
                Text("Personal Records")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
            }

            ForEach(summary.personalRecords) { pr in
                HStack(spacing: 14) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(PepTheme.amber)
                        .frame(width: 32, height: 32)
                        .background(PepTheme.amber.opacity(0.12))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(pr.exerciseName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("\(pr.recordType) — \(pr.value)")
                            .font(.caption)
                            .foregroundStyle(PepTheme.amber)
                    }

                    Spacer()
                }
                .padding(12)
                .background(PepTheme.amber.opacity(0.06))
                .clipShape(.rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(PepTheme.amber.opacity(0.2), lineWidth: 0.5)
                )
            }
        }
        .padding(.horizontal, 4)
    }

    private var formattedDuration: String {
        let mins = Int(summary.duration) / 60
        if mins >= 60 {
            return "\(mins / 60)h \(mins % 60)m"
        }
        return "\(mins)m"
    }

    private var formattedVolume: String {
        if summary.totalVolume >= 1000 {
            return String(format: "%.1fk", summary.totalVolume / 1000)
        }
        return "\(Int(summary.totalVolume))"
    }

    private func animateIn() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3)) {
            showStats = true
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.7)) {
            showPRs = true
        }
    }
}
