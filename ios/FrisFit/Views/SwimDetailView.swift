import SwiftUI
import MapKit

struct SwimDetailView: View {
    let swim: CompletedSwim

    private let accentColor = Color(red: 0.2, green: 0.6, blue: 1.0)

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                heroCard
                keyMetricsCard
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
        .appBackground(accent: accentColor)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero

    private var heroCard: some View {
        PepSportCard(accent: swim.sessionType.color) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    HStack(spacing: 6) {
                        Image(systemName: swim.sessionType.icon)
                            .font(.system(size: 9, weight: .bold))
                        Text(swim.sessionType.rawValue.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(2.0)
                    }
                    .foregroundStyle(swim.sessionType.color)

                    Spacer()

                    if swim.isOpenWater {
                        Text("OPEN WATER")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(Color(red: 0.0, green: 0.8, blue: 0.7))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(red: 0.0, green: 0.8, blue: 0.7).opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                Text(SwimFormatters.formatDistance(swim.totalDistanceMeters))
                    .font(.system(size: 34, weight: .semibold, design: .serif))
                    .kerning(-0.5)
                    .foregroundStyle(PepTheme.textPrimary)

                Text(swim.date.formatted(.dateTime.weekday(.wide).month(.wide).day().hour().minute()))
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)

                LinearGradient(
                    colors: [PepTheme.textPrimary.opacity(0.16), PepTheme.textPrimary.opacity(0)],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 0.5)

                HStack(spacing: 0) {
                    heroStat(value: swim.durationFormatted, label: "DURATION")
                    divider
                    heroStat(value: swim.averagePaceFormatted, label: "PACE/100")
                    divider
                    heroStat(value: swim.totalLaps > 0 ? "\(swim.totalLaps)" : "—", label: "LAPS")
                }
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(PepTheme.shimmerHighlight)
            .frame(width: 0.5, height: 32)
    }

    private func heroStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Metrics grid

    private var keyMetricsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Numbers", title: "Session metrics", accent: accentColor)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                if swim.averageSwolf > 0 {
                    metricCell(icon: "gauge.with.needle", value: String(format: "%.0f", swim.averageSwolf), label: "Avg Swolf", color: .green)
                }
                if swim.bestSwolf > 0 {
                    metricCell(icon: "star.fill", value: "\(swim.bestSwolf)", label: "Best Swolf", color: PepTheme.amber)
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
        }
        .editorialCard(accent: accentColor)
    }

    private func metricCell(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color.opacity(0.85))
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.06))
        .clipShape(.rect(cornerRadius: 10))
    }

    // MARK: - Lap breakdown

    private var lapBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(
                kicker: "Lap by lap",
                title: "Lap breakdown",
                accent: accentColor,
                trailing: AnyView(
                    Text("\(swim.laps.count) LAPS")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(PepTheme.textSecondary)
                )
            )

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
                            Text(stroke.rawValue.uppercased())
                                .font(.system(size: 8, weight: .bold))
                                .tracking(1.0)
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                }
                Spacer()
                Text("TALLER = FASTER")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
            }

            ScrollView {
                VStack(spacing: 0) {
                    HStack {
                        Text("#")
                            .frame(width: 28, alignment: .leading)
                        Text("STROKE")
                            .frame(width: 80, alignment: .leading)
                        Spacer()
                        Text("TIME")
                            .frame(width: 50, alignment: .trailing)
                        Text("SWOLF")
                            .frame(width: 48, alignment: .trailing)
                        Text("PACE")
                            .frame(width: 50, alignment: .trailing)
                    }
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.0)
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
                            .frame(width: 80, alignment: .leading)
                            Spacer()
                            Text(SwimFormatters.formatDuration(lap.duration))
                                .frame(width: 50, alignment: .trailing)
                            Text("\(lap.swolf)")
                                .frame(width: 48, alignment: .trailing)
                                .foregroundStyle(lap.swolf <= Int(swim.averageSwolf) ? .green : PepTheme.textPrimary)
                            Text(SwimFormatters.formatPace(lap.pacePer100))
                                .frame(width: 50, alignment: .trailing)
                        }
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(PepTheme.textPrimary)
                        .padding(.vertical, 4)
                    }

                    if swim.laps.count > 20 {
                        Text("+\(swim.laps.count - 20) more laps")
                            .font(.system(size: 11, design: .serif))
                            .italic()
                            .foregroundStyle(PepTheme.textSecondary)
                            .padding(.top, 4)
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .editorialCard(accent: accentColor)
    }

    // MARK: - Stroke breakdown

    private var strokeBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Stroke", title: "Breakdown", accent: accentColor)

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
                            .font(.system(size: 14, weight: .semibold, design: .serif))
                            .foregroundStyle(PepTheme.textPrimary)
                        HStack(spacing: 8) {
                            Text("\(breakdown.laps) laps")
                            Text(SwimFormatters.formatDistance(breakdown.distanceMeters))
                        }
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(PepTheme.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text("\(Int(breakdown.percentage * 100))%")
                            .font(.system(size: 16, weight: .semibold, design: .serif))
                            .foregroundStyle(breakdown.strokeType.color)
                        Text(SwimFormatters.formatPace(breakdown.averagePace) + "/100m")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .editorialCard(accent: accentColor)
    }

    // MARK: - Heart rate zones

    private var heartRateZonesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(
                kicker: "Effort",
                title: "Heart rate zones",
                accent: .red,
                trailing: swim.averageHeartRate > 0 ? AnyView(
                    Text("AVG \(swim.averageHeartRate) · MAX \(swim.maxHeartRate)")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.0)
                        .foregroundStyle(PepTheme.textSecondary)
                ) : nil
            )

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
                        .font(.system(size: 13, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                        .frame(width: 80, alignment: .leading)
                    Text("\(zone.zone.bpmRange.min)-\(zone.zone.bpmRange.max) bpm")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                    Text(SwimFormatters.formatDuration(zone.timeInZone))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("\(Int(zone.percentage * 100))%")
                        .font(.system(size: 12, weight: .semibold, design: .serif))
                        .foregroundStyle(zone.zone.color)
                        .frame(width: 36, alignment: .trailing)
                }
            }
        }
        .editorialCard(accent: .red)
    }

    // MARK: - Map

    private var openWaterMapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Route", title: "Open water map", accent: Color(red: 0.0, green: 0.8, blue: 0.7))

            let coords = swim.openWaterCoordinates

            Map {
                MapPolyline(coordinates: coords.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) })
                    .stroke(accentColor, lineWidth: 3)
            }
            .mapStyle(.standard(elevation: .flat))
            .frame(height: 200)
            .clipShape(.rect(cornerRadius: 12))
            .disabled(true)
        }
        .editorialCard(accent: Color(red: 0.0, green: 0.8, blue: 0.7))
    }

    // MARK: - SWOLF analysis

    private var swolfAnalysisCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Efficiency", title: "Swolf analysis", accent: accentColor)

            if swim.averageSwolf > 0 {
                HStack(spacing: 12) {
                    VStack(spacing: 4) {
                        Text(String(format: "%.0f", swim.averageSwolf))
                            .font(.system(size: 30, weight: .semibold, design: .serif))
                            .foregroundStyle(accentColor)
                        Text("AVERAGE")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(accentColor.opacity(0.06))
                    .clipShape(.rect(cornerRadius: 12))

                    VStack(spacing: 4) {
                        Text("\(swim.bestSwolf)")
                            .font(.system(size: 30, weight: .semibold, design: .serif))
                            .foregroundStyle(.green)
                        Text("BEST")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.green.opacity(0.06))
                    .clipShape(.rect(cornerRadius: 12))
                }

                Text("Swolf = stroke count + lap time (seconds). Lower means more efficient — fewer strokes for the same lap time.")
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Swolf data isn't available for this session.")
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
        }
        .editorialCard(accent: accentColor)
    }

    // MARK: - Notes

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            EditorialSectionHeading(kicker: "Logbook", title: "Notes", accent: accentColor)
            Text(swim.notes)
                .font(.system(size: 14, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .editorialCard(accent: accentColor)
    }
}
