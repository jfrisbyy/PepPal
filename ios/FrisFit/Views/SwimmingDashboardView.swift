import SwiftUI
import MapKit

struct SwimmingDashboardView: View {
    @Bindable var swimVM: SwimmingViewModel
    let accentColor: Color

    var body: some View {
        VStack(spacing: 16) {
            heroHeader
            insightsCard
            weeklyFocusCard
            sessionTypeCard
            weeklyVolumeCard
            swolfTrendCard
            cssCard
            paceZonesCard
            strokeDistributionCard
            recentSwimsCard
            personalBestsCard
        }
    }

    // MARK: - Hero

    private var heroHeader: some View {
        EditorialSportHeader(
            kicker: "Swimming",
            title: heroTitle,
            subtitle: heroSubtitle,
            accent: accentColor,
            stats: [
                EditorialStat(SwimFormatters.formatDistance(swimVM.thisWeekMeters), "This Wk"),
                EditorialStat("\(swimVM.thisWeekSwims.count)", "Swims"),
                EditorialStat(SwimFormatters.formatPace(swimVM.averagePaceAllTime), "Pace"),
                EditorialStat(swimVM.averageSwolfAllTime > 0 ? String(format: "%.0f", swimVM.averageSwolfAllTime) : "—", "Swolf")
            ]
        ) {
            Button {
                swimVM.showSwimSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(PepTheme.elevated.opacity(0.5), in: Circle())
            }
        }
    }

    private var heroTitle: String {
        if swimVM.thisWeekSwims.isEmpty { return "Hit the water" }
        if swimVM.thisWeekSwims.count >= 4 { return "Stroke after stroke" }
        return "In the lane"
    }

    private var heroSubtitle: String {
        let count = swimVM.thisWeekSwims.count
        if count == 0 { return "No swims logged this week — sync from your watch or pick a session below." }
        let dist = SwimFormatters.formatDistance(swimVM.thisWeekMeters)
        return "\(count) swim\(count == 1 ? "" : "s") this week · \(dist) of clean water."
    }

    // MARK: - Insights

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Editorial", title: "Today's read", accent: accentColor)

            VStack(spacing: 10) {
                ForEach(swimVM.insights) { insight in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(insight.kind.color.opacity(0.12))
                                .frame(width: 32, height: 32)
                            Image(systemName: insight.kind.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(insight.kind.color)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(insight.kind.kicker.uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.4)
                                .foregroundStyle(insight.kind.color.opacity(0.9))
                            Text(insight.title)
                                .font(.system(size: 14, weight: .semibold, design: .serif))
                                .foregroundStyle(PepTheme.textPrimary)
                            Text(insight.message)
                                .font(.system(size: 12, design: .serif))
                                .italic()
                                .foregroundStyle(PepTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .background(insight.kind.color.opacity(0.05))
                    .clipShape(.rect(cornerRadius: 10))
                }
            }
        }
        .editorialCard(accent: accentColor)
    }

    // MARK: - Weekly Focus

    private var weeklyFocusCard: some View {
        let focus = swimVM.weeklyFocus
        return VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: focus.kicker, title: "Weekly Focus", accent: accentColor)

            VStack(alignment: .leading, spacing: 10) {
                Text(focus.title)
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .kerning(-0.3)
                    .foregroundStyle(PepTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(focus.rationale)
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                LinearGradient(
                    colors: [PepTheme.textPrimary.opacity(0.16), PepTheme.textPrimary.opacity(0)],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 0.5)
                    .padding(.vertical, 2)

                HStack(spacing: 10) {
                    if let stroke = focus.targetStroke {
                        HStack(spacing: 6) {
                            Image(systemName: stroke.icon)
                                .font(.system(size: 10, weight: .semibold))
                            Text(stroke.rawValue.uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.4)
                        }
                        .foregroundStyle(stroke.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(stroke.color.opacity(0.10))
                        .clipShape(Capsule())
                    }

                    Spacer()

                    Button {
                        swimVM.showDrillLibrary = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10))
                            Text("Try \(focus.drillName ?? "a drill")")
                                .font(.system(size: 11, weight: .semibold, design: .serif))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(accentColor)
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .editorialCard(accent: accentColor)
    }

    // MARK: - Session type & quick actions

    private var sessionTypeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Begin", title: "Choose your session", accent: accentColor)

            HStack(spacing: 8) {
                ForEach([SwimSessionType.poolLaps, .structuredWorkout, .openWater, .drillSession], id: \.id) { type in
                    Button {
                        swimVM.selectedSessionType = type
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: type.icon)
                                .font(.system(size: 16))
                            Text(type.rawValue)
                                .font(.system(size: 9, weight: .bold, design: .serif))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(swimVM.selectedSessionType == type ? .black : type.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(swimVM.selectedSessionType == type ? type.color : type.color.opacity(0.10))
                        .clipShape(.rect(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(type.color.opacity(swimVM.selectedSessionType == type ? 0 : 0.25), lineWidth: 0.5)
                        )
                    }
                }
            }

            HStack(spacing: 8) {
                quickAction("Drills", icon: "book.fill") { swimVM.showDrillLibrary = true }
                quickAction("Workouts", icon: "list.bullet.clipboard") { swimVM.showWorkoutBuilder = true }
                quickAction("CSS Test", icon: "speedometer", accent: PepTheme.amber) { swimVM.showCSSTest = true }
            }

            HStack(spacing: 6) {
                Image(systemName: "applewatch")
                    .font(.system(size: 11))
                    .foregroundStyle(accentColor.opacity(0.7))
                Text("Swim data syncs from Apple Watch via HealthKit")
                    .font(.system(size: 10, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
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
                        Text("SYNC")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.2)
                    }
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(accentColor.opacity(0.12))
                    .clipShape(Capsule())
                }
                .disabled(swimVM.isImportingFromHealthKit)
            }
        }
        .editorialCard(accent: accentColor)
    }

    private func quickAction(_ label: String, icon: String, accent: Color? = nil, action: @escaping () -> Void) -> some View {
        let color = accent ?? accentColor
        return Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(color.opacity(0.10))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.22), lineWidth: 0.5))
        }
    }

    // MARK: - Volume

    private var weeklyVolumeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(
                kicker: "Volume",
                title: "Weekly distance",
                accent: accentColor,
                trailing: AnyView(
                    Text("\(SwimFormatters.formatDistance(swimVM.thisWeekMeters)) THIS WK")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(accentColor)
                )
            )

            let volumeData = swimVM.weeklyVolumeHistory
            let maxMeters = max(volumeData.map(\.totalMeters).max() ?? 1, 1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(volumeData) { week in
                        VStack(spacing: 4) {
                            Text(SwimFormatters.formatDistance(week.totalMeters))
                                .font(.system(size: 7, weight: .bold, design: .rounded))
                                .foregroundStyle(week.totalMeters > 0 ? accentColor : PepTheme.textSecondary.opacity(0.4))

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    week.totalMeters > 0 ?
                                    LinearGradient(colors: [accentColor, accentColor.opacity(0.5)], startPoint: .top, endPoint: .bottom) :
                                    LinearGradient(colors: [PepTheme.elevated, PepTheme.elevated], startPoint: .top, endPoint: .bottom)
                                )
                                .frame(width: 24, height: max(CGFloat(week.totalMeters / maxMeters) * 80, 4))

                            Text(weekLabel(week.weekStart))
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                }
                .frame(height: 110)
            }
            .contentMargins(.horizontal, 4)
        }
        .editorialCard(accent: accentColor)
    }

    // MARK: - SWOLF

    private var swolfTrendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(
                kicker: "Efficiency",
                title: "SWOLF trend",
                accent: accentColor,
                trailing: swimVM.bestSwolfEver > 0 ? AnyView(
                    Text("BEST \(swimVM.bestSwolfEver)")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(.green)
                ) : nil
            )

            let data = swimVM.swolfOverTimeData
            if data.count < 2 {
                noDataPlaceholder("Need 2+ swims to read the trend")
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
                    Text("LOWER = MORE EFFICIENT")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textSecondary)
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
        .editorialCard(accent: accentColor)
    }

    // MARK: - CSS

    private var cssCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Threshold", title: "Critical Swim Speed", accent: PepTheme.amber)

            if let css = swimVM.currentCSS {
                HStack(spacing: 12) {
                    VStack(spacing: 4) {
                        Text(css.cssFormatted)
                            .font(.system(size: 30, weight: .semibold, design: .serif))
                            .foregroundStyle(accentColor)
                        Text("/100M")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(accentColor.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 6) {
                        cssRow(label: "400m", value: SwimFormatters.formatDuration(css.time400m))
                        cssRow(label: "200m", value: SwimFormatters.formatDuration(css.time200m))
                        Text("TESTED \(css.date.formatted(.dateTime.month(.abbreviated).day()).uppercased())")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity)
                }

                Button {
                    swimVM.showCSSTest = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11))
                        Text("RETEST CSS")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.4)
                    }
                    .foregroundStyle(accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(accentColor.opacity(0.10))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(accentColor.opacity(0.22), lineWidth: 0.5))
                }
            } else {
                VStack(spacing: 10) {
                    Text("Test once. Unlock pace zones, threshold sets, and smarter recommendations.")
                        .font(.system(size: 13, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        swimVM.showCSSTest = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 11))
                            Text("Start CSS Test")
                                .font(.system(size: 13, weight: .semibold, design: .serif))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 11)
                        .background(PepTheme.amber)
                        .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .editorialCard(accent: PepTheme.amber)
    }

    private func cssRow(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
                .frame(width: 36, alignment: .leading)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
            Spacer()
        }
    }

    // MARK: - Pace zones

    private var paceZonesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Targets", title: "Pace zones", accent: accentColor)

            let zones = swimVM.paceZones
            if zones.isEmpty {
                noDataPlaceholder("Complete a CSS test to see your zones")
            } else {
                VStack(spacing: 6) {
                    ForEach(zones) { zone in
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(zone.color)
                                .frame(width: 4, height: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(zone.name.uppercased())
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1.4)
                                    .foregroundStyle(zone.color)
                                Text(zone.paceRange + " /100m")
                                    .font(.system(size: 13, weight: .semibold, design: .serif))
                                    .foregroundStyle(PepTheme.textPrimary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .editorialCard(accent: accentColor)
    }

    // MARK: - Stroke distribution

    private var strokeDistributionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Repertoire", title: "Stroke mix", accent: accentColor)

            let distribution = swimVM.strokeDistribution
            if distribution.isEmpty {
                noDataPlaceholder("Log swims to see your stroke breakdown")
            } else {
                VStack(spacing: 10) {
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
                                .font(.system(size: 13, weight: .semibold, design: .serif))
                                .foregroundStyle(PepTheme.textPrimary)
                            Spacer()
                            Text("\(Int(breakdown.percentage * 100))%")
                                .font(.system(size: 13, weight: .semibold, design: .serif))
                                .foregroundStyle(breakdown.strokeType.color)
                            Text(SwimFormatters.formatPace(breakdown.averagePace) + "/100m")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                }
            }
        }
        .editorialCard(accent: accentColor)
    }

    // MARK: - Recent swims

    private var recentSwimsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(
                kicker: "Logbook",
                title: "Recent swims",
                accent: accentColor,
                trailing: AnyView(
                    Text("\(swimVM.completedSwims.count) TOTAL")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(PepTheme.textSecondary)
                )
            )

            if swimVM.completedSwims.isEmpty {
                noDataPlaceholder("No swims logged yet — log your first one to see your progress.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(swimVM.completedSwims.prefix(5).enumerated()), id: \.element.id) { idx, swim in
                        Button {
                            swimVM.selectedSwim = swim
                            swimVM.showSwimDetail = true
                        } label: {
                            recentSwimRow(swim)
                        }
                        if idx < min(4, swimVM.completedSwims.count - 1) {
                            LinearGradient(
                                colors: [PepTheme.textPrimary.opacity(0.10), PepTheme.textPrimary.opacity(0)],
                                startPoint: .leading, endPoint: .trailing
                            )
                            .frame(height: 0.5)
                        }
                    }
                }
            }
        }
        .editorialCard(accent: accentColor)
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
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                    if swim.isOpenWater {
                        Text("GPS")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(Color(red: 0.0, green: 0.8, blue: 0.7))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(red: 0.0, green: 0.8, blue: 0.7).opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                Text(swim.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                    .font(.system(size: 10, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(SwimFormatters.formatDistance(swim.totalDistanceMeters))
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(accentColor)
                HStack(spacing: 6) {
                    if swim.totalLaps > 0 {
                        Text("\(swim.totalLaps) laps")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    Text(swim.averagePaceFormatted + "/100m")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
        }
        .padding(.vertical, 10)
    }

    // MARK: - Personal Bests

    private var personalBestsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Records", title: "Personal bests", accent: PepTheme.amber)

            let bests = swimVM.personalBests
            if bests.isEmpty {
                noDataPlaceholder("Swim more to set your records")
            } else {
                VStack(spacing: 8) {
                    ForEach(bests) { pb in
                        HStack(spacing: 12) {
                            Text(pb.distance.uppercased())
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1.2)
                                .foregroundStyle(accentColor)
                                .frame(width: 56, alignment: .leading)
                            Text(pb.timeFormatted)
                                .font(.system(size: 18, weight: .semibold, design: .serif))
                                .foregroundStyle(PepTheme.textPrimary)
                            Spacer()
                            Text(SwimFormatters.formatPace(pb.pace) + "/100m")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(PepTheme.textSecondary)
                            Text(pb.date.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.0)
                                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .editorialCard(accent: PepTheme.amber)
    }

    // MARK: - Helpers

    private func noDataPlaceholder(_ message: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "drop")
                    .font(.title2)
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                Text(message)
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 16)
            Spacer()
        }
    }

    private func weekLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}
