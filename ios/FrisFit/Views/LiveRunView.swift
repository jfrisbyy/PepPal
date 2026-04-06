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
            FrisTheme.background.ignoresSafeArea()

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
                .foregroundStyle(FrisTheme.textSecondary)
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
                if runVM.routePoints.count >= 2 {
                    MapPolyline(coordinates: runVM.routePoints.map {
                        CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                    })
                    .stroke(accentColor, lineWidth: 3)
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
                    .background(FrisTheme.violet.opacity(0.9))
                    .clipShape(Capsule())
                }

                if !runVM.isTreadmillMode {
                    GPSSignalBadge(signal: runVM.gpsSignal)
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
                        .foregroundStyle(FrisTheme.textPrimary)
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
                .fill(FrisTheme.separatorColor)
                .frame(width: 0.5, height: 50)

            metricBlock(
                value: runVM.currentPaceFormatted,
                unit: "/\(runVM.settings.distanceUnit.abbreviation)",
                label: "Pace"
            )

            Rectangle()
                .fill(FrisTheme.separatorColor)
                .frame(width: 0.5, height: 50)

            metricBlock(
                value: runVM.elapsedFormatted,
                unit: "",
                label: "Time"
            )
        }
        .padding(.vertical, 16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [accentColor.opacity(0.12), FrisTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    private func metricBlock(value: String, unit: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(FrisTheme.textPrimary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FrisTheme.textSecondary)
                }
            }
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(FrisTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Secondary Metrics

    private var secondaryMetrics: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            miniMetric(icon: "heart.fill", value: "\(runVM.currentHeartRate)", label: "BPM", color: .red)
            miniMetric(icon: "shoeprints.fill", value: "\(runVM.currentCadence)", label: "Cadence", color: .green)
            miniMetric(icon: "flame.fill", value: "\(runVM.currentCalories)", label: "Cal", color: .orange)
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
                .foregroundStyle(FrisTheme.textPrimary)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(FrisTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(FrisTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    // MARK: - Live Splits

    private var liveSplitsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "list.number")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Splits")
                Spacer()
            }

            if runVM.currentSplits.isEmpty {
                HStack {
                    Spacer()
                    Text("First split at 1 \(runVM.settings.distanceUnit.splitLabel)...")
                        .font(.caption)
                        .foregroundStyle(FrisTheme.textSecondary)
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
                                .foregroundStyle(FrisTheme.textPrimary)
                            HStack(spacing: 8) {
                                Label("\(split.avgHeartRate) bpm", systemImage: "heart.fill")
                                Label(String(format: "%+.0f ft", split.elevationChange), systemImage: "arrow.up.right")
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(FrisTheme.textSecondary)
                        }

                        Spacer()

                        splitPaceIndicator(split)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(FrisTheme.glassBorderTop, lineWidth: 0.5)
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
        .foregroundStyle(diff < -0.1 ? .green : diff > 0.1 ? .red : FrisTheme.textSecondary)
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
                        .background(FrisTheme.elevated)
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
            .background(FrisTheme.background.ignoresSafeArea())
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
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text(run.runType.rawValue)
                .font(.title2.weight(.bold))
                .foregroundStyle(FrisTheme.textPrimary)

            Text("+\(run.fpEarned) FP")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(FrisTheme.amber)
        }
        .padding(.top, 12)
    }

    private var mainStats: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            summaryCell(value: String(format: "%.2f", run.distanceMiles), label: "Miles", color: accentColor)
            summaryCell(value: run.durationFormatted, label: "Duration", color: .green)
            summaryCell(value: run.averagePaceFormatted, label: "Avg Pace", color: .orange)
            summaryCell(value: "\(run.averageHeartRate)", label: "Avg HR", color: .red)
            summaryCell(value: "\(run.cadence)", label: "Cadence", color: FrisTheme.violet)
            summaryCell(value: "\(run.caloriesBurned)", label: "Calories", color: FrisTheme.amber)
        }
    }

    private func summaryCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(FrisTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var splitsSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            HeadlineText(text: "Splits")
            ForEach(run.splits) { split in
                HStack {
                    Text("Mile \(split.splitNumber)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FrisTheme.textPrimary)
                    Spacer()
                    Text(split.paceFormatted + " /mi")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(accentColor)
                }
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
    }

    private var heartRateZoneSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            HeadlineText(text: "Heart Rate Zones")
            ForEach(run.heartRateZones, id: \.zone.id) { dist in
                HStack(spacing: 10) {
                    Text("Z\(dist.zone.rawValue)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(dist.zone.color)
                        .frame(width: 24)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(FrisTheme.elevated)
                                .frame(height: 8)
                            Capsule()
                                .fill(dist.zone.color)
                                .frame(width: geo.size.width * dist.percentage, height: 8)
                        }
                    }
                    .frame(height: 8)

                    Text("\(Int(dist.percentage * 100))%")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(FrisTheme.textSecondary)
                        .frame(width: 32, alignment: .trailing)
                }
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
    }
}
