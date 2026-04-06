import SwiftUI

struct ProgramReviewStep: View {
    @Bindable var viewModel: TrainViewModel
    let onComplete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                programHeader

                statsRow

                ForEach(Array(viewModel.programDays.enumerated()), id: \.element.id) { index, day in
                    reviewDayCard(index: index, day: day)
                }

                completeButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
    }

    private var programHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("REVIEW YOUR PROGRAM")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(FrisTheme.textSecondary)
                .tracking(1)

            Text(viewModel.programName)
                .font(.title2.weight(.bold))
                .foregroundStyle(FrisTheme.textPrimary)

            HStack(spacing: 12) {
                Label(viewModel.programType.rawValue, systemImage: viewModel.programType.icon)
                Label("\(viewModel.daysPerWeek) days/week", systemImage: "calendar")
            }
            .font(.subheadline)
            .foregroundStyle(FrisTheme.textSecondary)
        }
    }

    private var statsRow: some View {
        let totalExercises = viewModel.programDays.reduce(0) { $0 + $1.exercises.count }
        let totalSets = viewModel.programDays.flatMap(\.exercises).reduce(0) { $0 + $1.targetSets }
        let muscles = Set(viewModel.programDays.flatMap(\.exercises).map(\.primaryMuscle))

        return HStack(spacing: 0) {
            statItem(value: "\(viewModel.daysPerWeek)", label: "Days")
            Divider().frame(height: 30).background(FrisTheme.glassBorderTop)
            statItem(value: "\(totalExercises)", label: "Exercises")
            Divider().frame(height: 30).background(FrisTheme.glassBorderTop)
            statItem(value: "\(totalSets)", label: "Total Sets")
            Divider().frame(height: 30).background(FrisTheme.glassBorderTop)
            statItem(value: "\(muscles.count)", label: "Muscles")
        }
        .padding(.vertical, 14)
        .background(FrisTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(FrisTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(FrisTheme.cyan)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(FrisTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func reviewDayCard(index: Int, day: ProgramDay) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("DAY \(index + 1)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(FrisTheme.cyan)
                    .tracking(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(FrisTheme.cyan.opacity(0.12))
                    .clipShape(Capsule())

                Text(day.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FrisTheme.textPrimary)

                Spacer()

                Text("\(day.exercises.count) exercises")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(FrisTheme.textSecondary)
            }

            ForEach(day.exercises) { exercise in
                HStack(spacing: 10) {
                    Image(systemName: exercise.primaryMuscle.icon)
                        .font(.system(size: 11))
                        .foregroundStyle(FrisTheme.cyan.opacity(0.7))
                        .frame(width: 24, height: 24)
                        .background(FrisTheme.cyan.opacity(0.08))
                        .clipShape(.rect(cornerRadius: 6))

                    Text(exercise.exerciseName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FrisTheme.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Text("\(exercise.targetSets)×\(exercise.targetRepsMin)-\(exercise.targetRepsMax)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(FrisTheme.textSecondary)
                }
            }
        }
        .padding(14)
        .background(FrisTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
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

    private var completeButton: some View {
        Button {
            onComplete()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title3)
                Text("Start Program")
                    .font(.headline.weight(.bold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(FrisTheme.cyan)
            .clipShape(.rect(cornerRadius: 14))
        }
        .padding(.top, 4)
    }
}
