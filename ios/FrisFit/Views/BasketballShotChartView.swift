import SwiftUI

struct BasketballShotChartView: View {
    @Bindable var bbVM: BasketballViewModel
    @Environment(\.dismiss) private var dismiss

    private let accentColor = Color(red: 1.0, green: 0.55, blue: 0.1)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    overallSummary
                    courtChart
                    zoneBreakdown
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .appBackground()
            .navigationTitle("Shot Chart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(accentColor)
                }
            }
        }
    }

    private var overallSummary: some View {
        let allShots = bbVM.allShotChartEntries
        let made = allShots.filter(\.made).count
        let total = allShots.count
        let pct = total > 0 ? Double(made) / Double(total) * 100 : 0
        let threes = allShots.filter { $0.zone.isThreePointer }
        let threesMade = threes.filter(\.made).count
        let threePct = threes.isEmpty ? 0 : Double(threesMade) / Double(threes.count) * 100
        let twos = allShots.filter { !$0.zone.isThreePointer }
        let twosMade = twos.filter(\.made).count
        let twoPct = twos.isEmpty ? 0 : Double(twosMade) / Double(twos.count) * 100

        return HStack(spacing: 8) {
            summaryRing(label: "Overall", value: pct, made: made, total: total, color: accentColor)
            summaryRing(label: "2PT", value: twoPct, made: twosMade, total: twos.count, color: .green)
            summaryRing(label: "3PT", value: threePct, made: threesMade, total: threes.count, color: .blue)
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

    private func summaryRing(label: String, value: Double, made: Int, total: Int, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(PepTheme.elevated, lineWidth: 5)
                    .frame(width: 56, height: 56)
                Circle()
                    .trim(from: 0, to: min(value / 100, 1.0))
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                Text(String(format: "%.0f", value))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
            Text("\(made)/\(total)")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var courtChart: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h: CGFloat = 280

            ZStack {
                courtShape(width: w, height: h)

                ForEach(ShotZone.allCases) { zone in
                    let stats = bbVM.shotZoneStats(for: zone)
                    if stats.attempted > 0 {
                        let pos = zone.position
                        let heatColor: Color = stats.percentage >= 50 ? .green : stats.percentage >= 35 ? PepTheme.amber : .red

                        VStack(spacing: 2) {
                            Circle()
                                .fill(heatColor.opacity(0.25))
                                .frame(width: max(CGFloat(stats.attempted) * 5, 20), height: max(CGFloat(stats.attempted) * 5, 20))
                                .overlay(
                                    VStack(spacing: 1) {
                                        Text(String(format: "%.0f%%", stats.percentage))
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .foregroundStyle(heatColor)
                                        Text("\(stats.made)/\(stats.attempted)")
                                            .font(.system(size: 7, weight: .semibold))
                                            .foregroundStyle(PepTheme.textSecondary)
                                    }
                                )
                        }
                        .position(x: w * pos.x, y: h * pos.y)
                    }
                }
            }
            .frame(height: h)
        }
        .frame(height: 280)
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

    private func courtShape(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .stroke(PepTheme.elevated.opacity(0.6), lineWidth: 1)
                .frame(width: width, height: height)

            RoundedRectangle(cornerRadius: 2)
                .stroke(PepTheme.elevated.opacity(0.5), lineWidth: 1)
                .frame(width: width * 0.32, height: height * 0.35)
                .offset(y: height * 0.325)

            Circle()
                .stroke(PepTheme.elevated.opacity(0.4), lineWidth: 1)
                .frame(width: width * 0.22, height: width * 0.22)
                .offset(y: height * 0.15)

            Path { path in
                let centerX = width / 2
                let radius = width * 0.42
                path.addArc(center: CGPoint(x: centerX, y: height), radius: radius, startAngle: .degrees(160), endAngle: .degrees(20), clockwise: true)
            }
            .stroke(PepTheme.elevated.opacity(0.4), lineWidth: 1)
        }
    }

    private var zoneBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet.rectangle.fill")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Zone Breakdown")
                Spacer()
            }

            let sortedZones = ShotZone.allCases.filter { bbVM.shotZoneStats(for: $0).attempted > 0 }
                .sorted { bbVM.shotZoneStats(for: $0).percentage > bbVM.shotZoneStats(for: $1).percentage }

            if sortedZones.isEmpty {
                HStack {
                    Spacer()
                    Text("No shots recorded")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                }
                .padding(.vertical, 16)
            } else {
                ForEach(sortedZones) { zone in
                    let stats = bbVM.shotZoneStats(for: zone)
                    let color: Color = stats.percentage >= 50 ? .green : stats.percentage >= 35 ? PepTheme.amber : .red

                    HStack(spacing: 12) {
                        Text(zone.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                            .frame(width: 90, alignment: .leading)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(PepTheme.elevated)
                                    .frame(height: 8)
                                Capsule()
                                    .fill(color)
                                    .frame(width: max(geo.size.width * (stats.percentage / 100), 4), height: 8)
                            }
                        }
                        .frame(height: 8)

                        Text(String(format: "%.0f%%", stats.percentage))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(color)
                            .frame(width: 36, alignment: .trailing)

                        Text("\(stats.made)/\(stats.attempted)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                            .frame(width: 32, alignment: .trailing)
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
}
