import SwiftUI
import MapKit

struct RunDetailView: View {
    let run: CompletedRun
    let shoe: RunningShoe?
    @Environment(\.dismiss) private var dismiss

    private let accentColor = Color(red: 0.0, green: 0.9, blue: 1.0)

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                routeMapSection
                primaryStatsGrid
                splitTableSection
                splitChartSection
                elevationSection
                heartRateZoneSection
                additionalMetrics
                if let shoe {
                    shoeUsedSection(shoe)
                }
                if !run.notes.isEmpty {
                    notesSection
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(FrisTheme.background.ignoresSafeArea())
        .navigationTitle(run.runType.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(run.runType.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FrisTheme.textPrimary)
                    Text(run.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.system(size: 10))
                        .foregroundStyle(FrisTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - Route Map

    private var routeMapSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !run.routeCoordinates.isEmpty && !run.isTreadmill {
                Map {
                    MapPolyline(coordinates: run.routeCoordinates.map {
                        CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                    })
                    .stroke(accentColor, lineWidth: 3)

                    if let first = run.routeCoordinates.first {
                        Annotation("Start", coordinate: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude)) {
                            Circle()
                                .fill(.green)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                        }
                    }
                    if let last = run.routeCoordinates.last {
                        Annotation("Finish", coordinate: CLLocationCoordinate2D(latitude: last.latitude, longitude: last.longitude)) {
                            Circle()
                                .fill(.red)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                        }
                    }
                }
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
                .frame(height: 200)
                .clipShape(.rect(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(FrisTheme.glassBorderTop, lineWidth: 0.5)
                )
            } else if run.isTreadmill {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "figure.run.treadmill")
                            .font(.system(size: 32))
                            .foregroundStyle(FrisTheme.violet)
                        Text("Treadmill Run")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(FrisTheme.textPrimary)
                        Text("No route data")
                            .font(.caption)
                            .foregroundStyle(FrisTheme.textSecondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 32)
                .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
                .clipShape(.rect(cornerRadius: 16))
            }
        }
    }

    // MARK: - Primary Stats

    private var primaryStatsGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                bigStatCell(value: String(format: "%.2f", run.distanceMiles), label: "Miles", color: accentColor)
                bigStatCell(value: run.durationFormatted, label: "Duration", color: .green)
            }

            HStack(spacing: 10) {
                bigStatCell(value: run.averagePaceFormatted + "/mi", label: "Avg Pace", color: .orange)
                bigStatCell(value: run.bestPaceFormatted + "/mi", label: "Best Pace", color: .green)
            }

            HStack(spacing: 10) {
                bigStatCell(value: "\(run.averageHeartRate) bpm", label: "Avg Heart Rate", color: .red)
                bigStatCell(value: "\(run.caloriesBurned) kcal", label: "Calories", color: FrisTheme.amber)
            }
        }
    }

    private func bigStatCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(FrisTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(color.opacity(0.1), lineWidth: 0.5)
        )
    }

    // MARK: - Split Table

    private var splitTableSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.number")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Mile Splits")
                Spacer()
            }

            if run.splits.isEmpty {
                emptyPlaceholder("No split data")
            } else {
                HStack {
                    Text("Split")
                        .frame(width: 36, alignment: .leading)
                    Text("Pace")
                        .frame(maxWidth: .infinity)
                    Text("HR")
                        .frame(width: 40)
                    Text("Elev")
                        .frame(width: 50, alignment: .trailing)
                }
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(FrisTheme.textSecondary)
                .padding(.horizontal, 4)

                ForEach(run.splits) { split in
                    HStack {
                        Text("\(split.splitNumber)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(accentColor)
                            .frame(width: 36, alignment: .leading)

                        Text(split.paceFormatted + " /mi")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(FrisTheme.textPrimary)
                            .frame(maxWidth: .infinity)

                        Text("\(split.avgHeartRate)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.red.opacity(0.8))
                            .frame(width: 40)

                        Text(String(format: "%+.0f ft", split.elevationChange))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(split.elevationChange >= 0 ? .green : .orange)
                            .frame(width: 50, alignment: .trailing)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 4)

                    if split.id != run.splits.last?.id {
                        Divider().overlay(FrisTheme.separatorColor)
                    }
                }
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    // MARK: - Split Bar Chart

    private var splitChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Split Visualization")
                Spacer()
            }

            if run.splits.isEmpty {
                emptyPlaceholder("No split data")
            } else {
                let avgPace = run.splits.map(\.pace).reduce(0, +) / Double(run.splits.count)
                let maxPace = run.splits.map(\.pace).max() ?? 1
                let minPace = run.splits.map(\.pace).min() ?? 0
                let range = max(maxPace - minPace, 0.5)

                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(run.splits) { split in
                        VStack(spacing: 4) {
                            Text(split.paceFormatted)
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundStyle(split.pace <= avgPace ? .green : .orange)

                            let normalizedHeight = CGFloat(1.0 - (split.pace - minPace) / range)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    split.pace <= avgPace ?
                                    LinearGradient(colors: [.green, .green.opacity(0.5)], startPoint: .top, endPoint: .bottom) :
                                    LinearGradient(colors: [.orange, .orange.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                                )
                                .frame(height: max(normalizedHeight * 60 + 20, 12))

                            Text("\(split.splitNumber)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(FrisTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 100)

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle().fill(.green).frame(width: 6, height: 6)
                        Text("Faster than avg")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(FrisTheme.textSecondary)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(.orange).frame(width: 6, height: 6)
                        Text("Slower than avg")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(FrisTheme.textSecondary)
                    }
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    // MARK: - Elevation Profile

    private var elevationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "mountain.2.fill")
                    .foregroundStyle(.green)
                HeadlineText(text: "Elevation")
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("↑ \(String(format: "%.0f", run.totalElevationGain)) ft")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.green)
                    Text("↓ \(String(format: "%.0f", run.totalElevationLoss)) ft")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.orange)
                }
            }

            if run.routeCoordinates.count >= 2 {
                let elevations = run.routeCoordinates.map(\.elevation)
                let minElev = (elevations.min() ?? 0) - 5
                let maxElev = (elevations.max() ?? 100) + 5
                let elevRange = max(maxElev - minElev, 1)

                GeometryReader { geo in
                    let width = geo.size.width
                    let height: CGFloat = 60
                    let stepX = width / CGFloat(max(elevations.count - 1, 1))

                    ZStack {
                        Path { path in
                            for (i, elev) in elevations.enumerated() {
                                let x = CGFloat(i) * stepX
                                let y = height - CGFloat((elev - minElev) / elevRange) * height
                                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                            if let lastIdx = elevations.indices.last {
                                path.addLine(to: CGPoint(x: CGFloat(lastIdx) * stepX, y: height))
                                path.addLine(to: CGPoint(x: 0, y: height))
                                path.closeSubpath()
                            }
                        }
                        .fill(
                            LinearGradient(colors: [.green.opacity(0.25), .green.opacity(0.02)], startPoint: .top, endPoint: .bottom)
                        )

                        Path { path in
                            for (i, elev) in elevations.enumerated() {
                                let x = CGFloat(i) * stepX
                                let y = height - CGFloat((elev - minElev) / elevRange) * height
                                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                        }
                        .stroke(.green.opacity(0.7), lineWidth: 1.5)
                    }
                    .frame(height: height)
                }
                .frame(height: 60)
            } else {
                emptyPlaceholder("No elevation data")
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    // MARK: - Heart Rate Zones

    private var heartRateZoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                HeadlineText(text: "Heart Rate Zones")
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Avg \(run.averageHeartRate) bpm")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.red.opacity(0.8))
                    Text("Max \(run.maxHeartRate) bpm")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(FrisTheme.textSecondary)
                }
            }

            if run.heartRateZones.isEmpty {
                emptyPlaceholder("No heart rate data")
            } else {
                ForEach(run.heartRateZones, id: \.zone.id) { dist in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Z\(dist.zone.rawValue)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(dist.zone.color)
                            Text(dist.zone.name)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(FrisTheme.textSecondary)
                        }
                        .frame(width: 56, alignment: .leading)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(FrisTheme.elevated)
                                    .frame(height: 10)
                                Capsule()
                                    .fill(dist.zone.color)
                                    .frame(width: geo.size.width * dist.percentage, height: 10)
                            }
                        }
                        .frame(height: 10)

                        VStack(alignment: .trailing, spacing: 1) {
                            Text("\(Int(dist.percentage * 100))%")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(FrisTheme.textPrimary)
                            Text(formatZoneDuration(dist.timeInZone))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(FrisTheme.textSecondary)
                        }
                        .frame(width: 44, alignment: .trailing)
                    }
                }
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    // MARK: - Additional Metrics

    private var additionalMetrics: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.xyaxis.line")
                    .foregroundStyle(FrisTheme.violet)
                HeadlineText(text: "Advanced Metrics")
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                metricCell(label: "Cadence", value: "\(run.cadence) spm", icon: "shoeprints.fill", color: .green)
                metricCell(label: "Stride", value: String(format: "%.1f ft", run.strideLength), icon: "ruler", color: accentColor)
                metricCell(label: "Max HR", value: "\(run.maxHeartRate) bpm", icon: "heart.fill", color: .red)
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private func metricCell(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(FrisTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(FrisTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 10))
    }

    // MARK: - Shoe Used

    private func shoeUsedSection(_ shoe: RunningShoe) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(shoe.statusColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "shoe.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(shoe.statusColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("\(shoe.brand) \(shoe.name)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FrisTheme.textPrimary)
                Text(String(format: "%.0f / %.0f mi", shoe.totalMiles, shoe.retirementMiles))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(FrisTheme.textSecondary)
            }

            Spacer()

            Text(String(format: "%.0f mi left", shoe.milesRemaining))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(shoe.statusColor)
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundStyle(FrisTheme.textSecondary)
                HeadlineText(text: "Notes")
            }
            Text(run.notes)
                .font(.subheadline)
                .foregroundStyle(FrisTheme.textSecondary)
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func emptyPlaceholder(_ message: String) -> some View {
        HStack {
            Spacer()
            Text(message)
                .font(.caption)
                .foregroundStyle(FrisTheme.textSecondary)
                .padding(.vertical, 12)
            Spacer()
        }
    }

    private func cardBorder() -> some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(
                LinearGradient(colors: [FrisTheme.glassBorderTop, FrisTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 0.5
            )
    }

    private func formatZoneDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
