import SwiftUI
import MapKit

struct LiveRunView: View {
    @Bindable var runVM: RunningViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showStopConfirm: Bool = false
    @State private var completedRun: CompletedRun? = nil
    @State private var showSummary: Bool = false
    @State private var countdownActive: Bool = true
    @State private var countdownValue: Int = 3
    @State private var mapCameraPosition: MapCameraPosition = .automatic

    private let accentColor = Color(red: 0.0, green: 0.9, blue: 1.0)

    var body: some View {
        ZStack {
            PepTheme.background.ignoresSafeArea()

            if countdownActive {
                countdownOverlay
            } else {
                runContent
            }
        }
        .onAppear {
            startCountdown()
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showSummary) {
            if let run = completedRun {
                RunSummarySheet(run: run, onDismiss: { dismiss() })
            }
        }
        .confirmationDialog("End Run?", isPresented: $showStopConfirm) {
            Button("End Run", role: .destructive) {
                let run = runVM.stopRun()
                completedRun = run
                showSummary = true
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Countdown

    private var countdownOverlay: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("\(countdownValue)")
                .font(.system(size: 120, weight: .heavy, design: .rounded))
                .foregroundStyle(accentColor)
                .contentTransition(.numericText())
            Text("Get Ready")
                .font(.title3.weight(.semibold))
                .foregroundStyle(PepTheme.textSecondary)
            Spacer()
        }
    }

    private func startCountdown() {
        Task {
            for i in stride(from: 3, through: 1, by: -1) {
                withAnimation(.spring(response: 0.3)) {
                    countdownValue = i
                }
                try? await Task.sleep(for: .seconds(1))
            }
            withAnimation {
                countdownActive = false
            }
            runVM.startRun()
        }
    }

    // MARK: - Run Content

    private var runContent: some View {
        VStack(spacing: 0) {
            mapSection
                .frame(height: 220)

            heartRateZoneBar

            ScrollView {
                VStack(spacing: 16) {
                    primaryMetrics
                    secondaryMetrics
                    liveSplitsSection
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }

            Spacer(minLength: 0)
        }
        .safeAreaInset(edge: .bottom) {
            controlBar
        }
    }

    // MARK: - Map

    private var mapSection: some View {
        ZStack(alignment: .topTrailing) {
            Map(position: $mapCameraPosition) {
                ForEach(paceSegments.indices, id: \.self) { i in
                    let seg = paceSegments[i]
                    MapPolyline(coordinates: seg.coords)
                        .stroke(seg.color, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                }
                ForEach(mileMarkers) { marker in
                    Annotation("\(marker.mile)", coordinate: marker.coordinate) {
                        Text("\(marker.mile)")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(.black)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.white))
                            .overlay(Circle().strokeBorder(accentColor, lineWidth: 2))
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))

            VStack(alignment: .trailing, spacing: 6) {
                if runVM.isTreadmillMode {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.run.treadmill")
                            .font(.system(size: 12))
                        Text("Treadmill Mode")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(PepTheme.violet.opacity(0.9))
                    .clipShape(Capsule())
                }

                if !runVM.isTreadmillMode {
                    GPSSignalBadge(signal: runVM.gpsSignal)
                }
            }
            .padding(12)

            if runVM.isAutoPaused {
                autoPauseBanner
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .allowsHitTesting(false)
            }
        }
    }

    private var autoPauseBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 14))
            Text("Auto-paused")
                .font(.system(size: 12, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.95))
        .clipShape(Capsule())
        .frame(maxWidth: .infinity)
    }

    private struct MileMarker: Identifiable {
        let id = UUID()
        let mile: Int
        let coordinate: CLLocationCoordinate2D
    }

    private struct ColoredSegment {
        let coords: [CLLocationCoordinate2D]
        let color: Color
    }

    private var paceSegments: [ColoredSegment] {
        let pts = runVM.routePoints
        guard pts.count >= 2 else { return [] }
        let validPaces = pts.map(\.pace).filter { $0 > 0 && $0 < 20 }
        let minP = validPaces.min() ?? 6
        let maxP = validPaces.max() ?? 12
        var out: [ColoredSegment] = []
        for i in 0..<(pts.count - 1) {
            let a = pts[i]
            let b = pts[i + 1]
            let color = paceColor(a.pace, minPace: minP, maxPace: maxP)
            out.append(ColoredSegment(
                coords: [
                    CLLocationCoordinate2D(latitude: a.latitude, longitude: a.longitude),
                    CLLocationCoordinate2D(latitude: b.latitude, longitude: b.longitude)
                ],
                color: color
            ))
        }
        return out
    }

    private func paceColor(_ pace: Double, minPace: Double, maxPace: Double) -> Color {
        guard pace > 0, maxPace > minPace else { return accentColor }
        let t = max(0, min(1, (pace - minPace) / (maxPace - minPace)))
        if t < 0.5 {
            let k = t / 0.5
            return Color(red: k, green: 0.85, blue: 0.25 * (1 - k))
        } else {
            let k = (t - 0.5) / 0.5
            return Color(red: 1.0, green: 0.85 * (1 - k), blue: 0)
        }
    }

    private var mileMarkers: [MileMarker] {
        let splits = runVM.currentSplits
        guard !splits.isEmpty else { return [] }
        let pts = runVM.routePoints
        guard pts.count >= 2 else { return [] }
        var markers: [MileMarker] = []
        var cumDistance: Double = 0
        var lastMile: Int = 0
        for i in 1..<pts.count {
            let a = CLLocation(latitude: pts[i-1].latitude, longitude: pts[i-1].longitude)
            let b = CLLocation(latitude: pts[i].latitude, longitude: pts[i].longitude)
            cumDistance += a.distance(from: b) / 1609.344
            let mile = Int(cumDistance)
            if mile > lastMile && mile <= splits.count {
                markers.append(MileMarker(mile: mile, coordinate: CLLocationCoordinate2D(latitude: pts[i].latitude, longitude: pts[i].longitude)))
                lastMile = mile
            }
        }
        return markers
    }

    // MARK: - HR Zone Bar

    private var heartRateZoneBar: some View {
        HStack(spacing: 0) {
            ForEach(HeartRateZone.allCases) { zone in
                Rectangle()
                    .fill(zone == runVM.currentHeartRateZone ? zone.color : zone.color.opacity(0.2))
                    .frame(height: 4)
            }
        }
        .overlay(alignment: .center) {
            if runVM.currentHeartRate > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(runVM.currentHeartRateZone.color)
                    Text("\(runVM.currentHeartRate) bpm")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Z\(runVM.currentHeartRateZone.rawValue)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(runVM.currentHeartRateZone.color)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(runVM.currentHeartRateZone.color.opacity(0.15))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .offset(y: -16)
            }
        }
    }

    // MARK: - Primary Metrics

    private var primaryMetrics: some View {
        HStack(spacing: 0) {
            metricBlock(
                value: runVM.currentDistanceFormatted,
                unit: runVM.settings.distanceUnit.abbreviation,
                label: "Distance"
            )

            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(width: 0.5, height: 50)

            metricBlock(
                value: runVM.currentPaceFormatted,
                unit: "/\(runVM.settings.distanceUnit.abbreviation)",
                label: "Pace"
            )

            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(width: 0.5, height: 50)

            metricBlock(
                value: runVM.elapsedFormatted,
                unit: "",
                label: "Time"
            )
        }
        .padding(.vertical, 16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [accentColor.opacity(0.12), PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    private func metricBlock(value: String, unit: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Secondary Metrics

    private var secondaryMetrics: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            miniMetric(icon: "heart.fill", value: runVM.currentHeartRate > 0 ? "\(runVM.currentHeartRate)" : "--", label: "BPM", color: .red)
            miniMetric(icon: "shoeprints.fill", value: runVM.currentCadence > 0 ? "\(runVM.currentCadence)" : "--", label: "Cadence", color: .green)
            miniMetric(icon: "flame.fill", value: runVM.currentCalories > 0 ? "\(runVM.currentCalories)" : "--", label: "Cal", color: .orange)
            miniMetric(icon: "mountain.2.fill", value: String(format: "%.0f", runVM.currentElevation), label: "Elev ft", color: accentColor)
        }
    }

    private func miniMetric(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(PepTheme.textPrimary)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    // MARK: - Live Splits

    private var liveSplitsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            EditorialSectionHeading(
                kicker: "LIVE",
                title: "Splits",
                accent: accentColor,
                trailing: AnyView(
                    Image(systemName: "list.number")
                        .font(.system(size: 12))
                        .foregroundStyle(accentColor.opacity(0.7))
                )
            )

            if runVM.currentSplits.isEmpty {
                HStack {
                    Spacer()
                    Text("First split at 1 \(runVM.settings.distanceUnit.splitLabel)...")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                }
                .padding(.vertical, 12)
            } else {
                ForEach(runVM.currentSplits) { split in
                    HStack(spacing: 12) {
                        Text("\(split.splitNumber)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(accentColor)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(split.paceFormatted + " /\(runVM.settings.distanceUnit.abbreviation)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                            HStack(spacing: 8) {
                                Label("\(split.avgHeartRate) bpm", systemImage: "heart.fill")
                                Label(String(format: "%+.0f ft", split.elevationChange), systemImage: "arrow.up.right")
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                        }

                        Spacer()

                        splitPaceIndicator(split)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func splitPaceIndicator(_ split: RunSplit) -> some View {
        let avgPace = runVM.currentSplits.map(\.pace).reduce(0, +) / Double(runVM.currentSplits.count)
        let diff = split.pace - avgPace
        HStack(spacing: 3) {
            Image(systemName: diff < -0.1 ? "arrow.down" : diff > 0.1 ? "arrow.up" : "minus")
                .font(.system(size: 9))
            Text(String(format: "%+.1f", diff))
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .foregroundStyle(diff < -0.1 ? .green : diff > 0.1 ? .red : PepTheme.textSecondary)
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: 24) {
            if runVM.isPaused {
                Button {
                    runVM.resumeRun()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(accentColor)
                        .clipShape(Circle())
                }

                Button {
                    showStopConfirm = true
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.red.opacity(0.9))
                        .clipShape(Circle())
                }
            } else {
                Button {
                    runVM.pauseRun()
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(PepTheme.elevated)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(accentColor.opacity(0.3), lineWidth: 2))
                }
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Run Summary Sheet

struct RunSummarySheet: View {
    let run: CompletedRun
    let onDismiss: () -> Void

    private let accentColor = Color(red: 0.0, green: 0.9, blue: 1.0)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    summaryHeader
                    mainStats
                    splitsSummary
                    heartRateZoneSummary
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .appBackground()
            .navigationTitle("Run Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDismiss() }
                        .foregroundStyle(accentColor)
                }
            }
        }
    }

    private var summaryHeader: some View {
        PepSportCard(accent: accentColor) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("COMPLETE")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.0)
                        .foregroundStyle(.green)
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.green)
                }

                Text(summaryHeroTitle)
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .kerning(-0.4)
                    .foregroundStyle(PepTheme.textPrimary)

                Text(run.runType.rawValue)
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)

                LinearGradient(
                    colors: [PepTheme.textPrimary.opacity(0.16), PepTheme.textPrimary.opacity(0)],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 0.5)

                HStack(spacing: 0) {
                    summaryStat(value: String(format: "%.2f", run.distanceMiles), label: "MILES")
                    summaryDivider
                    summaryStat(value: run.durationFormatted, label: "DURATION")
                    summaryDivider
                    summaryStat(value: run.averagePaceFormatted, label: "AVG /MI")
                }
            }
        }
    }

    private var summaryHeroTitle: String {
        if run.distanceMiles >= 13 { return "A long one in the books." }
        if run.runType == .intervalSession { return "Reps banked." }
        if run.averagePace > 0 && run.averagePace < 7 { return "Sharp and fast." }
        return "Another mile in the bank."
    }

    private var summaryDivider: some View {
        Rectangle()
            .fill(PepTheme.shimmerHighlight)
            .frame(width: 0.5, height: 28)
    }

    private func summaryStat(value: String, label: String) -> some View {
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

    private var mainStats: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            summaryCell(value: String(format: "%.2f", run.distanceMiles), label: "Miles", color: accentColor)
            summaryCell(value: run.durationFormatted, label: "Duration", color: .green)
            summaryCell(value: run.averagePaceFormatted, label: "Avg Pace", color: .orange)
            summaryCell(value: "\(run.averageHeartRate)", label: "Avg HR", color: .red)
            summaryCell(value: "\(run.cadence)", label: "Cadence", color: PepTheme.violet)
            summaryCell(value: "\(run.caloriesBurned)", label: "Calories", color: PepTheme.amber)
        }
    }

    private func summaryCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var splitsSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(
                kicker: "PER MILE",
                title: "Splits",
                accent: accentColor
            )
            ForEach(run.splits) { split in
                HStack {
                    Text("Mile \(split.splitNumber)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                    Text(split.paceFormatted + " /mi")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(accentColor)
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
    }

    private var heartRateZoneSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(
                kicker: "EFFORT",
                title: "Heart Rate Zones",
                accent: .red
            )
            ForEach(run.heartRateZones, id: \.zone.id) { dist in
                HStack(spacing: 10) {
                    Text("Z\(dist.zone.rawValue)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(dist.zone.color)
                        .frame(width: 24)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(PepTheme.elevated)
                                .frame(height: 8)
                            Capsule()
                                .fill(dist.zone.color)
                                .frame(width: geo.size.width * dist.percentage, height: 8)
                        }
                    }
                    .frame(height: 8)

                    Text("\(Int(dist.percentage * 100))%")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 32, alignment: .trailing)
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
    }
}
