import SwiftUI
import MapKit

struct SwimDetailView: View {
    let swim: CompletedSwim

    private let accentColor = Color(red: 0.2, green: 0.6, blue: 1.0)

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                keyMetricsGrid
                if !swim.laps.isEmpty { lapBreakdownCard }
                if !swim.strokeBreakdown.isEmpty { strokeBreakdownCard }
                if !swim.heartRateZones.isEmpty { heartRateZonesCard }
                if !swim.openWaterCoordinates.isEmpty { openWaterMapCard }
                swolfAnalysisCard
                if !swim.notes.isEmpty { notesCard }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(PepTheme.background.ignoresSafeArea())
        .navigationTitle("Swim Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        GlassCard {
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [swim.sessionType.color.opacity(0.3), swim.sessionType.color.opacity(0.05)],
                                    center: .center, startRadius: 0, endRadius: 32
                                )
                            )
                            .frame(width: 56, height: 56)
                        Image(systemName: swim.sessionType.icon)
                            .font(.system(size: 24))
                            .foregroundStyle(swim.sessionType.color)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(swim.sessionType.rawValue)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text(swim.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().hour().minute()))
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(swim.fpEarned)")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.amber)
                        Text("FP earned")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }

                HStack(spacing: 0) {
                    heroStat(value: SwimFormatters.formatDistance(swim.totalDistanceMeters), label: "Distance")
                    Divider().frame(height: 40).overlay(PepTheme.separatorColor)
                    heroStat(value: swim.durationFormatted, label: "Duration")
                    Divider().frame(height: 40).overlay(PepTheme.separatorColor)
                    heroStat(value: swim.averagePaceFormatted, label: "Pace/100m")
                }
            }
        }
    }

    private func heroStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(accentColor)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var keyMetricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            if swim.totalLaps > 0 {
                metricCell(icon: "repeat", value: "\(swim.totalLaps)", label: "Laps", color: accentColor)
            }
            if swim.averageSwolf > 0 {
                metricCell(icon: "gauge.with.needle", value: String(format: "%.0f", swim.averageSwolf), label: "Avg SWOLF", color: .green)
            }
            if swim.bestSwolf > 0 {
                metricCell(icon: "star.fill", value: "\(swim.bestSwolf)", label: "Best SWOLF", color: PepTheme.amber)
            }
            metricCell(icon: "speedometer", value: swim.bestPaceFormatted, label: "Best Pace", color: .green)
            if swim.averageHeartRate > 0 {
                metricCell(icon: "heart.fill", value: "\(swim.averageHeartRate)", label: "Avg HR", color: .red)
            }
            if swim.caloriesBurned > 0 {
                metricCell(icon: "flame.fill", value: "\(swim.caloriesBurned)", label: "Calories", color: .orange)
            }
            if swim.totalStrokeCount > 0 {
                metricCell(icon: "hand.raised.fill", value: "\(swim.totalStrokeCount)", label: "Strokes", color: PepTheme.violet)
            }
            if swim.averageStrokeCount > 0 {
                metricCell(icon: "number", value: String(format: "%.0f", swim.averageStrokeCount), label: "Strokes/Lap", color: accentColor)
            }
            if !swim.poolLength.rawValue.isEmpty && !swim.isOpenWater {
                metricCell(icon: "ruler", value: swim.poolLength.rawValue, label: "Pool", color: PepTheme.textSecondary)
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private func metricCell(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color.opacity(0.7))
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.06))
        .clipShape(.rect(cornerRadius: 10))
    }

    private var lapBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.number")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Lap Breakdown")
                Spacer()
                Text("\(swim.laps.count) laps")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }

            let maxPace = swim.laps.map(\.pacePer100).max() ?? 1
            let minPace = swim.laps.map(\.pacePer100).min() ?? 0
            let range = max(maxPace - minPace, 1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(swim.laps) { lap in
                        VStack(spacing: 2) {
                            let normalizedHeight = max(1.0 - CGFloat((lap.pacePer100 - minPace) / range), 0.1)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(lap.strokeType.color)
                                .frame(width: max(200 / CGFloat(swim.laps.count), 6), height: normalizedHeight * 60 + 8)
                        }
                    }
                }
                .frame(height: 75)
            }
            .contentMargins(.horizontal, 4)

            HStack(spacing: 12) {
                ForEach(SwimStrokeType.allCases) { stroke in
                    let hasStroke = swim.laps.contains { $0.strokeType == stroke }
                    if hasStroke {
                        HStack(spacing: 4) {
                            Circle().fill(stroke.color).frame(width: 6, height: 6)
                            Text(stroke.rawValue)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                }
                Spacer()
                Text("↑ Taller = Faster")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
            }

            ScrollView {
                VStack(spacing: 0) {
                    HStack {
                        Text("#")
                            .frame(width: 28, alignment: .leading)
                        Text("Stroke")
                            .frame(width: 70, alignment: .leading)
                        Spacer()
                        Text("Time")
                            .frame(width: 50, alignment: .trailing)
                        Text("SWOLF")
                            .frame(width: 48, alignment: .trailing)
                        Text("Pace")
                            .frame(width: 50, alignment: .trailing)
                    }
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .padding(.vertical, 6)

                    ForEach(swim.laps.prefix(20)) { lap in
                        HStack {
                            Text("\(lap.lapNumber)")
                                .frame(width: 28, alignment: .leading)
                            HStack(spacing: 4) {
                                Circle().fill(lap.strokeType.color).frame(width: 5, height: 5)
                                Text(lap.strokeType.rawValue)
                            }
                            .frame(width: 70, alignment: .leading)
                            Spacer()
                            Text(SwimFormatters.formatDuration(lap.duration))
                                .frame(width: 50, alignment: .trailing)
                            Text("\(lap.swolf)")
                                .frame(width: 48, alignment: .trailing)
                                .foregroundStyle(lap.swolf <= Int(swim.averageSwolf) ? .green : PepTheme.textPrimary)
                            Text(SwimFormatters.formatPace(lap.pacePer100))
                                .frame(width: 50, alignment: .trailing)
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PepTheme.textPrimary)
                        .padding(.vertical, 4)
                    }

                    if swim.laps.count > 20 {
                        Text("+\(swim.laps.count - 20) more laps")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                            .padding(.top, 4)
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private var strokeBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Stroke Breakdown")
                Spacer()
            }

            ForEach(swim.strokeBreakdown) { breakdown in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(breakdown.strokeType.color.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: breakdown.strokeType.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(breakdown.strokeType.color)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(breakdown.strokeType.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                        HStack(spacing: 8) {
                            Text("\(breakdown.laps) laps")
                            Text(SwimFormatters.formatDistance(breakdown.distanceMeters))
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text("\(Int(breakdown.percentage * 100))%")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(breakdown.strokeType.color)
                        Text(SwimFormatters.formatPace(breakdown.averagePace) + "/100m")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private var heartRateZonesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                HeadlineText(text: "Heart Rate Zones")
                Spacer()
                if swim.averageHeartRate > 0 {
                    Text("Avg \(swim.averageHeartRate) · Max \(swim.maxHeartRate)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }

            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(swim.heartRateZones, id: \.zone) { zone in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(zone.zone.color)
                            .frame(width: max(geo.size.width * zone.percentage, 2))
                    }
                }
            }
            .frame(height: 16)

            ForEach(swim.heartRateZones, id: \.zone) { zone in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(zone.zone.color)
                        .frame(width: 4, height: 22)
                    Text(zone.zone.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .frame(width: 70, alignment: .leading)
                    Text("\(zone.zone.bpmRange.min)-\(zone.zone.bpmRange.max) bpm")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                    Text(SwimFormatters.formatDuration(zone.timeInZone))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("\(Int(zone.percentage * 100))%")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(zone.zone.color)
                        .frame(width: 32, alignment: .trailing)
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private var openWaterMapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "map.fill")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Route Map")
                Spacer()
            }

            let coords = swim.openWaterCoordinates
            let centerLat = coords.map(\.latitude).reduce(0, +) / Double(max(coords.count, 1))
            let centerLng = coords.map(\.longitude).reduce(0, +) / Double(max(coords.count, 1))

            Map {
                MapPolyline(coordinates: coords.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) })
                    .stroke(accentColor, lineWidth: 3)
            }
            .mapStyle(.standard(elevation: .flat))
            .frame(height: 200)
            .clipShape(.rect(cornerRadius: 12))
            .disabled(true)
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private var swolfAnalysisCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gauge.with.needle")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "SWOLF Analysis")
                Spacer()
            }

            if swim.averageSwolf > 0 {
                HStack(spacing: 12) {
                    VStack(spacing: 4) {
                        Text(String(format: "%.0f", swim.averageSwolf))
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .foregroundStyle(accentColor)
                        Text("Average")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(accentColor.opacity(0.06))
                    .clipShape(.rect(cornerRadius: 12))

                    VStack(spacing: 4) {
                        Text("\(swim.bestSwolf)")
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .foregroundStyle(.green)
                        Text("Best")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.green.opacity(0.06))
                    .clipShape(.rect(cornerRadius: 12))
                }

                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
                    Text("SWOLF = Stroke Count + Lap Time (seconds). Lower is more efficient.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.8))
                }
            } else {
                HStack {
                    Spacer()
                    Text("SWOLF data not available for this session")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Notes")
                Spacer()
            }
            Text(swim.notes)
                .font(.system(size: 13))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private func cardBorder() -> some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(
                LinearGradient(colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 0.5
            )
    }
}
