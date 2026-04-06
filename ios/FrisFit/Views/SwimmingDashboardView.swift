import SwiftUI
import MapKit

struct SwimmingDashboardView: View {
    @Bindable var swimVM: SwimmingViewModel
    let accentColor: Color

    var body: some View {
        VStack(spacing: 16) {
            quickStatsHeader
            sessionTypeSelector
            weeklyVolumeChart
            swolfTrendCard
            strokeDistributionCard
            cssCard
            recentSwimsList
            personalBestsCard
            paceZonesCard
        }
    }

    private var quickStatsHeader: some View {
        GlassCard {
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [accentColor.opacity(0.3), accentColor.opacity(0.05)],
                                    center: .center, startRadius: 0, endRadius: 32
                                )
                            )
                            .frame(width: 56, height: 56)
                        Image(systemName: "figure.pool.swim")
                            .font(.system(size: 24))
                            .foregroundStyle(accentColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Swimming")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(FrisTheme.textPrimary)
                        Text("\(swimVM.thisWeekSwims.count) swim\(swimVM.thisWeekSwims.count == 1 ? "" : "s") this week · \(SwimFormatters.formatDistance(swimVM.thisWeekMeters))")
                            .font(.caption)
                            .foregroundStyle(FrisTheme.textSecondary)
                    }

                    Spacer()

                    Button {
                        swimVM.showSwimSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(FrisTheme.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(FrisTheme.elevated.opacity(0.6))
                            .clipShape(Circle())
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    quickStat(value: SwimFormatters.formatDistance(swimVM.totalMetersAllTime), label: "Total Dist", icon: "water.waves")
                    quickStat(value: "\(swimVM.totalLapsAllTime)", label: "Total Laps", icon: "repeat")
                    quickStat(value: SwimFormatters.formatPace(swimVM.averagePaceAllTime), label: "Avg Pace", icon: "speedometer")
                    quickStat(value: String(format: "%.0f", swimVM.averageSwolfAllTime), label: "Avg SWOLF", icon: "gauge.with.needle")
                }
            }
        }
    }

    private func quickStat(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(accentColor.opacity(0.7))
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(FrisTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(FrisTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(FrisTheme.elevated.opacity(0.5))
        .clipShape(.rect(cornerRadius: 10))
    }

    private var sessionTypeSelector: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                ForEach([SwimSessionType.poolLaps, .structuredWorkout, .openWater, .drillSession], id: \.id) { type in
                    Button {
                        swimVM.selectedSessionType = type
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: type.icon)
                                .font(.system(size: 16))
                            Text(type.rawValue)
                                .font(.system(size: 8, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(swimVM.selectedSessionType == type ? .black : FrisTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(swimVM.selectedSessionType == type ? type.color : FrisTheme.elevated.opacity(0.5))
                        .clipShape(.rect(cornerRadius: 10))
                    }
                }
            }

            HStack(spacing: 10) {
                Button {
                    swimVM.showDrillLibrary = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 10))
                        Text("Drills")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(FrisTheme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(FrisTheme.elevated.opacity(0.5))
                    .clipShape(Capsule())
                }

                Button {
                    swimVM.showWorkoutBuilder = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.system(size: 10))
                        Text("Workouts")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(FrisTheme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(FrisTheme.elevated.opacity(0.5))
                    .clipShape(Capsule())
                }

                Button {
                    swimVM.showCSSTest = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                            .font(.system(size: 10))
                        Text("CSS Test")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(FrisTheme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(FrisTheme.elevated.opacity(0.5))
                    .clipShape(Capsule())
                }

                Spacer()
            }

            HStack(spacing: 6) {
                Image(systemName: "applewatch")
                    .font(.system(size: 11))
                    .foregroundStyle(accentColor.opacity(0.6))
                Text("Swim data syncs from Apple Watch via HealthKit")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(FrisTheme.textSecondary)
                Spacer()
                Button {
                    Task { await swimVM.importSwimDataFromHealthKit() }
                } label: {
                    HStack(spacing: 4) {
                        if swimVM.isImportingFromHealthKit {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "arrow.down.heart.fill")
                                .font(.system(size: 10))
                        }
                        Text("Sync")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accentColor.opacity(0.15))
                    .clipShape(Capsule())
                }
                .disabled(swimVM.isImportingFromHealthKit)
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [accentColor.opacity(0.15), FrisTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    private var weeklyVolumeChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Weekly Volume")
                Spacer()
                Text("\(SwimFormatters.formatDistance(swimVM.thisWeekMeters)) this week")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(accentColor)
            }

            let volumeData = swimVM.weeklyVolumeHistory
            let maxMeters = max(volumeData.map(\.totalMeters).max() ?? 1, 1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(volumeData) { week in
                        VStack(spacing: 4) {
                            Text(SwimFormatters.formatDistance(week.totalMeters))
                                .font(.system(size: 7, weight: .bold, design: .rounded))
                                .foregroundStyle(week.totalMeters > 0 ? accentColor : FrisTheme.textSecondary.opacity(0.4))

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    week.totalMeters > 0 ?
                                    LinearGradient(colors: [accentColor, accentColor.opacity(0.5)], startPoint: .top, endPoint: .bottom) :
                                    LinearGradient(colors: [FrisTheme.elevated, FrisTheme.elevated], startPoint: .top, endPoint: .bottom)
                                )
                                .frame(width: 24, height: max(CGFloat(week.totalMeters / maxMeters) * 80, 4))

                            Text(weekLabel(week.weekStart))
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(FrisTheme.textSecondary)
                        }
                    }
                }
                .frame(height: 110)
            }
            .contentMargins(.horizontal, 4)
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private var swolfTrendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gauge.with.needle")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "SWOLF Trend")
                Spacer()
                if swimVM.bestSwolfEver > 0 {
                    Text("Best: \(swimVM.bestSwolfEver)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.green)
                }
            }

            let data = swimVM.swolfOverTimeData
            if data.count < 2 {
                noDataPlaceholder("Need 2+ swims to show trend")
            } else {
                let minSwolf = (data.map(\.swolf).min() ?? 25) - 3
                let maxSwolf = (data.map(\.swolf).max() ?? 50) + 3
                let range = maxSwolf - minSwolf

                GeometryReader { geo in
                    let width = geo.size.width
                    let height: CGFloat = 100
                    let stepX = width / CGFloat(max(data.count - 1, 1))

                    ZStack(alignment: .topLeading) {
                        Path { path in
                            for (i, point) in data.enumerated() {
                                let x = CGFloat(i) * stepX
                                let y = CGFloat((point.swolf - minSwolf) / range) * height
                                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                        }
                        .stroke(accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                        Path { path in
                            for (i, point) in data.enumerated() {
                                let x = CGFloat(i) * stepX
                                let y = CGFloat((point.swolf - minSwolf) / range) * height
                                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                            if let last = data.indices.last {
                                path.addLine(to: CGPoint(x: CGFloat(last) * stepX, y: height))
                                path.addLine(to: CGPoint(x: 0, y: height))
                                path.closeSubpath()
                            }
                        }
                        .fill(LinearGradient(colors: [accentColor.opacity(0.2), accentColor.opacity(0)], startPoint: .top, endPoint: .bottom))
                    }
                    .frame(height: height)
                }
                .frame(height: 100)

                HStack {
                    Text("↓ Lower = More Efficient")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(FrisTheme.textSecondary)
                    Spacer()
                    if let first = data.first, let last = data.last {
                        let diff = first.swolf - last.swolf
                        HStack(spacing: 3) {
                            Image(systemName: diff > 0 ? "arrow.down.right" : "arrow.up.right")
                                .font(.system(size: 9))
                            Text(String(format: "%+.1f SWOLF", -diff))
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(diff > 0 ? .green : .orange)
                    }
                }
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private var strokeDistributionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Stroke Distribution")
                Spacer()
            }

            let distribution = swimVM.strokeDistribution
            if distribution.isEmpty {
                noDataPlaceholder("Log swims to see stroke breakdown")
            } else {
                VStack(spacing: 8) {
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            ForEach(distribution) { breakdown in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(breakdown.strokeType.color)
                                    .frame(width: max(geo.size.width * breakdown.percentage, 4))
                            }
                        }
                    }
                    .frame(height: 12)

                    ForEach(distribution) { breakdown in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(breakdown.strokeType.color)
                                .frame(width: 8, height: 8)
                            Text(breakdown.strokeType.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(FrisTheme.textPrimary)
                            Spacer()
                            Text("\(Int(breakdown.percentage * 100))%")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(breakdown.strokeType.color)
                            Text(SwimFormatters.formatPace(breakdown.averagePace) + "/100m")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(FrisTheme.textSecondary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private var cssCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "speedometer")
                    .foregroundStyle(FrisTheme.amber)
                HeadlineText(text: "Critical Swim Speed")
                Spacer()
            }

            if let css = swimVM.currentCSS {
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text(css.cssFormatted)
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .foregroundStyle(accentColor)
                        Text("/100m")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(FrisTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(accentColor.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 12))

                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Text("400m:")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(FrisTheme.textSecondary)
                            Text(SwimFormatters.formatDuration(css.time400m))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(FrisTheme.textPrimary)
                        }
                        HStack(spacing: 6) {
                            Text("200m:")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(FrisTheme.textSecondary)
                            Text(SwimFormatters.formatDuration(css.time200m))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(FrisTheme.textPrimary)
                        }
                        Text("Tested \(css.date.formatted(.dateTime.month(.abbreviated).day()))")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(FrisTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                Button {
                    swimVM.showCSSTest = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11))
                        Text("Retest CSS")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(accentColor.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 10))
                }
            } else {
                VStack(spacing: 8) {
                    Text("Take a CSS test to unlock pace zones")
                        .font(.caption)
                        .foregroundStyle(FrisTheme.textSecondary)
                    Button {
                        swimVM.showCSSTest = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 11))
                            Text("Start CSS Test")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(FrisTheme.amber)
                        .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private var recentSwimsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Recent Swims")
                Spacer()
                Text("\(swimVM.completedSwims.count) total")
                    .font(.caption)
                    .foregroundStyle(FrisTheme.textSecondary)
            }

            if swimVM.completedSwims.isEmpty {
                noDataPlaceholder("No swims logged yet")
            } else {
                ForEach(swimVM.completedSwims.prefix(5)) { swim in
                    Button {
                        swimVM.selectedSwim = swim
                        swimVM.showSwimDetail = true
                    } label: {
                        recentSwimRow(swim)
                    }
                }
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private func recentSwimRow(_ swim: CompletedSwim) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(swim.sessionType.color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: swim.sessionType.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(swim.sessionType.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(swim.sessionType.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FrisTheme.textPrimary)
                    if swim.isOpenWater {
                        Text("GPS")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color(red: 0.0, green: 0.8, blue: 0.7))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(red: 0.0, green: 0.8, blue: 0.7).opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                Text(swim.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                    .font(.system(size: 10))
                    .foregroundStyle(FrisTheme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(SwimFormatters.formatDistance(swim.totalDistanceMeters))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(accentColor)
                HStack(spacing: 4) {
                    if swim.totalLaps > 0 {
                        Text("\(swim.totalLaps) laps")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(FrisTheme.textSecondary)
                    }
                    Text(swim.averagePaceFormatted + "/100m")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(FrisTheme.textSecondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(FrisTheme.textSecondary.opacity(0.5))
        }
        .padding(.vertical, 4)
    }

    private var personalBestsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(FrisTheme.amber)
                HeadlineText(text: "Personal Bests")
                Spacer()
            }

            let bests = swimVM.personalBests
            if bests.isEmpty {
                noDataPlaceholder("Swim more to set records")
            } else {
                ForEach(bests) { pb in
                    HStack(spacing: 12) {
                        Text(pb.distance)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(accentColor)
                            .frame(width: 50, alignment: .leading)
                        Text(pb.timeFormatted)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(FrisTheme.textPrimary)
                        Spacer()
                        Text(SwimFormatters.formatPace(pb.pace) + "/100m")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(FrisTheme.textSecondary)
                        Text(pb.date.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(FrisTheme.textSecondary.opacity(0.6))
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private var paceZonesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.text.clipboard")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Pace Zones")
                Spacer()
            }

            let zones = swimVM.paceZones
            if zones.isEmpty {
                noDataPlaceholder("Complete a CSS test to see pace zones")
            } else {
                ForEach(zones) { zone in
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(zone.color)
                            .frame(width: 4, height: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(zone.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(FrisTheme.textPrimary)
                            Text(zone.paceRange + " /100m")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(FrisTheme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private func noDataPlaceholder(_ message: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .font(.title2)
                    .foregroundStyle(FrisTheme.textSecondary.opacity(0.5))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(FrisTheme.textSecondary)
            }
            .padding(.vertical, 16)
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

    private func weekLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}
