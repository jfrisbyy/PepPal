import SwiftUI

struct WorkoutAnalyticsView: View {
    let viewModel: ProfileViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                volumeTrendSection
                muscleHeatMapSection
                sportAnalyticsSection
                personalRecordsSection
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .appBackground()
        .navigationTitle("Workout Analytics")
        .navigationBarTitleDisplayMode(.large)
        
    }

    private var volumeTrendSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.xyaxis.line")
                    .foregroundStyle(PepTheme.teal)
                Text("Weekly Volume")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
            }

            VolumeChart(volumes: viewModel.weeklyVolumes, maxVolume: viewModel.maxVolume)
                .frame(height: 200)
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

    private var muscleHeatMapSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "figure.stand")
                    .foregroundStyle(PepTheme.teal)
                Text("Muscle Heat Map")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
            }

            Text("Training intensity over the past 7 days")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)

            MuscleHeatMap(data: viewModel.muscleHeatData)
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

    private var sportAnalyticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sportscourt.fill")
                    .foregroundStyle(.orange)
                Text("Sport Sessions")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
            }

            if viewModel.sportAnalytics.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "figure.run")
                            .font(.title)
                            .foregroundStyle(PepTheme.textSecondary)
                        Text("No sport sessions yet")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                sportSummaryBar

                ForEach(viewModel.sportAnalytics, id: \.sport) { data in
                    sportAnalyticsRow(data)
                    if data.sport != viewModel.sportAnalytics.last?.sport {
                        Divider().overlay(PepTheme.glassBorderTop)
                    }
                }
            }
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

    private var sportSummaryBar: some View {
        HStack(spacing: 0) {
            SportSummaryStat(
                value: "\(viewModel.sportSessions.count)",
                label: "Sessions",
                color: .orange
            )
            SportSummaryStat(
                value: "\(viewModel.sportSessions.reduce(0) { $0 + $1.durationMinutes })m",
                label: "Total Time",
                color: PepTheme.teal
            )
            SportSummaryStat(
                value: String(format: "%.1f", viewModel.sportSessions.isEmpty ? 0 : Double(viewModel.sportSessions.reduce(0) { $0 + $1.intensity }) / Double(viewModel.sportSessions.count)),
                label: "Avg Intensity",
                color: .red
            )
        }
        .padding(.vertical, 12)
        .background(PepTheme.elevated)
        .clipShape(.rect(cornerRadius: 10))
    }

    private func sportAnalyticsRow(_ data: SportAnalyticsData) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(data.sport.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: data.sport.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(data.sport.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(data.sport.rawValue)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                HStack(spacing: 8) {
                    Text("\(data.sessionCount) sessions")
                    Text("·")
                    Text("\(data.totalMinutes)m total")
                }
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f", data.averageIntensity))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(data.sport.color)
                Text("avg int.")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var personalRecordsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(PepTheme.amber)
                Text("Personal Records")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
            }

            ForEach(viewModel.personalRecords) { record in
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(PepTheme.amber.opacity(0.2))
                        .frame(width: 4, height: 40)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(record.exerciseName)
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text(record.dateAchieved.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }

                    Spacer()

                    Text("\(Int(record.bestWeight)) lbs")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.amber)
                }
                .padding(.vertical, 4)

                if record.id != viewModel.personalRecords.last?.id {
                    Divider().overlay(PepTheme.glassBorderTop)
                }
            }
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
}

private struct VolumeChart: View {
    let volumes: [WeeklyVolume]
    let maxVolume: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let barCount = CGFloat(volumes.count)
            let spacing: CGFloat = 8
            let barWidth = (w - spacing * (barCount - 1)) / barCount

            ZStack(alignment: .bottom) {
                ForEach(0..<4, id: \.self) { i in
                    let y = h * CGFloat(i) / 3
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: w, y: y))
                    }
                    .stroke(PepTheme.glassBorderTop, lineWidth: 0.5)
                }

                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(Array(volumes.enumerated()), id: \.element.id) { index, vol in
                        let fraction = vol.volume / maxVolume
                        let barH = max(h * fraction * 0.85, 4)

                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [PepTheme.teal, PepTheme.teal.opacity(0.3)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: barWidth, height: barH)

                            Text(vol.weekLabel)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                }
            }
        }
    }
}

private struct SportSummaryStat: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MuscleHeatMap: View {
    let data: [MuscleHeatData]

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(data) { item in
                HStack(spacing: 8) {
                    Circle()
                        .fill(PepTheme.teal.opacity(item.intensity))
                        .frame(width: 28, height: 28)
                        .overlay {
                            Image(systemName: item.muscle.icon)
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.9))
                        }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.muscle.rawValue)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("\(Int(item.intensity * 100))%")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(PepTheme.teal.opacity(max(item.intensity, 0.4)))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
