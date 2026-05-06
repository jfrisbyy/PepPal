import SwiftUI
import MapKit

struct LiveRideView: View {
    @Bindable var cyclingVM: CyclingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showStopConfirm: Bool = false
    @State private var completedRide: CompletedRide? = nil
    @State private var showSummary: Bool = false
    @State private var countdownActive: Bool = true
    @State private var countdownValue: Int = 3
    @State private var mapCameraPosition: MapCameraPosition = .automatic

    private let accentColor = Color(red: 0.95, green: 0.45, blue: 0.0)

    var body: some View {
        ZStack {
            PepTheme.background.ignoresSafeArea()

            if countdownActive {
                countdownOverlay
            } else {
                rideContent
            }
        }
        .onAppear {
            startCountdown()
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showSummary) {
            if let ride = completedRide {
                RideSummarySheet(ride: ride, onDismiss: { dismiss() })
            }
        }
        .confirmationDialog("End Ride?", isPresented: $showStopConfirm) {
            Button("End Ride", role: .destructive) {
                let ride = cyclingVM.stopRide()
                completedRide = ride
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
            cyclingVM.startRide()
        }
    }

    // MARK: - Ride Content

    private var rideContent: some View {
        VStack(spacing: 0) {
            mapSection
                .frame(height: 200)

            heartRateZoneBar

            ScrollView {
                VStack(spacing: 16) {
                    primaryMetrics
                    secondaryMetrics
                    powerAndCadenceCard
                    liveSegmentsSection
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
                ForEach(speedSegments.indices, id: \.self) { i in
                    let seg = speedSegments[i]
                    MapPolyline(coordinates: seg.coords)
                        .stroke(seg.color, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))

            VStack(alignment: .trailing, spacing: 6) {
                if cyclingVM.isIndoorMode {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.indoor.cycle")
                            .font(.system(size: 12))
                        Text("Indoor Mode")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(PepTheme.violet.opacity(0.9))
                    .clipShape(Capsule())
                }

                if !cyclingVM.isIndoorMode {
                    GPSSignalBadge(signal: cyclingVM.gpsSignal)
                }
            }
            .padding(12)

            if cyclingVM.isAutoPaused {
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
                .padding(12)
                .allowsHitTesting(false)
            }
        }
    }

    private struct ColoredSegment {
        let coords: [CLLocationCoordinate2D]
        let color: Color
    }

    private var speedSegments: [ColoredSegment] {
        let pts = cyclingVM.routePoints
        guard pts.count >= 2 else { return [] }
        let validSpeeds = pts.map(\.speed).filter { $0 > 0 && $0 < 60 }
        let minS = validSpeeds.min() ?? 5
        let maxS = validSpeeds.max() ?? 30
        var out: [ColoredSegment] = []
        for i in 0..<(pts.count - 1) {
            let a = pts[i]
            let b = pts[i + 1]
            let color = speedColor(a.speed, minSpeed: minS, maxSpeed: maxS)
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

    private func speedColor(_ speed: Double, minSpeed: Double, maxSpeed: Double) -> Color {
        guard speed > 0, maxSpeed > minSpeed else { return accentColor }
        let t = max(0, min(1, (speed - minSpeed) / (maxSpeed - minSpeed)))
        if t < 0.5 {
            let k = t / 0.5
            return Color(red: 1.0, green: 0.85 * k, blue: 0)
        } else {
            let k = (t - 0.5) / 0.5
            return Color(red: 1.0 - k, green: 0.85, blue: 0.25 * k)
        }
    }

    // MARK: - HR Zone Bar

    private var heartRateZoneBar: some View {
        HStack(spacing: 0) {
            ForEach(HeartRateZone.allCases) { zone in
                Rectangle()
                    .fill(zone == cyclingVM.currentHeartRateZone ? zone.color : zone.color.opacity(0.2))
                    .frame(height: 4)
            }
        }
        .overlay(alignment: .center) {
            if cyclingVM.currentHeartRate > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(cyclingVM.currentHeartRateZone.color)
                    Text("\(cyclingVM.currentHeartRate) bpm")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Z\(cyclingVM.currentHeartRateZone.rawValue)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(cyclingVM.currentHeartRateZone.color)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(cyclingVM.currentHeartRateZone.color.opacity(0.15))
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
                value: cyclingVM.currentSpeedFormatted,
                unit: cyclingVM.settings.speedUnit.rawValue,
                label: "Speed",
                isPrimary: true
            )

            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(width: 0.5, height: 50)

            metricBlock(
                value: cyclingVM.currentDistanceFormatted,
                unit: cyclingVM.settings.distanceUnit.abbreviation,
                label: "Distance",
                isPrimary: false
            )

            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(width: 0.5, height: 50)

            metricBlock(
                value: cyclingVM.elapsedFormatted,
                unit: "",
                label: "Time",
                isPrimary: false
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

    private func metricBlock(value: String, unit: String, label: String, isPrimary: Bool) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: isPrimary ? 32 : 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(isPrimary ? accentColor : PepTheme.textPrimary)
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
            miniMetric(icon: "heart.fill", value: cyclingVM.currentHeartRate > 0 ? "\(cyclingVM.currentHeartRate)" : "--", label: "BPM", color: .red)
            miniMetric(icon: "mountain.2.fill", value: String(format: "%.0f", cyclingVM.currentElevationGain), label: "Elev ft", color: .green)
            miniMetric(icon: "flame.fill", value: cyclingVM.currentCalories > 0 ? "\(cyclingVM.currentCalories)" : "--", label: "Cal", color: .orange)
            miniMetric(icon: "bolt.fill", value: String(format: "%.1f", cyclingVM.maxSpeedThisRide), label: "Max MPH", color: accentColor)
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

    // MARK: - Power & Cadence

    private var powerAndCadenceCard: some View {
        HStack(spacing: 10) {
            VStack(spacing: 8) {
                Image(systemName: "bolt.heart.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.yellow)
                Text(cyclingVM.currentPower > 0 ? "\(cyclingVM.currentPower)" : "--")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Watts")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.yellow.opacity(0.06))
            .clipShape(.rect(cornerRadius: 12))

            VStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14))
                    .foregroundStyle(.mint)
                Text(cyclingVM.currentCadence > 0 ? "\(cyclingVM.currentCadence)" : "--")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("RPM")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.mint.opacity(0.06))
            .clipShape(.rect(cornerRadius: 12))
        }
    }

    // MARK: - Live Segments

    private var liveSegmentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                EditorialSectionHeading(kicker: "Live", title: "Segments", accent: accentColor)
            }

            if cyclingVM.currentSegments.isEmpty {
                HStack {
                    Spacer()
                    Text("First segment at 1 \(cyclingVM.settings.distanceUnit.splitLabel)...")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                }
                .padding(.vertical, 12)
            } else {
                ForEach(cyclingVM.currentSegments) { seg in
                    HStack(spacing: 12) {
                        Text("\(seg.segmentNumber)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(accentColor)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(seg.avgSpeedFormatted) \(cyclingVM.settings.speedUnit.rawValue)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                            HStack(spacing: 8) {
                                Label("\(seg.avgHeartRate) bpm", systemImage: "heart.fill")
                                Label("\(seg.avgCadence) rpm", systemImage: "arrow.triangle.2.circlepath")
                                Label(String(format: "%+.0f ft", seg.elevationChange), systemImage: "arrow.up.right")
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                        }

                        Spacer()

                        segmentSpeedIndicator(seg)
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
    private func segmentSpeedIndicator(_ seg: RideSegment) -> some View {
        let avgSpeed = cyclingVM.currentSegments.map(\.avgSpeed).reduce(0, +) / Double(cyclingVM.currentSegments.count)
        let diff = seg.avgSpeed - avgSpeed
        HStack(spacing: 3) {
            Image(systemName: diff > 0.5 ? "arrow.up" : diff < -0.5 ? "arrow.down" : "minus")
                .font(.system(size: 9))
            Text(String(format: "%+.1f", diff))
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .foregroundStyle(diff > 0.5 ? .green : diff < -0.5 ? .red : PepTheme.textSecondary)
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: 24) {
            if cyclingVM.isPaused {
                Button {
                    cyclingVM.resumeRide()
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
                    cyclingVM.pauseRide()
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

// MARK: - Ride Summary Sheet

struct RideSummarySheet: View {
    let ride: CompletedRide
    let onDismiss: () -> Void

    private let accentColor = Color(red: 0.95, green: 0.45, blue: 0.0)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    summaryHeader
                    mainStats
                    powerStats
                    segmentsSummary
                    heartRateZoneSummary
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .appBackground()
            .navigationTitle("Ride Complete")
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
                    Text("RIDE COMPLETE")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.0)
                        .foregroundStyle(accentColor.opacity(0.9))
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.green)
                }

                Text(String(format: "%.1f miles, well ridden.", ride.distanceMiles))
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .kerning(-0.4)
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(2)

                Text(summaryBlurb)
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if ride.climbCategory != nil || ride.isIndoor {
                    HStack(spacing: 6) {
                        if let cat = ride.climbCategory {
                            Text(cat.rawValue)
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.2)
                                .foregroundStyle(cat.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(cat.color.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        if ride.isIndoor {
                            Text("INDOOR")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.2)
                                .foregroundStyle(PepTheme.violet)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(PepTheme.violet.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    private var summaryBlurb: String {
        if ride.totalElevationGain >= 2000 {
            return String(format: "%.0f ft of climbing on a %@. Legs earned the rest.", ride.totalElevationGain, ride.rideType.rawValue.lowercased())
        }
        if ride.maxSpeed >= 30 {
            return String(format: "Topped out at %.1f mph. That\u{2019}s a fast one.", ride.maxSpeed)
        }
        if ride.averageSpeed >= 18 {
            return String(format: "Held %.1f mph average — strong tempo today.", ride.averageSpeed)
        }
        return "Time in the saddle is time well spent."
    }

    private var mainStats: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            summaryCell(value: String(format: "%.1f", ride.distanceMiles), label: "Miles", color: accentColor)
            summaryCell(value: ride.durationFormatted, label: "Duration", color: .green)
            summaryCell(value: ride.averageSpeedFormatted, label: "Avg MPH", color: .blue)
            summaryCell(value: ride.maxSpeedFormatted, label: "Max MPH", color: .mint)
            summaryCell(value: String(format: "%.0f", ride.totalElevationGain), label: "Elev Gain", color: .orange)
            summaryCell(value: "\(ride.caloriesBurned)", label: "Calories", color: PepTheme.amber)
        }
    }

    private var powerStats: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Output", title: "Power & Cadence", accent: .yellow)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                summaryCell(value: "\(ride.averagePower)", label: "AVG WATTS", color: .yellow)
                summaryCell(value: "\(ride.maxPower)", label: "MAX WATTS", color: .red)
                summaryCell(value: "\(ride.averageCadence)", label: "AVG RPM", color: .mint)
                summaryCell(value: "\(ride.maxCadence)", label: "MAX RPM", color: .teal)
            }
        }
        .editorialCard(accent: .yellow)
    }

    private func summaryCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var segmentsSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Splits", title: "Segments", accent: accentColor)
            ForEach(ride.segments.prefix(10)) { seg in
                HStack {
                    Text("Mile \(seg.segmentNumber)")
                        .font(.system(size: 13, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                    HStack(spacing: 12) {
                        Text("\(seg.avgSpeedFormatted) mph")
                            .font(.system(size: 13, weight: .semibold, design: .serif))
                            .foregroundStyle(accentColor)
                        Text("\(seg.avgHeartRate) bpm")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
            }
        }
        .editorialCard(accent: accentColor)
    }

    private var heartRateZoneSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Effort", title: "Heart Rate Zones", accent: .red)
            ForEach(ride.heartRateZones, id: \.zone.id) { dist in
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
        .editorialCard(accent: .red)
    }
}
