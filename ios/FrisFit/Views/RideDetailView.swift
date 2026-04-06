import SwiftUI
import MapKit

struct RideDetailView: View {
    let ride: CompletedRide
    let bike: Bike?

    private let accentColor = Color(red: 0.95, green: 0.45, blue: 0.0)

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                routeMapSection
                headerSection
                mainStatsGrid
                elevationCard
                powerCadenceCard
                speedSegmentsCard
                heartRateZonesCard
                rideInfoCard
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(FrisTheme.background.ignoresSafeArea())
        .navigationTitle("Ride Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Route Map

    private var routeMapSection: some View {
        Group {
            if !ride.routeCoordinates.isEmpty {
                Map {
                    MapPolyline(coordinates: ride.routeCoordinates.map {
                        CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                    })
                    .stroke(accentColor, lineWidth: 3)
                }
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
                .frame(height: 200)
                .clipShape(.rect(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(FrisTheme.glassBorderTop, lineWidth: 0.5)
                )
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(ride.rideType.color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: ride.rideType.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(ride.rideType.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(ride.rideType.rawValue)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(FrisTheme.textPrimary)
                        if ride.isIndoor {
                            Text("INDOOR")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(FrisTheme.violet)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(FrisTheme.violet.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        if let cat = ride.climbCategory {
                            Text(cat.rawValue)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(cat.color)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(cat.color.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    Text(ride.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().hour().minute()))
                        .font(.caption)
                        .foregroundStyle(FrisTheme.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("+\(ride.fpEarned)")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(FrisTheme.amber)
                    Text("FP")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(FrisTheme.amber.opacity(0.7))
                }
            }
        }
    }

    // MARK: - Main Stats

    private var mainStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            statCell(value: String(format: "%.1f", ride.distanceMiles), label: "Miles", color: accentColor)
            statCell(value: ride.movingTimeFormatted, label: "Moving Time", color: .green)
            statCell(value: ride.averageSpeedFormatted, label: "Avg MPH", color: .blue)
            statCell(value: ride.maxSpeedFormatted, label: "Max MPH", color: .mint)
            statCell(value: String(format: "%.0f ft", ride.totalElevationGain), label: "Elev Gain", color: .orange)
            statCell(value: "\(ride.caloriesBurned)", label: "Calories", color: FrisTheme.amber)
        }
    }

    private func statCell(value: String, label: String, color: Color) -> some View {
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
        .padding(.vertical, 14)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 12))
    }

    // MARK: - Elevation Card

    private var elevationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "mountain.2.fill")
                    .foregroundStyle(.green)
                HeadlineText(text: "Elevation Profile")
                Spacer()
            }

            if ride.routeCoordinates.count >= 2 {
                let elevations = ride.routeCoordinates.map(\.elevation)
                let minElev = (elevations.min() ?? 0) - 5
                let maxElev = (elevations.max() ?? 100) + 5
                let range = max(maxElev - minElev, 1)

                GeometryReader { geo in
                    let width = geo.size.width
                    let height: CGFloat = 80
                    let stepX = width / CGFloat(max(elevations.count - 1, 1))

                    ZStack(alignment: .topLeading) {
                        Path { path in
                            for (i, elev) in elevations.enumerated() {
                                let x = CGFloat(i) * stepX
                                let y = height - CGFloat((elev - minElev) / range) * height
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
                                let y = height - CGFloat((elev - minElev) / range) * height
                                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                        }
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    }
                    .frame(height: height)
                }
                .frame(height: 80)
            }

            HStack(spacing: 16) {
                Label(String(format: "%.0f ft gain", ride.totalElevationGain), systemImage: "arrow.up.right")
                    .foregroundStyle(.green)
                Label(String(format: "%.0f ft loss", ride.totalElevationLoss), systemImage: "arrow.down.right")
                    .foregroundStyle(.red)
            }
            .font(.system(size: 11, weight: .medium))
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    // MARK: - Power & Cadence

    private var powerCadenceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.heart.fill")
                    .foregroundStyle(.yellow)
                HeadlineText(text: "Power & Cadence")
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                powerCell(value: "\(ride.averagePower)", label: "Avg Power (W)", color: .yellow)
                powerCell(value: "\(ride.maxPower)", label: "Max Power (W)", color: .red)
                powerCell(value: "\(ride.averageCadence)", label: "Avg Cadence", color: .mint)
                powerCell(value: "\(ride.maxCadence)", label: "Max Cadence", color: .teal)
            }

            HStack(spacing: 16) {
                Label("\(ride.averageHeartRate) avg bpm", systemImage: "heart.fill")
                    .foregroundStyle(.red)
                Label("\(ride.maxHeartRate) max bpm", systemImage: "heart.fill")
                    .foregroundStyle(.red.opacity(0.6))
            }
            .font(.system(size: 11, weight: .medium))
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private func powerCell(value: String, label: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Spacer()
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(FrisTheme.textSecondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(12)
        .background(FrisTheme.elevated.opacity(0.5))
        .clipShape(.rect(cornerRadius: 10))
    }

    // MARK: - Speed Segments

    private var speedSegmentsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "speedometer")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Mile Segments")
                Spacer()
                Text("\(ride.segments.count) segments")
                    .font(.caption)
                    .foregroundStyle(FrisTheme.textSecondary)
            }

            if ride.segments.isEmpty {
                HStack {
                    Spacer()
                    Text("No segment data")
                        .font(.caption)
                        .foregroundStyle(FrisTheme.textSecondary)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                let maxSpeed = ride.segments.map(\.avgSpeed).max() ?? 1
                ForEach(ride.segments.prefix(15)) { seg in
                    HStack(spacing: 10) {
                        Text("\(seg.segmentNumber)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(accentColor)
                            .frame(width: 20)

                        GeometryReader { geo in
                            let fraction = maxSpeed > 0 ? CGFloat(seg.avgSpeed / maxSpeed) : 0
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [accentColor, accentColor.opacity(0.5)],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * fraction, height: 14)
                        }
                        .frame(height: 14)

                        Text("\(seg.avgSpeedFormatted)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(FrisTheme.textPrimary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    // MARK: - Heart Rate Zones

    private var heartRateZonesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                HeadlineText(text: "Heart Rate Zones")
                Spacer()
            }

            ForEach(ride.heartRateZones, id: \.zone.id) { dist in
                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(dist.zone.color)
                            .frame(width: 8, height: 8)
                        Text("Z\(dist.zone.rawValue)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(dist.zone.color)
                    }
                    .frame(width: 42, alignment: .leading)

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
        .overlay(cardBorder())
    }

    // MARK: - Ride Info

    private var rideInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(FrisTheme.textSecondary)
                HeadlineText(text: "Ride Info")
                Spacer()
            }

            HStack {
                Text("Duration")
                    .foregroundStyle(FrisTheme.textSecondary)
                Spacer()
                Text(ride.durationFormatted)
                    .foregroundStyle(FrisTheme.textPrimary)
            }
            .font(.system(size: 13, weight: .medium))

            HStack {
                Text("Moving Time")
                    .foregroundStyle(FrisTheme.textSecondary)
                Spacer()
                Text(ride.movingTimeFormatted)
                    .foregroundStyle(FrisTheme.textPrimary)
            }
            .font(.system(size: 13, weight: .medium))

            if let bike {
                HStack {
                    Text("Bike")
                        .foregroundStyle(FrisTheme.textSecondary)
                    Spacer()
                    Text("\(bike.name) (\(bike.type))")
                        .foregroundStyle(FrisTheme.textPrimary)
                }
                .font(.system(size: 13, weight: .medium))
            }

            if !ride.notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(FrisTheme.textSecondary)
                    Text(ride.notes)
                        .font(.system(size: 13))
                        .foregroundStyle(FrisTheme.textPrimary)
                }
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private func cardBorder() -> some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(
                LinearGradient(colors: [FrisTheme.glassBorderTop, FrisTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 0.5
            )
    }
}
