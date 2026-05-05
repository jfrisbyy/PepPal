import SwiftUI
import AVKit

struct ExerciseDetailView: View {
    let exercise: Exercise
    let viewModel: ExerciseLibraryViewModel
    @State private var selectedSubEquipment: Equipment? = nil
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                contentSection
            }
        }
        .appBackground()
        .navigationBarTitleDisplayMode(.inline)
        
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("EXERCISE REFERENCE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.0)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.85))

            Text(exercise.name)
                .font(.system(size: 34, weight: .semibold, design: .serif))
                .kerning(-0.4)
                .foregroundStyle(PepTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            metaStrip
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 18)
        .padding(.bottom, 18)
        .padding(.horizontal, 18)
    }

    private var metaStrip: some View {
        HStack(spacing: 0) {
            metaItem(label: "Level", value: exercise.difficulty.rawValue)
            metaDivider
            metaItem(label: "Type", value: exercise.exerciseType.rawValue)
            metaDivider
            metaItem(label: "Tracking", value: exercise.trackingType.label)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(PepTheme.textSecondary.opacity(0.2))
                .frame(height: 0.5)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PepTheme.textSecondary.opacity(0.2))
                .frame(height: 0.5)
        }
    }

    private func metaItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.75))
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metaDivider: some View {
        Rectangle()
            .fill(PepTheme.textSecondary.opacity(0.2))
            .frame(width: 0.5, height: 28)
    }

    private var contentSection: some View {
        VStack(spacing: 16) {
            videoPlayerCard
            if !exercise.formCues.isEmpty {
                formCuesCard
            }
            videoDemoCard
            musclesCard
            equipmentCard
            instructionsCard
            commonMistakesCard
            proTipsCard
            substitutionSection
            alternativesSection
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }

    @ViewBuilder
    private var videoPlayerCard: some View {
        if let url = exercise.videoPlaybackURL {
            LoopingVideoPlayer(url: url)
                .aspectRatio(16/9, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(.rect(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(PepTheme.glassBorderTop.opacity(0.5), lineWidth: 0.5)
                )
        }
    }

    private var formCuesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionEyebrow("Form Cues", number: "01", accent: PepTheme.teal)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(exercise.formCues.enumerated()), id: \.offset) { index, cue in
                        HStack(alignment: .firstTextBaseline, spacing: 14) {
                            Text(String(format: "%02d", index + 1))
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                                .frame(width: 22, alignment: .leading)
                            Text(cue)
                                .font(.system(size: 14, design: .serif))
                                .lineSpacing(2)
                                .foregroundStyle(PepTheme.textPrimary.opacity(0.92))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private var videoDemoCard: some View {
        Button {
            openURL(exercise.demoSearchURL)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.red.opacity(0.85), Color.red.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    Image(systemName: "play.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Watch Form Demo")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Video tutorials on YouTube")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PepTheme.teal)
            }
            .padding(14)
            .background(PepTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(PepTheme.glassBorderTop.opacity(0.5), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var substitutionSection: some View {
        let equipment = viewModel.availableSubstitutionEquipment(for: exercise)
        return Group {
            if equipment.count > 1 {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        HeadlineText(text: "Substitute by Equipment")
                    }
                    .padding(.top, 8)

                    Text("Don't have \(exercise.equipment.rawValue.lowercased())? Pick what you have.")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(equipment, id: \.self) { eq in
                                let isSelected = selectedSubEquipment == eq
                                Button {
                                    withAnimation(.spring(duration: 0.25)) {
                                        selectedSubEquipment = isSelected ? nil : eq
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: eq.icon)
                                            .font(.system(size: 12))
                                        Text(eq.rawValue)
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundStyle(isSelected ? PepTheme.invertedText : PepTheme.textPrimary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(isSelected ? AnyShapeStyle(PepTheme.teal) : AnyShapeStyle(PepTheme.elevated))
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .contentMargins(.horizontal, 0)

                    if let eq = selectedSubEquipment {
                        let subs = viewModel.alternatives(for: exercise, equipment: eq)
                        if subs.isEmpty {
                            Text("No matches found")
                                .font(.caption)
                                .foregroundStyle(PepTheme.textSecondary)
                                .padding(.vertical, 8)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(subs) { sub in
                                    NavigationLink(value: sub) {
                                        AlternativeRow(exercise: sub)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var musclesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionEyebrow("Target Muscles", number: "02", accent: PepTheme.teal)

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
            HStack(spacing: 0) {
                detailColumn(label: "Equipment", value: exercise.equipment.rawValue)
                Rectangle()
                    .fill(PepTheme.textSecondary.opacity(0.2))
                    .frame(width: 0.5, height: 32)
                detailColumn(label: "Movement", value: exercise.movementPattern.rawValue)
                Rectangle()
                    .fill(PepTheme.textSecondary.opacity(0.2))
                    .frame(width: 0.5, height: 32)
                detailColumn(label: "Rest", value: "\(exercise.defaultRestSeconds)s")
            }
        }
    }

    private func detailColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.75))
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private var instructionsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionEyebrow("Instructions", number: "03", accent: PepTheme.teal)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .firstTextBaseline, spacing: 14) {
                            Text(String(format: "%02d", index + 1))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                                .frame(width: 22, alignment: .leading)
                            Text(step)
                                .font(.system(size: 15, design: .serif))
                                .lineSpacing(3)
                                .foregroundStyle(PepTheme.textPrimary.opacity(0.92))
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
                SectionEyebrow("Common Mistakes", number: "04", accent: PepTheme.teal)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(exercise.commonMistakes, id: \.self) { mistake in
                        HStack(alignment: .firstTextBaseline, spacing: 14) {
                            Rectangle()
                                .fill(PepTheme.textSecondary.opacity(0.5))
                                .frame(width: 8, height: 1)
                                .offset(y: -4)
                            Text(mistake)
                                .font(.system(size: 14))
                                .lineSpacing(2)
                                .foregroundStyle(PepTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private var proTipsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionEyebrow("Tips", number: "05", accent: PepTheme.teal)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(exercise.proTips, id: \.self) { tip in
                        HStack(alignment: .firstTextBaseline, spacing: 14) {
                            Rectangle()
                                .fill(PepTheme.textSecondary.opacity(0.5))
                                .frame(width: 8, height: 1)
                                .offset(y: -4)
                            Text(tip)
                                .font(.system(size: 14))
                                .lineSpacing(2)
                                .foregroundStyle(PepTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
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
