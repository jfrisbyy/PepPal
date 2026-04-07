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
                if cyclingVM.routePoints.count >= 2 {
                    MapPolyline(coordinates: cyclingVM.routePoints.map {
                        CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                    })
                    .stroke(accentColor, lineWidth: 3)
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
                Image(systemName: "list.number")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Segments")
                Spacer()
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
            .background(PepTheme.background.ignoresSafeArea())
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
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text(ride.rideType.rawValue)
                .font(.title2.weight(.bold))
                .foregroundStyle(PepTheme.textPrimary)

            if let cat = ride.climbCategory {
                Text(cat.rawValue)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(cat.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(cat.color.opacity(0.12))
                    .clipShape(Capsule())
            }


        }
        .padding(.top, 12)
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
        VStack(alignment: .leading, spacing: 10) {
            HeadlineText(text: "Power & Cadence")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                summaryCell(value: "\(ride.averagePower)", label: "Avg Watts", color: .yellow)
                summaryCell(value: "\(ride.maxPower)", label: "Max Watts", color: .red)
                summaryCell(value: "\(ride.averageCadence)", label: "Avg RPM", color: .mint)
                summaryCell(value: "\(ride.maxCadence)", label: "Max RPM", color: .teal)
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
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

    private var segmentsSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            HeadlineText(text: "Segments")
            ForEach(ride.segments.prefix(10)) { seg in
                HStack {
                    Text("Mi \(seg.segmentNumber)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                    HStack(spacing: 12) {
                        Text("\(seg.avgSpeedFormatted) mph")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(accentColor)
                        Text("\(seg.avgHeartRate) bpm")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
    }

    private var heartRateZoneSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            HeadlineText(text: "Heart Rate Zones")
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
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
    }
}
