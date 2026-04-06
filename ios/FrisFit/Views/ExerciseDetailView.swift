import SwiftUI

struct ExerciseDetailView: View {
    let exercise: Exercise
    let viewModel: ExerciseLibraryViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                contentSection
            }
        }
        .background(PepTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: exercise.primaryMuscle.icon)
                .font(.system(size: 44))
                .foregroundStyle(PepTheme.teal)
                .frame(width: 88, height: 88)
                .background(PepTheme.teal.opacity(0.12))
                .clipShape(Circle())

            Text(exercise.name)
                .font(.title2.weight(.bold))
                .foregroundStyle(PepTheme.textPrimary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                DifficultyBadge(difficulty: exercise.difficulty)

                Label(exercise.exerciseType.rawValue, systemImage: exercise.exerciseType == .compound ? "arrow.triangle.branch" : "scope")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(PepTheme.elevated)
                    .clipShape(Capsule())

                Label(exercise.trackingType.label, systemImage: "chart.bar.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(PepTheme.elevated)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
    }

    private var contentSection: some View {
        VStack(spacing: 16) {
            musclesCard
            equipmentCard
            instructionsCard
            commonMistakesCard
            proTipsCard
            alternativesSection
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }

    private var musclesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HeadlineText(text: "Target Muscles")

                HStack(spacing: 12) {
                    MuscleTag(muscle: exercise.primaryMuscle, isPrimary: true)
                    ForEach(exercise.secondaryMuscles) { muscle in
                        MuscleTag(muscle: muscle, isPrimary: false)
                    }
                }
            }
        }
    }

    private var equipmentCard: some View {
        GlassCard {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    SubheadText(text: "Equipment")
                    HStack(spacing: 8) {
                        Image(systemName: exercise.equipment.icon)
                            .foregroundStyle(PepTheme.teal)
                        Text(exercise.equipment.rawValue)
                            .font(.body.weight(.medium))
                            .foregroundStyle(PepTheme.textPrimary)
                    }
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    SubheadText(text: "Movement")
                    Text(exercise.movementPattern.rawValue)
                        .font(.body.weight(.medium))
                        .foregroundStyle(PepTheme.textPrimary)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    SubheadText(text: "Rest")
                    Text("\(exercise.defaultRestSeconds)s")
                        .font(.body.weight(.medium))
                        .foregroundStyle(PepTheme.teal)
                }
            }
        }
    }

    private var instructionsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HeadlineText(text: "Instructions")

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(PepTheme.invertedText)
                                .frame(width: 24, height: 24)
                                .background(PepTheme.teal)
                                .clipShape(Circle())

                            Text(step)
                                .font(.subheadline)
                                .foregroundStyle(PepTheme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private var commonMistakesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    HeadlineText(text: "Common Mistakes")
                }

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(exercise.commonMistakes, id: \.self) { mistake in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.red.opacity(0.7))
                                .padding(.top, 1)
                            Text(mistake)
                                .font(.subheadline)
                                .foregroundStyle(PepTheme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private var proTipsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(PepTheme.violet)
                HeadlineText(text: "Finn's Pro Tips", color: PepTheme.violet)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(exercise.proTips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(PepTheme.violet.opacity(0.8))
                            .padding(.top, 2)
                        Text(tip)
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .background(
            PepTheme.violet.opacity(0.08)
                .overlay(PepTheme.cardSurface.opacity(0.6))
        )
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [PepTheme.violet.opacity(0.2), PepTheme.violet.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }

    private var alternativesSection: some View {
        let alternatives = viewModel.alternatives(for: exercise)
        let similar = viewModel.similarExercises(for: exercise)
        let displayExercises = alternatives.isEmpty ? similar : alternatives
        let sectionTitle = alternatives.isEmpty ? "Similar Exercises" : "Alternatives"

        return Group {
            if !displayExercises.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HeadlineText(text: sectionTitle)
                        .padding(.top, 8)

                    ForEach(displayExercises) { alt in
                        NavigationLink(value: alt) {
                            AlternativeRow(exercise: alt)
                        }
                    }
                }
            }
        }
    }
}

private struct MuscleTag: View {
    let muscle: MuscleGroup
    let isPrimary: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: muscle.icon)
                .font(.system(size: 12))
            Text(muscle.rawValue)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(isPrimary ? PepTheme.teal : PepTheme.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            isPrimary
                ? PepTheme.teal.opacity(0.15)
                : PepTheme.elevated
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(
                    isPrimary ? PepTheme.teal.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
    }
}

private struct AlternativeRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: exercise.primaryMuscle.icon)
                .font(.system(size: 14))
                .foregroundStyle(PepTheme.teal)
                .frame(width: 36, height: 36)
                .background(PepTheme.teal.opacity(0.1))
                .clipShape(.rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(exercise.equipment.rawValue)
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            DifficultyBadge(difficulty: exercise.difficulty)

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
        }
        .padding(12)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(PepTheme.glassBorderTop.opacity(0.3), lineWidth: 0.5)
        )
    }
}
