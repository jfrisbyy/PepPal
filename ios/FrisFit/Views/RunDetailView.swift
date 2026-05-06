import SwiftUI
import MapKit

struct RunDetailView: View {
    let run: CompletedRun
    let shoe: RunningShoe?
    @Environment(\.dismiss) private var dismiss
    @State private var isReplaying: Bool = false
    @State private var replayProgress: Double = 0
    @State private var replayTask: Task<Void, Never>?
    @State private var scrubbing: Bool = false

    private let accentColor = Color(red: 0.0, green: 0.9, blue: 1.0)

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                editorialHero
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
        .appBackground()
        .navigationTitle(run.runType.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(run.runType.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(run.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.system(size: 10))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - Editorial Hero

    private var editorialHero: some View {
        PepSportCard(accent: accentColor) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(run.runType.rawValue.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.0)
                        .foregroundStyle(run.runType.color)
                    Spacer()
                    Text(run.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }

                Text(heroSummary)
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .kerning(-0.4)
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(heroLine)
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)

                LinearGradient(
                    colors: [PepTheme.textPrimary.opacity(0.16), PepTheme.textPrimary.opacity(0)],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 0.5)

                HStack(spacing: 0) {
                    heroStat(value: String(format: "%.2f", run.distanceMiles), label: "MILES")
                    heroDivider
                    heroStat(value: run.durationFormatted, label: "DURATION")
                    heroDivider
                    heroStat(value: run.averagePaceFormatted, label: "AVG /MI")
                }
            }
        }
    }

    private var heroSummary: String {
        let pace = run.averagePace
        if run.distanceMiles >= 13 { return "A long one in the books." }
        if pace > 0 && pace < 7 { return "Sharp, fast, focused." }
        if run.runType == .recoveryRun { return "Easy effort, full recovery." }
        if run.runType == .intervalSession { return "Hard reps, real work." }
        if run.totalElevationGain >= 200 { return "Climbing legs showed up." }
        return "Another mile in the bank."
    }

    private var heroLine: String {
        var bits: [String] = []
        if run.totalElevationGain > 0 {
            bits.append(String(format: "%.0f ft climbed", run.totalElevationGain))
        }
        if run.averageHeartRate > 0 {
            bits.append("avg \(run.averageHeartRate) bpm")
        }
        if run.caloriesBurned > 0 {
            bits.append("\(run.caloriesBurned) kcal")
        }
        if bits.isEmpty { return "A clean session — keep stacking them." }
        return bits.joined(separator: "  ·  ")
    }

    private var heroDivider: some View {
        Rectangle()
            .fill(PepTheme.shimmerHighlight)
            .frame(width: 0.5, height: 28)
    }

    private func heroStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Route Map

    private var routeMapSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !run.routeCoordinates.isEmpty && !run.isTreadmill {
                let coords = run.routeCoordinates
                let segments = paceSegments(from: coords)
                let replayCount = max(2, Int(Double(coords.count) * replayProgress))
                let currentCoord = coords[min(replayCount - 1, coords.count - 1)]

                Map {
                    ForEach(segments.indices, id: \.self) { i in
                        let seg = segments[i]
                        MapPolyline(coordinates: seg.points.map {
                            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                        })
                        .stroke(seg.color, lineWidth: 4)
                    }

                    if isReplaying || scrubbing {
                        Annotation("Runner", coordinate: CLLocationCoordinate2D(latitude: currentCoord.latitude, longitude: currentCoord.longitude)) {
                            ZStack {
                                Circle()
                                    .fill(accentColor)
                                    .frame(width: 20, height: 20)
                                    .shadow(color: accentColor, radius: 8)
                                Image(systemName: "figure.run")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }

                    if let first = coords.first {
                        Annotation("Start", coordinate: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude)) {
                            Circle()
                                .fill(.green)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                        }
                    }
                    if let last = coords.last {
                        Annotation("Finish", coordinate: CLLocationCoordinate2D(latitude: last.latitude, longitude: last.longitude)) {
                            Circle()
                                .fill(.red)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                        }
                    }
                }
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
                .frame(height: 220)
                .clipShape(.rect(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                )
                .overlay(alignment: .topLeading) {
                    paceLegend
                        .padding(10)
                }
                .overlay(alignment: .bottomTrailing) {
                    Button {
                        toggleReplay()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isReplaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(isReplaying ? "Pause" : "Replay")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.65))
                        .clipShape(Capsule())
                    }
                    .padding(12)
                }

                VStack(spacing: 4) {
                    Slider(value: $replayProgress, in: 0...1, onEditingChanged: { editing in
                        scrubbing = editing
                        if editing { replayTask?.cancel(); isReplaying = false }
                    })
                    .tint(accentColor)
                    HStack {
                        Text(timeLabel(progress: 0))
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(PepTheme.textSecondary)
                        Spacer()
                        Text(timeLabel(progress: replayProgress))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(accentColor)
                        Spacer()
                        Text(timeLabel(progress: 1))
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
                .padding(.horizontal, 4)
            } else if run.isTreadmill {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "figure.run.treadmill")
                            .font(.system(size: 32))
                            .foregroundStyle(PepTheme.violet)
                        Text("Treadmill Run")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("No route data")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 32)
                .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
                .clipShape(.rect(cornerRadius: 16))
            }
        }
        .onDisappear { replayTask?.cancel() }
    }

    private func toggleReplay() {
        if isReplaying {
            replayTask?.cancel()
            isReplaying = false
            return
        }
        isReplaying = true
        if replayProgress >= 0.99 { replayProgress = 0 }
        let totalSteps = 100
        let startStep = Int(replayProgress * Double(totalSteps))
        replayTask = Task { @MainActor in
            for step in startStep...totalSteps {
                if Task.isCancelled { return }
                withAnimation(.linear(duration: 0.08)) {
                    replayProgress = Double(step) / Double(totalSteps)
                }
                try? await Task.sleep(for: .milliseconds(80))
            }
            isReplaying = false
        }
    }

    private struct PaceSegment {
        let points: [RouteCoordinate]
        let color: Color
    }

    private func paceColor(_ pace: Double, minPace: Double, maxPace: Double) -> Color {
        guard pace > 0, maxPace > minPace else { return .gray }
        let t = (pace - minPace) / (maxPace - minPace)
        let clamped = max(0, min(1, t))
        if clamped < 0.5 {
            let k = clamped / 0.5
            return Color(red: k, green: 0.8, blue: 0.2 * (1 - k))
        } else {
            let k = (clamped - 0.5) / 0.5
            return Color(red: 1.0, green: 0.8 * (1 - k), blue: 0)
        }
    }

    private func paceSegments(from coords: [RouteCoordinate]) -> [PaceSegment] {
        guard coords.count >= 2 else { return [] }
        let paces = coords.map(\.pace).filter { $0 > 0 }
        let minP = paces.min() ?? 0
        let maxP = paces.max() ?? 1
        var segments: [PaceSegment] = []
        for i in 0..<(coords.count - 1) {
            let c = paceColor(coords[i].pace, minPace: minP, maxPace: maxP)
            segments.append(PaceSegment(points: [coords[i], coords[i + 1]], color: c))
        }
        return segments
    }

    private var paceLegend: some View {
        HStack(spacing: 4) {
            Text("Fast")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.green)
            LinearGradient(colors: [.green, .yellow, .orange, .red], startPoint: .leading, endPoint: .trailing)
                .frame(width: 60, height: 4)
                .clipShape(Capsule())
            Text("Slow")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.red)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.55))
        .clipShape(Capsule())
    }

    private func timeLabel(progress: Double) -> String {
        let secs = run.durationSeconds * progress
        let m = Int(secs) / 60
        let s = Int(secs) % 60
        return String(format: "%d:%02d", m, s)
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
                bigStatCell(value: "\(run.caloriesBurned) kcal", label: "Calories", color: PepTheme.amber)
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
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
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
                EditorialSectionHeading(
                    kicker: "PER MILE",
                    title: "Mile Splits",
                    accent: accentColor,
                    trailing: AnyView(
                        Image(systemName: "list.number")
                            .font(.system(size: 12))
                            .foregroundStyle(accentColor.opacity(0.7))
                    )
                )
                EmptyView()
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
                .foregroundStyle(PepTheme.textSecondary)
                .padding(.horizontal, 4)

                ForEach(run.splits) { split in
                    HStack {
                        Text("\(split.splitNumber)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(accentColor)
                            .frame(width: 36, alignment: .leading)

                        Text(split.paceFormatted + " /mi")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
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
                        Divider().overlay(PepTheme.separatorColor)
                    }
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    // MARK: - Split Bar Chart

    private var splitChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                EditorialSectionHeading(
                    kicker: "PACE",
                    title: "Split Visualization",
                    accent: accentColor,
                    trailing: AnyView(
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(accentColor.opacity(0.7))
                    )
                )
                EmptyView()
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
                                .foregroundStyle(PepTheme.textSecondary)
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
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(.orange).frame(width: 6, height: 6)
                        Text("Slower than avg")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    // MARK: - Elevation Profile

    private var elevationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                EditorialSectionHeading(
                    kicker: "TERRAIN",
                    title: "Elevation",
                    accent: .green,
                    trailing: AnyView(
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("↑ \(String(format: "%.0f", run.totalElevationGain)) ft")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.green)
                            Text("↓ \(String(format: "%.0f", run.totalElevationLoss)) ft")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.orange)
                        }
                    )
                )
                EmptyView()
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
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    // MARK: - Heart Rate Zones

    private var heartRateZoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                EditorialSectionHeading(
                    kicker: "EFFORT",
                    title: "Heart Rate Zones",
                    accent: .red,
                    trailing: AnyView(
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Avg \(run.averageHeartRate) bpm")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(.red.opacity(0.85))
                            Text("Max \(run.maxHeartRate) bpm")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    )
                )
                EmptyView()
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
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        .frame(width: 56, alignment: .leading)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(PepTheme.elevated)
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
                                .foregroundStyle(PepTheme.textPrimary)
                            Text(formatZoneDuration(dist.timeInZone))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        .frame(width: 44, alignment: .trailing)
                    }
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    // MARK: - Additional Metrics

    private var additionalMetrics: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                EditorialSectionHeading(
                    kicker: "ADVANCED",
                    title: "Form & Metrics",
                    accent: PepTheme.violet,
                    trailing: AnyView(
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 12))
                            .foregroundStyle(PepTheme.violet.opacity(0.7))
                    )
                )
                EmptyView()
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                metricCell(label: "Cadence", value: "\(run.cadence) spm", icon: "shoeprints.fill", color: .green)
                metricCell(label: "Stride", value: String(format: "%.1f ft", run.strideLength), icon: "ruler", color: accentColor)
                metricCell(label: "Max HR", value: "\(run.maxHeartRate) bpm", icon: "heart.fill", color: .red)
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
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
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
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
                    .foregroundStyle(PepTheme.textPrimary)
                Text(String(format: "%.0f / %.0f mi", shoe.totalMiles, shoe.retirementMiles))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            Text(String(format: "%.0f mi left", shoe.milesRemaining))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(shoe.statusColor)
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            EditorialSectionHeading(
                kicker: "FROM THE LOG",
                title: "Notes",
                accent: PepTheme.textSecondary,
                trailing: AnyView(
                    Image(systemName: "note.text")
                        .font(.system(size: 12))
                        .foregroundStyle(PepTheme.textSecondary)
                )
            )
            Text(run.notes)
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func emptyPlaceholder(_ message: String) -> some View {
        HStack {
            Spacer()
            Text(message)
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
                .padding(.vertical, 12)
            Spacer()
        }
    }

    private func cardBorder() -> some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(
                LinearGradient(colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 0.5
            )
    }

    private func formatZoneDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
