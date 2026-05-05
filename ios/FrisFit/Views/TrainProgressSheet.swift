import SwiftUI

struct TrainProgressSheet: View {
    @Bindable var viewModel: TrainViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    personalRecordsSection
                    weeklyVolumeSection
                    recoverySection
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }
            .appBackground()
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PepTheme.teal)
                }
            }
        }
    }

    private var personalRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(PepTheme.amber)
                HeadlineText(text: "Personal Records")
                Spacer()
            }

            if viewModel.personalRecords.isEmpty {
                Text("No records yet — complete a workout to set your first PR.")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            } else {
                ForEach(viewModel.personalRecords) { pr in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(pr.isNew ? PepTheme.amber : PepTheme.glassBorderTop)
                            .frame(width: 3, height: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pr.exerciseName)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(PepTheme.textPrimary)
                                .lineLimit(1)
                            Text(pr.dateAchieved.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.system(size: 10))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        Spacer()
                        Text("\(Int(pr.weight)) lbs × \(pr.reps)")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(pr.isNew ? PepTheme.amber : PepTheme.textPrimary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private var weeklyVolumeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(PepTheme.teal)
                HeadlineText(text: "Weekly Volume")
                Spacer()
            }

            ForEach(viewModel.weeklyMuscleVolumes) { vol in
                HStack(spacing: 10) {
                    Image(systemName: vol.muscle.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(PepTheme.teal.opacity(0.7))
                        .frame(width: 24)

                    Text(vol.muscle.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PepTheme.textPrimary)
                        .frame(width: 70, alignment: .leading)

                    GeometryReader { geo in
                        let fraction = vol.targetSets > 0 ? min(CGFloat(vol.setsCompleted) / CGFloat(vol.targetSets), 1.0) : 0
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(PepTheme.elevated)
                                .frame(height: 10)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    fraction >= 1.0
                                        ? AnyShapeStyle(.green.opacity(0.8))
                                        : fraction >= 0.6
                                            ? AnyShapeStyle(PepTheme.teal)
                                            : AnyShapeStyle(PepTheme.amber)
                                )
                                .frame(width: max(geo.size.width * fraction, 4), height: 10)
                        }
                    }
                    .frame(height: 10)

                    Text("\(vol.setsCompleted)/\(vol.targetSets)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 36, alignment: .trailing)
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private var recoverySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.text.clipboard")
                    .foregroundStyle(.green)
                HeadlineText(text: "Recovery Status")
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(viewModel.muscleRecoveryItems) { item in
                    recoveryCell(item)
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private func recoveryCell(_ item: MuscleRecoveryItem) -> some View {
        let color: Color = switch item.status {
        case .recovered: .green
        case .recovering: .orange
        case .fatigued: .red
        }

        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: item.status.icon)
                    .font(.system(size: 13))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.muscle.rawValue)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)
                Text(item.status.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(color)
            }
            Spacer()
        }
        .padding(10)
        .background(PepTheme.elevated.opacity(0.5))
        .clipShape(.rect(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(color.opacity(0.15), lineWidth: 0.5)
        )
    }
}
